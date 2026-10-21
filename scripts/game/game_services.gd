class_name GameServices
extends ActorServices

## The island's implementation of what the behaviours ask of an actor: animation clips of
## the skinned people, faces, ground height and the player. Everything not listed here keeps
## the defaults of ActorServices (sound, particles, camera and speech are not connected yet).

var island
var items := {}


func _item(record):
	return items.get(record.index)


func _frames(item: Dictionary) -> float:
	var blk = item.blk
	if item.clip >= 0 and item.clip < blk.anims.size():
		return maxf(float(int(blk.anims[item.clip].frames)), 1.0)
	return 1.0


func has_anim(record) -> bool:
	return items.has(record.index)


func set_clip(record, clip: int, start_frame: float) -> void:
	super.set_clip(record, clip, start_frame)
	var item = _item(record)
	if item != null:
		island._set_clip(item, clip)
		item.time = start_frame
		item["touched"] = true


func current_clip(record) -> int:
	var item = _item(record)
	if item == null:
		return super.current_clip(record)
	return int(item.clip)


## FUN_0042336A(anim, step): advance by `step` frames; true when the clip ran out.
func clip_finished(record, step: float) -> bool:
	var item = _item(record)
	if item == null:
		return super.clip_finished(record, step)
	item["touched"] = true
	var frames := _frames(item)
	item.time = float(item.time) + step
	if float(item.time) >= frames:
		item.time = fposmod(float(item.time), frames)
		return true
	if float(item.time) < 0.0:
		item.time = 0.0
	return false


func anim_frame(record) -> float:
	var item = _item(record)
	return float(item.time) if item != null else 0.0


func anim_set_frame(record, frame: float) -> void:
	var item = _item(record)
	if item != null:
		item.time = frame
		item["touched"] = true


func anim_length(record) -> float:
	var item = _item(record)
	return _frames(item) if item != null else 1.0


func anim_at_end(record) -> bool:
	var item = _item(record)
	if item == null:
		return false
	item["touched"] = true
	return float(item.time) + 1.0 >= _frames(item)


func set_face(record, frame: int) -> void:
	super.set_face(record, frame)
	var item = _item(record)
	if item != null and item.has("key"):
		island.set_face(String(item.key), frame)


## FUN_00881A12: the ground height under a point (game coordinates), or "none".
func ground_height(position: Vector3, _mode: float) -> float:
	var g: float = island._ground(Vector3(position.x, position.y + 4.0, -position.z), island.STEP_UP, false)
	return g if g > -INF else -1.0e38


func collide_down(_record, start: Vector3, delta: Vector3, _flags: int) -> Variant:
	var g: float = island._ground(Vector3(start.x, start.y, -start.z), island.STEP_UP, false)
	if g > -INF and g <= start.y and g >= start.y + minf(delta.y, 0.0):
		return Vector3(start.x, g, start.z)
	return null


const SPEECH_DIR := "_data/sounds/speech/English/"
var speech_files := {}
var speech_player: AudioStreamPlayer
var speech_ids: Array = []
var speech_until := 0
var talk_hold := false
var plays := 0


## FUN_00421C4D(table, name): the text and sound id of a talk line ("KEY:ID text").
func speech_lookup(table, name: String) -> Array:
	if table is Dictionary and table.has(name):
		var entry: Array = table[name]
		return [String(entry[1]), int(entry[0])]
	return [name, -1]


## Reads a .str file into {KEY: [id, text]} (the first line of a key wins).
func load_lines(path: String) -> Dictionary:
	var out := {}
	for line in Data.read(path).get_string_from_ascii().replace("\r\n", "\n").replace("\r", "\n").split("\n"):
		var colon := String(line).find(":")
		if colon <= 0:
			continue
		var key := String(line).substr(0, colon).to_upper()
		var rest := String(line).substr(colon + 1)
		var space := rest.find(" ")
		var id_text := rest.substr(0, space) if space >= 0 else rest
		if not out.has(key) and id_text.is_valid_int():
			out[key] = [int(id_text), rest.substr(space + 1).strip_edges() if space >= 0 else ""]
	return out


