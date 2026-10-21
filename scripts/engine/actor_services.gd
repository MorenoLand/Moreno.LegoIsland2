class_name ActorServices
extends RefCounted

## What the behaviours ask of an actor (animation, walker, sound). The engine layer calls
## these; the Godot glue (island.gd) supplies the real implementation. The default
## implementation keeps simple state so the behaviours run headless in tests.
## pseudocode: FUN_004232A3 set clip, FUN_0042336A clip finished test, FUN_0042332B
## current clip, FUN_0042333F current frame, FUN_00447390 walker step.

var clips := {}
var finished := {}


## FUN_004232A3(anim, clip, start_frame)
func set_clip(record, clip: int, start_frame: float) -> void:
	clips[record.index] = clip
	finished[record.index] = false


## FUN_0042332B(anim): the clip currently playing.
func current_clip(record) -> int:
	return int(clips.get(record.index, -1))


## FUN_0042336A(anim, 1.0): true when the clip has just reached its end.
func clip_finished(record, _step: float) -> bool:
	return bool(finished.get(record.index, false))


## Waypoint graphs by table (0 = W_ROAD, 1 = W_PATH, 2 = W_CSM, 3 = W_OTH), each a Waypoints.
var graphs := {}
var faces := {}
var particles_emitted: Array = []
var sounds_played: Array = []
## Things behaviours of one class share (the exe's file-scope globals), keyed by name.
var shared := {}
## Cut-scene switch name -> game var (FUN_00440CC4).
var switches := {}
## The walker engine (FUN_00445FAB..). Its graphs are the `graphs` above.
var walkers := WalkerEngine.new()


func _init() -> void:
	walkers.services = self


## FUN_004478A9(table, node, out): position of a waypoint node (game coordinates), or null.
func waypoint_position(table: int, node: int) -> Variant:
	var g = graphs.get(table)
	if g == null or node < 0 or node >= g.nodes.size():
		return null
	return g.nodes[node]


## Sets the waypoint graph of a table and gives it to the walker engine too.
func set_graph(table: int, graph) -> void:
	graphs[table] = graph
	walkers.graphs[table] = graph
	walkers.services = self


func _handle(record) -> int:
	return record.block.walker


## FUN_00426290(model, frame): the face expression frame of an actor.
func set_face(record, frame: int) -> void:
	faces[record.index] = frame


## FUN_00446BA4: the walker is held back by another walker (flag 0x400000).
func walker_blocked(record) -> bool:
	return walkers.blocked(_handle(record))


## FUN_00446BC9: the actor of the walker ahead, or null.
func walker_ahead(record) -> Variant:
	return walkers.ahead_actor(_handle(record))


## FUN_00433730 / FUN_00429FF0: particle control and emission (visual only).
func particles(handle: int, mode: int) -> void:
	pass


func emit_particle(handle: int, record) -> void:
	particles_emitted.append([handle, record.index])


## FUN_0042A0B0 / FUN_0042A1A0: play a sound handle (visual/audio only).
func play_sound(handle: int) -> void:
	sounds_played.append(handle)


## Walker engine entry points used by the behaviours (FUN_00446B29 finish route,
## FUN_00447612 turn toward a heading, FUN_004473E9 follow a record, FUN_00447390 step).
func walker_finish(record) -> void:
	walkers.finish(_handle(record))


func walker_turn_to(record, heading: float) -> void:
	walkers.turn_to(_handle(record), heading)


func walker_follow(record, target) -> void:
	walkers.follow_actor(_handle(record), target)


## Returns [result, heading, position]; result -1 = nothing to do, -3 = turn finished.
func walker_step(record, pos: Vector3) -> Array:
	return walkers.step(_handle(record), pos, record.yaw)


## FUN_004221E4: rebuild the actor matrix from its yaw and position.
func set_matrix(_record) -> void:
	pass


## FUN_0042333F: current animation frame; FUN_0042324D: halt the animation.
func anim_frame(_record) -> float:
	return 0.0


