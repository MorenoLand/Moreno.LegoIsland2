class_name DiveBrick
extends Behaviour

## FUN_00526188 (ctor) / FUN_00525C91 (update, vtable 0x008C5EE0, returns 1). One of the five bricks of
## the dive. It lies on the sea floor until the swimmer picks it up (it can be picked up once it has
## been loose for four seconds: it starts at ten); a dropped brick sinks and bounces (FUN_00522164),
## is knocked by the anchor, and is hidden again when it comes to rest.
##
## Node: +0x18 outline count (4), +0x1C outline, +0x4C the outline in the world, +0x7C last position,
## +0x88 velocity, +0x9C spin, +0xA0 flying, +0xA4 age.

const OUTLINE := [Vector3(1.600000023841858, 0.8999999761581421, 10.0), Vector3(-1.600000023841858, 0.8999999761581421, 10.0), Vector3(-1.600000023841858, 0.10000000149011612, 10.0), Vector3(1.600000023841858, 0.10000000149011612, 10.0)]
const FALL := 2.0

var outline := PackedVector3Array(OUTLINE)
var flying := false
var age := 10.0
var last_position := Vector3.ZERO
var velocity := Vector3.ZERO
var spin := 0.0

var services: ActorServices


static func from_descriptor(services_in: ActorServices, actor) -> DiveBrick:
	var b := DiveBrick.new()
	b.services = services_in
	actor.flags |= 2
	actor.flags &= ~0x10
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


## FUN_00525B1B: can the swimmer take it now. A brick that has been loose for four seconds is
## taken: hidden and marked.
func take(actor) -> bool:
	var ready := 4.0 <= age
	if ready:
		flying = false
		actor.flags &= ~2
		actor.flags |= 0x10
	return ready


## FUN_00525B81(brick, spot): dropped by the swimmer.
func drop(actor, spot: Vector3) -> void:
	flying = true
	age = 0.0
	actor.flags |= 2
	actor.flags &= ~0x10
	actor.x = spot.x
	actor.y = spot.y
	actor.z = 10.0
	actor.set_field_f(0x4C, 0.0)
	actor.yaw = 0.0
	actor.set_field_f(0x54, 0.0)
	last_position = Vector3(actor.x, actor.y, actor.z)
	velocity = Vector3.ZERO
	spin = 0.0


func update(actor, _block: BehaviourBlock, _var_value: int) -> int:
	var dt := DiveWorld.dt
	age += dt
	if flying:
		var here := Vector3(actor.x, actor.y, actor.z)
		var points := DiveWorld.rotate_points(outline, actor.field_f(0x54) + 1.5707964)
		for i in points.size():
			points[i] = Vector3(points[i].x + here.x, points[i].y + here.y, points[i].z)
		var list: Array = []
		for index in [DiveWorld.R_SEA, DiveWorld.R_ANCHOR] + DiveWorld.R_BRICKS + [DiveWorld.R_OCTOPUS_ARM, DiveWorld.R_WALL]:
			list.append(services.record_at(index))
		var touched := DiveWorld.edge_hits(points, actor, list)
		var on_wall := false
		var anchor = services.record_at(DiveWorld.R_ANCHOR)
		var on_anchor: bool = touched["records"].has(anchor)
		for record in touched["records"]:
			if record != anchor:
				on_wall = true
		velocity.y -= dt * FALL
		if on_anchor:
			velocity = DiveWorld.bump(anchor, DiveWorld.anchor_speed(anchor), anchor.field_f(0x54), here)
		if on_wall:
			actor.x = last_position.x
			actor.y = last_position.y
			actor.z = last_position.z
			var result := DiveWorld.bounce(velocity, last_position, touched["normal"], touched["point"])
			velocity = result["velocity"]
			spin = result["spin"]
			if result["rest"]:
				flying = false
		last_position = Vector3(actor.x, actor.y, actor.z)
		actor.x += velocity.x * dt
		actor.y += velocity.y * dt
		actor.set_field_f(0x54, spin * dt + actor.field_f(0x54))
	return 1
