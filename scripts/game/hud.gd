class_name Hud
extends Control

const DESIGN := Vector2(800, 600)
const LEFT_ICON := Rect2(20, 20, 60, 60)
const RIGHT_ICON := Rect2(716, 20, 60, 60)
const PROMPT_ICON := Rect2(20, 516, 60, 60)
const EARLY_STATE := 7

var overlay_folder := "_data/Overlays/Z02LGI/text%03d.tga"
var corners := true
var left: ImageTexture
var right: ImageTexture
var prompt_textures := {}
var prompt := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if corners:
		var early := Game.get_var(Game.VAR_STATE) < EARLY_STATE
		left = _load(2 if early else 0)
		right = _load(7 if early else 1)


func set_prompt(index: int) -> void:
	if index == prompt:
		return
	prompt = index
	queue_redraw()


func _load(index: int) -> ImageTexture:
	if prompt_textures.has(index):
		return prompt_textures[index]
	var image := Image.new()
	var bytes := Data.read(overlay_folder % index)
	var texture: ImageTexture = null
	if bytes.size() > 18 and image.load_tga_from_buffer(bytes) == OK:
		texture = ImageTexture.create_from_image(image)
	prompt_textures[index] = texture
	return texture


func _draw() -> void:
	var scale := size / DESIGN
	var items := []
	if corners:
		items.append([left, LEFT_ICON])
		items.append([right, RIGHT_ICON])
	if prompt >= 0:
		items.append([_load(prompt), PROMPT_ICON])
	for pair in items:
		var texture: ImageTexture = pair[0]
		var box: Rect2 = pair[1]
		if texture != null:
			draw_texture_rect(texture, Rect2(box.position * scale, box.size * scale), false)
