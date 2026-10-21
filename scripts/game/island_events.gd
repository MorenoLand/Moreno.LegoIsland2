class_name IslandEvents
extends RefCounted

## FUN_0044F09D: the island zone's per-frame event driver. Story scripts raise game vars and
## this turns them into effects: rotor spin (0x131), the swing (0x106) and wobble (0x134)
## state machines, the pizza countdown (0x11F), the rocket / zzz flames of the characters
## (0x110), the fade (0x128 / 0xD), the bill hands (0x109), the twinkle (0xFF) and the
## record flags (0x129). One call is one 30 Hz tick (the exe's step DAT_008A0850 is 1.0).
## The cut-scene sound table at 0x8A8460 that opens the function is CsmHost's.
##
## State (the zone struct): +0x18 rotor angle, +0x20 / +0x24 wobble angle and speed, +0x28 /
## +0x30 swing angles and speeds, +0x48 timer shared by the pizza and the fade.

const ROTOR_RECORDS := [[165, 3], [157, 2]]
const SWING_LIMIT := 1.7999999523162842
const SWING_DAMP := -0.5
const SWING_REST := 0.05000000074505806
const WOBBLE_LIMIT := 1.7999999523162842
const FADE_STEP := 0.0333
const ROCKET_SLOT_RECORDS := {1: 11, 2: 23, 4: 17, 8: 18, 0x10: 22, 0x20: 10}
const ROCKET_SLOT := {1: 0, 2: 0, 4: 0, 8: 2, 0x10: 0, 0x20: 4}
const TWINKLE_RECORDS := {2: 0x15, 4: 0x13, 8: 0x16, 0x10: 0x14, 0x20: 0x12, 0x40: 0x11, 0x100: 0x17}
const SOUND_INFO := 0x5D49E4C
const SOUND_TWINKLE := 0x5D49EA4
const SOUND_SWING := 0x5D49DC0
const FLAG_RECORDS := [12, 13, 17, 18]
const FADE_RECORD := 370
const PIZZA_RECORD := 78
const BILL_RECORD := 15
const INFO_RECORD := 11
const PIZZA_STEP := 1.0
const SWING_RECORD := 124
const WOBBLE_RECORD := 122
const TAU_F := 6.2831854820251465

var services
var records: Array = []
var rotor_angle := 0.0
var wobble_angle := 0.0
var wobble_speed := 0.0
var swing_angles := [0.0, 0.0]
var swing_speeds := [0.0, 0.0]
var timer := 0.0
## Emitters created by the act set-up and the matrices they follow (the exe's globals).
var rockets: Array = []
var rocket_holders: Array = []
var bill: Array = []
var bill_holders: Array = []
var zzz := -1
var zzz_holder: Array = [PackedFloat32Array()]
var twinkle := -1
var twinkle_holder: Array = [PackedFloat32Array()]


func _empty_matrix() -> PackedFloat32Array:
	var m := PackedFloat32Array()
	m.resize(16)
	m[0] = 1.0
	m[5] = 1.0
	m[10] = 1.0
	m[15] = 1.0
	return m


func setup(services_in, records_in: Array) -> void:
	services = services_in
	records = records_in
	zzz_holder = [_empty_matrix()]
	twinkle_holder = [_empty_matrix()]
	# FUN_00450098: the rest yaw of the info centre's doors (nodes 1 and 2) and of node 1 of
	# record 122 read from their node matrices.
	for i in 2:
		var m: PackedFloat32Array = services.model_node_matrix(records[SWING_RECORD], i + 1)
		swing_angles[i] = atan2(m[8], m[10])
	var w: PackedFloat32Array = services.model_node_matrix(records[WOBBLE_RECORD], 1)
	wobble_angle = atan2(w[8], w[10])
	if wobble_angle < -PI:
		wobble_angle += TAU_F
	elif wobble_angle > PI:
		wobble_angle -= TAU_F


