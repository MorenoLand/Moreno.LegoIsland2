extends Control

signal action(kind: int, value: int)
signal game_started(zone: int)
signal credits_requested
signal quit_requested
signal resume_requested
signal leave_requested
signal zone_requested(zone: int)
signal movie_requested(name: String)
signal load_requested(slot: int)

const CREDITS_LINE := 30
const CREDITS_WIDTH := 600
const CREDITS_START := -480.0
const CREDITS_RATE := 30.0
const CONFIRM_MENU := 20

# Ids stored in the callback column of data/menus.tsv. They say which rows of
# the save-slot menus pick an existing game or start a new one.
const SLOT_CALLBACK_PICK := 0x86BB2E
const SLOT_CALLBACK_NEW := 0x86BBB3

const SPACE := Vector2(640, 480)
const TILE := 24
const SHADOW := Vector2(1.6, 1.6)
const WHITE := Color(1, 1, 1, 1)
const GREY := Color(0.4980392, 0.4980392, 0.4980392, 1)
const TEXT_GREY := Color(0.2470588, 0.2470588, 0.2470588, 1)
const SHADOW_COLOR := Color(0, 0, 0, 1)
const PRESS_FRAMES := 4

var menus: Array[Dictionary] = []
var row_codes := PackedInt32Array()
var styles := PackedInt32Array()
var tiles: Array[ImageTexture] = []
var font_title: GameFont
var font_item: GameFont
var messages := {}
var current := 0
var selected := 1
var stack: Array = []
var press := 0
var half := 0
var disabled_mask := 0
var last_mouse := Vector2(-1000, -1000)
var sounds := {}
var move_index := 0
var pending_value := 0
var cursor_installed := false
var credits_lines: Array = []
var credits_t := 0.0
var credits_active := false

