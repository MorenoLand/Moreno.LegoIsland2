extends Control

const Story = preload("res://scripts/core/story.gd")

const DESIGN := Vector2(800, 600)
const SPIN_RATE := 0.05
const FLIP_RATE := 0.01
const TIME_UNIT := 1.0 / 30.0
const HALF := 128.0

var backdrop: ImageTexture
var pizza: ImageTexture
var cd: ImageTexture
var font: GameFont
var mode := 2
var auto_continue := true
## The screen exists to cover the zone build. When the data is already local the
## fetch is a no-op, so without this the disc is on screen for about three
## frames and then the island takes over - it reads as a still image rather than
## a spinning disc.
const MINIMUM_SECONDS := 1.1
var _elapsed := 0.0
var text_insert_cd := ""
var text_loading := ""
var spin := 0.0
var flip := 0.0
var last_ms := 0


func _ready() -> void:
	backdrop = _texture("_data/GenericBits/BackDrop/LoadingScreen.tga")
	pizza = _texture("_data/GenericBits/BackDrop/pizza.tga")
	cd = _texture("_data/GenericBits/BackDrop/CD.tga")
	font = GameFont.load_font("_data/fonts/Balloon24")
	var messages := _messages("_data/messages/FE/English/FRONTEND.str")
	text_insert_cd = messages.get("INSERTCD", "")
	text_loading = messages.get("LOADING", "")
	last_ms = Time.get_ticks_msec()
	Display.stretch_changed.connect(func(_s): queue_redraw())
	var plan := _resolve_zone()
	var archive: String = plan[0]
	var code: String = plan[1]
	if archive != "":
		Game.set_var(Game.VAR_ZONE, Story.travel_zone(archive, Game))
		await _fetch_zone_data(code if code != "" else archive)
		await _wait_out_minimum()
		get_tree().change_scene_to_file("res://scenes/island.tscn")
		return
	if Game.pending_zone >= 0:
		print("zone %d is not ported yet" % Game.pending_zone)
		return
	if auto_continue:
		await _fetch_zone_data("")
		await _wait_out_minimum()
		get_tree().change_scene_to_file("res://scenes/front_menu.tscn")


## Resolve this load into (archive, code): the archive name to fetch on the web,
## and the zone code string island.gd should be entered by ("" = the number
## path; island.gd knows 1 park, 3 house and treats the island's 2/31/32/33 as
## itself). Also records var 5 - the "travel sets var 5" step, which is what
## opens the state table's `var 5 == zone` objectives.
func _resolve_zone() -> Array:
	var code := Game.pending_zone_code
	if code.to_upper() == "Z02LGI":
		# The island must load by number: its code path would derive the
		# placement prefix "lgi" instead of the island's own table.
		Game.pending_zone_code = ""
		Game.pending_zone = 2
		return ["z02LGI", ""]
	if code != "":
		return [code, code]
	var archive := ""
	if Game.pending_zone >= 0:
		archive = String(Story.ZONE_ARCHIVE.get(Game.pending_zone, ""))
	return [archive, "" if Game.pending_zone in Story.NUMBER_PATH else archive]


## Holds the screen up long enough for the disc to be seen turning. Driven off
## the same clock as the spin, so a stalled frame cannot stretch it forever.
func _wait_out_minimum() -> void:
	var waited := 0.0
	while waited < MINIMUM_SECONDS:
		await get_tree().process_frame
		waited += get_process_delta_time()


## On the web the archives are not local yet, so pull in the ones this screen
## needs before it is built. Nothing to do when reading a local install.
func _fetch_zone_data(archive: String) -> void:
	for i in 3:
		await get_tree().process_frame
	if not Data.is_remote():
		return
	var wanted := ["Fonts", "GENERICBITS", "menu", "Overlays", "messages", "z60FRE"]
	# The menu picks a zone by number and the travel keys use the code; both are
	# resolved to the zone code before this is called.
	if archive != "":
		wanted.append(archive)
	for n in wanted:
		if not Data.fetched.has(n):
			text_loading = "Loading %s..." % n
			queue_redraw()
			await Data.fetch_archive(n)
	# the sounds sit loose in the data folder, not in an archive
	text_loading = "Loading sounds..."
	queue_redraw()
	await Data.fetch_files(LOOSE_FILES)
	text_loading = "Loading music..."
	queue_redraw()
	await Data.fetch_files(MUSIC_FILES)


const LOOSE_FILES := [
	"_data/SaveDef.lgo",
	"_data/sw.dat",
	"_data/sounds/z00FRE/UpDown1.wav",
	"_data/sounds/z00FRE/UpDown2.wav",
	"_data/sounds/z00FRE/UpDown3.wav",
	"_data/sounds/z00FRE/UpDown4.wav",
	"_data/sounds/z00FRE/Select.wav",
	"_data/sounds/z00FRE/Back.wav",
	"_data/sounds/z00FRE/OnOff.wav",
]

const MUSIC_FILES := [
	"_data/sounds/DirectMusic/menu/Menu.sgt",
	"_data/sounds/DirectMusic/menu/Menu.sty",
	"_data/sounds/DirectMusic/menu/Menu.dls",
]


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var elapsed := (now - last_ms) * TIME_UNIT
	last_ms = now
	spin += elapsed * SPIN_RATE
	flip += elapsed * FLIP_RATE
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var rect := Display.ui_rect(size)
	draw_set_transform(rect.position, 0.0, rect.size / DESIGN)
	if backdrop != null:
		draw_texture_rect(backdrop, Rect2(Vector2.ZERO, DESIGN), false)
	_draw_disc()
	_draw_text()


func _draw_disc() -> void:
	var cs := cos(spin)
	var sn := sin(spin)
	var cf := cos(flip)
	var corners := [Vector2(HALF, 0), Vector2(0, HALF), Vector2(-HALF, 0), Vector2(0, -HALF)]
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var points := PackedVector2Array()
	for c in corners:
		var x: float = c.x * cs - c.y * sn
		var y: float = c.x * sn + c.y * cs
		points.append(DESIGN * 0.5 + Vector2(x, y * cf))
	var tex := cd if cf > 0.0 else pizza
	if tex != null:
		draw_polygon(points, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]), uvs, tex)


func _draw_text() -> void:
	if font == null:
		return
	var text := text_loading if mode == 2 else text_insert_cd
	var scale := GameFont.scale_for(DESIGN)
	var width := font.measure(text, scale).x
	font.draw(self, text, int(DESIGN.x * 0.5) - int(width / 2), int(DESIGN.y) - 0x28, scale, Color(1, 1, 0, 1))


func _texture(path: String) -> ImageTexture:
	var image := Image.new()
	if image.load_tga_from_buffer(Data.read(path)) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _messages(path: String) -> Dictionary:
	var out := {}
	for line in Data.read_text(path).split("\r\n"):
		var colon := line.find(":")
		if colon < 0:
			continue
		var rest := line.substr(colon + 1)
		var space := rest.find(" ")
		out[line.substr(0, colon)] = rest.substr(space).strip_edges() if space >= 0 else ""
	return out
