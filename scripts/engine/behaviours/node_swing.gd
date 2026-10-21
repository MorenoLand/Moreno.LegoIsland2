class_name NodeSwing
extends Behaviour

## FUN_004D0B35 (ctor) / FUN_004D08E6 (update, vtable 0x008B9F58), returns 0.
## Swings one sub-node of the actor's model back and forth between two angles. The
## descriptor holds the speed (@0), the two limits (@8, @12, stored negated), the node
## index (@4) and the axis flags (@16: 0x20 = y, 0x40 = z, otherwise x).
## If the model has no such node the behaviour re-tags itself to var 1 (ctor `*node = 1`).

const TAU_F := 6.2831854820251465
const STEP := 1.0

var forced_tag := -1
var node_index := 0
var axis_flags := 0
var limit_low := 0.0
var speed := 0.0
var limit_high := 0.0
var angle := 0.0
var state := 0

var services: ActorServices


static func from_descriptor(desc: Descriptor, services_in: ActorServices, actor) -> NodeSwing:
	var b := NodeSwing.new()
	b.services = services_in
	b.node_index = desc.u32(4)
	if b.node_index < services_in.model_node_count(actor):
		b.limit_low = -desc.f32(12)
		b.limit_high = -desc.f32(8)
		b.speed = -desc.f32(0)
		if 0.0 <= b.speed or b.limit_high <= b.limit_low:
			if 0.0 < b.speed and b.limit_high < b.limit_low:
				b.limit_high += TAU_F
		else:
			b.limit_high -= TAU_F
		b.angle = b.limit_low
		services_in.set_node_rotation(actor, b.node_index, 0.0, b.angle, 0.0)
		b.axis_flags = desc.u16(16)
	else:
		b.forced_tag = 1
	b.state = 0
	return b


## FUN_004CFF8C: clamp `angle` to `limit` once it has run past it and return `result`.
func _clamp(moving: float, limit: float, result: int) -> int:
	if 0.0 <= moving:
		if limit < angle:
			angle = limit
			return result
	elif angle < limit:
		angle = limit
		return result
	return -1


func update(actor, _block: BehaviourBlock, _var_value: int) -> int:
	var next_state := -1
	match state:
		0, 1:
			state = 1
			angle = speed * STEP + angle
			next_state = _clamp(speed, limit_high, 2)
		2, 3:
			state = 3
			angle = angle - speed * STEP
			next_state = _clamp(-speed, limit_low, 0)
		_:
			return 0
	if next_state != -1:
		state = next_state
	if (axis_flags & 0x20) != 0:
		services.set_node_rotation(actor, node_index, 0.0, angle, 0.0)
	elif (axis_flags & 0x40) != 0:
		services.set_node_rotation(actor, node_index, 0.0, 0.0, angle)
	else:
		services.set_node_rotation(actor, node_index, angle, 0.0, 0.0)
	return 0
