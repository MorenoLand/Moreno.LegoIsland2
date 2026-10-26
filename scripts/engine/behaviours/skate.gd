class_name Skate
extends Behaviour

## The skateboard: constructor FUN_007ECF4D (FUN_00878C2C wraps it, vtable 0x00942A40), update
## FUN_007EB09D, post FUN_007ECB5D. It runs while the input selector (var 0x5E) has bit 4 set
## and owns Pepper: input (FUN_007EAF41 / FUN_007EAD63), the mode machine (FUN_007EA341 before
## the move, FUN_007E98D2 after it), ground following (FUN_007E83F0), the air tricks
## (FUN_007E8A80) and the chase camera. Var 0x59 (the zone being played) is 1 in the park; the
## island and the castle take the other branches.
##
## The mode is the Pepper clip that plays: 0x16 getting on, 0x0E / 0x19 / 0x27 / 0x28 / 0x29 /
## 0x2A / 0x2B / 0x2D the rolling and trick poses, 0x20 in the air, 0x21 landing, 0x23 and 0x32
## the crash poses. The board is record 9 and has clips of its own (1 on, 2 off, 3 and 4 ride).
##
## Fields keep the offsets of the original object in their comments.

const MODE_MOUNT := 0x16
const MODE_AIR := 0x20
const MODE_LAND := 0x21
const MODE_CRASH := 0x23
const MODE_ROLL := 0x29
const MODE_CHARGE_A := 0x2A
const MODE_CHARGE := 0x2B
const MODE_RECOVER := 0x2D
const MODE_FALL := 0x32
const CLIP_DISMOUNT := 0x1C
const CLIP_TIPPED := 0x37
const BOARD_RECORD := 9
const BOARD_CLIP_ON := 1
const BOARD_CLIP_OFF := 2
const BOARD_CLIP_RIDE := 3
const BOARD_CLIP_STEER := 4
const PARK_ZONE := 1
const ZONE_VAR := 0x59
const KIND_PIPE := 0x50495051
const KIND_LAND := 0x444E414C
const FRAME := 1.0
const SPEED_CAP := 0.75
const SPEED_STEP := 0.1
const BRAKE_STEP := 0.2
const TURN_RATE := 0.00075
const WALL_TURN := 0.19634955
## DAT_00942A30 / DAT_00942A34 / DAT_00942A38: the island's sweep radius, tolerance and jump speed.
const SWEEP_RADIUS := 1.4
const SWEEP_TOLERANCE := 0.2
const AIR_LAUNCH := 15.0
const PARK_LAUNCH := 20.0
const PARK_FALL := 30.0
## DAT_00942A58: the stick curve (counter 0..32 to 0..255).
const CURVE := [0, 8, 16, 24, 32, 40, 48, 56, 64, 72, 80, 88, 96, 104, 112, 120, 128, 136, 144, 152, 160, 168, 176, 184, 192, 200, 208, 216, 224, 232, 240, 248, 255]
## The rolling sound of each surface kind (DAT_05D50E9C ...), FUN_007EA13B.
const ROLL_SOUNDS := {0: 0x5D50E9C, 1: 0x5D50E8C, 3: 0x5D50E84, 4: 0x5D50E90, 6: 0x5D50EA4, 7: 0x5D50E88, 8: 0x5D50E8C, 9: 0x5D50E98, 10: 0x5D50E94}
const ROLL_MODES := [0x0E, 0x19, 0x27, 0x28, 0x29, 0x2A, 0x2B, 0x2D]
## The landing sound of each surface kind (FUN_007E98D2).
const LAND_SOUNDS := {0: 0x5D50EA0, 1: 0x5D50EB8, 3: 0x5D50EAC, 4: 0x5D50EBC, 6: 0x5D50EB0, 7: 0x5D50EA8, 8: 0x5D50EB8}
const SOUND_TRICK := 0x5D49EBC
const SOUND_LAUNCH_AT := 0x5D50DF4
const SOUND_FALL_AT := 0x5D50E68
const SOUND_CRASH_AT := 0x5D50E2C
const SOUND_LAND_A := 0x5D50DE8
const SOUND_LAND_B := 0x5D50E34
## The tricks whose bar drains (clips 0x68, 10, 0x11, 0x0F, 0x52, 0x54, 0x5C, 0x60, 0x6C).
const DRAIN_TRICKS := [0x68, 10, 0x11, 0x0F, 0x52, 0x54, 0x5C, 0x60, 0x6C]
## Stick dead zones of FUN_007E8A80: a trick is picked past +-0x1E and held while the stick
## stays past -0x1F / 0x1F (the exe's own asymmetric tests).
const PICK := 0x1E
const HOLD_LOW := -0x1F
const HOLD_HIGH := 0x1F
const HOLD_BAND := 0x1D
## Unset stack floats read as 0xCCCCCCCC.
const UNSET := -1.0737418e+08
const NO_GROUND := -8000.0
const PARK_FLOOR := 0.6478999853134155

