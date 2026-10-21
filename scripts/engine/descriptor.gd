class_name Descriptor
extends RefCounted

## The shared scratch descriptor DAT_05D4A338 (0x5C bytes) the act builders fill
## through the FUN_0045Cxxx helpers and then hand to a behaviour constructor.
## Typed little-endian stores at BYTE offsets (the pseudocode indexes it as
## undefined2* / undefined4* depending on the function, converted when ported).

const SIZE := 0x5C

var data := PackedByteArray()


func _init() -> void:
	data.resize(SIZE)


func memset(count: int) -> void:
	for i in count:
		data[i] = 0
	refs.clear()


func set_u8(at: int, value: int) -> void:
	data[at] = value & 0xFF


func set_u16(at: int, value: int) -> void:
	data.encode_u16(at, value & 0xFFFF)


## A Record stored in a descriptor is kept as its address (base + index * 0x68) and
## remembered in `refs` so the behaviour can follow the pointer later.
const RECORD_BASE := 0x00975E44

var refs := {}


func set_u32(at: int, value) -> void:
	if value is Record:
		refs[at] = value
		data.encode_u32(at, (RECORD_BASE + value.index * Record.SIZE) & 0xFFFFFFFF)
	else:
		refs.erase(at)
		data.encode_u32(at, int(value) & 0xFFFFFFFF)


func set_f32(at: int, value: float) -> void:
	data.encode_float(at, value)


func u8(at: int) -> int:
	return data[at]


func u16(at: int) -> int:
	return data.decode_u16(at)


func s16(at: int) -> int:
	return data.decode_s16(at)


func u32(at: int) -> int:
	return data.decode_u32(at)


func s32(at: int) -> int:
	return data.decode_s32(at)


func f32(at: int) -> float:
	return data.decode_float(at)


func copy() -> Descriptor:
	var out := Descriptor.new()
	out.data = data.duplicate()
	out.refs = refs.duplicate()
	return out
