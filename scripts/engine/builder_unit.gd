class_name BuilderUnit
extends RefCounted

## What the generated act builders (act_builders_gen.gd, produced by tools/pc2gd.py) run
## against: the record array, the script context/helpers and the game variables.

var ctx: ScriptContext
var helpers: ScriptHelpers
var vars
var records: Array = []
var unported_calls: Array = []
var constants := {}


func _init(game_vars, record_count: int = 450) -> void:
	vars = game_vars
	ctx = ScriptContext.new()
	helpers = ScriptHelpers.new(ctx)
	for i in record_count:
		var record := Record.new()
		record.index = i
		records.append(record)
	if ResourceLoader.exists("res://data/constants.tsv"):
		for row in Table.rows("res://data/constants.tsv"):
			if row.size() >= 2 and String(row[0]).begins_with("0x"):
				constants[String(row[0]).hex_to_int()] = float(row[1])


## DAT_00975E44 + off: the record at that offset (aligned), else the record that
## contains it.
func pointer(off: int) -> Record:
	return records[clampi(off / Record.SIZE, 0, records.size() - 1)]


## One character of a record's four-letter code ('' past the end).
func char_at(index: int, position: int) -> String:
	var code := String(records[index].code)
	return code[position] if position < code.length() else ""


func to_int(value) -> int:
	return 1 if value else 0


func reg(record, ctor: int, desc, slot: int, tag: int, mask: int, value: int) -> void:
	var previous = ctx.actor
	if record != ctx.actor:
		ctx.actor = record
	ctx.register(ctor, desc, slot, tag, mask, value)
	ctx.actor = previous


func desc_param(value) -> Descriptor:
	var d := Descriptor.new()
	d.memset(Descriptor.SIZE)
	return d


func new_block(record) -> void:
	record.block = BehaviourBlock.new()


func block_flags(record, value: int) -> void:
	if record != null and record.block != null:
		record.block.set_flags(value)


func record_flags_and(off: int, mask: int) -> void:
	var record := pointer(off - 0x60)
	record.flags &= mask


func record_flags_or(off: int, mask: int) -> void:
	var record := pointer(off - 0x60)
	record.flags |= mask


func actor_flags_and(off: int, mask: int) -> void:
	if ctx.actor != null and off == 0x60:
		ctx.actor.flags &= mask


func rec_f(off: int) -> float:
	var base := off - (off % Record.SIZE)
	return pointer(base).field_f(off - base)


func rec_set_f(off: int, value: float) -> void:
	var base := off - (off % Record.SIZE)
	pointer(base).set_field_f(off - base, value)


func const_f(address: int) -> float:
	return float(constants.get(address, 0.0))


func float_bits(bits: int) -> float:
	var buffer := PackedByteArray()
	buffer.resize(4)
	buffer.encode_u32(0, bits & 0xFFFFFFFF)
	return buffer.decode_float(0)


## The 16-float copy of one record's matrix block (+0xC) onto another: position and angles.
func copy_matrix(to: Record, from: Record) -> void:
	for offset in [0x0c, 0x10, 0x14, 0x1c, 0x20, 0x24, 0x2c, 0x30, 0x34, 0x4c, 0x50, 0x54]:
		to.set_field_f(offset, from.field_f(offset))
	to.x = from.x
	to.y = from.y
	to.z = from.z


## FUN_00881A12(position, 16): the terrain height under a point.
func ground_height(position: Vector3) -> float:
	if ctx.services != null:
		var g: float = ctx.services.ground_height(position, 0.0)
		return g if g > -1.0e37 else position.y
	return position.y


## FUN_004478A9(table, node, record position): put the record on that waypoint node.
func place_at_waypoint(table: int, node: int, record) -> void:
	if record == null:
		return
	var at := waypoint(table, node)
	record.x = at.x
	record.y = at.y
	record.z = at.z


## FUN_004B8B05(slot, a, b, c): the three candidate entry / exit records of a zone slot.
var portals := {}


func portal_register(slot: int, a, b, c) -> void:
	portals[slot] = [a, b, c]


## FUN_004B8B40(slot, hide_others): var 0xBB picks which of the three is shown (the others are
## hidden when asked); returns the chosen record.
func portal_pick(slot: int, hide_others: int):
	var list: Array = portals.get(slot, [null, null, null])
	var chosen := clampi(int(vars.get_var(0xBB)), 0, 2)
	if hide_others != 0:
		for i in 3:
			if i != chosen and list[i] != null:
				list[i].flags &= ~2
	if list[chosen] != null:
		list[chosen].flags |= 2
	return list[chosen]


