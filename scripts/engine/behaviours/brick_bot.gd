class_name BrickBot
extends Behaviour

## FUN_004CC3D5 (ctor) / FUN_004CB510 (update, vtable 0x008B9D78) / FUN_004CB916 (post),
## update returns 1. The BrickBot: a small brick creature that trails another actor. It
## copies the target's walker, keeps the last five positions of the target (spaced
## `distance` behind it) so it follows with a delay, and copies the target's animation
## through a clip map. Its post drives the idle / look-around states.
##
## Node: +0x14 follow distance, +0x18 formation slot (3 = rides on the target), +0x1C /
## +0x58 five positions / angles, +0x94 target, +0x98 history index, +0xA8 timer, +0xAC
## state, +0xB0 target clip, +0xB4 own clip, +0xB8 frame, +0xBC counter.

const CANARY_INT := -858993460
const GAP_CLIP := 0x121

var target = null
var history_index := 0
var distance := 0.0
var slot := 0
var positions: Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var angles: Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var timer := 0.0
var state := 0
var target_clip := -1
var own_clip := 0
var frame := 0.0
var counter := 0

var services: ActorServices
var vars


static func from_descriptor(desc: Descriptor, services_in: ActorServices, vars_in) -> BrickBot:
	var b := BrickBot.new()
	b.services = services_in
	b.vars = vars_in
	b.target = desc.refs.get(0, null)
	b.history_index = 0
	b.distance = desc.f32(4) * 8.0
	b.timer = 0.0
	b.target_clip = -1
	b.frame = 0.0
	b.state = 0
	if desc.s32(8) < 1:
		b.slot = services_in.talk.brickbot_slot
		services_in.talk.brickbot_slot += 1
		if 2 < services_in.talk.brickbot_slot:
			services_in.talk.brickbot_slot = 0
	else:
		b.slot = desc.s32(8)
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func _target_var() -> int:
	return vars.get_var(target.block.head.tag)


func update(actor, block: BehaviourBlock, _var_value: int) -> int:
	if target == null:
		return 1
	var g := services.talk
	var w := services.walkers
	var v := _target_var()
	if (v & 0x4000) != 0:
		g.head_op(target.block, 0x2000000, 2, vars)
		return 1
	if (v & 0x2000000) == 0:
		g.head_op(target.block, 0x2000000, 0, vars)
	if status != block.frame_counter:
		w.unlink_handle(block.walker)
		state = 0
	var pick := 0
	if slot == 3:
		actor.set_field_f(0x4C, target.field_f(0x4C))
		actor.set_field_f(0x50, target.field_f(0x50))
		actor.set_field_f(0x54, target.field_f(0x54))
		services.copy_matrix(actor, target)
		actor.y += 4.0
	else:
		services.set_face(actor, 0xE)
		var behind := Vector3(
			target.x + -distance * target.field_f(0x2C),
			target.y + -distance * target.field_f(0x30),
			target.z + -distance * target.field_f(0x34))
		var target_angles := Vector3(target.field_f(0x4C), target.field_f(0x50), target.field_f(0x54))
		if status == block.frame_counter:
			history_index += 1
			if history_index < 5:
				pick = history_index + 1
				if 4 < pick:
					pick = 0
			else:
				history_index = 0
				pick = 1
			positions[history_index] = behind
			angles[history_index] = target_angles
		else:
			history_index = 4
			for i in 5:
				positions[i] = behind
				angles[i] = target_angles
			pick = 0
		var a: Vector3 = angles[pick]
		services.set_rotation(actor, a.x, a.y, a.z)
		actor.set_field_f(0x50, a.y)
		var p: Vector3 = positions[pick]
		actor.y = p.y
		actor.x = p.x
		actor.z = p.z
	var walker_of_target: int = target.block.walker
	w.clone(walker_of_target, block.walker, distance)
	w.set_option_flags(block.walker, 1, 2)
	return 1


