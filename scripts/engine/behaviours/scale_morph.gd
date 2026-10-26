class_name ScaleMorph
extends Behaviour

## FUN_004CF219 (ctor) / FUN_004CE884 (update) / FUN_004CEA99 (post), vtable 0x008B9EF0,
## update returns 2. The pop-in / pop-out of a record: it eases the record's scale and
## height offset along a sine curve (channels selected by the flag bits: 1/2/4 = x/y/z
## scale, 8 = lift, 0x10/0x20/0x40 = rotation about x/y/z, 0x100 = pop out instead of
## in). When every channel has finished it restores the scale and sets or clears the
## var bits stored at +0x1C/+0x1E (both zero here, as the constructor leaves them).
## Node: +0x14 flags, +0x18 var (scale source), +0x1C/+0x1E short mask/value,
## +0x20 timer, +0x24 phase, +0x28/+0x2C/+0x30 rotation timers, +0x34/+0x38/+0x3C start
## position, +0x40 record, +0x44 target scale, +0x48 base scale, +0x4C ease, +0x50..58
## scale, +0x5C lift, +0x60 running.

const POP_OUT := 0x100
const ROTATION_STEP := 0.15707960724830627
const PHASE_STEP := 0.3330000042915344
const EASE_STEP := 0.009999999776482582
const EASE_END := 1.5707963705062866
const WAIT_TICKS := 10.0
const LIFT_GAIN := 10.0

## The constructor stores tag 1, mask 0, value 1, so the dispatcher never gates this
## behaviour on; whatever drives it is still open (see AGENTS.md).
var forced_tag := 1
var flags := 0
var scale_var := 0
var end_mask := 0
var end_value := 0
var timer := 0.0
var phase := 0.0
var rot := [0.0, 0.0, 0.0]
var start := Vector3.ZERO
var target = null
var scale_target := 1.0
var scale_base := 0.0
var ease_value := 0.0
var scale := Vector3.ONE
var lift := 0.0
var running := false

var services: ActorServices
var vars


static func from_descriptor(desc: Descriptor, services_in: ActorServices, vars_in, actor) -> ScaleMorph:
	var b := ScaleMorph.new()
	b.services = services_in
	b.vars = vars_in
	b.status = Behaviour.STATUS_NEW
	b.flags = desc.u32(0)
	b.scale_var = desc.s32(12)
	if b.scale_var > 1:
		b.scale_target = float(vars_in.get_var(b.scale_var)) * 0.01
		b.scale = Vector3(b.scale_target, b.scale_target, b.scale_target)
	b.target = desc.refs.get(8, actor)
	b.start = Vector3(b.target.x, b.target.y, b.target.z)
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	mask = 0
	value = 1


func update(_actor, _block: BehaviourBlock, var_value: int) -> int:
	if (var_value & end_mask) == end_value:
		if not running:
			running = true
			if scale_var < 2:
				scale_base = 0.0
				scale_target = 1.0
			else:
				scale_target = float(vars.get_var(scale_var)) * 0.01
			ease_value = 0.5235300064086914
			rot = [-12.566371, -12.566371, -12.566371]
			start = Vector3(target.x, target.y, target.z)
			target.flags |= Record.FLAG_VISIBLE
			timer = 0.0
			if (flags & POP_OUT) == 0:
				phase = -1.5707964
			else:
				phase = 1.5707964
		target.flags |= Record.FLAG_VISIBLE
	else:
		running = false
		return 2 if scale_var > 1 else 0
	return 2


func has_post() -> bool:
	return true


func post(actor) -> void:
	if not running:
		return
	var channels_run := 0
	var channels_done := 0
	lift = 0.0
	var span := scale_target - scale_base
	scale = Vector3.ONE
	if (flags & 0xF) != 0:
		channels_run = 1
		var curve: float
		var offset: float
		if (flags & POP_OUT) == 0:
			offset = sin(ease_value)
			curve = 1.0 - offset
		else:
			curve = 1.0 - sin(ease_value)
			offset = curve
		var level := sin(phase) * curve + offset
		phase += PHASE_STEP
		timer += 1.0
		if timer >= 10.0:
			ease_value += EASE_STEP
			if ease_value >= EASE_END:
				level = 1.0 if (flags & POP_OUT) == 0 else 0.0
				channels_done = 1
		if (flags & 1) != 0:
			scale.x = level
		if (flags & 2) != 0:
			scale.y = level
		if (flags & 4) != 0:
			scale.z = level
		if (flags & 8) != 0:
			lift = absf(sin(phase) * curve * LIFT_GAIN)
	scale = scale * span + Vector3(scale_base, scale_base, scale_base)
	if (flags & 0x70) != 0:
		for k in 3:
			if (flags & (0x10 << k)) != 0:
				rot[k] += ROTATION_STEP
				channels_run |= 2 << k
				if 0.0 < rot[k]:
					rot[k] = 0.0
					channels_done |= 2 << k
	if channels_done == channels_run or not services.scene_active:
		if (flags & POP_OUT) != 0:
			target.flags &= ~Record.FLAG_VISIBLE
		scale = Vector3.ONE * span + Vector3(scale_base, scale_base, scale_base)
		scale_base = scale_target
		_propagate_visibility(target)
		rot = [0.0, 0.0, 0.0]
		lift = 0.0
		running = false
		if tag > 2:
			if end_mask == end_value:
				vars.clear_var(tag, end_mask)
			else:
				vars.or_var(tag, end_mask)
	if scale_var < 2:
		services.set_actor_matrix(target,
				Vector3(rot[0] + target.field_f(0x4C), rot[1] + target.field_f(0x50), rot[2] + target.field_f(0x54)),
				Vector3(start.x, lift + start.y, start.z), scale)


## FUN_004CE3C0: records that follow another record's visible bit. Keys and members are
## record offsets in the array (offset / 0x68 = record number).
const FOLLOWERS := {
	0x2F20: [0x4298],
	0x3128: [0x46A8, 0x4368, 0x31F0, 0x9850, 0x99F0, 0x9A58],
	0x2EB8: [0x2E48, 0x2EB0, 0x3F58],
	0x3468: [0x43D0],
	0x31F8: [0x2DE0],
	0x3538: [0x9988, 0x9920, 0x9920],
}


func _propagate_visibility(source) -> void:
	for key in FOLLOWERS:
		if source != services.record_at(int(key) / Record.SIZE):
			continue
		for offset in FOLLOWERS[key]:
			var follower = services.record_at(int(offset) / Record.SIZE)
			if follower == null:
				continue
			if source.visible():
				follower.flags |= Record.FLAG_VISIBLE
			else:
				follower.flags &= ~Record.FLAG_VISIBLE
		return