## +0x18: the mode.
var mode := MODE_MOUNT
## +0x19: the landing was scored. +0x1A: on the ground. +0x1B: on a pipe. +0x1C: the bar was
## filling. +0x1D: toggles in the recover pose. +0x1E: held (pipe).
var scored := false
var grounded := true
var on_pipe := false
var bar_filling := false
var recover_toggle := false
var hold_flag := false
## +0x20: what the last clip step reported (0 playing, 1 looped, 2 ended).
var clip_result := 0
## +0x24 / +0x2C: stick counters (0x10 centred). +0x28 / +0x30: stick axes.
var counter_x := 0x10
var counter_y := 0x10
var axis_x := 0
var axis_y := 0
## +0x38: time in the air. +0x3C: ride direction on a pipe. +0x40: the trick rate.
var air_time := 0.0
var ride_direction := 0.0
var trick_rate := 0.0
## +0x44 / +0x48: the clip positions of the held trick, +0x4C the bar as a fraction,
## +0x50 the push along a pipe.
var pose_frame := 0.0
var board_frame := 0.0
var bar_fraction := 0.0
var pipe_push := UNSET
## +0x54: the yaw at the start of the tick.
var yaw_before := 0.0
## +0x5C: speed. +0x60: its cap.
var speed := 0.0
var speed_cap := SPEED_CAP
## +0x64: the charge of a jump. +0x68 / +0x6C: where the jump started and the height it is lifted
## to. +0x70 / +0x74: launch speed and current vertical speed.
var charge := 0.0
var launch_y := 0.0
var lift_y := 0.0
var launch_speed := 0.0
var vertical_speed := 0.0
## +0x78: the trick bar (0..127). +0x7C: recover timer.
var trick_bar := 0.0
var recover_timer := 0.0
## +0x80: keys and the two stick axes read this tick.
var pad_x := 0
var pad_y := 0
## +0x8C: velocity per tick.
var velocity := Vector3.ZERO
## +0x98: the normal of the pipe under the board. +0xB0: the surface being ridden.
var pipe_normal := Vector3(0.0, 8.0, 0.0)
var ride_surface = null
## DAT_05D50EC0 (trick score), DAT_05D50EC4 (score taken), DAT_05D50EC5 (reset on re-entry),
## DAT_05D50EB4 (the surface the rolling sound plays for).
var trick_score: float:
	get:
		return services.talk.trick_score
	set(value):
		services.talk.trick_score = value
var score_taken: bool:
	get:
		return services.talk.score_taken
	set(value):
		services.talk.score_taken = value
var reset_on_entry := false
var sound_surface := 5

var services: ActorServices
var vars


## FUN_007ECF4D.
static func from_descriptor(services_in: ActorServices, vars_in) -> Skate:
	var b := Skate.new()
	b.services = services_in
	b.vars = vars_in
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func has_post() -> bool:
	return true


func _park() -> bool:
	return vars.get_var(ZONE_VAR) == PARK_ZONE


## DAT_05DE1E7C: the board's record of the zone.
func _board():
	return services.record_at(services.talk.hidden_record)


func _rows(actor) -> Array:
	return [
		Vector3(actor.field_f(0x0C), actor.field_f(0x10), actor.field_f(0x14)),
		Vector3(actor.field_f(0x1C), actor.field_f(0x20), actor.field_f(0x24)),
		Vector3(actor.field_f(0x2C), actor.field_f(0x30), actor.field_f(0x34)),
	]


func _set_rows(actor, right: Vector3, up: Vector3, forward: Vector3) -> void:
	actor.set_field_f(0x0C, right.x)
	actor.set_field_f(0x10, right.y)
	actor.set_field_f(0x14, right.z)
	actor.set_field_f(0x1C, up.x)
	actor.set_field_f(0x20, up.y)
	actor.set_field_f(0x24, up.z)
	actor.set_field_f(0x2C, forward.x)
	actor.set_field_f(0x30, forward.y)
	actor.set_field_f(0x34, forward.z)
	actor.matrix_valid = true


static func _cross(a: Vector3, b: Vector3) -> Vector3:
	return Vector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)


