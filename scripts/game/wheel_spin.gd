extends RefCounted

## Vehicle meshes are one static mesh with every wheel baked in. Wheels are found
## by shape (a round part, about the width of a tyre, sitting on the ground),
## cut out into child nodes about their own axle and turned as the vehicle moves.

const MIN_DIAMETER := 0.9
const MAX_DIAMETER := 2.6
const MAX_WIDTH := 2.2
const ROUND := 0.1
const SAME_AXLE := 0.25
const SAME_SIDE := 1.4

var wheels: Array = []


## Cuts the wheels out of `node.mesh` and leaves the rest as the body.
static func split(node: MeshInstance3D) -> Object:
	var out = load("res://scripts/game/wheel_spin.gd").new()
	var mesh := node.mesh as ArrayMesh
	if mesh == null:
		return out
	var parts: Array = []
	var body := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var material := mesh.surface_get_material(s)
		var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var parent := PackedInt32Array()
		parent.resize(pos.size())
		for i in pos.size():
			parent[i] = i
		for t in range(0, idx.size() - 2, 3):
			var a := _root(parent, idx[t])
			var b := _root(parent, idx[t + 1])
			var c := _root(parent, idx[t + 2])
			parent[b] = a
			parent[_root(parent, c)] = a
		var tris := {}
		for t in range(0, idx.size() - 2, 3):
			var r := _root(parent, idx[t])
			if not tris.has(r):
				tris[r] = PackedInt32Array()
			var list: PackedInt32Array = tris[r]
			list.append(idx[t])
			list.append(idx[t + 1])
			list.append(idx[t + 2])
			tris[r] = list
		var keep := PackedInt32Array()
		for r in tris:
			var list: PackedInt32Array = tris[r]
			var low := Vector3(INF, INF, INF)
			var high := -low
			for i in list:
				low = low.min(pos[i])
				high = high.max(pos[i])
			var size := high - low
			var center := (low + high) * 0.5
			if _is_wheel(center, size):
				parts.append({"arrays": arrays, "material": material, "tris": list, "center": center, "size": size})
			else:
				keep.append_array(list)
		if not keep.is_empty():
			_add_surface(body, arrays, keep, material, Vector3.ZERO)
	if parts.is_empty():
		return out
	var clusters: Array = []
	for part in parts:
		var found := -1
		for k in clusters.size():
			var head: Dictionary = clusters[k][0]
			var d: Vector3 = (head.center as Vector3) - (part.center as Vector3)
			if absf(d.y) < SAME_AXLE and absf(d.z) < SAME_AXLE and absf(d.x) < SAME_SIDE:
				found = k
				break
		if found < 0:
			clusters.append([part])
		else:
			clusters[found].append(part)
	node.mesh = body
	for cluster in clusters:
		var big: Dictionary = cluster[0]
		for part in cluster:
			if part.size.y > big.size.y:
				big = part
		var center: Vector3 = big.center
		var mesh_part := ArrayMesh.new()
		for part in cluster:
			_add_surface(mesh_part, part.arrays, part.tris, part.material, center)
		var wheel := MeshInstance3D.new()
		wheel.mesh = mesh_part
		wheel.position = center
		node.add_child(wheel)
		out.wheels.append({"node": wheel, "radius": maxf(float(big.size.y) * 0.5, 0.1), "angle": 0.0})
	return out


## Turns every wheel for `distance` travelled; `sign` is +1 when the vehicle's
## local +Z is forward, -1 when local -Z is.
func spin(distance: float, sign: float) -> void:
	for w in wheels:
		w.angle = fposmod(float(w.angle) + sign * distance / float(w.radius), TAU)
		(w.node as MeshInstance3D).basis = Basis(Vector3.RIGHT, float(w.angle))


static func _is_wheel(center: Vector3, size: Vector3) -> bool:
	var tall := maxf(size.y, size.z)
	if tall < MIN_DIAMETER or tall > MAX_DIAMETER or size.x > MAX_WIDTH:
		return false
	if absf(size.y - size.z) > ROUND * tall:
		return false
	return center.y > 0.3 and center.y < 1.8


static func _root(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _add_surface(target: ArrayMesh, arrays: Array, tris: PackedInt32Array, material: Material, origin: Vector3) -> void:
	var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var remap := {}
	var out_pos := PackedVector3Array()
	var out_nor := PackedVector3Array()
	var out_uv := PackedVector2Array()
	var out_col := PackedColorArray()
	var out_idx := PackedInt32Array()
	var nor: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var col: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in tris:
		if not remap.has(i):
			remap[i] = out_pos.size()
			out_pos.append(pos[i] - origin)
			out_nor.append(nor[i])
			out_uv.append(uv[i])
			out_col.append(col[i])
		out_idx.append(remap[i])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = out_pos
	out[Mesh.ARRAY_NORMAL] = out_nor
	out[Mesh.ARRAY_TEX_UV] = out_uv
	out[Mesh.ARRAY_COLOR] = out_col
	out[Mesh.ARRAY_INDEX] = out_idx
	target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	target.surface_set_material(target.get_surface_count() - 1, material)
