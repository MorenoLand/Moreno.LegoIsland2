class_name BlkFile
extends RefCounted

var offsets := PackedVector3Array()
var parents := PackedInt32Array()
var anims: Array = []

# A pose depends only on the clip and the frame, and the file never changes, so
# every frame of every clip is worked out once and then reused. Walking the whole
# skeleton every frame for every actor was most of the island's frame time.
var _poses := {}


static func parse(bytes: PackedByteArray) -> BlkFile:
	var file := BlkFile.new()
	if bytes.size() < 8 or bytes.slice(0, 4).get_string_from_ascii() != "ABLK":
		return null
	var count := bytes.decode_u32(4)
	var at := 8
	for i in count:
		if at + 8 > bytes.size():
			break
		var tag := bytes.slice(at, at + 4).get_string_from_ascii()
		var size := bytes.decode_u32(at + 4)
		var body := bytes.slice(at + 8, at + 8 + size)
		at += 8 + size
		if tag == "ASKL" and file.offsets.is_empty():
			var bones := body.decode_u32(4)
			var frames := body.decode_u32(8)
			var base := 12 + frames * (3 + 4 * bones) * 4
			file.offsets.resize(bones)
			file.parents.resize(bones)
			for k in range(1, bones):
				var rec := base + 16 * k
				if rec + 16 > body.size():
					break
				file.offsets[k] = Vector3(body.decode_float(rec), body.decode_float(rec + 4), body.decode_float(rec + 8))
				file.parents[k] = body.decode_u32(rec + 12)
		if tag == "ASKL" or tag == "ANIM":
			var count_bones := body.decode_u32(4)
			var count_frames := body.decode_u32(8)
			var floats := (12 + count_frames * (3 + 4 * count_bones) * 4)
			file.anims.append({"bones": count_bones, "frames": count_frames, "data": body.slice(12, floats).to_float32_array()})
	return file


static func _rotation(q: Vector4) -> Basis:
	var x := q.x
	var y := q.y
	var z := q.z
	var w := q.w
	var rows := [
		Vector3(1.0 - 2.0 * (y * y + z * z), 2.0 * (x * y - z * w), 2.0 * (x * z + y * w)),
		Vector3(2.0 * (x * y + z * w), 1.0 - 2.0 * (x * x + z * z), 2.0 * (y * z - x * w)),
		Vector3(2.0 * (x * z - y * w), 2.0 * (y * z + x * w), 1.0 - 2.0 * (x * x + y * y)),
	]
	var column := Basis(Vector3(rows[0].x, rows[1].x, rows[2].x), Vector3(rows[0].y, rows[1].y, rows[2].y), Vector3(rows[0].z, rows[1].z, rows[2].z))
	return column.transposed()


func pose(clip: int, frame: int) -> Array:
	var out: Array = []
	if clip < 0 or clip >= anims.size():
		return out
	var anim: Dictionary = anims[clip]
	var at := frame % maxi(anim.frames, 1)
	var cached: Variant = _poses.get(clip * 4096 + at)
	if cached != null:
		return cached
	var bones: int = anim.bones
	var stride := 3 + 4 * bones
	var data: PackedFloat32Array = anim.data
	var base := at * stride
	var root := Vector3(-data[base], data[base + 1], data[base + 2])
	var world: Array[Transform3D] = []
	for k in bones:
		var q := Vector4(data[base + 3 + 4 * k], data[base + 4 + 4 * k], data[base + 5 + 4 * k], data[base + 6 + 4 * k])
		var local := _rotation(q)
		if k == 0:
			world.append(Transform3D(local, root))
		else:
			var t := Vector3(-offsets[k].x, offsets[k].y, offsets[k].z)
			var parent: Transform3D = world[parents[k]]
			world.append(Transform3D(parent.basis * local, parent.basis * t + parent.origin))
	_poses[clip * 4096 + at] = world
	return world
