class_name Record
extends RefCounted

## One entry of the island record array (DAT_00975E44, 0x68 bytes each). Only the fields
## the engine layer touches are modelled: position +0x3C/+0x40/+0x44 (game coordinates),
## yaw +0x50, flags +0x60 (bit 1 visible), behaviour block +0x5C.

const SIZE := 0x68
const FLAG_VISIBLE := 2

var index := 0
var code := ""
var x := 0.0
var y := 0.0
var z := 0.0
var yaw := 0.0
var flags := 0
var block: BehaviourBlock = null
## Godot-side node (the MeshInstance3D standing for this record), if any.
var node: Node3D = null
var floats := {}
## True once the 3x3 matrix cells (+0xC .. +0x34 in `floats`) hold the matrix to draw with.
var matrix_valid := false
## The record's polygon collision file (its model's .col), for the zones that test records
## against each other through RecordCollision.
var col: ColFile = null


func field_f(offset: int) -> float:
	match offset:
		0x3C:
			return x
		0x40:
			return y
		0x44:
			return z
		0x50:
			return yaw
	return float(floats.get(offset, 0.0))


func set_field_f(offset: int, value: float) -> void:
	match offset:
		0x3C:
			x = value
		0x40:
			y = value
		0x44:
			z = value
		0x50:
			yaw = value
		_:
			floats[offset] = value


func visible() -> bool:
	return (flags & FLAG_VISIBLE) != 0