func anim_halt(_record) -> void:
	pass


## FUN_004478D8(table, node) + FUN_004474A2(walker, handle): set the walker goal.
func walker_goal(record, table: int, node: int) -> void:
	walkers.goal_to(_handle(record), waypoint_position(table, node))


## FUN_00423353: length (frames) of the current clip; FUN_0042324D: jump to a frame;
## FUN_00423474(anim, 1.0, 0): the clip has run out (end-of-clip test used by MeetPepp).
func anim_length(_record) -> float:
	return 1.0


func anim_set_frame(_record, _frame: float) -> void:
	pass


func anim_at_end(record) -> bool:
	return clip_finished(record, 1.0)


## FUN_00875D62(pepper_block, actor, amount): tells Pepper's start-talk behaviour which
## actor spoke (and for how long).
func notify_pepper_talk(_actor, _amount: float) -> void:
	pass


## FUN_004259e0: number of animated sub-nodes of the actor's model.
func model_node_count(_record) -> int:
	return 0


## FUN_00425a00 + FUN_004220a1: set the local rotation (radians about x, y, z) of one
## sub-node of the actor's model.
func set_node_rotation(_record, _index: int, _x: float, _y: float, _z: float) -> void:
	pass


## FUN_00441102: true while the scene is live (DAT_05d3fd4c set, or DAT_05d399c8 == 1).
## Still unnamed in the exe; effects that wait on it skip to their end when it is false.
var scene_active := true


## FUN_004ce3c0 reaches other records by their offset in the record array.
func record_at(_index: int) -> Variant:
	return null


## FUN_00422342(matrix, angles, position, scale): rebuild the actor matrix from three
## rotation angles, a position and a per-axis scale.
func set_actor_matrix(record, angles: Vector3, position: Vector3, _scale: Vector3) -> void:
	record.set_field_f(0x4C, angles.x)
	record.set_field_f(0x50, angles.y)
	record.set_field_f(0x54, angles.z)
	record.x = position.x
	record.y = position.y
	record.z = position.z


## FUN_00446852(handle): 0 = free, 2/3/4 = walking states of the 0x84-byte walker slot
## (FUN_00446B08 reads the slot's goal node short).
func walker_state(handle: int) -> int:
	return walkers.state(handle)


func walker_goal_node(handle: int) -> int:
	return walkers.goal_node(handle)


## Pepper (DAT_009CCB00) and the record array (DAT_00975E44), set by the island glue.
var player = null
var all_records: Array = []
var talk := TalkGlobals.new()


## FUN_0041DD9C: true when no speech clip is playing (DAT_009CCC38 not 1 or 2).
func speech_idle() -> bool:
	return true


## FUN_0041DD01(first, second): queue a speech clip (and an optional follow-up).
func speech_queue(_first: int, _second: int) -> void:
	pass


## FUN_0041DD4E: start the queued speech.  FUN_0041DDD0: stop and clear it.
func speech_start() -> void:
	pass


func speech_clear() -> void:
	pass


## FUN_00421C4D(table, name): look the line up; returns [name found, handle or -1].
func speech_lookup(_table, name: String) -> Array:
	return [name, -1]


## FUN_004441EC: show the subtitle text of a speech line.
func subtitle_show(_name: String) -> void:
	pass


## FUN_0041B8B1(actor, yaw, kind, height, table): aim the camera at an actor.
func camera_look(_record, _yaw: float, _kind: int, _height: float, _table: int) -> void:
	pass


## FUN_004450C0: talk prompt on / off.
func prompt_mode(on: int) -> void:
	prompt_state = on


## FUN_004209AE(max): a random number in [0, max).
func random_float(_limit: float) -> float:
	return 0.0


## FUN_0042B150(actor, mask, value) / FUN_0042B2C0(actor, value): set a field on the
## actor's model sub-nodes.
func model_set_field(_record, _mask: int, _value: int) -> void:
	pass


