class_name DiveDolphin
extends Behaviour

## FUN_0052576E (ctor) / FUN_00524A20 (update, vtable 0x008C5E40, returns 2). The dolphin of the dive
## cruises the route graph, picking its next node at random as it reaches each one. When a brick is
## delivered it swims (FUN_005255A8) to one of three jump spots, leaps out of the water and
## comes down again at another.
##
## State: 0 cruising, 1 swimming to the spot, 2 / 3 last stretch of the two kinds of leap, 4 in the
## air, 5 back in the water heading for its landing node.
##
## Node: +0x18 position, +0x24 previous node, +0x28 target, +0x34 current node, +0xB0 route
## length, +0xB4 steering block, +0xE8 state, +0xEC the kind of leap, +0xF4 speed, +0xF8 wanted speed,
## +0xFC acceleration, +0x100.. the three jump spots (node, node beside it), +0x118 which one.

const NEAR_SQUARED := 9.0
const ROUTE_NEAR_SQUARED := 25.0
const SNAP := 0.087266

var steering := DiveSteering.new()
var position := Vector3.ZERO
var previous := -1
var target := Vector3.ZERO
var current := 0
var route: Array = []
var route_index := 0
var state := 0
var leap_kind := 0
var speed := 4.0
var wanted_speed := 4.0
var acceleration := 0.0
var spots: Array = []
var spot := 0
var jumping := false

var services: ActorServices
var graph: DiveGraph


static func from_descriptor(desc: Descriptor, services_in: ActorServices, graph_in: DiveGraph, actor) -> DiveDolphin:
	var b := DiveDolphin.new()
	b.services = services_in
	b.graph = graph_in
	var claimed := graph_in.claim_spurs(1)
	if claimed.size() == 6:
		b.spots = [[claimed[0], claimed[1]], [claimed[2], claimed[3]], [claimed[4], claimed[5]]]
	b.current = b.spots[0][1] if not b.spots.is_empty() else 0
	b.previous = -1
	b.position = graph_in.positions[b.current]
	actor.x = b.position.x
	actor.y = b.position.y
	actor.z = b.position.z
	b.steering.load_block(desc, 0)
	services_in.set_clip(actor, 3, 0.0)
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


## FUN_0052547B: the next stretch of the cruise.
func _wander() -> Vector3:
	if position.distance_squared_to(graph.positions[current]) < NEAR_SQUARED:
		var options: Array = []
		for node in graph.neighbours[current]:
			if node != previous and node != spots[0][0] and node != spots[1][0] and node != spots[2][0]:
				options.append(node)
		previous = current
		current = options[DiveWorld.pulse_level(options.size())]
	return graph.positions[current]


## FUN_005255A8: swim along the cheapest route to the node nearest the jump spot. Returns true on
## arrival; `out` receives the point to steer to.
func _swim(out: Array) -> bool:
	var goal := graph.nearest_with_tag(1, target)
	if goal != current or previous == -1:
		var start := graph.nearest_with_tag(1, position)
		current = goal
		route = graph.shortest_route(start, goal)
		route_index = 0
		previous = 0
	var node: int = route[route_index]
	if position.distance_squared_to(graph.positions[node]) < ROUTE_NEAR_SQUARED:
		if node == route[route.size() - 1]:
			return true
		route_index += 1
	out[0] = graph.positions[route[route_index]]
	return false