func _speech_file(id: int) -> String:
	if speech_files.is_empty():
		for row in Table.rows("res://data/speech_ids.tsv"):
			if row.size() >= 2 and String(row[0]).is_valid_int():
				speech_files[int(row[0])] = String(row[1])
	return String(speech_files.get(id, ""))


func _play_next() -> void:
	while not speech_ids.is_empty():
		var id: int = speech_ids.pop_front()
		var file := _speech_file(id)
		if file == "":
			continue
		var bytes := Data.read(SPEECH_DIR + file.to_upper() + ".mp3")
		if bytes.size() == 0:
			continue
		var stream := AudioStreamMP3.new()
		stream.data = bytes
		plays += 1
		speech_until = Time.get_ticks_msec() + int(stream.get_length() * 1000.0)
		if DisplayServer.get_name() != "headless" and Game.option("speech") != 0:
			if speech_player == null:
				speech_player = AudioStreamPlayer.new()
				speech_player.bus = "Speech"
				island.add_child(speech_player)
			speech_player.stream = stream
			speech_player.play()
		return


func speech_idle() -> bool:
	if Time.get_ticks_msec() < speech_until:
		return false
	if not speech_ids.is_empty():
		_play_next()
		return Time.get_ticks_msec() >= speech_until
	return true


func speech_queue(first: int, second: int) -> void:
	speech_ids = []
	if first >= 0:
		speech_ids.append(first)
	if second >= 0:
		speech_ids.append(second)


func speech_start() -> void:
	_play_next()


func speech_clear() -> void:
	speech_ids = []
	speech_until = 0
	if speech_player != null:
		speech_player.stop()


func subtitle_show(text: String) -> void:
	var host = island.csm_host
	if host != null and host.label != null:
		host.label.text = text
		host.label.visible = text != "" and Game.option("subtitles") != 0


func subtitle_clear() -> void:
	var host = island.csm_host
	if host != null and host.label != null:
		host.label.visible = false


func set_scene_active(on: int) -> void:
	talk_hold = on != 0
	scene_active = talk_hold


## FUN_0041B8B1(target, yaw, kind, height, table): aim the camera at an actor from a spot
## `table` (a local offset) rotated by `yaw`; looking at Pepper puts the normal camera back.
func camera_look(record, yaw: float, kind: int, height: float, table: int) -> void:
	if record == null or record == player:
		island.talk_view = {}
		return
	var offset := Vector3(4.0, 2.0, -10.0) if table == 0x974F20 else Vector3(0.0, 4.0, -20.0)
	var local := Vector3(offset.x, offset.y, offset.z)
	match kind:
		0:
			local = Vector3(0.0, 0.0, -1.75)
		2:
			pass
		_:
			local = Vector3(-offset.x, offset.y, -offset.z)
	var rotated := Vector3(local.x * cos(yaw) + local.z * sin(yaw), local.y, -local.x * sin(yaw) + local.z * cos(yaw))
	var look := Vector3(record.x, record.y + height, record.z)
	var eye := look + rotated
	island.talk_view = {"eye": Vector3(eye.x, eye.y, -eye.z), "look": Vector3(look.x, look.y, -look.z)}


## The exe's sound table (0x959030, 32 bytes per id: file, volume 0..127, loop count (0 = forever),
## near, far, pan, rate) and the handles its init code makes (key = address of the global).
var sound_table := {}
var sound_keys := {}
var sound_slots: Array = []
var sound_by_key := {}
var sound_streams := {}
var sound_plays := 0


