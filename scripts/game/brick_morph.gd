class_name BrickMorph
extends Node3D

## The brick-by-brick build effect (the exe's BRICKFX module, FUN_0042C9A0 .. FUN_0042FFA0 and
## FUN_00430090 .. FUN_00433F90). A building record owns an effect with one model per phase (a
## BrickMorph/*.txt list of bricks); the game variable of the effect picks the wanted phase
## (var % phases). When the wanted phase differs from the current one the phase's morph kind
## queues effects on the bricks, the effects are stepped at 30 Hz until every one is done, a
## linger time runs out, and then the building's real mesh is shown or hidden (FUN_0042EE50).
##
## Only the morph kind the island's house stages use is ported: kind 8 (FUN_00431CE0), whose
## bricks from `start` to `end` (list order) fall in one after another and land with a sound
## (effects 6, FUN_0042FD10). The other building kinds (7, 4, 5, 10..13) are OPEN.
##
## Matrices follow the exe: 4x4 row vectors, a point is turned by `point * matrix`, and
## `concat(first, then)` is FUN_004225E5 with the arguments swapped (first applied first).

const TICK := 30.0
const MAX_TICKS := 4
## Brick units to scene units (FUN_00432240 and FUN_0042F2B0 scale every position this way).
const UNIT := Vector3(0.8, 0.96, 0.8)
const DEG_TO_RAD := 0.017453292
const PI_F := 3.1415927
const TAU_F := 6.2831855
## _DAT_008870A0: added to the drop height.
const DROP_MARGIN := 0.1
## Squared distances to the eye for the three levels of detail (FUN_004320F0).
const LOD_NEAR_SQUARED := 1280.0
const LOD_FAR_SQUARED := 7200.0
const LOD_COUNT := 3
const BRICK_DIRECTORY := "_data/Bricks/"
const MORPH_DIRECTORY := "_data/BrickMorph/"
const PALETTE_TEXTURE := "_data/Bricks/text000.tga"
const PALETTE_COLUMNS := 8
const PALETTE_CELL := 0.125
## TRANS_BLUE and the colours after it carry an alpha of 192 in the palette.
const TRANSLUCENT_FIRST := 16
const COLOUR_NAMES := ["dkgrey", "dkgreen", "red", "blue", "black", "white", "green", "yellow", "buff", "brown", "ltgrey", "ltgreen", "orange", "dkblue", "unused14", "unused15", "trans_blue", "trans_red", "trans_ltgrey", "trans_green", "trans_yellow", "trans_lime"]
const MORPH_FALL := 8
const MORPH_ASSEMBLE := 7
const MORPH_BLAST := 4
const MORPH_TWIST := 5
## Sounds of the other kinds (FUN_00431BA0 picks one by a running count & 3; FUN_004318B0).
const ASSEMBLE_SOUNDS := [0x350, 0x351, 0x353, 0x352]
const BLAST_SOUND := 0x34E
const ASSEMBLE_SLOW := {"total": 3.0, "per": 0.0, "base": 1.0, "random": 0.25, "height": 100.0}
const ASSEMBLE_FAST := {"total": 3.0, "per": 0.0, "base": 1.0, "random": 0.1, "height": 200.0}
## FUN_0045B379's block for kind 4: time spread, spin targets, spin rates, their spreads,
## the blast's acceleration and its distance limit (squared).
const BLAST := {"total": 5.0, "per": 0.0, "targets": Vector3(0.3, 0.2, 0.4), "rates": Vector3(0.0, 0.0, 0.0), "spreads": Vector3(0.005, 0.005, 0.005), "accel": Vector3(0.0, 1.0, 0.0), "limit": 40000.0}
## Kind 5 (FUN_00431A30) is kind 4 plus a second spin on the brick's other rotation (effect 7).
const TWIST := {"targets": Vector3(0.0, 0.2, 0.0), "rates": Vector3(0.0, 0.0, 0.0), "spreads": Vector3(0.005, 0.005, 0.005)}
const EFFECT_STEP := 0.0333
## Sound ids of the landing sounds, chosen by a running count & 3 (FUN_0042FD10), and of the
## looping sound that plays while a building is made (FUN_00431CE0).
const LAND_SOUNDS := [825, 824, 823, 822]
const BUILD_SOUND := 847
## Pepper's house (FUN_0045C23E-ish builder in chunk 8): record, variable and brick range of
## each stage. Stage 11 is the finished house, on the PHSE record.
const HOUSE_MODEL := "peppershouse01.txt"
const HOUSE_STAGES := [
	[350, 0x13B, 0, 0x16], [351, 0x133, 0x16, 0x2F], [352, 0x100, 0x2F, 0x55],
	[353, 0x13C, 0x55, 0x6B], [354, 0xFC, 0x6B, 0x7C], [355, 0x10E, 0x7C, 0x84],
	[356, 0x10D, 0x84, 0x9F], [357, 0x108, 0x9F, 0xAB], [358, 0x10C, 0xAB, 0xB4],
	[359, 0x114, 0xB4, 0xB7], [125, 0xFD, 0xB7, -1],
]
const HOUSE_TOTAL_TIME := 3.0
const HOUSE_BASE_SPEED := 1.0
const HOUSE_RANDOM_SPEED := 0.0
const HOUSE_HEIGHT := 60.0
const HOUSE_LINGER := 3.0


