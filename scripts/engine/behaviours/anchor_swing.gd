class_name AnchorSwing
extends Behaviour

## FUN_00524990 (ctor) / FUN_005247B7 (update, vtable 0x008C5DF0, returns 1). The anchor of the
## dive swings back and forth in roll: the speed drops towards the ends of the 25 degree arc.
##
## Node: +0x18 current speed, +0x1C swing rate (starts at -0.43633).

const LIMIT := 0.43633

var speed := 0.0
var rate := -0.43633


static func from_descriptor() -> AnchorSwing:
	return AnchorSwing.new()


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func update(actor, _block: BehaviourBlock, _var_value: int) -> int:
	var roll: float = actor.field_f(0x54)
	var scale := (1.0 - absf(roll) / LIMIT) + 0.5
	if 1.0 < scale:
		scale = 1.0
	speed = rate * scale * scale * scale
	var next := speed * DiveWorld.dt + roll
	if 0.0 < rate:
		if LIMIT < next:
			rate = -rate
	elif next < -LIMIT:
		rate = -rate
	actor.set_field_f(0x4C, 0.0)
	actor.yaw = 0.0
	actor.set_field_f(0x54, next)
	return 1