func _sound_load() -> void:
	if not sound_table.is_empty():
		return
	for row in Table.rows("res://data/sound_table.tsv"):
		if row.size() >= 8:
			sound_table[int(row[0])] = [String(row[1]), int(row[2]), int(row[3]), float(row[4]), float(row[5]), int(row[6]), int(row[7])]
	for row in Table.rows("res://data/sound_keys.tsv"):
		if row.size() >= 3:
			sound_keys[int(row[0])] = int(row[2])


func _sound_stream(id: int) -> AudioStream:
	if sound_streams.has(id):
		return sound_streams[id]
	var entry: Array = sound_table.get(id, [])
	var stream: AudioStream = null
	if not entry.is_empty() and String(entry[0]) != "UNDEFINED":
		var bytes := Data.read(String(entry[0]))
		if bytes.size() > 0:
			var wav := Wav.parse(bytes)
			if wav != null:
				if int(entry[2]) == 0:
					var frame := (2 if wav.stereo else 1) * (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1)
					wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
					wav.loop_end = wav.data.size() / frame
				stream = wav
			else:
				var mp3 := AudioStreamMP3.new()
				mp3.data = bytes
				mp3.loop = int(entry[2]) == 0
				stream = mp3
	sound_streams[id] = stream
	return stream


## FUN_0042A180 / FUN_00429FB0: a handle for a sound id.
func sound_create(id: int) -> int:
	_sound_load()
	sound_slots.append({"id": id, "player": null, "three": false, "playing": false})
	return sound_slots.size() - 1


func _slot(key: int):
	_sound_load()
	if sound_keys.has(key):
		if not sound_by_key.has(key):
			sound_by_key[key] = sound_create(int(sound_keys[key]))
		return sound_slots[int(sound_by_key[key])]
	if key >= 0 and key < sound_slots.size():
		return sound_slots[key]
	return null


func _sound_player(slot: Dictionary, three: bool):
	if DisplayServer.get_name() == "headless":
		return null
	var wanted_kind := three
	if slot.player != null and bool(slot.three) != wanted_kind:
		slot.player.queue_free()
		slot.player = null
	if slot.player == null:
		var entry: Array = sound_table.get(int(slot.id), [])
		if entry.is_empty():
			return null
		slot.three = three
		if three:
			var p3 := AudioStreamPlayer3D.new()
			p3.bus = "Sound"
			p3.unit_size = maxf(float(entry[3]), 1.0)
			p3.max_distance = float(entry[4])
			slot.player = p3
		else:
			var p := AudioStreamPlayer.new()
			p.bus = "Sound"
			slot.player = p
		island.add_child(slot.player)
	return slot.player


func _sound_start(slot: Dictionary, three: bool, at: Vector3) -> void:
	if slot.playing:
		var current = slot.player
		if current != null and not current.playing and int(sound_table.get(int(slot.id), [0, 0, 1])[2]) != 0:
			slot.playing = false
		elif current != null and three:
			current.position = Vector3(at.x, at.y, -at.z)
		return
	var entry: Array = sound_table.get(int(slot.id), [])
	if entry.is_empty():
		return
	slot.playing = true
	sound_plays += 1
	var player = _sound_player(slot, three)
	var stream := _sound_stream(int(slot.id))
	if player == null or stream == null or Game.option("sound") == 0:
		return
	player.stream = stream
	player.volume_db = linear_to_db(maxf(float(entry[1]) / 127.0, 0.0001))
	if three:
		player.position = Vector3(at.x, at.y, -at.z)
	player.play()


func _sound_end(slot: Dictionary) -> void:
	slot.playing = false
	if slot.player != null:
		slot.player.stop()


## FUN_0042A1A0 (FUN_00858E04): start the 2D sound, or keep it going while it plays.
func sound_play(key: int) -> void:
	var slot = _slot(key)
	if slot != null:
		_sound_start(slot, false, Vector3.ZERO)


## The talk node's own call of FUN_0042A1A0 (its sound state is never 2 in the exe).
func sound_stop(key: int) -> void:
	sound_play(key)