class Brick:
	var kind: Dictionary = {}
	var record := 0
	var colour_a := 0
	var colour_b := 0
	var group := 255
	var layer := 0
	var kind_offset := Vector3.ZERO
	var position := Vector3.ZERO
	var angles_a := PackedFloat32Array([0, 0, 0, 0, 0, 0])
	var angles_b := PackedFloat32Array([0, 0, 0, 0, 0, 0])
	var angles_c := PackedFloat32Array([0, 0, 0, 0, 0, 0])
	var drop := Vector3.ZERO
	var matrix := PackedFloat32Array()
	var dirty := true
	var active := false
	var visible := false
	var moving := false
	var effects: Array = []
	var node: MeshInstance3D = null
	var lod := -1


class Model:
	var bricks: Array = []
	var layers := 0


class Fx:
	var record := 0
	var var_id := 0
	var group := 0
	var files: Array = ["", ""]
	var phases := 2
	var models: Array = [null, null]
	var modes: Array = [0, 1]
	var morphs: Array = [0, MORPH_FALL]
	var params: Array = [{}, {}]
	var current := 0
	var started := false
	var state := 0
	var linger := HOUSE_LINGER
	var sound := -1
	var drawn := false
	var finished := false


var island: Node
var services = null
var fxs: Array = []
var clock := 0.0
var land_count := 0
var assemble_count := 0
var kinds := {}
var kind_by_id := {}
var kind_meshes := {}
var mesh_cache := {}
var palette: ImageTexture
var palette_material: Material
var glass_material: Material
var models := {}
var land_handles := {}


func setup(owner: Node) -> void:
	island = owner
	if island.bridge != null:
		services = island.bridge.services
	_load_kinds()
	var act: int = island._walker_act(Game.get_var(Game.VAR_STATE))
	if act == 0 or act == 4:
		for row in HOUSE_STAGES:
			_add_house_stage(int(row[0]), int(row[1]), int(row[2]), int(row[3]))
	_add_buildings(act)


func _add_house_stage(record: int, var_id: int, start: int, end: int) -> void:
	var fx := Fx.new()
	fx.record = record
	fx.var_id = var_id
	fx.group = 1000
	fx.files = [HOUSE_MODEL, HOUSE_MODEL]
	fx.params[1] = {"total": HOUSE_TOTAL_TIME, "per": 0.0, "base": HOUSE_BASE_SPEED, "random": HOUSE_RANDOM_SPEED, "height": HOUSE_HEIGHT, "start": start, "end": end}
	fx.current = Game.get_var(var_id) % fx.phases
	fxs.append(fx)


