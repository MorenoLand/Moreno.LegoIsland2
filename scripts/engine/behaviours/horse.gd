class_name Horse
extends Behaviour

## FUN_004DF028 (ctor) / FUN_004DC858 (update, vtable 0x008BABD8, returns 0 / 1) / FUN_004DEDDD
## (post). The castle's horse: Pepper walks up to it and takes the action key to mount; ridden
## it walks, gallops, turns, backs up, rears when the brake is tapped and jumps when the jump key is
## let go, follows the ground with two probes and drags the camera behind it.
##
## The tag variable is 0x112 (SWITCH_CSI_HORSE): bit 1 = ridden, bit 0x10 = busy (turning or
## jumping). State flags: 1 gallop, 0x10 turning or jumping, 0x20 jump charging, 0x100 backing up,
## 0x1000 rearing. Move flags of one tick: 1 forward, 2 back, 4 jump, 0x10 turn, 0x20 standing.
## Everything below is the exe's arithmetic in the exe's order (each step is one 30 Hz tick, so
## DAT_008A0850 is 1).

const CLIP_WALK := 2
const CLIP_GALLOP := 3
const CLIP_REAR := 4
const CLIP_IDLE := 5
const CLIP_JUMP := 6
const MOUNT_CLIP := 0x62
const WALK_SELECTOR := 1
const HORSE_SELECTOR := 0x10
const HOME_NODE := 0x5A
const SOUND_NEIGH := 0x5D4A498
const SOUND_SNORT := 0x5D4A3F0
const SOUND_JUMP := 0x5D4A400
const SOUND_LAND_A := [0x5D4A438, 0x5D4A434]
const SOUND_LAND_B := [0x5D4A43C, 0x5D4A440]
const SOUND_STEP_A := 0x5D4A418
const SOUND_STEP_B := 0x5D4A41C
const SOUND_STEP_C := 0x5D4A420
const SOUND_STEP_D := 0x5D4A424
const SOUND_BLOW := 0x5D4A408
const RETURN_TIME := 300.0
const TURN_STEP := 0.052359596
const TURN_BASE := 0.17453292
const TURN_RATE := 0.052359596
const TURN_LIMIT := 1.5707879
const GALLOP_SCALE := 1.0
const WALK_SCALE := 0.33333334
const CAMERA_AIM := Vector3(0.0, 12.8, -24.0)
const CAMERA_SPEED := 0.0675
const CAMERA_NEAR_SQUARED := 0.64
const TARGET_RISE := 4.8
## 0xCDCDCDCD: what the debug heap leaves in a field the constructor does not set.
const UNSET := -4.1127872e8
## The byte local_6c holds when no ground probe ran this tick (the stack canary 0xCC).
const NO_PROBE := 0xCC
const PI_F := 3.1415927
const TAU_F := 6.2831855

var state := 0
var jump_rate := 0.0
var jump_base := 0.0
var jump_power := 0.0
var turn := TURN_BASE
var turn_rate := TURN_RATE
var pitch := 0.0
var brake_time := 0.0
var rest := Vector3.ZERO
var rest_yaw := 0.0
var step_phase := 0
var return_time := 0.0
var return_armed := 0
var idle_time := UNSET
var probe_delta := Vector3.ZERO

var services: ActorServices
var vars


static func from_descriptor(services_in: ActorServices, vars_in, actor) -> Horse:
	var b := Horse.new()
	b.services = services_in
	b.vars = vars_in
	services_in.shared["horse_taken"] = 0
	b.rest = Vector3(actor.x, actor.y, actor.z)
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func _wrap(angle: float) -> float:
	if -PI_F <= angle:
		if PI_F < angle:
			return angle - TAU_F
		return angle
	return angle + TAU_F


func _at(actor) -> Vector3:
	return Vector3(actor.x, actor.y, actor.z)


func _put(actor, at: Vector3) -> void:
	actor.x = at.x
	actor.y = at.y
	actor.z = at.z


func _sound(key: int, actor) -> void:
	services.sound_follow(key, _at(actor))


func _rotate(actor) -> void:
	services.set_rotation(actor, actor.field_f(0x4C), actor.field_f(0x50), actor.field_f(0x54))


func _place(actor, at: Vector3) -> void:
	services.set_actor_matrix(actor, Vector3(actor.field_f(0x4C), actor.field_f(0x50), actor.field_f(0x54)), at, Vector3.ONE)


