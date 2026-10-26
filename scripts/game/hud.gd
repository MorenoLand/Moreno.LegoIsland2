class_name Hud
extends Control

## The overlay HUD of FUN_00445ECF: corner icons, two columns of icons, a gauge of twelve pieces, three
## counters, with each zone's own set-up and per-tick update filling in what it shows. The geometry is
## read off the disassembly (the decompiler hides the __ftol calls): everything is laid out on an 800 x 600
## design and scaled to the window; the counters use Balloon24 at the window / 640 x 480 glyph scale.

const DESIGN := Vector2(800, 600)
const LEFT_ICON := Rect2(20, 20, 60, 60)
const RIGHT_ICON := Rect2(716, 20, 60, 60)
const EARLY_STATE := 7
## FUN_00450310: the corner icons and the bot column exist before this story state.
const LAST_STATE := 0x3D
## FUN_00445589: the left column at x 20 and the right one at x 716, entry k at y 516 - 72 k, 60 x 60.
const COLUMN_LEFT_X := 20.0
const COLUMN_RIGHT_X := 716.0
const COLUMN_Y := 516.0
const COLUMN_STEP := 72.0
## FUN_00445B84: twelve 32 x 16 pieces stacked from y 492 upwards at x 732, a 32 x 32 marker at x 696 that
## rides the level (y centre 508 - 192 f) and a 60 x 60 icon at (716, 516).
const GAUGE_X := 732.0
const GAUGE_MARKER_X := 696.0
const GAUGE_ICON_X := 716.0
const GAUGE_PIECES := 12
const GAUGE_BOTTOM := 492.0
const GAUGE_PIECE := Vector2(32, 16)
const GAUGE_RANGE := 192.0
const GAUGE_BASE := 508.0
const GAUGE_ICON_Y := 516.0
## FUN_004456B5: the counters at y 69 (left from x 100, right ending at x 699, centred on x 400).
const TEXT_LEFT := 100.0
const TEXT_RIGHT := 699.0
const TEXT_CENTRE := 400.0
const TEXT_Y := 69.0
const SHADOW_OFFSET := 2.0
## Colour table entries 0 (yellow) and 8 (black) of FUN_0040ED70.
const TEXT_COLOR := Color(1, 1, 0, 1)
const SHADOW_COLOR := Color(0, 0, 0, 1)
const WHITE := 0xFFFFFFFF
const DIM := 0xFF888888
const FONT_PATH := "_data/fonts/Balloon24"
const HINT_BLINK := 15.0
const HINT_CYCLE := 30.0
const BOT_COUNT_FIRST := 4
const BOT_COUNT_PARK := 2
const PIZZA_TOTAL := 11
const ZONE_VAR := 0x59
const PARK_ZONE_ID := 0x20
## The icons of the control hint column (entry 0): the island has them at 0xC..0x10, the castle at 1..5.
const ISLAND_HINTS := [0xC, 0xD, 0xE, 0xF, 0x10]
const CASTLE_HINTS := [1, 2, 3, 4, 5]
## FUN_0051FF9A: the dive's tints (dark glass for the empty column and the corner, cyan for the gauge).
const DIVE_DARK := 0x77333333
const DIVE_CYAN := 0xFF77FFFF
const DIVE_FULL := 100.0

var overlay_folder := "_data/Overlays/Z02LGI/text%03d.tga"
var corners := true
## "island", "castle", "dive" or "" (the house keeps only its prompt).
var kind := ""
var left_icon := [-1, WHITE]
var right_icon := [-1, WHITE]
var column_left: Array = []
var column_right: Array = []
var column_left_on := false
var column_right_on := false
var gauge_on := false
var gauge_top := [-1, WHITE]
var gauge_stack: Array = []
var gauge_marker := [-1, WHITE]
var gauge_max := 0.0
var gauge_min := 0.0
var gauge_value := 0.0
var texts: Array = ["", "", ""]
var hint_clock := 0.0
var prompt_textures := {}
var font: GameFont


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in 5:
		column_left.append([-1, WHITE])
		column_right.append([-1, WHITE])
	for k in GAUGE_PIECES:
		gauge_stack.append([-1, WHITE])
	font = GameFont.load_font(FONT_PATH)
	column_left_on = true
	match kind:
		"island":
			_island_init()
		"castle":
			_castle_init()
		"dive":
			_dive_init()


