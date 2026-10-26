class_name FlyingCraft
extends Behaviour

## FUN_004D697C (ctor) / FUN_004D5453 (update, vtable 0x008BA3D8) / FUN_004D689F (post),
## update returns 1. The flying craft that flies the W_OTH path graph (graph 3) between
## the two ends of the island, comes down to collect Pepper, carries Pepper to a landing
## chosen from the ring DAT_008BA3FC (or to the listed destination) and drops Pepper there.
## States: 0 landed, 1 coming down, 2 / 3 flying the path, 4 choosing the next leg, 5 / 7
## rising, 6 approaching Pepper, 8 lifting Pepper, 9 / 10 / 11 / 12 / 13 / 14 carrying,
## 15 setting down, 16 rising away.
##
## Node: +0x14 / +0x18 / +0x1C / +0x20 zone thresholds, +0x24 landing x, +0x28 wanted
## node, +0x2C current node, +0x30 next node, +0x34 speed, +0x38 state, +0x39 arrived,
## +0x3A turn flags, +0x3B leg, +0x3C / +0x40 turn rates, +0x44 turn timer, +0x48 / +0x4A
## ring / list destination, +0x4C carry flag, +0x50 wait timer.

## DAT_008BA3FC: the ring of landing nodes of graph 0.
const RING := [105, 97, 99, 101, 96, 98, 100, 102, 103, 104]
const SPEED := 1.600000023841858
const NEAR_NODE := 10.239999771118164
const REACH_SCALE := 15.0
const PI_F := 3.1415927410125732
const TAU_F := 6.2831854820251465
const SOUND_PRIME := 0x5D49DF0
const SOUND_LOOP := 0x5D49FC0
const SOUND_DROP := 0x5D49DC8
const CAMERA_BEHIND := Vector3(0.0, 10.0, -14.0)
const CAMERA_LEVEL := Vector3(0.0, 0.0, -14.0)
const RELEASE := [0x5D50E9C, 0x5D50E8C, 0x5D50EA4, 0x5D50E88, 0x5D50E98, 0x5D50E94, 0x5D50E84, 0x5D50E90]

var thresholds := [0.0, 0.0, 0.0, 0.0]
var landing_x := 0.0
var wanted := 0
var current := 0
var following := 0
var speed := SPEED
var state := 0
var arrived := 0
var turn_flags := 0
var leg := 0
var turn_rate_pitch := 0.0
var turn_rate_yaw := 0.0
var turn_timer := 0.0
var ring_node := 0
var list_node := 0
var carrying := 0
var wait := 0.0

var services: ActorServices
var vars


static func from_descriptor(services_in: ActorServices, vars_in, actor) -> FlyingCraft:
	var b := FlyingCraft.new()
	b.services = services_in
	b.vars = vars_in
	var north = services_in.waypoint_position(3, 0)
	var south = services_in.waypoint_position(3, 0x39)
	var z0: float = north.z
	var z1: float = south.z
	var quarter := (z0 - z1) * 0.25
	b.thresholds[0] = z0 - quarter
	b.thresholds[1] = z1 + quarter
	var tenth := (z0 - z1) * 0.10000000149011612
	b.thresholds[2] = z0 - tenth
	b.thresholds[3] = z1 + tenth
	var end := b._end_zone()
	b.speed = SPEED
	if end < 0:
		b.leg = 0
		b.wanted = b._rand5()
		b.current = 10
		b.following = b.current
		b.state = 2
	else:
		b.leg = 1
		b.wanted = end
		b.current = b.wanted
		b.current = 0x39 if b.current == 6 else 0
		b.following = b.current
		b.state = 0
	b.arrived = 0
	var at = services_in.waypoint_position(3, b.current)
	actor.y = at.y
	actor.x = at.x
	actor.z = at.z
	var landing = services_in.waypoint_position(0, 0x67)
	b.landing_x = landing.x
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


## FUN_004D49ED: -1 while Pepper is between the zone thresholds, else the end node (6 at the
## far end, 0x2F at the near end); while the turn flags are clear the speed is doubled.
func _end_zone() -> int:
	var pepper = services.all_records[16]
	if pepper.z <= thresholds[0]:
		if thresholds[1] <= pepper.z:
			return -1
		if turn_flags == 0:
			speed = SPEED + SPEED
		return 6
	if turn_flags == 0:
		speed = SPEED + SPEED
	return 0x2F


