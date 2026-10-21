class_name TalkNode
extends Behaviour

## FUN_0087D84E (ctor) / FUN_0087D310 (update, vtable 0x00974E88, returns 1 / 2) /
## FUN_0087D711 (post). The conversation node of an NPC: it keeps the actor on the
## ground, notices Pepper, picks the talk target, plays the talk clips and the speech
## line, and applies the var changes of a finished talk.
##
## Node: +0x14 / +0x18 squared near / far range, +0x1C short activation mask, +0x20 sound
## handle, +0x24..+0x27 option bytes, +0x28 character kind, +0x2A var to change, +0x2C
## change kind, +0x32 saved clip, +0x36 airborne, +0x37 pushed, +0x38 look-at-Pepper,
## +0x3C/+0x40/+0x44 saved position, +0x48 fall speed, +0x4C flags (2 walking to target,
## 0x10 near, 0x40 talking), +0x50 reward kind, +0x52 stage (-10 / -20 / -30 / ...),
## +0x54 timer, +0x58 / +0x59 counters, +0x5C / +0x60 queued speech.

## DAT_00974EA0, entries of five words: clip a, clip b, clip c, clip d, fall step.
const KINDS := [
	[113, 121, 130, 129, 0.032],
	[113, 121, 130, 129, 0.032],
	[113, 121, 130, 129, 0.032],
	[113, 121, 130, 129, 0.032],
	[-1, -1, 130, 129, 0.032],
	[-1, -1, 130, 129, 0.032],
]
const PI_F := 3.1415927410125732
const TAU_F := 6.2831854820251465
const NO_GROUND := -9.999999680285692e+37

var range_near := 0.0
var range_far := 0.0
var activate_mask := 0
var sound := 0
var option_a := 0
var option_b := 0
var option_c := 0
var option_d := 0
var kind := 0
var change_var := 0
var change_kind := 0
var saved_clip := 0
var airborne := 0
var pushed := 0
var look_at_pepper := 0
var saved_position := Vector3.ZERO
var fall_speed := 5.0
var flags := 0
var reward := 0
var stage := 0
var timer := 0.0
var speech_alt := 0
var tick_counter := 0
var speech_a := 0
var speech_b := 0

var services: ActorServices
var vars
var g: TalkGlobals


static func from_descriptor(desc: Descriptor, services_in: ActorServices, vars_in, actor, tag_in: int) -> TalkNode:
	var b := TalkNode.new()
	b.services = services_in
	b.vars = vars_in
	b.g = services_in.talk
	var block: BehaviourBlock = actor.block
	var tag_value: int = vars_in.get_var(tag_in)
	services_in.model_set_flag(actor, 1)
	actor.flags |= 0x40
	b.g.nearest_distance = 1.0e38
	b.g.nearest_actor = null
	b.option_a = desc.u8(0x1c)
	b.option_b = desc.u8(0x1d)
	b.option_c = desc.u8(0x1e)
	b.option_d = desc.u8(0x1f)
	if 0.0 <= desc.f32(4):
		b.range_near = desc.f32(4) * 8.0
		b.range_near = b.range_near * b.range_near
	else:
		b.range_near = desc.f32(4)
	b.range_far = desc.f32(8) * 8.0
	b.range_far = b.range_far * b.range_far
	b.fall_speed = 5.0
	b.flags = 0
	b.activate_mask = desc.s16(0x0C)
	b.kind = desc.s16(0x28)
	b.airborne = 0
	b.look_at_pepper = 0
	b.pushed = 0
	if (tag_value & 0x40000) == 0:
		b.reward = desc.s16(0)
		b.stage = desc.s16(0x20)
	else:
		b.reward = 0
		b.stage = -1
	b.change_var = desc.s16(0x2A)
	b.change_kind = desc.s16(0x2C)
	b.speech_alt = 0
	if desc.s32(0x10) >= 0:
		services_in.set_clip(actor, desc.s32(0x10), 0.0)
	var handle := services_in.walker_create(actor, desc.s32(0x14))
	block.walker = handle
	services_in.walker_set_speed(handle, 0.016666667535901070)
	services_in.walker_set_field(handle, 0x20, desc.s32(0x24))
	services_in.walker_set_field(handle, 0x40, absf(0.5235300064086914))
	services_in.walker_set_field(handle, 0x4C, 0.2)
	services_in.walker_set_field(handle, 0x50, 0.75)
	services_in.walker_set_field(handle, 0x74, 0.25)
	services_in.walker_bind(handle, actor)
	b.sound = services_in.sound_create(desc.s32(0x18))
	var start := Vector3(actor.x, actor.y + 4.0, actor.z)
	var ground := services_in.ground_height(start, 0.0)
	var drop := -128.0
	if NO_GROUND < ground:
		drop = ground - start.y
	var hit = services_in.collide_down(actor, start, Vector3(0.0, drop, 0.0), 1)
	if hit == null:
		if NO_GROUND < ground:
			actor.y = ground
	else:
		actor.x = hit.x
		actor.y = hit.y
		actor.z = hit.z
	services_in.model_set_field(actor, 0xFF, 1)
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func _kind_row() -> Array:
	return KINDS[kind]