## FUN_00450310.
func _island_init() -> void:
	var state := Game.get_var(Game.VAR_STATE)
	var early := state < EARLY_STATE
	if state < LAST_STATE:
		left_icon = [2 if early else 0, WHITE]
		right_icon = [7 if early else 1, WHITE]
		if not early:
			for k in 4:
				column_left[k + 1][0] = 3 + k


## FUN_004DBB00: the castle shows the first icon in the left corner.
func _castle_init() -> void:
	left_icon = [0, WHITE]


## FUN_0051FF9A.
func _dive_init() -> void:
	column_right_on = false
	for k in 5:
		column_left[k] = [4, DIVE_DARK]
	gauge_on = true
	gauge_top = [1, DIVE_CYAN]
	gauge_max = DIVE_FULL
	gauge_min = 0.0
	gauge_value = DIVE_FULL
	for k in GAUGE_PIECES:
		gauge_stack[k] = [2, DIVE_CYAN]
	left_icon = [5, DIVE_DARK]


## The control hint of FUN_004504AD / FUN_004DBB50: the prompt bits (var 0xC, which is cleared here)
## pick the icon of entry 0; `hints` holds the icons for [vehicle, talk, door, blink a, blink b].
func _hint_tick(hints: Array, walking_only: bool) -> void:
	var prompts := Game.get_var(0xC)
	var walking := (Game.get_var(0x5E) & 1) != 0
	if (prompts & 0x20) != 0:
		if walking or not walking_only:
			column_left[0][0] = hints[2]
	elif (prompts & 1) != 0:
		if walking or not walking_only:
			column_left[0][0] = hints[1]
	elif (prompts & 0x1E) != 0:
		if walking or not walking_only:
			column_left[0][0] = hints[0]
	elif (prompts & 0xC0) != 0:
		hint_clock += 1.0
		if hint_clock < HINT_BLINK:
			column_left[0][0] = hints[3]
		else:
			column_left[0][0] = hints[4]
			if hint_clock > HINT_CYCLE:
				hint_clock = 0.0
	else:
		column_left[0][0] = -1
		hint_clock = 0.0
	Game.set_var(0xC, 0)


## The per-tick update of the zone's HUD (the island's FUN_004504AD, the castle's FUN_004DBB50).
func tick() -> void:
	match kind:
		"island":
			_island_tick()
		"castle":
			_castle_tick()
	queue_redraw()


func _island_tick() -> void:
	var state := Game.get_var(Game.VAR_STATE)
	var zone := Game.get_var(ZONE_VAR)
	texts[2] = "%04d" % Game.get_var(0x12)
	_hint_tick(ISLAND_HINTS, true)
	if state < LAST_STATE:
		# FUN_00450428: the pizza and brick totals (one more at state 6) and the bot total.
		var first_total := PIZZA_TOTAL + 1 if state == 6 else PIZZA_TOTAL
		var bots := BOT_COUNT_PARK if zone == PARK_ZONE_ID else BOT_COUNT_FIRST
		if state < EARLY_STATE:
			texts[0] = "%d/%d" % [PIZZA_TOTAL - Game.get_var(0xB0), first_total]
			texts[1] = "%d/%d" % [PIZZA_TOTAL - Game.get_var(0x4F), PIZZA_TOTAL]
		else:
			texts[0] = "%d" % Game.get_var(0x52)
			texts[1] = "%d/%d" % [Game.get_var(0xA5), bots]
			var defeated := Game.get_var(0x8E)
			if defeated < 0xF and zone != PARK_ZONE_ID:
				for k in 4:
					column_left[k + 1][1] = WHITE if (defeated & (1 << k)) != 0 else DIM
			else:
				for k in 4:
					column_left[k + 1][0] = -1


## FUN_004DBB50: the score (var 0xCE) in the middle, the number of the ten things taken (var 0xBC) on the left.
func _castle_tick() -> void:
	texts[2] = "%04d" % Game.get_var(0xCE)
	var taken := 0
	var bits := Game.get_var(0xBC)
	for k in 10:
		if (bits & (1 << k)) != 0:
			taken += 1
	texts[0] = "x%d" % taken
	_hint_tick(CASTLE_HINTS, true)


## FUN_0051F2A3 (the HUD part): the air gauge, a brick lit in the column for each one taken and the
## corner icon once the bricks are delivered.
func dive_tick(air_gauge: float, bricks: int, delivered: bool) -> void:
	gauge_value = air_gauge
	if bricks > 0:
		column_left[bricks - 1][1] = WHITE
	if delivered:
		left_icon[1] = WHITE
	queue_redraw()


