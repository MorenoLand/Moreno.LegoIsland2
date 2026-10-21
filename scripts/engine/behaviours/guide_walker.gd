class_name GuideWalker
extends Behaviour

## FUN_004CE238 (ctor) / FUN_004CD241 (update, vtable 0x008B9DC8) / FUN_004CE152 (post),
## update returns 1, post returns 1. A character that leads along a ring of seven path
## nodes (DAT_008B9DE0) or to a given node: it waits for its target (Pepper unless set),
## walks to the next node of the ring, turns at corners with a side step and runs a var
## action when it has arrived. It freezes while the actor has been out of sight for more
## than 90 ticks (the post counts them).
##
## Node: +0x14 node (-1 follow the ring, -2 never time out), +0x16 / +0x18 / +0x1A var
## action (var, value, kind), +0x1C target record, +0x20 idle clip (0xDA default), +0x24
## state (0 look, 1 wait for the clip, 2 walk, 3 turn to the next node), +0x28 / +0x2A last
## and current ring node, +0x2C unseen counter, +0x30 patience, +0x34 timer, +0x38..+0x40
## offset from the node.

## DAT_008B9DE0: the ring of path nodes.
const RING := [369, 370, 371, 372, 373, 374, 375]
const UNSEEN_LIMIT := 90.0
const PATIENCE := 300.0
const ANGLE_LIMIT := 0.1745319962501526
const HALF_PI := 1.5707963705062866
const PI_F := 3.1415927410125732
const TAU_F := 6.2831854820251465

var node_id := 0
var action_value := 0
var action_var := 0
var action_kind := 0
var target = null
var idle_clip := 0xDA
var state := 0
var last_index := 0
var index := 0
var unseen := 0.0
var patience := 0.0
var timer := 0.0
var offset := Vector3.ZERO

var services: ActorServices
var vars


static func from_descriptor(desc: Descriptor, services_in: ActorServices, vars_in, actor) -> GuideWalker:
	var b := GuideWalker.new()
	b.services = services_in
	b.vars = vars_in
	b.unseen = 0.0
	b.index = 0
	b.state = 0
	b.timer = 0.0
	b.patience = 0.0
	b.node_id = desc.s16(4)
	b.action_var = desc.s16(6)
	b.action_value = desc.s16(8)
	b.action_kind = desc.s16(10)
	b.target = desc.refs.get(12, null)
	b.idle_clip = 0xDA if desc.s32(0) == 0 else desc.s32(0)
	if b.node_id < 1:
		services_in.walkers.place(actor.block.walker, RING[b.index])
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


func _waypoint(index_in: int) -> Vector3:
	var at = services.waypoint_position(1, index_in)
	return at if at != null else Vector3.ZERO


func _target_node() -> int:
	return RING[index] if node_id < 0 else node_id


func _rotate(actor) -> void:
	services.set_rotation(actor, actor.field_f(0x4C), actor.field_f(0x50), actor.field_f(0x54))


func _forward(actor) -> Vector3:
	return Vector3(actor.field_f(0x2C), actor.field_f(0x30), actor.field_f(0x34))


func _normalised(v: Vector3) -> Vector3:
	if v.length_squared() == 0.0:
		return v
	return v / sqrt(v.length_squared()) * 1.0


func update(actor, block: BehaviourBlock, _var_value: int) -> int:
	if unseen > UNSEEN_LIMIT:
		return 1
	var w := services.walkers
	var handle := block.walker
	if block.frame_counter != status:
		match state:
			0:
				services.set_clip(actor, 0xB4, 0.0)
			1:
				services.set_clip(actor, 0x90, 0.0)
			_:
				services.set_clip(actor, idle_clip, 0.0)
		if block.frame_counter < 10 or vars.get_var(0x58) == 0x36:
			if node_id > 0:
				w.place(handle, node_id)
			else:
				w.place(handle, RING[index])
	var lane := w.lane(handle) * 8.0
	match state:
		1:
			if services.clip_finished(actor, 1.0):
				state = 0
				services.set_clip(actor, 0xB4, 0.0)
				_lead(actor, block, handle, lane)
		0:
			_lead(actor, block, handle, lane)
		2:
			block.look_flags |= 0x10
			var step := w.step(handle, Vector3(actor.x, actor.y, actor.z), actor.yaw)
			actor.yaw = step[1]
			actor.x = step[2].x
			actor.y = step[2].y
			actor.z = step[2].z
			_rotate(actor)
			if step[0] == -1:
				services.set_clip(actor, 0xB4, 0.0)
				state = 0
				timer = 0.0
				w.place(handle, RING[index])
			else:
				var push := _forward(actor) * (0.4000000059604645 * 1.0)
				actor.x += push.x
				actor.y += push.y
				actor.z += push.z
				services.clip_finished(actor, 1.0)
		3:
			_turn(actor, block, lane)
	return 1