const KEYS_MENU := 13
const RESOLUTION_MENU := 14
const MODE_ACTION := 100
const MODES := [Vector2i(800, 600), Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const BLINK_SECONDS := 0.17

var with_backdrop := true
var music: DmPlayer
var fade := 0.0
const FADE_STEP := 0.0625
const FADE_RATE := 30.0
var start_menu := 0
var transparent := false
var backdrop: FrontBackdrop
var backdrop_view: SubViewport
var backdrop_rect: TextureRect
var backdrop_black: ColorRect
const BACKDROP_SIZE := Vector2i(1600, 1200)
var bindings: KeyBindings
var keys_row_codes := PackedInt32Array()
var key_scroll := 0
var rebinding := 0
var blink_time := 0.0


func _ready() -> void:
	_read_menus()
	row_codes.append_array(Table.column("res://data/menu_rows.tsv", 1))
	styles.append_array(Table.column("res://data/menu_styles.tsv", 1))
	keys_row_codes.append_array(Table.column("res://data/menu_keys_rows.tsv", 1))
	bindings = KeyBindings.new()
	bindings.load_from_tables()
	for i in 72:
		var image := Image.new()
		var bytes := Data.read("_data/menu/mOverlays/text%03d.tga" % i)
		tiles.append(ImageTexture.create_from_image(image) if image.load_tga_from_buffer(bytes) == OK else null)
	_install_cursor()
	font_title = GameFont.load_font("_data/fonts/Balloon24")
	font_item = GameFont.load_font("_data/fonts/Balloon12")
	for file in ["FRONTEND", "PAUSE", "IFC_ST"]:
		_read_messages("_data/messages/FE/English/%s.str" % file)
	_read_messages("_data/messages/FE/English/CREDITS.str")
	Game.read_state_keys()
	_fill_slots()
	_build_credits()
	current = start_menu
	selected = 1
	game_started.connect(_enter_zone)
	quit_requested.connect(func(): get_tree().quit())
	credits_requested.connect(func():
		credits_t = CREDITS_START
		credits_active = true)
	Display.stretch_changed.connect(func(_s): queue_redraw())
	if with_backdrop and DisplayServer.get_name() != "headless":
		music = DmPlayer.new()
		add_child(music)
		music.play("_data/sounds/DirectMusic/menu/Menu.sgt")
	if with_backdrop:
		backdrop_view = SubViewport.new()
		backdrop_view.size = BACKDROP_SIZE
		backdrop_view.own_world_3d = true
		backdrop_view.gui_disable_input = true
		backdrop_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		backdrop = FrontBackdrop.new()
		backdrop_view.add_child(backdrop)
		add_child(backdrop_view)
		backdrop_black = ColorRect.new()
		backdrop_black.color = Color.BLACK
		backdrop_black.show_behind_parent = true
		backdrop_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(backdrop_black)
		backdrop_rect = TextureRect.new()
		backdrop_rect.texture = backdrop_view.get_texture()
		backdrop_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop_rect.stretch_mode = TextureRect.STRETCH_SCALE
		backdrop_rect.show_behind_parent = true
		backdrop_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(backdrop_rect)
		_place_backdrop()
		Display.stretch_changed.connect(func(_s): _place_backdrop())
		resized.connect(_place_backdrop)
	for name in ["UpDown1", "UpDown2", "UpDown3", "UpDown4", "Select", "Back", "OnOff"]:
		sounds[name] = Wav.parse(Data.read("_data/sounds/z00FRE/%s.wav" % name))
	set_process(true)


func _read_menus() -> void:
	# data/menus.tsv holds one row per menu item, grouped by the menu column, in
	# the order the menus were declared.
	for row in Table.rows("res://data/menus.tsv"):
		if row.size() < 10:
			continue
		var item := {"name": String(row[6]), "type": int(row[7]),
			"value": int(row[8]), "flags": int(row[9])}
		if menus.is_empty() or menus[-1]["first"] != int(row[0]):
			menus.append({"type": int(row[2]), "count": int(row[3]),
				"style": int(row[4]), "callback": int(row[5]),
				"first": int(row[0]), "items": []})
		var option_key: String = Game.OPTION_ITEMS.get(item.name, "")
		if option_key != "":
			item.value = Game.option(option_key)
		(menus[-1]["items"] as Array).append(item)


func _read_messages(path: String) -> void:
	for line in Data.read_text(path).split("\r\n"):
		var colon := line.find(":")
		if colon <= 0:
			continue
		var rest := line.substr(colon + 1)
		var space := rest.find(" ")
		var key := line.substr(0, colon)
		if not messages.has(key):
			messages[key] = rest.substr(space).strip_edges() if space >= 0 else ""


func _place_backdrop() -> void:
	if backdrop_rect == null:
		return
	backdrop_black.position = Vector2.ZERO
	backdrop_black.size = size
	var rect := Display.ui_rect(size)
	backdrop_rect.position = rect.position
	backdrop_rect.size = rect.size


func label(name: String) -> String:
	if name.begins_with("!"):
		return messages.get(name.substr(1), name.substr(1))
	if name.begins_with("^"):
		return name.substr(1)
	return name


func _process(delta: float) -> void:
	if fade < 1.0 and with_backdrop:
		fade = minf(1.0, fade + delta * FADE_RATE * FADE_STEP)
		modulate = Color(fade, fade, fade, 1.0)
	if credits_active:
		credits_t += delta * CREDITS_RATE
		if int(credits_t / CREDITS_LINE) >= credits_lines.size():
			credits_active = false
		queue_redraw()
		return
	if rebinding != 0:
		blink_time += delta
		if blink_time >= BLINK_SECONDS:
			blink_time = 0.0
			rebinding = -1 if rebinding > 0 else 1
	if press > 0:
		press -= 1
		if press == 0:
			_fire(selected)
	queue_redraw()


func _draw() -> void:
	if backdrop == null and not transparent:
		draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if menus.is_empty() or font_title == null or font_item == null:
		return
	var rect := Display.ui_rect(size)
	draw_set_transform(rect.position, 0.0, rect.size / SPACE)
	if credits_active:
		_draw_credits()
		return
	_draw_menu()


func _tile(index: int, x: int, row: int, yoff: int, tint := WHITE) -> void:
	if index >= 0 and index < tiles.size() and tiles[index] != null:
		draw_texture_rect(tiles[index], Rect2(x * TILE + 320, yoff + (row - 1) * TILE, TILE, TILE), false, tint)


func _plate(index: int, x: int, row: int, yoff: int) -> void:
	if index >= 0 and index < tiles.size() and tiles[index] != null:
		draw_texture_rect(tiles[index], Rect2(x * TILE + 320, yoff + (row - 1) * TILE, TILE * 2, TILE * 2), false)


func _text(font: GameFont, text: String, center_x: int, y: int, color: Color) -> void:
	var width := font.measure(text, Vector2.ONE).x
	var x := center_x - int(width / 2)
	font.draw(self, text, x, y, Vector2.ONE, SHADOW_COLOR, SHADOW)
	font.draw(self, text, x, y, Vector2.ONE, color)


func _toggle_text(item: Dictionary) -> String:
	return label("!ON") if int(item.value) != 0 else label("!OFF")


func _text_left(font: GameFont, text: String, x: int, y: int, color: Color) -> void:
	font.draw(self, text, x, y, Vector2.ONE, SHADOW_COLOR, SHADOW)
	font.draw(self, text, x, y, Vector2.ONE, color)


func _text_right(font: GameFont, text: String, right_x: int, y: int, color: Color) -> void:
	var x := right_x - font.measure(text, Vector2.ONE).x
	font.draw(self, text, x, y, Vector2.ONE, SHADOW_COLOR, SHADOW)
	font.draw(self, text, x, y, Vector2.ONE, color)


func _segment(index: int, x: int, row: int, yoff: int, tint: Color) -> void:
	if index >= 0 and index < tiles.size() and tiles[index] != null:
		draw_texture_rect(tiles[index], Rect2(x * 12 + 320, yoff + 2 + (row - 1) * TILE, 12, TILE - 4), false, tint)


func _adjust(step: int) -> void:
	# The keys screen numbers its rows in tens, so left and right can arrive here
	# with a row that is not a menu item at all.
	var items: Array = menus[current].items
	if selected < 0 or selected >= items.size():
		return
	var item: Dictionary = items[selected]
	if (int(item.flags) & disabled_mask) != 0:
		return
	if int(item.type) == 6:
		item.value = clampi(int(item.value) + step * 10, 0, 100)
		_commit_option(item)
	elif int(item.type) == 5:
		press = PRESS_FRAMES


func _item_width(item: Dictionary) -> int:
	var w := font_item.measure(label(item.name), Vector2.ONE).x
	match int(item.type):
		5:
			return w + 0x30 + font_item.measure(_toggle_text(item), Vector2.ONE).x
		6:
			return w + 0xA8
		7:
			return 0xF0
	return w


func _layout() -> Dictionary:
	var m: Dictionary = menus[current]
	var count: int = m.count
	var rows := count * 2 + 2
	var yoff := 0xF0 - int((rows - 1) * TILE / 2)
	var title_w := font_title.measure(label(m.items[0].name), Vector2.ONE).x
	var wide := title_w
	for k in range(1, count):
		wide = maxi(wide, _item_width(m.items[k]))
	return {"rows": rows, "yoff": yoff, "title_half": int(title_w / 0x30) + 1, "half": int(wide / 0x30) + 1}


func _draw_menu() -> void:
	if current == KEYS_MENU:
		_draw_keys_menu()
		return
	var m: Dictionary = menus[current]
	var lay := _layout()
	var rows: int = lay.rows
	var yoff: int = lay.yoff
	var title_half: int = lay.title_half
	half = lay.half
	var style: int = m.style
	var base := int(styles[style])
	for r in rows:
		var code := row_codes[r] if r < rows - 1 else -6
		match code:
			-5:
				_tile(base + 0xF, -2 - half, r, yoff)
				for x in range(-1 - half, half + 1):
					_tile(base + 3, x, r, yoff)
				_tile(base + 0x12, half + 1, r, yoff)
			-6:
				_tile(base + 0x15, -2 - half, r, yoff)
				for x in range(-1 - half, half + 1):
					_tile(base + 6, x, r, yoff)
				_tile(base + 0x18, half + 1, r, yoff)
			-1:
				_tile(base + 9, -2 - half, r, yoff)
				for x in range(-1 - half, half + 1):
					_tile(0, x, r, yoff)
				_tile(base + 0xC, half + 1, r, yoff)
			0:
				_title_row(r, yoff, base, style, half, title_half, label(m.items[0].name))
			_:
				if code > 0 and code < int(m.count):
					_item_row(m.items[code], code, r, yoff, base, style, half)


func _title_row(r: int, yoff: int, base: int, style: int, half: int, title_half: int, text: String) -> void:
	_tile(base + 9, -2 - half, r, yoff)
	_tile(base + 9, -2 - half, r + 1, yoff)
	for x in range(-1 - half, -1 - title_half):
		_tile(0, x, r, yoff)
		_tile(0, x, r + 1, yoff)
	var x := -1 - title_half
	while x < title_half + 1:
		_plate(style + 0x36, x, r, yoff)
		x += 2
	for fx in range(title_half + 1, half + 1):
		_tile(0, fx, r, yoff)
		_tile(0, fx, r + 1, yoff)
	_tile(base + 0xC, half + 1, r, yoff)
	_tile(base + 0xC, half + 1, r + 1, yoff)
	_text(font_title, text, 320, yoff + 0x18 + 14, WHITE)


func _item_row(item: Dictionary, index: int, r: int, yoff: int, base: int, style: int, half: int) -> void:
	var off := int(item.type) != 7 and (int(item.flags) & disabled_mask) != 0
	var tint := GREY if off else WHITE
	var is_selected := index == selected
	var pressed := is_selected and press > 0
	_tile(base + 9, -2 - half, r, yoff)
	var left := style + (0x2A if pressed else 0x27) if is_selected else style + 0x24
	_tile(left, -1 - half, r, yoff)
	_tile(style + 0x1E, -half, r, yoff, tint)
	for x in range(-half + 1, half - 1):
		_tile(style + 0x1B, x, r, yoff, tint)
	_tile(style + 0x21, half - 1, r, yoff, tint)
	var right := style + (0x33 if pressed else 0x30) if is_selected else style + 0x2D
	_tile(right, half, r, yoff)
	_tile(base + 0xC, half + 1, r, yoff)
	var color := TEXT_GREY if off else WHITE
	var text_y := yoff + r * TILE - 4
	match int(item.type):
		5:
			_text_left(font_item, label(item.name), (1 - half) * TILE + 320, text_y, color)
			_text_right(font_item, _toggle_text(item), (half - 1) * TILE + 320, text_y, color)
		6:
			_text_left(font_item, label(item.name), (1 - half) * TILE + 320, text_y, color)
			for j in 10:
				var seg := 0x39 if j * 10 < int(item.value) else 0x3A
				_segment(seg, j - 0xB + half * 2, r, yoff, tint)
		_:
			_text(font_item, label(item.name), 320, text_y, color)


func _play(name: String) -> void:
	var stream: AudioStream = sounds.get(name)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.bus = "Sound"
	player.stream = stream
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _play_move() -> void:
	_play("UpDown%d" % (move_index + 1))
	move_index = (move_index + 1) % 4


func _wide(index: int, x: int, row: int, yoff: int) -> void:
	if index >= 0 and index < tiles.size() and tiles[index] != null:
		draw_texture_rect(tiles[index], Rect2(x * TILE + 320, yoff + (row - 1) * TILE, TILE * 4, TILE), false)


func _plate_at(index: int, x: int, row: int, yoff: int, shift: int) -> void:
	if index >= 0 and index < tiles.size() and tiles[index] != null:
		draw_texture_rect(tiles[index], Rect2(x * TILE + 320 + shift, yoff + (row - 1) * TILE, TILE * 2, TILE * 2), false)


func _track(index: int, x: int, row: int, yoff: int) -> void:
	if index >= 0 and index < tiles.size() and tiles[index] != null:
		draw_texture_rect(tiles[index], Rect2(x * TILE + 320, yoff + (row - 1) * TILE, TILE, TILE * 8), false)


func _key_label(action: Dictionary) -> String:
	var name := str(action.name)
	if name.begins_with("@"):
		var bang := name.find("!")
		var number := name.substr(1, bang - 1).strip_edges()
		return messages.get(name.substr(bang + 1), name.substr(bang + 1)) + " " + number
	return label(name)


func _keys_rows() -> int:
	return int(menus[KEYS_MENU].count) * 2 + 0xB


func _slot_valid(k: int) -> bool:
	return key_scroll + k - 1 < bindings.actions.size()


func _draw_keys_menu() -> void:
	var m: Dictionary = menus[KEYS_MENU]
	var rows := _keys_rows()
	var yoff := 0xF0 - int((rows - 1) * TILE / 2)
	var style: int = m.style
	var base := int(styles[style])
	var title := label(m.items[0].name)
	var title_w := font_title.measure(title, Vector2.ONE).x
	var wide := maxi(title_w, 0xF0 + 0x60)
	for k in range(2, int(m.count)):
		wide = maxi(wide, font_item.measure(label(m.items[k].name), Vector2.ONE).x)
	var h := int(wide / 0x30) + 1
	half = h
	var title_half := int(title_w / 0x30) + 1
	for r in rows:
		var code := keys_row_codes[r] if r < rows - 1 else -6
		match code:
			-5:
				_tile(base + 0xF, -2 - h, r, yoff)
				for x in range(-1 - h, h + 1):
					_tile(base + 3, x, r, yoff)
				_tile(base + 0x12, h + 1, r, yoff)
			-6:
				_tile(base + 0x15, -2 - h, r, yoff)
				for x in range(-1 - h, h + 1):
					_tile(base + 6, x, r, yoff)
				_tile(base + 0x18, h + 1, r, yoff)
				_plate_at(0x40 if rebinding == 0 else 0x41, h - 1, 13, yoff, -12)
			-1:
				_tile(base + 9, -2 - h, r, yoff)
				for x in range(-1 - h, h + 1):
					_tile(0, x, r, yoff)
				_tile(base + 0xC, h + 1, r, yoff)
			0:
				_title_row(r, yoff, base, style, h, title_half, title)
			-3:
				for x in range(-2 - h, h + 2):
					var edge := base + 9 if x == -2 - h else (base + 0xC if x == h + 1 else 0)
					_tile(edge, x, r, yoff)
					if x != h - 1:
						for k in range(1, 9):
							if not _slot_valid(k):
								_tile(edge, x, r + k, yoff)
				_plate_at(0x3E, h - 1, r - 1, yoff, -12)
				_track(1, h - 1, r + 1, yoff)
				var max_scroll := bindings.actions.size() - 8
				var thumb := int(key_scroll * 0xA8 / max_scroll) if max_scroll >= 1 else 0
				_tile(0x42, h - 1, r + 1, yoff + thumb)
			10, 20, 30, 40, 50, 60, 70, 80:
				_key_row(int(code / 10), r, yoff, base)
			_:
				if code > 1 and code < int(m.count):
					_key_button(m.items[code], code, r, yoff, base, style, h)


func _key_row(k: int, r: int, yoff: int, base: int) -> void:
	if not _slot_valid(k):
		return
	var action: Dictionary = bindings.actions[key_scroll + k - 1]
	var is_selected := selected == k * 10
	if k == 1:
		_wide(0x3D, -8, r - 2, yoff)
		_wide(0x3D, -3, r - 2, yoff)
		_wide(0x3D, 2, r - 2, yoff)
		_text(font_item, label("!ACTION"), -6 * TILE + 320, yoff + (r - 2) * TILE - 4, WHITE)
		_text(font_item, _key_label({"name": "@ 1!SET"}), -1 * TILE + 320, yoff + (r - 2) * TILE - 4, WHITE)
		_text(font_item, _key_label({"name": "@ 2!SET"}), 4 * TILE + 320, yoff + (r - 2) * TILE - 4, WHITE)
	_tile(base + 9, -10, r, yoff)
	_tile(0, -9, r, yoff)
	_wide(0x3D, -8, r, yoff)
	_tile(0, -4, r, yoff)
	_wide(0x3B, -3, r, yoff)
	_tile(0, 1, r, yoff)
	_wide(0x3C, 2, r, yoff)
	_tile(0, 6, r, yoff)
	_tile(0, 8, r, yoff)
	_tile(base + 0xC, 9, r, yoff)
	if is_selected:
		var mark := 0x43 if (press > 0 or rebinding > 0) else 0x42
		_tile(mark, -4, r, yoff)
		_tile(mark, 1, r, yoff)
		_tile(mark, 6, r, yoff)
	var y := yoff + r * TILE - 4
	_text(font_item, _key_label(action), -6 * TILE + 320, y, WHITE)
	_text(font_item, bindings.key_text(int(action.fixed)), -1 * TILE + 320, y, TEXT_GREY)
	if is_selected and rebinding != 0:
		if rebinding < 0:
			_text(font_item, "_", 4 * TILE + 320, y, WHITE)
	else:
		_text(font_item, bindings.key_text(int(action.value)), 4 * TILE + 320, y, WHITE)


func _key_button(item: Dictionary, index: int, r: int, yoff: int, base: int, style: int, h: int) -> void:
	var is_selected := selected == index
	var pressed := is_selected and press > 0
	var narrow := h - 2
	var shift := -1
	_tile(base + 9, -2 - h, r, yoff)
	_tile(0, -1 - h, r, yoff)
	var left := style + (0x2A if pressed else 0x27) if is_selected else style + 0x24
	_tile(left, -1 - narrow + shift, r, yoff)
	_tile(style + 0x1E, shift - narrow, r, yoff)
	var x := -narrow
	while true:
		x += 1
		if x >= narrow - 1:
			break
		_tile(style + 0x1B, x + shift, r, yoff)
	_tile(style + 0x21, x + shift, r, yoff)
	var right := style + (0x33 if pressed else 0x30) if is_selected else style + 0x2D
	_tile(right, narrow + shift, r, yoff)
	_text(font_item, label(item.name), shift * TILE + 320, yoff + r * TILE - 4, WHITE)
	_tile(0, narrow + 1 + shift, r, yoff)
	_tile(0, narrow + 1, r, yoff)
	_tile(0, narrow + 2, r, yoff)
	_tile(base + 0xC, narrow + 3, r, yoff)


func _keys_selectable() -> Array[int]:
	var out: Array[int] = []
	for k in range(1, 9):
		if _slot_valid(k):
			out.append(k * 10)
	out.append(2)
	out.append(3)
	return out


func _keys_move(step: int) -> void:
	var list := _keys_selectable()
	var i := list.find(selected)
	var last_slot := 10 * mini(8, bindings.actions.size() - key_scroll)
	if step > 0:
		if selected == last_slot and key_scroll + 8 < bindings.actions.size():
			key_scroll += 1
		else:
			selected = list[(i + 1) % list.size()] if i >= 0 else list[0]
	else:
		if selected == 10 and key_scroll > 0:
			key_scroll -= 1
		else:
			selected = list[list.size() - 1] if i <= 0 else list[i - 1]
	press = 0
	_play_move()


func _keys_fire() -> void:
	_play("Select")
	if selected >= 10:
		rebinding = 1
		return
	if selected == 2:
		bindings.commit()
	else:
		bindings.revert()
	_back()


func _selectable() -> Array[int]:
	var out: Array[int] = []
	for k in range(1, int(menus[current].count)):
		out.append(k)
	return out


func _move(step: int) -> void:
	if current == KEYS_MENU:
		_keys_move(step)
		return
	var list := _selectable()
	if list.is_empty():
		return
	var i := list.find(selected)
	if step > 0:
		selected = list[(i + 1) % list.size()] if i >= 0 else list[0]
	else:
		selected = list[list.size() - 1] if i <= 0 else list[i - 1]
	press = 0
	_play_move()


func _activate() -> void:
	if current == KEYS_MENU:
		if rebinding == 0:
			_keys_fire()
		return
	var item: Dictionary = menus[current].items[selected]
	if int(item.type) != 7 and (int(item.flags) & disabled_mask) != 0:
		return
	press = PRESS_FRAMES


func _back() -> void:
	_play("Back")
	if stack.is_empty():
		if start_menu != 0:
			resume_requested.emit()
		return
	var top: Array = stack.pop_back()
	current = top[0]
	selected = top[1]
	press = 0


func _build_credits() -> void:
	credits_lines.clear()
	for row in Table.rows("res://data/credits.tsv"):
		if row.size() < 3:
			continue
		var kind := int(row[1])
		var key := String(row[2])
		if key == "":
			continue
		var text := label(key)
		var font := font_item if kind == 0 else font_title
		var rest := text
		while true:
			var line := rest
			var tail := ""
			while font.measure(line, Vector2.ONE).x > CREDITS_WIDTH:
				var space := line.rfind(" ")
				if space < 0:
					break
				tail = line.substr(space + 1) + ((" " + tail) if tail != "" else "")
				line = line.substr(0, space)
			credits_lines.append([kind, line])
			if tail == "":
				break
			rest = tail


func _draw_credits() -> void:
	var scroll := int(credits_t)
	var sub := scroll % CREDITS_LINE
	var base := int(scroll / CREDITS_LINE)
	for i in 18:
		var index := i + base
		if index < 0 or index >= credits_lines.size():
			continue
		var entry: Array = credits_lines[index]
		var kind := int(entry[0])
		if kind < 0 or kind > 2:
			continue
		var font := font_item if kind == 0 else font_title
		_text(font, str(entry[1]), 320, (i + 1) * CREDITS_LINE - sub, WHITE)


func _fire(index: int) -> void:
	_play("Select")
	var items: Array = menus[current].items
	if index < 0 or index >= items.size():
		return
	var item: Dictionary = items[index]
	match int(item.type):
		1:
			stack.append([current, selected])
			current = int(item.value)
			selected = 1
			if current == KEYS_MENU:
				selected = 10
				key_scroll = 0
				rebinding = 0
			elif current == RESOLUTION_MENU:
				_fill_modes()
		2:
			_back()
		3:
			if start_menu == 0:
				quit_requested.emit()
			else:
				leave_requested.emit()
		9:
			pending_value = int(item.value)
			menus[CONFIRM_MENU].items[0].name = str(item.name)
			stack.append([current, selected])
			current = CONFIRM_MENU
			selected = 1
		5:
			item.value = 0 if int(item.value) != 0 else 1
			_play("OnOff")
			_commit_option(item)
			action.emit(5, int(item.value))
		10:
			_back()
			_handle_action(4, pending_value)
		_:
			action.emit(int(item.type), int(item.value))
			_handle_action(int(item.type), int(item.value))


## Writes a slider or toggle to the game's options and mirrors the speech /
## subtitles rule back onto the screen.
func _commit_option(item: Dictionary) -> void:
	var key: String = Game.OPTION_ITEMS.get(item.name, "")
	if key == "":
		return
	Game.set_option(key, int(item.value))
	for m in menus:
		for other in m.items:
			var other_key: String = Game.OPTION_ITEMS.get(other.name, "")
			if other_key != "":
				other.value = Game.option(other_key)


func _fill_modes() -> void:
	var screen := DisplayServer.screen_get_size()
	var items: Array[Dictionary] = [menus[RESOLUTION_MENU].items[0]]
	var now := DisplayServer.window_get_size()
	var pick := 1
	for mode in MODES:
		if mode.x > screen.x or mode.y > screen.y:
			continue
		items.append({"name": "^%d x %d" % [mode.x, mode.y], "type": 4, "value": MODE_ACTION + items.size() - 1, "flags": 0})
		if mode == now:
			pick = items.size() - 1
	items.append({"name": "!BACK", "type": 2, "value": 0, "flags": 0})
	menus[RESOLUTION_MENU].items = items
	menus[RESOLUTION_MENU].count = items.size()
	selected = pick


func _enter_zone(zone: int) -> void:
	Game.pending_zone = zone
	get_tree().change_scene_to_file("res://scenes/loading.tscn")


const CURSOR_TILE := 2
const CURSOR_SIZE := 44


## The menu's own mouse pointer: the yellow-and-red arrow in mOverlays/text002, with
## its hot spot on the opaque pixel nearest the top-left corner (the arrow tip).
func _install_cursor() -> void:
	if DisplayServer.get_name() == "headless" or tiles.size() <= CURSOR_TILE or tiles[CURSOR_TILE] == null:
		return
	var image: Image = (tiles[CURSOR_TILE] as ImageTexture).get_image()
	if image == null or image.is_empty():
		return
	image.convert(Image.FORMAT_RGBA8)
	var tip := Vector2i(0, 0)
	var best := 1 << 30
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.5 and x + y < best:
				best = x + y
				tip = Vector2i(x, y)
	var factor := float(CURSOR_SIZE) / float(maxi(image.get_width(), image.get_height()))
	image.resize(maxi(int(image.get_width() * factor), 1), maxi(int(image.get_height() * factor), 1), Image.INTERPOLATE_LANCZOS)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(image), Input.CURSOR_ARROW,
		Vector2(tip) * factor)
	cursor_installed = true


