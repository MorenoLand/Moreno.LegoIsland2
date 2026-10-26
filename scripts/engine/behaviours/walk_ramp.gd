class_name WalkRamp
extends Behaviour

## FUN_004599B9 (ctor) / FUN_00459555 (update, vtable 0x008A9640, returns 1 when the
## +0x28 value is set, otherwise 2) / FUN_004596CE (post, slot 1). Works out how far a
## character takes to speed up to its walking speed and plays the walk start / loop /
## stop clips. It reads and writes fields of the first behaviour of the actor (+0x28
## character kind, +0x36 airborne flag, +0x48 fall speed).
## Node: +0x14 distance, +0x18 negated acceleration, +0x1C ramp length, +0x20 goal node,
## +0x24 start clip, +0x28 loop flag, +0x2C state, +0x2E arrived flag.

## DAT_00974EA0: five-word entries indexed by the character kind; only the last word (a
## float) is used here.
const KIND_ACCEL := [0.032, 0.032, 0.032, 0.032, 0.032, 0.032]
const MAX_STEPS := 600.0
const UNSET := -107374176.0

var distance := 0.0
var accel := 0.0
var ramp_length := 0.0
var goal := 0
var start_clip := 0
var loop_flag := 0
var state := 0
var arrived := 0

var services: ActorServices
var vars


static func _kind_of(head) -> int:
	if head == null:
		return 0
	var kind = head.get("kind")
	if kind != null:
		return int(kind)
	if head is StubBehaviour and head.descriptor != null:
		return head.descriptor.u16(0x28)
	return 0


static func from_descriptor(desc: Descriptor, services_in: ActorServices, vars_in, actor) -> WalkRamp:
	var b := WalkRamp.new()
	b.services = services_in
	b.vars = vars_in
	b.goal = desc.s32(8)
	b.start_clip = desc.s32(16)
	b.loop_flag = desc.s32(20)
	b.distance = desc.f32(0) * 8.0
	var accel_per_step: float = KIND_ACCEL[_kind_of(actor.block.head)]
	var acceleration := 0.0
	var lead := 0.0
	if 0.0 < desc.f32(4):
		lead = desc.f32(4)
	else:
		lead = b.distance * 0.10000000149011612
	var total := lead + b.distance
	var steps := UNSET
	var sum := 0.0
	var l := 1.0
	while l < MAX_STEPS:
		sum = (l - 1.0) + sum
		acceleration = l * accel_per_step
		var covered := l * acceleration - sum * accel_per_step
		if total < covered:
			b.accel = -acceleration
			steps = l
			break
		l += 1.0
	var offset := 0.0
	sum = 0.0
	l = 0.0
	while true:
		if steps <= l:
			break
		sum = (l - 1.0) + sum
		var reach := -b.accel * l - sum * accel_per_step
		if lead < reach:
			offset = l
			break
		l += 1.0
	b.ramp_length = steps + offset
	if 0 < b.start_clip:
		b.ramp_length += 10.0
	if desc.s32(12) > 1:
		vars_in.set_var(desc.s32(12), int(b.ramp_length + 0.5))
	return b


## FUN_00459555. The decompiler lost the floats the walker slot answers (FUN_004476B1 the squared
## gap to the goal, FUN_00446FC4 the speed), so the returns were read off the disassembly: 0 while
## the character is not yet inside the ramp it needs, otherwise 1 or 2 by the loop flag.
func update(actor, block: BehaviourBlock, _var_value: int) -> int:
	if status != block.frame_counter:
		state = 0
	if state == 0:
		if goal >= 0:
			var walk := services.walker_state(block.walker)
			if walk == 0:
				return 0
			if walk != 3 and walk != 2:
				return 0
			if services.walker_goal_node(block.walker) != goal:
				arrived = 0
				return 0
			if arrived != 0:
				return 0
			var gap: float = services.walkers.gap_to_goal(block.walker)
			var reach: float = ramp_length * services.walkers.speed(block.walker)
			reach = (reach + 1.0) * (reach + 1.0)
			if not (gap <= reach):
				return 0
		elif goal < -1:
			if not (float(-goal) <= services.anim_frame(actor)):
				return 0
	return 1 if loop_flag != 0 else 2


func has_post() -> bool:
	return true


func post(actor) -> void:
	var block: BehaviourBlock = actor.block
	var changed := false
	if start_clip < 1:
		if state != 4:
			state = 4
			changed = true
	else:
		match state:
			0:
				state = 1
				services.set_clip(actor, start_clip, 0.0)
			1:
				if 10.0 <= services.anim_frame(actor):
					state = 2
					changed = true
			2:
				if not _airborne(block.head):
					state = 3
					services.anim_set_frame(actor, 26.0)
				elif 26.0 < services.anim_frame(actor):
					services.anim_set_frame(actor, 25.0)
			3:
				if loop_flag == 0 and services.anim_frame(actor) < 27.0:
					arrived = 1
					state = 0
		if loop_flag != 0 and services.anim_at_end(actor):
			arrived = 1
			state = 0
			if mask == value:
				vars.clear_var(tag, mask)
			else:
				vars.or_var(tag, mask)
	if changed:
		block.head.set("fall_speed", accel)
		block.head.set("airborne", 1)


func _airborne(head) -> bool:
	if head == null:
		return false
	var flag = head.get("airborne")
	return flag != null and bool(flag)
