class_name CastleProgram
extends ZoneProgram

## z07CSI (the castle), loop FUN_004D87C0: the set-up FUN_004D93D7 (generated as
## CastleBuilders.build_setup) wires every record; Pepper is record 7, placed by the story
## builders on the waypoint node that suits the story state.

## FUN_004D8DA0: the sounds the zone creates (global address, sound id).
const SOUNDS := [
	[0x5D4A448, 0x273], [0x5D4A444, 0x274], [0x5D4A44C, 0x275], [0x5D4A40C, 0x29B], [0x5D4A434, 0x287],
	[0x5D4A438, 0x289], [0x5D4A3F0, 0x29D], [0x5D4A440, 0x277], [0x5D4A43C, 0x29C], [0x5D4A498, 0x278],
	[0x5D4A400, 0x279], [0x5D4A408, 0x276], [0x5D4A418, 0x2CC], [0x5D4A41C, 0x2CD], [0x5D4A420, 0x2CE],
	[0x5D4A424, 0x2CF], [0x5D4A3E8, 0x2E2], [0x5D4A3EC, 0x2E2], [0x5D4A3FC, 0x365], [0x5D4A404, 0x366],
	[0x5D4A450, 0x367], [0x5D4A42C, 0x36A], [0x5D4A3F4, 0x369], [0x5D4A428, 0x36B], [0x5D4A410, 0x36C],
	[0x5D4A454, 0x368], [0x5D4A430, 0x379], [0x5D4A414, 0x2F0], [0x5D4A458, 0x37A],
]


## FUN_0041B4E0: the eye 6.4 up and 16 behind the rig, looking at 3 above it.
const CAMERA_BEHIND := Vector3(0.0, 6.4, -16.0)
const CAMERA_RISE := 3.0
var _bridge


func _init() -> void:
	player_record = 7


func build(bridge) -> void:
	var services = bridge.services
	var records: Array = bridge.records
	services.talk.ground_min = 0.0
	var unit := BuilderUnit.new(bridge.vars, records.size())
	unit.records = records
	EngineSetup.register_ports(unit.ctx, services, bridge.vars)
	for row in SOUNDS:
		services.sound_define(int(row[0]), int(row[1]))
	_bridge = bridge
	CastleBuilders.build_setup(unit)
	var pepper: Record = records[player_record]
	services.camera_rig = pepper
	services.camera_eye = services.actor_point(pepper, CAMERA_BEHIND)
	services.camera_target = Vector3(pepper.x, pepper.y + CAMERA_RISE, pepper.z)
	var island = bridge.island
	if island.player != null:
		island.player.position = Vector3(pepper.x, pepper.y, -pepper.z)
	island.start = Vector3(pepper.x, pepper.y, pepper.z)
	island.player_yaw = PI - pepper.yaw


## FUN_0041B4E0 (setting 0) after the set-up: the camera starts behind the rig, which is
## Pepper's record, and from then on the boat (BoatDrive) moves it.
func camera_pose() -> Dictionary:
	var services = _bridge.services
	if services.camera_eye == Vector3.ZERO:
		return {}
	return {"eye": services.camera_eye, "target": services.camera_target}