func update(actor, block: BehaviourBlock, var_value: int) -> int:
	if (var_value & 0x4000) != 0:
		actor.flags &= ~2
		return 1
	if (actor.flags & 2) == 0:
		return 1
	if stage == -10:
		stage = -20
	elif stage == -20:
		stage = -30
		if reward != 0:
			vars.add_var(0xA6, 1000)
			vars.add_var(0x12, 1000)
			if reward == 2:
				services.reward_show(vars.get_var(0xAD) + 0x1A)
				vars.add_var(0xAD, 1)
				vars.add_var(0x4F, -1)
			reward = 0
		if change_var == 0xB0:
			vars.or_var(tag, 0x40003)
			_notify_group(actor, 3, 0)
		else:
			vars.or_var(tag, 0x40001)
			_notify_group(actor, 1, 0)
		var_value = vars.get_var(tag)
		if change_kind == 1:
			vars.set_var(change_var, 1)
		elif change_kind == 2:
			vars.add_var(change_var, 1)
		elif change_kind == 3:
			vars.add_var(change_var, -1)
			if change_var == 0xB0:
				vars.or_var(tag, 0x8000)
	if pushed != 0 and 4.326399803161621 < block.distance_squared:
		actor.x = saved_position.x
		actor.y = saved_position.y
		actor.z = saved_position.z
		pushed = 0
	var look_height := -4.4
	if airborne != 0:
		look_height = -(fall_speed * 1.0 + 4.0)
	var hint_mode := 3 if (block.flags & 0x40) != 0 else 0x43
	var origin := Vector3(0.0, 4.0, 0.0)
	var target := Vector3(0.0, look_height, 0.0)
	if airborne == 0:
		block.set_hint(origin, target, hint_mode, 0xA110)
	else:
		block.look_flags |= 0x10
		block.set_hint(origin, target, hint_mode, 0x2110)
	if (var_value & 0x2000) == 0:
		if (g.game_flags & 0x40) != 0:
			if not services.scene_active and g.busy == 0 and (vars.get_var(0x5E) & 0x11) != 0:
				if (block.flags & 0x40) == 0:
					if (flags & 0x40) == 0:
						if block.distance_squared < g.nearest_distance:
							g.nearest_distance = block.distance_squared
							g.nearest_actor = actor
					else:
						g.nearest_distance = 0.0
						g.nearest_actor = actor
			else:
				g.nearest_distance = -1.0
				g.nearest_actor = null
		if (flags & 0x40) == 0:
			return 2
		if not _talk_step(actor, block, var_value):
			flags &= ~0x40
			g.busy = 0
			vars.clear_var(0x5E, 0x100)
		return 1
	if _kind_row()[0] < 0:
		return 2
	return 1


func _notify_group(actor, mask_in: int, op: int) -> void:
	g.notify_group(actor, mask_in, op, vars)


func post(actor) -> void:
	var v: int = vars.get_var(tag)
	_stand_on_ground(actor)
	if (actor.flags & 1) == 0:
		if (v & 0xE00) != 0:
			vars.clear_var(tag, 0xE00)
	else:
		if not _bounds_check(actor, v):
			_proximity(actor, v)
			if (v & 0x20000) != 0:
				vars.clear_var(tag, 0x20000)


func has_post() -> bool:
	return true


