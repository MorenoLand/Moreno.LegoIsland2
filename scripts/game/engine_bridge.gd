class_name EngineBridge
extends RefCounted

## Connects the ported behaviour engine (scripts/engine) to the island scene: one Record
## per island record with its node, the act builders of the current story state, a
## fixed 30 Hz BehaviourSystem tick and the write-back of positions, angles and
## visibility to the nodes the behaviours own.

const Waypoints = preload("res://scripts/core/waypoints.gd")
const Builders = preload("res://scripts/engine/act_builders_gen.gd")
const TICK := 30.0
const MAX_TICKS := 4
## Input selector value while Pepper rides a machine (var 0x5E), and Pepper's clips for it
## (PEP_LGISTEER, PEP_INTOWALK).
const RIDE_SELECTOR := 8
const HORSE_SELECTOR := 0x10
const WALK_SELECTOR := 1
const STEER_CLIP := 0x4C
const WALK_CLIP := 0x1B
## The seat of a machine: node 1 of its model (FUN_00878C93).
const SEAT_NODE := 1
## The input selector while Pepper is on the skateboard (the low 12 bits are the state).
const SKATE_SELECTOR := 4
const BOARD_RECORD := 9
const RECORD_COUNT := 450
const PLAYER_RECORD := 16
const VIEW_RANGE_SQUARED := 90000.0
## Records other systems of the island still move themselves.
const LEGACY := [61, 62, 63, 64, 65, 158, 159, 160, 161, 162, 166, 167, 168, 169]
const LEGACY_RANGES := [[51, 60], [134, 153]]
## Talk set-up of each story state range (FUN_0044E5A0): [state below, talk file, hologram
## file (-1 none), target kind, target argument].
const TALK_STATES := [
	[4, 1, 1, "actor", 0], [5, 2, 2, "actor", 125], [6, 3, 3, "actor", 123], [7, 4, 4, "actor", 122],
	[8, 5, 5, "any", [69, 70, 71, 72]], [9, 6, 6, "actor", 0], [10, 7, 7, "actor", 124],
	[0xD, 8, 8, "actor", 116], [0x1E, 8, 8, "range", [162, 163]], [0x1F, 10, 5, "any", [69, 70, 71, 72]],
	[0x20, 10, 10, "actor", 121], [0x34, 10, 9, "range", [161, 165]], [0x35, 13, 5, "any", [69, 70, 71, 72]],
	[0x36, 13, 5, "any", [69, 70, 71, 72]], [0x37, 12, 5, "any", [69, 70, 71, 72]], [0x38, 12, 12, "actor", 120],
	[0x39, 13, 13, "actor", 0], [0x3A, 13, 13, "actor", 121], [0x3B, 14, 14, "actor", 115],
	[0x3E, 14, 14, "actor", 115], [0x45, 15, -1, "waypoint", 0x1A5],
]
## Builders of each act (FUN_004C632B, 004C4F19, 004C1118, 004BCCF4).
const ACTS := [
	["act0_a", "act0_b", "act0_c"],
	["act1_a", "act1_b", "act1_c", "act1_d"],
	["act2_a", "act2_b", "act2_c"],
	["act3_a", "act3_b", "act3_c"],
]


class GameVars:
	func get_var(i: int) -> int:
		if i == 9:
			return Game.option("speech")
		if i == 0:
			return Game.option("subtitles")
		return Game.get_var(i)

	func set_var(i: int, v: int) -> void:
		Game.set_var(i, v)

	func add_var(i: int, v: int) -> void:
		Game.set_var(i, Game.get_var(i) + v)

	func or_var(i: int, v: int) -> void:
		Game.set_var(i, Game.get_var(i) | v)

	func clear_var(i: int, v: int) -> void:
		Game.set_var(i, Game.get_var(i) & ~v)


var island
var records: Array = []
var nodes := {}
var services := GameServices.new()
var system := BehaviourSystem.new()
var vars := GameVars.new()
var clock := 0.0
var previous_keys := 0
var press_override := 0
var ready := false
var events := IslandEvents.new()
var program: ZoneProgram = null
var player_record := PLAYER_RECORD
var ride_started := false
var ride_last := {}
var record_count := RECORD_COUNT


