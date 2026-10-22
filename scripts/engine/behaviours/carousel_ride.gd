class_name CarouselRide
extends Behaviour

## FUN_006D1E58 (ctor) / FUN_006D0A1E (update, vtable 0x00900688, returns 1) with the hit test
## FUN_006D01B1. z36CNT carousel (Walk.c): the platform turns, the rider (record 19) sits on
## it, and the player taps left / right as the marked side passes the front. Good taps add to
## the score and the speed, a miss ends the combo; after sixty seconds the ride winds down and
## the score decides the medal. Keys: bit 1 left, bit 2 right, bit 0x40 start (edges of the
## held keys).
##
## State: 0 set up, 1 title (start key), 2 wait to start, 3 riding, 4 winding down, 5 finished
## (best score into game var 0x9B, medal into 0x86), 6 shown, 7 waiting for the rider clip.
##
## Node: +0xD4 rider record, +0xD8 slowest turn, +0xDC fastest turn, +0xE0 speed gain per good
## tap, +0xE4 hit window (times the fastest turn), +0xE8 time limit, +0xF0 time left, +0xF4
## perfect taps, +0xF8 state, +0xFC rider clip, +0x100 fast flag, +0x104 / +0x108 left / right
## taken, +0x10C bonus taken, +0x110 turn, +0x114 speed fraction, +0x11C combo, +0x120 combo
## reset, +0x124 previous tap, +0x128 tapped, +0x12C score, +0x130 on a side, +0x134 lock.

const RIDER := 19
## FUN_006CF530: the zone sound handles (global address).
const S_LOOP := 0x5D4E1DC
const S_BONUS := 0x5D4E1D4
const S_ICE := 0x5D4E214
const S_END_B := 0x5D4E1CC
const S_KEY := 0x5D4E1D8
const S_LOCK := 0x5D4E200
const S_GO := 0x5D4E20C
const S_END_A := 0x5D4E1E4
const S_TURN_A := 0x5D4E1F8
const S_TURN_B := 0x5D4E1F4
const S_MISS_L := 0x5D4E204
const S_TAP_L := 0x5D4E208
const S_MISS_R := 0x5D4E1FC
const S_TAP_R := 0x5D4E1D0
const TAU_F := 6.2831855
const PI_F := 3.1415927

var rider = null
var slowest := 0.052359596
var fastest := 0.26179925
var gain := 0.01
var window := 2.75
var limit := 1800.0
var time_left := 1800.0
var perfect := 0.0
var state := 0
var clip := 1
var fast := 0
var left_taken := 0
var right_taken := 0
var bonus := 0
var turn := 0.0
var speed := 0.0
var combo := 0
var combo_reset := 0
var previous_tap := 0
var tapped := 0
var score := 0
var on_side := 0
var lock := 0
var loop_flag := false

var services: ActorServices


static func from_descriptor(services_in: ActorServices) -> CarouselRide:
	var b := CarouselRide.new()
	b.services = services_in
	b.rider = services_in.record_at(RIDER)
	CarouselWorld.reset()
	b.state = 0
	b.clip = 1
	services_in.set_clip(b.rider, b.clip, 0.0)
	b.time_left = b.limit
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func _flag(index: int, on: bool) -> void:
	var record = services.record_at(index)
	if on:
		record.flags |= 2
	else:
		record.flags &= ~2


## FUN_006CF6B2: the two turning loops speed up with the turn.
func _pitch() -> void:
	services.sound_set_value(S_TURN_A, 0x3880 + int(0xFD94 * CarouselWorld.speed_fraction))
	services.sound_set_value(S_TURN_B, 0x204C + int(0x8BF8 * CarouselWorld.speed_fraction))


## FUN_006D01B1(keys): the tap windows.
func _taps(keys: int) -> void:
	var a := turn
	if a <= PI_F:
		if a < -PI_F:
			a += TAU_F
	else:
		a -= TAU_F
	var w := window * fastest
	if (keys & 3) != 0:
		services.sound_play(S_KEY)
	if PI_F < a:
		a -= TAU_F
	if lock == 0:
		if a < -w or w < a:
			if a <= w or PI_F - w <= a:
				if PI_F - w <= a or a <= -(PI_F - w):
					_flag(4, false)
					_flag(17, false)
					_flag(5, true)
					_flag(6, false)
					_flag(7, true)
					on_side = 1
					if (keys & 2) != 0 and right_taken == 0:
						right_taken = 1
						tapped = 1
						services.sound_play(S_TAP_R)
						speed += gain
						score += 20 + combo * 5
						if combo < 20:
							combo += 1
						if bonus != 0:
							perfect += 1.0
				elif a < -w and -(PI_F - w) < a:
					if on_side != 0:
						_flag(7, false)
						if tapped == 0:
							_flag(16, true)
							combo_reset = 1
							services.sound_play(S_MISS_L)
						else:
							_flag(6, true)
						if tapped != 0 and previous_tap != 0:
							speed += gain
						previous_tap = tapped
						tapped = 0
						on_side = 0
						right_taken = 0
					if (keys & 1) != 0:
						left_taken = 1
			else:
				if on_side != 0:
					_flag(4, false)
					if tapped == 0:
						_flag(17, true)
						combo_reset = 1
						services.sound_play(S_MISS_R)
					else:
						_flag(5, true)
					if tapped != 0 and previous_tap != 0:
						speed += gain
					previous_tap = tapped
					tapped = 0
					on_side = 0
					left_taken = 0
				if (keys & 2) != 0:
					right_taken = 1
		else:
			_flag(7, false)
			_flag(16, false)
			_flag(6, true)
			_flag(5, false)
			_flag(4, true)
			on_side = 1
			if (keys & 1) != 0 and left_taken == 0:
				left_taken = 1
				tapped = 1
				services.sound_play(S_TAP_L)
				speed += gain
				score += 20 + combo * 5
				if combo < 20:
					combo += 1
				if bonus != 0:
					perfect += 1.0
	else:
		services.sound_play(S_LOCK)
		if w < a:
			lock = 0
	if combo_reset != 0:
		combo = 0
		CarouselWorld.combo = 0
		combo_reset = 0
	time_left -= 1.0
	if time_left <= 0.0:
		time_left = 0.0
		state = 4
		CarouselWorld.set_rider_next(1)
		clip = 2
		services.set_clip(rider, clip, 0.0)
		combo = 0
		CarouselWorld.combo = 0
	if 0.75 < speed:
		fast = 1
		if 1.0 <= speed:
			speed = 1.0
			if bonus == 0:
				clip = 3
				services.set_clip(rider, clip, 0.0)
				bonus = 1
				score += 490
				if not CarouselWorld.spoke_bonus:
					CarouselWorld.say("LESGCE08")
					CarouselWorld.spoke_bonus = true


