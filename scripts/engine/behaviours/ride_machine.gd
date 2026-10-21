class_name RideMachine
extends Behaviour

## FUN_00880905 (ctor) / FUN_0087FB26 (update, vtable 0x00975060) / FUN_008805E6 (post),
## update returns 0 / 1. A machine Pepper can ride (var bit 0x10000000 = being ridden):
## the nearest one within reach is chosen, then it is steered with the controls (left /
## right turn it, accelerate / brake change the thrust), follows the ground, slides along
## walls and drags the camera with it.
##
## Node: +0x1C / +0x20 steering steps (0x10 centre), +0x24 / +0x28 steering amounts, +0x2C
## bump timer, +0x30 hold, +0x34 thrust, +0x3C input bits, +0x40 / +0x44 input axes,
## +0x48 / +0x4C / +0x50 velocity, +0x1A ridden before.

## DAT_00975078: steering curve (0..32 -> 0..255).
const CURVE := [0, 8, 16, 24, 32, 40, 48, 56, 64, 72, 80, 88, 96, 104, 112, 120, 128, 136, 144, 152, 160, 168, 176, 184, 192, 200, 208, 216, 224, 232, 240, 248, 255]
const CAMERA_OFFSET := Vector3(0.0, 12.0, -16.0)
const NEAR := 12.0
const NO_GROUND := -1000.0

var steer_a := 0x10
var steer_b := 0x10
var amount_a := 0
var amount_b := 0
var bump_timer := 0.0
var hold := 0.0
var thrust := 0.0
var input_bits := 0
var axis_x := 0
var axis_y := 0
var velocity := Vector3.ZERO
var ridden := 0

var services: ActorServices
var vars


static func from_descriptor(services_in: ActorServices, vars_in, tag_in: int) -> RideMachine:
	var b := RideMachine.new()
	b.services = services_in
	b.vars = vars_in
	vars_in.clear_var(tag_in, 0x10000000)
	b.steer_a = 0x10
	b.steer_b = 0x10
	b.amount_a = 0
	b.amount_b = 0
	b.thrust = 0.0
	b.hold = 0.0
	b.bump_timer = 0.0
	b.ridden = 0
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	mask = 0
	value = 0


## FUN_0087F7E9: step the two steering values toward the held direction bits.
func _steer_steps() -> void:
	var a := steer_a
	var b := steer_b
	var moved_a := false
	var moved_b := false
	var held: int = services.talk.game_flags_b
	if (held & 1) != 0:
		moved_a = true
		a = a - 3 if a < 0x11 else 0x10
		if a < 1:
			a = 0
	if (held & 2) != 0:
		moved_a = true
		a = 0x10 if a < 0x10 else a + 3
		if 0x1F < a:
			a = 0x20
	if (held & 4) != 0:
		moved_b = true
		b = b - 3 if b < 0x11 else 0x10
		if b < 1:
			b = 0
	if (held & 8) != 0:
		moved_b = true
		b = 0x10 if b < 0x10 else b + 3
		if 0x1F < b:
			b = 0x20
	if not moved_a:
		if 0x10 < a:
			a -= 4
			if a < 0x10:
				a = 0x10
		if a < 0x10:
			a += 4
			if 0x10 < a:
				a = 0x10
	if not moved_b:
		if 0x10 < b:
			b -= 4
			if b < 0x10:
				b = 0x10
		if b < 0x10:
			b += 4
			if 0x10 < b:
				b = 0x10
	steer_b = b
	amount_b = CURVE[b] - 0x80
	steer_a = a
	amount_a = CURVE[a] - 0x80


## FUN_0087F9B6: read the controls, turn the machine and change the thrust.
func _steer(actor) -> void:
	_steer_steps()
	var inputs := services.read_input()
	input_bits = inputs[0]
	axis_x = inputs[1]
	axis_y = inputs[2]
	if 0x14 < axis_x or axis_x < -0x14:
		amount_a = axis_x
	var held: int = services.talk.game_flags_b
	if (held & 0x80) == 0:
		if 0.0 < thrust:
			thrust -= 0.02500000037252903
	elif 1.0 <= thrust:
		thrust = 1.0
	else:
		thrust += 0.05000000074505806
	if (held & 0x20) == 0:
		if thrust < 0.0:
			thrust += 0.02500000037252903
	elif thrust <= -0.75:
		thrust = -0.75
	else:
		thrust -= 0.009999999776482582
	var yaw: float = actor.yaw
	if thrust <= 0.05000000074505806:
		if thrust < -0.05000000074505806:
			yaw -= float(amount_a) * 0.000750000006519258 * 1.0
	else:
		yaw += float(amount_a) * 0.000750000006519258 * 1.0
	actor.yaw = yaw


func _rig_point(local: Vector3) -> Vector3:
	return services.actor_point(services.camera_rig, local)


