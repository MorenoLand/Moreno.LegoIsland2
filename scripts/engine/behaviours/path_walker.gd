class_name PathWalker
extends Behaviour

## FUN_00459290 (ctor) / FUN_0045889F (update, vtable 0x008A9618) / FUN_0045917C (post,
## returns 1). The path-walking NPC ("Human1"): it works through a table of waypoint
## steps with the walker engine, plays its walk and stop clips, turns at corners and
## runs a var action at each step.
##
## Step (8 bytes): node, value, kind, mode, clip. Node: +0x14 steps, +0x18 count (a
## count <= 0 picks nodes at random; -1..-5 select the pick rule), +0x19 repeat, +0x1A
## walk clip, +0x1C stop clip, +0x20 speed, +0x28 last node, +0x2A step, +0x2B previous
## step, +0x2C turn angle, +0x30 turning, +0x31 clip countdown, +0x33 stopped, +0x34 timer.

## DAT_008A95E8: random pick table for the walker nodes (two rows of six).
const PICK := [
	[26, 31, 96, 99, 307, 345],
	[44, 46, 47, 113, 119, 282],
]
const CANARY := -107374176.0
const ANGLE_STEP := 0.1745319962501526
const TURN_END := 1.5707879066467285

var steps: Array = []
var count := 0
var repeat := 0
var walk_clip := 0
var stop_clip := 0
var speed := 0.0
var last_node := -1
var step_index := 0
var previous_step := -1
var turn_angle := 0.0
var turning := 0
var clip_countdown := 0
var stopped := 0
var timer := 0.0

var services: ActorServices
var vars
## DAT_008A9630 / 9634 / 9638: what the last pick did.
static var last_pick := [0, 0, 0]


static func from_descriptor(desc: Descriptor, services_in: ActorServices, vars_in, actor) -> PathWalker:
	var b := PathWalker.new()
	b.services = services_in
	b.vars = vars_in
	var n := desc.u8(0x50)
	if n >= 128:
		n -= 256
	b.count = n
	if desc.s16(0x54) == 0:
		b.stop_clip = 0x78
	else:
		b.stop_clip = desc.s16(0x54)
	b.repeat = desc.u8(0x51) if b.count > 0 else 0
	for i in maxi(n, 0):
		var step := {
			"node": desc.s16(i * 2),
			"value": desc.s16(0x14 + i * 2),
			"kind": desc.u8(0x3C + i),
			"mode": desc.u8(0x46 + i),
			"clip": 0x78 if desc.s16(0x28 + i * 2) == 0 else desc.s16(0x28 + i * 2),
		}
		b.steps.append(step)
	b.step_index = 0
	b.last_node = -1
	b.previous_step = -1
	if not services_in.has_anim(actor):
		b.walk_clip = -1
	else:
		b.walk_clip = desc.s16(0x52)
	b.speed = services_in.walkers.speed(actor.block.walker)
	if 0.0 < desc.f32(0x58):
		b.speed = b.speed * desc.f32(0x58)
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


## FUN_00458539: pick the next node at random; code -1 any node, -2 / -3 / -4 / -5 the
## tables, and when the walker is already on a table node it takes the one that joins.
func _pick(code: int, handle: int, again: bool) -> int:
	var w := services.walkers
	var g := PathWalker.last_pick
	if code == -5 or again:
		var row := 1 if code == -3 else 0
		var from_node := w.from_node(handle)
		var goal := w.goal_node(handle)
		var graph := w.graph_of(handle)
		for pass_index in 2:
			for col in 6:
				var n := w.next_node(graph, goal, PICK[row][col])
				if n == from_node and n != goal:
					g[0] = 1
					g[1] = row
					g[2] = col
					return PICK[row][col]
			row = 1 if row == 0 else 0
	if code == -1:
		g[0] = 2
		return int(services.random_float(float(w.node_count(w.graph_of(handle)))))
	var index := int(services.random_float(6.0))
	if code == -2:
		g[0] = 3
		return PICK[0][index]
	if code == -3:
		g[0] = 4
		return PICK[1][index]
	if code == -4 or code == -5:
		if services.random_float(10.0) < 5.0:
			g[0] = 6
			return PICK[0][index]
		g[0] = 5
		return PICK[1][index]
	g[0] = 7
	return int(services.random_float(float(w.node_count(w.graph_of(handle)))))


## FUN_00458772: move to the next table step; modes 1 / 2 teleport the actor to the node.
func _advance(actor, block: BehaviourBlock) -> int:
	var done := 0
	if count <= step_index:
		step_index = 0
	var step: Dictionary = steps[step_index]
	if step["mode"] == 4:
		actor.flags &= ~2
	elif step["mode"] != 0 and (step["mode"] == 1 or (step["mode"] == 2 and (actor.flags & 1) == 0)):
		actor.set_field_f(0x54, 0.0)
		actor.set_field_f(0x4C, 0.0)
		services.walkers.place_at_node(block.walker, step["node"], actor)
		previous_step = step_index
		last_node = step["node"]
		done = 1
	return done


## FUN_00458472: run the var action of the step just finished.
func _act(actor) -> void:
	if count > 0:
		var step: Dictionary = steps[previous_step]
		if step["kind"] == 8:
			if services.has_anim(actor):
				services.set_clip(actor, step["clip"], 0.0)
			timer = float(step["value"])
		else:
			FlagSetterBehaviour.apply_op(vars, step["kind"], tag, step["value"], actor, services.talk)