## FUN_007EB09D.
func update(actor, block: BehaviourBlock, _var_value: int) -> int:
	var g := services.talk
	var park := _park()
	var request := 0
	var ground_y := UNSET
	var hit_kind := 0
	if status != block.frame_counter or mode != g.pepper_clip:
		clip_result = 0
		actor.flags |= 2
		speed_cap = SPEED_CAP
		speed = 0.0
		if g.pepper_clip == 1:
			g.pepper_clip = MODE_AIR
			mode = MODE_AIR
			air_time = 0.0
			launch_speed = 20.0
			launch_y = actor.y
			lift_y = launch_y + 2.0
		elif g.pepper_clip != 0:
			mode = g.pepper_clip
			g.pepper_clip = 0
		if reset_on_entry:
			air_time = 0.0
			launch_y = 0.0
			lift_y = 0.0
			launch_speed = 0.0
			vertical_speed = 0.0
			reset_on_entry = false
	if mode != MODE_CRASH and mode != MODE_MOUNT:
		_read_input(actor)
		yaw_before = actor.yaw
	request = _step_mode(actor)
	if mode != MODE_MOUNT:
		var probe := Vector3(actor.x, actor.y + 1.2, actor.z)
		var down := velocity.y * FRAME - 40.0 if park else -8.0
		var hit = services.collide_sweep(actor, probe, Vector3(0.0, down, 0.0), 3, 0.8 if park else SWEEP_RADIUS, 0.6 if park else SWEEP_TOLERANCE)
		if hit == null:
			if park:
				grounded = true
				on_pipe = false
				ride_surface = null
			else:
				ground_y = services.terrain_height(probe, 4.0)
				if lift_y < ground_y:
					actor.y = ground_y
		else:
			hit_kind = int(hit.get("kind", KIND_LAND))
			if hit_kind == KIND_PIPE:
				on_pipe = true
				ride_surface = hit
				pipe_normal = hit.normal
			elif grounded:
				on_pipe = false
				ride_surface = null
			if park:
				ground_y = hit.position.y
				if air_time == 0.0:
					actor.y = hit.position.y
			elif lift_y <= hit.position.y:
				ground_y = hit.position.y
				actor.y = hit.position.y
				if air_time != 0.0:
					request = MODE_LAND
					_land()
	if not (park and services.current_clip(actor) == MODE_AIR):
		services.set_matrix_yaw(actor, Vector3(actor.x, actor.y, actor.z))
	if mode == MODE_AIR or on_pipe or mode == MODE_MOUNT:
		if on_pipe and mode != MODE_CRASH and not hold_flag and park:
			_align_to_pipe(actor)
	elif hit_kind == KIND_LAND and not park:
		_align_to_ground(actor)
	var rows := _rows(actor)
	var forward: Vector3 = rows[2]
	velocity = forward * speed * FRAME
	if on_pipe and not grounded and ride_surface != null:
		var axis: Vector3 = ride_surface.get("axis", Vector3.ZERO) * pipe_push
		if ride_direction > 0.0:
			velocity = axis
		elif ride_direction < 0.0:
			velocity = -axis
	var from := Vector3(actor.x, actor.y, actor.z)
	var probe_up := Vector3(from.x, from.y + 1.2, from.z)
	var wall = services.collide_sweep(actor, probe_up, velocity, 3, 0.8 if park else SWEEP_RADIUS, 0.6 if park else SWEEP_TOLERANCE)
	if wall != null and int(wall.get("kind", KIND_LAND)) != KIND_PIPE:
		var normal: Vector3 = wall.normal
		var along := normal.x * velocity.x + normal.z * velocity.z
		velocity -= normal * along
		if park and ride_direction == 0.0:
			var right: Vector3 = rows[0]
			if normal.dot(right) <= 0.0:
				actor.yaw -= FRAME * WALL_TURN
			else:
				actor.yaw += FRAME * WALL_TURN
		var again = services.collide_sweep(actor, probe_up, velocity, 3, 0.6 if park else SWEEP_RADIUS, 0.6 if park else SWEEP_TOLERANCE)
		if again != null:
			velocity = Vector3.ZERO
	var target := from + velocity
	if air_time != 0.0:
		if lift_y <= ground_y:
			target.y = ground_y
			request = MODE_LAND
			_land()
		else:
			target.y = lift_y
	if park and mode != MODE_RECOVER and mode != MODE_MOUNT:
		target = _park_walls(actor, target)
	actor.x = target.x
	actor.y = target.y
	actor.z = target.z
	if park and actor.y < PARK_FLOOR:
		actor.y = PARK_FLOOR
	request = _settle_mode(actor, request)
	rows = _rows(actor)
	var ahead: Vector3 = rows[2] * 2.5 + from
	var ahead_ground := services.terrain_height(ahead, 4.0)
	if ahead_ground < -1000.0:
		ahead_ground = g.ground_min
	var ceiling = services.collide_sweep(actor, Vector3(ahead.x, ahead.y + 80.0, ahead.z), Vector3(0.0, -176.0, 0.0), 1, 0.01, 0.0)
	if ceiling != null and ahead_ground < ceiling.position.y:
		ahead_ground = ceiling.position.y
	if actor.y - ahead_ground > 2.0 and services.terrain_height(from, 4.0) < actor.y and mode != MODE_AIR and mode != MODE_MOUNT and request != MODE_AIR and (not park or actor.z <= -25.0):
		_start_fall(actor, park)
		request = MODE_AIR
	if park:
		var tilt: Vector3 = (_rows(actor))[2]
		if actor.y > 9.25 and tilt.y > 0.0 and mode != MODE_AIR and mode != MODE_LAND:
			_start_fall(actor, park)
			request = MODE_AIR
	if request != 0:
		services.set_clip(actor, request, 0.0)
		mode = request
		g.pepper_clip = mode
	var clip := services.current_clip(actor)
	if mode == MODE_AIR:
		_tricks(actor, clip)
	_copy_to_board(actor)
	_chase_camera(actor, park)
	return 1


## The jump is over: the air state of the object is cleared and the board is on the ground.
func _land() -> void:
	air_time = 0.0
	launch_y = 0.0
	lift_y = 0.0
	launch_speed = 0.0
	vertical_speed = 0.0
	grounded = true
	ride_surface = null


func _start_fall(actor, park: bool) -> void:
	air_time = 0.0
	launch_speed = PARK_FALL if park else AIR_LAUNCH
	charge = 0.0
	lift_y = launch_y + 4.0
	launch_y = actor.y
	services.sound_follow(SOUND_LAUNCH_AT, Vector3(actor.x, actor.y, actor.z))