## The buildings of an act (FUN_00459DC7, FUN_0045AB01, FUN_0045A553, FUN_0045B379): each has a
## phase 0 and a phase 1 kind; only the kinds that are ported are registered.
func _add_buildings(act: int) -> void:
	var wanted := 0 if act == 0 or act == 4 else act
	for row in Table.rows("res://data/brick_fx.tsv"):
		if row.size() < 9 or int(row[0]) != wanted:
			continue
		var kind0 := int(row[4])
		var kind1 := int(row[6])
		if not (kind0 in [0, MORPH_ASSEMBLE]) or not (kind1 in [MORPH_ASSEMBLE, MORPH_BLAST, MORPH_TWIST]):
			continue
		var fx := Fx.new()
		fx.record = int(row[1])
		fx.var_id = int(row[2])
		fx.group = fx.record
		fx.files = ["test01.txt", String(row[3])]
		fx.morphs = [kind0, kind1]
		fx.modes = [int(row[5]), int(row[7])]
		fx.linger = float(row[8])
		var assemble: Dictionary = ASSEMBLE_FAST if wanted == 0 else ASSEMBLE_SLOW
		fx.params = [assemble, assemble]
		if kind1 == MORPH_BLAST:
			fx.params[1] = BLAST
		elif kind1 == MORPH_TWIST:
			var twisted := BLAST.duplicate()
			twisted["twist"] = TWIST
			fx.params[1] = twisted
		fx.current = Game.get_var(fx.var_id) % fx.phases
		if fx.current == 1 and int(fx.modes[1]) == 0:
			_show_record(fx, false)
		fxs.append(fx)


func _load_kinds() -> void:
	for row in Table.rows("res://data/brick_kinds.tsv"):
		if row.size() < 3 or not String(row[0]).is_valid_int():
			continue
		var kind := {"id": int(row[0]), "name": String(row[1]), "glass": int(row[2]), "split": [-1, -1, -1], "offset": Vector3.ZERO}
		for lod in LOD_COUNT:
			if row.size() > 3 + lod and String(row[3 + lod]).is_valid_int():
				kind.split[lod] = int(row[3 + lod])
		kinds[String(row[1]).to_lower()] = kind
		kind_by_id[int(row[0])] = kind
	for line in Data.read_text(BRICK_DIRECTORY + "brickset.txt").split("\n"):
		if line.begins_with("//"):
			continue
		var words := _words(line)
		if words.size() < 7:
			continue
		var key := String(words[0]).to_lower()
		if kinds.has(key):
			kinds[key].offset = Vector3(float(words[4]), float(words[5]), float(words[6])) * UNIT
			kinds[key].file = String(words[0])


func _words(line: String) -> PackedStringArray:
	var out := PackedStringArray()
	for part in line.replace("\t", " ").replace("\r", "").split(" ", false):
		out.append(part)
	return out


## FUN_00432240: read one BrickMorph list.
func _model(file_name: String) -> Model:
	if models.has(file_name):
		return _copy_model(models[file_name])
	var model := Model.new()
	var lines := Data.read_text(MORPH_DIRECTORY + file_name).split("\n")
	var centre := Vector3.ZERO
	var layer := 0
	var header := 0
	for raw in lines:
		var line := raw.strip_edges()
		if line.begins_with("//"):
			continue
		if header < 3:
			if line == "":
				continue
			header += 1
			if header == 3:
				var words := _words(line)
				if words.size() >= 5 and words[1].to_lower() == "vector":
					centre = Vector3(float(words[2]), float(words[3]), float(words[4])) * UNIT
			continue
		if line == "":
			continue
		line = line.to_lower()
		var words := _words(line)
		if words.size() == 1:
			if words[0].begins_with("newlayer"):
				layer += 1
			continue
		if words.size() < 9:
			continue
		var kind: Dictionary = kinds.get(words[1], {})
		if kind.is_empty() or not kind.has("file"):
			continue
		var brick := Brick.new()
		brick.kind = kind
		brick.kind_offset = kind.offset
		brick.position = Vector3(float(words[2]), float(words[3]), float(words[4])) * UNIT
		var rotation := Vector3(float(words[5]), float(words[6]), float(words[7])) * DEG_TO_RAD
		brick.angles_b[0] = rotation.x
		brick.angles_b[1] = _wrap(rotation.y + PI_F)
		brick.angles_b[2] = rotation.z
		brick.colour_a = COLOUR_NAMES.find(words[8])
		brick.colour_b = COLOUR_NAMES.find(words[9]) if words.size() > 9 else -1
		brick.layer = layer
		brick.group = _group(words[0])
		model.bricks.append(brick)
	for brick in model.bricks:
		brick.position += centre
	model.layers = layer
	models[file_name] = model
	return _copy_model(model)


