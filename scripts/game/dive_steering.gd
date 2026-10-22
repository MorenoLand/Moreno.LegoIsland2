class_name DiveSteering
extends RefCounted

## The steering block of a swimming creature of the dive and FUN_00521D32 (it turns towards a
## target with an angular acceleration, then thrusts along its heading).
##
## Block: [0] yaw rate, [1] pitch rate, [3] yaw, [4] pitch, [6..8] velocity, [9] turn
## acceleration, [10] turn damping, [11] thrust, [12] drag (the others are unused).

const SNAP := 0.087266
const QUARTER_TURN := 1.5707964

var values: Array = []


func _init() -> void:
	values.resize(13)
	values.fill(0.0)


## The 13 floats a descriptor holds from `first`, then FUN_00521CD4 clears the first nine.
func load_block(desc: Descriptor, first: int) -> void:
	for i in 13:
		values[i] = desc.f32(first + i * 4)
	for i in 9:
		values[i] = 0.0


func steer(actor, target: Vector3, speed_scale: float, services) -> void:
	var dt := DiveWorld.dt
	var here := Vector3(actor.x, actor.y, actor.z)
	var toward := (target - here).normalized()
	var yaw_target := DiveWorld.wrap_angle(atan2(toward.x, toward.z))
	var pitch_target := DiveWorld.wrap_angle(-asin(toward.y))
	var yaw_gap := DiveWorld.angle_gap(yaw_target, values[3])
	var yaw_push := 0.0
	if yaw_gap[0] == 1:
		yaw_push = values[9] * yaw_gap[1] + 0.0
	if yaw_gap[0] == -1:
		yaw_push = yaw_push - values[9] * yaw_gap[1]
	var pitch_gap := DiveWorld.angle_gap(pitch_target, values[4])
	var pitch_push := 0.0
	if pitch_gap[0] == 1:
		pitch_push = values[9] * pitch_gap[1] + 0.0
	if pitch_gap[0] == -1:
		pitch_push = pitch_push - values[9] * pitch_gap[1]
	values[0] = (yaw_push + values[10] * values[0]) * dt
	values[1] = (pitch_push + values[1] * values[10]) * dt
	var yaw: float = dt * values[0] + values[3]
	var pitch: float = values[1] * dt + values[4]
	if yaw_gap[2] < SNAP:
		yaw = yaw_target
	if pitch_gap[2] < SNAP:
		pitch = pitch_target
	yaw = DiveWorld.wrap_angle(yaw)
	pitch = DiveWorld.wrap_angle(pitch)
	var thrust: float = values[11] * speed_scale
	var rows := ActorServices.rotation_rows(pitch + QUARTER_TURN, yaw, 0.0)
	var heading := Vector3(rows[4], rows[5], rows[6])
	values[6] = (heading.x * thrust + values[12] * values[6]) * dt + values[6]
	values[7] = (heading.y * thrust + values[12] * values[7]) * dt + values[7]
	values[8] = (heading.z * thrust + values[12] * values[8]) * dt + values[8]
	actor.x = values[6] * dt + here.x
	actor.y = values[7] * dt + here.y
	actor.z = values[8] * dt + here.z
	actor.set_field_f(0x4C, pitch)
	actor.yaw = yaw
	actor.set_field_f(0x54, 0.0)
	values[3] = yaw
	values[4] = pitch
	services.clip_finished(actor, 1.0)
