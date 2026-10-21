class_name Butterfly
extends RefCounted

const TICK_RATE := 30.0
const RANGE_SCALE := 8.0
const FAR := 1.0e38
const FLAP_STEP := 0.667
const COUNTER_LIMIT := 10
const COUNTER_RELOAD := 10.0
const BODY_SCALE := 1.5
const HOME_SPEED := 0.2
const WANDER_SPEED := 0.1
const WANDER_BASE := 0.005
const START_SPEED := 0.08
const START_CLIMB := 0.04
const CLIMB_BAND := 6.0
const CLIMB_RATE := 0.1
const DRIFT_RATE := 0.2

var node: MeshInstance3D
var position := Vector3.ZERO
var home := Vector3.ZERO
var yaw := 0.0
var sight := 0.0
var sight_squared := 0.0
var speed := START_SPEED
var climb := START_CLIMB
var flap := 1.0
var flap_down := true
var heading_counter := 0
var climb_counter := 0
var clock := 0.0
var rng := RandomNumberGenerator.new()


func setup(sight_param: float, start: Vector3, start_yaw: float) -> void:
	sight = sight_param * RANGE_SCALE
	sight_squared = sight * sight
	home = start
	position = start
	yaw = start_yaw
	rng.randomize()


func update(delta: float) -> void:
	clock += delta * TICK_RATE
	while clock >= 1.0:
		clock -= 1.0
		_tick()
	_apply()


func _forward() -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw)) * BODY_SCALE


func _tick() -> void:
	if flap_down:
		flap -= FLAP_STEP
		if flap <= -1.0:
			flap = -1.0
			flap_down = false
	else:
		flap += FLAP_STEP
		if flap >= 1.0:
			flap = 1.0
			flap_down = true
	var gap := home - position
	var squared := FAR
	if gap.x <= sight and gap.z <= sight:
		squared = gap.x * gap.x + gap.z * gap.z
	if squared <= sight_squared:
		var previous := heading_counter
		heading_counter += 1
		if previous > COUNTER_LIMIT:
			heading_counter = int(rng.randf() * COUNTER_RELOAD)
			yaw = PI - rng.randf() * TAU
			speed = rng.randf() * WANDER_SPEED + WANDER_BASE
	else:
		yaw = atan2(gap.x, gap.z)
		heading_counter = int(rng.randf() * COUNTER_RELOAD)
		speed = rng.randf() * WANDER_SPEED + HOME_SPEED
	position.y += climb
	if position.y < home.y:
		climb = rng.randf() * CLIMB_RATE + CLIMB_RATE
		climb_counter = int(rng.randf() * COUNTER_RELOAD)
	elif position.y > home.y + CLIMB_BAND:
		climb = -(rng.randf() * CLIMB_RATE + CLIMB_RATE)
		climb_counter = int(rng.randf() * COUNTER_RELOAD)
	else:
		var before := climb_counter
		climb_counter += 1
		if before > COUNTER_LIMIT:
			climb_counter = int(rng.randf() * COUNTER_RELOAD)
			climb = CLIMB_RATE - rng.randf() * DRIFT_RATE
			if climb < 0.0:
				climb -= CLIMB_RATE
			else:
				climb += CLIMB_RATE
	position += _forward() * speed


func _apply() -> void:
	if node == null:
		return
	node.position = Vector3(position.x, position.y, -position.z)
	node.rotation = Vector3(0.0, -yaw, 0.0)
	node.scale = Vector3(BODY_SCALE, BODY_SCALE * flap, BODY_SCALE)