func setup(owner) -> void:
	island = owner
	services.island = owner
	program = ZonePrograms.for_zone(owner.zone)
	if program != null:
		player_record = program.player_record
		record_count = 0
		for row in owner._rows("res://data/%s_placement.tsv" % owner.prefix):
			record_count = maxi(record_count, int(row[0]) + 1)
	for i in record_count:
		var record := Record.new()
		record.index = i
		records.append(record)
	for row in owner._rows("res://data/%s_placement.tsv" % owner.prefix):
		var record: Record = records[int(row[0])]
		record.code = String(row[1])
		record.set_field_f(0x4C, float(row[2]))
		record.yaw = float(row[3])
		record.set_field_f(0x54, float(row[4]))
		record.x = float(row[5])
		record.y = float(row[6])
		record.z = float(row[7])
	for child in owner.get_children():
		if not (child is MeshInstance3D):
			continue
		var tail := String(child.name).get_slice("_", String(child.name).get_slice_count("_") - 1)
		if not tail.is_valid_int():
			continue
		var index := int(tail)
		if index < 0 or index >= record_count:
			continue
		nodes[index] = child
		var record: Record = records[index]
		record.flags = 2 if child.visible else 0
		record.node = child
		record.x = child.position.x
		record.y = child.position.y
		record.z = -child.position.z
	for item in owner.cheerers:
		var name := String(item.node.name)
		var tail := name.get_slice("_", name.get_slice_count("_") - 1)
		if tail.is_valid_int() and int(tail) < record_count:
			item["driven"] = true
			item.stage = 3
			services.items[int(tail)] = item
	var graph_files := ["w_road_c", "w_path_c", "w_csm_c", "w_oth_c"]
	for table in 4:
		var graph = Waypoints.new()
		if graph.parse(Data.read("_data/%s/waypoints/%s.wpt" % [owner.zone, graph_files[table]])):
			services.set_graph(table, graph)
	services.all_records = records
	records[player_record].flags = 3
	services.player = records[player_record]
	if program == null:
		services.camera_rig = records[player_record]
	if program != null:
		program.build(self)
	else:
		services.talk.ground_min = island.SEA_LEVEL
		_build_act()
		_setup_effects()
		_setup_talk()
		_setup_player_modes()
	if Game.get_var(0x5E) == 0:
		Game.set_var(0x5E, 1)
	if records[player_record].block == null:
		records[player_record].block = BehaviourBlock.new()
	ready = true


## FUN_0044B7B0 registers the controllers of the input selector on Pepper's record; the island's
## own walker and swimmer stand in for the ones at selectors 1 and 2. The island's sounds the board
## uses (FUN_0044B287 / FUN_0044B666) are defined here.
func _setup_player_modes() -> void:
	for row in IslandMode.SOUNDS:
		services.sound_define(int(row[0]), int(row[1]))
	var player: Record = records[player_record]
	if player.block == null:
		player.block = BehaviourBlock.new()
	var controller := IslandMode.from_descriptor(services, vars)
	controller.tag = 0x5E
	var board := Skate.from_descriptor(services, vars)
	board.tag = 0x5E
	board.mask = 4
	board.value = 4
	player.block.add(controller, 0)
	player.block.add(board, 1)


func _setup_talk() -> void:
	var state: int = Game.get_var(Game.VAR_STATE)
	var g := services.talk
	for row in TALK_STATES:
		if state >= int(row[0]):
			continue
		g.speech_table = services.load_lines("_data/messages/li/english/lifsm%d.str" % int(row[1]))
		if int(row[2]) >= 0:
			g.helper_table = services.load_lines("_data/messages/li/english/lihol%d.str" % int(row[2]))
		match row[3]:
			"actor":
				g.set_target_actor(records[int(row[4])] if int(row[4]) > 0 else null, 16.0)
			"any":
				var list: Array = row[4]
				g.set_target_any(records[list[0]], records[list[1]], records[list[2]], records[list[3]])
			"range":
				g.set_target_actor_range(records[int(row[4][0])], records[int(row[4][1])], 8.0)
			"waypoint":
				g.set_target_waypoint(int(row[4]), 16.0)
				g.set_target_actor(null, 16.0)
		return