## FUN_0042A190: 1 while the sound plays, 0 when it is done or never started.
func sound_state(key: int) -> int:
	var slot = _slot(key)
	if slot == null or not slot.playing:
		return 0
	var player = slot.player
	if player != null and not player.playing and int(sound_table.get(int(slot.id), [0, 0, 1])[2]) != 0:
		slot.playing = false
		return 0
	return 1


## FUN_00429FF0: play a sound at a position when the listener is within its range, else stop it.
func sound_follow(key: int, position: Vector3) -> void:
	var slot = _slot(key)
	if slot == null:
		return
	var entry: Array = sound_table.get(int(slot.id), [])
	if entry.is_empty():
		return
	var here: Vector3 = player_listener()
	var far: float = float(entry[4])
	if here.distance_squared_to(position) <= far * far:
		_sound_start(slot, true, position)
	else:
		_sound_end(slot)


func player_listener() -> Vector3:
	return Vector3(player.x, player.y, player.z) if player != null else Vector3.ZERO


## FUN_0042A200: playback rate in Hz.
func sound_set_value(key: int, value: int) -> void:
	var slot = _slot(key)
	if slot == null or slot.player == null:
		return
	var entry: Array = sound_table.get(int(slot.id), [])
	if not entry.is_empty() and int(entry[6]) > 0:
		slot.player.pitch_scale = clampf(float(value) / float(entry[6]), 0.1, 4.0)


## FUN_0042A1B0: stop and free the sample.
func sound_release(key: int) -> void:
	var slot = _slot(key)
	if slot != null:
		_sound_end(slot)


var particle_fx: ParticleEffects


func _fx() -> ParticleEffects:
	if particle_fx == null:
		particle_fx = ParticleEffects.new()
		particle_fx.island = island
		island.add_child(particle_fx)
	return particle_fx


func particle_create(file: String, record, offset: Vector3, rotation: Vector3, gate: Array = []) -> int:
	return _fx().create(file, record, offset, rotation, gate)


func particles(handle: int, mode: int) -> void:
	_fx().set_mode(handle, mode)


func emit_particle(handle: int, record) -> void:
	super.emit_particle(handle, record)
	_fx().burst_once(handle, record)


func particle_attach(handle: int, record) -> void:
	_fx().attach_record(handle, record)


func particle_attach_matrix(handle: int, matrix: PackedFloat32Array) -> void:
	_fx().attach_matrix(handle, matrix)


func particle_scale(handle: int, which: int, value: float) -> void:
	_fx().set_param(handle, which, value)


func particle_param(handle: int, which: int, value: float) -> void:
	_fx().set_param(handle, which, value)


func particle_tick() -> void:
	if particle_fx != null:
		particle_fx.tick()


## FUN_004209AE(max): C rand() / 32767 * max (0 when max <= 0).
func random_float(limit: float) -> float:
	if limit <= 0.0:
		return 0.0
	return float(randi() & 32767) / 32767.0 * limit


## FUN_0041F9C9 with the keyboard: the key bits (the two analogue axes stay 0 without a stick).
func read_input() -> Array:
	return [island._input_bits(), 0, 0]


## FUN_00428210: sweep a probe through the collision files. A vertical sweep reports the first
## ground surface it crosses, a horizontal one the first wall (the hit point is found by
## bisecting the segment; the exe's own radius and surface-mask handling are not read, OPEN).
func collide_sweep(_record, start: Vector3, delta: Vector3, _flags: int, _radius: float, _tolerance: float) -> Variant:
	var from := Vector3(start.x, start.y, -start.z)
	if absf(delta.x) + absf(delta.z) < 0.0001:
		var ground: float = island._ground(Vector3(from.x, maxf(start.y, start.y + delta.y), from.z), island.STEP_UP, false)
		if ground > -INF and ground >= minf(start.y, start.y + delta.y) and ground <= maxf(start.y, start.y + delta.y):
			return {"position": Vector3(start.x, ground, start.z), "normal": Vector3.UP}
		return null
	var to := Vector3(start.x + delta.x, start.y + delta.y, -(start.z + delta.z))
	var wall: Vector3 = island._wall_normal(from, to)
	if wall == Vector3.ZERO:
		return null
	var low := 0.0
	var high := 1.0
	for i in 6:
		var mid := (low + high) * 0.5
		if island._wall_normal(from, from.lerp(to, mid)) != Vector3.ZERO:
			high = mid
		else:
			low = mid
	var hit_at := from.lerp(to, high)
	return {"position": Vector3(hit_at.x, hit_at.y, -hit_at.z), "normal": Vector3(wall.x, 0.0, -wall.z).normalized()}