## FUN_004DC6F0: one ground probe from `at` along `delta`. [result, hit y]: 0 no ground, 1 the
## terrain, 2 a record's surface (the record at +0x1A0, number 4, also marks the water flag).
func _probe(actor, at: Vector3) -> Array:
	var ground := services.terrain_height(at, 4.0)
	var found := 0
	if ground < -160.0:
		ground = at.y
	else:
		# The exe writes the drop into the delta it was given, and the next probe reuses it.
		probe_delta.y = ground - at.y
		found = 1
	var hit = services.record_under(actor, at, probe_delta)
	if hit == null:
		return [found, ground]
	if int(hit.record) == 4:
		services.shared["horse_over_water"] = 1
	return [2, float(hit.position.y)]


func update(actor, block: BehaviourBlock, var_value: int) -> int:
	if (actor.flags & 2) == 0:
		return 0
	if services.scene_active:
		return 1
	if (var_value & 1) == 0:
		return _loose(actor, block)
	return _ridden(actor, block, var_value)


## Not ridden: the action key picks this horse as the mount when it is the nearest one in
## reach, otherwise it stands about.
func _loose(actor, block: BehaviourBlock) -> int:
	var g := services.talk
	var pressed: int = g.game_flags
	if g.machine_actor == actor:
		g.machine_distance = block.distance_squared
		services.shared["horse_taken"] = 1
		return 1
	var picked: bool = (pressed & 0x10) != 0 and g.pepper_clip != MOUNT_CLIP \
			and block.distance_squared < g.machine_distance and (actor.flags & 2) != 0 \
			and (vars.get_var(0x5E) & 0x7FFF) == WALK_SELECTOR
	if picked:
		g.machine_actor = actor
		g.machine_distance = block.distance_squared
		return 1
	if block.distance_squared < g.machine_distance:
		vars.or_var(0xC, 2)
	if services.current_clip(actor) == CLIP_IDLE:
		services.clip_finished(actor, 1.0)
	else:
		services.set_clip(actor, CLIP_IDLE, 0.0)
	if actor.field_f(0x4C) != pitch:
		actor.set_field_f(0x4C, pitch)
		services.set_rotation(actor, actor.field_f(0x4C), actor.field_f(0x50), 0.0)
	if services.random_float(120.0) >= 119.0:
		_sound(SOUND_NEIGH, actor)
	if return_armed != 0:
		if (actor.flags & 1) == 0:
			return_time -= 1.0
			if return_time <= 0.0:
				return_armed = 0
				var home = services.waypoint_position(1, HOME_NODE)
				if home != null:
					_put(actor, home)
		else:
			return_time = RETURN_TIME
	return 0


