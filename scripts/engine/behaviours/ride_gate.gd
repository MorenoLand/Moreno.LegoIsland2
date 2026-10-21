class_name RideGate
extends Behaviour

## FUN_008763DB (ctor) / FUN_00875E54 (update, vtable 0x00974B58, no post). Returns 0, 1 or
## 2. A ride platform node: while its +0x24 flag is clear it counts a timer (set by the
## ride code) and, when the timer first runs, drops the actor to the floor and hides it
## when the timer ends; with the flag set it only mirrors the var and holds (1) or lets
## the behaviours below run (2).
##
## Node: +0x14 / +0x18 / +0x1C descriptor words, +0x20 first word, +0x24 flag, +0x28 var
## copy, +0x2C / +0x2E shorts, +0x30 one, +0x34 timer, +0x38..+0x40 offset to apply.

var word_a := 0
var word_b := 0
var word_c := 0
var first := 0
var locked := 0
var var_copy := 0
var shift_pending := 0
var timer := 0.0
var offset := Vector3.ZERO

var services: ActorServices
var vars


static func from_descriptor(desc: Descriptor, services_in: ActorServices, vars_in) -> RideGate:
	var b := RideGate.new()
	b.services = services_in
	b.vars = vars_in
	b.first = desc.u32(0)
	b.word_a = desc.u32(4)
	b.word_b = desc.u32(8)
	b.word_c = desc.u32(12)
	b.locked = desc.u32(16)
	b.shift_pending = 0
	services_in.talk.ride_actor = null
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func update(actor, _block: BehaviourBlock, var_value: int) -> int:
	if locked == 0:
		if 0.0 < timer:
			if shift_pending != 0:
				shift_pending = 0
				actor.x += offset.x
				actor.y += offset.y
				actor.z += offset.z
				var start := Vector3(actor.x, actor.y + 8.0, actor.z)
				var hit = services.collide_sweep(actor, start, Vector3(0.0, -40.0, 0.0), 0x43, 1.0, 0.009999999776482582)
				if hit != null:
					actor.x = hit["position"].x
					actor.y = hit["position"].y
					actor.z = hit["position"].z
				services.set_rotation(actor, 1.5707963705062866, 0.0, 0.0)
			timer = timer - 1.0 * 1.0
			if timer <= 0.0:
				timer = 0.0
				actor.flags &= ~2
		return 0
	var_copy = var_value
	return 1 if var_copy == 1 else 2
