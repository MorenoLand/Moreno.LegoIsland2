class_name WalkerEngine
extends RefCounted

## The walker engine (FUN_00445FAB .. FUN_00449EB6): 60 slots that move actors along the
## waypoint graphs (0 = W_ROAD, 1 = W_PATH, 2 = W_CSM, 3 = W_OTH). Handles are the slot
## number plus one, as in the exe. Positions are handled in "grid" units (game units *
## 0.125) inside the step, exactly like the original.
##
## Slot flags (u32): 0x1 placed in lists, 0x2 idle, 0x4 started, 0x8 / 0x10 route set,
## 0x1000..0x3000 speed phase, 0x100000 / 0x200000 route options, 0x400000 blocked,
## 0x1000000 waiting; top nibble = mode: 0x80000000 route, 0x10000000 goal (alt),
## 0x20000000 follow, 0x40000000 turn, 0x60000000 goal position.

const SLOT_COUNT := 60
const PI_F := 3.1415927410125732
const TAU_F := 6.2831854820251465
const EIGHTH := 0.125
const MODE_MASK := 0xF0000000
const KEEP_LOW := 0x0FFFFFFF

var slots: Array = []
## Waypoints (scripts/core/waypoints.gd) per graph, null when not loaded.
var graphs: Array = [null, null, null, null]
## lists[graph][k][node] = Array of WalkerSlot, head first (k 0 = after node, 1 = to node,
## 2 = linked road node).
var lists: Array = []
var services
var last_y := 0.0


func _init() -> void:
	for i in SLOT_COUNT:
		slots.append(WalkerSlot.new())
	for g in 4:
		lists.append([{}, {}, {}])


## FUN_00446090
func reset() -> void:
	for slot in slots:
		slot.flags = 0
	for g in 4:
		lists[g] = [{}, {}, {}]


func slot(handle: int) -> WalkerSlot:
	return slots[handle - 1]


func _handle_of(s: WalkerSlot) -> int:
	return slots.find(s) + 1


func node_count(graph: int) -> int:
	var w = graphs[graph]
	return 0 if w == null else w.node_count


func node_position(graph: int, node: int) -> Vector3:
	return graphs[graph].nodes[node]


static func wrap_angle(a: float) -> float:
	if -PI_F <= a:
		if PI_F < a:
			a -= TAU_F
	else:
		a += TAU_F
	return a


static func _dist2(x: float, z: float) -> float:
	return x * x + z * z


func _kind(graph: int, node: int) -> int:
	return graphs[graph].kind[node]


func _link(graph: int, node: int) -> int:
	return graphs[graph].link[node]


func _priority(graph: int, node: int) -> int:
	return graphs[graph].priority[node]


## FUN_00448049
func next_node(graph: int, from_id: int, to_id: int) -> int:
	return graphs[graph].next_node(from_id, to_id)


# --- per-node slot lists (FUN_00448250 remove, FUN_00448311 insert) ---

func _list_remove(s: WalkerSlot, graph: int, node: int, k: int) -> void:
	if node > -1 and node <= node_count(graph):
		var list: Array = lists[graph][k].get(node, [])
		list.erase(s)


func _list_insert(s: WalkerSlot, graph: int, node: int, k: int) -> void:
	if node > -1 and node <= node_count(graph):
		if not lists[graph][k].has(node):
			lists[graph][k][node] = []
		var list: Array = lists[graph][k][node]
		if not list.has(s):
			list.push_front(s)


func _list_of(graph: int, k: int, node: int) -> Array:
	return (lists[graph][k].get(node, []) as Array).duplicate()


## FUN_004483c8
func unlink(s: WalkerSlot) -> void:
	if s.s16(0x1A) > -1:
		_list_remove(s, s.graph, s.s16(0x1A), 1)
	if s.s16(0x1C) > -1:
		_list_remove(s, s.graph, s.s16(0x1C), 0)
	if s.s16(0x1E) > -1 and s.graph == 1 and _kind(s.graph, s.s16(0x1E)) == 4 and _link(s.graph, s.s16(0x1E)) > -1:
		_list_remove(s, 0, s.s16(0x1A), 2)


## FUN_0044849d
func link(s: WalkerSlot) -> void:
	unlink(s)
	if s.s16(0x1A) > -1:
		_list_insert(s, s.graph, s.s16(0x1A), 1)
	if s.s16(0x1C) > -1:
		_list_insert(s, s.graph, s.s16(0x1C), 0)
	if s.s16(0x1E) > -1 and s.graph == 1 and _kind(s.graph, s.s16(0x1E)) == 4 and _link(s.graph, s.s16(0x1E)) > -1:
		_list_insert(s, 0, s.s16(0x1A), 2)