func _copy_model(source: Model) -> Model:
	var model := Model.new()
	model.layers = source.layers
	for original in source.bricks:
		var brick := Brick.new()
		brick.kind = original.kind
		brick.colour_a = original.colour_a
		brick.colour_b = original.colour_b
		brick.group = original.group
		brick.layer = original.layer
		brick.kind_offset = original.kind_offset
		brick.position = original.position
		brick.angles_b = original.angles_b.duplicate()
		_rebuild(brick)
		model.bricks.append(brick)
	return model


## The tag of a brick line: AUTO09..AUTO00 are 0..9, PART00..PART19 are 10..29.
func _group(tag: String) -> int:
	if tag.length() == 6 and tag.begins_with("auto") and tag.substr(4).is_valid_int():
		return 9 - int(tag.substr(4))
	if tag.length() == 6 and tag.begins_with("part") and tag.substr(4).is_valid_int():
		return 10 + int(tag.substr(4))
	return 255


static func _wrap(angle: float) -> float:
	if angle > PI_F:
		return angle - TAU_F
	if angle < -PI_F:
		return angle + TAU_F
	return angle


static func _identity() -> PackedFloat32Array:
	return PackedFloat32Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])


## FUN_00421F40.
static func _euler(rx: float, ry: float, rz: float) -> PackedFloat32Array:
	var cx := cos(rx)
	var sx := sin(rx)
	var cy := cos(ry)
	var sy := sin(ry)
	var cz := cos(rz)
	var sz := sin(rz)
	return PackedFloat32Array([
		cz * cy, sz * cy, -sy, 0.0,
		cz * sy * sx - sz * cx, cz * cx + sz * sy * sx, cy * sx, 0.0,
		sz * sx + cz * sy * cx, sz * sy * cx - cz * sx, cy * cx, 0.0,
		0.0, 0.0, 0.0, 1.0])


