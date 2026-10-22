class_name DiveGraph
extends RefCounted

## The dive's route graph (FUN_005212AA / FUN_005211EB): one node per waypoint of table 1 with
## its position, its group tag and its neighbours, the flock routes of the fish and the
## creatures follow it.

## Per node: position (x, y, z), neighbour node numbers, group tag (the waypoint's group short,
## negative for a spur), and the visited mark the route search uses.
var positions := PackedVector3Array()
var neighbours: Array = []
var tags := PackedInt32Array()
var marks := PackedInt32Array()


## FUN_005212AA: build the graph from the waypoint table.
static func from_waypoints(wp) -> DiveGraph:
	var graph := DiveGraph.new()
	for node in wp.node_count:
		var list := PackedInt32Array()
		if wp.group[node] < 0:
			list.append(wp.index[node])
		else:
			for other in wp.node_count:
				if adjacent(wp, node, other):
					list.append(other)
		graph.positions.append(wp.nodes[node])
		graph.neighbours.append(list)
		graph.tags.append(wp.group[node])
		graph.marks.append(0)
	return graph


## FUN_00447EA7(table, a, b): b is the next hop of a's route to b, the waypoint table's own
## test for "joined by an edge".
static func adjacent(wp, a: int, b: int) -> bool:
	if wp.group[b] < 0:
		return a == wp.index[b]
	var group_a: int = wp.group[a]
	if group_a < 0:
		return wp.index[a] == b
	var edge: Dictionary = wp.edges[group_a]
	var w: int = int(edge["w"])
	var column: int = wp.index[b] if group_a == wp.group[b] else wp.group[b] + int(edge["h"])
	var cell: int = wp.index[a] * w + column
	var cells: PackedInt32Array = edge["m"]
	return cell >= 0 and cell < cells.size() and cells[cell] == b


func size() -> int:
	return positions.size()


## FUN_00521837: the first node with this group tag, or -1.
func first_with_tag(tag: int) -> int:
	for node in tags.size():
		if tags[node] == tag:
			return node
	return -1


## FUN_005215D0(tag, start, slot, ..., fraction): walk the ring that starts at `start` and
## leaves it away from neighbour `slot`, back to that neighbour, and pick the node where the
## squared path length reaches `fraction` of its total. Returns {"route", "index", "node"}.
func ring_route(start: int, slot: int, fraction: float) -> Dictionary:
	var stop: int = neighbours[start][slot]
	var route: Array = []
	var current := start
	var previous := stop
	while current != stop:
		route.append(current)
		var list: PackedInt32Array = neighbours[current]
		var following: int = list[1] if list[0] == previous else list[0]
		previous = current
		current = following
	route.append(stop)
	var cumulative: Array = []
	var total := 0.0
	for i in route.size():
		cumulative.append(total)
		var from_node: int = route[i]
		var to_node: int = route[0] if i + 1 == route.size() else route[i + 1]
		total += positions[from_node].distance_squared_to(positions[to_node])
	var wanted := total * fraction
	var found := route.size() - 1
	for i in route.size():
		if wanted <= cumulative[i]:
			found = i
			break
	return {"route": route, "index": found, "node": route[found]}


## FUN_005219BB(tag): every node still tagged -1 (a spur) takes the tag. Returns [node, its first
## neighbour] for each, in node order.
func claim_spurs(tag: int) -> Array:
	var out: Array = []
	for node in tags.size():
		if tags[node] == -1:
			tags[node] = tag
			out.append(node)
			out.append(neighbours[node][0])
	return out


## FUN_005218E9(tag, position): the nearest node with this tag, or -1.
func nearest_with_tag(tag: int, at: Vector3) -> int:
	var best := -1
	var best_distance := 999999.9
	for node in tags.size():
		if tags[node] == tag:
			var d := positions[node].distance_squared_to(at)
			if d < best_distance:
				best = node
				best_distance = d
	return best


## FUN_00521558(.., from, to) with FUN_00521380: the cheapest route by summed squared step lengths
## (below 100000), found by trying every simple path. Returns the node list, empty when there is none.
func shortest_route(from_node: int, to_node: int) -> Array:
	_best_cost = 100000.0
	_best_route = []
	_cost = 0.0
	_stack = []
	_target = to_node
	for i in marks.size():
		marks[i] = 0
	_walk(from_node, 0.0)
	return _best_route


var _best_cost := 0.0
var _best_route: Array = []
var _cost := 0.0
var _stack: Array = []
var _target := 0


func _walk(node: int, step: float) -> bool:
	if marks[node] != 0:
		return false
	marks[node] = 1
	_cost += step
	_stack.append(node)
	if node == _target:
		if _cost < _best_cost:
			_best_route = _stack.duplicate()
			_best_cost = _cost
		_finish(node, step)
		return true
	for next in neighbours[node]:
		var d := positions[node].distance_squared_to(positions[next])
		if _walk(next, d):
			break
	_finish(node, step)
	return false


func _finish(node: int, step: float) -> void:
	_cost -= step
	_stack.pop_back()
	marks[node] = 0