## FUN_007EAF41: read the keys, ramp the speed and turn the board.
func _read_input(actor) -> void:
	var park := _park()
	var inputs := services.read_input()
	pad_x = inputs[1]
	pad_y = inputs[2]
	_step_stick()
	if pad_x > 0x1E or pad_x < -0x1E:
		axis_x = pad_x
	if pad_y > 0x1E or pad_y < -0x1E:
		axis_y = pad_y
	if (services.talk.game_flags_b & 8) != 0 and mode != MODE_AIR and not park:
		if speed <= 0.0:
			speed = 0.0
		else:
			speed -= BRAKE_STEP
	if park:
		if speed_cap <= speed:
			speed = speed_cap
		else:
			speed += SPEED_STEP
	elif SPEED_CAP <= speed:
		speed = SPEED_CAP
	else:
		speed += SPEED_STEP
	if mode != MODE_AIR:
		actor.yaw = float(axis_x) * TURN_RATE * FRAME + actor.yaw


## FUN_007EAD63: the stick counters follow the held direction keys and fall back to the centre.
func _step_stick() -> void:
	var held_keys: int = services.talk.game_flags_b
	var a := counter_x
	var b := counter_y
	var moved_a := false
	var moved_b := false
	if (held_keys & 1) != 0:
		moved_a = true
		a = a - 3 if a < 0x11 else 0x10
		if a < 1:
			a = 0
	if (held_keys & 2) != 0:
		moved_a = true
		a = 0x10 if a < 0x10 else a + 3
		if a > 0x1F:
			a = 0x20
	if (held_keys & 4) != 0:
		moved_b = true
		b = b - 3 if b < 0x11 else 0x10
		if b < 1:
			b = 0
	if (held_keys & 8) != 0:
		moved_b = true
		b = 0x10 if b < 0x10 else b + 3
		if b > 0x1F:
			b = 0x20
	if not moved_a:
		if a > 0x10:
			a -= 4
			if a < 0x10:
				a = 0x10
		if a < 0x10:
			a += 4
			if a > 0x10:
				a = 0x10
	if not moved_b:
		if b > 0x10:
			b -= 4
			if b < 0x10:
				b = 0x10
		if b < 0x10:
			b += 4
			if b > 0x10:
				b = 0x10
	counter_y = b
	axis_y = CURVE[b] - 0x80
	counter_x = a
	axis_x = CURVE[a] - 0x80


## FUN_007EA13B and FUN_007EA057: the rolling sound follows the surface under the board.
func _roll_sound() -> void:
	if ROLL_MODES.has(mode):
		var surface: int = services.last_surface
		if surface != sound_surface:
			_release_roll()
		if ROLL_SOUNDS.has(surface):
			services.sound_play(ROLL_SOUNDS[surface])
		else:
			_release_roll()
		sound_surface = surface
	else:
		_release_roll()


func _release_roll() -> void:
	if ROLL_SOUNDS.has(sound_surface):
		services.sound_release(ROLL_SOUNDS[sound_surface])


## FUN_007EA341: what the mode does before the move; returns the mode to switch to (0 = none).
func _step_mode(actor) -> int:
	var g := services.talk
	var park := _park()
	var request := 0
	var clip_step := 1.0
	var board_step := 1.0
	var here := Vector3(actor.x, actor.y, actor.z)
	_roll_sound()
	match mode:
		MODE_MOUNT:
			speed = 0.0
			board_step = 0.5
		MODE_AIR:
			_air_step(actor, here, park)
			if services.current_clip(actor) != MODE_AIR:
				clip_step = 0.0
				board_step = 0.0
		0x27, 0x28:
			clip_step = 0.0
		MODE_ROLL:
			if speed > 0.1:
				if speed == 0.0:
					clip_step = 0.0
			else:
				request = MODE_RECOVER
			trick_score = 0.0
			if axis_x < 0x15 and axis_x > -0x15:
				if services.current_clip(actor) != MODE_ROLL:
					request = MODE_ROLL
					services.set_clip(_board(), BOARD_CLIP_RIDE, 0.0)
			else:
				_steer_pose(actor, 0x51)
				clip_step = 0.0
				board_step = 0.0
			if (g.game_flags_b & 0x20) != 0:
				request = MODE_CHARGE_A
				charge = 0.1
			if not park:
				recover_timer += FRAME
				if recover_timer > 50.0:
					request = MODE_RECOVER
					recover_timer = 0.0
		MODE_CHARGE:
			if (g.game_flags_b & 0x20) == 0:
				air_time = 0.0
				launch_speed = charge * (PARK_LAUNCH if park else AIR_LAUNCH)
				charge = 0.0
				lift_y = launch_y + 4.0
				launch_y = actor.y
				request = MODE_AIR
			else:
				if axis_x < 0x15 and axis_x > -0x15:
					if services.current_clip(actor) != MODE_CHARGE:
						request = MODE_CHARGE
						services.set_clip(_board(), BOARD_CLIP_RIDE, 0.0)
				else:
					_steer_pose(actor, 0x53)
					board_step = 0.0
				if charge < 2.0:
					charge += FRAME * 0.06
			clip_step = 0.0
		MODE_FALL:
			air_time += FRAME * 0.1
			vertical_speed = air_time * g.gravity + launch_speed
			lift_y = vertical_speed * air_time + launch_y + g.gravity * air_time * air_time * 0.5
			speed = -1.0
			services.sound_follow(SOUND_FALL_AT, here)
	if clip_step != 0.0:
		clip_result = services.clip_advance(actor, clip_step)
	if board_step != 0.0:
		services.clip_advance(_board(), board_step)
	return request