## FUN_0044857e: set the node the walker came from.
func set_from(s: WalkerSlot, node: int) -> void:
	if node < 0:
		node = 0
	if s.graph == 1 and _kind(s.graph, s.s16(0x1E)) == 4:
		var linked := _link(s.graph, s.s16(0x1E))
		if linked > -1:
			_list_remove(s, 0, linked, 2)
	s.set_s16(0x1E, node)


## FUN_0044860c: set the node the walker is heading to.
func set_to(s: WalkerSlot, node: int) -> void:
	_list_remove(s, s.graph, node, 1)
	_list_remove(s, s.graph, s.s16(0x1A), 1)
	s.set_s16(0x1A, node)
	if node > -1:
		_list_insert(s, s.graph, s.s16(0x1A), 1)
		if s.graph == 1 and _kind(s.graph, s.s16(0x1A)) == 4:
			var linked := _link(s.graph, s.s16(0x1A))
			if linked > -1:
				_list_insert(s, 0, linked, 2)
		var to_pos := node_position(s.graph, s.s16(0x1A))
		var from_pos := node_position(s.graph, s.s16(0x1E))
		var dx := (to_pos.x - from_pos.x) * EIGHTH
		var dz := (to_pos.z - from_pos.z) * EIGHTH
		s.set_f(0x5C, atan2(dx, dz))
		s.set_f(0x68, _dist2(dx, dz))


## FUN_004487B0: set the node after the next one (for the corner ahead).
func set_after(s: WalkerSlot, node: int) -> void:
	if s.s16(0x1C) > -1:
		_list_remove(s, s.graph, s.s16(0x1C), 0)
	s.set_s16(0x1C, node)
	if node < 0:
		s.set_f(0x58, s.f(0x5C))
	else:
		_list_remove(s, s.graph, node, 0)
		var after_pos := node_position(s.graph, s.s16(0x1C))
		var to_pos := node_position(s.graph, s.s16(0x1A))
		var dx := (after_pos.x - to_pos.x) * EIGHTH
		var dz := (after_pos.z - to_pos.z) * EIGHTH
		s.set_f(0x58, atan2(dx, dz))
		s.set_f(0x68, _dist2(dx, dz))
		_list_insert(s, s.graph, s.s16(0x1C), 0)


## FUN_004460CF: put an actor on a node.
func place_at_node(handle: int, node: int, actor) -> void:
	var s := slot(handle)
	s.flags = s.flags & 0xFFFFFFFB
	s.set_s16(0x1E, node)
	if actor != null:
		var p := node_position(s.graph, node)
		actor.x = p.x
		actor.y = p.y
		actor.z = p.z


## FUN_00446195: take a free slot for an actor on a graph; returns the handle or 0.
func create(graph: int, actor, start_node: int) -> int:
	if node_count(graph) < 1:
		return 0
	var index := 0
	while index < SLOT_COUNT and slots[index].flags != 0:
		index += 1
	if index == SLOT_COUNT:
		return 0
	var s: WalkerSlot = slots[index]
	s.clear()
	s.graph = graph
	s.set_f(0x40, 0.0872664600610733)
	s.set_f(0x50, 200.0)
	s.set_f(0x4C, 20.0)
	s.set_f(0x74, 20.0)
	s.set_f(0x48, 0.0)
	s.set_f(0x80, 1.0)
	s.actor = actor
	var code: String = "" if actor == null else actor.code
	for i in 4:
		s.set_u8(0x0C + i, code.unicode_at(i) if i < code.length() else 0)
	s.set_s16(0x1A, start_node)
	s.set_f(0x78, 3.75 if graph == 0 else 0.36)
	s.flags = 0xB
	s.set_f(0x6C, 1.0)
	var handle := index + 1
	if start_node < 0 and start_node == -1 and actor != null:
		var best := 1.0e38
		start_node = -1
		for i in node_count(graph):
			var p := node_position(graph, i)
			var d := Vector3(actor.x, actor.y, actor.z) - p
			var d2 := d.z * d.z + d.y * d.y + d.x * d.x
			if d2 < best:
				start_node = i
				best = d2
	if start_node < 0:
		if start_node == -3:
			s.set_s16(0x1E, 0)
			s.set_s16(0x1A, 0)
		else:
			s.set_s16(0x1E, -1)
			s.set_s16(0x1A, -1)
	else:
		place_at_node(handle, start_node, actor)
		for i in node_count(graph):
			if i != start_node and next_node(graph, start_node, i) == i:
				set_to(s, i)
				s.set_s16(0x1C, -1)
				break
	return handle


