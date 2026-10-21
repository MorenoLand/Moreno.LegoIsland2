class_name SkinnedMesh
extends RefCounted

var file: MeshFile
var materials: Array = []
var mesh := ArrayMesh.new()
var _uvs: Array = []
var _colors: Array = []
var _indices: Array = []


static func create(source: MeshFile, surface_materials: Array) -> SkinnedMesh:
	if source == null or source.bones.size() != source.positions.size():
		return null
	var skin := SkinnedMesh.new()
	skin.file = source
	skin.materials = surface_materials
	for group in source.groups:
		var arrays := source.group_surface(group)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var swapped := PackedInt32Array()
		swapped.resize(idx.size())
		for t in range(0, idx.size() - 2, 3):
			swapped[t] = idx[t]
			swapped[t + 1] = idx[t + 2]
			swapped[t + 2] = idx[t + 1]
		skin._uvs.append(arrays[Mesh.ARRAY_TEX_UV])
		skin._colors.append(arrays[Mesh.ARRAY_COLOR])
		skin._indices.append(swapped)
	return skin


func update(pose: Array) -> void:
	mesh.clear_surfaces()
	var surface := 0
	for g in file.groups.size():
		var group := file.groups[g]
		var first := group[2]
		var count := group[3]
		var pos := PackedVector3Array()
		var nor := PackedVector3Array()
		pos.resize(count)
		nor.resize(count)
		for i in count:
			var bone := file.bones[first + i]
			var p := file.positions[first + i]
			var n := file.normals[first + i]
			if bone >= 0 and bone < pose.size():
				var m: Transform3D = pose[bone]
				p = m * p
				n = m.basis * n
			pos[i] = Vector3(p.x, p.y, -p.z)
			nor[i] = Vector3(n.x, n.y, -n.z)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = pos
		arrays[Mesh.ARRAY_NORMAL] = nor
		arrays[Mesh.ARRAY_TEX_UV] = _uvs[g]
		arrays[Mesh.ARRAY_COLOR] = _colors[g]
		arrays[Mesh.ARRAY_INDEX] = _indices[g]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if surface < materials.size():
			mesh.surface_set_material(surface, materials[surface])
		surface += 1