func _rand5() -> int:
	var n := 99
	while 4 < n:
		n = int(services.random_float(5.0))
	return n


## FUN_004D4AAB: the node of the ring nearest to the craft.
func _nearest_ring(actor) -> int:
	var best := 1.0e38
	var pick := -1
	for i in 10:
		var at = services.waypoint_position(0, RING[i])
		var d: Vector3 = at - Vector3(actor.x, actor.y, actor.z)
		var d2 := d.z * d.z + d.y * d.y + d.x * d.x
		if d2 < best:
			pick = i
			best = d2
	return RING[pick]


## FUN_004D4B87: the destination node of the list entry nearest to the craft.
func _nearest_list(actor) -> int:
	var best := 1.0e38
	var pick := -1
	var list: Array = services.talk.list_a
	for i in list.size():
		var entry: Dictionary = list[i]
		var at = services.waypoint_position(int(entry["table"]), int(entry["dest"]))
		if at == null:
			continue
		var d: Vector3 = at - Vector3(actor.x, actor.y, actor.z)
		var d2 := d.z * d.z + d.y * d.y + d.x * d.x
		if d2 < best:
			pick = i
			best = d2
	return int(list[pick]["dest"]) if pick >= 0 else 0


## FUN_004D4C7A: heading (yaw, pitch) and distance from the craft to a point.
func _aim(actor, to: Vector3) -> Array:
	var d := Vector3(to.x - actor.x, to.y - actor.y, to.z - actor.z)
	var horizontal := sqrt(d.x * d.x + d.z * d.z)
	var yaw := atan2(d.x, d.z)
	var pitch := atan2(-d.y, horizontal)
	return [yaw, pitch, sqrt(d.z * d.z + d.y * d.y + d.x * d.x)]


## FUN_004D4D52: put the craft on the camera, pushed back toward Pepper, facing Pepper.
func _place_near_camera(actor) -> void:
	var eye := services.camera_eye
	actor.x = eye.x
	actor.y = eye.y
	actor.z = eye.z
	var player = services.player
	var d := Vector3(player.x - actor.x, player.y - actor.y, player.z - actor.z)
	if d.length_squared() != 0.0:
		d = d / sqrt(d.length_squared()) * 1.0
	d = d * 24.0
	actor.x -= d.x
	actor.y -= d.y
	actor.z -= d.z
	actor.y += 8.0
	var aim := _aim(actor, Vector3(player.x, player.y, player.z))
	actor.yaw = aim[0]
	actor.set_field_f(0x4C, aim[1])


## FUN_004D4E68: turn toward a yaw and pitch by at most `step` a tick; true once the yaw is there.
func _steer_to(actor, yaw_target: float, pitch_target: float, step: float) -> bool:
	var yaw_diff: float = yaw_target - actor.yaw
	var pitch_diff: float = pitch_target - actor.field_f(0x4C)
	actor.set_field_f(0x54, pitch_diff)
	yaw_diff = WalkerEngine.wrap_angle(yaw_diff)
	pitch_diff = WalkerEngine.wrap_angle(pitch_diff)
	var yaw_done := false
	if step + step <= absf(yaw_diff):
		if -step * 1.0 <= yaw_diff:
			actor.yaw = step * 1.0 + actor.yaw
		else:
			actor.yaw = actor.yaw - step * 1.0
	else:
		actor.yaw = yaw_target
		yaw_done = true
	var pitch: float = actor.field_f(0x4C)
	if 2.0 * step <= absf(pitch_diff):
		if -step * 1.0 <= pitch_diff:
			pitch = step * 1.0 + pitch
		else:
			pitch = pitch - step * 1.0
	else:
		pitch = pitch_target
	actor.yaw = WalkerEngine.wrap_angle(actor.yaw)
	actor.set_field_f(0x54, WalkerEngine.wrap_angle(actor.field_f(0x54)))
	actor.set_field_f(0x4C, WalkerEngine.wrap_angle(pitch))
	services.set_rotation(actor, actor.field_f(0x4C), actor.yaw, actor.field_f(0x54))
	return yaw_done


