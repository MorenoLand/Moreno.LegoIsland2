class_name MeshBuilder
extends RefCounted

static var _textures := {}
static var lighting := {}
static var _white: ImageTexture
static var _lit_shader: Shader
static var _clamp_shader: Shader
static var _blend_shader: Shader
static var _anim_shader: Shader
static var _anim_materials := {}
static var animated: Array = []

const LIT_BLEND_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 light_direction;
uniform vec3 light_color;
uniform vec3 ambient_color;
varying vec3 lit;
varying float vertex_alpha;
void vertex() {
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float d = max(dot(n, light_direction), 0.0);
	lit = clamp(max(vec3(d) * light_color, ambient_color), 0.0, 1.0);
	vertex_alpha = COLOR.a;
}
void fragment() {
	vec4 t = texture(albedo_texture, UV);
	ALBEDO = t.rgb * lit;
	ALPHA = t.a * vertex_alpha;
}
"""

const ANIM_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 light_direction;
uniform vec3 light_color;
uniform vec3 ambient_color;
uniform vec2 grid = vec2(1.0, 1.0);
uniform vec2 cell = vec2(0.0, 0.0);
varying vec3 lit;
void vertex() {
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float d = max(dot(n, light_direction), 0.0);
	vec3 c = vec3(d) * light_color;
	lit = clamp(max(c, ambient_color), 0.0, 1.0);
}
void fragment() {
	vec4 t = texture(albedo_texture, (UV + cell) / grid);
	if (t.a < 0.5) {
		discard;
	}
	ALBEDO = t.rgb * lit;
}
"""

