class_name SirenVehicle
extends Behaviour

## FUN_004D27B6 (ctor) / FUN_004D1D19 (update, vtable 0x008BA178) / FUN_004D23E4 (post),
## update returns 2. An emergency vehicle (SPD0..SPD2, AMBU, PCAR): it follows the road
## walker, tilts with the ground under its front and back, plays its siren while its var
## has bit 0x20000000, bumps off anything solid in its way and returns to where it
## started after five minutes of being left alone.
##
## Node: +0x18 siren phase, +0x1C siren pitch, +0x20 skip tilt, +0x21 off the road,
## +0x24 timer, +0x28 / +0x2C / +0x30 start position (x, y, z), +0x38 / +0x3C / +0x40 start
## angles.

## DAT_008BA1B8.. : the sound handles by vehicle code (siren play / follow, horn).
const SIREN := {"SPD0": 0x5D49FA0, "SPD1": 0x5D49DF4, "SPD2": 0x5D49E6C, "AMBU": 0x5D49DE0, "PCAR": 0x5D49DE4}
const HORN := {"SPD0": 0x5D49DA8, "SPD1": 0x5D49E08, "SPD2": 0x5D49E94, "AMBU": 0x5D49E20, "PCAR": 0x5D49E0C}
const CHATTER := [0x5D49E28, 0x5D49E2C, 0x5D49E44, 0x5D49E48, 0x5D49E40]
const SIREN_LOOP := 0x5D49E68
const CRASH := 0x5D49F94
const PITCH_LOW := 18500.0
const PITCH_HIGH := 22050.0
const PITCH_STEP := 118.30000305175781
const TILT_STEP := 0.03490639850497246
const NO_GROUND := -10000.0

var phase := 0.0
var pitch := PITCH_LOW
var skip_tilt := 0
var off_road := 0
var timer := 0.0
var start_position := Vector3.ZERO
var start_angles := Vector3.ZERO

var services: ActorServices
var vars


static func from_descriptor(desc: Descriptor, services_in: ActorServices, vars_in, actor) -> SirenVehicle:
	var b := SirenVehicle.new()
	b.services = services_in
	b.vars = vars_in
	var handle := services_in.walkers.get_or_create(0, actor, desc.s32(0))
	actor.block.walker = handle
	services_in.walker_set_speed(handle, 0.13333000242710114)
	services_in.walker_set_field(handle, 0x20, 0.5)
	services_in.walker_set_field(handle, 0x40, absf(0.10000000149011612))
	services_in.walker_set_field(handle, 0x4C, 1.0)
	services_in.walker_set_field(handle, 0x50, 2.0)
	services_in.walker_bind(handle, actor)
	services_in.walker_set_field(handle, 0x74, 3.0)
	b.start_position = Vector3(actor.x, actor.y, actor.z)
	b.skip_tilt = 0
	b.off_road = 0
	b.timer = 0.0
	services_in.model_set_field(actor, 0xFF, 1)
	if services_in.all_records.size() > 9:
		services_in.model_set_flag(services_in.all_records[9], 1)
	services_in.model_reset_shadow(actor)
	services_in.talk.vehicle_crashed = 0
	b.phase = 0.0
	b.pitch = PITCH_LOW
	actor.set_field_f(0x54, 0.0)
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func _code(actor) -> String:
	return String(actor.code).substr(0, 4)


## FUN_004D1590: start the siren sound of this vehicle type.
func _siren_start(actor) -> void:
	var key = SIREN.get(_code(actor))
	if key != null:
		services.sound_play(key)


## FUN_004D167A: keep the siren of this vehicle type following it.
func _siren_follow(actor) -> void:
	var key = SIREN.get(_code(actor))
	if key != null:
		services.sound_follow(key, Vector3(actor.x, actor.y, actor.z))


## FUN_004D1774: sound the horn (unless the crash flag is set).
func _horn(actor) -> void:
	if services.talk.vehicle_crashed == 0:
		var key = HORN.get(_code(actor))
		if key != null:
			services.sound_follow(key, Vector3(actor.x, actor.y, actor.z))


## FUN_004D187B: the siren pitch wobble around `base`.
func _wobble(base: float) -> float:
	var result := sin(phase) * (base * 0.05000000074505806) + base
	phase = 0.019999999552965164 * 1.0 + phase
	if phase >= 360.0:
		phase = 0.0
	return result


## FUN_004D190A: update the pitch of the siren loop and (re)start it.
func _siren_pitch() -> void:
	if (services.talk.game_flags_b & 0xA3) == 0:
		if pitch <= PITCH_LOW:
			services.sound_set_value(SIREN_LOOP, int(_wobble(PITCH_LOW)))
		else:
			pitch = pitch - PITCH_STEP * 1.0
			services.sound_set_value(SIREN_LOOP, int(pitch))
	elif PITCH_HIGH <= pitch:
		services.sound_set_value(SIREN_LOOP, int(_wobble(PITCH_HIGH)))
	else:
		pitch = PITCH_STEP * 1.0 + pitch
		services.sound_set_value(SIREN_LOOP, int(pitch))
	services.sound_play(SIREN_LOOP)


