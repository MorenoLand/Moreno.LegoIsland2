class_name ParkWalk
extends Behaviour

## The park's walk to the board: constructor FUN_007EDAA3, update FUN_007ED740 (returns 1). It runs
## while the input selector (var 0x5E) is 1, which is how the run starts and how it starts again after
## a crash: Pepper turns to the spot where the board waits, walks to it, and when he is within 0.8 of it
## he gets on (the board appears, the selector becomes 4). The camera stays where it is and looks at him.
##
## Fields of the original object: +0x15 the clip he walks in (0x1B at first), +0x16 that clip ran out,
## +0x17 he has turned towards the spot.

const SPOT := Vector3(33.900001525878906, 16.299999237060547, -29.0)
const ARRIVED := 0.800000011920929
const TURN_MIN := 6.800000190734863
const TURN_DONE := 6.0
const TURN_STEP := 0.7853981852531433
const STEP := 0.20000000298023224
const CLIP_INTO_WALK := 0x1B
const CLIP_WALK := 0x0D
const CLIP_MOUNT := 0x16
const BOARD_CLIP_ON := 1
const SELECTOR_BOARD := 4
const CAMERA_RISE := 3.0

var clip := CLIP_INTO_WALK
var clip_done := false
var turned := false

var services: ActorServices
var vars


static func from_descriptor(services_in: ActorServices, vars_in) -> ParkWalk:
	var b := ParkWalk.new()
	b.services = services_in
	b.vars = vars_in
	services_in.talk.pepper_clip = b.clip
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func update(actor, _block: BehaviourBlock, _var_value: int) -> int:
	var g := services.talk
	var here := Vector3(actor.x, actor.y, actor.z)
	var gap := SPOT - here
	var distance := gap.length()
	var forward := Vector3(actor.field_f(0x2C), actor.field_f(0x30), actor.field_f(0x34))
	if distance <= ARRIVED:
		services.set_clip(actor, CLIP_MOUNT, 0.0)
		var board = services.record_at(g.hidden_record)
		services.set_clip(board, BOARD_CLIP_ON, 0.0)
		vars.set_var(tag, SELECTOR_BOARD)
		clip = CLIP_MOUNT
		g.pepper_clip = clip
		board.flags |= 2
	else:
		var along := forward.dot(gap)
		if along < TURN_MIN and not turned:
			actor.yaw += TURN_STEP
			if along > TURN_DONE:
				turned = true
		else:
			actor.yaw = atan2(gap.x, gap.z)
			actor.x += forward.x * STEP
			actor.z += forward.z * STEP
		services.set_matrix_yaw(actor, Vector3(actor.x, actor.y, actor.z))
		clip_done = services.clip_advance(actor, 1.0) != 0
		if clip_done and clip == CLIP_INTO_WALK:
			services.set_clip(actor, CLIP_WALK, 0.0)
			clip = CLIP_WALK
	services.camera_target = Vector3(actor.x, actor.y + CAMERA_RISE, actor.z)
	return 1
