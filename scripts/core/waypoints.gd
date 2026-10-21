extends RefCounted

## Island waypoint graph, read straight from the game's own `.wpt` files.
##
## CONFIRMED layout (Ghidra: `FUN_0045ade0` builds the file name from the strings
## `_Data\z02LGI\Waypoints\W_ROAD` + `_C.wpt`; the bytes were then read from
## `_data/z02LGI/waypoints/w_road_c.wpt` and checked against the loader's fields):
##
##   header   5 x i32:  -1, 5, 0, nodeCount, edgeCount
##   nodes    nodeCount x 32 bytes:
##              +0x00 f32 x, +0x04 f32 y, +0x08 f32 z
##              +0x0c i16 edge-group index (-1 = none)
##              +0x0e i16 index inside that group
##   edges    edgeCount x 16-byte descriptor (i32 w, i32 h, i32 runtime ptr, i32 pad)
##            each immediately followed by w*h i16 next-hop entries
##
## The descriptor's pointer field is filled in at load time, so the matrices are
## read in descriptor order from the blob that follows the descriptor array.
##
## `next_node()` is `FUN_00448049`: the next node on the route from `a` toward
## `b`, looked up in the group matrix (this is how the exe routes without an A*).

var node_count := 0
var edge_count := 0
var nodes := PackedVector3Array()
var group := PackedInt32Array()
var index := PackedInt32Array()
## Node bytes +0x10 (kind: 1 / 2 / 4 mark crossings and links), +0x11 (priority) and +0x12
## (short link to the road node of a path node).
var kind := PackedInt32Array()
var priority := PackedInt32Array()
var link := PackedInt32Array()
# Per edge group: {"w": int, "h": int, "m": PackedInt32Array}
var edges: Array = []


func parse(bytes: PackedByteArray) -> bool:
	if bytes.size() < 20:
		return false
	node_count = bytes.decode_s32(12)
	edge_count = bytes.decode_s32(16)
	if node_count <= 0 or edge_count < 0:
		return false
	if bytes.size() < 20 + node_count * 32:
		return false
	nodes.resize(node_count)
	group.resize(node_count)
	index.resize(node_count)
	kind.resize(node_count)
	priority.resize(node_count)
	link.resize(node_count)
	var at := 20
	for i in node_count:
		nodes[i] = Vector3(
			bytes.decode_float(at),
			bytes.decode_float(at + 4),
			bytes.decode_float(at + 8))
		group[i] = bytes.decode_s16(at + 12)
		index[i] = bytes.decode_s16(at + 14)
		kind[i] = bytes.decode_u8(at + 16)
		priority[i] = bytes.decode_u8(at + 17)
		link[i] = bytes.decode_s16(at + 18)
		at += 32
	var desc_at := at
	var data_at := desc_at + edge_count * 16
	for g in edge_count:
		if desc_at + g * 16 + 8 > bytes.size():
			return false
		var w := bytes.decode_s32(desc_at + g * 16)
		var h := bytes.decode_s32(desc_at + g * 16 + 4)
		var m := PackedInt32Array()
		if w > 0 and h > 0:
			if data_at + w * h * 2 > bytes.size():
				return false
			m.resize(w * h)
			for k in w * h:
				m[k] = bytes.decode_s16(data_at + k * 2)
			data_at += w * h * 2
		edges.append({"w": w, "h": h, "m": m})
	return true


## FUN_00448049(table, from, to) -> the next node toward `to`, or `from` when
## there is no hop. Out-of-range indices clamp the way the exe clamps them.
func next_node(from_id: int, to_id: int) -> int:
	var a := from_id
	var b := to_id
	if a < 0 or b < 0 or a >= node_count or b >= node_count:
		if a >= node_count:
			a = node_count - 1
		if b >= node_count:
			b = node_count - 1
		if a < 0 or b < 0:
			return a
	var result := a
	if a == b:
		return result
	var proceed := true
	if group[b] < 0:
		var raw := b
		b = index[b]
		result = raw
		proceed = a != b
	if not proceed:
		return result
	var ga := group[a]
	if ga < 0:
		return index[a]
	if ga >= edges.size():
		return result
	var edge: Dictionary = edges[ga]
	var w: int = int(edge["w"])
	var h: int = int(edge["h"])
	if w <= 0 or h <= 0:
		return result
	var column := index[b] if ga == group[b] else group[b] + h
	var cell := index[a] * w + column
	var m: PackedInt32Array = edge["m"]
	if cell < 0 or cell >= m.size():
		return result
	return m[cell]


## The full node chain from `from_id` to `to_id` (inclusive), or [] if the route
## never reaches the target.
func route(from_id: int, to_id: int, limit := 400) -> Array:
	var out: Array = []
	var cur := from_id
	while out.size() < limit:
		out.append(cur)
		if cur == to_id:
			return out
		var nxt := next_node(cur, to_id)
		if nxt == cur or out.has(nxt):
			break
		cur = nxt
	return out if out.has(to_id) else []
