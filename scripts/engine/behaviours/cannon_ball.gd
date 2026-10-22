class_name CannonBall
extends Behaviour

## FUN_00522CE7 (ctor) / FUN_00522870 (update, vtable 0x008C5C50, returns 1). A ball of the dive's
## cannon: once fired it flies, falls, bounces off the sea floor (FUN_00522164) and is knocked about
## by the swinging anchor; after 20 seconds it goes back to the cannon's pool, hidden.
##
## Node: +0x18 outline count (4), +0x1C outline, +0x4C the outline in the world, +0x7C last
## position, +0x88 velocity, +0x9C spin, +0xA0 flying, +0xA4 age.

const LIFETIME := 20.0
const FALL := 4.0
const OUTLINE := [Vector3(0.800000011920929, 0.800000011920929, 10.0), Vector3(-0.800000011920929, 0.800000011920929, 10.0), Vector3(-0.800000011920929, -0.800000011920929, 10.0), Vector3(0.800000011920929, -0.800000011920929, 10.0)]

var outline := PackedVector3Array(OUTLINE)
var flying := false
var age := 0.0
var last_position := Vector3.ZERO
var velocity := Vector3.ZERO
var spin := 0.0

var services: ActorServices


static func from_descriptor(services_in: ActorServices) -> CannonBall:
	var b := CannonBall.new()
	b.services = services_in
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


## FUN_005226CB(ball, spot, speed): fired from the cannon.
func launch(actor, spot: Vector3, push: Vector3) -> void:
	flying = true
	age = 0.0
	actor.flags |= 2
	actor.x = spot.x
	actor.y = spot.y
	actor.z = 10.0
	actor.set_field_f(0x4C, 0.0)
	actor.yaw = 0.0
	actor.set_field_f(0x54, 0.0)
	last_position = Vector3(actor.x, actor.y, actor.z)
	velocity = Vector3(push.x, push.y, 40.0)
	spin = 0.0
	DiveWorld.cannon_balls_out += 1


## FUN_0052280D + FUN_00522E40: the ball is spent, hidden and put back in the cannon's pool.
func retire(actor) -> void:
	actor.flags &= ~2
	flying = false
	DiveWorld.cannon_balls_out -= 1
	var cannon = services.record_at(DiveWorld.R_CANNON)
	var item = cannon.block.head if cannon.block != null else null
	while item != null:
		if item is DiveCannon:
			item.take_back(actor)
			return
		item = item.next


func update(actor, _block: BehaviourBlock, _var_value: int) -> int:
	var dt := DiveWorld.dt
	if not flying:
		return 1
	age += dt
	if LIFETIME < age:
		retire(actor)
		return 1
	var here := Vector3(actor.x, actor.y, actor.z)
	var points := DiveWorld.rotate_points(outline, actor.field_f(0x54) + 1.5707964)
	for i in points.size():
		points[i] = Vector3(points[i].x + here.x, points[i].y + here.y, points[i].z)
	var sea = services.record_at(DiveWorld.R_SEA)
	var anchor = services.record_at(DiveWorld.R_ANCHOR)
	var touched := DiveWorld.edge_hits(points, actor, [sea, anchor])
	velocity.y -= dt * FALL
	if touched["records"].has(anchor):
		velocity = DiveWorld.bump(anchor, DiveWorld.anchor_speed(anchor), anchor.field_f(0x54), here)
	if touched["records"].has(sea):
		here = last_position
		actor.x = here.x
		actor.y = here.y
		actor.z = here.z
		var result := DiveWorld.bounce(velocity, here, touched["normal"], touched["point"])
		velocity = result["velocity"]
		spin = result["spin"]
	last_position = Vector3(actor.x, actor.y, actor.z)
	actor.x += velocity.x * dt
	actor.y += velocity.y * dt
	actor.set_field_f(0x54, spin * dt + actor.field_f(0x54))
	return 1
