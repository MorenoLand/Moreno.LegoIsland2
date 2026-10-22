class_name DivePirate
extends Behaviour

## FUN_00523854 (ctor) / FUN_00523410 (update, vtable 0x008C5CF0, returns 1). The pirate of the dive
## sleeps until the last brick is taken (FUN_005233A0), wakes when the swimmer comes within 10
## units and then faces him; its clip follows what the swimmer carries: the attack clip (1) is
## chosen at the end of a clip while he is near and holds a brick.
##
## Node: +0x18 enabled, +0x1C awake, +0x20 swimmer near, +0x24 clip (-1 none), +0x28 pause.

const WAKE_SQUARED := 100.0
const NEAR_SQUARED := 256.0

var enabled := 0
var awake := 0
var near := 0
var clip := -1
var pause := 0.0

var services: ActorServices


static func from_descriptor(services_in: ActorServices, actor) -> DivePirate:
	var b := DivePirate.new()
	b.services = services_in
	services_in.set_clip(actor, 3, 1.0)
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


## FUN_005233A0
func enable() -> void:
	enabled = 1


## FUN_005233C4: the pirate is attacking.
func attacking() -> bool:
	return clip == 1


## FUN_005233EC: the swimmer has just been caught.
func rest() -> void:
	pause = 10.0


func update(actor, _block: BehaviourBlock, _var_value: int) -> int:
	var swimmer = services.record_at(DiveWorld.R_SWIMMER)
	var here := Vector3(actor.x, actor.y, actor.z)
	var other := Vector3(swimmer.x, swimmer.y, swimmer.z)
	if enabled != 0 and awake == 0:
		if (here - other).length_squared() < WAKE_SQUARED:
			awake = 1
			near = 1
			clip = 3
			services.set_clip(actor, clip, 1.0)
			services.sound_play(0x5D4C834)
			DiveWorld.say("CASGBD06")
	if awake != 0:
		if pause != 0.0:
			pause -= DiveWorld.dt
			if pause < 0.0:
				pause = 0.0
		var d := other - here
		near = 0 if NEAR_SQUARED <= d.length_squared() else 1
		var n := d.normalized()
		var facing := atan2(n.x, n.z)
		actor.set_field_f(0x4C, 0.0)
		actor.yaw = facing
		actor.set_field_f(0x54, 0.0)
		var finished := false
		if clip != -1:
			var length := services.anim_length(actor)
			var frame := services.anim_frame(actor)
			if length - 2.0 < frame:
				finished = true
		if finished:
			var wanted := 2
			var holding: bool = DiveWorld.swimmer != null and DiveWorld.swimmer.held != null
			if clip == 3 and near != 0 and holding:
				wanted = 1
			if clip == 2 and near != 0 and pause == 0.0 and holding:
				wanted = 1
			if clip == 1 and near != 0 and pause == 0.0 and holding:
				wanted = 1
			if wanted != clip:
				clip = wanted
				services.set_clip(actor, clip, 1.0)
	if clip != -1:
		services.clip_finished(actor, 1.0)
	return 1