## A pose that follows the stick: the Pepper and board clips are set to the frame that matches
## how far the stick is pushed.
func _steer_pose(actor, clip: int) -> void:
	var board = _board()
	services.set_clip(actor, clip, 0.0)
	services.set_clip(board, BOARD_CLIP_STEER, 0.0)
	var amount := float(axis_x) / 127.0
	var half := (services.anim_length(actor) - 1.0) * 0.5
	var pepper_at := half * amount + half
	half = (services.anim_length(board) - 1.0) * 0.5
	var board_at := half * amount + half
	_set_frame(board, board_at)
	_set_frame(actor, pepper_at)


## FUN_0042324D: set the clip position when it lies inside the clip.
func _set_frame(record, frame: float) -> void:
	if frame >= 0.0 and frame <= services.anim_length(record):
		services.anim_set_frame(record, frame)


## Mode 0x20: the jump arc. The height is lifted by launch speed and gravity; a ceiling above
## stops the climb.
func _air_step(actor, here: Vector3, park: bool) -> void:
	var g := services.talk
	air_time += FRAME * 0.1
	vertical_speed = air_time * g.gravity + launch_speed
	var new_y := vertical_speed * air_time + launch_y + g.gravity * air_time * air_time * 0.5
	if absf(new_y - here.y) > 4.0 and new_y - here.y < 0.0:
		new_y = here.y - 4.0
	if new_y < here.y:
		lift_y = new_y
	else:
		var climb := new_y - here.y
		var above = services.collide_sweep(actor, Vector3(here.x, here.y + 4.0, here.z), Vector3(0.0, climb, 0.0), 1, SWEEP_RADIUS, SWEEP_RADIUS)
		if above == null:
			lift_y = new_y
		else:
			lift_y = above.position.y - climb - 4.0
	grounded = false
	velocity = Vector3.ZERO
	if park and not hold_flag:
		_park_air(actor)


## The park's pipes turn the board in the air: a ride direction is chosen from how it leaves the
## pipe and then it turns that way until it is level again.
func _park_air(actor) -> void:
	var rows := _rows(actor)
	var right: Vector3 = rows[0]
	var up: Vector3 = rows[1]
	var forward: Vector3 = rows[2]
	if pipe_push == UNSET:
		pass
	if ride_direction == 0.0:
		if on_pipe and up.y < 6.0:
			if right.y >= 0.0:
				if forward.y > -1.0:
					ride_direction = -10.0
			elif -right.y < 1.0 and forward.y > -0.9:
				ride_direction = 10.0
		if forward.y != 0.0:
			pipe_push = 0.25 / forward.y
	else:
		if (ride_direction < 0.0 or ride_direction > 0.0) and forward.y > -0.65:
			actor.yaw += ride_direction * 0.0174532 * FRAME
		if services.current_clip(actor) != 0x5F:
			services.set_matrix_yaw(actor, Vector3(actor.x, actor.y, actor.z))


## FUN_007E98D2: what a mode does once the board has moved. Returns the mode to switch to. (The
## decompiler lost the writes to the returned byte; every one below is read off the disassembly.)
func _settle_mode(actor, request: int) -> int:
	var park := _park()
	var g := services.talk
	var board = _board()
	match mode:
		0x0E:
			if clip_result == 2:
				request = 0x27
			if axis_x < 0x14:
				request = MODE_ROLL
		0x19:
			if clip_result == 2:
				request = 0x28
			if axis_x > -0x14:
				request = MODE_ROLL
		0x27:
			if axis_x < 0x14:
				request = MODE_ROLL
		0x28:
			if axis_x > -0x14:
				request = MODE_ROLL
		MODE_MOUNT:
			if park:
				var forward: Vector3 = (_rows(actor))[2]
				if forward.z < 0.95:
					actor.yaw -= FRAME * WALL_TURN
					services.set_matrix_yaw(actor, Vector3(actor.x, actor.y, actor.z))
				hold_flag = true
			if clip_result == 2:
				request = MODE_RECOVER
				services.set_clip(board, BOARD_CLIP_RIDE, 0.0)
		MODE_AIR:
			if pipe_normal.y < 0.6 and pipe_normal.y > 0.0 and not hold_flag:
				pipe_normal = Vector3(0.0, 0.0, 1.0 if pipe_normal.z >= 0.0 else -1.0)
				var forward: Vector3 = (_rows(actor))[2]
				var normal := pipe_normal.normalized()
				forward -= normal * normal.dot(forward)
				forward = forward.normalized()
				_set_rows(actor, _cross(normal, forward), normal, forward)
		MODE_LAND:
			ride_direction = 0.0
			services.sound_release(SOUND_LAND_A)
			services.sound_release(SOUND_LAND_B)
			if clip_result == 2:
				request = MODE_ROLL
				scored = false
			services.set_clip(board, BOARD_CLIP_RIDE, 0.0)
			ride_direction = 0.0
			if not scored:
				if not bar_filling:
					if trick_bar <= 100.0 or score_taken:
						trick_bar = 0.0
						score_taken = true
					else:
						request = _crash(actor)
				elif trick_bar >= 100.0 or score_taken:
					if trick_bar > 100.0 and not score_taken:
						trick_bar = 0.0
						score_taken = true
				else:
					request = _crash(actor)
				scored = true
			if request != MODE_CRASH:
				var surface: int = services.last_surface
				if LAND_SOUNDS.has(surface):
					services.sound_play(LAND_SOUNDS[surface])
			hold_flag = false
		MODE_CRASH:
			speed_cap = SPEED_CAP
			speed = 0.0
			if clip_result == 2:
				request = MODE_ROLL
		MODE_CHARGE_A:
			if charge < 2.0:
				charge += FRAME * 0.06
			if clip_result != 0:
				if (g.game_flags_b & 0x20) != 0:
					request = MODE_CHARGE
				else:
					air_time = 0.0
					launch_speed = charge * (PARK_LAUNCH if park else AIR_LAUNCH)
					charge = 0.0
					lift_y = launch_y + 4.0
					launch_y = actor.y
					request = MODE_AIR
		MODE_RECOVER:
			if clip_result == 2:
				if not recover_toggle:
					recover_toggle = true
					clip_result = 0
				else:
					request = MODE_ROLL
					recover_toggle = false
		MODE_FALL:
			if clip_result == 2:
				request = MODE_ROLL
				g.pepper_clip = 0
	return request


