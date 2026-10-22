class_name ClamHinge
extends Behaviour

## FUN_0052402A (ctor) / FUN_00523B9A (update, vtable 0x008C5D50, returns 1). The clam of the dive
## opens and shuts about its x axis: the speed eases towards the ends of the arc, the shell creaks
## while it opens and snaps shut with a sound.
##
## Node: +0x18 speed (starts at -0.8727), +0x1C opened latch, +0x20 pause timer.

const MIDDLE := 0.39269698
const OPEN_LIMIT := -0.78539395
const PAUSE := 4.0

var speed := -0.8727
var opened := 0
var pause := 0.0

var services: ActorServices


static func from_descriptor(services_in: ActorServices) -> ClamHinge:
	var b := ClamHinge.new()
	b.services = services_in
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func update(actor, _block: BehaviourBlock, _var_value: int) -> int:
	var dt := DiveWorld.dt
	var at := Vector3(actor.x, actor.y, actor.z)
	var angle: float = actor.field_f(0x4C)
	var swing := absf(angle + MIDDLE)
	var ease_scale := (1.0 - swing / MIDDLE) + 0.5
	if 1.0 < ease_scale:
		ease_scale = 1.0
	ease_scale = ease_scale * ease_scale * ease_scale
	if speed <= 0.0:
		if pause == 0.0:
			angle = dt * ease_scale * speed + angle
			if angle < OPEN_LIMIT:
				speed = -speed
				pause = PAUSE
			services.sound_follow(DiveWorld.SOUND_CLAM_CREAK, at)
			opened = 0
		else:
			pause -= dt
			if pause < 0.0:
				pause = 0.0
	if 0.0 < speed:
		if pause == 0.0:
			services.sound_release(DiveWorld.SOUND_CLAM_CREAK)
			angle = dt * ease_scale * speed + angle
			if 0.0 < angle:
				services.sound_follow(DiveWorld.SOUND_CLAM_SHUT, at)
				speed = -speed
				if opened != 0:
					pause = PAUSE
		else:
			pause -= dt
			if pause < 0.0:
				pause = 0.0
	actor.set_field_f(0x4C, angle)
	return 1