func set_prompt(index: int) -> void:
	if column_left.is_empty():
		return
	if column_left[0][0] == index:
		return
	column_left[0][0] = index
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


func _process(_delta: float) -> void:
	# FUN_00445ECF draws nothing while the prompt mode (FUN_004450C0) is 1 or 2.
	var hidden := false
	var owner_island = get_parent().get_parent() if get_parent() != null else null
	if owner_island != null and owner_island.get("bridge") != null:
		hidden = int(owner_island.bridge.services.prompt_state) != 0
	if visible == hidden:
		visible = not hidden


static func _tint(argb: int) -> Color:
	return Color(float((argb >> 16) & 0xFF) / 255.0, float((argb >> 8) & 0xFF) / 255.0, float(argb & 0xFF) / 255.0, float((argb >> 24) & 0xFF) / 255.0)


func _icon(entry: Array, box: Rect2, scale: Vector2) -> void:
	if int(entry[0]) < 0:
		return
	var texture := _load(int(entry[0]))
	if texture != null:
		draw_texture_rect(texture, Rect2(box.position * scale, box.size * scale), false, _tint(int(entry[1])))


func _draw() -> void:
	if column_left.is_empty():
		return
	var scale := size / DESIGN
	if corners:
		_icon(left_icon, LEFT_ICON, scale)
		_icon(right_icon, RIGHT_ICON, scale)
	if column_left_on:
		for k in 5:
			_icon(column_left[k], Rect2(COLUMN_LEFT_X, COLUMN_Y - COLUMN_STEP * k, 60, 60), scale)
	if column_right_on:
		for k in 5:
			_icon(column_right[k], Rect2(COLUMN_RIGHT_X, COLUMN_Y - COLUMN_STEP * k, 60, 60), scale)
	if gauge_on:
		_draw_gauge(scale)
	_draw_texts(scale)


## FUN_00445B84: the share of the level, the pieces up to it, the marker at its height and the icon.
func _draw_gauge(scale: Vector2) -> void:
	var fraction := _gauge_fraction()
	var count := 0
	if int(gauge_marker[0]) < 0:
		count = clampi(int(GAUGE_PIECES * fraction + 0.5), 0, GAUGE_PIECES)
	else:
		count = GAUGE_PIECES
		var middle := int(GAUGE_BASE - GAUGE_RANGE * fraction)
		_icon(gauge_marker, Rect2(GAUGE_MARKER_X, middle - 16, 32, 32), scale)
	for i in count:
		_icon(gauge_stack[i], Rect2(GAUGE_X, GAUGE_BOTTOM - 16.0 * i, GAUGE_PIECE.x, GAUGE_PIECE.y), scale)
	_icon(gauge_top, Rect2(GAUGE_ICON_X, GAUGE_ICON_Y, 60, 60), scale)


## FUN_00445B84's share: +0x78 is the full value, +0x7C the empty one and +0x80 the current one (the dive
## sets them to 100, 0 and 1.2 times the air left). The branches are the exe's, including its treatment of
## a full value at or under the empty one.
func _gauge_fraction() -> float:
	var full := gauge_max
	var empty := gauge_min
	var value := gauge_value
	var span := full - empty
	if full <= empty:
		if value < full:
			return 1.0
		if value <= empty:
			return (value - empty) / span
		return 0.0
	if value > full:
		return 1.0
	if value < empty:
		return 0.0
	return (value - empty) / span


func _draw_texts(scale: Vector2) -> void:
	if font == null:
		return
	var glyphs := GameFont.scale_for(size)
	var y := int(TEXT_Y * scale.y)
	var lines := [[texts[0], int(TEXT_LEFT * scale.x)], [texts[1], int(TEXT_RIGHT * scale.x) - font.measure(texts[1], glyphs).x],
		[texts[2], int(TEXT_CENTRE * scale.x) - font.measure(texts[2], glyphs).x / 2]]
	for line in lines:
		if String(line[0]) == "":
			continue
		font.draw(self, line[0], line[1], y, glyphs, SHADOW_COLOR, Vector2(SHADOW_OFFSET, SHADOW_OFFSET))
		font.draw(self, line[0], line[1], y, glyphs, TEXT_COLOR)
