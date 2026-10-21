class_name BoatDrive
extends Behaviour

## FUN_0087B32C (ctor) / FUN_00879E62 (update, vtable 0x00974DF0) / FUN_0087AC09 (post),
## update returns 0 / 1. A boat Pepper can drive (SPBT speedboat, JSKI jet ski, DNGY
## dinghy): chosen like the other rideables, then driven with the controls over the sea,
## with its engine sound pitched by the throttle, a wake and a plume, bumping to a halt
## against the shore, wrapping at the edge of the map and docking at a free landing.
##
## Node: +0x18 hull, +0x1C / +0x20 / +0x24 wake records, +0x28 plume, +0x2C plume scale,
## +0x38 state (0 docked, 1 driving, 2 heading to a dock), +0x3A dock slot, +0x3C speed,
## +0x40 pitch wobble phase, +0x44 engine pitch, +0x48 smoothed steering, +0x4C extent,
## +0x58 fast.

const SPEEDBOAT := "SPBT"
const JETSKI := "JSKI"
const DINGHY := "DNGY"
## DAT_00974E08.. : engine pitch (running, idle, step) per boat.
const ENGINE := {
	"S": [11443.0, 9966.0, 36.0],
	"D": [11500.0, 10738.0, 25.0],
	"J": [12237.0, 10253.0, 66.0],
}
const ENGINE_SOUND := {"S": "eb0", "J": "ebc", "D": "e9c"}
const WRAP_HALF := {6: 880.0, 10: 1840.0, 22: 1840.0}
const WRAP_DEFAULT := 1040.0
const LIMIT_RANGE := 24.0
const DOCK_NEAR := 576.0
const DOCK_REACH := 0.6399999856948853
const PLUME_EXTENT_RATE := 0.25

var hull = null
var wake_a = null
var wake_b = null
var wake_c = null
var plume := 0
var plume_scale := 0.0
var state := 0
var dock_slot := -1
var speed := 0.0
var wobble := 0.0
var pitch := 0.0
var steer_smooth := 0.0
var extent := 0.0
var fast := 0
var sounds := {}

var services: ActorServices
var vars


static func from_descriptor(desc: Descriptor, services_in: ActorServices, vars_in, actor) -> BoatDrive:
	var b := BoatDrive.new()
	b.services = services_in
	b.vars = vars_in
	b.state = 0
	b.speed = 0.0
	b.steer_smooth = 0.0
	b.hull = desc.refs.get(4, null)
	if b.hull != null:
		b.hull.flags |= 0x10
		services_in.model_set_field(b.hull, 0xFF, 2)
	b.wake_a = desc.refs.get(8, null)
	if b.wake_a != null:
		b.wake_a.flags |= 0x10
		b.wake_a.flags &= ~2
	b.wake_b = desc.refs.get(12, null)
	if b.wake_b != null:
		b.wake_b.flags |= 0x10
		b.wake_b.flags &= ~2
		services_in.model_set_field(b.wake_b, 0xFF, 2)
		b.fast = 0
	b.wake_c = desc.refs.get(16, null)
	if b.wake_c != null:
		b.wake_c.flags |= 0x10
		b.wake_c.flags &= ~2
		services_in.model_set_field(b.wake_c, 0xFF, 2)
	b.sounds = {
		"ebc": services_in.sound_create(0x8D),
		"e9c": services_in.sound_create(299),
		"eb0": services_in.sound_create(0x129),
		"ea0": services_in.sound_create(0x332),
	}
	var g := services_in.talk
	var best := 6400.0
	var chosen := -1
	for i in g.list_b.size():
		var entry: Dictionary = g.list_b[i]
		if int(entry.get("used", 0)) == 0:
			var at = services_in.waypoint_position(int(entry["table"]), int(entry["node"]))
			if at != null:
				var dx: float = at.x - actor.x
				var dz: float = at.z - actor.z
				if absf(dx) <= 80.0 and absf(dz) <= 80.0 and dz * dz + dx * dx < best:
					chosen = i
					best = dz * dz + dx * dx
	if chosen < 0:
		b.dock_slot = -1
	else:
		g.list_b[chosen]["used"] = 1
		b.dock_slot = chosen
	var extents := services_in.model_extents(actor)
	b.extent = extents[1].z
	b.plume = services_in.particle_create("BOATPLUME", actor, Vector3(0.0, 1.0, -b.extent), Vector3(-1.5707963705062866, 0.0, 0.0))
	b.pitch = 9966.0
	b.wobble = 0.0
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func _key(actor) -> String:
	return String(actor.code).substr(0, 1)


