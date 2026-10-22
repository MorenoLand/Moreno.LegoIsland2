class_name DiveCannon
extends Behaviour

## FUN_00523253 (ctor) / FUN_00522EAF (update, vtable 0x008C5CA0, returns 1). The cannon of the dive
## turns to face the swimmer while he is within 40 units and fires a ball from its pool every
## eight seconds.
##
## Node: +0x18 timer (starts at 1), +0x1C..+0x40 the pool of ten balls, +0x44 its size.

const RANGE_SQUARED := 1600.0
const MUZZLE_SPEED := 10.0
const MUZZLE_OFFSET := 5.0
const RELOAD := 8.0
const LEAST_AIM := 4.014236
const MOST_AIM := 5.497758

var timer := 1.0
var pool: Array = []

var services: ActorServices


static func from_descriptor(services_in: ActorServices) -> DiveCannon:
	var b := DiveCannon.new()
	b.services = services_in
	for index in DiveWorld.R_BALLS:
		b.pool.append(services_in.record_at(index))
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


## FUN_00522E40: a spent ball goes into the first free place.
func take_back(ball) -> void:
	for i in pool.size():
		if pool[i] == null:
			pool[i] = ball
			return


func update(actor, _block: BehaviourBlock, _var_value: int) -> int:
	var here := Vector3(actor.x, actor.y, actor.z)
	var swimmer = services.record_at(DiveWorld.R_SWIMMER)
	var to_swimmer := Vector3(swimmer.x, swimmer.y, swimmer.z) - here
	if to_swimmer.length_squared() < RANGE_SQUARED:
		var n := to_swimmer.normalized()
		var aim := -atan2(n.x, n.y)
		aim = DiveWorld.wrap_angle(aim + 0.087266)
		if MOST_AIM < aim:
			aim = MOST_AIM
		if aim < LEAST_AIM:
			aim = LEAST_AIM
		actor.set_field_f(0x4C, 0.0)
		actor.yaw = 0.0
		actor.set_field_f(0x54, aim + 1.5707964)
		var direction := Vector3(cos(aim + 1.5707964), sin(aim + 1.5707964), 0.0)
		var muzzle := Vector3(direction.x * MUZZLE_OFFSET + here.x, direction.y * MUZZLE_OFFSET + here.y, 10.0)
		timer -= DiveWorld.dt
		if timer <= 0.0:
			var slot := 0
			while slot < pool.size() and pool[slot] == null:
				slot += 1
			if slot != pool.size():
				var ball = pool[slot]
				var item = ball.block.head if ball.block != null else null
				while item != null:
					if item is CannonBall:
						item.launch(ball, muzzle, direction * MUZZLE_SPEED)
						break
					item = item.next
				services.sound_follow(0x5D4C844, here)
				pool[slot] = null
				timer = RELOAD
	return 1
