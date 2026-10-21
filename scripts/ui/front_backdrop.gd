class_name FrontBackdrop
extends Node3D

const ZONE := "z60FRE"
const CAMERA_POSITION := Vector3(0, 11.0, 56.8)
const CAMERA_TARGET := Vector3(0, 11.0, 0)
const FOV_RADIANS := 1.0
const NEAR := 4.0
const FAR := 1500.0


func _ready() -> void:
	MeshBuilder.load_lighting(ZONE)
	lit_scene = not MeshBuilder.lighting.is_empty()
	var camera := Camera3D.new()
	camera.fov = rad_to_deg(FOV_RADIANS)
	camera.near = NEAR
	camera.far = FAR
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(camera)
	camera.look_at_from_position(_flip(CAMERA_POSITION), _flip(CAMERA_TARGET))
	camera.current = true
	_load_runs()
	_add_mesh("pPlane1", Vector3(-7.478, 13.8, -2.77), 1.2, 1)
	_add_mesh("pPlane2", Vector3(-6.78, 13.8, 11.39), 0.975, 2)
	_add_mesh("group1", Vector3(64.0, 34.4, -4.0), 0.4, 22, -0.5236)
	_add_butterflies()


const TRAIN_FIRST_WAIT := 300
const TRAIN_CROSS := 180
const TRAIN_WAIT := 750
const UPDATE_RATE := 30.0
const BUTTERFLY_FIRST := 35
const BUTTERFLY_SIGHT := 8.0
const STILL_FIRST := 23

var train: MeshInstance3D
var lit_scene := false
var runs := {}
var run_for := {}
var train_frames := 0.0
var train_crossing := false
var train_z := -4.0
var train_timer := float(TRAIN_FIRST_WAIT)
var butterflies: Array = []


func _process(delta: float) -> void:
	for fly in butterflies:
		fly.update(delta)
	if train == null:
		return
	train.visible = train_crossing
	train_timer -= delta * UPDATE_RATE
	if train_timer <= 0.0:
		train_crossing = not train_crossing
		train_timer = float(TRAIN_CROSS if train_crossing else TRAIN_WAIT)
	if train_crossing:
		var x := (8.0 - train_timer * 16.0 / 180.0) * 8.0
		train.position = _flip(Vector3(x, 34.4, train_z))


func _add_butterflies() -> void:
	var file := FileAccess.open("res://data/front_placement.tsv", FileAccess.READ)
	if file == null:
		return
	file.get_line()
	while not file.eof_reached():
		var parts := file.get_line().split("	")
		if parts.size() < 8:
			continue
		var record := int(parts[0])
		if record < STILL_FIRST or record > BUTTERFLY_FIRST + 6:
			continue
		var slot := record - 22
		var name := "Butterfly%d" % (BUTTERFLY_FIRST + 6 - record)
		var start := Vector3(float(parts[5]), float(parts[6]), float(parts[7]))
		if record < BUTTERFLY_FIRST:
			_add_mesh(name, start, 1.0, slot)
			continue
		var instance := _add_mesh(name, start, 1.0, slot)
		if instance == null:
			continue
		var fly := Butterfly.new()
		fly.node = instance
		fly.setup(BUTTERFLY_SIGHT, start, float(parts[3]))
		butterflies.append(fly)


func _flip(v: Vector3) -> Vector3:
	return Vector3(v.x, v.y, -v.z)


func _add_mesh(name: String, position: Vector3, scale: float, run: int, tilt := 0.0) -> MeshInstance3D:
	var file := MeshFile.parse(Data.read("_data/%s/meshes/%s.msh" % [ZONE, name]))
	if file == null:
		return null
	var ids: PackedInt32Array = runs.get(run_for.get(name, run), PackedInt32Array())
	var mesh := ArrayMesh.new()
	for i in file.groups.size():
		var arrays := file.group_surface(file.groups[i])
		var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var nor: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for v in pos.size():
			pos[v] = _flip(pos[v])
			nor[v] = _flip(nor[v])
		arrays[Mesh.ARRAY_VERTEX] = pos
		arrays[Mesh.ARRAY_NORMAL] = nor
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var flipped := PackedInt32Array()
		flipped.resize(idx.size())
		for t in range(0, idx.size() - 2, 3):
			flipped[t] = idx[t]
			flipped[t + 1] = idx[t + 2]
			flipped[t + 2] = idx[t + 1]
		arrays[Mesh.ARRAY_INDEX] = flipped
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if lit_scene and name != "pPlane1" and name != "pPlane2":
			mesh.surface_set_material(i, MeshBuilder.lit_blend_material(_texture(ids[i] if i < ids.size() else i)))
			continue
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.texture_repeat = true
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if name == "pPlane1":
			mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			mat.render_priority = -10
		elif name == "pPlane2":
			mat.render_priority = 10
		var tex := _texture(ids[i] if i < ids.size() else i)
		if tex != null:
			mat.albedo_texture = tex
		mesh.surface_set_material(i, mat)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = _flip(position)
	instance.scale = Vector3.ONE * scale
	instance.rotation.x = tilt
	add_child(instance)
	if name == "group1":
		train = instance
		var smoke := SmokeEmitter.new()
		smoke.position = Vector3(7.25, 10.0, 0.0)
		instance.add_child(smoke)
	return instance


func _texture(index: int) -> ImageTexture:
	var base := "_data/%s/textures/text%03d" % [ZONE, index]
	var image := Image.new()
	var bytes := Data.read(base + ".tga")
	if bytes.size() > 18 and image.load_tga_from_buffer(bytes) == OK:
		image.flip_y()
		return ImageTexture.create_from_image(image)
	bytes = Data.read(base + ".wib")
	if bytes.size() < 24:
		return null
	var n := bytes.decode_u32(4)
	var at := 8 + n * 4 + 4
	var w := bytes.decode_u32(at)
	var h := bytes.decode_u32(at + 4)
	var bpp := 3 if bytes.decode_u32(at + 8) == 0 else 4
	var pix := bytes.slice(at + 16, at + 16 + w * h * bpp)
	var rgba := PackedByteArray()
	rgba.resize(w * h * 4)
	for p in w * h:
		rgba[p * 4] = pix[p * bpp + 2]
		rgba[p * 4 + 1] = pix[p * bpp + 1]
		rgba[p * 4 + 2] = pix[p * bpp]
		rgba[p * 4 + 3] = pix[p * bpp + 3] if bpp == 4 else 255
	return ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba))


func _load_runs() -> void:
	var file := FileAccess.open("res://data/front_texsets.tsv", FileAccess.READ)
	if file != null:
		file.get_line()
		while not file.eof_reached():
			var parts := file.get_line().split("	")
			if parts.size() >= 3:
				var ids := PackedInt32Array()
				for id in String(parts[2]).split(" ", false):
					ids.append(int(id))
				runs[int(parts[0])] = ids
	file = FileAccess.open("res://data/front_models.tsv", FileAccess.READ)
	if file != null:
		file.get_line()
		while not file.eof_reached():
			var parts := file.get_line().split("	")
			if parts.size() >= 4:
				run_for[String(parts[2]).get_basename()] = int(parts[3])