func particle_attach_ref(handle: int, holder: Array) -> void:
	_fx().attach_ref(handle, holder)


## The bone matrix of node `index` of a skinned actor in its current pose (16 floats, row
## vectors: rows are the images of the axes, translation in 12..14).
func anim_node_matrix(record, index: int) -> PackedFloat32Array:
	var m := PackedFloat32Array()
	m.resize(16)
	var item = _item(record)
	if item == null or not item.has("blk"):
		var file = _static_file(record)
		if file != null and index >= 0 and index < file.matrices.size():
			return _rows_of(file.matrices[index])
		return m
	var blk = item.blk
	var frames := int(_frames(item))
	var pose: Array = blk.pose(int(item.clip), int(item.time) % maxi(frames, 1))
	if index < 0 or index >= pose.size():
		return m
	var t: Transform3D = pose[index]
	m[0] = t.basis.x.x
	m[1] = t.basis.x.y
	m[2] = t.basis.x.z
	m[4] = t.basis.y.x
	m[5] = t.basis.y.y
	m[6] = t.basis.y.z
	m[8] = t.basis.z.x
	m[9] = t.basis.z.y
	m[10] = t.basis.z.z
	m[12] = t.origin.x
	m[13] = t.origin.y
	m[14] = t.origin.z
	m[15] = 1.0
	return m


func model_node_matrix(record, index: int) -> PackedFloat32Array:
	return anim_node_matrix(record, index)


## Parts of a static model that were cut out so they can turn on their own: record index ->
## {node index: {"node": MeshInstance3D, "base": Transform3D}} (matrices in game axes). An anim
## node of a static model is an entry of its MATL list; its part is every group whose GTOM
## entry names that matrix (node 0 is the body and never moves).
var node_parts := {}
var static_files := {}


## The parsed .msh of a record's static model (its node name is "<mesh>_<record>").
func _static_file(record):
	if static_files.has(record.index):
		return static_files[record.index]
	var host := record.node as MeshInstance3D if record != null else null
	var file = null
	if host != null:
		var base_name := String(host.name)
		file = MeshFile.parse(Data.read("_data/%s/meshes/%s.msh" % [island.zone, base_name.substr(0, base_name.rfind("_"))]))
	static_files[record.index] = file
	return file


func _rows_of(t: Transform3D) -> PackedFloat32Array:
	var m := PackedFloat32Array()
	m.resize(16)
	m[0] = t.basis.x.x
	m[1] = t.basis.x.y
	m[2] = t.basis.x.z
	m[4] = t.basis.y.x
	m[5] = t.basis.y.y
	m[6] = t.basis.y.z
	m[8] = t.basis.z.x
	m[9] = t.basis.z.y
	m[10] = t.basis.z.z
	m[12] = t.origin.x
	m[13] = t.origin.y
	m[14] = t.origin.z
	m[15] = 1.0
	return m


## FUN_004259E0: the number of animation nodes: bones of a skinned actor, entries of the MATL
## list of a static model.
func model_node_count(record) -> int:
	var item = _item(record)
	if item != null and item.has("blk"):
		return int(item.blk.offsets.size())
	var file = _static_file(record)
	return file.matrices.size() if file != null else 0