func model_set_flag(_record, _value: int) -> void:
	pass


## FUN_00428A60: sweep from `start` along `delta`; returns the hit position or null.
func collide_down(_record, _start: Vector3, _delta: Vector3, _flags: int) -> Variant:
	return null


## FUN_00881A12(position, mode): ground height under a position.
func ground_height(_position: Vector3, _mode: float) -> float:
	return -1.0e38


## FUN_00447A0F(1, actor, arg): get or make the walker slot of an actor.
func walker_create(record, arg: int) -> int:
	return walkers.get_or_create(1, record, arg)


## FUN_00446EC6 sets the speed (and rescales the slot's step); the other setters write one
## field of the 0x84-byte walker slot at the given offset.
func walker_set_speed(handle: int, value: float) -> void:
	walkers.set_speed(handle, value)


func walker_set_field(handle: int, offset: int, value) -> void:
	if value is int:
		walkers.slot(handle).set_u32(offset, value)
	else:
		walkers.slot(handle).set_f(offset, value)


## FUN_0042A180 / FUN_0042A190 / FUN_0042A1A0: sound handle make / state / stop.
func sound_create(_id: int) -> int:
	return 0


func sound_state(_handle: int) -> int:
	return 0


func sound_stop(_handle: int) -> void:
	pass


func sound_play(_key: int) -> void:
	pass


## FUN_0086E6A0: tilt the actor's matrix to the ground under it.
func align_to_ground(_record) -> void:
	pass


## FUN_00880CDF(a, b, point, radius, limit): closest-approach fraction along a segment.
func segment_hit(_a: Vector3, _b: Vector3, _point: Vector3, _radius: float, _limit: float) -> float:
	return -1.0


## FUN_004410DC(n): show the reward of a pickup.
func reward_show(_index: int) -> void:
	pass


## FUN_004221E4: rebuild the matrix from the angles stored on the record and a position.
func set_matrix_at(record, position: Vector3) -> void:
	record.x = position.x
	record.y = position.y
	record.z = position.z


## FUN_00441126(on): set DAT_05D3FD4C, the flag FUN_00441102 reports.
func set_scene_active(on: int) -> void:
	scene_active = on != 0


## FUN_004474A2(handle, position): send the walker to a position.
func walker_goal_to(record, position) -> void:
	walkers.goal_to(_handle(record), position)


## Snapshot of an actor's matrix (the talk start copies it to DAT_05DE1EF0).
func matrix_snapshot(_record) -> Variant:
	return null


## FUN_004220A1: set the rotation part of the matrix from the angles stored on the record.
func set_rotation(_record, _x: float, _y: float, _z: float) -> void:
	pass


## FUN_00446CA4(handle, actor): bind a walker slot to its actor.
func walker_bind(handle: int, record) -> void:
	walkers.bind(handle, record)


## Clears the four subtitle lines (DAT_05D3FE4C / 05D3FF1C / 05D3FFEC / 05D400BC).
func subtitle_clear() -> void:
	pass


## Whether the actor has an animation controller (record +8 is not null).
func has_anim(_record) -> bool:
	return true


## DAT_05D4A318: the records that block walkers; FUN_00428AB0 tests a swept sphere
## against one of them (the exe passes origin, direction and size in `query`).
var solid_records: Array = []


func collide_actor(_record, _query: Dictionary) -> bool:
	return false


## DAT_009CCB18: the camera position (set by FUN_0041B8B1).
var camera_position := Vector3.ZERO


## The 4x4 matrix (16 floats, row vectors, translation in 12..14) of a sub-node of the
## actor's model (FUN_00425A00).
func model_node_matrix(_record, _index: int) -> PackedFloat32Array:
	var m := PackedFloat32Array()
	m.resize(16)
	return m


