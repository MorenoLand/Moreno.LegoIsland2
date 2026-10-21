class_name HopBomb
extends Behaviour

## FUN_004D3BEE (ctor) / FUN_004D349B (update, vtable 0x008BA2F0) / FUN_004D3B13 (post,
## returns 1), update returns 1. A thing that hops from one of three perch actors to the
## next (a hop is a half sine, heading found when it leaves the perch): phase 1 waits on
## the perch until the perch is free, 2 waits for the launch clip, 8 is the flight
## toward the next perch (the hop shrinks as it goes, six times), 4 the last leap. The
## record position is not written here; the flight is reported through the block hint
## (origin = flight position + 8) that the exe's renderer uses.
##
## Node: +0x14 / +0x18 / +0x1C perches, +0x20 count var, +0x24 previous perch, +0x28 perch,
## +0x2C hop angle, +0x30 hop height, +0x34..+0x3C last gap, +0x40..+0x48 start, +0x4C..
## +0x54 leap step, +0x58 angle rate, +0x5C speed, +0x60 flight matrix, +0xA0 range,
## +0xA4 phase, +0xA5 counter, +0xA6 long hop.

const PI_F := 3.1415927410125732
const TAU_F := 6.2831854820251465
const SOUND_LAND := 0x5D49E3C
const SOUND_HOP := 0x5D49E34

var perches: Array = [null, null, null]
var count_var := 0
var previous := 0
var current := 0
var hop_angle := 0.0
var hop_height := 0.0
var last_gap := Vector3.ZERO
var start := Vector3.ZERO
var leap := Vector3.ZERO
var rate := 0.0
var speed := 0.0
var flight_yaw := 0.0
var flight_roll := 0.0
var reach := 0.0
var phase := 1
var counter := 0
var long_hop := 0

var services: ActorServices
var vars


static func from_descriptor(desc: Descriptor, services_in: ActorServices, vars_in, actor) -> HopBomb:
	var b := HopBomb.new()
	b.services = services_in
	b.vars = vars_in
	b.perches = [desc.refs.get(0, null), desc.refs.get(4, null), desc.refs.get(8, null)]
	b.count_var = desc.u32(12)
	b.phase = 1
	b.current = 0
	b.previous = 0
	services_in.copy_matrix(actor, b.perches[0])
	b._next_perch()
	b.long_hop = 0
	b.counter = 0
	actor.flags |= 0x10
	vars_in.set_var(0x73, 2)
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


## FUN_004D2F10: move on to the next perch; every few turns the next hop is a long one.
func _next_perch() -> void:
	previous = current
	current += 1
	if 2 < current:
		current = 0
	long_hop = 0
	if current == 1:
		var roll := int(services.random_float(10.0))
		if (10 - counter) < roll:
			long_hop = 1
			counter = 0
		else:
			counter += 1


## FUN_004D2FF8: where the hop starts from (the perch, or waypoint 0xBC of W_PATH).
func _perch_position() -> Vector3:
	if long_hop == 0:
		var p = perches[current]
		return Vector3(p.x, p.y, p.z)
	var at = services.waypoint_position(1, 0xBC)
	return at if at != null else Vector3.ZERO


func _forward(yaw: float, roll: float) -> Vector3:
	return Vector3(cos(roll) * sin(yaw), sin(roll) * sin(yaw), cos(yaw))


## FUN_004D3069: leave the perch toward `toward`.
func _launch(actor, toward: Vector3) -> void:
	start = _perch_position()
	var perch = perches[current]
	var shift := Vector3(perch.field_f(0x2C), perch.field_f(0x30), perch.field_f(0x34)) * 0.800000011920929
	start += shift
	var gap := toward - start
	var length := sqrt(gap.z * gap.z + gap.y * gap.y + gap.x * gap.x)
	actor.yaw = atan2(gap.x, gap.z)
	flight_yaw = actor.yaw
	flight_roll = actor.field_f(0x54)
	services.set_rotation(actor, actor.field_f(0x4C), actor.yaw, actor.field_f(0x54))
	hop_height = 14.0
	hop_angle = 0.0
	speed = 0.800000011920929
	var steps := length / speed
	rate = 6.2831854820251465 if long_hop != 0 else 3.9269909858703613
	rate = rate / steps
	reach = speed * float(vars.get_var(count_var))
	services.talk.head_op(perch.block, 6, 2, vars)
	var before = perches[previous]
	if (vars.get_var(before.block.head.tag) & 8) == 0:
		services.talk.head_op(before.block, 2, 0, vars)
	last_gap = Vector3(1.0e38, 0.0, 1.0e38)


