class_name MeshFile
extends RefCounted

var positions := PackedVector3Array()
var normals := PackedVector3Array()
var uvs := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()
var groups: Array[PackedInt32Array] = []
var bones := PackedInt32Array()
var weights := PackedFloat32Array()
## GTOM: the matrix each group is drawn with, MATL: those matrices. Props such as
## vehicles keep their wheels and doors as groups modelled around the origin.
var group_matrix := PackedInt32Array()
var matrices: Array[Transform3D] = []


static func parse(data: PackedByteArray) -> MeshFile:
	if data.size() < 12 or data.slice(0, 4).get_string_from_ascii() != "VERT":
		return null
	var m := MeshFile.new()
	var n := data.decode_u32(4)
	var pos := 8
	m.positions.resize(n)
	m.uvs.resize(n)
	m.colors.resize(n)
	for i in n:
		var at := pos + i * 32
		m.positions[i] = Vector3(data.decode_float(at), data.decode_float(at + 4), data.decode_float(at + 8))
		var c := data.decode_u32(at + 12)
		m.colors[i] = Color(((c >> 16) & 0xFF) / 255.0, ((c >> 8) & 0xFF) / 255.0, (c & 0xFF) / 255.0, ((c >> 24) & 0xFF) / 255.0)
		m.uvs[i] = Vector2(data.decode_float(at + 16), data.decode_float(at + 20))
	pos += n * 32
	m.normals.resize(n)
	for i in n:
		var at := pos + i * 12
		m.normals[i] = Vector3(data.decode_float(at), data.decode_float(at + 4), data.decode_float(at + 8))
	pos += n * 12
	if data.slice(pos, pos + 4).get_string_from_ascii() != "INDL":
		return null
	var k := data.decode_u32(pos + 4)
	pos += 8
	m.indices.resize(k)
	for i in k:
		m.indices[i] = data.decode_u16(pos + i * 2)
	pos += k * 2
	if data.slice(pos, pos + 4).get_string_from_ascii() != "GRPL":
		return null
	var g := data.decode_u32(pos + 4)
	pos += 8
	for i in g:
		var at := pos + i * 20
		m.groups.append(PackedInt32Array([data.decode_u32(at), data.decode_u32(at + 4), data.decode_u32(at + 8), data.decode_u32(at + 12), data.decode_u32(at + 16)]))
	pos += g * 20
	if pos + 8 <= data.size() and data.slice(pos, pos + 4).get_string_from_ascii() == "SVWL":
		var c := data.decode_u32(pos + 4)
		pos += 8
		if pos + c * 8 <= data.size():
			m.bones.resize(c)
			m.weights.resize(c)
			for i in c:
				m.bones[i] = data.decode_s32(pos + i * 8)
				m.weights[i] = data.decode_float(pos + i * 8 + 4)
	pos = _tail(data, m, pos)
	return m


## Reads the GTOM / MATL chunks that follow the group list (or the skin weights).
static func _tail(data: PackedByteArray, m: MeshFile, pos: int) -> int:
	while pos + 8 <= data.size():
		var tag := data.slice(pos, pos + 4).get_string_from_ascii()
		var c := data.decode_u32(pos + 4)
		if tag == "GTOM":
			if pos + 8 + c * 4 > data.size():
				break
			m.group_matrix.resize(c)
			for i in c:
				m.group_matrix[i] = data.decode_u32(pos + 8 + i * 4)
			pos += 8 + c * 4
		elif tag == "MATL":
			if pos + 8 + c * 36 > data.size():
				break
			for i in c:
				var at := pos + 8 + i * 36
				var f := PackedFloat32Array()
				for k in 9:
					f.append(data.decode_float(at + k * 4))
				m.matrices.append(_matrix(f))
			pos += 8 + c * 36
		else:
			break
	return pos


## FUN_00422342: x y z, rx ry rz, sx sy sz. Row-vector layout, the rows are the
## images of the axes and the scale multiplies the output axes.
static func _matrix(f: PackedFloat32Array) -> Transform3D:
	var c1 := cos(f[3])
	var s1 := sin(f[3])
	var c2 := cos(f[4])
	var s2 := sin(f[4])
	var c3 := cos(f[5])
	var s3 := sin(f[5])
	var row0 := Vector3(c3 * c2 * f[6], s3 * c2 * f[7], -s2 * f[8])
	var row1 := Vector3((c3 * s2 * s1 - s3 * c1) * f[6], (c3 * c1 + s3 * s2 * s1) * f[7], c2 * s1 * f[8])
	var row2 := Vector3((s3 * s1 + c3 * s2 * c1) * f[6], (s3 * s2 * c1 - c3 * s1) * f[7], c2 * c1 * f[8])
	# Godot basis columns are the images of the axes: v' = x * row0 + y * row1 + z * row2.
	return Transform3D(Basis(row0, row1, row2), Vector3(f[0], f[1], f[2]))


func group_surface(group: PackedInt32Array, index := -1) -> Array:
	var first_vertex := group[2]
	var vertex_count := group[3]
	var first_index := group[4]
	var index_count := group[1]
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var tex := PackedVector2Array()
	var col := PackedColorArray()
	for v in range(first_vertex, first_vertex + vertex_count):
		pos.append(positions[v])
		nor.append(normals[v])
		tex.append(uvs[v])
		col.append(colors[v])
	if index >= 0 and index < group_matrix.size() and group_matrix[index] < matrices.size():
		var place := matrices[group_matrix[index]]
		if place != Transform3D.IDENTITY:
			for v in pos.size():
				pos[v] = place * pos[v]
				nor[v] = (place.basis * nor[v]).normalized()
	var idx := PackedInt32Array()
	for i in range(first_index, first_index + index_count):
		idx.append(indices[i])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nor
	arrays[Mesh.ARRAY_TEX_UV] = tex
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays
