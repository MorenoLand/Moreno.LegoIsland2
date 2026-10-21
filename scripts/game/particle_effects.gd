class_name ParticleEffects
extends Node3D

## The island's particle effects: the .par scripts (with the .app / .emi / .mov files they
## run) and the .swl swirls of the zone's particle folder, fed by the behaviours through
## GameServices. One tick is one 30 Hz engine step (the exe's per-frame step is 1.0 and life
## is lifespan * 30 ticks). The emitter arithmetic follows the exe's update code
## (FUN_00436FD0 / FUN_004380E0); the cone and ring placement are APPROXIMATE (see AGENTS.md).

const TICK_RATE := 30.0
const COLOUR_ONE := 65280.0
const ATLAS_CELLS := 8
const SWIRL_BASE := 0x1000
const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform sampler2D atlas : filter_nearest, source_color;
varying vec4 tint;
varying float cell;
void vertex() {
	tint = COLOR;
	cell = INSTANCE_CUSTOM.x;
	mat4 face = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	face[0] *= length(MODEL_MATRIX[0].xyz);
	face[1] *= length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * face;
}
void fragment() {
	float c = floor(cell + 0.5);
	vec2 origin = vec2(mod(c, 8.0), floor(c / 8.0)) / 8.0;
	vec4 t = texture(atlas, origin + UV / 8.0);
	ALBEDO = t.rgb * tint.rgb;
	ALPHA = t.a * tint.a;
}
"""


class Layer:
	var max_particles := 0
	var lifespan := 0.0
	var d_lifespan := 0.0
	var density := 0.0
	var d_density := 0.0
	var force := 0.0
	var d_force := 0.0
	var inc_angle := 0.0
	var exc_angle := 0.0
	var gravity := Vector3.ZERO
	var d_gravity := Vector3.ZERO
	var air := 1.0
	var d_air := 0.0
	var colour_start := Color.WHITE
	var colour_end := Color.WHITE
	var size_start := 1.0
	var size_end := 1.0
	var sprite_start := 0
	var sprite_end := 0
	var box_min := Vector3.ZERO
	var box_max := Vector3.ZERO
	var colour_keys_start: Array = []
	var colour_keys_end: Array = []
	var reset_at := -1.0


class Emitter:
	var layer: Layer
	var record = null
	var offset := Vector3.ZERO
	var rotation := Vector3.ZERO
	var matrix = null
	## A one-element array whose item 0 is the live matrix (the exe's global matrices).
	var matrix_ref = null
	var active := false
	var gate: Array = []
	var accumulator := 0.0
	var clock := 0.0
	var particles: Array = []
	var multimesh: MultiMesh
	var node: MultiMeshInstance3D
	var size_scale := Vector2.ONE
	var swirl: Array = []
	var density_override := -1.0
	var d_density_override := -1.0
	var end_size_override := -1.0
	var air_override := -1.0
	var burst := false


var island
var emitters: Array = []
var effect_cache := {}
var material: ShaderMaterial
var rng := RandomNumberGenerator.new()
var spawned := 0


func _folder() -> String:
	return "_data/%s/particle/" % island.zone


func _numbers(tokens: PackedStringArray, from: int) -> Array:
	var out: Array = []
	for i in range(from, tokens.size()):
		if tokens[i].is_valid_float():
			out.append(float(tokens[i]))
	return out


func _tokens(line: String) -> PackedStringArray:
	var parts := line.replace("\t", " ").replace("=", " ").strip_edges().split(" ", false)
	return parts


func _lines(path: String) -> Array:
	var text := Data.read(path).get_string_from_ascii().replace("\r", "")
	var out: Array = []
	for line in text.split("\n"):
		var trimmed := String(line).strip_edges()
		if trimmed != "" and not trimmed.begins_with("//"):
			out.append(trimmed)
	return out


func _colour(values: Array, at: int) -> Color:
	return Color(clampf(float(values[at]) / COLOUR_ONE, 0.0, 1.0), clampf(float(values[at + 1]) / COLOUR_ONE, 0.0, 1.0),
		clampf(float(values[at + 2]) / COLOUR_ONE, 0.0, 1.0), clampf(float(values[at + 3]) / COLOUR_ONE, 0.0, 1.0))


func _read_app(layer: Layer, file: String) -> void:
	for line in _lines(_folder() + file):
		var t := _tokens(line)
		if t.size() < 2:
			continue
		var v := _numbers(t, 1)
		match t[0]:
			"rgbaSColour":
				if v.size() >= 4:
					layer.colour_start = _colour(v, 0)
			"rgbaEColour":
				if v.size() >= 4:
					layer.colour_end = _colour(v, 0)
			"fSSize":
				layer.size_start = float(v[0])
			"fESize":
				layer.size_end = float(v[0])
			"iSSprite":
				layer.sprite_start = int(v[0])
			"iESprite":
				layer.sprite_end = int(v[0])


func _read_emi(layer: Layer, file: String) -> void:
	for line in _lines(_folder() + file):
		var t := _tokens(line)
		if t.size() < 2:
			continue
		var value := float(t[1]) if t[1].is_valid_float() else 0.0
		match t[0]:
			"iMaxParticles":
				layer.max_particles = int(value)
			"fLifespan":
				layer.lifespan = value
			"fDLifespan":
				layer.d_lifespan = value
			"fDensity":
				layer.density = value
			"fDDensity":
				layer.d_density = value
			"fForce":
				layer.force = value
			"fDForce":
				layer.d_force = value
			"fIncAngle":
				layer.inc_angle = value
			"fExcAngle":
				layer.exc_angle = value


func _read_mov(layer: Layer, file: String) -> void:
	for line in _lines(_folder() + file):
		var t := _tokens(line)
		if t.size() < 2:
			continue
		var v := _numbers(t, 1)
		match t[0]:
			"vGravity":
				if v.size() >= 3:
					layer.gravity = Vector3(v[0], v[1], v[2])
			"vDGravity":
				if v.size() >= 3:
					layer.d_gravity = Vector3(v[0], v[1], v[2])
			"fAir":
				layer.air = float(v[0])
			"fDAir":
				layer.d_air = float(v[0])


## Reads <name>.par and the scripts it runs into one Layer (null when the file is missing).
func load_effect(name: String) -> Layer:
	var key := name.to_lower()
	if key.ends_with(".par"):
		key = key.substr(0, key.length() - 4)
	if effect_cache.has(key):
		return effect_cache[key]
	var layer: Layer = null
	if Data.read(_folder() + key + ".par").size() > 0:
		layer = Layer.new()
		for line in _lines(_folder() + key + ".par"):
			var t := _tokens(line)
			if t.size() < 3 or (t[0] != "ForNew" and t[0] != "ForAll"):
				continue
			var v := _numbers(t, 2)
			match t[1]:
				"ExecuteScript":
					var file := String(t[t.size() - 1])
					match file.get_extension().to_lower():
						"app":
							_read_app(layer, file)
						"emi":
							_read_emi(layer, file)
						"mov":
							_read_mov(layer, file)
				"SetEmiPrimitive":
					var at := t.find("Size")
					if at >= 0:
						var box := _numbers(t, at + 1)
						if box.size() >= 6:
							layer.box_min = Vector3(box[0], box[1], box[2])
							layer.box_max = Vector3(box[3], box[4], box[5])
				"rgbaSColour", "rgbaEColour":
					if v.size() >= 10:
						var start := _colour(v, 2)
						var end := _colour(v, 6)
						var row := [float(v[0]), float(v[1]), start, end]
						if t[1] == "rgbaSColour":
							layer.colour_keys_start.append(row)
						else:
							layer.colour_keys_end.append(row)
				"ResetScript":
					if v.size() >= 1:
						layer.reset_at = float(v[0])
				"fDensity":
					if v.size() >= 3:
						layer.density = float(v[2])
	effect_cache[key] = layer
	return layer


func _material() -> ShaderMaterial:
	if material == null:
		var shader := Shader.new()
		shader.code = SHADER
		material = ShaderMaterial.new()
		material.shader = shader
		var image := Image.new()
		var bytes := Data.read(_folder() + "Text000.tga")
		if image.load_tga_from_buffer(bytes) == OK:
			material.set_shader_parameter("atlas", ImageTexture.create_from_image(image))
	return material


func _attach_mesh(emitter: Emitter, capacity: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	emitter.multimesh = MultiMesh.new()
	emitter.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	emitter.multimesh.use_colors = true
	emitter.multimesh.use_custom_data = true
	emitter.multimesh.mesh = mesh
	emitter.multimesh.instance_count = maxi(capacity, 1)
	emitter.multimesh.visible_instance_count = 0
	emitter.node = MultiMeshInstance3D.new()
	emitter.node.multimesh = emitter.multimesh
	emitter.node.material_override = _material()
	emitter.node.top_level = true
	emitter.node.extra_cull_margin = 4096.0
	add_child(emitter.node)


## FUN_004335F0: start an effect; returns its handle (the slot index) or -1.
## `gate` is [var, mask, value]: the effect runs while (var & mask) == value (the last three
## arguments of FUN_004335F0); without one it waits for set_mode.
func create(file: String, record, offset: Vector3, rotation: Vector3, gate: Array = []) -> int:
	var emitter := Emitter.new()
	emitter.gate = gate
	emitter.record = record
	emitter.offset = offset
	emitter.rotation = rotation
	if file.get_extension().to_lower() == "swl":
		emitter.layer = null
		_read_swirl(emitter, file)
		if emitter.swirl.is_empty():
			return -1
		_attach_mesh(emitter, _swirl_points(emitter))
		emitters.append(emitter)
		return SWIRL_BASE + emitters.size() - 1
	var layer := load_effect(file)
	if layer == null:
		return -1
	emitter.layer = layer
	_attach_mesh(emitter, layer.max_particles)
	emitters.append(emitter)
	return emitters.size() - 1


func _slot(handle: int) -> Emitter:
	var index := handle - SWIRL_BASE if (handle & SWIRL_BASE) == SWIRL_BASE else handle
	if index < 0 or index >= emitters.size():
		return null
	return emitters[index]


func _swirl_points(emitter: Emitter) -> int:
	var total := 0
	for ring in emitter.swirl:
		total += int(ring.points)
	return total


func _read_swirl(emitter: Emitter, file: String) -> void:
	var lines := _lines(_folder() + file)
	if lines.size() < 2:
		return
	var count := int(lines[1])
	var at := 2
	for i in count:
		if at + 6 >= lines.size():
			break
		var ring := {"layer": Layer.new(), "points": int(lines[at + 1]), "direction": float(lines[at + 2]),
			"speed": float(lines[at + 3]), "radius": float(lines[at + 4]), "yaw": float(lines[at + 5])}
		_read_app(ring.layer, String(lines[at]))
		var wobble := _tokens(lines[at + 6])
		ring["wobble"] = float(wobble[0]) if wobble.size() > 0 else 0.0
		ring["d_wobble"] = float(wobble[1]) if wobble.size() > 1 else 0.0
		emitter.swirl.append(ring)
		at += 7


## FUN_00433730 (handle, 1, 1, 1 / 2, 1, 1): mode 2 emits, mode 1 holds the effect back.
func set_mode(handle: int, mode: int) -> void:
	var emitter := _slot(handle)
	if emitter != null:
		emitter.gate = []
		emitter.active = mode == 2


## FUN_004336D0: follow an actor.
func attach_record(handle: int, record) -> void:
	var emitter := _slot(handle)
	if emitter != null:
		emitter.record = record
		emitter.matrix = null
		emitter.matrix_ref = null


## Follow a matrix the caller keeps updating (holder[0], 16 floats).
func attach_ref(handle: int, holder: Array) -> void:
	var emitter := _slot(handle)
	if emitter != null:
		emitter.matrix_ref = holder
		emitter.record = null


## FUN_004299A0: follow a matrix (16 floats, row vectors: the translation is row 3).
func attach_matrix(handle: int, matrix: PackedFloat32Array) -> void:
	var emitter := _slot(handle)
	if emitter != null and matrix.size() >= 16:
		emitter.matrix = matrix
		emitter.matrix_ref = null
		emitter.record = null


## FUN_004338A0(handle, which, value).
func set_param(handle: int, which: int, value: float) -> void:
	var emitter := _slot(handle)
	if emitter == null:
		return
	match which:
		0:
			emitter.end_size_override = value
		2:
			emitter.size_scale.x = value
		3:
			emitter.size_scale.y = value
		8:
			emitter.density_override = value
		9:
			emitter.d_density_override = value
		0x11:
			emitter.air_override = value


func burst_once(handle: int, record) -> void:
	var emitter := _slot(handle)
	if emitter != null:
		emitter.record = record
		emitter.burst = true


## The emitter's world position and its orientation basis (Godot coordinates).
func _frame(emitter: Emitter):
	var origin := Vector3.ZERO
	var basis := Basis.IDENTITY
	var live = emitter.matrix
	if emitter.matrix_ref != null:
		live = (emitter.matrix_ref as Array)[0]
	if live != null:
		var m: PackedFloat32Array = live
		origin = Vector3(m[12], m[13], -m[14])
		basis = Basis(Vector3(m[0], m[1], -m[2]), Vector3(m[4], m[5], -m[6]), Vector3(-m[8], -m[9], m[10]))
	elif emitter.record != null:
		var node = emitter.record.node
		if node != null:
			basis = (node as Node3D).global_transform.basis.orthonormalized()
			origin = (node as Node3D).global_transform.origin
		else:
			origin = Vector3(emitter.record.x, emitter.record.y, -emitter.record.z)
		if emitter.record.index == island.bridge.PLAYER_RECORD:
			basis = Basis(Vector3.UP, island.player_yaw)
			origin = Vector3(emitter.record.x, emitter.record.y, -emitter.record.z)
	else:
		return null
	var local := Vector3(emitter.offset.x, emitter.offset.y, -emitter.offset.z)
	return [origin + basis * local, basis]


func _cone_direction(layer: Layer, rotation: Vector3) -> Vector3:
	var theta := layer.exc_angle + rng.randf() * (layer.inc_angle - layer.exc_angle)
	var phi := rng.randf() * TAU
	var local := Vector3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta))
	var turned := Basis.from_euler(rotation) * local
	return Vector3(turned.x, turned.y, -turned.z)


func _key_colour(keys: Array, clock_ticks: float, fallback: Color) -> Color:
	for row in keys:
		var from: float = float(row[0]) * TICK_RATE
		var span: float = maxf(float(row[1]) * TICK_RATE, 1.0)
		if clock_ticks >= from and clock_ticks < from + span:
			return (row[2] as Color).lerp(row[3], (clock_ticks - from) / span)
	return fallback


func _spawn(emitter: Emitter, frame: Array) -> void:
	var layer: Layer = emitter.layer
	var life := (layer.lifespan + rng.randf() * layer.d_lifespan) * TICK_RATE
	if life <= 0.0:
		return
	var spread := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
	var box := layer.box_min.lerp(layer.box_max, rng.randf())
	var at: Vector3 = frame[0] + (frame[1] as Basis) * Vector3(spread.x * box.x, spread.y * box.y, -spread.z * box.z)
	var speed := layer.force + rng.randf() * layer.d_force
	var dir := (frame[1] as Basis) * _cone_direction(layer, emitter.rotation)
	var start := _key_colour(layer.colour_keys_start, emitter.clock, layer.colour_start)
	var end := _key_colour(layer.colour_keys_end, emitter.clock, layer.colour_end)
	var air := emitter.air_override if emitter.air_override >= 0.0 else layer.air + rng.randf() * layer.d_air
	var size_end := emitter.end_size_override if emitter.end_size_override >= 0.0 else layer.size_end
	emitter.particles.append({
		"pos": at, "vel": dir * speed, "age": 0.0, "life": life,
		"c0": start, "c1": end, "s0": layer.size_start * emitter.size_scale.x, "s1": size_end * emitter.size_scale.y,
		"i0": layer.sprite_start, "i1": layer.sprite_end, "air": air,
		"g": layer.gravity + layer.d_gravity * rng.randf(),
	})
	spawned += 1


func _gate(emitter: Emitter) -> void:
	if not emitter.gate.is_empty():
		emitter.active = (Game.get_var(int(emitter.gate[0])) & int(emitter.gate[1])) == int(emitter.gate[2])


func _step_effect(emitter: Emitter) -> void:
	_gate(emitter)
	var layer: Layer = emitter.layer
	var frame = _frame(emitter)
	var density := emitter.density_override if emitter.density_override >= 0.0 else layer.density
	var d_density := emitter.d_density_override if emitter.d_density_override >= 0.0 else layer.d_density
	if frame != null and (emitter.active or emitter.burst) and emitter.particles.size() < layer.max_particles:
		emitter.accumulator += rng.randf() * d_density + density
		var room := layer.max_particles - emitter.particles.size()
		var count := mini(int(emitter.accumulator), room)
		emitter.accumulator -= float(count)
		for i in count:
			_spawn(emitter, frame)
	emitter.burst = false
	if emitter.active or emitter.clock > 0.0:
		emitter.clock += 1.0
		if layer.reset_at >= 0.0 and emitter.clock >= layer.reset_at * TICK_RATE:
			emitter.clock = 0.0
	var alive: Array = []
	for p in emitter.particles:
		p.age = float(p.age) + 1.0
		if float(p.age) >= float(p.life):
			continue
		p.vel = ((p.vel as Vector3) + (Vector3(p.g.x, p.g.y, -p.g.z))) * float(p.air)
		p.pos = (p.pos as Vector3) + (p.vel as Vector3)
		alive.append(p)
	emitter.particles = alive


func _step_swirl(emitter: Emitter) -> void:
	_gate(emitter)
	emitter.clock += 1.0
	var frame = _frame(emitter)
	emitter.particles = []
	if frame == null or not emitter.active:
		return
	for ring in emitter.swirl:
		var layer: Layer = ring.layer
		var points: int = ring.points
		for i in points:
			var a: float = float(ring.yaw) + float(ring.direction) * float(ring.speed) * emitter.clock + TAU * float(i) / float(points)
			var local := Vector3(cos(a) * float(ring.radius), float(ring.wobble) * sin(a + float(ring.d_wobble) * emitter.clock), sin(a) * float(ring.radius))
			emitter.particles.append({"pos": frame[0] + (frame[1] as Basis) * local, "age": 0.0, "life": 1.0,
				"c0": layer.colour_start, "c1": layer.colour_start, "s0": layer.size_start, "s1": layer.size_start,
				"i0": layer.sprite_start, "i1": layer.sprite_start})


func tick() -> void:
	for emitter in emitters:
		if emitter.layer != null:
			_step_effect(emitter)
		else:
			_step_swirl(emitter)
		_draw(emitter)


func _draw(emitter: Emitter) -> void:
	if emitter.multimesh == null:
		return
	var shown := mini(emitter.particles.size(), emitter.multimesh.instance_count)
	emitter.multimesh.visible_instance_count = shown
	for i in shown:
		var p: Dictionary = emitter.particles[i]
		var t := clampf(float(p.age) / maxf(float(p.life), 1.0), 0.0, 1.0)
		var size := lerpf(float(p.s0), float(p.s1), t)
		var xf := Transform3D(Basis.IDENTITY.scaled(Vector3(size, size, size)), p.pos)
		emitter.multimesh.set_instance_transform(i, xf)
		emitter.multimesh.set_instance_color(i, (p.c0 as Color).lerp(p.c1, t))
		emitter.multimesh.set_instance_custom_data(i, Color(lerpf(float(p.i0), float(p.i1), t), 0.0, 0.0, 0.0))


func live_count() -> int:
	var total := 0
	for emitter in emitters:
		total += emitter.particles.size()
	return total