## FUN_00879AB0: the engine pitch wobble around `base`.
func _engine_wobble(base: float) -> float:
	var result := sin(wobble) * (base * 0.05) + base
	wobble = 1.0 * 0.05 + wobble
	if 360.0 <= wobble:
		wobble = 0.0
	return result


## FUN_00879B26 / 00879C3A / 00879D4E: set the engine sound pitch from the held controls.
func _engine_sound(actor) -> void:
	var key := _key(actor)
	var run: Array = ENGINE.get(key, ENGINE["S"])
	var sound = sounds.get(ENGINE_SOUND.get(key, "eb0"))
	var held: int = services.talk.game_flags_b
	if (held & 0xA3) == 0:
		if pitch <= run[1]:
			services.sound_set_value(sound, int(_engine_wobble(run[1])))
		else:
			pitch = pitch - run[2] * 1.0
			services.sound_set_value(sound, int(pitch))
	elif run[0] <= pitch:
		var loud = sounds["ebc"] if key == "D" else sound
		services.sound_set_value(loud, int(_engine_wobble(run[0])))
	else:
		pitch = run[2] * 1.0 + pitch
		services.sound_set_value(sound, int(pitch))
	services.sound_play(sound)


## FUN_0087EC2C: carry the boat (and the camera) to the opposite edge when it leaves the map.
func _wrap(actor) -> void:
	var half: float = WRAP_DEFAULT
	var area: int = vars.get_var(0x59)
	if WRAP_HALF.has(area):
		half = WRAP_HALF[area]
	var table := [0.0, 0.0, -half, half, 0.0, 0.0, 0.0, 0.0, half, -half, 0.0, 0.0]
	var pick := -1
	if table[2] - 16.0 <= actor.z:
		if actor.x <= table[3] + 16.0:
			if actor.z <= table[8] + 16.0:
				if actor.x < table[9] - 16.0:
					pick = 3
			else:
				pick = 0
		else:
			pick = 9
	else:
		pick = 6
	if pick >= 0:
		var dx: float = table[pick] - floor(actor.x)
		var dz: float = table[pick + 2] - floor(actor.z)
		var eye := services.camera_eye
		eye.x += dx
		eye.z += dz
		services.camera_eye = eye
		var target := services.camera_target
		target.x += dx
		target.z += dz
		services.camera_target = target
		if actor != services.player:
			services.player.x += dx
			services.player.z += dz
		actor.x += dx
		actor.z += dz