## FUN_0087BC66: rest on top of other actors, then fall (or hold) with gravity.
func _stand_on_ground(actor) -> void:
	var block: BehaviourBlock = actor.block
	if (block.flags & 0x40) != 0:
		for other in services.all_records:
			if (other.flags & 0x40) == 0 and other.block != null and (other.block.flags & 0x40) != 0 and other.block != block:
				if absf(actor.x - other.x) < 0.1 and absf(actor.z - other.z) < 0.1 and actor.y - other.y < 0.0:
					airborne = 0
					fall_speed = 0.0
					actor.y = other.y + 2.0
	if block.hint_hold == 0:
		var y: float = actor.y
		airborne = 1
		y -= fall_speed
		if y < g.ground_min:
			y = g.ground_min
			fall_speed = 0.0
		actor.y = y
		fall_speed = _kind_row()[4] * 1.0 + fall_speed
		if 4.0 < fall_speed:
			fall_speed = 4.0
	else:
		fall_speed = 0.0
		airborne = 0


## FUN_0087BE7C: lift off / land on a platform; true while the actor is being carried.
func _bounds_check(actor, v: int) -> bool:
	var block: BehaviourBlock = actor.block
	var carried := false
	if (v & 0x40000000) != 0:
		return false
	if not ((block.flags & 0x40) != 0 or 1.6383999586105347 <= block.distance_squared or services.player.y <= actor.y + 2.4000000953674316):
		return false
	var found = _find_platform(actor)
	if found == null:
		if (v & 0x2000) == 0:
			return false
		carried = false
	else:
		carried = true
		if (v & 0x2000) == 0:
			vars.or_var(tag, 0x3000)
			v = vars.get_var(tag)
			if _kind_row()[0] >= 0:
				saved_clip = services.current_clip(actor)
				actor.flags &= ~0x40
				if found.y - actor.y <= 2.0:
					services.set_clip(actor, _kind_row()[1], 0.0)
				else:
					services.set_clip(actor, _kind_row()[0], 0.0)
	if _kind_row()[0] == -1:
		if not carried and (v & 0x2000) != 0:
			vars.clear_var(tag, 0x2000)
		carried = false
	elif not carried:
		if services.clip_finished(actor, 1.0):
			actor.flags |= 0x40
			vars.clear_var(tag, 0x2000)
			services.set_clip(actor, saved_clip, 0.0)
	else:
		services.clip_finished(actor, 1.0)
	return carried


## FUN_00875843: is the actor on one of the three moving platforms, or being lifted by
## Pepper's ride? Returns the platform point (Vector3, y used) or null.
func _find_platform(actor):
	var v: int = vars.get_var(0x5E)
	var block: BehaviourBlock = actor.block
	if v == 0:
		return null
	var here := Vector3(actor.x, actor.y, actor.z)
	for i in g.platform_records.size():
		var platform = g.platform_records[i]
		var node = g.platform_nodes[i]
		if platform == null or (platform.flags & 2) == 0 or bool(node.get("disabled")):
			continue
		var base := Vector3(platform.x, platform.y, platform.z)
		var diff := here - base
		if absf(diff.x) <= 8.0 and absf(diff.z) <= 8.0 and absf(diff.y) <= 8.0:
			var dir: Vector3 = node.get("direction") * 10.0 * 4.0
			var other := base + dir
			var fraction := services.segment_hit(base, other, here, 4.0, 5.099999904632568)
			if 0.0 <= fraction:
				return Vector3(0.0, (other.y - base.y) * fraction + base.y, 0.0)
	if g.ride_record != null and (g.ride_record.flags & 2) != 0:
		if g.ride_range < block.distance_squared:
			return null
		if g.ride_tick - 5 < int(g.ride_node.get("counter")) and (v & int(g.ride_node.get("mask"))) != 0:
			var player = services.player
			if g.ride_actor != actor:
				var d := Vector3(player.x - actor.x, player.y - actor.y, player.z - actor.z)
				var heading := atan2(d.x, d.z)
				if heading < -PI_F:
					heading += TAU_F
				elif PI_F < heading:
					heading -= TAU_F
				var off := absf(actor.yaw - heading)
				if PI_F < off:
					off = TAU_F - off
				if 0.7853939533233643 < off:
					return null
			if (block.flags & 0x40) != 0 and block.distance_squared < float(g.ride_node.get("distance")):
				g.ride_node.set("actor", actor)
				g.ride_node.set("distance", block.distance_squared)
			return Vector3(0.0, player.y + 4.0, 0.0)
	return null


## FUN_0087BA30: which side of the actor Pepper stands on (0 = out of range, else 2 /
## 4 / 8) and the squared distance; sets the facing bits of the actor's block.
func _facing(actor, limit: float, tolerance: float) -> Array:
	return TalkNode.facing(services, actor, limit, tolerance)


static func facing(services_in: ActorServices, actor, limit: float, tolerance: float) -> Array:
	var block: BehaviourBlock = actor.block
	var result := 0
	var distance: float = block.distance_squared
	block.look_flags &= ~0xE
	if distance < limit:
		var player = services_in.player
		var toward := atan2(player.x * 0.125 - actor.x * 0.125, player.z * 0.125 - actor.z * 0.125)
		if toward < -PI_F:
			toward += TAU_F
		elif PI_F < toward:
			toward -= TAU_F
		if actor.yaw < -PI_F:
			actor.yaw += TAU_F
		elif PI_F < actor.yaw:
			actor.yaw -= TAU_F
		var off: float = toward - actor.yaw
		if off < -PI_F:
			off += TAU_F
		elif PI_F < off:
			off -= TAU_F
		off = absf(off)
		if PI_F < off:
			off = TAU_F - off
		if tolerance <= off:
			if tolerance <= off - tolerance:
				block.look_flags |= 4
				result = 4
			else:
				block.look_flags |= 8
				result = 8
		else:
			block.look_flags |= 2
			result = 2
	return [result, distance]


## FUN_0087CFFF: update the proximity bits (0x200 / 0x400 / 0x500 / 0x600 / 0x700 /
## 0xD00) of the actor's var from Pepper's distance and the talk prompt.
func _proximity(actor, v: int) -> void:
	var block: BehaviourBlock = actor.block
	var set_bits := 0
	var clear_bits := 0
	if (flags & 0x40) != 0:
		return
	var facing := _facing(actor, range_far, 1.0471975803375244)
	var side: int = facing[0]
	var distance: float = facing[1]
	if distance <= range_near:
		if (v & 0x20000) == 0 and (block.flags & 0x10) != 0 and (actor.flags & 2) != 0:
			vars.or_var(0xC, 1)
		if (flags & 0x10) != 0:
			side = 2
	elif speech_alt > 0:
		speech_alt = 0
	if side == 0:
		clear_bits = 0x600
		flags &= ~0x30
	elif side == 2:
		if range_near <= distance:
			if range_far <= distance:
				flags &= ~0x30
				clear_bits = 0x600
			else:
				set_bits = 0x700
		else:
			flags |= 0x10
			if (g.game_flags & 0x40) != 0 and g.nearest_actor == actor and (v & 0x20000) == 0:
				if g.hidden_record >= 0:
					services.all_records[g.hidden_record].flags &= ~2
				_face_pepper(actor)
				if stage < 0 or (v & 0x40000) != 0:
					_begin_talk(actor)
				else:
					services.reward_show(stage)
					stage = -10
			set_bits = 0x500
			clear_bits = 0x200
	elif range_near <= distance:
		clear_bits = 0x600
		flags &= ~0x30
	elif (v & activate_mask) == activate_mask:
		if (g.game_flags & 0x40) == 0 or g.nearest_actor != actor:
			clear_bits = 0x400
		else:
			if services.sound_state(sound) == 2:
				services.sound_stop(sound)
			set_bits = 0xD00
	elif (g.game_flags & 0x40) == 0 or g.nearest_actor != actor:
		set_bits = 0x700
	else:
		set_bits = 0x500
		clear_bits = 0x200
	if (v & set_bits) != set_bits:
		vars.or_var(tag, set_bits)
		v = vars.get_var(tag)
	if (v & clear_bits) != 0:
		vars.clear_var(tag, clear_bits)