## Effects the island's act set-up functions attach to records, each running while a game
## var matches (FUN_0045B379 and FUN_0045AF0A for acts 0 and 4, FUN_0045A830 for act 1).
## The ones placed by FUN_0044F09D from static matrices (bill01, rocket01, zzz, twinkle03)
## need that driver and are still open.
func _setup_effects() -> void:
	var state: int = Game.get_var(Game.VAR_STATE)
	var act: int = island._walker_act(state)
	var turned := Vector3(-PI / 2.0, 0.0, 0.0)
	events.setup(services, records)
	if act == 1 or act == 2 or act == 0 or act == 4:
		events.add_bill()
	if act == 3:
		events.add_bill()
		events.add_rockets(6)
		events.add_twinkle()
	if act == 0 or act == 4:
		events.add_rockets(2)
		events.add_zzz()
	if act == 1:
		services.particle_create("TWINKLE01.par", records[4], Vector3(8.0, 51.3, 158.0), turned, [0x95, 9, 9])
	elif act == 0 or act == 4:
		services.particle_create("problow.par", records[10], Vector3(0.0, 3.5, 0.0), Vector3.ZERO, [0x11E, 1, 1])
		services.particle_create("eatpizza.par", records[10], Vector3(0.0, 3.5, 0.0), Vector3.ZERO, [0x11F, 1, 1])
		services.particle_create("twinkle02.par", records[318], Vector3.ZERO, Vector3(0.0, 2.355, 0.0), [0x132, 1, 1])
		if Game.get_var(0x58) >= 8:
			services.particle_create("shuttle01.par", records[155], Vector3(0.0, -1.0, 2.86), Vector3(PI / 2.0, 0.0, 0.0), [0xFB, 1, 1])
			services.particle_create("shuttle02.par", records[155], Vector3(0.0, -8.0, 2.86), Vector3.ZERO, [0xFB, 1, 1])


func _build_act() -> void:
	var state: int = Game.get_var(Game.VAR_STATE)
	var act: int = island._walker_act(state)
	var unit := BuilderUnit.new(vars, 0)
	unit.records = records
	EngineSetup.register_ports(unit.ctx, services, vars)
	var generator = Builders.new()
	for name in ACTS[act]:
		generator.call("build_" + name, unit, state)


func _legacy(index: int) -> bool:
	if program != null:
		return program.legacy(index)
	if LEGACY.has(index):
		return true
	for range_pair in LEGACY_RANGES:
		if index >= range_pair[0] and index <= range_pair[1]:
			return true
	return false


func update(delta: float) -> void:
	if not ready:
		return
	if island.csm_host != null:
		island.csm_host.engine_driven = true
	clock = minf(clock + delta * TICK, float(MAX_TICKS))
	while clock >= 1.0:
		clock -= 1.0
		_tick()