## The landing was too hard for the bar: the board crashes and everything scored is dropped.
func _crash(actor) -> int:
	services.sound_follow(SOUND_CRASH_AT, Vector3(actor.x, actor.y, actor.z))
	trick_bar = 0.0
	speed = 0.0
	trick_score = 0.0
	score_taken = false
	return MODE_CRASH


## FUN_007E83F0: stand on the ground under the board with four probes, two across it and two
## along it, and tilt the matrix to the plane they make.
func _align_to_ground(actor) -> void:
	var rows := _rows(actor)
	var right: Vector3 = rows[0] * 0.8
	var forward: Vector3 = rows[2] * 0.8
	var here := Vector3(actor.x, actor.y, actor.z)
	var left_point := _probe(actor, here - right, 1.2, true)
	var right_point := _probe(actor, here + right, 1.2, false)
	var back_point := _probe(actor, here - forward, 2.0, false)
	var front_point := _probe(actor, here + forward, 2.0, false)
	var across: Vector3 = (right_point - left_point).normalized()
	var along: Vector3 = (front_point - back_point).normalized()
	var up := _cross(along, across)
	var heading := Vector3(sin(actor.yaw), 0.0, cos(actor.yaw))
	heading -= up * up.dot(heading)
	heading = heading.normalized()
	_set_rows(actor, _cross(up, heading), up, heading)


## One probe of FUN_007E83F0: the ground height at `point`. The collision hit counts first; with
## none, the terrain does when it is within reach of the board (the first probe also rejects
## ground at -1000, the others anything under the sea floor level).
func _probe(actor, point: Vector3, lift: float, first: bool) -> Vector3:
	var floor_level: float = services.talk.ground_min
	var start := Vector3(point.x, actor.y + lift, point.z)
	var terrain: float = services.terrain_height(start, 4.0)
	var drop := -8.0 if terrain <= floor_level else terrain - start.y
	var hit = services.collide_sweep(actor, start, Vector3(0.0, drop, 0.0), 3, SWEEP_RADIUS, SWEEP_TOLERANCE)
	var height: float = actor.y
	if hit != null:
		height = hit.position.y
	else:
		var missing: bool = terrain <= -1000.0 if first else terrain <= floor_level
		if not missing and absf(start.y - actor.y) <= 4.0:
			height = terrain
	return Vector3(point.x, height, point.z)


## The park's pipe: the board stands on the pipe's normal.
func _align_to_pipe(actor) -> void:
	var forward: Vector3 = (_rows(actor))[2]
	var normal := pipe_normal.normalized()
	forward -= normal * normal.dot(forward)
	forward = forward.normalized()
	_set_rows(actor, _cross(normal, forward), normal, forward)


## The park's walls keep the board inside the rink and turn it at the ends.
func _park_walls(actor, target: Vector3) -> Vector3:
	var right: Vector3 = (_rows(actor))[0]
	if target.x >= -39.9:
		if target.x > 39.9:
			target.x = 39.9
			_wall_turn(actor, right.x * -8.0)
	else:
		target.x = -39.9
		_wall_turn(actor, right.x * 8.0)
	target.z = clampf(target.z, -24.0, 24.0)
	return target


func _wall_turn(actor, along: float) -> void:
	if ride_direction == 0.0:
		if along <= 0.0:
			actor.yaw -= FRAME * WALL_TURN
		else:
			actor.yaw += FRAME * WALL_TURN


## FUN_007E8A80: the air tricks. The bar of the trick that plays fills and drains, the clips
## follow it, and a button with the stick starts a trick when the board is in the air pose.
func _tricks(actor, clip: int) -> void:
	var held_keys: int = services.talk.game_flags_b
	var board = _board()
	var pepper_clip := 0
	var board_clip := 0
	if clip != MODE_AIR:
		_bar_step(held_keys, clip)
		bar_fraction = trick_bar * 1.0 / 128.0
		pose_frame = services.anim_length(actor) * bar_fraction
		board_frame = services.anim_length(board) * bar_fraction
		_set_frame(board, board_frame)
		_set_frame(actor, pose_frame)
	else:
		bar_filling = false
	if clip == MODE_AIR:
		var picked := _pick_tricks(held_keys)
		pepper_clip = picked[0]
		board_clip = picked[1]
	if pepper_clip != 0:
		services.set_clip(actor, pepper_clip, 0.0)
	if board_clip != 0:
		services.set_clip(board, board_clip, 0.0)


