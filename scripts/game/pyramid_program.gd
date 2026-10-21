class_name PyramidProgram
extends ZoneProgram

## z16PYA (the pyramid): FUN_0062FB9E, the zone set-up the loop FUN_0062EC00 runs, and the
## code FUN_0062FAC8 / FUN_0062F752 that attach behaviours to the records by their codes.
## Pepper is record 3; the records 14, 15 and 16 are hidden once the story has moved on.

const GEM_TAG := 0xDE
const GROUND_FLOOR := -400.0
const ALWAYS := [2, 1, 1]
## FUN_0062F570: the sounds the zone creates (global address, sound id).
const SOUNDS := [
	[0x5D4DAF4, 0x307], [0x5D4DAF0, 0x323], [0x5D4DAF8, 0x306], [0x5D4DAE4, 0x30B], [0x5D4DAE8, 0x30A],
	[0x5D4DAEC, 0x309], [0x5D4DA90, 0x308], [0x5D4DAA0, 0x2FE], [0x5D4DAA4, 0x2FD],
	[0x5D4DA6C, 0x2FC], [0x5D4DA64, 0x2FC], [0x5D4DA68, 0x2FC], [0x5D4DA78, 0x2FC], [0x5D4DA7C, 0x2FC],
	[0x5D4DA70, 0x2FC], [0x5D4DA74, 0x2FC], [0x5D4DA84, 0x2FC], [0x5D4DA88, 0x2FC], [0x5D4DA80, 0x2FC],
]


func _init() -> void:
	player_record = 3


func build(bridge) -> void:
	var services = bridge.services
	var records: Array = bridge.records
	services.talk.ground_min = GROUND_FLOOR
	var unit := BuilderUnit.new(bridge.vars, records.size())
	unit.records = records
	EngineSetup.register_ports(unit.ctx, services, bridge.vars)
	for row in SOUNDS:
		services.sound_define(int(row[0]), int(row[1]))
	_gems(unit, records)
	_by_code(unit, records)
	_story(unit, bridge)


## FUN_0062FAC8: every GEM record gets a gem behaviour on game var 0xDE with its own bit.
func _gems(unit: BuilderUnit, records: Array) -> void:
	var bit := 1
	for record in records:
		if String(record.code).begins_with("GEM"):
			unit.new_block(record)
			unit.reg(record, Ctor.GEM, unit.desc_param(0), 0, GEM_TAG, bit, 0)
			bit <<= 1


## FUN_0062F752: behaviours by record code. TUM and SCR followed by a digit get their
## behaviour on the always-run var; BL and BS records are marked 0x10; the collision shape
## calls for PM*, RK* and JAK (FUN_00429850 / FUN_00429780) are OPEN (the port uses the node
## bounds for collisions).
func _by_code(unit: BuilderUnit, records: Array) -> void:
	for record in records:
		var code := String(record.code)
		if code.length() < 4:
			continue
		var digit := code.unicode_at(3)
		var is_digit := digit > 47 and digit < 58
		if code.begins_with("TUM") and is_digit:
			unit.new_block(record)
			unit.reg(record, Ctor.TUMBLEWEED, unit.desc_param(0), 0, ALWAYS[0], ALWAYS[1], ALWAYS[2])
		elif code.begins_with("SCR") and is_digit:
			unit.new_block(record)
			unit.reg(record, Ctor.SCORPION, unit.desc_param(0), 0, ALWAYS[0], ALWAYS[1], ALWAYS[2])
		elif code.begins_with("BL") or code.begins_with("BS"):
			record.flags |= 0x10


## FUN_0062FB9E: the set-up for the story state (var 0x58): below 0x25 / 0x27 / 0x29 each has
## its own builder (talk nodes, the guides, Pepper's start node); later states hide the
## records 14, 15 and 16. Record 17 starts hidden.
func _story(unit: BuilderUnit, bridge) -> void:
	var records: Array = bridge.records
	var state: int = Game.get_var(0x58)
	if state < 0x25:
		PyramidBuilders.build_story_early(unit)
	elif state < 0x27:
		PyramidBuilders.build_story_middle(unit)
	elif state < 0x29:
		PyramidBuilders.build_story_late(unit)
	else:
		for index in [15, 14, 16]:
			records[index].flags &= ~2
	records[17].flags &= ~2
	bridge.services.shared["hint_record"] = 17
	var pepper: Record = records[player_record]
	var island = bridge.island
	if island.player != null:
		island.player.position = Vector3(pepper.x, pepper.y, -pepper.z)
	island.start = Vector3(pepper.x, pepper.y, pepper.z)
	island.player_yaw = pepper.yaw