func update(actor, block: BehaviourBlock, var_value: int) -> int:
	var g := services.talk
	var player = services.player
	if (player.block.flags & 2) == 0:
		return 0
	if var_value == 0:
		if services.scene_active:
			return 0
		if g.machine_actor == actor or ((g.game_flags & 0x10) != 0 and (actor.flags & 2) != 0 and block.distance_squared < g.machine_distance and 0.0 < block.distance_squared):
			g.boat_taken = 1
			g.machine_actor = actor
			g.machine_distance = block.distance_squared
			return 1
		services.particles(plume, 1)
		if wake_a != null:
			if (actor.flags & 2) == 0:
				wake_a.flags &= ~2
			else:
				wake_a.flags |= 2
			services.set_matrix_at(wake_a, Vector3(actor.x, actor.y, actor.z))
			wake_a.set_field_f(0x4C, actor.field_f(0x4C))
			wake_a.set_field_f(0x50, actor.field_f(0x50))
			wake_a.set_field_f(0x54, actor.field_f(0x54))
		if block.distance_squared < g.machine_distance and (actor.flags & 2) != 0:
			vars.or_var(0xC, 8)
		return 0
	var here := Vector3(actor.x, actor.y, actor.z)
	var forward := Vector3(actor.field_f(0x2C), 0.0, actor.field_f(0x34))
	here.y -= sin(-actor.field_f(0x4C)) * extent
	var yaw: float = actor.yaw
	var steer_in := 0.0
	var throttle := 0.0
	if state == 1:
		for entry in g.list_b:
			if int(entry.get("used", 0)) == 0:
				var at = services.waypoint_position(int(entry["table"]), int(entry["node"]))
				if at != null:
					var d: Vector3 = at - here
					if absf(d.x) <= LIMIT_RANGE and absf(d.z) <= LIMIT_RANGE and d.z * d.z + d.x * d.x < DOCK_NEAR:
						vars.or_var(0xC, 0x80)
						break
		_engine_sound(actor)
		if (g.game_flags & 0x10) == 0:
			var held: int = g.game_flags_b
			if (held & 0x80) == 0 or (held & 0x20) != 0:
				if (held & 0x20) != 0 and (held & 0x80) == 0:
					g.axis_y = 0x7F
			else:
				g.axis_y = -0x7F
			if (held & 1) == 0 or (held & 2) != 0:
				if (held & 2) != 0 and (held & 1) == 0:
					g.axis_x = 0x7F
			else:
				g.axis_x = -0x7F
			steer_in = float(g.axis_x) / 127.0
			throttle = float(-g.axis_y) / 127.0
			if absf(steer_in) < 0.20000000298023224:
				steer_in = 0.0
			if absf(throttle) < 0.20000000298023224:
				throttle = 0.0
		else:
			state = 2
	elif state == 0:
		if dock_slot > -1:
			g.list_b[dock_slot]["used"] = 0
		state = 1
	elif state == 2:
		var near_index := -1
		var near_d2 := 576.0
		for i in g.list_b.size():
			var entry: Dictionary = g.list_b[i]
			if int(entry.get("used", 0)) == 0:
				var at = services.waypoint_position(int(entry["table"]), int(entry["node"]))
				if at != null:
					var d: Vector3 = at - here
					if absf(d.x) <= LIMIT_RANGE and absf(d.z) <= LIMIT_RANGE and d.z * d.z + d.x * d.x < near_d2:
						near_index = i
						near_d2 = d.z * d.z + d.x * d.x
		if near_index < 0:
			state = 1
		else:
			var entry: Dictionary = g.list_b[near_index]
			var at = services.waypoint_position(int(entry["table"]), int(entry["node"]))
			var d: Vector3 = at - here
			var d2: float = d.z * d.z + d.x * d.x
			if d2 <= DOCK_REACH:
				speed = 0.0
				state = 0
				var land = services.waypoint_position(int(entry["table"]), int(entry["land"]))
				player.y = land.y
				player.x = land.x
				player.z = land.z
				vars.clear_var(0x5E, 0x1FF)
				vars.set_var(0x5E, 1)
				vars.set_var(tag, 0)
				services.set_clip(player, 0x1B, 0.0)
				g.pepper_clip = 0x1B
				g.machine_actor = null
				vars.set_var(0xC5, 4)
				dock_slot = near_index
				entry["used"] = 1
				services.sound_release(sounds["ebc"])
				services.sound_release(sounds["e9c"])
				services.sound_release(sounds["eb0"])
			else:
				here.x = d.x * 0.125 * 1.0 + here.x
				here.z = d.z * 0.125 * 1.0 + here.z
				speed = 0.0
	steer_smooth = (steer_in - steer_smooth) * 0.125 * 1.0 + steer_smooth
	steer_in = steer_smooth
	var reverse_part := 0.0 if speed < 0.0 else 0.5
	yaw = steer_in * 0.06283185482025147 * (speed * 0.390625 + reverse_part) * 1.0 + yaw
	if speed <= 0.0:
		actor.set_field_f(0x4C, 0.0)
	else:
		actor.set_field_f(0x4C, -(speed * 0.06872234120965004))
	actor.set_field_f(0x54, -(steer_in * 0.4398229837417603 * speed * 0.390625))
	if throttle < 0.0:
		speed = throttle * 0.06400000303983688 * 1.0 + speed
	else:
		speed = throttle * 0.11999999731779099 * 1.0 + speed
	speed = speed - speed * 0.029999999329447746 * 1.0
	var before := here
	var move := Vector3(speed * forward.x, 0.0, speed * forward.z)
	var probe := Vector3(here.x, g.ground_min + 2.799999952316284, here.z)
	here.x = move.x * 1.0 + here.x
	here.z = move.z * 1.0 + here.z
	var hit_a = services.collide_sweep(actor, probe, Vector3(move.x * 1.0, 0.0, move.z * 1.0), 3, 0.800000011920929, 2.0)
	var floor_probe := Vector3(here.x, g.ground_min, here.z)
	var hit_b = services.collide_sweep(actor, floor_probe, Vector3(0.0, 8.0, 0.0), 3, 0.800000011920929, 2.0)
	if hit_a != null or hit_b != null:
		here = before
		move = Vector3.ZERO
		if speed != 0.0:
			services.sound_play(sounds["ea0"])
		speed = 0.0
	actor.yaw = yaw
	var tilt: float = actor.field_f(0x4C)
	var lifted := Vector3(here.x, sin(-tilt) * extent + before.y, here.z)
	services.set_actor_matrix(actor, Vector3(tilt, yaw, actor.field_f(0x54)), lifted, Vector3.ONE)
	var steps := int((services.anim_length(player) - 1.0) * 0.5)
	var frame := int(float(steps) + float(steps) * steer_in)
	services.anim_set_frame(player, float(frame))
	var eye := services.camera_eye
	eye.x = ((here.x + forward.x * -40.0) - eye.x) * 0.3499999940395355 * 1.0 + eye.x
	eye.y = ((before.y + 16.0) - eye.y) * 0.3499999940395355 * 1.0 + eye.y
	eye.z = ((here.z + forward.z * -40.0) - eye.z) * 0.3499999940395355 * 1.0 + eye.z
	services.camera_eye = eye
	services.camera_target = Vector3(here.x, before.y + 8.0, here.z)
	_wrap(actor)
	return 1