## FUN_00447A0F: the actor's walker, made on first use.
func get_or_create(graph: int, actor, start_node: int) -> int:
	if actor == null or actor.block.walker == 0:
		return create(graph, actor, start_node)
	return actor.block.walker


## FUN_004466FB: free a slot.
func release(handle: int) -> void:
	var index := handle - 1
	if index > -1 and slots[index].flags != 0:
		if node_count(slots[index].graph) > 0:
			unlink(slots[index])
		slots[index].flags = 0


# --- small accessors ---

func state(handle: int) -> int:
	var f := slot(handle).flags
	if (f & 2) != 0:
		return 0
	if (f & 4) == 0:
		return 0
	if (f & MODE_MASK) == 0x10000000:
		return 3
	if (f & 0x60000000) == 0:
		return 2
	return 4


func goal_node(handle: int) -> int:
	return slot(handle).s16(0x1A)


func route_target(handle: int) -> int:
	return slot(handle).s16(0x18)


func from_node(handle: int) -> int:
	return slot(handle).s16(0x1E)


func is_idle(handle: int) -> bool:
	return (slot(handle).flags & 2) == 0


func finish(handle: int) -> void:
	var s := slot(handle)
	s.flags = s.flags | 0x1000000
	s.flags = s.flags | 2


func hold(handle: int) -> void:
	var s := slot(handle)
	s.flags = s.flags | 0x1000000
	s.flags = s.flags & 0xFFFFFFFD


func waiting(handle: int) -> bool:
	return (slot(handle).flags & 0x1000000) != 0


func blocked(handle: int) -> bool:
	return (slot(handle).flags & 0x400000) != 0


func ahead_actor(handle: int):
	var s := slot(handle)
	return null if s.ahead == null else s.ahead.actor


func set_option_flags(handle: int, a: int, b: int) -> void:
	var s := slot(handle)
	if a == 1:
		s.flags = s.flags | 0x200000
	elif a == 0:
		s.flags = s.flags & 0xFFDFFFFF
	if b == 1:
		s.flags = s.flags | 0x100000
	elif b == 0:
		s.flags = s.flags & 0xFFEFFFFF


func set_graph(handle: int, graph: int) -> void:
	slot(handle).graph = graph


func graph_of(handle: int) -> int:
	return slot(handle).graph


func set_lane(handle: int, value: float) -> void:
	slot(handle).set_f(0x20, value)


func lane(handle: int) -> float:
	return slot(handle).f(0x20)


func flip_lane(handle: int) -> void:
	var s := slot(handle)
	s.set_f(0x20, -s.f(0x20))


## FUN_004467EA: flip the lane of every walker on a graph.
func flip_lanes(graph: int) -> void:
	for s in slots:
		if s.flags != 0 and s.graph == graph:
			s.set_f(0x20, -s.f(0x20))


func set_flags_raw(handle: int, value: int) -> void:
	slot(handle).flags = value


func set_speed_scale(handle: int, value: float) -> void:
	var index := handle - 1
	if index > -1 and slots[index].flags != 0:
		slots[index].set_f(0x80, value)


## FUN_00446EC6
func set_speed(handle: int, value: float) -> void:
	var s := slot(handle)
	if s.f(0x44) != value:
		if 0.009999999776482582 < absf(s.f(0x44)) and (s.flags & 0x1000) != 0:
			var scaled := (s.f(0x48) * value) / s.f(0x44)
			var previous := s.f(0x48)
			s.set_f(0x48, scaled)
			s.set_f(0x54, (s.f(0x54) * scaled) / previous)
	s.set_f(0x44, value)


func speed(handle: int) -> float:
	return slot(handle).f(0x44)


## FUN_00446FE4
func set_turn_limit(handle: int, value: float) -> void:
	slot(handle).set_f(0x40, absf(value))


func set_accel(handle: int, value: float) -> void:
	slot(handle).set_f(0x4C, value)


func set_brake(handle: int, value: float) -> void:
	slot(handle).set_f(0x50, value)


func set_follow_gap(handle: int, value: float) -> void:
	slot(handle).set_f(0x78, value * value)


func set_slack(handle: int, value: float) -> void:
	slot(handle).set_f(0x74, value)


## FUN_00446C80
func set_flags_nine(handle: int) -> void:
	slot(handle).flags = 9