## The bar of the trick that plays: it gains while a trick is held and, once let go, drains for
## the tricks in DRAIN_TRICKS and keeps gaining for the others.
func _bar_step(held_keys: int, clip: int) -> void:
	if _trick_held(held_keys, clip):
		_bar_gain()
		return
	if trick_bar > 0.0:
		var drains := DRAIN_TRICKS.has(clip)
		if drains:
			trick_bar -= (trick_rate + trick_rate) * FRAME
			if trick_bar < 0.0:
				trick_bar = 0.0
			if not score_taken and trick_bar <= 100.0 and trick_score != 0.0:
				bar_filling = false
				if board_frame < 1.0 and pose_frame == board_frame:
					board_frame += 0.1
		elif not score_taken and trick_bar >= 100.0 and trick_score != 0.0:
			bar_filling = true
			if board_frame < 1.0 and pose_frame == board_frame:
				board_frame += 0.1
		if not drains:
			_bar_gain()


func _bar_gain() -> void:
	if trick_bar >= 127.0:
		trick_bar = 127.0
		trick_score += FRAME * 30.0
	else:
		trick_bar += trick_rate * FRAME
		if trick_bar > 127.0:
			trick_bar = 127.0
		trick_score += FRAME * 15.0


## Whether a button, the stick and the clip that plays still make up a trick (FUN_007E8A80's long
## condition, tests copied one by one).
func _trick_held(held_keys: int, clip: int) -> bool:
	var x := axis_x
	var y := axis_y
	if (held_keys & 0x10) != 0:
		if x <= HOLD_LOW and y <= HOLD_LOW and clip == 0x69:
			return true
		if x <= HOLD_LOW and clip == 0x67:
			return true
		if x <= HOLD_LOW and y >= HOLD_HIGH and clip == 0x68:
			return true
		if y >= HOLD_HIGH and clip == 0x6D:
			return true
		if x >= HOLD_HIGH and y >= HOLD_HIGH and clip == 0x5E:
			return true
		if x >= HOLD_HIGH and absi(y) <= HOLD_BAND and clip == 0x5C:
			return true
		if x >= HOLD_HIGH and y <= HOLD_LOW and clip == 0x60:
			return true
		if absi(x) <= HOLD_BAND and y <= HOLD_LOW and clip == 0x52:
			return true
	if (held_keys & 0x80) != 0:
		if x <= HOLD_LOW and y <= HOLD_LOW and clip == 0x66:
			return true
		if x <= HOLD_LOW and absi(y) <= HOLD_BAND and clip == 10:
			return true
		if absi(x) <= HOLD_BAND and y >= HOLD_HIGH and clip == 0x11:
			return true
		if x >= HOLD_HIGH and absi(y) <= HOLD_BAND and clip == 0x0F:
			return true
		if x >= HOLD_HIGH and y <= HOLD_LOW and clip == 0x54:
			return true
	if (held_keys & 0x40) != 0:
		if x <= HOLD_LOW and y <= HOLD_LOW and clip == 0x10:
			return true
		if x <= HOLD_LOW and absi(y) <= HOLD_BAND and clip == 0x6A:
			return true
		if x <= HOLD_LOW and y >= HOLD_HIGH and clip == 100:
			return true
		if absi(x) <= HOLD_BAND and y >= HOLD_HIGH and clip == 0x6C:
			return true
		if x >= HOLD_HIGH and y >= HOLD_HIGH and clip == 0x5F:
			return true
		if x >= HOLD_HIGH and absi(y) <= HOLD_BAND and clip == 0x65:
			return true
		if x >= HOLD_HIGH and y <= HOLD_LOW and clip == 0x19:
			return true
		if absi(x) <= HOLD_BAND and y <= HOLD_LOW and clip == 0x6B:
			return true
	return false