## FUN_004CBFD4: the clip this bot plays for a clip of the target.
func _map_clip(clip: int) -> int:
	if slot == 3:
		match clip:
			0x71, 0x79, 0x85:
				return 0x123
			0x74:
				return 0x74
			0x78, 0x82:
				return 0x78
			_:
				return 0x29
	if clip < 0x8E:
		if clip != 0x8D:
			match clip:
				0xD, 0x73:
					if slot == 1:
						return 0x8D
					if slot != 2:
						return 0x113
				0x74:
					if slot == 1:
						return 0x91
					return 0x90
				0x85:
					return 0x123
				_:
					return clip
		clip = 0x8E
	else:
		match clip:
			0x8E:
				return 0x113
			0x90:
				return 0x91
			0x91:
				return 0x90
			0x113:
				return 0x8D
	return clip


func has_post() -> bool:
	return true


func post(actor) -> void:
	var g := services.talk
	vars.or_var(tag, 0x20000)
	if (actor.flags & 1) == 0:
		frame = services.anim_frame(target)
		target_clip = -1
		own_clip = -1
		return
	var current := CANARY_INT
	var shown := frame
	var common := false
	if state == 1:
		var seen := services.anim_frame(target)
		if 2.0 <= seen:
			common = true
		else:
			var wait := true
			if slot != 3:
				if (mask & 1) == 0 or (value & 1) != 0:
					wait = services.random_float(10.0) > 5.0
				else:
					wait = true
			if not wait:
				state = 3
				services.set_clip(actor, GAP_CLIP, seen)
				state = 0
			else:
				state = 2
				services.set_clip(actor, 0xFE, seen)
				seen = services.anim_frame(actor)
				own_clip = -1
				counter = 0
	elif state == 2:
		var done := services.anim_at_end(actor)
		shown = services.anim_frame(actor)
		counter += 1
		if done:
			shown = services.anim_frame(actor)
			state = 0
			g.head_op(target.block, 2, 0, vars)
			timer = 0.0
	elif state != 3:
		common = true
	else:
		var done3 := services.anim_at_end(actor)
		shown = services.anim_frame(actor)
		if not done3:
			if g.brickbot_frame <= shown:
				g.head_op(target.block, 4, 0, vars)
				g.head_op(target.block, 0x2000000, 2, vars)
		elif mask == value:
			vars.clear_var(tag, mask)
		else:
			vars.or_var(tag, mask)
	if common:
		var tclip := services.current_clip(target)
		current = services.current_clip(actor)
		if current == own_clip:
			if current == 0x123:
				target_clip = -1
		else:
			target_clip = -1
		if target_clip == -1:
			var seen2 := services.anim_frame(target)
			own_clip = _map_clip(tclip)
			frame = seen2
			shown = seen2
			services.set_clip(actor, own_clip, frame)
			target_clip = tclip
		elif tclip == target_clip:
			var seen3 := services.anim_frame(target)
			if frame <= seen3:
				shown = seen3
				if frame < seen3 - 2.0:
					shown = frame + 2.0
				services.anim_set_frame(actor, shown)
			else:
				services.clip_finished(actor, 1.0)
				shown = services.anim_frame(actor)
			frame = shown
		else:
			var length := services.anim_length(actor)
			var here := services.anim_frame(actor)
			shown = here
			if length - 2.0 <= shown:
				services.anim_set_frame(actor, length - 1.0)
				own_clip = _map_clip(tclip)
				services.set_clip(actor, own_clip, 0.0)
				target_clip = tclip
			else:
				services.anim_set_frame(actor, shown + 2.0)
			frame = services.anim_frame(actor)
		var length2 := services.anim_length(actor)
		if length2 <= shown:
			frame = services.anim_frame(target)
			services.anim_set_frame(actor, length2 - 1.0)
		timer = 1.0 * 1.0 + timer
		if 360.0 < timer:
			if (tclip == 0xD or tclip == 0x73) and slot != 3:
				state = 1
				timer = -1000.0
			else:
				timer = services.random_float(120.0)
	if current == 0x29 and slot == 3:
		actor.y -= 0.5