## FUN_0044714A: copy walker `from_handle` over `to_handle`, keeping the actor.
func clone(from_handle: int, to_handle: int, extra: float) -> void:
	var dst := slot(to_handle)
	var keep = dst.actor
	dst.copy_from(slot(from_handle))
	dst.actor = keep
	var code: String = "" if keep == null else keep.code
	for i in 4:
		dst.set_u8(0x0C + i, code.unicode_at(i) if i < code.length() else 0)
	if 0.05000000074505806 < absf(extra):
		var root := sqrt(dst.f(0x7C))
		dst.set_f(0x7C, (root + extra) * (root + extra))


## FUN_00447297
func place(handle: int, node: int) -> void:
	var s := slot(handle)
	s.flags = s.flags | 1
	s.set_s16(0x1E, node)
	s.set_s16(0x1A, node)
	s.set_s16(0x1C, node)
	link(s)


func relink(handle: int) -> void:
	var s := slot(handle)
	s.flags = s.flags | 1
	link(s)


func unlink_handle(handle: int) -> void:
	unlink(slot(handle))


## FUN_004468E4: head for a node through the route.
func set_route(handle: int, node: int, again: int) -> void:
	var s := slot(handle)
	var keep := again
	if node < 0:
		node = 0
	elif node_count(s.graph) < node:
		node = node_count(s.graph) - 1
	if (s.flags & 2) != 0:
		s.flags = s.flags & 0xFFFFFFFD
		keep = 0
	if (s.flags & MODE_MASK) == 0x20000000:
		s.flags = s.flags & KEEP_LOW
		keep = 0
	if (s.flags & MODE_MASK) == 0x10000000:
		s.flags = s.flags & KEEP_LOW
		keep = 0
	if s.s16(0x18) == node:
		if again == 1:
			keep = 1
	else:
		s.set_s16(0x18, node)
	s.flags = s.flags & KEEP_LOW
	if keep == 0:
		s.flags = s.flags | 0x80000008
	else:
		s.flags = s.flags | 0x80000010


## FUN_004473E9: follow an actor.
func follow_actor(handle: int, actor) -> void:
	var s := slot(handle)
	s.follow = actor
	if actor != null:
		if (s.flags & 2) != 0:
			s.flags = s.flags & 0xFFFFFFFD
		s.flags = s.flags & KEEP_LOW
		s.flags = s.flags | 0x20000000


## FUN_004474A2: walk to a position (null stops).
func goal_to(handle: int, position) -> void:
	var s := slot(handle)
	if position == null:
		s.set_u32(0x3C, 0)
		s.flags = s.flags & KEEP_LOW
		s.flags = s.flags | 2
	else:
		s.set_f(0x30, position.x)
		s.set_f(0x34, position.y)
		s.set_f(0x38, position.z)
		s.set_u32(0x3C, 1)
		if (s.flags & 2) != 0:
			s.flags = s.flags & 0xFFFFFFFD
		s.flags = s.flags & KEEP_LOW
		s.flags = s.flags | 0x60000000


## FUN_004475D8: walk to a node of the walker's graph.
func goal_to_node(handle: int, node: int) -> void:
	goal_to(handle, node_position(slot(handle).graph, node))


## FUN_00447612: turn on the spot to a heading.
func turn_to(handle: int, heading: float) -> void:
	var s := slot(handle)
	s.set_f(0x60, heading)
	if (s.flags & 2) != 0:
		s.flags = s.flags & 0xFFFFFFFD
	s.flags = s.flags & KEEP_LOW
	s.flags = s.flags | 0x40000000


## FUN_004476D1: walk to a position, the alternate way (stops at one unit).
func goal_to_alt(handle: int, position) -> void:
	var s := slot(handle)
	if position == null:
		s.flags = s.flags & KEEP_LOW
		s.flags = s.flags | 2
	else:
		s.set_f(0x30, position.x)
		s.set_f(0x34, position.y)
		s.set_f(0x38, position.z)
		s.flags = s.flags & KEEP_LOW
		s.flags = s.flags & 0xFEFFFFFF
		s.flags = s.flags & 0xFFFF8FFF
		s.flags = s.flags & 0xFFFFFFFD
		s.flags = s.flags | 0x10000000


func gap_to_goal(handle: int) -> float:
	return slot(handle).f(0x7C)


# --- graph helpers (FUN_00447908 .. FUN_00447EA7) ---

