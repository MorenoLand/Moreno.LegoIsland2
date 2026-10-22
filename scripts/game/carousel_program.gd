class_name CarouselProgram
extends ZoneProgram

## z36CNT, loop FUN_006CEE17: the zone set-up FUN_006CFADD -> FUN_006CF970 puts the carousel
## behaviour on record 18 and the rider's clip chooser on record 0, hides records 1, 2 and 18, and
## fixes the camera on the carousel. The player has no controller here: the keys are the game.

## FUN_006CF530: the sounds the zone creates (global address, sound id).
const SOUNDS := [
	[0x5D4E1DC, 0xCA], [0x5D4E1D4, 0xCB], [0x5D4E214, 0xCC], [0x5D4E1CC, 0xCD], [0x5D4E1D8, 0xCE],
	[0x5D4E200, 0xCF], [0x5D4E20C, 0xD0], [0x5D4E1E4, 0xD1], [0x5D4E1F8, 0xD2], [0x5D4E1F4, 0xD3],
	[0x5D4E204, 0xD4], [0x5D4E208, 0xD5], [0x5D4E1FC, 0xD6], [0x5D4E1D0, 0xD7], [0x5D4E210, 0xD8],
	[0x5D4E1F0, 0xD9], [0x5D4E1EC, 0xDA], [0x5D4E1E8, 0xDB], [0x5D4E1E0, 0xDC],
]

var eye := Vector3.ZERO
var target := Vector3.ZERO


func _init() -> void:
	player_record = 0
	drives_player = true


func camera_pose() -> Dictionary:
	return {"eye": eye, "target": target}


func build(bridge) -> void:
	var services = bridge.services
	var records: Array = bridge.records
	services.talk.ground_min = -1.0e30
	var unit := BuilderUnit.new(bridge.vars, records.size())
	unit.records = records
	EngineSetup.register_ports(unit.ctx, services, bridge.vars)
	for row in SOUNDS:
		services.sound_define(int(row[0]), int(row[1]))
	CarouselWorld.reset()
	CarouselWorld.services = services
	CarouselWorld.speech = services.load_lines("_data/messages/LI/English/cnt.str")
	unit.new_block(records[18])
	unit.reg(records[18], Ctor.CAROUSEL_RIDE, unit.desc_param(0), 0, 2, 1, 1)
	unit.new_block(records[0])
	unit.reg(records[0], Ctor.RIDER_CLIPS, unit.desc_param(0), 0, 2, 1, 1)
	records[2].flags = 0
	records[18].flags = 0
	records[1].flags = 0
	var carousel: Record = records[18]
	target = Vector3(carousel.x, carousel.y + 3.9, carousel.z)
	eye = Vector3(carousel.x, target.y + 15.0, target.z + 30.0)
	var rider: Record = records[0]
	var island = bridge.island
	if island.player != null:
		island.player.position = Vector3(rider.x, rider.y, -rider.z)
	island.start = Vector3(rider.x, rider.y, rider.z)
	island.player_yaw = PI - rider.yaw