func has_post() -> bool:
	return true


func post(actor) -> void:
	var g := services.talk
	if hull != null:
		var wake := 0.0
		var scale_a := 0.0
		if speed <= 0.0:
			scale_a = 0.0
			wake = 0.0
			fast = 0
			plume_scale = 0.0
		else:
			scale_a = speed + speed
			if speed <= 2.0:
				wake = 0.0
				fast = 0
			else:
				fast = 1
				wake = scale_a
			services.particles(plume, 2)
			plume_scale = (speed / 4.0) * 0.25
		services.particle_scale(plume, 2, plume_scale)
		services.particle_scale(plume, 3, plume_scale)
		hull.flags &= ~2
		var yaw_now: float = actor.field_f(0x50)
		var along := Vector3(actor.field_f(0x2C), 0.0, actor.field_f(0x34))
		var base := Vector3(actor.x, g.ground_min, actor.z)
		services.set_actor_matrix(wake_a, Vector3(0.0, yaw_now, 0.0), base, Vector3(2.0 * scale_a, 1.0, 2.0 * scale_a))
		services.set_actor_matrix(wake_b, Vector3(0.0, yaw_now, 0.0), base, Vector3(wake, scale_a * 1.25, wake))
		var push := along * extent
		wake_b.x -= push.x
		wake_b.y = g.ground_min - 1.5
		wake_b.z -= push.z
		if wake_c != null:
			services.set_actor_matrix(wake_c, Vector3(0.0, yaw_now, 0.0), base, Vector3(2.0 * scale_a, scale_a + scale_a, 2.0 * scale_a))
			wake_c.x += push.x
			wake_c.z += push.z
			wake_c.y = g.ground_min - 0.05 * speed
			wake_c.set_field_f(0x4C, actor.field_f(0x4C))
			wake_c.set_field_f(0x50, actor.field_f(0x50))
			wake_c.set_field_f(0x54, actor.field_f(0x54))
		var lead := 1.0 - speed * 0.25
		wake_a.x += lead * push.x
		wake_a.z += lead * push.z
		wake_b.set_field_f(0x4C, actor.field_f(0x4C))
		wake_b.set_field_f(0x50, actor.field_f(0x50))
		wake_b.set_field_f(0x54, actor.field_f(0x54))
		wake_a.set_field_f(0x4C, actor.field_f(0x4C))
		wake_a.set_field_f(0x50, actor.field_f(0x50))
		wake_a.set_field_f(0x54, actor.field_f(0x54))
	actor.y = g.ground_min
	if ((g.game_flags & 0x10) != 0 or g.boat_taken != 0) and g.machine_actor == actor and not services.scene_active:
		g.boat_taken = 0
		vars.set_var(tag, 1)
		vars.set_var(0x5E, 8)
		var code := String(actor.code).substr(0, 4)
		var clip := services.current_clip(player_record())
		if code == SPEEDBOAT:
			if clip != 0x4C:
				services.set_clip(player_record(), 0x4C, 0.0)
		elif code == JETSKI:
			if clip != 0x6F:
				services.set_clip(player_record(), 0x6F, 0.0)
		elif code == DINGHY:
			if clip != 0x6E:
				services.set_clip(player_record(), 0x6E, 0.0)
		g.list_mode = -2


func player_record():
	return services.player