## The four quadrants of the turn light their own pair of pieces.
func _quadrants() -> void:
	if turn <= 0.0 or 1.5707964 <= turn:
		if turn <= 1.5707964 or PI_F <= turn:
			if turn <= PI_F or 4.712389 <= turn:
				if 4.712389 < turn and turn < TAU_F:
					_flag(10, false)
					_flag(14, true)
					_flag(15, false)
					_flag(11, true)
			else:
				_flag(9, false)
				_flag(13, true)
				_flag(14, false)
				_flag(10, true)
		else:
			_flag(8, false)
			_flag(12, true)
			_flag(13, false)
			_flag(9, true)
	else:
		_flag(11, false)
		_flag(15, true)
		_flag(12, false)
		_flag(8, true)


func update(actor, _block: BehaviourBlock, _var_value: int) -> int:
	var keys: int = services.talk.game_flags
	services.sound_play(S_LOOP)
	match state:
		0:
			CarouselWorld.combo = 0
			CarouselWorld.shown_score = 0
			CarouselWorld.gold = false
			state = 1
		1:
			if (keys & 0x40) != 0:
				state = 7
				clip = 15
				services.set_clip(rider, clip, 0.0)
				CarouselWorld.set_rider_next(1)
		2:
			if (keys & 0x40) != 0:
				state = 7
				clip = 14
				services.set_clip(rider, clip, 0.0)
				services.sound_play(S_GO)
		3:
			_taps(keys)
			turn += ((fastest - slowest) * speed + slowest) * 1.0
			if TAU_F <= turn:
				turn -= TAU_F
			CarouselWorld.speed_fraction = speed
			CarouselWorld.rider_chance = speed
			_pitch()
			services.sound_play(S_TURN_A)
			if turn < 0.5 or loop_flag:
				if turn < 0.5:
					loop_flag = false
			else:
				services.sound_play(S_TURN_B)
				loop_flag = true
		4:
			_pitch()
			services.sound_play(S_TURN_A)
			services.sound_play(S_TURN_B)
			if 1999 < score:
				CarouselWorld.gold = true
			speed -= 0.01
			for index in [5, 6]:
				_flag(index, true)
			for index in [4, 7, 17, 16]:
				_flag(index, false)
			var step := (fastest - slowest) * speed + slowest
			turn = step * 1.0 + turn
			if TAU_F < turn:
				turn -= TAU_F
			if speed <= 0.0:
				speed = 0.0
				if turn < step:
					turn = 0.0
					services.sound_play(S_END_A)
					if fast == 0:
						state = 5
					else:
						clip = 8
						services.set_clip(rider, clip, 0.0)
						state = 7
						services.sound_play(S_END_B)
		5, 6:
			if state == 5:
				services.sound_release(S_TURN_A)
				services.sound_release(S_TURN_B)
				CarouselWorld.shown_score = score
				state = 6
				if Game.get_var(0x9B) < CarouselWorld.shown_score:
					Game.set_var(0x9B, CarouselWorld.shown_score)
					if not CarouselWorld.gold:
						Game.set_var(0x86, 0)
					elif CarouselWorld.shown_score < 6000:
						Game.set_var(0x86, 1 if CarouselWorld.shown_score < 4000 else 2)
					else:
						Game.set_var(0x86, 3)
	if clip == 12:
		var frame := int(services.anim_frame(rider))
		if 26 < frame and frame < 29:
			services.sound_play(S_ICE)
	actor.set_field_f(0x4C, 0.0)
	actor.yaw = -turn
	actor.set_field_f(0x54, 0.0)
	_quadrants()
	CarouselWorld.timer = time_left
	CarouselWorld.hits = perfect
	if CarouselWorld.shown_score < score:
		CarouselWorld.shown_score += 17
		if score < CarouselWorld.shown_score:
			CarouselWorld.shown_score = score
	CarouselWorld.combo = combo
	CarouselWorld.speed_fraction = speed
	if clip == 2:
		services.anim_set_frame(rider, services.anim_length(rider) * speed)
	else:
		var finished := services.clip_finished(rider, 1.0)
		if not finished and clip == 15:
			var frame := int(services.anim_frame(rider))
			if 19 < frame and frame < 22:
				services.sound_play(S_BONUS)
				CarouselWorld.say("LESGCE09")
		if finished:
			match clip:
				8:
					clip = 1
					state = 5
				12:
					clip = 1
					state = 2
				14:
					clip = 2
					speed = 0.0
					combo_reset = 0
					tapped = 0
					previous_tap = 0
					on_side = 0
					time_left = limit
					state = 3
					CarouselWorld.set_rider_next(4)
				15:
					clip = 12
			services.set_clip(rider, clip, 0.0)
	return 1