## FUN_00447EA7: is node `b` directly reachable from node `a`.
func connected(graph: int, a: int, b: int) -> bool:
	var w = graphs[graph]
	if w.group[b] < 0:
		return a == w.index[b]
	var ga: int = w.group[a]
	if ga < 0:
		return w.index[a] == b
	var edge: Dictionary = w.edges[ga]
	var column: int = w.index[b] if ga == w.group[b] else w.group[b] + int(edge["h"])
	var m: PackedInt32Array = edge["m"]
	var cell: int = w.index[a] * int(edge["w"]) + column
	return cell >= 0 and cell < m.size() and m[cell] == b


## FUN_00447DD4
func same_route(graph: int, a: int, b: int) -> bool:
	var w = graphs[graph]
	if w.group[b] < 0:
		return a == w.index[b]
	var ga: int = w.group[a]
	if ga < 0:
		return w.index[a] == b
	return ga == w.group[b]


## FUN_00447908: the nodes next to `node`. Returns {"count", "group", "nodes"}.
func neighbours(graph: int, node: int) -> Dictionary:
	var w = graphs[graph]
	var out: Array = []
	var count := 0
	if w.group[node] < 0:
		out.append(w.index[node])
		count = 1
	else:
		for i in w.node_count:
			if connected(graph, node, i):
				out.append(i)
		count = out.size()
	return {"count": count, "group": w.group[node], "nodes": out}


## FUN_00447D80 / FUN_00447DAC
func valid_node(graph: int, node: int) -> bool:
	return node >= 0 and node <= node_count(graph)


func is_special_node(graph: int, node: int) -> bool:
	return graphs[graph].group[node] < 0


# --- motion ---

## FUN_00448E18: turn toward the target heading by one step; false once it is reached.
func _turn_step(s: WalkerSlot, m: Array) -> bool:
	var step := s.f(0x54) * s.f(0x80) * 1.0
	if m[5] <= step:
		if -step <= m[5]:
			m[0] = s.f(0x60)
			return false
		m[0] = step + m[0]
	else:
		m[0] = m[0] - step
	m[0] = wrap_angle(m[0])
	return true


## FUN_004488FE
func _compute_speed(s: WalkerSlot) -> void:
	s.set_f(0x70, 0.0)
	s.set_f(0x6C, 1.0)
	if 0.009999999776482582 <= absf(s.f(0x20)):
		var speed_now := s.f(0x44)
		s.set_f(0x54, speed_now / absf(s.f(0x20)))
		var eighth := s.f(0x54) * 0.125
		var quarter_cos := cos(s.f(0x54) * 0.25)
		s.set_f(0x48, cos(eighth) * (quarter_cos * speed_now))
		s.set_f(0x54, s.f(0x48) / absf(s.f(0x20)))
	else:
		s.set_f(0x54, s.f(0x40))
		s.set_f(0x48, 0.0)


## FUN_00448A17: can the walker take the corner; 0 no, 1 yes, 2 yes and stop.
func _corner(s: WalkerSlot, phase: int) -> int:
	var lane_wide := false
	var angle := s.f(0x58) - s.f(0x5C)
	angle = wrap_angle(angle)
	if absf(angle) < 0.1745319962501526:
		s.set_f(0x70, 0.0)
		s.set_f(0x54, s.f(0x44) / s.f(0x4C))
		return 2
	if absf(angle) > 2.967043876647949:
		return 0
	angle = angle * 0.5
	var sine := sin(angle)
	var cosine := cos(angle)
	var tangent := sine / cosine
	if phase == 0:
		if absf(s.f(0x20)) >= 0.0010000000474974513:
			s.set_f(0x70, -s.f(0x20) * tangent)
		else:
			s.set_f(0x70, 0.0)
	var limit := 0.0
	if phase == 0:
		limit = s.f(0x4C)
	elif phase == 0x2000:
		if s.graph == 0:
			if _kind(s.graph, s.s16(0x1A)) == 1:
				lane_wide = true
				if 0.0 <= s.f(0x20) or 0.0 <= angle:
					if s.f(0x20) <= 0.0 or angle <= 0.0:
						limit = s.f(0x50) + s.f(0x50)
					else:
						limit = s.f(0x50)
				else:
					limit = s.f(0x50)
			else:
				limit = s.f(0x50)
		else:
			limit = s.f(0x50)
	elif phase == 0x3000:
		limit = (s.f(0x50) - s.f(0x4C)) * 0.5 + s.f(0x4C)
	if (limit / cosine - limit <= s.f(0x74)) or lane_wide:
		var shift := absf(tangent) * limit
		if absf(tangent) * limit * shift <= s.f(0x7C):
			if (shift + shift) * (shift + shift) <= s.f(0x68):
				s.set_f(0x6C, 1.0 + shift)
				s.set_f(0x54, s.f(0x44) / limit)
				var quarter := s.f(0x54) * 0.25
				var eighth := s.f(0x54) * 0.125
				var base := absf(s.f(0x44))
				s.set_f(0x48, cos(eighth) * (cos(quarter) * base))
				s.set_f(0x54, s.f(0x48) / limit)
				if s.graph == 0:
					if _kind(s.graph, s.s16(0x1A)) == 2:
						return 2
					if lane_wide:
						return 2
				return 1
			return 0
		return 0
	return 0