## FUN_00422772(out, actor matrix, local): a point of the actor in world space.
func actor_point(record, local: Vector3) -> Vector3:
	var m := rotation_rows(record.field_f(0x4C), record.field_f(0x50), record.field_f(0x54))
	return Vector3(
		local.x * m[0] + local.y * m[4] + local.z * m[8] + record.x,
		local.x * m[1] + local.y * m[5] + local.z * m[9] + record.y,
		local.x * m[2] + local.y * m[6] + local.z * m[10] + record.z)


## FUN_004220A1 / FUN_00421F40: the rotation part of an actor matrix (16 floats, rows) from
## the three angles (pitch, yaw, roll).
static func rotation_rows(a: float, b: float, c: float) -> PackedFloat32Array:
	var f1 := cos(a)
	var f2 := sin(a)
	var f3 := cos(b)
	var f4 := sin(b)
	var f5 := cos(c)
	var f6 := sin(c)
	var m := PackedFloat32Array()
	m.resize(16)
	m[0] = f5 * f3
	m[1] = f6 * f3
	m[2] = -f4
	m[4] = f5 * f4 * f2 - f6 * f1
	m[5] = f5 * f1 + f6 * f4 * f2
	m[6] = f3 * f2
	m[8] = f6 * f2 + f5 * f4 * f1
	m[9] = f6 * f4 * f1 - f5 * f2
	m[10] = f3 * f1
	m[15] = 1.0
	return m


## FUN_00429780: reset the shadow / light state of the actor's model.
func model_reset_shadow(_record) -> void:
	pass


## FUN_00429FF0(handle, position): play a sound at a position when it is in range,
## otherwise stop it; FUN_0042A200: set its value; FUN_0042A1B0: release it.
func sound_follow(_key: int, _position: Vector3) -> void:
	pass


func sound_set_value(_key: int, _value: int) -> void:
	pass


func sound_release(_key: int) -> void:
	pass


## DAT_009CCAFC == 0: the first frame of the behaviour system.
func frame_zero() -> bool:
	return frame_counter == 0


var frame_counter := 0


## FUN_0042CB70(actor, id): send an actor event (FUN_0042F080).
func actor_event(_record, _id: int) -> void:
	pass


## FUN_00428210(actor, start, delta, flags, radius, tolerance): sphere sweep; null or
## {"position": Vector3, "normal": Vector3}.
func collide_sweep(_record, _start: Vector3, _delta: Vector3, _flags: int, _radius: float, _tolerance: float) -> Variant:
	return null


## DAT_009CCB3C / DAT_009CCB54: the camera's forward and right vectors (FUN_0042A0D0).
var camera_forward := Vector3(0, 0, 1)
var camera_right := Vector3(1, 0, 0)

var prompt_state := 0


func get_prompt_mode() -> int:
	return prompt_state


## FUN_004225E5 with a shear: scale the x axis into y and z of the actor's matrix.
func shear_matrix(_record, _amount: float) -> void:
	pass


## Copy the target's whole matrix (rotation and position) onto the actor (16 floats).
func copy_matrix(record, source) -> void:
	record.x = source.x
	record.y = source.y
	record.z = source.z
	record.set_field_f(0x4C, source.field_f(0x4C))
	record.set_field_f(0x50, source.field_f(0x50))
	record.set_field_f(0x54, source.field_f(0x54))


## FUN_004335F0 / FUN_00433660: start a particle effect from a file at an actor (the
## arguments are the offset, rotation and scale); returns its handle.
func particle_create(_file: String, _record, _offset: Vector3, _rotation: Vector3, _gate: Array = []) -> int:
	return 0


## FUN_004336D0(handle, actor): attach a particle effect to an actor's matrix.
func particle_attach(_handle: int, _record) -> void:
	pass


## The camera: DAT_009CCB18 eye, DAT_009CCB24 target, DAT_009CCB10 setting, DAT_00979CA0
## "camera follows by easing" flag, DAT_009CCB08 the camera rig record.
var camera_eye := Vector3.ZERO
var camera_target := Vector3.ZERO
var camera_setting := 0
var camera_locked := 0
var camera_rig = null