## FUN_0087C9C0: turn Pepper toward the actor and push the actor back if too close.
func _face_pepper(actor) -> void:
	var player = services.player
	var dx: float = actor.x - player.x
	var dz: float = actor.z - player.z
	var heading := atan2(dx, dz)
	if (vars.get_var(0x5E) & 0x10) == 0:
		if heading < -PI_F:
			heading += TAU_F
		elif PI_F < heading:
			heading -= TAU_F
		player.yaw = heading
		services.set_rotation(player, 0.0, player.yaw, 0.0)
		services.align_to_ground(player)
	var distance := sqrt(dz * dz + dx * dx + 0.0)
	if distance < 1.2799999713897705:
		var depth := 1.2799999713897705 - distance
		if pushed == 0:
			saved_position = Vector3(actor.x, actor.y, actor.z)
		pushed = 1
		actor.x -= actor.field_f(0x2C) * depth
		actor.y -= actor.field_f(0x30) * depth
		actor.z -= actor.field_f(0x34) * depth
	if (vars.get_var(0x5E) & 0x10) == 0:
		vars.set_var(0x5E, 1)


## FUN_0087C534: the position the actor should walk to while the talk starts, or null.
static func pick_target(services_in: ActorServices, vars_in, actor):
	var g := services_in.talk
	var v: int = vars_in.get_var(0x5E)
	var best := 1.0e38
	var chosen := -1
	if (v & 8) == 0 or g.list_mode == -1:
		match g.target_mode:
			2:
				return TalkNode._position_of(g.targets[1])
			1:
				return TalkNode._position_of(g.targets[0])
			3:
				return services_in.waypoint_position(1, g.target_waypoint)
			4:
				for i in 4:
					var record = g.targets[i]
					if record != null and (record.flags & 2) != 0 and record.block != null and record.block.distance_squared < best:
						best = record.block.distance_squared
						chosen = i
				if chosen >= 0:
					return TalkNode._position_of(g.targets[chosen])
				return null
			_:
				var picked = null
				for record in services_in.all_records:
					if (record.flags & 2) != 0 and record.block != null and record != actor:
						var other: BehaviourBlock = record.block
						if (other.flags & 0x50) != 0 and other.distance_squared < best and 8.0 < other.distance_squared:
							var head = other.head
							if head != null and head is TalkNode and head.reward != 0:
								best = other.distance_squared
								picked = record
				if picked == null:
					return null
				return TalkNode._position_of(picked)
	if g.target_mode == 2:
		return TalkNode._position_of(g.targets[0])
	var nearest := 1.0e38
	var index := -1
	var list: Array = []
	if g.list_mode == -3:
		list = g.list_a
	elif g.list_mode == -2:
		list = g.list_b
	for i in list.size():
		var entry: Dictionary = list[i]
		if int(entry.get("used", 0)) == 0:
			var at = services_in.waypoint_position(int(entry["table"]), int(entry["node"]))
			if at != null:
				var dx: float = at.x - actor.x
				var dz: float = at.z - actor.z
				var d2 := dz * dz + dx * dx
				if d2 < nearest:
					index = i
					nearest = d2
	return services_in.waypoint_position(1, index)


static func _position_of(record):
	if record == null:
		return null
	return Vector3(record.x, record.y, record.z)