## FUN_00429900 for the six rocket01 emitters (matrices 0xA0D8 + 0x40 * i), run while
## (var 0x110 & 2) == 2 until the block below switches them by hand.
func add_rockets(count: int) -> void:
	for i in count:
		var holder: Array = [_empty_matrix()]
		rocket_holders.append(holder)
		var handle: int = services.particle_create("rocket01.par", null, Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0), [0x110, 2, 2])
		services.particle_attach_ref(handle, holder)
		rockets.append(handle)


func add_bill() -> void:
	for i in 2:
		var holder: Array = [_empty_matrix()]
		bill_holders.append(holder)
		var handle: int = services.particle_create("bill01.par", null, Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0), [])
		services.particle_attach_ref(handle, holder)
		bill.append(handle)


func add_zzz() -> void:
	zzz = services.particle_create("zzz.par", null, Vector3(0.0, 0.3, 0.2), Vector3.ZERO, [0x110, 1, 1])
	services.particle_attach_ref(zzz, zzz_holder)


func add_twinkle() -> void:
	twinkle = services.particle_create("twinkle03.par", null, Vector3.ZERO, Vector3(-PI / 2.0, 0.0, 0.0), [])
	services.particle_attach_ref(twinkle, twinkle_holder)


func read_var(id: int) -> int:
	return Game.get_var(id)


func write_var(id: int, value: int) -> void:
	Game.set_var(id, value)


## dest = node matrix of the record's model times the record's own matrix (FUN_004225E5).
func _world(record, node: int) -> PackedFloat32Array:
	return services.matrix_multiply(services.anim_node_matrix(record, node), services.actor_matrix(record))


func _position(record) -> Vector3:
	return Vector3(record.x, record.y, record.z)


func tick() -> void:
	var state := read_var(0x58)
	_rotors()
	_swing()
	_pizza()
	_rockets()
	_fade(state)
	_bill_hands()
	_twinkle_marks()
	_flags()
	_wobble()


func _rotors() -> void:
	var v := read_var(0x131)
	if v == 0:
		return
	rotor_angle += float(v) / 10.0
	for pair in ROTOR_RECORDS:
		services.set_node_rotation(records[pair[0]], int(pair[1]), 0.0, rotor_angle, 0.0)


func _swing() -> void:
	var v := read_var(0x106)
	if v == 0:
		return
	var phase := v + 1
	if phase == 0 or phase == 2:
		swing_angles = [0.0, 0.0]
		swing_speeds = [float(v) * -0.1, float(v) * 0.1]
		services.sound_follow(SOUND_SWING, _position(records[124]))
		write_var(0x106, 2)
		phase = 3
	if phase == 3:
		for i in 2:
			swing_angles[i] += swing_speeds[i]
			if absf(swing_angles[i]) > SWING_LIMIT:
				swing_speeds[i] *= SWING_DAMP
				write_var(0x106, 3)
			services.set_node_rotation(records[SWING_RECORD], i + 1, 0.0, swing_angles[i], 0.0)
	elif phase == 4:
		for i in 2:
			swing_angles[i] += swing_speeds[i]
			if absf(swing_angles[i]) < SWING_REST:
				swing_speeds = [0.0, 0.0]
				swing_angles = [0.0, 0.0]
				write_var(0x106, 0)
			services.set_node_rotation(records[SWING_RECORD], i + 1, 0.0, swing_angles[i], 0.0)


func _pizza() -> void:
	if (read_var(0x11F) & 1) == 0:
		return
	var record = records[PIZZA_RECORD]
	if timer <= 0.0:
		record.flags &= ~2
	else:
		timer -= PIZZA_STEP


