class_name WalkerSlot
extends RefCounted

## One of the 60 walker slots (DAT_05D40270, 0x84 bytes each). The bytes are kept as in
## the exe so the walker code can use the same offsets; pointers live beside them.
##   +0x00 flags       +0x04 graph       +0x08 actor (Record)   +0x0C 4 name bytes
##   +0x10 slot ahead  +0x14 follow target (Record)             +0x18 goal node (s16)
##   +0x1A to node     +0x1C after node  +0x1E from node        +0x20 lane offset
##   +0x24/+0x28/+0x2C list links (kept by the engine) +0x30..+0x38 goal position, +0x3C goal set
##   +0x40 turn limit  +0x44 speed       +0x48 slow speed       +0x4C accel
##   +0x50 brake       +0x54 turn rate   +0x58 heading after    +0x5C heading to
##   +0x60 target heading               +0x68 segment length^2  +0x6C reach
##   +0x70 lane shift  +0x74 slack       +0x78 follow gap^2     +0x7C goal gap^2
##   +0x80 speed scale

const SIZE := 0x84

var bytes := PackedByteArray()
var actor = null
var ahead: WalkerSlot = null
var follow = null


func _init() -> void:
	bytes.resize(SIZE)
	bytes.fill(0)


func clear() -> void:
	bytes.fill(0)
	actor = null
	ahead = null
	follow = null


var flags: int:
	get:
		return bytes.decode_u32(0)
	set(value):
		bytes.encode_u32(0, value & 0xFFFFFFFF)


var graph: int:
	get:
		return bytes.decode_s32(4)
	set(value):
		bytes.encode_s32(4, value)


func s16(offset: int) -> int:
	return bytes.decode_s16(offset)


func set_s16(offset: int, value: int) -> void:
	bytes.encode_s16(offset, value)


func u8(offset: int) -> int:
	return bytes.decode_u8(offset)


func set_u8(offset: int, value: int) -> void:
	bytes.encode_u8(offset, value & 0xFF)


func f(offset: int) -> float:
	return bytes.decode_float(offset)


func set_f(offset: int, value: float) -> void:
	bytes.encode_float(offset, value)


func u32(offset: int) -> int:
	return bytes.decode_u32(offset)


func set_u32(offset: int, value: int) -> void:
	bytes.encode_u32(offset, value & 0xFFFFFFFF)


func copy_from(other: WalkerSlot) -> void:
	bytes = other.bytes.duplicate()
	actor = other.actor
	ahead = other.ahead
	follow = other.follow
