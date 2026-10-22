class_name RecordCollision
extends RefCounted

## The exe's per-record collision query FUN_00428AB0 on the polygon files (.col): a segment, thickened by
## a radius, swept against the polygons of one record. The polygon test is FUN_004277B0, the
## bounding sphere test FUN_00880B89; the record's matrix takes the segment into the file's space.
## The sphere / box record shapes (FUN_00427CA0 / FUN_00427DA0) and the 0x40 flag path
## (FUN_00428080) are not ported: the query answers no hit for them.

const FAR := 1.0e30
const MODE_BODY := 0x80


## FUN_00880B89(a, b, centre, radius): the parameter along a -> b where it meets the sphere
## (the second root when the first is behind a), or -1.
static func segment_sphere(a: Vector3, b: Vector3, centre: Vector3, radius: float) -> float:
	var from_centre := a - centre
	var along := b - a
	var length_squared := along.length_squared()
	var half_inverse := 1.0 / (length_squared * 2.0)
	var dot := along.dot(from_centre)
	dot = dot + dot
	var discriminant := dot * dot - length_squared * (from_centre.length_squared() - radius * radius) * 4.0
	if discriminant <= 0.0:
		return -1.0
	var root := sqrt(discriminant)
	var near := (-dot - root) * half_inverse
	var far := (-dot + root) * half_inverse
	if near < 0.0 or far < near:
		near = far
	return near


## FUN_00422C22: a world point into the record's space (row vectors, the matrix rows are the axes).
static func to_local(m: PackedFloat32Array, p: Vector3) -> Vector3:
	var d := Vector3(p.x - m[12], p.y - m[13], p.z - m[14])
	return Vector3(
		d.x * m[0] + d.y * m[1] + d.z * m[2],
		d.x * m[4] + d.y * m[5] + d.z * m[6],
		d.x * m[8] + d.y * m[9] + d.z * m[10])


## FUN_00422772: a point of the record's space into the world.
static func to_world(m: PackedFloat32Array, p: Vector3) -> Vector3:
	return Vector3(
		p.x * m[0] + p.y * m[4] + p.z * m[8] + m[12],
		p.x * m[1] + p.y * m[5] + p.z * m[9] + m[13],
		p.x * m[2] + p.y * m[6] + p.z * m[10] + m[14])


## FUN_004227E6: a direction of the record's space into the world (no translation).
static func rotate(m: PackedFloat32Array, v: Vector3) -> Vector3:
	return Vector3(
		v.x * m[0] + v.y * m[4] + v.z * m[8],
		v.x * m[1] + v.y * m[5] + v.z * m[9],
		v.x * m[2] + v.y * m[6] + v.z * m[10])


## FUN_004277B0(start, end, polygon, state): the sweep of the segment against one polygon in the
## file's space. `state` holds "r0" (the edge tolerance), "r1" (the plane tolerance), "t" (the best
## parameter so far, only nearer hits count) and receives "point", "normal" and "poly".
static func sweep_polygon(col: ColFile, index: int, a: Vector3, b: Vector3, state: Dictionary) -> bool:
	var normal := Vector3(col.faces[index * 4], col.faces[index * 4 + 1], col.faces[index * 4 + 2])
	var plane: float = col.faces[index * 4 + 3]
	var from_plane := a.dot(normal) - plane
	var to_plane := b.dot(normal) - plane
	var r1: float = state["r1"]
	var travel: float
	var span: float
	if from_plane >= 0.0:
		if to_plane >= 0.0:
			if from_plane < to_plane:
				return false
			if 0.0 < from_plane - r1 and r1 < to_plane:
				return false
		span = from_plane - to_plane
		travel = from_plane - r1
	else:
		travel = -from_plane - r1
		if to_plane < 0.0:
			if -from_plane < -to_plane:
				return false
			if 0.0 < travel and r1 < -to_plane:
				return false
		span = to_plane - from_plane
	var t: float
	var x: float
	var y: float
	var z_offset: float
	if travel <= r1:
		t = 0.0
		var push := -(from_plane + r1) if from_plane < 0.0 else r1 - from_plane
		x = push * normal.x + a.x
		y = push * normal.y + a.y
		z_offset = push * normal.z
	else:
		t = travel / span
		if t < 0.0 or 1.0 < t:
			return false
		if float(state["t"]) < t:
			return false
		x = (b.x - a.x) * t + a.x
		y = (b.y - a.y) * t + a.y
		z_offset = (b.z - a.z) * t
	var z := z_offset + a.z
	var r0: float = state["r0"]
	for edge in 3 + (1 if (col.flags[index] & 4) != 0 else 0):
		var ex: float
		var ey: float
		var ez: float
		var ed: float
		if edge < 3:
			var at := index * 12 + edge * 4
			ex = col.planes[at]
			ey = col.planes[at + 1]
			ez = col.planes[at + 2]
			ed = col.planes[at + 3]
		else:
			ex = col.quad_edge[index * 4]
			ey = col.quad_edge[index * 4 + 1]
			ez = col.quad_edge[index * 4 + 2]
			ed = col.quad_edge[index * 4 + 3]
		if r0 < (y * ey + x * ex + z * ez) - ed:
			return false
	state["t"] = t
	state["point"] = Vector3(x, y, z)
	state["normal"] = normal
	state["poly"] = index
	return true


## FUN_00428AB0(record, query, 0): does the segment start -> start + direction touch the record's
## polygons whose flag word matches `mask`. The record must be visible (flag 2), or carry flag
## 0x20 unless the query has the body bit 0x80. Returns {} for no hit, else {"point", "normal",
## "poly", "t"} in world space.
static func query(record, matrix: PackedFloat32Array, start: Vector3, direction: Vector3, mask: int, radius_a: float, radius_b: float) -> Dictionary:
	var col: ColFile = record.col
	if col == null or col.count == 0:
		return {}
	var flags: int = record.flags
	if ((flags & 0x20) == 0 or (mask & MODE_BODY) != 0) and (flags & 2) == 0:
		return {}
	if (flags & 0x40) != 0 and (mask & 0x40) == 0:
		return {}
	var end := start + direction
	var centre := to_world(matrix, col.box_a)
	if segment_sphere(start, end, centre, col.radius) <= 0.0:
		return {}
	var local_start := to_local(matrix, start)
	var local_end := to_local(matrix, end)
	var state := {"r0": radius_a, "r1": radius_b, "t": FAR}
	var found := false
	for i in col.count:
		if (col.flags[i] & mask) != 0 and sweep_polygon(col, i, local_start, local_end, state):
			found = true
	if not found:
		return {}
	return {
		"point": to_world(matrix, state["point"]),
		"normal": rotate(matrix, state["normal"]),
		"poly": state["poly"],
		"t": state["t"],
	}