## FUN_004D511E: fly at a point; true once closer than `reach`.
func _approach(actor, at: Vector3, reach: float, step: float) -> bool:
	var aim := _aim(actor, at)
	_steer_to(actor, aim[0], aim[1], step)
	var push := Vector3(actor.field_f(0x2C), actor.field_f(0x30), actor.field_f(0x34)) * (2.4000000953674316 * 1.0)
	actor.x += push.x
	actor.y += push.y
	actor.z += push.z
	return reach * 1.0 > float(aim[2])


## FUN_004D5223: ease the camera toward a spot behind the craft.
func _camera_ease(actor, behind: Vector3, rate: float) -> void:
	var rows := ActorServices.rotation_rows(0.0, actor.yaw, 0.0)
	var wanted_eye := Vector3(
		behind.x * rows[0] + behind.y * rows[4] + behind.z * rows[8] + actor.x,
		behind.x * rows[1] + behind.y * rows[5] + behind.z * rows[9] + actor.y + 4.0,
		behind.x * rows[2] + behind.y * rows[6] + behind.z * rows[10] + actor.z)
	services.camera_target = Vector3(actor.x, actor.y + 4.0, actor.z)
	var eye := services.camera_eye
	eye = eye + (wanted_eye - eye) * (rate * 1.0)
	services.camera_eye = eye


## FUN_004D5309: Pepper hangs under the craft.
func _carry(actor) -> void:
	var player = services.player
	vars.set_var(0x5E, 0x80)
	services.copy_matrix(player, actor)
	var rows := ActorServices.rotation_rows(actor.field_f(0x4C), actor.yaw, actor.field_f(0x54))
	player.x = player.x - rows[4] * 1.0
	player.y = player.y - rows[5] * 1.0
	player.z = player.z - rows[6] * 1.0
	player.x = player.x - rows[0] * 1.0
	player.y = player.y - rows[1] * 1.0
	player.z = player.z - rows[2] * 1.0


## FUN_004D44C0: stop the eight craft sounds.
func _release_sounds() -> void:
	for key in RELEASE:
		services.sound_release(key)


## FUN_004D4541: follow the path nodes with smoothed turns.
func _steer_path(actor) -> void:
	var here := Vector3(actor.x, actor.y, actor.z)
	var at: Vector3 = services.waypoint_position(3, current)
	var d := at - here
	var d2 := d.z * d.z + d.y * d.y + d.x * d.x
	var w := services.walkers
	if NEAR_NODE <= d2:
		if d2 < speed * REACH_SCALE * speed * REACH_SCALE:
			current = w.next_node(3, current, wanted)
			following = w.next_node(3, current, wanted)
			turn_flags = 7
			turn_timer = 0.0
	else:
		current = w.next_node(3, current, wanted)
		following = w.next_node(3, current, wanted)
		turn_flags = 4
		if current == following:
			state = 4
			return
		at = services.waypoint_position(3, current)
		d = at - here
	var horizontal := sqrt(d.x * d.x + d.z * d.z)
	var yaw_target := atan2(d.x, d.z)
	var pitch_target := atan2(-d.y, horizontal)
	var yaw_diff: float = yaw_target - actor.yaw
	var pitch_diff: float = pitch_target - actor.field_f(0x4C)
	actor.set_field_f(0x54, pitch_diff)
	if (turn_flags & 3) == 0:
		actor.set_field_f(0x4C, pitch_target)
		actor.yaw = yaw_target
		if (turn_flags & 4) != 0:
			turn_flags = 0
			var after: Vector3 = services.waypoint_position(3, following)
			var leg_vec := after - at
			var leg_horizontal := sqrt(leg_vec.x * leg_vec.x + leg_vec.z * leg_vec.z)
			var next_pitch := atan2(leg_vec.y, leg_horizontal)
			var half_yaw := absf(yaw_target - actor.yaw) * 0.5
			var half_pitch := absf(next_pitch - actor.field_f(0x4C)) * 0.5
			turn_rate_pitch = cos(half_yaw) / (sin(half_yaw) * REACH_SCALE)
			turn_rate_yaw = cos(half_pitch) / (sin(half_pitch) * REACH_SCALE)
	else:
		if turn_rate_pitch <= absf(yaw_diff):
			if -turn_rate_pitch * 1.0 <= yaw_diff:
				actor.yaw = actor.yaw - turn_rate_pitch * 1.0
			else:
				actor.yaw = turn_rate_pitch * 1.0 + actor.yaw
		else:
			actor.yaw = yaw_target
			turn_flags &= 0xFE
		if turn_rate_yaw <= absf(pitch_diff):
			var pitch: float = actor.field_f(0x4C)
			if -turn_rate_yaw * 1.0 <= pitch_diff:
				pitch = pitch - turn_rate_yaw * 1.0
			else:
				pitch = turn_rate_yaw * 1.0 + pitch
			actor.set_field_f(0x4C, pitch)
		else:
			actor.set_field_f(0x4C, pitch_target)
			turn_flags &= 0xFD
		turn_timer = 1.0 * 1.0 + turn_timer
		if REACH_SCALE < turn_timer:
			turn_flags = 0


func _set_idle(actor) -> void:
	services.set_clip(actor, 0xD2, 0.0)


func update(actor, block: BehaviourBlock, _var_value: int) -> int:
	var g := services.talk
	var player = services.player
	var records := services.all_records
	var watch = records[158].block if records.size() > 158 else null
	var watch_distance := 1.0e38 if watch == null else float(watch.distance_squared)
	var near_watch := false
	if g.machine_kind == 10:
		near_watch = watch_distance < 1024.0
	if g.machine_kind == 9 or near_watch:
		wait = 1.0 * 1.0 + wait
		if watch_distance < 576.0:
			wait = 4.0
		if 3.0 <= wait and state < 5 and 41.0 < player.y and player.y < 48.0:
			ring_node = _nearest_ring(actor)
			list_node = _nearest_list(actor)
			if services.camera_locked == 0:
				if 24.0 <= absf(player.x - landing_x):
					carrying = 0
				else:
					carrying = 1
					ring_node = 0x60 if ring_node == 0x67 else 0x67
			else:
				carrying = 0
			g.machine_actor = null
			if (actor.flags & 1) == 0 or watch_distance <= 576.0:
				state = 6
				_set_idle(actor)
				_place_near_camera(actor)
			else:
				var gap := Vector3(actor.x, actor.y, actor.z) - services.camera_eye
				if gap.length() <= 1600.0:
					if state == 0:
						state = 7
						_release_sounds()
						actor.set_field_f(0x54, 0.0)
						actor.set_field_f(0x4C, 0.0)
						services.set_clip(actor, 0x8C, 0.0)
						services.anim_set_frame(actor, services.anim_length(actor) - 1.0)
					else:
						state = 6
						_set_idle(actor)
				else:
					state = 6
					_set_idle(actor)
					_place_near_camera(actor)
	else:
		wait = 0.0
	if state < 5 and leg == 0:
		var zone := _end_zone()
		if zone > -1:
			if services.walkers.next_node(3, current, zone) < 0:
				leg = 1
			else:
				wanted = zone
				leg = 2
	var tail := true
	match state:
		0:
			var clip := services.current_clip(actor)
			if clip != 0x8C:
				var zone := _end_zone()
				arrived = 0
				if zone > -1:
					return 0
				wanted = 10
				state = 2
				turn_flags = 4
				leg = 0
				_set_idle(actor)
				tail = _fly_path(actor)
			elif services.clip_finished(actor, 1.0):
				services.set_clip(actor, 0x78, 0.0)
		1:
			var here := Vector3(actor.x, actor.y, actor.z)
			var ground := services.ground_height(here, 8.0)
			var start := Vector3(here.x, here.y + 4.0, here.z)
			var hit = services.collide_down(actor, start, Vector3(0.0, ground - start.y, 0.0), 3)
			if hit != null:
				ground = hit.y
			if 0.800000011920929 <= actor.y - ground:
				actor.y -= 0.800000011920929
			else:
				state = 0
				actor.set_field_f(0x54, 0.0)
				actor.set_field_f(0x4C, 0.0)
			if services.clip_finished(actor, 1.0):
				services.set_clip(actor, 0x78, 0.0)
		2, 3:
			tail = _fly_path(actor)
		4:
			if leg != 0:
				if leg == 1:
					var zone := _end_zone()
					if zone < 0:
						current = _rand5()
						state = 2
						following = services.walkers.next_node(3, current, wanted)
						leg = 0
					else:
						current = 0x37
						state = 2
						wanted = zone
						following = services.walkers.next_node(3, current, wanted)
				else:
					_land(actor)
			else:
				current = _rand5()
				state = 2
				following = services.walkers.next_node(3, current, wanted)
		5, 7:
			actor.y = 0.800000011920929 * 1.0 + actor.y
			services.clip_finished(actor, -1.0)
			if services.anim_frame(actor) <= 0.0:
				if not services.scene_active:
					_set_idle(actor)
					state = 6
				else:
					_set_idle(actor)
					actor.flags |= 0x10
					state = 3
					leg = 0
					current = 10
			return 1
		6:
			var there := Vector3(player.x, player.y, player.z)
			if _approach(actor, there, 6.0, 0.2617979943752289):
				if not services.scene_active:
					state = 8
					_release_sounds()
					services.sound_play(SOUND_PRIME)
					services.sound_play(SOUND_LOOP)
					services.set_clip(actor, 0x8C, 0.0)
					services.anim_set_frame(actor, services.anim_length(actor) - 1.0)
					services.set_clip(player, 0x8C, 0.0)
					services.anim_set_frame(player, services.anim_length(player) - 1.0)
					g.craft_ticks = 0
					g.craft_flag = 0
					return 1
				_set_idle(actor)
				actor.flags |= 0x10
				state = 3
				leg = 0
				current = 10
		8:
			_release_sounds()
			var at: Vector3 = services.waypoint_position(0, ring_node)
			at.y += 12.0
			if actor.y < at.y:
				actor.y = 0.800000011920929 * 1.0 + actor.y
			var frame := services.anim_frame(actor) - 1.0 * 1.0
			g.craft_ticks += 1
			if 0.0 < frame:
				services.anim_set_frame(actor, frame)
				services.set_clip(player, 0x8C, frame)
			else:
				g.machine_actor = null
				_set_idle(actor)
				_set_idle(player)
				if (vars.get_var(0x5E) & 4) != 0:
					g.craft_seen = 1
				state = 0xC if carrying == 0 else 9
			if ring_node == 0x67 or ring_node == 0x60:
				var spot: Vector3 = services.waypoint_position(0, ring_node)
				spot.y += 16.0
				var aim := _aim(actor, spot)
				_steer_to(actor, aim[0], aim[1], 0.0872659981250763)
			_carry(actor)
			_camera_ease(actor, CAMERA_BEHIND, 0.009999999776482582)
			return 1
		9:
			var at9: Vector3 = services.waypoint_position(0, ring_node)
			at9.y += 12.0
			var aim9 := _aim(actor, at9)
			if _steer_to(actor, aim9[0], aim9[1], 0.0872659981250763):
				state = 10
			_slide_to_landing(actor)
			_carry(actor)
			_camera_ease(actor, CAMERA_BEHIND, 0.009999999776482582)
			tail = true
		10:
			var at10: Vector3 = services.waypoint_position(0, ring_node)
			at10.y += 12.0
			var aim10 := _aim(actor, at10)
			_steer_to(actor, aim10[0], aim10[1], 0.0872659981250763)
			actor.flags |= 0x10
			if absf(actor.x - landing_x) < 0.4000000059604645:
				state = 0xB
				_state_11(actor)
			else:
				if landing_x <= actor.x:
					actor.x -= 0.4000000059604645
				else:
					actor.x += 0.4000000059604645
				_carry(actor)
				_camera_ease(actor, CAMERA_BEHIND, 0.009999999776482582)
		0xB:
			_state_11(actor)
		0xC:
			vars.set_var(0x5E, 0x80)
			var at12: Vector3 = services.waypoint_position(1, list_node)
			at12.y += 80.0
			actor.flags |= 0x10
			if _approach(actor, at12, 80.0, 0.0872659981250763):
				state = 0xD
			services.clip_finished(player, 1.0)
			if actor.y < at12.y:
				actor.y = 0.800000011920929 * 1.0 + actor.y
			_carry(actor)
			_camera_ease(actor, CAMERA_BEHIND, 0.03999999910593033)
		0xD:
			var at13: Vector3 = services.waypoint_position(1, list_node)
			at13.y += 16.0
			var reached13 := _approach(actor, at13, 24.0, 0.0872659981250763)
			actor.flags |= 0x10
			if reached13:
				state = 0xE
			if services.current_clip(player) == 0xD2:
				services.clip_finished(player, 1.0)
			else:
				services.set_clip(player, 0xD2, 0.0)
			_carry(actor)
			_camera_ease(actor, CAMERA_BEHIND, 0.07999999821186066)
		0xE:
			var at14: Vector3 = services.waypoint_position(1, list_node)
			var ground14 := services.ground_height(at14, 8.0)
			at14.y = ground14 + 16.0
			var reached14 := _approach(actor, at14, 4.0, 0.3490639925003052)
			actor.flags |= 0x10
			if not reached14:
				if services.current_clip(player) == 0xD2:
					services.clip_finished(player, 1.0)
				else:
					services.set_clip(player, 0xD2, 0.0)
			else:
				services.set_clip(player, 0x8C, 0.0)
				services.set_clip(actor, 0x8C, 0.0)
				state = 0xF
			_carry(actor)
			_camera_ease(actor, CAMERA_BEHIND, 0.07999999821186066)
		0xF:
			actor.y = actor.y - 1.600000023841858 * 1.0
			if not services.clip_finished(actor, 1.0):
				services.set_clip(player, 0x8C, services.anim_frame(actor))
				_carry(actor)
			else:
				g.machine_actor = null
				vars.set_var(0x5E, 1)
				services.set_clip(player, 0x1B, 0.0)
				g.pepper_clip = 0x1B
				player.y = services.ground_height(Vector3(player.x, player.y, player.z), 4.0)
				player.yaw = actor.yaw
				services.set_rotation(player, 0.0, player.yaw, 0.0)
				state = 0x10
				services.sound_play(SOUND_DROP)
				services.sound_release(SOUND_LOOP)
				leg = 0
				if records.size() > 10:
					records[10].flags &= ~2
				actor.flags |= 0x10
				services.set_clip(actor, 0x8C, services.anim_length(actor) - 1.0)
			var floor_y := services.ground_height(Vector3(player.x, player.y, player.z), 40.0)
			if player.y < floor_y:
				player.y = floor_y
			if actor.y < floor_y:
				actor.y = floor_y
			_camera_ease(actor, CAMERA_BEHIND, 0.20000000298023224)
			return 1
		0x10:
			actor.y = 1.600000023841858 * 1.0 + actor.y
			services.clip_finished(actor, -1.0)
			if services.anim_frame(actor) <= 0.0:
				_set_idle(actor)
				actor.flags &= ~0x10
				state = 3
				leg = 0
				current = 10
			return 1
	if tail:
		if status == block.frame_counter:
			services.clip_finished(actor, 1.0)
		else:
			_set_idle(actor)
	return 1


