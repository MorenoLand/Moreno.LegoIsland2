class_name DiveCamera
extends Behaviour

## FUN_00526677 (ctor) / FUN_0052658E (update, vtable 0x008C5F78, returns 1) with FUN_00526390.
## The camera of the dive follows the swimmer's height along a table of four bands (the exe's
## table at 0x008C5F30: the swimmer's y, then how far the camera sits above him, behind him and the
## height it looks at) and slides sideways with his x.

## y, eye height offset, look height offset, eye distance
const BANDS := [
	[87.0, 35.0, 15.0, 35.0],
	[70.0, 18.0, 0.0, 25.0],
	[27.0, 0.0, 0.0, 46.0],
	[-170.0, -2.0, 0.0, 43.0],
]

static var eye := Vector3(0.0, 60.0, 40.0)
static var target := Vector3(0.0, 60.0, 0.0)

var services: ActorServices


static func from_descriptor(services_in: ActorServices, actor) -> DiveCamera:
	var b := DiveCamera.new()
	b.services = services_in
	eye = Vector3(0.0, 60.0, 40.0)
	target = Vector3(0.0, 60.0, 0.0)
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


## FUN_00526390(position)
static func follow(at: Vector3) -> void:
	var band := 0
	while band < BANDS.size() and BANDS[band][0] >= at.y:
		band += 1
	var along := -1.0073741e+08
	if band == 0 or band == BANDS.size():
		eye.y = at.y
		eye.z = 30.0
		target.y = at.y
	else:
		var above: Array = BANDS[band - 1]
		var below: Array = BANDS[band]
		along = (at.y - below[0]) / (above[0] - below[0])
		eye.y = (above[1] - below[1]) * along + below[1] + at.y
		target.y = (above[2] - below[2]) * along + below[2] + at.y
		eye.z = (above[3] - below[3]) * along + below[3]
	var shift := (at.x / 40.0) * 15.0 * 0.3
	if band == 1:
		shift = (1.0 - along) * shift
	target.x = shift + at.x
	var back := (at.x / 40.0) * 15.0
	if band == 1:
		back = (1.0 - along) * back
	eye.x = at.x - back
	target.z = at.z


func update(actor, _block: BehaviourBlock, _var_value: int) -> int:
	follow(Vector3(actor.x, actor.y, actor.z))
	return 1