func update(actor, _block: BehaviourBlock, _var_value: int) -> int:
	var dt := DiveWorld.dt
	var steer := true
	var falling := false
	var spawn := DiveWorld.dolphin_hint
	DiveWorld.dolphin_hint = 0
	if spawn != 0 and state == 0:
		state = 1
		leap_kind = spawn
		wanted_speed = 12.0
		acceleration = 12.0
		spot = DiveWorld.pulse_level(3)
		previous = -1
		target = graph.positions[spots[spot][1]]
	position = Vector3(actor.x, actor.y, actor.z)
	var aim := Vector3.ZERO
	match state:
		0:
			aim = _wander()
		1:
			var box := [Vector3.ZERO]
			var arrived := _swim(box)
			aim = box[0]
			if arrived:
				if leap_kind == 1:
					state = 2
				elif leap_kind == 2:
					state = 3
		2:
			aim = graph.positions[spots[spot][0]]
			if 78.5 < position.y:
				state = 4
				DiveWorld.dolphin_jumping = true
				services.set_clip(actor, 2, 0.0)
				wanted_speed = 24.0
				acceleration = 40.0
				steer = false
		3:
			aim = graph.positions[spots[spot][0]]
			if 78.5 < position.y:
				state = 4
				DiveWorld.dolphin_jumping = true
				services.set_clip(actor, 5, 0.0)
				wanted_speed = 40.0
				acceleration = 32.0
				steer = false
		4:
			steer = false
			if position.y <= 86.5:
				if speed < 0.0:
					speed = -speed
					wanted_speed = 4.0
					acceleration = 16.0
					state = 5
			else:
				falling = true
		5:
			aim = graph.positions[spots[spot][1]]
			if position.distance_squared_to(aim) < NEAR_SQUARED:
				current = spots[spot][1]
				previous = -1
				state = 0
	if DiveWorld.dolphin_jumping:
		var length := services.anim_length(actor)
		var frame := services.anim_frame(actor)
		if length - 1.0 < frame:
			DiveWorld.dolphin_jumping = false
			services.set_clip(actor, 3, 0.0)
			steering.values[4] += DiveWorld.PI_F
	var yaw: float
	var pitch: float
	if not steer:
		yaw = steering.values[3]
		pitch = steering.values[4]
	else:
		var toward := (aim - position).normalized()
		var yaw_target := DiveWorld.wrap_angle(atan2(toward.x, toward.z))
		var pitch_target := DiveWorld.wrap_angle(-asin(toward.y))
		var scale := speed / 12.0
		var yaw_gap := DiveWorld.angle_gap(yaw_target, steering.values[3])
		var yaw_ratio: float = yaw_gap[1] * scale
		var yaw_push := 0.0
		if yaw_gap[0] == 1:
			yaw_push = steering.values[9] * yaw_ratio + 0.0
		if yaw_gap[0] == -1:
			yaw_push = yaw_push - steering.values[9] * yaw_ratio
		var pitch_gap := DiveWorld.angle_gap(pitch_target, steering.values[4])
		var pitch_ratio: float = pitch_gap[1] * scale
		var pitch_push := 0.0
		if pitch_gap[0] == 1:
			pitch_push = steering.values[9] * pitch_ratio + 0.0
		if pitch_gap[0] == -1:
			pitch_push = pitch_push - steering.values[9] * pitch_ratio
		steering.values[0] = yaw_push * dt
		steering.values[1] = pitch_push * dt
		var yaw_step: float = dt * steering.values[0]
		var pitch_step: float = steering.values[1] * dt
		if yaw_gap[2] < SNAP or yaw_gap[2] < absf(yaw_step):
			steering.values[0] = 0.0
			yaw = yaw_target
		else:
			yaw = yaw_step + steering.values[3]
		if pitch_gap[2] < SNAP or pitch_gap[2] < absf(pitch_step):
			steering.values[1] = 0.0
			pitch = pitch_target
		else:
			pitch = pitch_step + steering.values[4]
		yaw = DiveWorld.wrap_angle(yaw)
		pitch = DiveWorld.wrap_angle(pitch)
	var rows := ActorServices.rotation_rows(pitch + DiveSteering.QUARTER_TURN, yaw, 0.0)
	var heading := Vector3(rows[4], rows[5], rows[6])
	if not falling:
		if speed != wanted_speed:
			if wanted_speed <= speed:
				speed -= acceleration * dt
				if speed < wanted_speed:
					speed = wanted_speed
			else:
				speed = acceleration * dt + speed
				if wanted_speed < speed:
					speed = wanted_speed
		steering.values[6] = speed * heading.x
		steering.values[7] = speed * heading.y
		steering.values[8] = speed * heading.z
	else:
		speed = dt * -24.0 + speed
		steering.values[6] = 0.0
		steering.values[7] = speed
		steering.values[8] = 0.0
	actor.x = steering.values[6] * dt + position.x
	actor.y = steering.values[7] * dt + position.y
	actor.z = steering.values[8] * dt + position.z
	services.clip_finished(actor, 1.0)
	actor.set_field_f(0x4C, pitch)
	actor.yaw = yaw
	actor.set_field_f(0x54, 0.0)
	steering.values[3] = yaw
	steering.values[4] = pitch
	return 2
