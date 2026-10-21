class_name FlagSetterBehaviour
extends Behaviour

## FUN_004CB3F9 (constructor) / FUN_004CB050 (update) / vtable 0x008B9D20.
## Registered by FUN_0045CF96 / 0045D07C / 0045D13F: applies a var operation to the
## behaviour's own tag when its clip finishes, then waits for the "other" mask and
## clears or sets the tag bits (the end of a conversation step).
## Node layout (from the constructor): +0x14 clip, +0x18 s16 post value, +0x1C s16 value,
## +0x1E s16 kind, +0x1A s16 wait mask, +0x20 s16 / +0x22 s16 walker config,
## +0x24 state counter.

var clip := 0
var post_value := 0
var op_value := 0
var op_kind := 0
var wait_mask := 0
var walker_a := 0
var walker_b := 0
var state := 0

var services: ActorServices
var vars


static func from_descriptor(desc: Descriptor, services_in: ActorServices, vars_in) -> FlagSetterBehaviour:
	var b := FlagSetterBehaviour.new()
	b.clip = desc.s32(0)
	b.post_value = desc.s16(4)
	b.op_kind = desc.s16(6)
	b.op_value = desc.s16(8)
	b.wait_mask = desc.s16(10)
	b.walker_a = desc.s16(12)
	b.walker_b = desc.s16(14)
	b.services = services_in
	b.vars = vars_in
	return b


## FUN_004B82E0(actor, kind, var, value). Kinds 0x10 / 0x20 first tell the actor's group
## (FUN_0087B811 with op 0 / 2) and then or / clear the var.
static func apply_op(vars, kind: int, var_id: int, value: int, actor = null, talk = null) -> void:
	match kind:
		0x10, 2:
			if kind == 0x10 and talk != null:
				talk.notify_group(actor, value, 0, vars)
			vars.or_var(var_id, value)
		0x20, 4:
			if kind == 0x20 and talk != null:
				talk.notify_group(actor, value, 2, vars)
			vars.clear_var(var_id, value)
		0x40:
			vars.add_var(0xA6, 1000)
			vars.add_var(0x12, 1000)
			vars.add_var(0xB0, -1)
			vars.set_var(var_id, value)
		1:
			vars.set_var(var_id, value)


func update(actor, block: BehaviourBlock, var_value: int) -> int:
	var head_clip := 0
	var continuing := status == block.frame_counter
	if continuing:
		var done := services.clip_finished(actor, 1.0)
		if not done:
			pass  # walker step (FUN_00447390) is the Human1 engine, not ported yet
		elif state == 0:
			apply_op(vars, op_kind, tag, op_value, actor, services.talk)
			state = -9
		else:
			if state > 0:
				state -= 1
			services.set_clip(actor, head_clip if clip == -1 else clip, 0.0)
		if state == -9 and (var_value & wait_mask) == wait_mask:
			state = -10
		if state == -10:
			if (var_value & 0x8000) != 0:
				vars.clear_var(tag, 0x8000)
			if mask == value:
				vars.clear_var(tag, mask)
			else:
				vars.or_var(tag, mask)
	else:
		state = post_value
		services.set_clip(actor, head_clip if clip == -1 else clip, 0.0)
	return 1
