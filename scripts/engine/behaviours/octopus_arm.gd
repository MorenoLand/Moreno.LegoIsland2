class_name OctopusArm
extends Behaviour

## FUN_00524580 (ctor) / FUN_00524268 (update, vtable 0x008C5DA0, returns 1). The octopus of the
## dive plays its first half of frames, then its second, while its arm (record 69) swings up
## and down in roll between -70 and 0 degrees.
##
## Node: +0x18 arm speed (starts at -0.69813), +0x1C first half done, +0x20 first half running
## (starts 1), +0x24 second half done, +0x28 second half running.

const ARM_RECORD := 69
const ARM_DOWN := -1.2217239
const ARM_NEAR_DOWN := -0.261798
const ARM_NEAR_UP := -1.047192
const FIRST_HALF_END := 30.0
const STEP := 0.15

var speed := -0.69813
var first_done := 0
var first_running := 1
var second_done := 0
var second_running := 0

var services: ActorServices


static func from_descriptor(services_in: ActorServices) -> OctopusArm:
	var b := OctopusArm.new()
	b.services = services_in
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func update(actor, _block: BehaviourBlock, _var_value: int) -> int:
	var dt := DiveWorld.dt
	var arm = services.record_at(ARM_RECORD)
	var roll: float = arm.field_f(0x54)
	var hit_up := false
	var hit_down := false
	var frame := services.anim_frame(actor)
	var length := services.anim_length(actor)
	if 0.0 < speed:
		if 0.0 <= roll:
			hit_up = true
			roll = 0.0
		else:
			if ARM_NEAR_UP < roll:
				speed = 2.2672
			roll = speed * dt * STEP + roll
	elif roll <= ARM_DOWN:
		hit_down = true
		roll = ARM_DOWN
	else:
		if roll < ARM_NEAR_DOWN:
			speed = -1.9196
		roll = speed * dt * STEP + roll
	if first_running != 0:
		if frame < 0.0 or FIRST_HALF_END <= frame:
			first_running = 0
			first_done = 1
		else:
			services.clip_finished(actor, STEP)
	if second_running != 0:
		if frame < FIRST_HALF_END or length <= frame:
			second_running = 0
			second_done = 1
		else:
			services.clip_finished(actor, STEP)
	if first_done != 0 and hit_down:
		speed = 0.34907
		first_done = 0
		second_running = 1
	if second_done != 0 and hit_up:
		speed = -0.69813
		second_done = 0
		first_running = 1
	arm.set_field_f(0x54, roll)
	return 1
