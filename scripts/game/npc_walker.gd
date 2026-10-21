extends RefCounted

## One island person walking their patrol (Human1.c, FUN_00459290 / FUN_0045889f).
## CONFIRMED from the act builder FUN_004c7230: each person has several walk
## behaviours, each gated by (var[tag] & mask) == value, and a node list on the
## pedestrian graph (W_PATH). The person walks to node 0, then 1, ... and back
## to 0, taking the graph's own next-hop route between nodes. Pace: the talk
## node sets the walker speed to 0.016667 walker units per tick (FUN_00446ec6 with
## 0x3c888888) and one walker unit is 8 world units, times the entry's speed
## factor, at 30 ticks a second.

const TICK := 30.0
const WORLD_PER_WALKER := 8.0
const BASE_SPEED := 0.016667
const ARRIVE := 1.2
const TURN_STEP := 0.15
const NO_CLIP := 0xffff
## FUN_0045889f asks FUN_0087ba30(record, .., 2.4, 1.39): Pepper within 2.4 walker
## units and inside 1.39 rad of the way the person faces stops them for 30 ticks.
const NOTICE_RANGE := 2.4 * WORLD_PER_WALKER
const NOTICE_ANGLE := 1.39
const NOTICE_HOLD := 30.0 / TICK

var node: MeshInstance3D
var item: Dictionary
var record := 0
var tag := 0
var behaviours: Array = []
var graph
var cur_node := -1
var goal_index := 0
var route: Array = []
var route_at := 0
var yaw := 0.0
var active := -1
var moving := false
var hold := 0.0
var others: Array = []


func _pick(game) -> int:
	var single := -1
	for i in behaviours.size():
		var b: Dictionary = behaviours[i]
		if (game.get_var(tag) & int(b.mask)) != int(b.value):
			continue
		if (b.nodes as Array).size() >= 2:
			return i
		if single < 0:
			single = i
	return single


## Advances the walk by `delta` seconds. `island` supplies the ground height.
func step(delta: float, game, island) -> void:
	var pick := _pick(game)
	if pick != active:
		active = pick
		route.clear()
		goal_index = 0
	moving = false
	if active < 0:
		return
	if hold > 0.0:
		hold -= delta
		_face_pepper(delta, island)
		return
	if _blocked_by_other():
		return
	if _notices_pepper(island):
		hold = NOTICE_HOLD
		_face_pepper(delta, island)
		return
	var b: Dictionary = behaviours[active]
	var nodes: Array = b.nodes
	var scene_pos: Vector3 = node.position
	var game_pos := Vector3(scene_pos.x, scene_pos.y, -scene_pos.z)
	if cur_node < 0:
		cur_node = _nearest(game_pos)
	var budget := BASE_SPEED * WORLD_PER_WALKER * float(b.speed) * delta * TICK
	var guard := 0
	while budget > 0.0 and guard < 8:
		guard += 1
		if route.is_empty() or route_at >= route.size():
			var goal: int = nodes[goal_index % nodes.size()]
			if cur_node == goal:
				goal_index += 1
				if nodes.size() < 2:
					return
				continue
			route = graph.route(cur_node, goal)
			route_at = 1
			if route.size() < 2:
				route.clear()
				goal_index += 1
				return
		var target: Vector3 = graph.nodes[route[route_at]]
		var to := Vector3(target.x - game_pos.x, 0.0, target.z - game_pos.z)
		var dist := to.length()
		if dist <= ARRIVE:
			cur_node = route[route_at]
			route_at += 1
			if route_at >= route.size():
				route.clear()
				goal_index += 1
			continue
		var move := minf(budget, dist)
		var dir := to / dist
		game_pos += dir * move
		budget -= move
		moving = true
		var want := atan2(dir.x, dir.z)
		yaw = _turn(yaw, want, TURN_STEP * delta * TICK)
	scene_pos = Vector3(game_pos.x, scene_pos.y, -game_pos.z)
	var ground: float = island._ground(Vector3(scene_pos.x, scene_pos.y + 4.0, scene_pos.z), island.STEP_UP, true)
	if ground > -INF:
		scene_pos.y = ground
	node.position = scene_pos
	node.basis = island._placement_basis(0.0, yaw, 0.0)


func _notices_pepper(island) -> bool:
	if island.player == null:
		return false
	var me: Vector3 = node.position
	var pepper: Vector3 = island.player_pos
	var gap := Vector2(pepper.x - me.x, -(pepper.z - me.z))
	if gap.length() >= NOTICE_RANGE:
		return false
	var bearing := atan2(gap.x, gap.y)
	return absf(wrapf(bearing - yaw, -PI, PI)) < NOTICE_ANGLE


## FUN_004490bf: a walker stops while another one is just ahead of it on its path,
## closer than its own look-ahead gap (squared threshold at handle +0x78, 3.75 walker
## units for the pedestrian table = 30 world units squared-compared as (d/8)^2).
const GAP := 3.75 * 0.125 * WORLD_PER_WALKER * 0.5


func _blocked_by_other() -> bool:
	var me: Vector3 = node.position
	var ahead := Vector3(sin(yaw), 0.0, -cos(yaw))
	for other in others:
		if other == self:
			continue
		var gap: Vector3 = (other.node as Node3D).position - me
		gap.y = 0.0
		var d := gap.length()
		if d < 0.001 or d > GAP * 2.0:
			continue
		if ahead.dot(gap / d) > 0.7 and other.moving == false or ahead.dot(gap / d) > 0.9:
			if d < GAP * 2.0 and _closer_to_goal(other):
				return true
	return false


func _closer_to_goal(other) -> bool:
	if route.is_empty() or route_at >= route.size():
		return false
	var target: Vector3 = graph.nodes[route[route_at]]
	var mine := Vector2(target.x - node.position.x, target.z + node.position.z).length()
	var theirs := Vector2(target.x - other.node.position.x, target.z + other.node.position.z).length()
	return theirs < mine


func _face_pepper(delta: float, island) -> void:
	var me: Vector3 = node.position
	var pepper: Vector3 = island.player_pos
	var bearing := atan2(pepper.x - me.x, -(pepper.z - me.z))
	yaw = _turn(yaw, bearing, TURN_STEP * delta * TICK)
	node.basis = island._placement_basis(0.0, yaw, 0.0)


func walk_clip() -> int:
	if active < 0:
		return NO_CLIP
	return int(behaviours[active].clip)


func _nearest(game_pos: Vector3) -> int:
	var best := 0
	var best_d := INF
	for i in graph.nodes.size():
		var q: Vector3 = graph.nodes[i]
		var d := Vector2(q.x - game_pos.x, q.z - game_pos.z).length_squared()
		if d < best_d:
			best_d = d
			best = i
	return best


static func _turn(from: float, to: float, step: float) -> float:
	var diff := wrapf(to - from, -PI, PI)
	if absf(diff) <= step:
		return to
	return wrapf(from + signf(diff) * step, -PI, PI)