## FUN_004490BF: the walker ahead on the same stretch; true when it holds this one back.
func _ahead_search(s: WalkerSlot) -> bool:
	var best := -1.0e38
	s.ahead = null
	for other in _list_of(s.graph, 1, s.s16(0x1A)):
		if other != s and (other.actor.flags & 2) != 0 and other.s16(0x1E) == s.s16(0x1E) and other.f(0x7C) < s.f(0x7C) and best < other.f(0x7C):
			best = other.f(0x7C)
			s.ahead = other
	if s.ahead == null and s.s16(0x1C) > -1:
		best = -1.0e38
		for other in _list_of(s.graph, 1, s.s16(0x1C)):
			if other != s and (other.actor.flags & 2) != 0 and other.s16(0x1E) == s.s16(0x1A):
				var dx: float = s.actor.x - other.actor.x
				var dy: float = s.actor.y - other.actor.y
				var dz: float = s.actor.z - other.actor.z
				var d2 := dz * dz + dy * dy + dx * dx
				if best < d2:
					s.ahead = other
					best = d2
	if s.ahead != null:
		var vx: float = (s.actor.x - s.ahead.actor.x) * EIGHTH
		var vz: float = (s.actor.z - s.ahead.actor.z) * EIGHTH
		if _dist2(vx, vz) < s.f(0x78):
			if (s.flags & 0x200000) == 0:
				s.flags = s.flags | 0x1000000
				return true
			s.flags = s.flags | 0x400000
	return false


## FUN_0044904B
func _crossing_wait(s: WalkerSlot) -> bool:
	for other in _list_of(s.graph, 2, s.s16(0x1A)):
		if other != s and other.graph == 1 and (other.flags & 0x1000000) == 0:
			s.flags = s.flags | 0x1000000
			return true
	return false


## FUN_00448F7A
func _junction_wait(s: WalkerSlot) -> bool:
	for other in _list_of(s.graph, 0, s.s16(0x1C)):
		if other != s and (other.flags & 0x1000000) == 0 and other.s16(0x1A) != s.s16(0x1A):
			if _priority(s.graph, s.s16(0x1A)) <= _priority(s.graph, other.s16(0x1A)):
				s.flags = s.flags | 0x1000000
				return true
	return false


## FUN_00448ED2
func _path_wait(s: WalkerSlot, m: Array) -> bool:
	if absf(m[5]) <= s.f(0x54):
		var linked := _link(s.graph, s.s16(0x1A))
		for other in _list_of(0, 1, linked):
			if other != s and (other.flags & 0x1000000) == 0:
				s.flags = s.flags | 0x1000000
				return true
	return false


## FUN_00449316
func _held_back(s: WalkerSlot, m: Array) -> bool:
	s.flags = s.flags & 0xFEFFFFFF
	s.flags = s.flags & 0xFFBFFFFF
	if _ahead_search(s):
		return true
	if s.graph == 0:
		if (s.flags & 0x100000) == 0 and s.s16(0x1A) > -1 and _kind(s.graph, s.s16(0x1A)) == 4 and _crossing_wait(s):
			return true
		if s.s16(0x1C) > -1 and _kind(s.graph, s.s16(0x1C)) == 2 and _junction_wait(s):
			return true
	elif s.graph == 1 and (s.flags & 0x100000) == 0 and s.s16(0x1A) > -1 and _kind(s.graph, s.s16(0x1A)) == 4 and _path_wait(s, m):
		return true
	return false