func _ridden(actor, block: BehaviourBlock, var_value: int) -> int:
	var g := services.talk
	var held: int = g.game_flags_b
	var pressed: int = g.game_flags
	var move := 0
	var finished := false
	var step := Vector3.ZERO
	return_time = RETURN_TIME
	return_armed = 1
	if status != block.frame_counter:
		services.set_clip(actor, CLIP_WALK, 0.0)
		held |= 4
		g.machine_actor = actor
	if g.axis_y < -0x32:
		if g.axis_y < -0x5A:
			if state == 0:
				state |= 1
		else:
			state &= ~1
		held |= 4
	elif 0x32 < g.axis_y:
		held |= 8
		if g.axis_y < 0x5B:
			state &= ~1
		else:
			state |= 1
	if g.axis_x < 0x33:
		if g.axis_x < -0x32:
			turn = float(-0x32 - g.axis_x) * PI_F / 170.0
			held |= 1
	else:
		turn = float(g.axis_x - 0x28) * PI_F / 170.0
		held |= 2
	if (pressed & 0x80) != 0 and (state & 0x1100) == 0:
		if (state & 1) == 0:
			state |= 1
		else:
			state &= ~1
	var gait := CLIP_WALK
	var scale := WALK_SCALE
	if (state & 1) != 0:
		gait = CLIP_GALLOP
		scale = GALLOP_SCALE
	if (state & 0x1010) == 0:
		if (var_value & 0x10) != 0:
			vars.clear_var(tag, 0x10)
		if services.current_clip(actor) != gait:
			services.set_clip(actor, gait, 0.0)
	elif (var_value & 0x10) == 0:
		vars.or_var(tag, 0x10)
	if (held & 0x20) == 0:
		if (state & 0x20) != 0:
			state &= ~0x20
			services.sound_play(SOUND_JUMP)
			services.sound_play(SOUND_LAND_A[0] if services.random_float(2.0) < 1.0 else SOUND_LAND_A[1])
			services.sound_play(SOUND_LAND_B[0] if services.random_float(2.0) < 1.0 else SOUND_LAND_B[1])
			services.set_clip(actor, CLIP_JUMP, 0.0)
			jump_rate = PI_F / services.anim_length(actor)
			state |= 0x10
			jump_base = actor.y
	elif (state & 0x1010) == 0:
		state |= 0x20
		jump_power += 0.8
		if 6.4 < jump_power:
			jump_power = 6.4
	var row0 := Vector3(actor.field_f(0x0C), actor.field_f(0x10), actor.field_f(0x14))
	var row1 := Vector3(actor.field_f(0x1C), actor.field_f(0x20), actor.field_f(0x24))
	var row2 := Vector3(actor.field_f(0x2C), actor.field_f(0x30), actor.field_f(0x34))
	if (state & 0x10) == 0:
		if (held & 4) != 0:
			step = row2 * scale
			move = 1
	else:
		step = row2 * scale
		move = 4
	if (held & 8) != 0 and move != 4:
		step = -row2 * scale
		move |= 2
	if (move & 3) == 3:
		move = 0
	if (move & 2) == 0:
		if 0.0 < brake_time and brake_time <= 4.0:
			move = 0x20
			state |= 0x1000
			services.set_clip(actor, CLIP_REAR, 0.0)
		brake_time = 0.0
	else:
		brake_time += 1.0
	var turn_delta := 0.0
	if (held & 1) != 0:
		turn_delta = -(sin(turn) * TURN_STEP)
		move |= 0x10
	if (held & 2) != 0 and (move & 0x10) == 0:
		turn_delta = sin(turn) * TURN_STEP
		move |= 0x10
	if (state & 0x1000) != 0:
		var frame := services.anim_frame(actor)
		move = 0x20
		if 15.0 < frame and frame < 45.0:
			actor.yaw += 0.10471919
	var yaw: float = actor.yaw
	var old := Vector3.ZERO
	var target := Vector3.ZERO
	var jump_sin := 0.0
	if (move & 7) == 0:
		if 0.0 <= idle_time:
			idle_time += 1.0
			if 10.0 < idle_time:
				idle_time = -1.0
				services.anim_set_frame(actor, 0.0)
		target = _at(actor)
	else:
		old = _at(actor)
		target = old + step
		if (move & 7) == 2:
			state |= 0x100
			turn_delta = -turn_delta
		else:
			state &= ~0x100
		yaw += turn_delta
		if (state & 0x10) != 0:
			jump_sin = sin(jump_rate * services.anim_frame(actor))
		idle_time = 0.0
	var wanted_pitch := 0.0
	var surface_flags := NO_PROBE
	var slope := 0.0
	if move != 0:
		surface_flags = 0
		var reach := row2 * 1.6
		var top := maxf(target.y - reach.y, target.y + reach.y) + 6.0
		var ahead := Vector3(target.x + reach.x, top, target.z + reach.z)
		var behind := Vector3(target.x - reach.x, top, target.z - reach.z)
		probe_delta = Vector3(0.0, -120.0, 0.0)
		services.shared["horse_over_water"] = 0
		var probe_a := _probe(actor, ahead)
		var surface_a := services.last_surface
		var probe_b := _probe(actor, behind)
		var surface_b := services.last_surface
		var hit_a: float = probe_a[1]
		var hit_b: float = probe_b[1]
		var floor_y: float = g.ground_min + 0.1
		if hit_a <= floor_y or int(probe_a[0]) == 0:
			hit_a = floor_y
			surface_flags = 1
		if hit_b <= floor_y or int(probe_b[0]) == 0:
			hit_b = floor_y
			surface_flags |= 2
		if surface_a == 7 or surface_b == 7:
			services.shared["horse_over_water"] = 1
		slope = hit_a - hit_b
		if int(probe_a[0]) == 2 or int(probe_b[0]) == 2:
			wanted_pitch = 0.0
			target.y = maxf(hit_a, hit_b)
			slope = 0.0
		elif int(services.shared.get("horse_over_water", 0)) == 0:
			if int(probe_a[0]) == 0 or int(probe_b[0]) == 0:
				if int(probe_a[0]) == 0:
					if int(probe_b[0]) == 0:
						wanted_pitch = -atan2(slope, 1.6)
					else:
						wanted_pitch = -atan2(slope, 1.6)
						target.y = hit_b
				else:
					wanted_pitch = -atan2(slope, 1.6)
					target.y = hit_a
			else:
				wanted_pitch = _wrap(-atan2(slope, 1.6))
				target.y = (hit_a + hit_b) * 0.5
		else:
			wanted_pitch = 0.0
			target.y = hit_a
			slope = 0.0
		pitch = wanted_pitch
	if (move & 7) == 0:
		if surface_flags == 0:
			_remember(actor)
	else:
		wanted_pitch = _slew(actor.field_f(0x4C), wanted_pitch)
		if surface_flags == 0:
			_remember(actor)
		if (state & 0x10) == 0:
			var along := target - old
			target = old + along.normalized() * scale
		else:
			var arc: float
			if jump_base <= target.y:
				arc = jump_power * jump_sin + jump_base
			else:
				arc = jump_power * jump_sin + target.y
			if target.y < arc:
				target.y = arc
		if (move & 5) == 0:
			if (move & 7) == 2:
				yaw = _back_up(actor, old, target, yaw, wanted_pitch, surface_flags, slope, turn_delta)
			else:
				actor.set_field_f(0x4C, wanted_pitch)
				actor.yaw = yaw
				_place(actor, target)
		elif (surface_flags & 1) != 0 or slope <= -8.0:
			_rotate(actor)
			actor.y = target.y
		else:
			var result := _forward(actor, old, target, yaw, wanted_pitch, move, turn_delta, row1, row2)
			yaw = result[0]
			move = result[1]
			turn_delta = result[2]
		if (move & 0x100) == 0:
			if (state & 0x100) == 0:
				finished = services.clip_finished(actor, 1.0)
			else:
				var frame_back := services.anim_frame(actor) - 1.0
				if frame_back < 0.0:
					frame_back = services.anim_length(actor) - 1.0
				services.anim_set_frame(actor, frame_back)
			if finished and (state & 0x10) != 0:
				state &= ~0x10
				services.set_clip(actor, gait, 0.0)
				jump_power = 0.0
		else:
			_rotate(actor)
			actor.y = target.y
	if (move & 7) == 0:
		if (state & 0x1000) != 0:
			finished = services.clip_finished(actor, 1.0)
			if finished:
				state &= ~0x1000
				services.set_clip(actor, gait, 0.0)
	if (move & 0x10) == 0:
		if (move & 0x20) != 0:
			actor.yaw = _wrap(yaw)
			actor.set_field_f(0x4C, wanted_pitch)
			_rotate(actor)
	else:
		state &= ~0x20
		if (state & 0x1000) == 0:
			finished = services.clip_finished(actor, 1.0)
			yaw += turn_delta
			actor.yaw = _wrap(yaw)
			actor.set_field_f(0x4C, wanted_pitch)
			_rotate(actor)
	_push_out(actor, target, row1, row2)
	if move == 0:
		_rotate(actor)
	if (move & 0x10) == 0:
		turn = TURN_BASE
	else:
		turn += turn_rate
		if TURN_LIMIT < turn:
			turn = TURN_LIMIT
	if surface_flags == 3:
		actor.y = rest.y
		actor.x = rest.x
		actor.z = rest.z
	_camera(actor)
	_sounds(actor, finished)
	return 1