func _exit_tree() -> void:
	if cursor_installed:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)


func _handle_action(kind: int, value: int) -> void:
	if kind != 4:
		return
	if value > MODE_ACTION and value < MODE_ACTION + 40:
		var chosen: Variant = menus[RESOLUTION_MENU].items[value - MODE_ACTION]
		var parts := String(chosen.name).substr(1).split(" x ")
		if parts.size() == 2 and DisplayServer.get_name() != "headless":
			DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
		return
	if value == 0x11:
		zone_requested.emit(3)
		return
	if value == 18 or value == 19:
		movie_requested.emit("introfmv" if value == 18 else "outrofmv")
		return
	if value == 1:
		quit_requested.emit()
	elif value == 2:
		credits_requested.emit()
	elif value > 2 and value < 10:
		Game.new_game(value - 3)
		game_started.emit(Game.get_var(Game.VAR_ZONE))
	elif value > 0x13 and value < 0x1B:
		if Game.load_slot(value - 0x14):
			game_started.emit(Game.get_var(Game.VAR_NEXT_ZONE))
	elif value > 0x1D and value < 0x25:
		Game.save(value - 0x1E)
	elif value > 0x27 and value < 0x2F:
		Game.erase(value - 0x28)
	_fill_slots()


func _fill_slots() -> void:
	for m in menus:
		var cb := int(m.callback)
		if cb != SLOT_CALLBACK_PICK and cb != SLOT_CALLBACK_NEW:
			continue
		for k in range(1, mini(8, int(m.count))):
			var item: Dictionary = m.items[k]
			item.name = Game.slot_label(k - 1, messages)
			item.type = 9 if cb == SLOT_CALLBACK_PICK else 4
			item.flags = 0


