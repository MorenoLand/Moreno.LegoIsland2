class_name OsdProgram
extends ZoneProgram

## z14OSD (the desert), loop FUN_00600520 and its set-up FUN_00601CEA: gems on var 0x1D, the
## tumbleweeds and scorpions the pyramid shares, the by-code flags of FUN_0060179F and the
## story builders FUN_00604D90 (state < 0x23) and FUN_00604410 (state < 0x2E). Pepper is
## record 4 and starts on the waypoint node 0x10 unless he arrives from zone 10.

const ALWAYS := [2, 1, 1]
const TUMBLEWEED_RECORDS := [104, 105, 106, 107, 108, 109, 111]
const SCORPION_RECORDS := [8, 9, 10, 11, 12, 13, 14, 15, 16, 17]
## FUN_006011E0: the sounds the zone creates (global address, sound id).
const SOUNDS := [
	[0x5D4DA9C, 0x300], [0x5D4DAA8, 0x2FF], [0x5D4DA98, 0x324], [0x5D4DA8C, 0x304], [0x5D4DAAC, 0x2F9],
	[0x5D4DAC8, 0x2FB], [0x5D4DAB8, 0x2FB], [0x5D4DABC, 0x2FB], [0x5D4DAC0, 0x2FB], [0x5D4DAC4, 0x2FB],
	[0x5D4DAB0, 0x2FB], [0x5D4DAB4, 0x2FB], [0x5D4DA94, 0x2FA], [0x5D4DA90, 0x308], [0x5D4DAA0, 0x2FE],
	[0x5D4DAA4, 0x2FD],
	[0x5D4DA6C, 0x2FC], [0x5D4DA64, 0x2FC], [0x5D4DA68, 0x2FC], [0x5D4DA78, 0x2FC], [0x5D4DA7C, 0x2FC],
	[0x5D4DA70, 0x2FC], [0x5D4DA74, 0x2FC], [0x5D4DA84, 0x2FC], [0x5D4DA88, 0x2FC], [0x5D4DA80, 0x2FC],
]


func _init() -> void:
	player_record = 4


func build(bridge) -> void:
	var services = bridge.services
	var records: Array = bridge.records
	services.talk.ground_min = 0.0
	var unit := BuilderUnit.new(bridge.vars, records.size())
	unit.records = records
	EngineSetup.register_ports(unit.ctx, services, bridge.vars)
	for row in SOUNDS:
		services.sound_define(int(row[0]), int(row[1]))
	_attach(unit, records)
	var state: int = Game.get_var(0x58)
	if state < 0x23:
		OsdBuilders.build_story_early(unit)
	elif state < 0x2E:
		OsdBuilders.build_story_late(unit)
	else:
		for index in [6, 5, 7, 63]:
			records[index].flags &= ~2
	records[64].flags &= ~2
	var island = bridge.island
	if Game.get_var(0xA3) != 10:
		var node: Vector3 = services.waypoint_position(1, 0x10) if services.waypoint_position(1, 0x10) != null else Vector3(records[4].x, records[4].y, records[4].z)
		var pepper: Record = records[player_record]
		pepper.x = node.x
		pepper.y = node.y
		pepper.z = node.z
		pepper.yaw = 1.5707899
		if island.player != null:
			island.player.position = Vector3(node.x, node.y, -node.z)
		island.start = node
		island.player_yaw = PI - pepper.yaw


## FUN_006013D6 / FUN_00601567 / FUN_0060179F: behaviours on fixed records and by record code.
func _attach(unit: BuilderUnit, records: Array) -> void:
	for index in TUMBLEWEED_RECORDS:
		unit.new_block(records[index])
		unit.reg(records[index], Ctor.TUMBLEWEED, unit.desc_param(0), 0, ALWAYS[0], ALWAYS[1], ALWAYS[2])
	for index in SCORPION_RECORDS:
		unit.new_block(records[index])
		unit.reg(records[index], Ctor.SCORPION, unit.desc_param(0), 0, ALWAYS[0], ALWAYS[1], ALWAYS[2])
	var bit := 1
	for record in records:
		var code := String(record.code)
		if code.begins_with("GEM"):
			unit.new_block(record)
			unit.reg(record, Ctor.GEM, unit.desc_param(0), 0, 0x1D, bit, 0)
			bit <<= 1
		elif code.begins_with("BL") or code.begins_with("BS"):
			record.flags |= 0x10
		elif code.begins_with("SH") or code.begins_with("SF"):
			record.flags &= ~2
	records[62].flags &= ~2
	records[112].flags |= 0x10