## FUN_004225E5(out, then, first): the matrix that does `first`, then `then`.
static func _concat(first: PackedFloat32Array, then: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(16)
	for row in 3:
		for column in 3:
			out[row * 4 + column] = first[row * 4] * then[column] + first[row * 4 + 1] * then[4 + column] + first[row * 4 + 2] * then[8 + column]
	for column in 3:
		out[12 + column] = first[12] * then[column] + first[13] * then[4 + column] + first[14] * then[8 + column] + then[12 + column]
	out[15] = 1.0
	return out


## FUN_00431EA0: add the spin of one angle set, wrap it, and turn the matrix by it.
static func _spin(matrix: PackedFloat32Array, angles: PackedFloat32Array) -> PackedFloat32Array:
	for i in 3:
		angles[i] = _wrap(angles[i] + angles[3 + i])
	return _concat(matrix, _euler(angles[0], angles[1], angles[2]))


static func _shift(matrix: PackedFloat32Array, by: Vector3) -> void:
	matrix[12] += by.x
	matrix[13] += by.y
	matrix[14] += by.z


## FUN_00432000.
func _rebuild(brick: Brick) -> void:
	if not brick.dirty and not brick.matrix.is_empty():
		return
	var matrix := _identity()
	matrix = _spin(matrix, brick.angles_a)
	_shift(matrix, brick.kind_offset)
	matrix = _spin(matrix, brick.angles_b)
	_shift(matrix, brick.position)
	matrix = _spin(matrix, brick.angles_c)
	_shift(matrix, brick.drop)
	brick.matrix = matrix
	brick.dirty = false


func _process(delta: float) -> void:
	if island == null or fxs.is_empty():
		return
	clock = minf(clock + delta * TICK, float(MAX_TICKS))
	var stepped := false
	while clock >= 1.0:
		clock -= 1.0
		_tick()
		stepped = true
	if stepped:
		_draw()


## FUN_0042EE50 for every effect: start the wanted phase, step it, finish it.
func _tick() -> void:
	var paused: bool = Game.get_var(10) != 0 or island.pause_layer != null
	for fx in fxs:
		var wanted: int = Game.get_var(fx.var_id) % fx.phases
		if fx.current == wanted:
			continue
		if not fx.started:
			if fx.models[wanted] == null and fx.files[wanted] != "":
				fx.models[wanted] = _model(fx.files[wanted])
			match int(fx.morphs[wanted]):
				MORPH_FALL:
					_start_fall(fx, wanted)
				MORPH_ASSEMBLE:
					_start_assemble(fx, wanted)
				MORPH_BLAST, MORPH_TWIST:
					_start_blast(fx, wanted)
			fx.started = true
		if paused:
			continue
		fx.state = _step(fx)
		if fx.state != 2:
			continue
		match int(fx.modes[wanted]):
			0:
				_show_record(fx, false)
			1:
				_show_record(fx, true)
		fx.state = 0
		fx.finished = true
		fx.current = (fx.current + 1) % fx.phases
		for model in fx.models:
			if model != null:
				for brick in model.bricks:
					brick.effects.clear()
		fx.started = false
		if fx.sound >= 0 and services != null:
			services.sound_release(fx.sound)
		fx.sound = -1


func _show_record(fx: Fx, shown: bool) -> void:
	var node: Node3D = island.csm_host._record_node(fx.record)
	if node != null:
		node.visible = shown


## FUN_00431CE0: bricks before `start` stand, those up to `end` drop in, the rest wait.
func _start_fall(fx: Fx, phase: int) -> void:
	var model: Model = fx.models[phase]
	var p: Dictionary = fx.params[phase]
	var start: int = p.start
	var end: int = p.end if int(p.end) >= 0 else model.bricks.size()
	var step: float = p.per
	if float(p.total) > 0.0:
		step = float(p.total) / float(end - start)
	var delay := step
	var index := 0
	for brick in model.bricks:
		brick.active = true
		brick.record = fx.record
		if index < start:
			brick.visible = true
			brick.drop = Vector3.ZERO
		elif index < end:
			brick.visible = true
			var speed: float = (randf() * float(p.random) if float(p.random) > 0.0 else 0.0) + float(p.base)
			brick.effects.append({"kind": 6, "state": 0, "delay": delay, "started": false, "speed": speed, "velocity": Vector3.ZERO})
			brick.drop = Vector3(0.0, float(p.height) + DROP_MARGIN, 0.0)
			brick.dirty = true
			_rebuild(brick)
			delay += step
		else:
			brick.visible = false
		index += 1
	if services != null:
		fx.sound = services.sound_create(BUILD_SOUND)
		services.sound_follow(fx.sound, _record_position(fx.record))


## FUN_00431BA0: every brick is lifted by the height, then falls back in list order.
func _start_assemble(fx: Fx, phase: int) -> void:
	var model: Model = fx.models[phase]
	var p: Dictionary = fx.params[phase]
	for brick in model.bricks:
		brick.active = true
		brick.visible = true
		brick.record = fx.record
		brick.drop.y += float(p.height)
		brick.dirty = true
		_rebuild(brick)
	var step: float = p.per
	if float(p.total) > 0.0:
		step = float(p.total) / float(model.bricks.size())
	var delay := step
	for brick in model.bricks:
		var speed: float = (randf() * float(p.random) if float(p.random) > 0.0 else 0.0) + float(p.base)
		brick.effects.append({"kind": 6, "state": 0, "delay": delay, "started": false, "speed": speed, "velocity": Vector3.ZERO})
		delay += step
	assemble_count += 1
	_start_sound(fx, ASSEMBLE_SOUNDS[assemble_count & 3], false)


## FUN_004318B0: the layers blow apart from the top down; each brick spins up and then
## accelerates away until it is far enough (effects 3 and 0xC).
func _start_blast(fx: Fx, phase: int) -> void:
	var model: Model = fx.models[phase]
	var p: Dictionary = fx.params[phase]
	var step: float = p.per
	if float(p.total) > 0.0:
		step = float(p.total) / float(model.layers)
	for i in range(model.bricks.size() - 1, -1, -1):
		var brick: Brick = model.bricks[i]
		brick.active = true
		brick.visible = true
		brick.record = fx.record
		var delay: float = _random(step) + float(model.layers - brick.layer) * step
		brick.drop = Vector3.ZERO
		for k in 3:
			brick.angles_a[k] = 0.0
			brick.angles_a[3 + k] = 0.0
			brick.angles_c[k] = 0.0
		var targets: Vector3 = p.targets
		var rates: Vector3 = p.rates
		var spreads: Vector3 = p.spreads
		var rate := Vector3(rates.x - spreads.x + _random(spreads.x * 2.0), rates.y - spreads.y + _random(spreads.y), rates.z - spreads.z + _random(spreads.z))
		brick.effects.append({"kind": 3, "state": 0, "delay": delay, "targets": targets, "rates": rate, "cleared": false})
		if p.has("twist"):
			var twist: Dictionary = p.twist
			var twist_rate := Vector3(twist.rates.x - twist.spreads.x + _random(twist.spreads.x * 2.0), twist.rates.y - twist.spreads.y + _random(twist.spreads.y), twist.rates.z - twist.spreads.z + _random(twist.spreads.z))
			brick.effects.append({"kind": 7, "state": 0, "delay": delay, "targets": twist.targets, "rates": twist_rate, "cleared": false})
		brick.effects.append({"kind": 12, "state": 0, "delay": delay, "accel": p.accel, "velocity": Vector3.ZERO, "limit": p.limit})
	_start_sound(fx, BLAST_SOUND, true)


## FUN_004209AE: a random number from 0 up to the limit.
func _random(limit: float) -> float:
	return randf() * limit if limit > 0.0 else 0.0


func _start_sound(fx: Fx, id: int, restart: bool) -> void:
	if services == null:
		return
	if restart and fx.sound >= 0:
		services.sound_release(fx.sound)
	fx.sound = services.sound_create(id)
	services.sound_follow(fx.sound, _record_position(fx.record))


func _record_position(record: int) -> Vector3:
	var node: Node3D = island.csm_host._record_node(record)
	if node == null:
		return Vector3.ZERO
	return Vector3(node.position.x, node.position.y, -node.position.z)


## FUN_00430FD0: step every brick's effects; 2 once all are done and the linger time is out.
func _step(fx: Fx) -> int:
	var state := 3
	for model in fx.models:
		if model == null:
			continue
		for i in range(model.bricks.size() - 1, -1, -1):
			var brick: Brick = model.bricks[i]
			if brick.effects.is_empty():
				continue
			state = mini(state, _step_effects(brick))
	if state == 2 and fx.linger > 0.0:
		fx.linger -= 1.0 / TICK
		return 3
	return state


## FUN_00430E50: the lowest state of a brick's effects (0 waiting, 1 running, 2 done).
func _step_effects(brick: Brick) -> int:
	var lowest := 2
	for effect in brick.effects:
		if int(effect.state) == 2:
			continue
		match int(effect.kind):
			6:
				lowest = mini(lowest, _fall(brick, effect))
			3, 7:
				_spin_up(brick, effect)
			12:
				lowest = mini(lowest, _blast(brick, effect))
	return lowest


## FUN_00430090 (effect 3, the first rotation) and FUN_00430AC0 (effect 7, the last one): the
## angular speed of the brick moves toward its targets (never finishes).
func _spin_up(brick: Brick, effect: Dictionary) -> void:
	if not brick.active:
		return
	var dt := 1.0 / TICK
	if dt <= float(effect.delay):
		effect.delay = float(effect.delay) - dt
		return
	effect.state = 1
	var angles: PackedFloat32Array = brick.angles_a if int(effect.kind) == 3 else brick.angles_c
	if not effect.cleared:
		for other in brick.effects:
			if other != effect and int(other.kind) == int(effect.kind) and float(other.delay) == 0.0:
				other.state = 2
		effect.cleared = true
	for axis in 3:
		var target: float = effect.targets[axis]
		var current: float = angles[3 + axis]
		var moved: float = current + float(effect.rates[axis]) * 1.0
		if target < 0.0:
			if target < current:
				angles[3 + axis] = maxf(moved, target)
		elif current < target:
			angles[3 + axis] = minf(moved, target)
	brick.dirty = true


## FUN_004308B0: accelerate along the vector until the brick is far from its place.
func _blast(brick: Brick, effect: Dictionary) -> int:
	if not brick.active:
		return int(effect.state)
	var dt := 1.0 / TICK
	if dt <= float(effect.delay):
		effect.delay = float(effect.delay) - dt
		return int(effect.state)
	effect.state = 1
	effect.velocity += effect.accel * EFFECT_STEP
	brick.drop += effect.velocity
	brick.moving = true
	brick.dirty = true
	if brick.drop.length_squared() <= float(effect.limit):
		return 1
	return 2


## FUN_0042FD10: wait out the delay, then move down the drop at the effect's speed and land.
func _fall(brick: Brick, effect: Dictionary) -> int:
	if not brick.active:
		return int(effect.state)
	var dt := 1.0 / TICK
	if dt <= float(effect.delay):
		effect.delay = float(effect.delay) - dt
		return int(effect.state)
	effect.state = 1
	if not effect.started:
		_rebuild(brick)
		effect.velocity = -float(effect.speed) * brick.drop.normalized()
		brick.moving = true
		brick.visible = true
		effect.started = true
	var step: Vector3 = effect.velocity * dt * TICK
	if step.length() < brick.drop.length():
		brick.drop += step
		brick.dirty = true
		return int(effect.state)
	_land(brick)
	brick.drop = Vector3.ZERO
	effect.state = 2
	brick.moving = false
	brick.dirty = true
	return 2


func _land(brick: Brick) -> void:
	land_count += 1
	if services == null:
		return
	var id: int = LAND_SOUNDS[land_count & 3]
	if not land_handles.has(id):
		land_handles[id] = services.sound_create(id)
	var at := Vector3(brick.matrix[12], brick.matrix[13], brick.matrix[14])
	services.sound_follow(land_handles[id], at + _record_position(brick.record))


## FUN_004327B0 / FUN_004320F0: place every shown brick under its record and pick a level of detail.
func _draw() -> void:
	var eye := Vector3.ZERO
	if island.camera != null:
		eye = Vector3(island.camera.global_position.x, island.camera.global_position.y, -island.camera.global_position.z)
	for index in fxs.size():
		var fx: Fx = fxs[index]
		# The bricks of a finished effect stay drawn (the exe never clears their shown flag), but a
		# later stage of the same house draws all of them again, so they are dropped then.
		var covered := false
		for later in range(index + 1, fxs.size()):
			if fxs[later].group == fx.group and (fxs[later].started or fxs[later].finished):
				covered = true
		if not (fx.started or fx.finished) or covered:
			if fx.drawn:
				fx.drawn = false
				for model in fx.models:
					if model != null:
						for brick in model.bricks:
							if brick.node != null:
								brick.node.visible = false
			continue
		fx.drawn = true
		var parent := _identity()
		_shift(parent, _record_position(fx.record))
		for model in fx.models:
			if model == null:
				continue
			for brick in model.bricks:
				if not brick.visible:
					continue
				_rebuild(brick)
				var world := _concat(brick.matrix, parent)
				var position := Vector3(world[12], world[13], world[14])
				var lod := 0
				var distance := eye.distance_squared_to(position)
				if distance >= LOD_FAR_SQUARED:
					lod = 2
				elif distance >= LOD_NEAR_SQUARED:
					lod = 1
				_place(brick, world, lod)


func _place(brick: Brick, world: PackedFloat32Array, lod: int) -> void:
	if brick.node == null:
		brick.node = MeshInstance3D.new()
		brick.node.material_override = _material(brick.colour_a >= TRANSLUCENT_FIRST or brick.colour_b >= TRANSLUCENT_FIRST)
		add_child(brick.node)
	if brick.lod != lod:
		brick.lod = lod
		brick.node.mesh = _mesh(brick, lod)
	brick.node.visible = true
	var x := Vector3(world[0], world[1], -world[2])
	var y := Vector3(world[4], world[5], -world[6])
	var z := Vector3(world[8], world[9], -world[10])
	brick.node.transform = Transform3D(Basis(x, y, z), Vector3(world[12], world[13], -world[14]))


## The bricks are lit by the zone's own light, like the other lit meshes (FUN_00867440).
func _material(translucent: bool) -> Material:
	if palette == null:
		var image := Image.new()
		if image.load_tga_from_buffer(Data.read(PALETTE_TEXTURE)) == OK:
			palette = ImageTexture.create_from_image(image)
	if MeshBuilder.lighting.is_empty():
		var plain := StandardMaterial3D.new()
		plain.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		plain.cull_mode = BaseMaterial3D.CULL_DISABLED
		plain.albedo_texture = palette
		plain.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		return plain
	if translucent:
		if glass_material == null:
			glass_material = MeshBuilder.lit_blend_material(palette)
		return glass_material
	if palette_material == null:
		palette_material = MeshBuilder._lit_material(palette)
	return palette_material


## The three levels of a kind; a missing level takes the nearest one that exists (FUN_0042F2B0).
func _lods(kind: Dictionary) -> Array:
	if kind_meshes.has(kind.id):
		return kind_meshes[kind.id]
	var found: Array = []
	for lod in LOD_COUNT:
		var bytes := Data.read("%slods/%s_lod%d.msh" % [BRICK_DIRECTORY, kind.file, lod])
		found.append(MeshFile.parse(bytes) if bytes.size() > 0 else null)
	var order := [[0, 1, 2], [1, 0, 2], [2, 1, 0]]
	var filled: Array = []
	for lod in LOD_COUNT:
		var pick: MeshFile = null
		for candidate in order[lod]:
			if found[candidate] != null:
				pick = found[candidate]
				break
		filled.append(pick)
	kind_meshes[kind.id] = filled
	return filled


## One mesh per kind, level and colour pair: the vertices before the split use the first colour's
## palette cell, the glass vertices after it the second's.
func _mesh(brick: Brick, lod: int) -> ArrayMesh:
	var key := "%d_%d_%d_%d" % [brick.kind.id, lod, brick.colour_a, brick.colour_b]
	if mesh_cache.has(key):
		return mesh_cache[key]
	var file: MeshFile = _lods(brick.kind)[lod]
	if file == null:
		return null
	var count := file.positions.size()
	var split: int = int(brick.kind.split[lod]) if int(brick.kind.split[lod]) >= 0 else count - int(brick.kind.glass)
	var uvs := PackedVector2Array()
	uvs.resize(count)
	for i in count:
		uvs[i] = _palette_uv(brick.colour_a if i < split or brick.colour_b < 0 else brick.colour_b)
	var indices := file.indices.duplicate()
	for group in file.groups:
		for k in range(int(group[4]), int(group[4]) + int(group[1])):
			indices[k] += int(group[2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = file.positions
	arrays[Mesh.ARRAY_NORMAL] = file.normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_cache[key] = mesh
	return mesh


func _palette_uv(colour: int) -> Vector2:
	var index := maxi(colour, 0)
	# The exe reads the bottom-up TGA in file order, so its v counts from the bottom; the engine
	# flips such files on load, hence 1 - v.
	return Vector2(0.0625 + PALETTE_CELL * float(index % PALETTE_COLUMNS), 0.0625 + PALETTE_CELL * float(index / PALETTE_COLUMNS))