func update(actor, block: BehaviourBlock, var_value: int) -> int:
	var g := services.talk
	var player = services.player
	var rig = services.camera_rig
	if (var_value & 0x10000000) == 0:
		if services.scene_active:
			return 0
		if (g.game_flags & 0x10) == 0 or g.pepper_clip == 0x62 or (vars.get_var(0x5E) & 1) == 0 or (actor.flags & 2) == 0:
			if g.machine_actor == actor:
				g.machine_taken = 1
				return 1
			if block.distance_squared < g.machine_distance and (actor.flags & 2) != 0:
				vars.or_var(0xC, 2)
			if (var_value & 0x20000000) == 0:
				vars.or_var(tag, 0x20000000)
			return 0
		if (actor.flags & 2) == 0:
			return 0
		if block.distance_squared < g.machine_distance and 0.0 < block.distance_squared:
			g.machine_actor = actor
			g.machine_distance = block.distance_squared
		return 1
	if actor != g.machine_actor:
		return 1
	if ridden != 0:
		ridden = 0
		bump_timer = 0.0
		hold = 0.0
		thrust = 0.0
		velocity = Vector3.ZERO
		steer_a = 0x10
		amount_a = 0
		steer_b = 0x10
		amount_b = 0
	_steer(actor)
	var length := services.anim_length(player)
	var frame := (length - 1.0) * 0.5
	frame = frame * (float(amount_a) / 127.0) + frame
	services.anim_set_frame(player, frame)
	var speed := velocity.length()
	if 0.0 < speed:
		services.set_matrix_at(actor, Vector3(actor.x, actor.y, actor.z))
		services.align_to_ground_machine(actor)
	var forward := Vector3(actor.field_f(0x2C), actor.field_f(0x30), actor.field_f(0x34))
	var here := Vector3(actor.x, actor.y, actor.z)
	var ground := services.ground_height(here, 4.0)
	if -1000.0 < ground:
		actor.y = ground
	if bump_timer == 0.0:
		velocity = forward * thrust
	elif 20.0 <= bump_timer:
		bump_timer = 0.0
		services.set_clip(player, 0x4C, 0.0)
	else:
		bump_timer = 1.0 * 1.0 + bump_timer
		actor.yaw = 0.5 * 1.0 + actor.yaw
	here = Vector3(actor.x, actor.y, actor.z)
	var step := velocity * 1.0
	if step.length_squared() != 0.0:
		step = step / sqrt(step.length_squared()) * 1.0
	step = step * 8.0
	var ahead := here + step
	ground = services.ground_height(ahead, 4.0)
	if g.ground_min < ground:
		if thrust <= -0.5:
			thrust = -0.5
		else:
			thrust = thrust - 0.10000000149011612 * forward.y
	else:
		velocity = Vector3.ZERO
	var node_a
	var node_b
	var machine = g.machine_actor
	if thrust < 0.0:
		node_a = services.model_node_matrix(machine, 5)
		node_b = services.model_node_matrix(machine, 4)
	else:
		node_a = services.model_node_matrix(machine, 2)
		node_b = services.model_node_matrix(machine, 3)
	var pa := services.actor_point(actor, Vector3(node_a[12], node_a[13], node_a[14]))
	var pb := services.actor_point(actor, Vector3(node_b[12], node_b[13], node_b[14]))
	var mid := Vector3((pa.x + pb.x) * 0.5, (pa.y + pb.y) * 0.5 + 1.600000023841858, (pa.z + pb.z) * 0.5)
	var hit = services.collide_sweep(actor, mid, velocity * 1.0, 3, 0.6000000238418579, 0.6000000238418579)
	if hit != null:
		var normal: Vector3 = hit["normal"]
		var along := normal.dot(velocity)
		velocity = velocity - normal * along
		hit = services.collide_sweep(actor, mid, velocity, 3, 0.6000000238418579, 0.6000000238418579)
		if hit != null:
			velocity.x = -velocity.x
			velocity.z = -velocity.z
			bump_timer = 1.0
			services.set_clip(player, 0x4A, 0.0)
	actor.x = velocity.x * 1.0 + actor.x
	actor.z = velocity.z * 1.0 + actor.z
	var rig_position := Vector3(rig.x, rig.y, rig.z)
	services.camera_target = rig_position
	var wanted := _rig_point(CAMERA_OFFSET)
	var eye := services.camera_eye
	var right := services.camera_right
	if services.camera_locked == 0:
		if bump_timer == 0.0:
			eye = eye + (wanted - eye) * 0.10000000149011612
	else:
		var d := eye - rig_position
		if 13.0 <= d.length():
			if bump_timer == 0.0:
				eye = eye + (wanted - eye) * 0.10000000149011612
		elif thrust <= 0.0:
			eye.x -= right.x * 1.0
			eye.z -= right.z * 1.0
		else:
			eye.x += velocity.x * 1.0
			eye.z += velocity.z * 1.0
	services.camera_eye = eye
	services.camera_ease_height(actor.y)
	return 1


func has_post() -> bool:
	return true


func post(actor) -> void:
	var g := services.talk
	if g.machine_taken == 0 and ((g.game_flags & 0x10) == 0 or g.pepper_clip == 0x62):
		if g.machine_actor == null:
			vars.or_var(tag, 0x20000000)
			vars.clear_var(tag, 0x10000000)
	else:
		g.machine_taken = 0
		if g.machine_actor == actor:
			if not services.scene_active:
				vars.or_var(tag, 0x10000000)
				vars.set_var(0x5E, 8)
				ridden = 1
				g.list_mode = -1
			else:
				g.machine_actor = null