func _remember(actor) -> void:
	rest = _at(actor)
	rest_yaw = actor.yaw


## The pitch eases toward the wanted one by at most 3 degrees a tick, and not at all inside that.
func _slew(current: float, wanted: float) -> float:
	if current <= wanted:
		if TURN_STEP < wanted - current:
			return current + TURN_STEP
		return current
	if TURN_STEP < current - wanted:
		return current - TURN_STEP
	return current


## Backing up (move 2): blocked when the rear probe found no ground or the ground drops away.
## Returns the yaw.
func _back_up(actor, old: Vector3, target: Vector3, yaw: float, wanted_pitch: float, surface_flags: int, slope: float, _turn_delta: float) -> float:
	var row1 := Vector3(actor.field_f(0x1C), actor.field_f(0x20), actor.field_f(0x24))
	var row2 := Vector3(actor.field_f(0x2C), actor.field_f(0x30), actor.field_f(0x34))
	var back := row2 * -4.0
	if (surface_flags & 2) != 0 or slope <= -8.0:
		actor.yaw = yaw
		_rotate(actor)
		actor.y = target.y
		return yaw
	var from := old + row1 * 6.0
	var hit = services.collide_sweep(actor, from, back, 3, 0.8, 0.8)
	if hit == null:
		from.y += 2.0
		hit = services.collide_sweep(actor, from, back, 3, 0.8, 0.8)
	if hit == null:
		actor.set_field_f(0x4C, wanted_pitch)
		actor.yaw = yaw
		_place(actor, target)
	else:
		actor.yaw = yaw
		_rotate(actor)
		actor.y = target.y
	return yaw