## FUN_004478A9(table, node, out): the position of a waypoint node (game coordinates).
func waypoint(table: int, node: int) -> Vector3:
	if ctx.services != null:
		var at = ctx.services.waypoint_position(table, node)
		if at != null:
			return at
	return Vector3.ZERO


## FUN_004221E4(matrix of a record, rx, ry, rz, x, y, z): put the record there with those angles.
func set_matrix(record, rx: float, ry: float, rz: float, position: Vector3) -> void:
	record.set_field_f(0x4C, rx)
	record.yaw = ry
	record.set_field_f(0x54, rz)
	record.x = position.x
	record.y = position.y
	record.z = position.z


## FUN_0087B720(path): the zone's talk lines ("KEY:ID text" file).
func load_speech_table(path: String) -> void:
	if ctx.services != null:
		ctx.services.talk.speech_table = ctx.services.load_lines(path)


## FUN_0087DC90(path): the zone's guide (hologram) lines.
func load_hold_table(path: String) -> void:
	if ctx.services != null:
		ctx.services.talk.helper_table = ctx.services.load_lines(path)


## FUN_0087B9B0(record, range): the actor the talk prompt follows (range as float bits).
func set_talk_target(record, range_bits) -> void:
	if ctx.services != null:
		ctx.services.talk.set_target_actor(_record_of(record), float_bits(int(range_bits)) if range_bits is int else float(range_bits))


## FUN_004232A3(record, clip, start): start an animation clip on the actor.
func set_clip(record, clip: int, start: float) -> void:
	if ctx.services != null and record != null:
		ctx.services.set_clip(record, clip, start)


## FUN_004220A1: rebuild the matrix rotation of a record from its angles (the port keeps angles only).
func set_rotation(_matrix, _rx, _ry, _rz) -> void:
	pass


## FUN_00425A00(anim, node) != null: the record's model has that animation node.
func has_node(record, node: int) -> bool:
	return ctx.services != null and record != null and node < ctx.services.model_node_count(record)


## node matrix [12 + axis] = value: move an animation node of the record's model.
func set_node_translation(record, node: int, axis: int, value: float) -> void:
	if ctx.services != null and record != null:
		ctx.services.set_node_translation(record, node, axis, value)


## FUN_00440CC4(list, name, var): the cut-scene switch `name` is game var `var`.
func register_switch(name: String, var_id: int) -> void:
	if ctx.services != null:
		ctx.services.switches[name] = var_id


## The exe's file-scope globals the builders store (DAT_...): kept by address; the ones the
## port reads have named homes.
var globals := {}


func write_global(address: int, value) -> void:
	if ctx.services != null and address == 0x05DE1CA0:
		ctx.services.talk.ground_min = float(value)
	if ctx.services != null and address == 0x05DE1E80:
		ctx.services.talk.machine_actor = value if value is Record else null
	globals[address] = value


func read_global(address: int):
	return globals.get(address, 0)


## FUN_00440BF0(size): a table of size + 1 entries, each a value 0 and an owner 0xFFFF.
func slot_table(size: int) -> Array:
	var table := []
	for i in size + 1:
		table.append([0, 0xFFFF])
	return table


func call_unported(address: int, args: Array) -> void:
	if ctx.services != null:
		match address:
			0x0087B720:
				ctx.services.talk.speech_table = ctx.services.load_lines(String(args[0]))
				return
			0x0087DC90:
				ctx.services.talk.helper_table = ctx.services.load_lines(String(args[0]))
				return
			0x0087B9B0:
				ctx.services.talk.set_target_actor(_record_of(args[0]), float_bits(int(args[1])))
				return
			0x0087B7BF:
				ctx.services.talk.add_group(_record_of(args[0]), _record_of(args[1]), _record_of(args[2]))
				return
			0x00421F40:
				# FUN_00421F40(matrix of a record, 0, yaw): the record's matrix from its angles.
				if args[0] is Record:
					ctx.services.init_matrix(args[0])
				return
			0x0042B2C0:
				ctx.services.model_set_flag(_record_of(args[0]), int(args[1]))
				return
			0x00520540:
				DiveWorld.register_group(args[0], int(args[1]), String(args[2]))
				return
			0x004B9290:
				helpers.defeat(int(args[0]))
				return
	unported_calls.append([address, args])


## A pointer argument of a plain call: a Record, or null for a zero.
func _record_of(value):
	if value is int and value == 0:
		return null
	return value


func float_to_bits(value: float) -> int:
	var buffer := PackedByteArray()
	buffer.resize(4)
	buffer.encode_float(0, value)
	return buffer.decode_u32(0)