func _input(event: InputEvent) -> void:
	if menus.is_empty():
		return
	if credits_active:
		var key_hit := false
		if event is InputEventKey:
			var key_event: InputEventKey = event
			key_hit = key_event.pressed and not key_event.echo and key_event.keycode != KEY_SPACE
		elif event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event
			key_hit = mouse_event.pressed
		if key_hit:
			credits_active = false
		return
	if rebinding != 0 and current == KEYS_MENU:
		if event is InputEventKey and event.pressed and not event.echo:
			var captured: InputEventKey = event
			if captured.keycode == KEY_ESCAPE:
				rebinding = 0
			else:
				var code := bindings.code_for_event(captured)
				if code != 0:
					bindings.actions[key_scroll + int(selected / 10) - 1].value = code
					rebinding = 0
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP:
				_move(-1)
			KEY_DOWN:
				_move(1)
			KEY_LEFT:
				_adjust(-1)
			KEY_RIGHT:
				_adjust(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SHIFT:
				_activate()
			KEY_ESCAPE:
				_back()
	elif event is InputEventMouseMotion:
		_mouse_over(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _row_at(event.position) > 0:
			_activate()


func _design_point(p: Vector2) -> Vector2:
	var rect := Display.ui_rect(size)
	return (p - rect.position) / rect.size * SPACE


func _row_at(p: Vector2) -> int:
	if current == KEYS_MENU:
		return 0
	var d := _design_point(p)
	var rows := int(menus[current].count) * 2 + 2
	var yoff: int = _layout().yoff
	var row := floori((d.y - yoff) / float(TILE)) + 1
	var column := floori((d.x - 320) / float(TILE))
	if row < 0 or row >= rows or column > half or column < -1 - half:
		return 0
	var code := row_codes[row] if row < rows - 1 else -6
	return code if code > 0 and code < int(menus[current].count) else 0


func _mouse_over(p: Vector2) -> void:
	if last_mouse.distance_to(p) <= 4.0:
		return
	last_mouse = p
	var code := _row_at(p)
	if code > 0 and code != selected:
		selected = code
		press = 0
		_play_move()