## FUN_0044947A: one step along the current stretch.
func _move(s: WalkerSlot, m: Array) -> void:
	var phase := s.flags & 0x7000
	if _held_back(s, m):
		return
	var mode := 0
	if _turn_step(s, m):
		mode = 2
	else:
		mode = 1
		if phase != 0x1000:
			s.flags = s.flags & 0xFFFF8FFF
			var corner := _corner(s, phase)
			if phase == 0:
				if corner == 0:
					_compute_speed(s)
					s.flags = s.flags | 0x1000
				elif corner == 2:
					s.flags = s.flags | 0x1000
				else:
					s.flags = s.flags | 0x2000
			elif phase == 0x2000:
				if corner == 0:
					s.flags = s.flags | 0x3000
				else:
					s.flags = s.flags | 0x1000
			elif phase == 0x3000:
				s.flags = s.flags | 0x1000
	var travel := 0.0
	if mode == 2:
		travel = s.f(0x48) * s.f(0x80)
	else:
		travel = s.f(0x44) * s.f(0x80)
	travel = travel * 1.0
	m[6] = travel + m[6]
	m[1] = sin(m[0]) * travel + m[1]
	m[2] = cos(m[0]) * travel + m[2]


## FUN_00449646: turn on the spot.
func _turn_on_spot(s: WalkerSlot, m: Array) -> int:
	m[5] = wrap_angle(m[0] - s.f(0x60))
	s.set_f(0x54, s.f(0x40))
	return -3 if not _turn_step(s, m) else -2


## FUN_004496D4: walk toward a goal position or the followed actor.
func _head_for_goal(s: WalkerSlot, m: Array) -> int:
	var lx := 0.0
	var lz := 0.0
	if (s.flags & 0x60000000) == 0x60000000:
		if s.u32(0x3C) == 0:
			s.flags = s.flags | 2
			s.flags = s.flags & KEEP_LOW
			return -1
		lx = s.f(0x30) * EIGHTH - m[1]
		lz = s.f(0x38) * EIGHTH - m[2]
	else:
		if s.follow == null:
			s.flags = s.flags | 2
			s.flags = s.flags & KEEP_LOW
			return -1
		lx = s.follow.x * EIGHTH - m[1]
		lz = s.follow.z * EIGHTH - m[2]
	var heading := atan2(lx, lz)
	s.set_f(0x60, heading)
	m[5] = wrap_angle(m[0] - s.f(0x60))
	s.set_f(0x54, s.f(0x40))
	return -3 if not _turn_step(s, m) else -2


## FUN_00449853: arrived at the node; pick the next stretch.
func _next_stretch(s: WalkerSlot) -> void:
	if s.s16(0x1A) < 0:
		if s.follow == null:
			s.flags = s.flags & 0xFFFFFFFB
			s.flags = s.flags | 2
		else:
			s.flags = s.flags & KEEP_LOW
			s.flags = s.flags | 0x20000000
	else:
		set_from(s, s.s16(0x1A))
		set_to(s, s.s16(0x1C))
		s.flags = s.flags & 0xFFFF8FFF
		if s.s16(0x1A) > -1:
			var after := next_node(s.graph, s.s16(0x1A), s.s16(0x18))
			set_after(s, after)


## FUN_00449916: walk toward the goal position (alternate mode); false when reached.
func _head_for_goal_alt(s: WalkerSlot, m: Array) -> bool:
	var dx: float = s.f(0x30) * EIGHTH - m[1]
	var dz: float = s.f(0x38) * EIGHTH - m[2]
	var heading := atan2(dx, dz)
	s.set_f(0x60, heading)
	var sine := sin(heading)
	var cosine := cos(heading)
	m[5] = wrap_angle(m[0] - s.f(0x60))
	s.set_f(0x7C, _dist2(dx + sine, dz + cosine))
	var reached_not := 1.0 <= s.f(0x7C)
	if not reached_not:
		s.flags = s.flags & 0xFFFFFFFB
		s.flags = s.flags | 2
	return reached_not


## FUN_00449A5E: aim at the point on the stretch ahead; true while still on route.
func _aim(s: WalkerSlot, m: Array) -> bool:
	while true:
		if s.s16(0x1A) < 0:
			return false
		if s.s16(0x18) == s.s16(0x1E):
			break
		if s.s16(0x1A) == s.s16(0x1E):
			_next_stretch(s)
		else:
			var sine := sin(s.f(0x5C))
			var cosine := cos(s.f(0x5C))
			var offset_x := s.f(0x20) * cosine + (1.0 + s.f(0x70)) * sine
			var offset_z := -sine * s.f(0x20) + (1.0 + s.f(0x70)) * cosine
			var node := node_position(s.graph, s.s16(0x1A))
			var target_x := node.x * EIGHTH + offset_x
			var target_z := node.z * EIGHTH + offset_z
			var dx: float = target_x - m[1]
			var dz: float = target_z - m[2]
			var heading := atan2(dx, dz)
			s.set_f(0x60, heading)
			m[5] = wrap_angle(m[0] - s.f(0x60))
			s.set_f(0x7C, _dist2(dx, dz))
			if s.f(0x6C) * s.f(0x6C) <= s.f(0x7C):
				return true
			_next_stretch(s)
	return false


