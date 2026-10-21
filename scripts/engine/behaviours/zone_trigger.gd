class_name ZoneTrigger
extends Behaviour

## FUN_004B90CC (ctor) / FUN_004B8C3B (update, vtable 0x008B9370, no post), returns 0.
## A box around the actor (the portal / door trigger): while Pepper (or a member of a
## party group) stands inside it for a second it raises a var, and it spins or turns to
## face the camera meanwhile.
##
## Node: +0x14 / +0x18 / +0x1C box half sizes, +0x20 squared range, +0x24 var, +0x28 bits,
## +0x2C party group, +0x2E value for var 5, +0x30 face camera, +0x31 spin, +0x34 required
## game flags, +0x38 var bits to raise when blocked, +0x3C nearest distance, +0x40 timer.

const SPIN_STEP := 0.008726599626243114
const PI_F := 3.1415927410125732
const TAU_F := 6.2831854820251465
const HALF_PI := 1.5707963705062866

var half_x := 0.0
var half_y := 0.0
var half_z := 0.0
var range_squared := 0.0
var change_var := 0
var change_bits := 0
var party := 0
var set_five := 0
var face_camera := 0
var spin := 0
var flags_needed := 0
var blocked_bits := 0
var nearest := -1.0
var timer := 0.0

var services: ActorServices
var vars


static func from_descriptor(desc: Descriptor, services_in: ActorServices, vars_in) -> ZoneTrigger:
	var b := ZoneTrigger.new()
	b.services = services_in
	b.vars = vars_in
	b.nearest = -1.0
	b.half_x = desc.f32(0)
	b.half_y = desc.f32(4)
	b.half_z = desc.f32(8)
	b.change_var = desc.u32(12)
	b.change_bits = desc.u32(16)
	b.range_squared = desc.f32(8) * desc.f32(8) + desc.f32(4) * desc.f32(4) + desc.f32(0) * desc.f32(0) + 16.0
	b.party = desc.s16(0x14)
	b.set_five = desc.s16(0x18)
	b.spin = desc.u8(0x1B)
	b.face_camera = desc.u8(0x1A)
	b.flags_needed = desc.u32(0x1C)
	if b.flags_needed == 0:
		b.blocked_bits = desc.u32(0x20)
	elif desc.u32(0x20) == 0:
		b.blocked_bits = 2
	else:
		b.blocked_bits = desc.u32(0x20)
	b.timer = 0.0
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


func update(actor, block: BehaviourBlock, _var_value: int) -> int:
	timer = 1.0 * 1.0 + timer
	if spin != 0:
		actor.set_field_f(0x4C, _wrap(actor.field_f(0x4C) + SPIN_STEP))
	if face_camera != 0:
		var camera := services.camera_position
		actor.yaw = atan2(actor.x - camera.x, actor.z - camera.z) + HALF_PI
	if face_camera != 0 or spin != 0:
		services.set_rotation(actor, actor.field_f(0x4C), actor.yaw, actor.field_f(0x54))
	var distance: float = block.distance_squared
	if distance < range_squared:
		if flags_needed != 0 or distance < nearest:
			nearest = distance
			if 30.0 <= timer:
				if flags_needed == 0 and blocked_bits != 0:
					vars.or_var(0xC, blocked_bits)
				var who = null
				var slot := -1
				if party < 1:
					who = services.player
				else:
					var group: Array = services.talk.parties[party - 1] if party - 1 < services.talk.parties.size() else []
					for i in 3:
						if i < group.size() and group[i] != null and group[i].block != null and group[i].block.distance_squared < range_squared:
							who = group[i]
							slot = i
					if who == null:
						return 0
				var dx: float = actor.x - who.x
				var dy: float = actor.y - who.y
				var dz: float = actor.z - who.z
				if absf(dx) <= half_x and absf(dy) <= half_y and absf(dz) <= half_z:
					if (services.talk.game_flags & flags_needed) == flags_needed:
						if slot > -1:
							vars.set_var(0xBB, slot)
						if flags_needed != 0:
							vars.set_var(0x5E, 0x100)
						vars.or_var(change_var, change_bits)
						if set_five != 0:
							vars.set_var(5, set_five)
					else:
						vars.or_var(0xC, blocked_bits)
		else:
			nearest = distance
	else:
		vars.clear_var(change_var, change_bits)
		nearest = -1.0
	return 0