func _cut_node(record, index: int):
	var parts: Dictionary = node_parts.get(record.index, {})
	if parts.has(index):
		return parts[index]
	var host := record.node as MeshInstance3D
	if index <= 0 or host == null or not (host.mesh is ArrayMesh):
		return null
	var file = _static_file(record)
	if file == null or index >= file.matrices.size():
		return null
	var surface := 0
	var wanted := {}
	for g in file.groups.size():
		if file.group_surface(file.groups[g], g)[Mesh.ARRAY_VERTEX].is_empty():
			continue
		if g < file.group_matrix.size() and file.group_matrix[g] == index:
			wanted[surface] = true
		surface += 1
	var mesh := host.mesh as ArrayMesh
	if wanted.is_empty():
		return null
	var rest := ArrayMesh.new()
	var piece := ArrayMesh.new()
	for i in mesh.get_surface_count():
		var target: ArrayMesh = piece if wanted.has(i) else rest
		target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(i))
		target.surface_set_material(target.get_surface_count() - 1, mesh.surface_get_material(i))
	host.mesh = rest
	var child := MeshInstance3D.new()
	child.mesh = piece
	host.add_child(child)
	var entry := {"node": child, "base": file.matrices[index]}
	parts[index] = entry
	node_parts[record.index] = parts
	return entry


## FUN_00425A00 + FUN_004220A1: set the rotation of one anim node of the actor's model (translation kept,
## so the node turns about its own origin); the model's rest rotation is replaced by the angles,
## as in the exe, and the constructors pass the rest angle read from the node matrix.
func set_node_rotation(record, index: int, x: float, y: float, z: float) -> void:
	var entry = _cut_node(record, index)
	if entry == null:
		return
	var base: Transform3D = entry.base
	var turned := MeshFile._matrix(PackedFloat32Array([base.origin.x, base.origin.y, base.origin.z, x, y, z, 1.0, 1.0, 1.0]))
	var change := turned * base.affine_inverse()
	var flip := Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))
	(entry.node as MeshInstance3D).transform = Transform3D(flip * change.basis * flip, flip * change.origin)


## FUN_00428AB0 (as used by FUN_00458320 and the siren vehicle): does the segment origin ->
## origin + direction, thickened by `size`, touch the actor's solid. The exe tests the sphere,
## box or mesh the model's collision record names; here the bounding box of the actor's node
## stands in for it (APPROXIMATE). Like the exe it only answers for visible actors.
func collide_actor(record, query: Dictionary) -> bool:
	if record == null or (record.flags & 2) == 0:
		return false
	var node := record.node as Node3D
	if node == null:
		return false
	var box := AABB()
	var found := false
	for child in [node] + node.get_children():
		var mesh_node := child as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		var part: AABB = mesh_node.global_transform * mesh_node.get_aabb()
		box = part if not found else box.merge(part)
		found = true
	if not found:
		return false
	var size: Vector2 = query.get("size", Vector2.ONE)
	box = box.grow(maxf(size.x, size.y) * 0.5)
	var origin: Vector3 = query.origin
	var direction: Vector3 = query.direction
	var from := Vector3(origin.x, origin.y, -origin.z)
	var to := Vector3(origin.x + direction.x, origin.y + direction.y, -(origin.z + direction.z))
	var hit = box.intersects_segment(from, to)
	return hit != null or box.has_point(from)


## FUN_004410DC / FUN_0043D9E5: start cut scene `index` of the act (the position in the act's
## list) unless var 0xB is set; while one runs the next is queued. Var 0x5E bit 0x100 marks a
## running scene (set here, cleared by the scene tick FUN_0043DDE9 when it ends).
func reward_show(index: int) -> void:
	if Game.get_var(0xB) != 0:
		return
	var host = island.csm_host
	if host == null:
		return
	var name: String = host.script_for(index)
	if name == "":
		return
	if host.active:
		if host.queued == "":
			host.queued = name
		return
	if host.play(name):
		Game.set_var(0x5E, Game.get_var(0x5E) | 0x100)