func _tick() -> void:
	var held: bool = island.story_hold or island.camera_locked
	services.scene_active = held or services.talk_hold
	if held:
		return
	var player: Record = records[player_record]
	var here: Vector3 = island.player_pos
	var riding := _riding()
	var skating := _skating()
	if not riding and not skating:
		_follow_camera()
	if not riding and not skating and (Game.get_var(0x5E) & 0xFFF) == WALK_SELECTOR and services.talk.busy == 0:
		# While Pepper walks the clip he plays is the mode the controller reads (DAT_009749B8).
		services.talk.pepper_clip = island.pepper_clip
	# island.player_pos and player_yaw are in the scene's axes (z mirrored); the records use the game's.
	if (program == null or not program.drives_player) and not riding and not skating:
		player.x = here.x
		player.y = here.y
		player.z = -here.z
		player.yaw = wrapf(PI - island.player_yaw, -PI, PI)
	# DAT_00975E7C holds the keys held, DAT_00975E80 the keys that went down this tick
	# (0x10 action, 0x40 talk, 0x80 space).
	var held_keys: int = island._input_bits() | press_override
	services.talk.game_flags = held_keys & ~previous_keys
	services.talk.game_flags_b = held_keys
	previous_keys = held_keys
	var camera: Camera3D = island.camera
	# The record nodes are direct children of the island, which sits at the origin, so local
	# and global positions agree (global_position is much slower to read).
	var eye: Vector3 = camera.global_position if camera != null else Vector3.ZERO
	for index in nodes:
		var record: Record = records[index]
		var node: Node3D = nodes[index]
		var seen: bool = node.visible and (record.flags & 2) != 0
		if seen and camera != null:
			seen = eye.distance_squared_to(node.position) < VIEW_RANGE_SQUARED
		if seen:
			record.flags |= 1
		else:
			record.flags &= ~1
	# Vtable slot 3 of the talk node (FUN_0087D7D3), run when its actor is drawn, resets the
	# nearest-talker distance to 256 (16 units squared) for the next frame.
	services.talk.nearest_distance = 256.0
	for item in services.items.values():
		item["touched"] = false
	if program != null:
		program.pre_tick()
	system.tick(records, player, vars)
	services.resolve_hits(records)
	system.post_pass(records)
	var was_on: bool = island.ride_on
	island.ride_on = _riding() or _skating()
	island.ground_skip = machine_record()
	if was_on and not island.ride_on and skating:
		island.dismount_t = island.pepper_time
		island.ride_tilted = false
	if program != null and not riding and not island.ride_on:
		# A zone's own behaviours may have moved Pepper (the castle puts him on the ground
		# beside the horse): the island's walk starts from there.
		var moved := Vector3(player.x, player.y, -player.z)
		if moved.distance_to(here) > 0.001:
			island.player_pos = moved
	if _skating():
		_skate_follow()
	elif island.ride_on:
		_ride_follow()
	services.frame_counter = system.frame
	if program == null:
		events.tick()
	else:
		program.tick()
	services.particle_tick()
	for index in nodes:
		var record: Record = records[index]
		var driven: bool = index == machine_record()
		if record.block == null or index == player_record or (_legacy(index) and not driven):
			continue
		var node: MeshInstance3D = nodes[index]
		node.visible = (record.flags & 2) != 0
		node.position = Vector3(record.x, record.y, -record.z)
		if record.matrix_valid:
			node.basis = island.rows_basis(Vector3(record.field_f(0x0C), record.field_f(0x10), record.field_f(0x14)), Vector3(record.field_f(0x1C), record.field_f(0x20), record.field_f(0x24)), Vector3(record.field_f(0x2C), record.field_f(0x30), record.field_f(0x34)))
		else:
			node.basis = island._placement_basis(record.field_f(0x4C), record.yaw, record.field_f(0x54))
		if driven:
			island.move_collider(index, node.position, record.yaw)
			_spin_wheels(index, record)
	_show_board()
	for item in services.items.values():
		if not bool(item.get("touched", false)):
			item.time = float(item.time) + 1.0


## The skateboard (record 9) is drawn where the engine put it while it is shown.
func _show_board() -> void:
	var node = nodes.get(BOARD_RECORD)
	if node == null:
		return
	var board: Record = records[BOARD_RECORD]
	node.visible = (board.flags & 2) != 0
	if not node.visible:
		return
	node.position = Vector3(board.x, board.y, -board.z)
	if board.matrix_valid:
		node.basis = island.rows_basis(Vector3(board.field_f(0x0C), board.field_f(0x10), board.field_f(0x14)), Vector3(board.field_f(0x1C), board.field_f(0x20), board.field_f(0x24)), Vector3(board.field_f(0x2C), board.field_f(0x30), board.field_f(0x34)))


func _skating() -> bool:
	return (Game.get_var(0x5E) & 0xFFF) == SKATE_SELECTOR


