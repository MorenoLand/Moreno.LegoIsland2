class_name TeleportStep
extends Behaviour

## FUN_004D2C63 (ctor) / FUN_004D29D6 (update, vtable 0x008BA1A0). Ctor: node +0x14 and
## +0x18 from the descriptor, state byte 0, mask/value stored at +0x1C/+0x1E (the ctor
## overwrites the generic ones), starts clip 0x43. Update: while (var & mask2) == value2
## clear the placed flag and OR 0x40020000 into the tag; otherwise, once, move the actor
## to W_PATH node +0x18 (FUN_004478A9 table 1). Returns 1.

var arg_a := 0
var node_index := 0
var mask2 := 0
var value2 := 0
var placed := 0
var services: ActorServices
var vars


static func from_descriptor(desc: Descriptor, services_in: ActorServices, vars_in) -> TeleportStep:
	var b := TeleportStep.new()
	b.arg_a = desc.s32(0)
	b.node_index = desc.s32(4)
	b.services = services_in
	b.vars = vars_in
	return b


## The registration passes mask/value in; this ctor keeps them for itself (+0x1C/+0x1E)
## and leaves the generic mask/value at 0 so the dispatcher always runs it.
func configure(mask_in: int, value_in: int) -> void:
	mask2 = mask_in
	value2 = value_in
	mask = 0
	value = 0


func update(actor, _block, var_value: int) -> int:
	if (var_value & mask2) == value2:
		placed = 0
		vars.or_var(tag, 0x40020000)
		return 1
	elif placed == 0:
		var p = services.waypoint_position(1, node_index)
		if p != null:
			actor.x = p.x
			actor.y = p.y
			actor.z = p.z
		placed = 1
	return 0
