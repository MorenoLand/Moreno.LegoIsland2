class_name ColFile
extends RefCounted

const RECORD := 88
const WALL_SLOPE := 0.5
const FACE_AT := 0x08
const EDGE_AT := [0x18, 0x28, 0x38]

var count := 0
var flags := PackedInt32Array()
var surface := PackedInt32Array()
var faces := PackedFloat32Array()
var planes := PackedFloat32Array()
var box_a := Vector3.ZERO
var box_b := Vector3.ZERO
var last_surface := 0


static func parse(bytes: PackedByteArray) -> ColFile:
	if bytes.size() < 40 or bytes.slice(0, 4).get_string_from_ascii() != "CBBX":
		return null
	var out := ColFile.new()
	out.box_a = Vector3(bytes.decode_float(4), bytes.decode_float(8), bytes.decode_float(12))
	out.box_b = Vector3(bytes.decode_float(16), bytes.decode_float(20), bytes.decode_float(24))
	var tag := bytes.slice(32, 36).get_string_from_ascii()
	if tag != "COLP":
		return out
	out.count = bytes.decode_u32(36)
	out.flags.resize(out.count)
	out.surface.resize(out.count)
	out.planes.resize(out.count * 12)
	out.faces.resize(out.count * 4)
	for i in out.count:
		var at := 40 + i * RECORD
		out.flags[i] = bytes.decode_u32(at)
		out.surface[i] = bytes.decode_u32(at + 4)
		for k in 4:
			out.faces[i * 4 + k] = bytes.decode_float(at + FACE_AT + k * 4)
		for p in 3:
			for k in 4:
				out.planes[i * 12 + p * 4 + k] = bytes.decode_float(at + EDGE_AT[p] + k * 4)
	return out


const CELL := 12.0
var _grid := {}
var _loose := PackedInt32Array()
var _grid_built := false


## Buckets every floor-ish polygon by the XZ cells its corners cover. The corners
## are recovered from the face plane and the three edge planes (each pair of edge
## planes meets the face plane in one corner), so a query only tests the polygons
## near it instead of the whole file.
func _build_grid() -> void:
	_grid_built = true
	for i in count:
		if faces[i * 4 + 1] < 0.05:
			continue
		var face := Vector3(faces[i * 4], faces[i * 4 + 1], faces[i * 4 + 2])
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		var ok := true
		for pair in [[0, 1], [1, 2], [0, 2]]:
			var o1: int = i * 12 + pair[0] * 4
			var o2: int = i * 12 + pair[1] * 4
			var rows := Basis(face, Vector3(planes[o1], planes[o1 + 1], planes[o1 + 2]),
				Vector3(planes[o2], planes[o2 + 1], planes[o2 + 2])).transposed()
			if absf(rows.determinant()) < 0.000001:
				ok = false
				break
			var corner: Vector3 = rows.inverse() * Vector3(faces[i * 4 + 3], planes[o1 + 3], planes[o2 + 3])
			low = low.min(Vector2(corner.x, corner.z))
			high = high.max(Vector2(corner.x, corner.z))
		if not ok or high.x - low.x > 400.0 or high.y - low.y > 400.0:
			_loose.append(i)
			continue
		var x0 := int(floor((low.x - 0.5) / CELL))
		var x1 := int(floor((high.x + 0.5) / CELL))
		var z0 := int(floor((low.y - 0.5) / CELL))
		var z1 := int(floor((high.y + 0.5) / CELL))
		for cx in range(x0, x1 + 1):
			for cz in range(z0, z1 + 1):
				var key := Vector2i(cx, cz)
				var list: PackedInt32Array = _grid.get(key, PackedInt32Array())
				list.append(i)
				_grid[key] = list