## FUN_00458320: is something solid in front of the actor.
func _obstacle(actor) -> bool:
	var forward := Vector3(actor.field_f(0x2C), actor.field_f(0x30), actor.field_f(0x34)) * 4.0
	var query := {
		"origin": Vector3(actor.x, actor.y + 2.0, actor.z),
		"direction": forward,
		"mode": 3,
		"size": Vector2(1.0, 1.0),
	}
	for record in services.solid_records:
		if record == null:
			break
		if record != actor and record.block != null and record.block.head != null:
			if (vars.get_var(record.block.head.tag) & 0x20000000) != 0:
				if services.collide_actor(record, query):
					return true
	return false


func update(actor, block: BehaviourBlock, _var_value: int) -> int:
	var w := services.walkers
	var handle := block.walker
	var running := status == block.frame_counter
	if timer > 0.0:
		timer -= 1.0
		if services.has_anim(actor):
			services.clip_finished(actor, 1.0)
			if timer <= 0.0:
				clip_countdown = 2
		return 1
	var stop_to_play := 0
	var out_of_bounds := false
	if absf(actor.x) > 600.0 or absf(actor.y) > 300.0 or absf(actor.z) > 600.0:
		out_of_bounds = true
	if out_of_bounds:
		w.place_at_node(handle, 0xA4, actor)
	var walking_state := w.state(handle)
	var not_walking := walking_state != 2
	var route := w.route_target(handle)
	if not running and repeat != 0:
		step_index = 0
	if not running or ((count > 0 and route != steps[step_index]["node"]) or not_walking):
		if count < 1:
			if count == -5:
				route = _pick(count, handle, false)
		else:
			_advance(actor, block)
			route = steps[step_index]["node"]
		w.set_route(handle, route, 0)
		w.set_speed(handle, speed)
		w.hold(handle)
	var position := Vector3(actor.x, actor.y, actor.z)
	var yaw: float = actor.yaw
	var side := 0
	if services.has_anim(actor):
		side = int(TalkNode.facing(services, actor, 2.4000000953674316, 1.3962630033493042)[0])
	if side != 2 and _obstacle(actor):
		side = 2
	var result := 0
	var moved := 0.0
	if side == 2:
		result = w.goal_node(handle)
		w.finish(handle)
		stopped = 1
		if services.has_anim(actor) and stop_clip > 0:
			stop_to_play = stop_clip
		timer = 30.0
	else:
		if stopped != 0:
			w.hold(handle)
			stopped = 0
		var step := w.step(handle, position, yaw)
		result = step[0]
		yaw = step[1]
		position = step[2]
		moved = step[3]
		if not w.blocked(handle):
			if w.waiting(handle):
				if count < 0:
					route = _pick(count, handle, true)
					w.set_route(handle, route, 0)
				if services.has_anim(actor) and stop_clip > 0:
					stop_to_play = stop_clip
					timer = 30.0
		else:
			turning = 1
	var pose_a := Vector3.ZERO
	if turning == 0:
		if 0.0 < turn_angle:
			turn_angle -= ANGLE_STEP * 1.0
			if turn_angle < 0.0:
				turn_angle = 0.0
				services.set_clip(actor, walk_clip, 0.0)
			pose_a.y = sin(turn_angle) * 6.0
			block.set_hint(pose_a, Vector3(CANARY, CANARY, CANARY), 0x41, 0x110)
	else:
		var pose_b := Vector3(0.0, -16.0, 0.0)
		if TURN_END <= turn_angle:
			turning = 0
		else:
			if services.current_clip(actor) != 0x116:
				services.set_clip(actor, 0x116, 0.0)
			turn_angle += ANGLE_STEP * 1.0
			if TURN_END <= turn_angle:
				turn_angle = 1.5707963705062866
				turning = 0
		pose_a.y = sin(turn_angle) * 6.0
		block.set_hint(pose_a, pose_b, 0x41, 0x110)
	if result == -1 and count == 1:
		previous_step = step_index
		_act(actor)
	else:
		block.look_flags |= 0x10
		if stop_to_play != 0:
			services.set_clip(actor, stop_clip, 0.0)
		if last_node != result and last_node > -1:
			if previous_step > -1:
				_act(actor)
			last_node = -1
			previous_step = -1
		if result == route or result == -1:
			if count < 1:
				var picked := _pick(count, handle, false)
				w.set_route(handle, picked, 1)
			elif count != 1:
				previous_step = step_index
				last_node = route
				step_index += 1
				if _advance(actor, block) != 0:
					position = Vector3(actor.x, actor.y, actor.z)
				w.set_route(handle, steps[step_index]["node"], 1)
		actor.yaw = yaw
		services.set_matrix_at(actor, position)
		if running:
			if clip_countdown == 1:
				services.set_clip(actor, walk_clip, 0.0)
				clip_countdown = 0
			elif walk_clip > -1 and services.has_anim(actor) and 0.0001 < moved and timer <= 0.0 and services.clip_finished(actor, 1.0):
				if turn_angle <= 0.0:
					services.set_clip(actor, walk_clip, services.anim_frame(actor))
				else:
					services.set_clip(actor, 0x116, 0.0)
			if clip_countdown != 0:
				clip_countdown -= 1
		elif walk_clip > -1 and services.has_anim(actor) and services.current_clip(actor) != walk_clip:
			clip_countdown = 2
	return 1