## FUN_00449C81: set the route up when it was just ordered.
func _prepare(s: WalkerSlot) -> void:
	if (s.flags & 0x18) != 0 and (s.flags & 0x60000000) == 0:
		var g := s.graph
		if (s.flags & 4) == 0:
			set_to(s, next_node(g, s.s16(0x1E), s.s16(0x18)))
			set_after(s, next_node(g, s.s16(0x1A), s.s16(0x18)))
			_compute_speed(s)
		elif (s.flags & 8) == 0:
			set_after(s, next_node(g, s.s16(0x1A), s.s16(0x18)))
		elif s.s16(0x1A) == s.s16(0x1E):
			set_to(s, next_node(g, s.s16(0x1E), s.s16(0x18)))
			set_after(s, next_node(g, s.s16(0x1A), s.s16(0x18)))
			_compute_speed(s)
		else:
			var n := next_node(g, s.s16(0x1A), s.s16(0x18))
			if n == s.s16(0x1E):
				set_from(s, s.s16(0x1A))
				set_to(s, n)
				set_after(s, next_node(g, n, s.s16(0x18)))
				_compute_speed(s)
			else:
				set_after(s, next_node(g, s.s16(0x1A), s.s16(0x18)))
		s.flags = s.flags | 4
		s.flags = s.flags & 0xFFFF8FFF
		s.flags = s.flags & 0xFFFFFFE7


## FUN_00449EB6: one step. `pos` is the actor's position in game units, `yaw` its heading.
## Returns [result, yaw, position, moved]; result is the node reached, -1 nothing to do,
## -2 turning, -3 turn finished, -4 walking to a goal.
func _step(s: WalkerSlot, pos: Vector3, yaw: float) -> Array:
	var result := 0
	_prepare(s)
	var m := [wrap_angle(yaw), pos.x * EIGHTH, pos.z * EIGHTH, 0.0, 0.0, 0.0, 0.0]
	last_y = pos.y
	var mode := s.flags & MODE_MASK
	var goto_goal := false
	if mode == 0x20000000:
		goto_goal = true
	elif mode == 0x80000000:
		if (s.flags & 4) == 0:
			result = -1
		else:
			if _aim(s, m):
				_move(s, m)
				result = s.s16(0x1A)
			elif (s.flags & MODE_MASK) != 0x20000000:
				result = -1
				s.flags = s.flags | 2
				s.flags = s.flags & 0xFFFF8FFF
			else:
				goto_goal = true
	elif mode == 0x10000000:
		if not _head_for_goal_alt(s, m):
			s.flags = s.flags | 2
			s.flags = s.flags & 0xFFFF8FFF
			result = -1
		else:
			_move(s, m)
			result = -4
	elif mode == 0x40000000:
		s.set_f(0x54, s.f(0x40))
		result = _turn_on_spot(s, m)
	elif mode == 0x60000000:
		goto_goal = true
	if goto_goal:
		result = _head_for_goal(s, m)
	return [result, m[0], Vector3(m[1] * 8.0, pos.y, m[2] * 8.0), m[6]]


## FUN_00447390(handle, position, yaw) -> [result, yaw, position, moved]
func step(handle: int, pos: Vector3, yaw: float) -> Array:
	var s := slot(handle)
	if (s.flags & 2) == 0:
		return _step(s, pos, yaw)
	return [-1, yaw, pos, 0.0]


## FUN_00446CA4: put the actor where its walker says it should stand.
func bind(handle: int, actor) -> void:
	var s := slot(handle)
	if actor == null:
		return
	var m := [actor.yaw, actor.x * EIGHTH, actor.z * EIGHTH, 0.0, 0.0, 0.0, 0.0]
	if s.s16(0x1A) > -1:
		_aim(s, m)
		actor.yaw = s.f(0x60)
		services.set_rotation(actor, actor.field_f(0x4C), actor.yaw, actor.field_f(0x54))
	var lane_now := absf(s.f(0x20))
	if 0.0010000000474974513 < lane_now and s.s16(0x1E) > -1:
		var b: float = actor.yaw
		var c: float = actor.field_f(0x54)
		var side := Vector3(cos(c) * cos(b), sin(c) * cos(b), -sin(b)) * (s.f(0x20) * 8.0)
		var node := node_position(s.graph, s.s16(0x1E))
		actor.x = side.x + node.x
		actor.y = side.y + node.y
		actor.z = side.z + node.z