## State 0 (and the end of state 1): lead the target, step aside at corners, pick the
## next ring node when the wait is over.
func _lead(actor, block: BehaviourBlock, handle: int, lane: float) -> void:
	if target == null:
		target = services.player
	var there := Vector3(target.x, target.y, target.z)
	var here := Vector3(actor.x, actor.y, actor.z)
	var way := _waypoint(RING[index] if node_id < 0 else node_id)
	var to_target := Vector3(there.x - here.x, 0.0, there.z - here.z)
	var arrived := false
	if node_id == -2:
		arrived = false
	else:
		patience = 1.0 * 1.0 + patience
		if patience <= PATIENCE:
			arrived = false
		else:
			arrived = true
			patience = 0.0
	if not arrived:
		var from_node := there - way
		var to_node := way - here
		var ahead_heading := _wrap(atan2(from_node.x, from_node.z))
		var node_heading := _wrap(atan2(to_node.x, to_node.z))
		var diff := _wrap(node_heading - ahead_heading)
		var side := 0.0
		if -ANGLE_LIMIT <= diff:
			side = 0.0 if diff <= ANGLE_LIMIT else HALF_PI
		else:
			side = -HALF_PI
		if side != 0.0 or status != block.frame_counter:
			if side == 0.0:
				actor.yaw = node_heading + HALF_PI
			else:
				actor.yaw = node_heading + side
			_rotate(actor)
		if side == 0.0:
			timer = 1.0 * 1.0 + timer
			if 90.0 < timer and node_id == -1:
				state = 1
				timer = 0.0
				services.set_clip(actor, 0x90, 0.0)
				_rotate(actor)
		else:
			block.look_flags |= 0x10
			var step := _forward(actor) * (0.20000000298023224 * 1.0)
			actor.x += step.x
			actor.y += step.y
			actor.z += step.z
			var rel := Vector3(actor.x - way.x, actor.y - way.y, actor.z - way.z)
			rel = _normalised(rel)
			offset = rel * lane
			actor.x = way.x + offset.x
			actor.y = way.y + offset.y
			actor.z = way.z + offset.z
			services.clip_finished(actor, 1.0)
			timer = 0.0
	elif node_id < 0:
		var next := index + 1
		if 6 < next:
			next = 0
		var before := index - 1
		if before < 0:
			before = 6
		var next_at := _waypoint(RING[next])
		var before_at := _waypoint(RING[before])
		var d_next := (there - next_at).length_squared()
		var d_before := (there - before_at).length_squared()
		last_index = index
		if d_before <= d_next:
			index = next
		else:
			index = before
		services.set_clip(actor, idle_clip, 0.0)
		state = 3
		services.walkers.set_route(handle, RING[index], 0)
	else:
		if action_var != 0:
			FlagSetterBehaviour.apply_op(vars, action_kind, action_var, action_value, actor, services.talk)
		patience = 0.0


## State 3: turn toward the next ring node, side-stepping while the corner is sharp.
func _turn(actor, block: BehaviourBlock, lane: float) -> void:
	block.look_flags |= 0x10
	var here := Vector3(actor.x, actor.y, actor.z)
	var from_at := _waypoint(RING[last_index])
	var to_at := _waypoint(RING[index])
	var toward := to_at - here
	var heading_to := _wrap(atan2(toward.x, toward.z))
	var behind := from_at - here
	var heading_from := _wrap(atan2(behind.x, behind.z))
	var diff := _wrap(heading_to - heading_from)
	if HALF_PI <= absf(diff):
		if 0.0 <= diff:
			actor.yaw = heading_from - HALF_PI
		else:
			actor.yaw = heading_from + HALF_PI
		block.look_flags |= 0x10
		_rotate(actor)
		var step := _forward(actor) * (0.20000000298023224 * 1.0)
		actor.x += step.x
		actor.y += step.y
		actor.z += step.z
		var rel := Vector3(actor.x - from_at.x, actor.y - from_at.y, actor.z - from_at.z)
		rel = _normalised(rel)
		offset = rel * lane
		actor.x = from_at.x + offset.x
		actor.y = from_at.y + offset.y
		actor.z = from_at.z + offset.z
		services.clip_finished(actor, 1.0)
	else:
		actor.yaw = heading_to
		state = 2
		_rotate(actor)
		var right := Vector3(actor.field_f(0x0C), actor.field_f(0x10), actor.field_f(0x14))
		offset = right * lane
		var push := _forward(actor) * (0.4000000059604645 * 1.0)
		actor.x += push.x
		actor.y += push.y
		actor.z += push.z


func has_post() -> bool:
	return true


func post(actor) -> void:
	if (actor.flags & 1) == 0:
		unseen = 1.0 * 1.0 + unseen
	else:
		unseen = 0.0