## The trick a button and the stick start while the board is in the air pose: [Pepper clip, board
## clip]. Later buttons override earlier ones, and each trick sets the rate of the bar.
func _pick_tricks(held_keys: int) -> Array:
	var x := axis_x
	var y := axis_y
	var pepper_clip := 0
	var board_clip := 0
	if (held_keys & 0x10) != 0:
		if x < -PICK and y < -PICK:
			pepper_clip = 0x69
			board_clip = 9
			trick_rate = 4.0
		if x < -PICK and y < PICK and y > -PICK:
			pepper_clip = 0x67
			board_clip = 10
			trick_rate = 4.0
		if x < -PICK and y > PICK:
			pepper_clip = 0x68
			trick_rate = 8.0
		if x < PICK and x > -PICK and y > PICK:
			pepper_clip = 0x6D
			trick_rate = 4.0
		if x > PICK and y > PICK:
			pepper_clip = 0x5E
			board_clip = 6
			trick_rate = 4.0
		if x > PICK and y < PICK and y > -PICK:
			pepper_clip = 0x5C
			board_clip = 7
			trick_rate = 8.0
		if x > PICK and y < -PICK:
			pepper_clip = 0x60
			board_clip = 8
			trick_rate = 4.0
		if x < PICK and x > -PICK and y < -PICK:
			pepper_clip = 0x52
			board_clip = 5
			trick_rate = 4.0
	if (held_keys & 0x80) != 0:
		if x < -PICK and y < -PICK:
			pepper_clip = 0x66
			trick_rate = 4.0
		if x < -PICK and y < PICK and y > -PICK:
			pepper_clip = 10
			trick_rate = 4.0
		if x < PICK and x > -PICK and y > PICK:
			pepper_clip = 0x11
			trick_rate = 4.0
		if x > PICK and y < PICK and y > -PICK:
			pepper_clip = 0x0F
			trick_rate = 4.0
		if x > PICK and y < -PICK:
			pepper_clip = 0x54
			trick_rate = 4.0
	if (held_keys & 0x40) != 0:
		if x < -PICK and y < -PICK:
			pepper_clip = 0x10
			board_clip = 0x0B
			trick_rate = 4.0
		if x < -PICK and y < PICK and y > -PICK:
			pepper_clip = 0x6A
			trick_rate = 4.0
		if x < -PICK and y > PICK:
			pepper_clip = 100
			trick_rate = 4.0
		if x < PICK and x > -PICK and y > PICK:
			pepper_clip = 0x6C
			board_clip = 0x0E
			trick_rate = 8.0
		if x > PICK and y < PICK and y > -PICK:
			pepper_clip = 0x65
			trick_rate = 2.0
		if x > PICK and y < -PICK:
			pepper_clip = 0x19
			board_clip = 0x0C
			trick_rate = 4.0
		if x < PICK and x > -PICK and y < -PICK:
			pepper_clip = 0x6B
			board_clip = 0x0D
			trick_rate = 4.0
	if pepper_clip != 0:
		services.sound_play(SOUND_TRICK)
	return [pepper_clip, board_clip]


## The board (record 9) takes Pepper's place and matrix.
func _copy_to_board(actor) -> void:
	var board = _board()
	if board == null:
		return
	board.x = actor.x
	board.y = actor.y
	board.z = actor.z
	for offset in [0x0C, 0x10, 0x14, 0x1C, 0x20, 0x24, 0x2C, 0x30, 0x34]:
		board.set_field_f(offset, actor.field_f(offset))
	board.matrix_valid = true


## The chase camera: the target is 4 above the board, the eye eases a tenth of the way (0.8 in the
## park's air) to the point 12 above and 14 behind the board in the board's own frame.
func _chase_camera(actor, park: bool) -> void:
	var rows := _rows(actor)
	var wanted: Vector3 = rows[0] * 0.0 + rows[1] * 12.0 + rows[2] * -14.0 + Vector3(actor.x, actor.y, actor.z)
	var follow := 0.8 if park and mode == MODE_AIR else 0.1
	var eye: Vector3 = services.camera_eye
	services.camera_target = Vector3(actor.x, actor.y + 4.0, actor.z)
	if services.fog_active and not park:
		if (eye - services.camera_target).length() < 13.0:
			if speed <= 0.0:
				eye.x -= services.camera_right.x * FRAME
				eye.z -= services.camera_right.z * FRAME
			else:
				eye.x += velocity.x * FRAME
				eye.z += velocity.z * FRAME
	if park:
		eye.x = clampf((wanted.x - eye.x) * follow + eye.x, -37.9, 37.9)
		eye.y = (wanted.y - eye.y) * follow + eye.y
		eye.z = clampf((wanted.z - eye.z) * follow + eye.z, -21.9, 21.9)
	else:
		eye += (wanted - eye) * follow
	services.camera_eye = eye


## FUN_007ECB5D: after the move the board slides along what it ran into, tips over on a steep
## wall and gets off when it has stopped.
func post(actor) -> void:
	var g := services.talk
	var park := _park()
	if not park:
		var probe := Vector3(actor.x, actor.y + 4.0, actor.z)
		var push := Vector3(velocity.x * FRAME, 1.2, velocity.z * FRAME)
		var hit = services.collide_sweep(actor, probe, push, 1, SWEEP_RADIUS, SWEEP_TOLERANCE)
		if hit != null and hit.normal.y < 0.0:
			var normal: Vector3 = hit.normal
			var along := normal.z * velocity.z + normal.x * velocity.x
			if along <= 0.0:
				velocity.x -= normal.x * along
				velocity.z -= normal.z * along
				push = Vector3(velocity.x, 1.2 - normal.y * along, velocity.z)
				var again = services.collide_sweep(actor, probe, push, 1, SWEEP_RADIUS, SWEEP_TOLERANCE)
				if again != null:
					if normal.y > -1.0:
						velocity = Vector3.ZERO
					if (_rows(actor))[1].y < 0.9:
						g.pepper_clip = CLIP_TIPPED
						services.set_clip(actor, CLIP_TIPPED, 0.0)
						_board().flags &= ~2
						vars.set_var(tag, 1)
	if speed <= 0.0 and mode != MODE_MOUNT and mode != MODE_RECOVER:
		if not park and mode != MODE_AIR:
			g.pepper_clip = CLIP_DISMOUNT
			services.set_clip(actor, CLIP_DISMOUNT, 0.0)
			services.set_clip(_board(), BOARD_CLIP_OFF, 0.0)
			vars.set_var(tag, 1)
