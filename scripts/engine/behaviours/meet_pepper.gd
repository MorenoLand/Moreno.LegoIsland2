class_name MeetPepper
extends Behaviour

## MeetPepp.c: FUN_004CAD75 (ctor) / FUN_004CA6DB (update, vtable 0x008B9C48), returns 1.
## The cut-in of an NPC that walks to / turns to Pepper, plays its clip chain and then
## applies a var op (FUN_004B82E0) and clears or sets its tag bits.
## Node (from the ctor): +0x14 clip A, +0x16 clip B, +0x18 clip C, +0x1A mode (-4 sync to
## target animation, -1 face saved heading, <0 finish), +0x1C target record, +0x20 phase
## offset (float), +0x24 node id, +0x26 graph table, +0x28 countdown start, +0x2A op
## value, +0x2C op kind, +0x2E wait mask, +0x30 saved yaw, +0x34 timer, +0x38 turning
## flag, +0x3A countdown.

const CLIP_HOLD := 30.0

var clip_a := 0
var clip_b := 0
var clip_c := 0
var mode := 0
var target = null
var phase_offset := 0.0
var node_id := 0
var table := 0
var countdown_start := 0
var op_value := 0
var op_kind := 0
var wait_mask := 0
var saved_yaw := 0.0
var timer := 0.0
var turning := 0
var countdown := 0

var services: ActorServices
var vars


static func from_descriptor(desc: Descriptor, services_in: ActorServices, vars_in) -> MeetPepper:
	var b := MeetPepper.new()
	b.clip_a = desc.s16(0)
	b.clip_b = desc.s16(2)
	b.clip_c = desc.s16(4)
	b.mode = desc.s16(6)
	b.target = desc.refs.get(8, null)
	b.phase_offset = _bits_to_float(desc.u32(16))
	b.node_id = desc.s16(12)
	b.table = desc.s16(14)
	b.countdown_start = desc.s16(26)
	b.op_value = desc.s16(20)
	b.op_kind = desc.s16(22)
	b.wait_mask = desc.s16(24)
	b.services = services_in
	b.vars = vars_in
	return b


static func _bits_to_float(bits: int) -> float:
	var buffer := PackedByteArray()
	buffer.resize(4)
	buffer.encode_u32(0, bits)
	return buffer.decode_float(0)


func _wrap_phase(target_frame: float, length: float) -> float:
	var phase := target_frame
	while length < phase:
		phase -= length
	if phase < 0.0:
		phase = 0.0
	return phase


func update(actor, block: BehaviourBlock, var_value: int) -> int:
	var finished := false
	var step_ok := true
	var continuing := status == block.frame_counter
	if not continuing:
		saved_yaw = actor.yaw
		services.walker_finish(actor)
		turning = 0
		countdown = countdown_start
		if clip_a < 1:
			services.set_clip(actor, clip_b, 0.0)
		else:
			services.set_clip(actor, clip_a, 0.0)
		if mode == -4:
			var phase := services.anim_frame(target) + phase_offset
			phase = _wrap_phase(phase, services.anim_length(actor))
			services.anim_set_frame(actor, phase)
	var at := Vector3(actor.x, actor.y, actor.z)
	if turning == 0:
		if target == null:
			if node_id < 0:
				step_ok = false
			else:
				services.walker_goal(actor, table, node_id)
				step_ok = true
		else:
			services.walker_follow(actor, target)
			step_ok = true
	else:
		services.walker_turn_to(actor, saved_yaw)
	var result := -3
	if step_ok:
		var step := services.walker_step(actor, at)
		result = int(step[0])
		actor.yaw = step[1]
	if turning == 0:
		if continuing:
			var skip := countdown == 0 and (var_value & wait_mask) == wait_mask
			if mode == -4:
				var wanted := services.anim_frame(target) + phase_offset
				var length := services.anim_length(actor)
				if length < wanted:
					if clip_a > 0:
						services.set_clip(actor, clip_b, 0.0)
					wanted = _wrap_phase(wanted, length)
				elif wanted < 0.0:
					wanted = 0.0
				services.anim_set_frame(actor, wanted)
			elif not skip:
				var done := services.clip_finished(actor, 1.0)
				if done:
					var current := services.current_clip(actor)
					if current == clip_b:
						if clip_c > 0:
							timer += 1.0
							if timer > 30.0:
								services.set_clip(actor, clip_c, 0.0)
					else:
						if current == clip_a and (var_value & 0x8000) != 0:
							services.notify_pepper_talk(actor, 480.0)
						services.set_clip(actor, clip_b, 0.0)
						timer = 0.0
					if countdown > 0:
						countdown -= 1
						if countdown == 0:
							FlagSetterBehaviour.apply_op(vars, op_kind, tag, op_value, actor, services.talk)
			else:
				if services.anim_at_end(actor):
					if mode < 0:
						finished = true
						if mode == -1:
							actor.yaw = saved_yaw
					elif turning == 0:
						turning = 1
						services.set_clip(actor, mode, 0.0)
	else:
		if result == -3:
			finished = true
		services.clip_finished(actor, 1.0)
	if finished:
		if (var_value & 0x8000) != 0:
			services.notify_pepper_talk(actor, 0.0)
			vars.clear_var(tag, 0x8000)
		if mask == value:
			vars.clear_var(tag, mask)
		else:
			vars.or_var(tag, mask)
	services.set_matrix(actor)
	return 1