## States 2 and 3: fly the path unless it is time to land. False skips the tail work.
func _fly_path(actor) -> bool:
	var zone := _end_zone()
	if leg == 0 or zone < 0 or arrived == 0:
		_steer_path(actor)
		services.set_rotation(actor, actor.field_f(0x4C), actor.yaw, actor.field_f(0x4C))
		var push := Vector3(actor.field_f(0x2C), actor.field_f(0x30), actor.field_f(0x34)) * speed
		actor.x += push.x
		actor.y += push.y
		actor.z += push.z
	else:
		arrived = 0
		current = zone
		actor.set_field_f(0x54, 0.0)
		actor.set_field_f(0x4C, 0.0)
		_land(actor)
	return true


## The landing (LAB_004D67BD): set down on the end node and look for the next leg.
func _land(actor) -> void:
	state = 1
	services.set_clip(actor, 0x8C, 0.0)
	actor.set_field_f(0x54, 0.0)
	current = 0x39 if current == 6 else 0


func _slide_to_landing(actor) -> void:
	if 0.4000000059604645 <= absf(actor.x - landing_x):
		if landing_x <= actor.x:
			actor.x -= 0.4000000059604645
		else:
			actor.x += 0.4000000059604645
	else:
		actor.x = landing_x


## State 11: lower Pepper to the ring landing.
func _state_11(actor) -> void:
	vars.set_var(0x5E, 0x80)
	var at: Vector3 = services.waypoint_position(0, ring_node)
	at.y += 16.0
	if _approach(actor, at, 48.0, 0.0872659981250763):
		state = 0xC
	actor.flags |= 0x10
	services.clip_finished(services.player, 1.0)
	if actor.y < at.y:
		actor.y = 0.800000011920929 * 1.0 + actor.y
	_carry(actor)
	_camera_ease(actor, CAMERA_LEVEL, 0.019999999552965164)


func has_post() -> bool:
	return true


func post(_actor) -> void:
	if state > 4:
		vars.or_var(tag, 0x20000)
