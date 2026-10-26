class_name DiveProgram
extends ZoneProgram

## z08BKD (the dive), loop FUN_0051E218: the zone set-up FUN_0052018D -> FUN_0051F400 (generated
## as DiveBuilders.build_setup) attaches the swimmer, the camera, the fish groups and the
## creatures; Pepper is record 5 and starts at the position the swimmer's constructor sets.


func _init() -> void:
	player_record = 5
	drives_player = true


func pre_tick() -> void:
	DiveWorld.tick_clock()
	DiveWorld.update_groups()


func tick() -> void:
	DiveWorld.play_animals()
	DiveWorld.tick_hud()
	var hud = _bridge.island.hud
	if hud != null:
		hud.dive_tick(DiveWorld.gauge, DiveWorld.bricks_taken, DiveWorld.delivered)


func camera_pose() -> Dictionary:
	return {"eye": DiveCamera.eye, "target": DiveCamera.target}


var _bridge


func build(bridge) -> void:
	_bridge = bridge
	var services = bridge.services
	var records: Array = bridge.records
	services.talk.ground_min = -1.0e30
	var unit := BuilderUnit.new(bridge.vars, records.size())
	unit.records = records
	EngineSetup.register_ports(unit.ctx, services, bridge.vars)
	# FUN_00884370(1, W_OTH): the dive's waypoint table 1 is the zone's w_oth file (table 3 here).
	var other = services.graphs.get(3)
	if other != null:
		services.set_graph(1, other)
		services.shared["dive_graph"] = DiveGraph.from_waypoints(other)
	ActorServices.assign_colliders(bridge.island.zone, records)
	DiveWorld.reset(services, services.shared.get("dive_graph"))
	DiveWorld.speech = services.load_lines("_data/messages/CI/English/bkd.str")
	for row in DiveWorld.SOUNDS:
		services.sound_define(int(row[0]), int(row[1]))
	DiveBuilders.build_setup(unit, 1)
	DiveWorld.start_over()
	var pepper: Record = records[player_record]
	var island = bridge.island
	if island.player != null:
		island.player.position = Vector3(pepper.x, pepper.y, -pepper.z)
	island.start = Vector3(pepper.x, pepper.y, pepper.z)
	island.player_yaw = PI - pepper.yaw