## While Pepper is on the board the engine owns his position, heading and tilt, and the camera.
func _skate_follow() -> void:
	var player: Record = records[player_record]
	island.player_pos = Vector3(player.x, player.y, -player.z)
	island.player_yaw = PI - player.yaw
	island.ride_tilted = player.matrix_valid
	if player.matrix_valid:
		island.ride_basis = island.rows_basis(Vector3(player.field_f(0x0C), player.field_f(0x10), player.field_f(0x14)), Vector3(player.field_f(0x1C), player.field_f(0x20), player.field_f(0x24)), Vector3(player.field_f(0x2C), player.field_f(0x30), player.field_f(0x34)))
	var look: Vector3 = services.camera_target - services.camera_eye
	if look.length() > 0.001:
		services.camera_forward = look.normalized()
		var flat := Vector3(look.z, 0.0, -look.x)
		if flat.length() > 0.001:
			services.camera_right = flat.normalized()


## The record of the machine Pepper rides, or -1.
func machine_record() -> int:
	var machine = services.talk.machine_actor
	var selector: int = Game.get_var(0x5E)
	return machine.index if machine != null and (selector == RIDE_SELECTOR or selector == HORSE_SELECTOR) else -1


func _riding() -> bool:
	return machine_record() >= 0


## FUN_00878C93: while riding, Pepper takes the machine's heading and sits at node 1 of its
## model. The first tick of a ride puts Pepper into the steering clip.
func _ride_follow() -> void:
	var machine: Record = services.talk.machine_actor
	var player: Record = records[player_record]
	if Game.get_var(0x5E) == HORSE_SELECTOR:
		# The horse's rider behaviour (HorseRider) has put Pepper on the horse and chosen his clip.
		ride_started = true
		island.player_pos = Vector3(player.x, player.y, -player.z)
		island.player_yaw = PI - player.yaw
		return
	if not ride_started:
		ride_started = true
		services.set_clip(player, STEER_CLIP, 0.0)
		services.camera_eye = island.camera_game_position()
	var seat := services.model_node_matrix(machine, SEAT_NODE)
	var point := services.actor_point(machine, Vector3(seat[12], seat[13], seat[14]))
	player.x = point.x
	player.y = point.y
	player.z = point.z
	player.yaw = machine.yaw
	island.player_pos = Vector3(point.x, point.y, -point.z)
	island.player_yaw = PI - player.yaw


## While nobody rides, the camera globals follow the island's own camera, so a ride starts
## from where the camera is.
func _follow_camera() -> void:
	ride_started = false
	var camera: Camera3D = island.camera
	if camera == null:
		return
	services.camera_eye = island.camera_game_position()
	var look: Vector3 = -camera.global_transform.basis.z
	services.camera_target = services.camera_eye + Vector3(look.x, look.y, -look.z) * 10.0
	var right: Vector3 = camera.global_transform.basis.x
	services.camera_right = Vector3(right.x, right.y, -right.z)


## Port decision (the exe has no step-off for a ridden machine, a cut scene releases it):
## the action key steps off. The machine stops and Pepper walks again beside it.
func dismount() -> void:
	var machine: Record = services.talk.machine_actor
	if machine == null:
		return
	var rider := machine.block.head
	while rider != null and not rider is RideMachine:
		rider = rider.next
	if rider == null:
		return
	rider.release()
	services.talk.machine_actor = null
	Game.set_var(0x5E, WALK_SELECTOR)
	services.set_clip(records[player_record], WALK_CLIP, 0.0)
	var side := services.actor_point(machine, Vector3(-4.0, 0.0, 0.0))
	island.player_pos = Vector3(side.x, island.player_pos.y, -side.z)
	ride_started = false


## The wheels of a driven machine turn with the distance it covered along its heading.
func _spin_wheels(index: int, record: Record) -> void:
	var here := Vector3(record.x, record.y, record.z)
	if ride_last.has(index) and island.wheel_sets.has(index):
		var step: Vector3 = here - ride_last[index]
		var forward := Vector3(record.field_f(0x2C), 0.0, record.field_f(0x34))
		island.wheel_sets[index].spin(Vector3(step.x, 0.0, step.z).length(), 1.0 if step.dot(forward) >= 0.0 else -1.0)
	ride_last[index] = here
