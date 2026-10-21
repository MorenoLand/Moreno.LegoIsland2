class_name GameFont
extends RefCounted

const DESIGN := Vector2(640, 480)

var texture: ImageTexture
var line_height := 0
var count := 0
var cmap := PackedByteArray()
var glyphs := []
var kern := PackedByteArray()


static func load_font(path: String) -> GameFont:
	var data := Data.read(path + ".fnt")
	if data.size() < 276:
		return null
	var f := GameFont.new()
	f.line_height = data.decode_u32(8)
	f.count = data.decode_u32(12)
	f.cmap = data.slice(20, 276)
	for i in f.count:
		var at := 276 + i * 32
		f.glyphs.append([data.decode_float(at), data.decode_float(at + 4), data.decode_float(at + 8), data.decode_float(at + 12), data.decode_s32(at + 16), data.decode_s32(at + 20), data.decode_s32(at + 24), data.decode_s32(at + 28)])
	var kern_at := 276 + f.count * 32
	f.kern = data.slice(kern_at, kern_at + f.count * f.count)
	var image := Image.new()
	if image.load_tga_from_buffer(Data.read(path + ".tga")) != OK:
		return null
	f.texture = ImageTexture.create_from_image(image)
	return f


static func scale_for(screen: Vector2) -> Vector2:
	return Vector2(screen.x / DESIGN.x, screen.y / DESIGN.y)


func _fold(c: int) -> int:
	return c - 0x20 if c >= 0xE0 else c


func _bytes(text: String) -> PackedByteArray:
	var out := PackedByteArray()
	for i in text.length():
		out.append(text.unicode_at(i) & 0xFF)
	return out


func advance(a: int, b: int, scale_x: float) -> float:
	return kern[cmap[_fold(a)] * count + cmap[_fold(b)]] * scale_x


func measure(text: String, scale: Vector2) -> Vector2i:
	var bytes := _bytes(text)
	var width := 0
	for i in bytes.size():
		var next := bytes[i + 1] if i + 1 < bytes.size() else 0
		width = int(advance(bytes[i], next, scale.x) + width)
	return Vector2i(width, int(line_height * scale.y))


func draw(item: CanvasItem, text: String, x: int, y: int, scale: Vector2, color: Color, shift := Vector2.ZERO) -> void:
	var bytes := _bytes(text)
	var tex_size := texture.get_size()
	var cx := x
	for i in bytes.size():
		var c := _fold(bytes[i])
		var g: Array = glyphs[cmap[c]]
		var left: float = cx + g[6] * scale.x + shift.x
		var top: float = y + (g[7] - line_height) * scale.y + shift.y
		var src := Rect2(g[0] * tex_size.x, g[1] * tex_size.y, (g[2] - g[0]) * tex_size.x, (g[3] - g[1]) * tex_size.y)
		item.draw_texture_rect_region(texture, Rect2(left, top, g[4] * scale.x, g[5] * scale.y), src, color)
		var next := bytes[i + 1] if i + 1 < bytes.size() else 0
		cx = int(advance(c, next, scale.x) + cx)
