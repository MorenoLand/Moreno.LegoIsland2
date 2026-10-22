class_name PageSpinner
extends Behaviour

## FUN_00525A75 (ctor) / FUN_00525966 (update, vtable 0x008C5E90, returns 1). The collectible
## page of the dive: it turns about the vertical axis at 110 degrees a second on the spot z = 10.


static func from_descriptor() -> PageSpinner:
	return PageSpinner.new()


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func update(actor, _block: BehaviourBlock, _var_value: int) -> int:
	actor.yaw = DiveWorld.wrap_angle(DiveWorld.dt * 1.9198519 + actor.yaw)
	actor.set_field_f(0x4C, 0.0)
	actor.set_field_f(0x54, 0.0)
	actor.z = 10.0
	return 1