## FUN_004D1A36: probe the ground at the front and back of the vehicle. Returns
## {"pitch", "front", "back"}.
func _slope(actor) -> Dictionary:
	var here := Vector3(actor.x, actor.y, actor.z)
	var fwd := Vector3(actor.field_f(0x2C), actor.field_f(0x30), actor.field_f(0x34)) * 4.0
	var front := Vector3(here.x + fwd.x, here.y + fwd.y + 6.0, here.z + fwd.z)
	var back := Vector3(here.x - fwd.x, (here.y - fwd.y) + 6.0, here.z - fwd.z)
	var drop := -4.0
	var front_found := false
	var back_found := false
	var out_front := front
	var out_back := back
	var ground := services.ground_height(front, 0.0)
	var no_ground := ground <= NO_GROUND
	if no_ground:
		drop = -8.0
	else:
		drop = ground - front.y
		out_front.y = ground
	front_found = not no_ground
	var hit = services.collide_down(actor, front, Vector3(0.0, drop, 0.0), 0x43)
	if hit != null:
		out_front = hit
	front_found = front_found or hit != null
	ground = services.ground_height(back, 0.0)
	no_ground = ground <= NO_GROUND
	if no_ground:
		drop = -8.0
	else:
		drop = ground - back.y
		out_back.y = ground
	back_found = not no_ground
	hit = services.collide_down(actor, back, Vector3(0.0, drop, 0.0), 0x43)
	if hit != null:
		out_back = hit
	back_found = back_found or hit != null
	var tilt: float = actor.field_f(0x4C)
	if front_found and back_found:
		tilt = -atan2(out_front.y - out_back.y, 8.0)
		tilt = WalkerEngine.wrap_angle(tilt)
	return {"pitch": tilt, "front": out_front, "back": out_back}


func update(actor, _block: BehaviourBlock, var_value: int) -> int:
	var g := services.talk
	var leave := false
	if (var_value & 0x20000000) != 0:
		if (actor.flags & 0x2000) == 0 or (var_value & 0x10000000) != 0:
			actor.flags &= ~0x2000
			actor.flags &= ~0x10
			if (var_value & 0x10000000) == 0:
				if g.vehicle_siren_owner == actor:
					g.vehicle_siren_owner = null
					services.sound_release(SIREN_LOOP)
				if off_road != 0:
					if (actor.flags & 1) == 0:
						timer = 1.0 * 1.0 + timer
						if 300.0 < timer:
							actor.x = start_position.x
							actor.y = start_position.y
							actor.z = start_position.z
							actor.set_field_f(0x4C, start_angles.x)
							actor.set_field_f(0x50, start_angles.y)
							actor.set_field_f(0x54, start_angles.z)
							services.set_rotation(actor, actor.field_f(0x4C), actor.field_f(0x50), actor.field_f(0x54))
							off_road = 0
							_siren_start(actor)
					else:
						timer = 0.0
			else:
				if (g.game_flags & 0x40) != 0:
					var pick := int(services.random_float(6.0))
					if pick < 5:
						if pick > 0:
							services.sound_play(CHATTER[pick - 1] if pick < 5 else CHATTER[4])
					else:
						services.sound_play(CHATTER[4])
				if g.vehicle_siren_owner == null:
					_siren_start(actor)
					g.vehicle_siren_owner = actor
				_siren_pitch()
				off_road = 1
				timer = 0.0
			leave = true
		else:
			services.sound_release(SIREN_LOOP)
	if leave:
		return 2
	_siren_follow(actor)
	if services.frame_zero():
		var slope := _slope(actor)
		actor.set_field_f(0x4C, slope["pitch"])
		var mid: Vector3 = (slope["front"] + slope["back"]) * 0.5
		services.set_matrix_at(actor, mid)
		_remember(actor)
	else:
		_remember(actor)
		var fwd := Vector3(actor.field_f(0x2C), actor.field_f(0x30), actor.field_f(0x34))
		var ahead_short := fwd * 5.28000020980835
		var ahead_far := fwd * 25.280000686645508
		var start := Vector3(start_position.x - ahead_short.x, (start_position.y - ahead_short.y) + 2.0, start_position.z - ahead_short.z)
		var stop := start + ahead_far
		var query := {"origin": start, "direction": ahead_far, "mode": 3, "size": Vector2(4.0, 4.0), "end": stop}
		var hit_something := false
		for record in services.solid_records:
			if record == null:
				break
			if record != actor and record.block != null and record.block.head != null:
				if (vars.get_var(record.block.head.tag) & 0x20000000) != 0:
					hit_something = services.collide_actor(record, query)
					if hit_something:
						break
		if not hit_something and services.all_records.size() > 16:
			var pepper = services.all_records[16]
			pepper.flags |= 0x40
			hit_something = services.collide_actor(pepper, query)
			pepper.flags &= ~0x40
		if not hit_something:
			g.vehicle_crashed = 0
			actor.flags &= ~0x2000
			if (actor.flags & 0x8000) == 0:
				actor.flags &= ~0x10
		else:
			_horn(actor)
			services.sound_follow(CRASH, Vector3(actor.x, actor.y, actor.z))
			g.vehicle_crashed = 1
			_siren_start(actor)
			if (actor.flags & 0x8000) == 0:
				actor.flags |= 0xA010
				services.actor_event(actor, 0xD)
		skip_tilt = 0
	return 2


func _remember(actor) -> void:
	start_position = Vector3(actor.x, actor.y, actor.z)
	start_angles = Vector3(actor.field_f(0x4C), actor.field_f(0x50), actor.field_f(0x54))


func has_post() -> bool:
	return true


## FUN_004D23E4: ease the tilt toward the ground slope and rebuild the matrix.
func post(actor) -> void:
	if skip_tilt == 0:
		var slope := _slope(actor)
		var wanted: float = slope["pitch"]
		var tilt: float = actor.field_f(0x4C)
		if tilt <= wanted:
			if TILT_STEP < wanted - tilt:
				tilt = tilt + TILT_STEP
			else:
				tilt = wanted
		elif TILT_STEP < tilt - wanted:
			tilt = tilt - TILT_STEP
		else:
			tilt = wanted
		actor.set_field_f(0x4C, tilt)
		var mid: Vector3 = (slope["front"] + slope["back"]) * 0.5
		services.set_matrix_at(actor, mid)
