class_name Rattus
extends Behaviour

## FUN_004DC27A (ctor) / FUN_004DBD20 (update, vtable 0x008BAB10), slot 1 returns 1. A rat
## that wanders near its start spot, turning and idling in random bursts, and walks back when
## it strays more than 16 units away.
## State 0 walks slowly, 1 sits (clip 1), 2 walks fast; a new one is drawn each time the
## clip ends and the counter has run its course.
##
## Node: +0x14 / +0x18 / +0x1C start, +0x20 turn limit, +0x24 state, +0x28 turn timer,
## +0x2C counter, +0x30 turn rate.

const PI_F := 3.1415927410125732
const TAU_F := 6.2831854820251465
const TURN_STEP := 0.0872659981250763
const NEAR_START_SQUARED := 256.0
const FAST_SPEED := 0.1599999964237213
const SLOW_SPEED := 0.07999999821186066
const CLIP_WALK := 4
const CLIP_SIT := 1

var start := Vector3.ZERO
var turn_limit := 0.0
var state := 0
var turn_timer := 0.0
var counter := 0
var turn_rate := 0.0

var services: ActorServices


static func from_descriptor(services_in: ActorServices, actor) -> Rattus:
	var b := Rattus.new()
	b.services = services_in
	b.start = Vector3(actor.x, actor.y, actor.z)
	services_in.set_clip(actor, CLIP_WALK, 0.0)
	var length := services_in.anim_length(actor)
	services_in.anim_set_frame(actor, services_in.random_float(length - 2.0))
	b.counter = int(services_in.random_float(10.0))
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func update(actor, block: BehaviourBlock, _var_value: int) -> int:
	if services.clip_finished(actor, 1.0):
		counter += 1
		if state == 0 or state == 1 or state == 2:
			state = int(services.random_float(3.0))
			while state > 2:
				state = int(services.random_float(3.0))
			match state:
				0:
					counter = int(services.random_float(10.0))
					services.set_clip(actor, CLIP_WALK, 0.0)
				1:
					counter = 0
					services.set_clip(actor, CLIP_SIT, 0.0)
				2:
					counter = int(services.random_float(20.0))
					services.set_clip(actor, CLIP_WALK, 0.0)
	if state == 0 or state == 2:
		_walk(actor)
		services.request_hit(block, Vector3(0.0, 8.0, 0.0), Vector3(0.0, -16.0, 0.0), 3, 0x50)
	return 0


func _walk(actor) -> void:
	var to_start := start - Vector3(actor.x, actor.y, actor.z)
	if to_start.length_squared() <= NEAR_START_SQUARED:
		if turn_timer <= turn_limit:
			if turn_timer < 20.0:
				actor.yaw += turn_rate
		else:
			turn_rate = services.random_float(TURN_STEP) - TURN_STEP * 0.5
			turn_limit = services.random_float(50.0) + 20.0
			turn_timer = services.random_float(20.0)
		turn_timer += 1.0
	else:
		turn_limit = -1.0
		turn_timer = 0.0
		var heading := atan2(to_start.x, to_start.z)
		var off: float = actor.yaw - heading
		if -PI_F <= off:
			if PI_F < off:
				off -= TAU_F
		else:
			off += TAU_F
		if off <= TURN_STEP:
			if TURN_STEP <= off:
				actor.yaw = heading
			else:
				actor.yaw += TURN_STEP
		else:
			actor.yaw -= TURN_STEP
	services.set_rotation(actor, actor.field_f(0x4C), actor.yaw, actor.field_f(0x54))
	var rows := ActorServices.rotation_rows(actor.field_f(0x4C), actor.yaw, actor.field_f(0x54))
	var speed := SLOW_SPEED if state == 0 else FAST_SPEED
	actor.x += speed * rows[8]
	actor.y += speed * rows[9]
	actor.z += speed * rows[10]
