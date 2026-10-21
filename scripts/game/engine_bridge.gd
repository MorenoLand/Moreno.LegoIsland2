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
	if program != null:
		program.build(self)
	else:
		services.talk.ground_min = island.SEA_LEVEL
		_build_act()
		_setup_effects()
		_setup_talk()
	if Game.get_var(0x5E) == 0:
		Game.set_var(0x5E, 1)
	if records[player_record].block == null:
		records[player_record].block = BehaviourBlock.new()
	ready = true


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
	# island.player_pos and player_yaw are in the scene's axes (z mirrored); the records use the game's.
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
	system.tick(records, player, vars)
	services.resolve_hits(records)
	system.post_pass(records)
	services.frame_counter = system.frame
	if program == null:
		events.tick()
	else:
		program.tick()
	services.particle_tick()
	for index in nodes:
		var record: Record = records[index]
		if record.block == null or index == player_record or _legacy(index):
			continue
		var node: MeshInstance3D = nodes[index]
		node.visible = (record.flags & 2) != 0
		node.position = Vector3(record.x, record.y, -record.z)
		node.basis = island._placement_basis(record.field_f(0x4C), record.yaw, record.field_f(0x54))
	for item in services.items.values():
		if not bool(item.get("touched", false)):
			item.time = float(item.time) + 1.0