## FUN_004D32DD: set the leap step for the last hop.
func _leap_step() -> void:
	if long_hop == 0:
		var spot := _perch_position()
		var next_index := current + 1
		if 2 < next_index:
			next_index = 0
		var next = perches[next_index]
		var reach_offset := Vector3(next.field_f(0x0C), next.field_f(0x10), next.field_f(0x14)) * 0.7200000286102295
		var aim := spot - Vector3(next.field_f(0x2C), next.field_f(0x30), next.field_f(0x34)) * 0.7200000286102295 - reach_offset
		var gap := aim - start
		var factor := rate / (PI_F - hop_angle)
		leap = Vector3(gap.x * factor, 0.0, gap.z * factor)
	else:
		leap = Vector3.ZERO


func update(actor, block: BehaviourBlock, _var_value: int) -> int:
	var pos := Vector3(actor.x, actor.y, actor.z)
	if (phase & 1) != 0:
		var perch = perches[current]
		var head: Behaviour = perch.block.head
		var airborne = head.get("airborne")
		if (airborne == null or int(airborne) == 0) and (vars.get_var(head.tag) & 0x100) == 0:
			_launch(actor, pos)
			phase = 2
		return 1
	if (phase & 2) != 0:
		if services.current_clip(actor) == 0x1D:
			if 5.0 < services.anim_frame(actor):
				phase = 8
				services.sound_follow(SOUND_LAND, pos)
		return 1
	if (phase & 4) == 0:
		var gap := pos - start
		var arrived := false
		if absf(last_gap.x) < absf(gap.x):
			arrived = true
		elif absf(last_gap.z) < absf(gap.z):
			arrived = true
		elif speed < absf(gap.x) or speed < absf(gap.z):
			if absf(gap.x) <= reach and absf(gap.z) <= reach and long_hop == 0:
				services.talk.head_op((perches[current]).block, 4, 0, vars)
		else:
			arrived = true
		last_gap = gap
		if not arrived:
			hop_angle += rate * 1.0
			if PI_F < hop_angle:
				if long_hop == 0:
					hop_height = 4.0
					rate = rate + rate
					services.sound_follow(SOUND_HOP, pos)
				elif long_hop < 6:
					long_hop += 1
					hop_height *= 0.28600001335144043
					rate = rate + rate
					speed *= 0.75
					services.sound_follow(SOUND_HOP, pos)
				else:
					hop_height = 0.0
					if 0.800000011920929 < speed:
						speed *= 0.8999999761581421
				hop_angle -= PI_F
			pos -= _forward(flight_yaw, flight_roll) * (speed * 1.0)
		else:
			pos.x = start.x
			pos.z = start.z
			phase = 4
			if long_hop != 0:
				services.talk.head_op((perches[current]).block, 8, 0, vars)
			_leap_step()
	else:
		hop_angle += rate * 1.0
		if PI_F < hop_angle:
			_next_perch()
			phase = 1
			services.sound_follow(SOUND_HOP, Vector3(actor.x, actor.y, actor.z))
		pos += leap
	var spin: float = actor.field_f(0x4C) - 0.20000000298023224
	if spin < -TAU_F:
		spin += TAU_F
	actor.set_field_f(0x4C, spin)
	services.set_rotation(actor, actor.field_f(0x4C), actor.field_f(0x50), actor.field_f(0x54))
	var origin := Vector3(pos.x, pos.y + 8.0, pos.z)
	var up := Vector3(0.0, absf(sin(hop_angle)) * hop_height, 0.0)
	block.set_hint_full(origin, Vector3(0.0, -40.0, 0.0), up, 0x2043, 0.019999999552965164, 0.4000000059604645, 0x16)
	return 1


func has_post() -> bool:
	return false
