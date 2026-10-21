class_name NullStep
extends Behaviour

## FUN_004D2E09 (ctor) / FUN_004D2D60 (update, vtable 0x008BA2A0): a sound-handle holder; the
## update does nothing and returns 2. Ctor: sound handle from FUN_00429FB0(desc +0), its
## length, and the actor's position at registration.

var sound := 0
var origin := Vector3.ZERO


static func from_descriptor(desc: Descriptor, actor) -> NullStep:
	var b := NullStep.new()
	b.sound = desc.s32(0)
	if actor != null:
		b.origin = Vector3(actor.x, actor.y, actor.z)
	return b


func update(_actor, _block, _var_value: int) -> int:
	return 2
