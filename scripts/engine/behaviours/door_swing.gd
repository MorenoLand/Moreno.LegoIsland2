class_name DoorSwing
extends Behaviour

## FUN_004D0510 (ctor) / FUN_004CFFDE (update, vtable 0x008B9F40), returns 0. A door that
## swings one model sub-node open when Pepper comes near (or a switch var asks for it) and
## shut when Pepper leaves. State: 0 shut, 1 opening, 2 open, 3 closing.
##
## Node: +0x14 squared near range, +0x18 squared far range, +0x1C..+0x24 pivot (sub-node
## position, moved along its axis), +0x28 closed angle, +0x2C speed, +0x30 open angle,
## +0x34 sub-node index, +0x36 flags (bit 1 stays open), +0x38 switch var (-1 none),
## +0x3C state, +0x40 angle.

const PIVOT_SHIFT := 1.2200000286102295
const NEAR_PUSH := 16.0
const STAY_NEAR := 4.326399803161621

var near_squared := 0.0
var far_squared := 0.0
var pivot := Vector3.ZERO
var closed_angle := 0.0
var speed := 0.0
var open_angle := 0.0
var node_index := 0
var flags := 0
var switch_var := -1
var state := 0
var angle := 0.0
var forced_tag := -1

var services: ActorServices
var vars


static func from_descriptor(desc: Descriptor, services_in: ActorServices, vars_in, actor) -> DoorSwing:
	var b := DoorSwing.new()
	b.services = services_in
	b.vars = vars_in
	b.switch_var = desc.s32(0x10)
	b.near_squared = 6.0 if b.switch_var < 0 else 12.0
	b.node_index = desc.s32(4)
	if desc.s32(4) < services_in.model_node_count(actor):
		var m := services_in.model_node_matrix(actor, b.node_index)
		b.pivot = Vector3(m[12], m[13], m[14])
		var bits := desc.u32(12)
		if (bits & 0x300) != 0:
			var shift := Vector3(m[0], m[1], m[2]) * PIVOT_SHIFT
			b.pivot = b.pivot - shift if (bits & 0x100) != 0 else b.pivot + shift
		elif (bits & 0xC00) != 0:
			var shift := Vector3(m[8], m[9], m[10]) * PIVOT_SHIFT
			b.pivot = b.pivot - shift if (bits & 0x400) != 0 else b.pivot + shift
		var reach := sqrt(b.pivot.z * b.pivot.z + b.pivot.y * b.pivot.y + b.pivot.x * b.pivot.x) + b.near_squared
		b.far_squared = reach * reach
		b.near_squared = b.near_squared * b.near_squared
		b.closed_angle = atan2(m[8], m[10])
		b.open_angle = b.closed_angle - desc.f32(8)
		b.speed = -desc.f32(0)
		b.flags = desc.s16(12)
		b.angle = b.closed_angle
		services_in.set_node_rotation(actor, b.node_index, 0.0, b.angle, 0.0)
	else:
		b.forced_tag = 1
	b.state = 0
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


## FUN_004CFF8C: clamp `angle` to `limit` once it has run past it and return `result`.
func _clamp(moving: float, limit: float, result: int) -> int:
	if 0.0 <= moving:
		if limit < angle:
			angle = limit
			return result
	elif angle < limit:
		angle = limit
		return result
	return -1


func _push_player(offset: Vector3) -> void:
	var player = services.player
	var unit := offset
	if unit.length_squared() != 0.0:
		unit = unit / sqrt(unit.length_squared()) * 1.0
	unit = unit * (0.10000000149011612 * 1.0)
	player.x += unit.x
	player.y += unit.y
	player.z += unit.z


func update(actor, _block: BehaviourBlock, _var_value: int) -> int:
	var dist2 := -1.0
	var clamp_result := -1
	var open_request := false
	if services.scene_active or (actor.flags & 2) == 0:
		return 0
	if not (state != 0 or switch_var > -1 or ((services.talk.game_flags & 0x40) != 0 and (vars.get_var(0x5E) & 5) != 0)):
		return 0
	var player = services.player
	var at := services.actor_point(actor, pivot)
	var d := Vector3(player.x - at.x, player.y - at.y, player.z - at.z)
	if absf(d.y) > 4.0:
		return 0
	d.y = 0.0
	dist2 = d.z * d.z + d.x * d.x + 0.0
	if dist2 < near_squared and switch_var > -1:
		vars.or_var(0xC, 0x20)
	match state:
		1:
			if dist2 <= NEAR_PUSH and switch_var < 0:
				_push_player(d)
			angle = speed * 1.0 + angle
			clamp_result = _clamp(speed, open_angle, 2)
		2:
			if (services.talk.game_flags & 0x40) != 0 and switch_var < 0:
				open_request = true
		3:
			if dist2 <= NEAR_PUSH and switch_var < 0:
				_push_player(d)
			angle = angle - speed * 1.0
			clamp_result = _clamp(-speed, closed_angle, 0)
	match state:
		0:
			if dist2 < near_squared:
				state = 1
		1, 3:
			services.set_node_rotation(actor, node_index, 0.0, angle, 0.0)
			if clamp_result != -1:
				state = clamp_result
		2:
			if not open_request:
				if (flags & 1) != 0 or (((dist2 <= far_squared or switch_var > -1) and (dist2 <= near_squared or switch_var < 0))):
					if dist2 <= STAY_NEAR and switch_var > -1 and (vars.get_var(0x5E) & 5) != 0:
						vars.set_var(5, switch_var)
				else:
					state = 3
			else:
				state = 3
	return 0
