class_name TurnToPepper
extends Behaviour

## Turn2Pep.c: FUN_004CA5C9 (ctor) / FUN_004CA120 (update, vtable 0x008B9C30), returns 1.
## An NPC notices Pepper, turns to face him, plays the notice clip and turns back.
## Var bits of the tag: 0x100 talk key, 0x200 near, 0x400 stop, 0x800 force clip.
## Node: +0x14 notice clip, +0x16 idle clip, +0x18 forced clip, +0x1A enable byte
## (0 when var 0x59 == 6), +0x20 Pepper record, +0x24 saved yaw, +0x28 turned flag,
## +0x2A notice flag, +0x2C / +0x30 float timers.

const NOTICE_WAIT := 180.0
const FRAME_LIMIT := 20.0

var clip_notice := 0
var clip_idle := 0
var clip_forced := 0
var enabled := 1
var pepper = null
var saved_yaw := 0.0
var turned := 0
var near_flag := 0
var timer_near := 0.0
var timer_start := 0.0

var services: ActorServices
var vars


static func from_descriptor(desc: Descriptor, services_in: ActorServices, vars_in, pepper_record) -> TurnToPepper:
	var b := TurnToPepper.new()
	b.clip_notice = desc.s16(0)
	b.clip_idle = desc.s16(4)
	b.clip_forced = desc.s16(8)
	b.pepper = desc.refs.get(16, pepper_record)
	b.enabled = 0 if vars_in.get_var(0x59) == 6 else 1
	b.services = services_in
	b.vars = vars_in
	return b


func update(actor, block: BehaviourBlock, var_value: int) -> int:
	var first_frame_pending := false
	var go_idle := false
	var turning := false
	var held := 0
	var continuing := status == block.frame_counter
	if (var_value & 0x200) == 0:
		near_flag = 0
	elif timer_near > 0.0 and near_flag == 0 and enabled != 0:
		timer_near -= 1.0
		return 0
	if not continuing:
		if timer_start > 0.0 and enabled != 0:
			timer_start -= 1.0
			return 0
		saved_yaw = actor.yaw
		services.walker_finish(actor)
		turned = 0
		timer_near = 0.0
	if (var_value & 0x800) != 0:
		if services.anim_frame(actor) >= FRAME_LIMIT:
			var_value |= 0x400
		else:
			first_frame_pending = true
	var settle := false
	if not first_frame_pending:
		var at := Vector3(actor.x, actor.y, actor.z)
		var face := (((var_value & 0x400) == 0 and (var_value & 0x100) != 0)
			or (near_flag != 0 and (var_value & 0x200) != 0)) and turned != 0
		if face:
			services.walker_turn_to(actor, saved_yaw)
			turning = true
		else:
			turned = 0
			near_flag = 0
			services.walker_follow(actor, pepper)
		var step := services.walker_step(actor, at)
		actor.yaw = step[1]
		if turning and int(step[0]) == -3:
			actor.yaw = saved_yaw
			near_flag = 0
			vars.clear_var(tag, 0xB00)
		services.set_matrix(actor)
	var clip_done := false
	if continuing:
		clip_done = services.clip_finished(actor, 1.0)
		if not clip_done:
			first_frame_pending = false
		else:
			if (var_value & 0x400) == 0 and (var_value & 0x100) != 0:
				turned = 1
			services.anim_halt(actor)
			first_frame_pending = true
	else:
		first_frame_pending = true
	if first_frame_pending:
		var current := services.current_clip(actor)
		var new_clip := current
		var proceed := true
		if (var_value & 0x800) != 0:
			if current != clip_forced:
				new_clip = clip_forced
				proceed = false
			else:
				vars.clear_var(tag, 0x800)
		if proceed:
			if (var_value & 0x200) == 0 or turned != 0:
				new_clip = clip_idle
			else:
				if current == clip_notice:
					new_clip = clip_idle
					timer_near = NOTICE_WAIT
					near_flag = enabled
					turned = enabled
				else:
					new_clip = clip_notice
		if new_clip != current:
			services.set_clip(actor, new_clip, 0.0)
	return 1