## FUN_0041F9C9: read the controls. Returns [bits, axis x, axis y]; DAT_00975E7C (the held
## direction bits 1 left, 2 right, 4 up, 8 down, 0x20 / 0x80 brake / accelerate) is
## `talk.game_flags_b`.
func read_input() -> Array:
	return [0, 0, 0]


## DAT_0089DA14: the camera height offset of each camera setting (first float of 3).
const CAMERA_HEIGHT := [6.4000000953674316, 1.0, 1.0, 1.0, 10.399999618530273, 8.0, 4.0, 0.0]


## FUN_0041B76C(eye, y, setting): bring the camera height to the setting's offset above y.
func camera_ease_height(y: float) -> void:
	var wanted: float = CAMERA_HEIGHT[camera_setting] + y
	if wanted <= camera_eye.y:
		if 32.0 < camera_eye.y - wanted:
			camera_eye.y -= 0.800000011920929
	else:
		camera_eye.y = wanted


## FUN_0087F210: tilt the machine's matrix to the ground under it (four probes).
func align_to_ground_machine(_record) -> void:
	pass


## FUN_00429510: the extents of the actor's model: [minimum, maximum].
func model_extents(_record) -> Array:
	return [Vector3.ZERO, Vector3.ZERO]


## FUN_004338A0(handle, which, value): set a scale on a particle effect.
func particle_scale(_handle: int, _which: int, _value: float) -> void:
	pass


## FUN_00423858(anim, index): the matrix (16 floats) of an animation node of the actor.
func anim_node_matrix(_record, _index: int) -> PackedFloat32Array:
	var m := PackedFloat32Array()
	m.resize(16)
	return m


## FUN_004299A0(handle, matrix): attach a particle effect to a matrix.
func particle_attach_matrix(_handle: int, _matrix: PackedFloat32Array) -> void:
	pass


func particle_attach_ref(_handle: int, _holder: Array) -> void:
	pass


## FUN_004338A0(handle, which, value): set a parameter of a particle effect.
func particle_param(_handle: int, _which: int, _value: float) -> void:
	pass


## FUN_004225E5(a, b): multiply two 4x4 matrices of 16 floats (row vectors).
static func matrix_multiply(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(16)
	for row in 4:
		for column in 4:
			var sum := 0.0
			for k in 4:
				sum += a[row * 4 + k] * b[k * 4 + column]
			out[row * 4 + column] = sum
	return out


## The 4x4 matrix (16 floats) of an actor from its angles and position.
func actor_matrix(record) -> PackedFloat32Array:
	var m := rotation_rows(record.field_f(0x4C), record.field_f(0x50), record.field_f(0x54))
	m[12] = record.x
	m[13] = record.y
	m[14] = record.z
	return m


## FUN_00425B80(model, which, colour, 0): tint a model (vertex colour); visual only.
func model_tint(_record, _which: int, _colour: int) -> void:
	pass


## FUN_008765F4(block, origin, push, kind, flags): leave a move request on the actor's block
## (see BehaviourBlock.set_hint); the pass FUN_00876813 resolves it after the update pass.
func request_hit(block, origin: Vector3, push: Vector3, kind: int, flags: int) -> void:
	block.set_hint(origin, push, kind, flags)


## FUN_00876808(block): the hit state field at +0x64 (what the collision pass wrote back).
func block_hit_state(block) -> int:
	return block.hint_hold if block != null else 0


## FUN_0087BA30(record, out, radius): what hit the actor this tick (0 / 4 = nothing worth
## reacting to); the player's thrown pizza and the like are not connected yet.
func hit_by_player(_record, _radius: float) -> int:
	return 0


func sound_define(_key: int, _id: int) -> void:
	pass


## Set one axis of an animation node's translation (game axes) in the actor's model.
func set_node_translation(_record, _index: int, _axis: int, _value: float) -> void:
	pass