## FUN_00429FB0 / FUN_0042A180 stored in a global by a zone's set-up: `key` is that global's
## address, `id` the sound-table id it was created from (the island's come from data/sound_keys.tsv).
func sound_define(key: int, id: int) -> void:
	_sound_load()
	sound_keys[key] = id
	sound_by_key.erase(key)


## FUN_00876813, run between the update pass and the post pass: resolves the move requests
## (BehaviourBlock.hint_*) the behaviours left on their blocks. Flags (+0x5C): 1 the origin is
## relative to the actor, 2 write the result back to the record (0x1000: only its height), 4 add
## the up offset, 8 keep the hit point, 0x10 / 0x20 probe the terrain under the origin (a sweep end
## below the ground is a hit and is clamped to it), 0x40 skip the sweep, 0x200 / 0x400 / 0x8000
## throttle the actor (every 4th / 8th tick, 0x8000: 8th when out of range), 0x2000 only while
## the look flag 0x10 is set, 0x4000 only while on screen. Hold (+0x64): 0 nothing, 1 ground.
## The sweep against other records (FUN_00428A60 / FUN_00428210 with the request's radius and
## kind) is OPEN; only the terrain probe is ported.
func resolve_hits(records: Array) -> void:
	for record in records:
		var block = record.block
		if block == null:
			continue
		if (block.flags & BehaviourBlock.FLAG_RUNS) == 0 or block.hint_mode == 0:
			block.hint_hold = 0
			continue
		var flags: int = block.hint_flags
		if ((flags & 0x2000) != 0 and (block.look_flags & 0x10) == 0) or ((flags & 0x4000) != 0 and (record.flags & 1) == 0):
			block.hint_mode = 0
			block.hint_hold = -0x45454546
			continue
		var throttle := flags & 0xE00
		if (flags & 0x8000) != 0 and block.range_limit < block.distance_squared:
			throttle = 0x400
		if (throttle & 0x400) != 0:
			block.hint_distance += 1.0
			if block.hint_distance < 8.0:
				block.hint_mode = 0
				block.hint_hold = -0x45454546
				continue
			block.hint_distance = 0.0
		elif (throttle & 0x200) != 0:
			block.hint_distance += 1.0
			if block.hint_distance < 4.0:
				block.hint_mode = 0
				block.hint_hold = -0x45454546
				continue
			block.hint_distance = 0.0
		if (flags & 1) != 0:
			block.hint_origin += Vector3(record.x, record.y, record.z)
		var origin: Vector3 = block.hint_origin
		var push: Vector3 = block.hint_target
		var struck := false
		var ground := -1.0e38
		if (flags & 0x30) != 0:
			ground = ground_height(origin, 4.0)
			if ground > -1.0e38 and push.y < ground - origin.y:
				struck = true
				push.y = ground - origin.y
				block.hint_target = push
		block.hint_mode = 0
		if struck:
			if block.hint_hold == 0 or block.hint_hold == -0x45454546:
				block.hint_hold = 1
			if (flags & 4) != 0:
				ground += block.hint_up.y
			if (flags & 2) != 0:
				if (flags & 0x1000) == 0:
					record.x = origin.x
					record.z = origin.z
				record.y = ground
		else:
			block.hint_hold = 0


func set_node_translation(record, index: int, axis: int, value: float) -> void:
	var entry = _cut_node(record, index)
	if entry == null:
		return
	var base: Transform3D = entry.base
	var moved := base.origin
	moved[axis] = value
	var change := Vector3(moved.x - base.origin.x, moved.y - base.origin.y, moved.z - base.origin.z)
	var flip := Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))
	var part := entry.node as MeshInstance3D
	part.transform = Transform3D(part.transform.basis, flip * change)