const LIT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 light_direction;
uniform vec3 light_color;
uniform vec3 ambient_color;
uniform vec2 uv_offset = vec2(0.0);
varying vec3 lit;
void vertex() {
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float d = max(dot(n, light_direction), 0.0);
	vec3 c = vec3(d) * light_color;
	lit = clamp(max(c, ambient_color), 0.0, 1.0);
}
void fragment() {
	vec4 t = texture(albedo_texture, UV + uv_offset);
	if (t.a < 0.5) {
		discard;
	}
	ALBEDO = t.rgb * lit;
}
"""


static func flip(v: Vector3) -> Vector3:
	return Vector3(v.x, v.y, -v.z)


static func build(zone: String, name: String, first_texture: int, unshaded := true, ids := PackedInt32Array(), lit := false) -> MeshInstance3D:
	var file := MeshFile.parse(Data.read("_data/%s/meshes/%s.msh" % [zone, name]))
	if file == null:
		return null
	var mesh := ArrayMesh.new()
	var surface := 0
	for i in file.groups.size():
		var arrays := file.group_surface(file.groups[i], i)
		var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if pos.is_empty():
			continue
		var nor: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for v in pos.size():
			pos[v] = flip(pos[v])
			nor[v] = flip(nor[v])
		arrays[Mesh.ARRAY_VERTEX] = pos
		arrays[Mesh.ARRAY_NORMAL] = nor
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var swapped := PackedInt32Array()
		swapped.resize(idx.size())
		for t in range(0, idx.size() - 2, 3):
			swapped[t] = idx[t]
			swapped[t + 1] = idx[t + 2]
			swapped[t + 2] = idx[t + 1]
		arrays[Mesh.ARRAY_INDEX] = swapped
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var texture_id: int = ids[i] if i < ids.size() else first_texture + i
		var atlas := _uses_atlas(arrays[Mesh.ARRAY_TEX_UV])
		if lit and not lighting.is_empty() and not atlas:
			var moving := _animated_material(zone, texture_id)
			if moving != null:
				mesh.surface_set_material(surface, moving)
				surface += 1
				continue
		if lit and not lighting.is_empty():
			var picked: ImageTexture = texture_atlas(zone, texture_id) if atlas else texture(zone, texture_id)
			var glass: bool = (int(file.groups[i][0]) & 2) != 0 and not atlas
			var made := lit_blend_material(picked) if glass else _lit_material(picked)
			if atlas:
				made.set_meta("face", true)  # expression frames: see Island.set_face
			if not atlas and not glass and _is_decal(arrays[Mesh.ARRAY_TEX_UV], picked):
				made.shader = _clamping_shader()
			mesh.surface_set_material(surface, made)
			surface += 1
			continue
		if not atlas:
			var flowing := _animated_standard(zone, texture_id, unshaded)
			if flowing != null:
				mesh.surface_set_material(surface, flowing)
				surface += 1
				continue
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_VERTEX
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.texture_repeat = true
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if (int(file.groups[i][0]) & 2) != 0 else BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		var tex := texture_atlas(zone, texture_id) if atlas else texture(zone, texture_id)
		if tex != null:
			mat.albedo_texture = tex
		mesh.surface_set_material(surface, mat)
		surface += 1
	var instance := MeshInstance3D.new()
	# Name it after the mesh it came from. Without this every built node is
	# "@MeshInstance3D@N", which makes scenery impossible to find from a test or
	# the remote scene tree. Godot suffixes duplicates on its own.
	instance.name = name
	instance.mesh = mesh
	return instance


static func load_lighting(zone: String) -> void:
	lighting = {}
	var bytes := Data.read("_data/%s/lights/lights.lgt" % zone)
	if bytes.size() < 8 + 88:
		return
	var at := 8
	var kind := bytes.decode_u32(at)
	var direction := Vector3(bytes.decode_float(at + 28), bytes.decode_float(at + 32), bytes.decode_float(at + 36))
	if kind == 2:
		direction.y = absf(direction.y)
	if direction.length() < 0.001:
		return
	lighting = {
		"direction": Vector3(direction.x, direction.y, -direction.z).normalized(),
		"color": Vector3(bytes.decode_float(at + 56), bytes.decode_float(at + 60), bytes.decode_float(at + 64)),
		"ambient": Vector3(bytes.decode_float(at + 40), bytes.decode_float(at + 44), bytes.decode_float(at + 48)),
	}


static func lit_blend_material(tex: ImageTexture) -> ShaderMaterial:
	if _blend_shader == null:
		_blend_shader = Shader.new()
		_blend_shader.code = LIT_BLEND_SHADER
	var material := _lit_material(tex)
	material.shader = _blend_shader
	return material


## A small quad whose UVs start below 0 on BOTH axes is a decal centred on the quad (the
## Information Centre's "i" sign, the hospital cross, shop signs): sampled with
## clamping it shows once on its own background, where repeating draws the sign
## again across the wall. Tiling strips start at 0 and are left alone.
static func _is_decal(uvs: PackedVector2Array, tex: ImageTexture) -> bool:
	if tex == null or uvs.is_empty() or uvs.size() > 8:
		return false
	var low := Vector2(9, 9)
	for uv in uvs:
		low = low.min(uv)
	return low.x < -0.01 and low.y < -0.01


static func _clamping_shader() -> Shader:
	if _clamp_shader == null:
		_clamp_shader = Shader.new()
		_clamp_shader.code = LIT_SHADER.replace("repeat_enable", "repeat_disable")
	return _clamp_shader


static func _uses_atlas(uvs: PackedVector2Array) -> bool:
	if uvs.is_empty():
		return false
	var low := Vector2(9, 9)
	var high := Vector2(-9, -9)
	for uv in uvs:
		low = Vector2(minf(low.x, uv.x), minf(low.y, uv.y))
		high = Vector2(maxf(high.x, uv.x), maxf(high.y, uv.y))
	return high.x - low.x <= 0.26 and high.y - low.y <= 0.26 and high.x <= 1.001 and high.y <= 1.001


static func texture_atlas(zone: String, index: int) -> ImageTexture:
	var base := "_data/%s/textures/text%03d" % [zone, index]
	var key := base + "#atlas"
	if _textures.has(key):
		return _textures[key]
	var result: ImageTexture = texture(zone, index)
	var bytes := Data.read(base + ".wib")
	if bytes.size() >= 24:
		var n := bytes.decode_u32(4)
		var at := 8 + n * 4 + 4
		var w := bytes.decode_u32(at)
		var h := bytes.decode_u32(at + 4)
		var bpp := 3 if bytes.decode_u32(at + 8) == 0 else 4
		var frames := bytes.decode_u32(at + 12)
		if frames > 1 and w > 0 and h > 0 and bytes.size() >= at + 16 + frames * w * h * bpp:
			var cols := int(ceil(sqrt(float(frames))))
			var rows := int(ceil(float(frames) / cols))
			var atlas := Image.create(w * cols, h * rows, false, Image.FORMAT_RGBA8)
			for f in frames:
				var pix := bytes.slice(at + 16 + f * w * h * bpp, at + 16 + (f + 1) * w * h * bpp)
				var rgba := PackedByteArray()
				rgba.resize(w * h * 4)
				for p in w * h:
					rgba[p * 4] = pix[p * bpp + 2]
					rgba[p * 4 + 1] = pix[p * bpp + 1]
					rgba[p * 4 + 2] = pix[p * bpp]
					rgba[p * 4 + 3] = pix[p * bpp + 3] if bpp == 4 else 255
				var frame := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba)
				atlas.blit_rect(frame, Rect2i(0, 0, w, h), Vector2i((f % cols) * w, (rows - 1 - f / cols) * h))
			result = ImageTexture.create_from_image(atlas)
	_textures[key] = result
	return result


static func timeline(zone: String, index: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var bytes := Data.read("_data/%s/textures/text%03d.wib" % [zone, index])
	if bytes.size() < 24:
		return out
	var n := bytes.decode_u32(4)
	var at := 8 + n * 4 + 4
	if n < 2 or bytes.size() < at + 16 or bytes.decode_u32(at + 12) < 2:
		return out
	for k in n:
		out.append(bytes.decode_s32(8 + k * 4))
	return out


static func _animated_material(zone: String, index: int) -> ShaderMaterial:
	var key := "%s:%d" % [zone, index]
	if _anim_materials.has(key):
		return _anim_materials[key]
	var result: ShaderMaterial = null
	var table := timeline(zone, index)
	if not table.is_empty():
		var bytes := Data.read("_data/%s/textures/text%03d.wib" % [zone, index])
		var n := bytes.decode_u32(4)
		var at := 8 + n * 4 + 4
		var frames := int(bytes.decode_u32(at + 12))
		var cols := int(ceil(sqrt(float(frames))))
		var rows := int(ceil(float(frames) / cols))
		if _anim_shader == null:
			_anim_shader = Shader.new()
			_anim_shader.code = ANIM_SHADER
		result = ShaderMaterial.new()
		result.shader = _anim_shader
		result.set_shader_parameter("albedo_texture", texture_atlas(zone, index))
		result.set_shader_parameter("light_direction", lighting.direction)
		result.set_shader_parameter("light_color", lighting.color)
		result.set_shader_parameter("ambient_color", lighting.ambient)
		result.set_shader_parameter("grid", Vector2(cols, rows))
		animated.append({"material": result, "table": table, "cols": cols, "rows": rows})
	_anim_materials[key] = result
	return result


static func _animated_standard(zone: String, index: int, unshaded: bool) -> StandardMaterial3D:
	var key := "std:%s:%d:%s" % [zone, index, unshaded]
	if _anim_materials.has(key):
		return _anim_materials[key]
	var result: StandardMaterial3D = null
	var table := timeline(zone, index)
	if not table.is_empty():
		var bytes := Data.read("_data/%s/textures/text%03d.wib" % [zone, index])
		var n := bytes.decode_u32(4)
		var at := 8 + n * 4 + 4
		var frames := int(bytes.decode_u32(at + 12))
		var cols := int(ceil(sqrt(float(frames))))
		var rows := int(ceil(float(frames) / cols))
		result = StandardMaterial3D.new()
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_VERTEX
		result.cull_mode = BaseMaterial3D.CULL_DISABLED
		result.texture_repeat = true
		result.vertex_color_use_as_albedo = true
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		result.albedo_texture = texture_atlas(zone, index)
		result.uv1_scale = Vector3(1.0 / cols, 1.0 / rows, 1.0)
		animated.append({"material": result, "table": table, "cols": cols, "rows": rows})
	_anim_materials[key] = result
	return result


static func step_animated(tick: int) -> void:
	for item in animated:
		var table: PackedInt32Array = item.table
		var frame: int = table[tick % table.size()]
		var cols: int = item.cols
		var rows: int = item.rows
		var column := frame % cols
		var row := rows - 1 - frame / cols
		var material: Material = item.material
		if material is ShaderMaterial:
			(material as ShaderMaterial).set_shader_parameter("cell", Vector2(column, row))
		elif material is StandardMaterial3D:
			(material as StandardMaterial3D).uv1_offset = Vector3(float(column) / cols, float(row) / rows, 0.0)


static func _lit_material(tex: ImageTexture) -> ShaderMaterial:
	if _lit_shader == null:
		_lit_shader = Shader.new()
		_lit_shader.code = LIT_SHADER
	if _white == null:
		var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(image)
	var material := ShaderMaterial.new()
	material.shader = _lit_shader
	material.set_shader_parameter("albedo_texture", tex if tex != null else _white)
	material.set_shader_parameter("light_direction", lighting.direction)
	material.set_shader_parameter("light_color", lighting.color)
	material.set_shader_parameter("ambient_color", lighting.ambient)
	return material


static func texture(zone: String, index: int) -> ImageTexture:
	var base := "_data/%s/textures/text%03d" % [zone, index]
	if _textures.has(base):
		return _textures[base]
	var result: ImageTexture = null
	var image := Image.new()
	var bytes := Data.read(base + ".tga")
	if bytes.size() > 18 and image.load_tga_from_buffer(bytes) == OK:
		image.flip_y()
		image.generate_mipmaps()
		result = ImageTexture.create_from_image(image)
	else:
		bytes = Data.read(base + ".wib")
		if bytes.size() >= 24:
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
			var wib := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba)
			wib.generate_mipmaps()
			result = ImageTexture.create_from_image(wib)
	_textures[base] = result
	return result