func _rockets() -> void:
	var v := read_var(0x110)
	if v == 0:
		return
	var started := false
	if v == 1:
		services.sound_follow(SOUND_INFO, _position(records[INFO_RECORD]))
	if (v & 0x1000) != 0:
		started = true
		v &= ~0x1000
		write_var(0x110, v)
	for flagged in FLAG_RECORDS:
		records[flagged].flags &= ~0x10
	for bit in 8:
		var mask := 1 << bit
		var record_index: int = ROCKET_SLOT_RECORDS.get(v & mask, 0)
		if record_index == 0:
			continue
		var slot: int = ROCKET_SLOT.get(v & mask, 0)
		if (v & 0x80) != 0:
			_rocket_mode(slot, 1)
			continue
		if (v & 0x7F) == 1:
			if zzz >= 0:
				zzz_holder[0] = _world(records[INFO_RECORD], 10)
			continue
		if slot + 1 < rocket_holders.size():
			rocket_holders[slot][0] = _world(records[record_index], 5)
			rocket_holders[slot + 1][0] = _world(records[record_index], 7)
		if started:
			_rocket_mode(slot, 2)


func _rocket_mode(slot: int, mode: int) -> void:
	if slot + 1 < rockets.size():
		services.particles(rockets[slot], mode)
		services.particles(rockets[slot + 1], mode)


func _fade(state: int) -> void:
	var id := 0
	var v := 0
	if state < 7:
		id = 0x128
		v = read_var(0x128)
	elif state >= 0x3D:
		id = 0xD
		v = read_var(0xD)
	if v == 0:
		return
	var overlay = records[FADE_RECORD]
	if v == 1:
		timer = 0.0
		write_var(id, 2)
	elif v == 2:
		if timer < 1.0:
			overlay.flags |= 2
			timer += FADE_STEP
			if timer > 1.0:
				write_var(id, 5 if id == 0xD else 0)
			timer = minf(timer, 1.0)
			services.set_actor_matrix(overlay, Vector3(overlay.field_f(0x4C), overlay.field_f(0x50), overlay.field_f(0x54)),
				Vector3(overlay.x, overlay.y, overlay.z), Vector3(timer, timer, timer))
	elif v == 3:
		overlay.flags &= ~2
		write_var(id, 0)


func _bill_hands() -> void:
	var v := read_var(0x109)
	if v == 0 or bill.size() < 2:
		return
	var record = records[BILL_RECORD]
	bill_holders[0][0] = _world(record, 0xE)
	bill_holders[1][0] = _world(record, 0x10)
	if v == 1:
		services.particles(bill[0], 2)
		services.particles(bill[1], 2)
		write_var(0x109, 2)
	elif v == 3:
		services.particles(bill[0], 1)
		services.particles(bill[1], 1)
		write_var(0x109, 0)


func _twinkle_marks() -> void:
	var v := read_var(0xFF)
	if v == 0:
		return
	var fresh := false
	if (v & 1) != 0:
		fresh = true
		v &= ~1
		write_var(0xFF, v)
	if (v & 0x80) == 0:
		var record_index: int = TWINKLE_RECORDS.get(v, 0)
		if record_index != 0 and fresh and twinkle >= 0:
			var record = records[record_index]
			twinkle_holder[0] = services.actor_matrix(record)
			services.particles(twinkle, 2)
			services.sound_follow(SOUND_TWINKLE, _position(record))
	elif twinkle >= 0:
		services.particles(twinkle, 1)
		write_var(0xFF, v & ~0x80)


func _flags() -> void:
	var v := read_var(0x129)
	if v == 1:
		for index in FLAG_RECORDS:
			records[index].flags |= 0x10
	elif v == 2:
		for index in FLAG_RECORDS:
			records[index].flags &= ~0x10


func _wobble() -> void:
	var v := read_var(0x134)
	if v == 0:
		return
	if v == 1:
		wobble_angle = 0.0
		wobble_speed = 0.10000000149011612
		write_var(0x134, 2)
	elif v != 2:
		return
	wobble_angle += wobble_speed
	if absf(wobble_angle) > WOBBLE_LIMIT:
		wobble_speed = 0.0
		write_var(0x134, 0)
	services.set_node_rotation(records[WOBBLE_RECORD], 1, 0.0, wobble_angle, 0.0)