## FUN_0087CBA2: Pepper steps up to the actor, the talk clips and the speech line start.
func _begin_talk(actor) -> void:
	var player = services.player
	var pblock: BehaviourBlock = player.block
	var walks := true
	if services.scene_active or g.busy != 0:
		return
	g.face_timer = 0.0
	g.talk_distance = 4.0
	flags &= ~2
	flags |= 0x40
	saved_clip = services.current_clip(actor)
	timer = 90.0
	services.set_scene_active(1)
	pblock.flags &= ~2
	if (vars.get_var(0x5E) & 0x10) == 0:
		var start := Vector3(player.x, player.y + 4.0, player.z)
		var ground := services.ground_height(Vector3(player.x, player.y, player.z), 4.0)
		var floor_y := ground
		var drop := ground - start.y
		if ground < -80.0:
			floor_y = player.y
			drop = -160.0
		var hit = services.collide_down(player, start, Vector3(0.0, drop, 0.0), 0x43)
		if hit == null:
			player.y = floor_y
		else:
			player.y = hit.y
	look_at_pepper = 1
	tick_counter += 1
	if tick_counter < 0:
		tick_counter = 0
	if (vars.get_var(0x5E) & 0x10) == 0:
		services.set_clip(player, 0x78, 0.0)
		g.pepper_clip = 0x78
	if speech_alt < 1:
		services.set_clip(actor, _kind_row()[2], 0.0)
		walks = false
	if _kind_row()[3] == -1:
		speech_alt = 0
		services.set_clip(actor, _kind_row()[2], 0.0)
		walks = false
	var prefix: String = actor.code.substr(0, 4)
	var name_a := prefix + char(65 + speech_alt * 2)
	var name_b := prefix + char(65 + speech_alt * 2 + 1)
	var first := services.speech_lookup(g.speech_table, name_a)
	var handle_a := int(first[1])
	g.speech_name = "" if first[0] == name_a else String(first[0])
	var second := services.speech_lookup(g.speech_table, name_b)
	var handle_b := int(second[1])
	if second[0] == name_b:
		handle_b = -1
	else:
		g.speech_name += String(second[0])
	if vars.get_var(9) == 0:
		speech_a = -1
		speech_b = -1
	else:
		if services.speech_idle():
			services.speech_queue(handle_a, handle_b)
			speech_a = -1
			speech_b = -1
		else:
			speech_a = handle_a
			speech_b = handle_b
		services.speech_start()
	if vars.get_var(0) != 0:
		services.subtitle_show(g.speech_name)
	services.prompt_mode(1)
	g.talk_matrix = services.matrix_snapshot(actor)
	if walks:
		var target = TalkNode.pick_target(services, vars, actor)
		if target == null:
			speech_alt = 0
		else:
			services.walker_goal_to(actor, target)
			services.set_clip(actor, _kind_row()[3], 0.0)
			flags |= 2


## FUN_0087C0A3: the running talk. Returns true while it goes on.
func _talk_step(actor, block: BehaviourBlock, _var_value: int) -> bool:
	var finished := false
	if (g.game_flags & 0x40) == 0:
		if speech_a < 0:
			timer -= 1.0 * 1.0
			if 30.0 <= timer:
				finished = false
			else:
				if vars.get_var(9) == 0:
					finished = not (0.0 <= timer)
				else:
					finished = services.speech_idle()
				if finished:
					if (flags & 2) == 0:
						timer = -1.0
					elif 15.0 < timer:
						timer = 15.0
		else:
			finished = false
			if services.speech_idle():
				services.speech_queue(speech_a, speech_b)
				speech_a = -1
				speech_b = -1
	else:
		timer = -1.0
		vars.or_var(0x5E, 0x100)
		if vars.get_var(9) != 0:
			services.speech_clear()
		finished = true
	if look_at_pepper != 0:
		look_at_pepper = 0
		services.camera_look(actor, services.player.yaw + PI_F, 1, 3.200000047683716, 0x974F20)
	if (flags & 2) == 0:
		services.clip_finished(actor, 1.0)
	else:
		var step := services.walker_step(actor, Vector3(actor.x, actor.y, actor.z))
		actor.yaw = step[1]
		services.set_matrix_at(actor, step[2])
		if 15.0 <= timer:
			if services.anim_frame(actor) < 15.0:
				services.clip_finished(actor, 1.0)
		else:
			services.anim_set_frame(actor, 29.0 - timer)
	if timer <= 2.0:
		flags &= ~2
		services.walker_goal_to(actor, null)
	if finished:
		if (vars.get_var(0x5E) & 0x10) == 0:
			services.set_clip(services.player, 0x1B, 0.0)
			g.pepper_clip = 0x1B
			vars.set_var(0x5E, 1)
		services.subtitle_clear()
		services.set_clip(actor, saved_clip, 0.0)
		services.player.block.flags |= 2
		services.set_scene_active(0)
		speech_alt += 1
		if speech_alt > 1:
			speech_alt = 0
		services.prompt_mode(0)
		services.set_face(actor, g.face_frame)
		services.camera_look(services.player, services.player.yaw, 2, 3.200000047683716, 0x974F30)
		g.talk_distance = g.talk_distance_default
		return false
	g.face_timer -= 1.0 * 1.0
	if g.face_timer <= 0.0:
		if services.random_float(100.0) <= 95.0:
			g.face_timer = 6.0
			services.set_face(actor, int(services.random_float(6.0)))
		else:
			g.face_timer = 2.0
			services.set_face(actor, int(services.random_float(4.0)) + 6)
	return true
