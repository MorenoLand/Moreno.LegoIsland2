class_name PulseScale
extends Behaviour

## FUN_004D4068 (ctor) / FUN_004D3D3F (update, vtable 0x008BA308), returns 1. A pickup that
## swells and shrinks: after 90 ticks it grows until 180, shrinks back until 360 with a
## sound, then clears (or raises) its var bits and starts over.
##
## Node: +0x18 timer, +0x1C scale.

const START_SCALE := 0.5
const GROW_SOUND := 0x5D49E54
const SHRINK_SOUND := 0x5D49E14

var timer := 0.0
var scale_now := START_SCALE

var services: ActorServices
var vars


static func from_descriptor(services_in: ActorServices, vars_in, actor) -> PulseScale:
	var b := PulseScale.new()
	b.services = services_in
	b.vars = vars_in
	b.timer = 0.0
	b.scale_now = START_SCALE
	b._place(actor)
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func _place(actor) -> void:
	services.set_actor_matrix(actor,
			Vector3(actor.field_f(0x4C), actor.field_f(0x50), actor.field_f(0x54)),
			Vector3(actor.x, actor.y, actor.z), Vector3(scale_now, scale_now, scale_now))


func update(actor, block: BehaviourBlock, _var_value: int) -> int:
	if status != block.frame_counter:
		scale_now = START_SCALE
		timer = 0.0
	timer = 1.0 * 1.0 + timer
	if 90.0 <= timer:
		if 180.0 <= timer:
			if timer < 360.0:
				scale_now = scale_now - 0.011110999621450901 * 1.0
				if scale_now < 0.5:
					scale_now = START_SCALE
					timer = 360.0
				services.sound_follow(SHRINK_SOUND, Vector3(actor.x, actor.y, actor.z))
				_place(actor)
			else:
				scale_now = START_SCALE
				timer = 0.0
				_place(actor)
				if mask == value:
					vars.clear_var(tag, mask)
				else:
					vars.or_var(tag, mask)
	else:
		scale_now = 0.01111110020428896 * 1.0 + scale_now
		_place(actor)
		services.sound_follow(GROW_SOUND, Vector3(actor.x, actor.y, actor.z))
	return 1