func ground(x: float, z: float, y_from: float, step: float, mask := 0xFFFFFFFF) -> float:
	if not _grid_built:
		_build_grid()
	var best := -INF
	var cell: PackedInt32Array = _grid.get(Vector2i(int(floor(x / CELL)), int(floor(z / CELL))), PackedInt32Array())
	for list in [cell, _loose]:
		for i in list:
			if (flags[i] & mask) == 0:
				continue
			var ny: float = faces[i * 4 + 1]
			if ny < 0.05:
				continue
			var y: float = (faces[i * 4 + 3] - faces[i * 4] * x - faces[i * 4 + 2] * z) / ny
			if y > y_from + step or y <= best:
				continue
			var inside := true
			for p in 3:
				var o: int = i * 12 + p * 4
				if planes[o] * x + planes[o + 1] * y + planes[o + 2] * z - planes[o + 3] > 0.0:
					inside = false
					break
			if inside:
				best = y
				last_surface = surface[i]
	return best


var _walls := PackedInt32Array()
var _walls_built := false
var _wall_grid := {}
var _wall_loose := PackedInt32Array()


func _build_walls() -> void:
	_walls_built = true
	for i in count:
		if absf(faces[i * 4 + 1]) >= WALL_SLOPE:
			continue
		_walls.append(i)
		var face := Vector3(faces[i * 4], faces[i * 4 + 1], faces[i * 4 + 2])
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		var ok := true
		for pair in [[0, 1], [1, 2], [0, 2]]:
			var o1: int = i * 12 + pair[0] * 4
			var o2: int = i * 12 + pair[1] * 4
			var rows := Basis(face, Vector3(planes[o1], planes[o1 + 1], planes[o1 + 2]),
				Vector3(planes[o2], planes[o2 + 1], planes[o2 + 2])).transposed()
			if absf(rows.determinant()) < 0.000001:
				ok = false
				break
			var corner: Vector3 = rows.inverse() * Vector3(faces[i * 4 + 3], planes[o1 + 3], planes[o2 + 3])
			low = low.min(Vector2(corner.x, corner.z))
			high = high.max(Vector2(corner.x, corner.z))
		if not ok or high.x - low.x > 400.0 or high.y - low.y > 400.0:
			_wall_loose.append(i)
			continue
		for cx in range(int(floor((low.x - 0.6) / CELL)), int(floor((high.x + 0.6) / CELL)) + 1):
			for cz in range(int(floor((low.y - 0.6) / CELL)), int(floor((high.y + 0.6) / CELL)) + 1):
				var key := Vector2i(cx, cz)
				var list: PackedInt32Array = _wall_grid.get(key, PackedInt32Array())
				list.append(i)
				_wall_grid[key] = list


func wall_hit(a: Vector3, b: Vector3, heights: PackedFloat32Array) -> Vector3:
	if not _walls_built:
		_build_walls()
	var low := Vector2(minf(a.x, b.x) - 0.5, minf(a.z, b.z) - 0.5)
	var high := Vector2(maxf(a.x, b.x) + 0.5, maxf(a.z, b.z) + 0.5)
	if high.x < box_a.x or low.x > box_b.x or high.y < box_a.z or low.y > box_b.z:
		return Vector3.ZERO
	var candidates := {}
	for cx in range(int(floor(low.x / CELL)), int(floor(high.x / CELL)) + 1):
		for cz in range(int(floor(low.y / CELL)), int(floor(high.y / CELL)) + 1):
			for w in _wall_grid.get(Vector2i(cx, cz), PackedInt32Array()):
				candidates[w] = true
	for w in _wall_loose:
		candidates[w] = true
	var ordered: Array = candidates.keys()
	ordered.sort()
	for i: int in ordered:
		var nx := faces[i * 4]
		var ny := faces[i * 4 + 1]
		var nz := faces[i * 4 + 2]
		var d := faces[i * 4 + 3]
		for h in heights:
			var s0 := nx * a.x + ny * (a.y + h) + nz * a.z - d
			var s1 := nx * b.x + ny * (b.y + h) + nz * b.z - d
			if s0 * s1 >= 0.0 or s0 == s1:
				continue
			var t := s0 / (s0 - s1)
			var px := a.x + (b.x - a.x) * t
			var py := a.y + h + (b.y - a.y) * t
			var pz := a.z + (b.z - a.z) * t
			var inside := true
			for k in 3:
				var o: int = i * 12 + k * 4
				if planes[o] * px + planes[o + 1] * py + planes[o + 2] * pz - planes[o + 3] > 0.0:
					inside = false
					break
			if inside:
				return Vector3(nx, 0.0, nz).normalized()
	return Vector3.ZERO