## Moving forward or jumping. Returns [yaw, move flags, turn delta].
func _forward(actor, old: Vector3, target: Vector3, yaw: float, wanted_pitch: float, move: int, turn_delta: float, row1: Vector3, row2: Vector3) -> Array:
	if (move & 0x10) == 0:
		var from := Vector3(old.x, old.y + 4.0, old.z)
		var hit = services.collide_sweep(actor, from, row2 * 8.0, 3, 1.04, 1.04)
		if hit != null and int(hit.get("record", -1)) != -2:
			var normal: Vector3 = hit.normal
			var away := _wrap(atan2(normal.x, normal.z))
			var difference := _wrap(away - actor.yaw)
			if absf(difference) < 2.61798:
				if 0.0 <= difference:
					turn_delta = sin(turn) * TURN_STEP
				else:
					turn_delta = -(sin(turn) * TURN_STEP)
				move |= 0x10
	yaw += turn_delta
	actor.yaw = yaw
	_rotate(actor)
	var from_low := old + row1 * 4.0
	var ahead := row2 * 4.0
	var blocked = services.collide_sweep(actor, from_low, ahead, 3, 0.8, 0.8)
	if blocked == null:
		blocked = services.collide_sweep(actor, old + row1 * 6.0, ahead, 3, 0.8, 0.8)
	if blocked == null:
		actor.set_field_f(0x4C, wanted_pitch)
		_place(actor, target)
	else:
		_rotate(actor)
		actor.y = target.y
	return [yaw, move, turn_delta]


## Two sweeps along the horse's length from just above it push it out of what it overlaps.
func _push_out(actor, target: Vector3, _row1: Vector3, _row2: Vector3) -> void:
	var row1 := Vector3(actor.field_f(0x1C), actor.field_f(0x20), actor.field_f(0x24))
	var row2 := Vector3(actor.field_f(0x2C), actor.field_f(0x30), actor.field_f(0x34))
	var from := target + row1 * 4.0
	var hit = services.collide_sweep(actor, from, row2 * 1.92, 3, 0.8, 0.8)
	if hit != null:
		_put(actor, _at(actor) - (hit.position - from) * 1.1)
	hit = services.collide_sweep(actor, from, row2 * -1.92, 3, 0.8, 0.8)
	if hit != null:
		_put(actor, _at(actor) - (hit.position - from) * 1.1)


## The camera looks 4.8 above the horse and eases to a point 12.8 up and 24 behind it.
func _camera(actor) -> void:
	services.camera_target = Vector3(actor.x, actor.y + TARGET_RISE, actor.z)
	var wanted := services.actor_point(actor, CAMERA_AIM)
	var eye := services.camera_eye
	var offset := wanted - eye
	if CAMERA_NEAR_SQUARED < offset.length_squared():
		eye += offset * CAMERA_SPEED
		services.camera_eye = eye
		services.camera_ease_height(actor.y + 1.0)


## The hoof sounds: by the clip playing and the frame it is at.
func _sounds(actor, finished: bool) -> void:
	var clip := services.current_clip(actor)
	var frame := int(services.anim_frame(actor))
	match clip - 1:
		0:
			_sound(SOUND_SNORT, actor)
		1:
			var chance := services.random_float(25.0)
			if step_phase == 0:
				if 0xC < frame:
					_sound(SOUND_STEP_A, actor)
					if 24.0 <= chance:
						_sound(SOUND_BLOW, actor)
					step_phase = 1
			elif step_phase == 1:
				if 0x16 < frame:
					_sound(SOUND_STEP_B, actor)
					step_phase = 2
				if finished:
					step_phase = 0
			elif step_phase == 2 and finished:
				_sound(SOUND_STEP_C, actor)
				_sound(SOUND_STEP_D, actor)
				step_phase = 0
		2:
			if step_phase == 0:
				if 4 < frame:
					_sound(SOUND_STEP_A, actor)
					step_phase = 1
			elif step_phase == 1:
				if 9 < frame:
					_sound(SOUND_STEP_B, actor)
					step_phase = 2
				if finished:
					_sound(SOUND_STEP_C, actor)
					step_phase = 0
			elif step_phase == 2 and finished:
				_sound(SOUND_STEP_C, actor)
				_sound(SOUND_STEP_D, actor)
				step_phase = 0
		3:
			_sound(SOUND_SNORT, actor)


func has_post() -> bool:
	return true


## FUN_004DEDDD.
func post(actor) -> void:
	var g := services.talk
	if int(services.shared.get("horse_taken", 0)) == 0 and ((g.game_flags & 0x10) == 0 or g.pepper_clip == MOUNT_CLIP):
		services.shared["horse_taken"] = 0
	elif g.machine_actor == actor:
		vars.or_var(tag, 1)
		vars.set_var(0x5E, HORSE_SELECTOR)
		g.list_mode = -4
	elif g.machine_actor == null:
		vars.clear_var(tag, 1)
