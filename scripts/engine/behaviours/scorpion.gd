class_name Scorpion
extends Behaviour

## FUN_00603935 (ctor) / FUN_00602D20 (update, vtable 0x008E7BD8), slot 1 returns 1. A scorpion
## that wanders near its start spot and turns on Pepper when he comes close.
## State: 1 wandering, 2 turning at a spot, 0x10 attacking (the claw clip), 0x11 attack over.
## When something hits it (the exe asks FUN_0087BA30 with radius 64) it goes to the attack
## state with clip 1 and a squeal; in the attack it faces Pepper in 10-degree steps and
## by the clip frame walks up, bites (var 0x5E |= 0x20) or backs off. While it wanders it
## leaves a ground-follow move request on its own block (probe from 12 above, 28 down).
##
## Node: +0x14 / +0x18 / +0x1C start, +0x20 timer, +0x24 state, +0x28 heading.

const PI_F := 3.1415927410125732
const TAU_F := 6.2831854820251465
const TURN_STEP := 0.174532
const NEAR_START_SQUARED := 576.0
const HIT_RADIUS := 64.0
const SOUND_HURT := 0x5D4DAA4
const SOUND_BITE_3D := 0x5D4DAA0
const SOUND_BITE := 0x5D4DA90
## First four letters of the record code -> its rustling sound (the exe lists SCR6 twice).
const RUSTLE := {
	"SCR0": 0x5D4DA6C, "SCR1": 0x5D4DA64, "SCR2": 0x5D4DA68, "SCR3": 0x5D4DA7C, "SCR5": 0x5D4DA70,
	"SCR6": 0x5D4DA74, "SCR7": 0x5D4DA84, "SCR8": 0x5D4DA88, "SCR9": 0x5D4DA80,
}

var start := Vector3.ZERO
var timer := 0.0
var state := 1
var heading := 0.0

var services: ActorServices
var vars


static func from_descriptor(services_in: ActorServices, vars_in, actor) -> Scorpion:
	var b := Scorpion.new()
	b.services = services_in
	b.vars = vars_in
	b.state = 1
	b.timer = services_in.random_float(3.0)
	b.start = Vector3(actor.x, actor.y, actor.z)
	services_in.set_clip(actor, 2, 0.0)
	services_in.model_set_field(actor, 0xFF, 1)
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


static func _wrap(a: float) -> float:
	if -PI_F <= a:
		if PI_F < a:
			a -= TAU_F
	else:
		a += TAU_F
	return a


func _forward(actor) -> Vector3:
	var m := ActorServices.rotation_rows(actor.field_f(0x4C), actor.field_f(0x50), actor.field_f(0x54))
	return Vector3(m[8], m[9], m[10])


func _face(actor) -> void:
	services.set_rotation(actor, actor.field_f(0x4C), actor.yaw + PI_F, 0.0)


func update(actor, block: BehaviourBlock, _var_value: int) -> int:
	var here := Vector3(actor.x, actor.y, actor.z)
	var done := false
	if (state & 0x10) == 0:
		var struck := services.hit_by_player(actor, HIT_RADIUS)
		if struck == 0 or struck == 4:
			done = services.clip_finished(actor, 1.0)
		else:
			state = 0x10
			services.sound_follow(SOUND_HURT, here)
			timer = 0.0
			services.set_clip(actor, 1, 0.0)
			done = false
	else:
		done = services.clip_finished(actor, 1.0)
	match state:
		1, 0x11:
			_wander(actor, block, done)
		0x10:
			if done:
				state = 0x11
				services.set_clip(actor, 2, 0.0)
				timer = -1.0
				_turn_spot(actor)
			else:
				_attack(actor)
		2:
			_turn_spot(actor)
	return 1


func _wander(actor, block: BehaviourBlock, done: bool) -> void:
	if (actor.flags & 1) != 0:
		var key: int = RUSTLE.get(String(actor.code).substr(0, 4), 0)
		if key != 0:
			services.sound_follow(key, Vector3(actor.x, actor.y, actor.z))
	if done:
		timer = timer - 1.0
		if timer < 0.0:
			state = 2
			timer = services.random_float(90.0) + 30.0
	var step := _forward(actor) * -0.2
	actor.x += step.x
	actor.y += step.y
	actor.z += step.z
	services.request_hit(block, Vector3(0.0, 12.0, 0.0), Vector3(0.0, -28.0, 0.0), 1, 0x110)


## Case 0x10 while the claw clip runs.
func _attack(actor) -> void:
	var player = services.player
	var frame := services.anim_frame(actor)
	var gap := Vector3(player.x - actor.x, player.y - actor.y, player.z - actor.z)
	var aim := 0.0
	if 15.0 <= frame:
		aim = heading
	else:
		aim = atan2(gap.x, gap.z)
		heading = aim
		aim = _wrap(aim)
	var off := _wrap(actor.yaw - aim)
	if TURN_STEP <= absf(off):
		if off <= 0.0:
			actor.yaw += TURN_STEP
		else:
			actor.yaw -= TURN_STEP
	else:
		actor.yaw = aim
	aim = _wrap(aim)
	_face(actor)
	if 15.0 <= frame:
		if 20.0 < frame:
			actor.x += sin(aim) * 0.2
			actor.z += cos(aim) * 0.2
	elif 6.0 < frame:
		if 12.0 < frame:
			if gap.length_squared() <= 4.0:
				services.sound_follow(SOUND_BITE_3D, Vector3(actor.x, actor.y, actor.z))
				services.sound_play(SOUND_BITE)
				vars.or_var(0x5E, 0x20)
				timer = -1.0
				heading = _wrap(heading + PI_F)
		var push := Vector3(sin(aim) * 0.8, 0.0, cos(aim) * 0.8)
		var close := gap.length_squared()
		if close <= 2.56:
			if close < 1.0:
				actor.x -= push.x
				actor.y -= push.y
				actor.z -= push.z
		else:
			actor.x += push.x
			actor.y += push.y
			actor.z += push.z


## Case 2 (and the end of the attack): count the timer down; at zero pick a new heading,
## drifting back toward the start spot when it has strayed 24 units, else facing Pepper.
func _turn_spot(actor) -> void:
	timer = timer - 1.0
	if timer >= 0.0:
		return
	timer = services.random_float(5.0)
	state = 1
	var home := Vector3(start.x - actor.x, start.y - actor.y, start.z - actor.z)
	if NEAR_START_SQUARED <= home.length_squared():
		var aim := _wrap(atan2(home.x, home.z))
		var off := _wrap(actor.yaw - aim)
		if off <= 0.0:
			actor.yaw = services.random_float(0.078539394) * 10.0 + actor.yaw
		else:
			actor.yaw = actor.yaw - services.random_float(0.078539394) * 10.0
	else:
		var player = services.player
		var gap := Vector3(player.x - actor.x, player.y - actor.y, player.z - actor.z)
		actor.yaw = _wrap(atan2(gap.x, gap.z) + PI_F)
		timer = 5.0
	_face(actor)


func has_post() -> bool:
	return false
