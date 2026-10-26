class_name ParkScreen
extends Control

## What the park draws over the 3D view: the framed message panel of FUN_00444756 (shared by every
## game of the exe, here with its text lines), the clock, the score and the points of the trick of
## FUN_00445ECF, the name of the trick of FUN_007E6A8D, and the fade of FUN_00425C20.
##
## The panel and the messages are laid out on 640 x 480 (24 pixel tiles), the HUD texts on 800 x 600,
## both inside the rectangle the display setting gives.

const SPACE := Vector2(640, 480)
const HUD_SPACE := Vector2(800, 600)
const TILE := 24
const TILE_PATH := "_data/menu/mOverlays/text%03d.tga"
## FUN_00444756 with 0x16 and 0x14: the panel is 26 tiles wide and 20 rows tall.
const FRAME_HALF := 11
const FRAME_ROWS := 20
const TILE_FILL := 0
const TILE_TOP := 3
const TILE_BOTTOM := 6
const TILE_LEFT := 9
const TILE_RIGHT := 0xC
const TILE_TOP_LEFT := 0xF
const TILE_TOP_RIGHT := 0x12
const TILE_BOTTOM_LEFT := 0x15
const TILE_BOTTOM_RIGHT := 0x18
const PRESS_ROW := 18
const PRESS_Y_OFFSET := -4
const FONT_BIG := "_data/fonts/Balloon24"
const FONT_SMALL := "_data/fonts/Balloon12"
const YELLOW := Color(1, 1, 0, 1)
const WHITE := Color(1, 1, 1, 1)
const SHADOW := Color(0, 0, 0, 1)
const SHADOW_SHIFT := Vector2(2, 2)
## FUN_004456B5: the score on the left from x 100, the clock centred on x 400, both at y 69.
const HUD_LEFT := 100.0
const HUD_CENTRE := 400.0
const HUD_Y := 69.0
## FUN_00445973: the line above the points of the trick (y 494) and the points (y 518), centred.
const HUD_LINE_Y := 494.0
const HUD_TRICK_Y := 518.0
const TRICK_X := 325
const TRICK_Y := 450
const TRICK_WRAP := 30
const LINE_SHRINK := 8

var services: ActorServices
var panel := false
var panel_lines: Array = []
var trick_text := ""
var brightness := 1.0
var tiles := {}
var font_big: GameFont
var font_small: GameFont
var press_text := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font_big = GameFont.load_font(FONT_BIG)
	font_small = GameFont.load_font(FONT_SMALL)
	var lines := services.load_lines("_data/messages/FE/English/PAUSE.str")
	if lines.has("PRESS"):
		press_text = String(lines["PRESS"][1])


func _tile_texture(index: int) -> ImageTexture:
	if not tiles.has(index):
		var image := Image.new()
		var bytes := Data.read(TILE_PATH % index)
		tiles[index] = ImageTexture.create_from_image(image) if bytes.size() > 18 and image.load_tga_from_buffer(bytes) == OK else null
	return tiles[index]


## FUN_00444410: one tile at a column (0 is the middle of the screen) and a row.
func _tile(index: int, column: int, row: int) -> void:
	var texture := _tile_texture(index)
	if texture != null:
		draw_texture_rect(texture, Rect2(column * TILE + 320, TILE + (row - 1) * TILE, TILE, TILE), false)


func _draw_panel() -> void:
	_tile(TILE_TOP_LEFT, -2 - FRAME_HALF, 0)
	for column in range(-1 - FRAME_HALF, FRAME_HALF + 1):
		_tile(TILE_TOP, column, 0)
	_tile(TILE_TOP_RIGHT, FRAME_HALF + 1, 0)
	for row in range(1, FRAME_ROWS - 1):
		_tile(TILE_LEFT, -2 - FRAME_HALF, row)
		for column in range(-1 - FRAME_HALF, FRAME_HALF + 1):
			_tile(TILE_FILL, column, row)
		_tile(TILE_RIGHT, FRAME_HALF + 1, row)
	_tile(TILE_BOTTOM_LEFT, -2 - FRAME_HALF, FRAME_ROWS - 1)
	for column in range(-1 - FRAME_HALF, FRAME_HALF + 1):
		_tile(TILE_BOTTOM, column, FRAME_ROWS - 1)
	_tile(TILE_BOTTOM_RIGHT, FRAME_HALF + 1, FRAME_ROWS - 1)
	_centred(font_small, press_text, 320, TILE + PRESS_ROW * TILE + PRESS_Y_OFFSET, WHITE)


func _centred(font: GameFont, text: String, x: int, y: int, color: Color) -> void:
	if font == null or text == "":
		return
	var left := x - int(font.measure(text, Vector2.ONE).x / 2.0)
	font.draw(self, text, left, y, Vector2.ONE, SHADOW, SHADOW_SHIFT)
	font.draw(self, text, left, y, Vector2.ONE, color)


## FUN_00421CC4: a message at a place on 640 x 480, broken at a space when it is longer than `wrap`
## characters; each further line is a line of the font less 8 lower.
func message(text: String, x: int, y: int, wrap: int, font: GameFont) -> void:
	var line := 0
	var rest := text
	while true:
		var shown := rest
		var more := false
		if rest.length() > wrap:
			var cut := wrap
			while cut > 0 and rest[cut] != " ":
				cut -= 1
			shown = rest.substr(0, cut)
			rest = rest.substr(cut + 1)
			more = true
		_centred(font, shown, x, y + line * (font.line_height - LINE_SHRINK), YELLOW)
		line += 1
		if not more:
			break


func _draw() -> void:
	if font_big == null or services == null:
		return
	var rect := Display.ui_rect(size)
	draw_set_transform(rect.position, 0.0, rect.size / SPACE)
	if panel:
		_draw_panel()
		for entry in panel_lines:
			message(String(entry[0]), int(entry[1]), int(entry[2]), int(entry[3]), font_big)
	if trick_text != "":
		message(trick_text, TRICK_X, TRICK_Y, TRICK_WRAP, font_big)
	var g := services.talk
	if g.park_hud:
		draw_set_transform(rect.position, 0.0, rect.size / HUD_SPACE)
		_hud_text(font_big, g.park_score_text, int(HUD_LEFT), int(HUD_Y), false)
		_hud_text(font_big, g.park_clock_text, int(HUD_CENTRE), int(HUD_Y), true)
		_hud_text(font_small, g.park_line_text, int(HUD_CENTRE), int(HUD_LINE_Y), true)
		_hud_text(font_small, g.park_trick_text, int(HUD_CENTRE), int(HUD_TRICK_Y), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if brightness < 1.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 1.0 - brightness))


## The HUD texts are drawn at the glyph scale of the window over 640 x 480, as the other zones' counters.
func _hud_text(font: GameFont, text: String, x: int, y: int, centred: bool) -> void:
	if font == null or text == "":
		return
	var glyphs := Vector2(HUD_SPACE.x / SPACE.x, HUD_SPACE.y / SPACE.y)
	var left := x - (int(font.measure(text, glyphs).x / 2.0) if centred else 0)
	font.draw(self, text, left, y, glyphs, SHADOW, SHADOW_SHIFT)
	font.draw(self, text, left, y, glyphs, YELLOW)
