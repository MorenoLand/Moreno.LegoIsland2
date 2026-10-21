extends Node

const MOVIES := [
	["legosoftware", true],
	["sdlogo", true],
	["introfmv", true],
]

## Where a web build fetches the game archives from. This has to be an http
## address the page can reach, and the _data folder has to be served under it.
const WEB_DATA_URL := "https://orion.moreno.land/_isle2/_data/"

var message: Label
var dialog: FileDialog
var movie: Control
var step := 0


func _ready() -> void:
	print("[boot] locate=%s web=%s remote_base=%s" % [str(Data.locate()), str(OS.has_feature("web")), Data.remote_base])
	if Data.locate():
		if DisplayServer.get_name() == "headless":
			print("LEGO Island 2 port: data found, boot ok")
			get_tree().quit()
			return
		movie = load("res://scenes/movie.tscn").instantiate()
		add_child(movie)
		movie.finished.connect(_next)
		_next.call_deferred()
		return
	if OS.has_feature("web"):
		_fetch_web_data()
		return
	if DisplayServer.get_name() == "headless":
		push_error("Game data not found. Pass --root=<install folder>, set LI2_ROOT, or set [data] root in user://config.cfg.")
		get_tree().quit(1)
		return
	_ask_for_folder()


## A browser has no folder to point at, so the archive list is fetched over HTTP
## and each archive is downloaded into user:// as it is needed.
func _fetch_web_data() -> void:
	_show_status("Fetching game file list...")
	print("[boot] locate_remote begin, %d archives" % Data.archives().size())
	var ok := await Data.locate_remote(WEB_DATA_URL)
	print("[boot] locate_remote done ok=%s indexed=%d" % [str(ok), str(Data.indexed())])
	if not ok:
		_show_status("Could not reach the game data at\n%s" % WEB_DATA_URL)
		return
	_show_status("Game data ready.")
	_next.call_deferred()


func _show_status(text: String) -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# the layer is anchored full rect, so setting size by hand would be overridden
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(label)
	add_child.call_deferred(layer)


func _next() -> void:
	while step < MOVIES.size():
		var entry: Array = MOVIES[step]
		step += 1
		var path: String = await Data.fetch_movie(String(entry[0]))
		if path == "":
			push_warning("movie unavailable: " + String(entry[0]))
			continue
		if movie == null:
			movie = load("res://scenes/movie.tscn").instantiate()
			add_child(movie)
			movie.finished.connect(_next)
		movie.play(path, entry[1])
		return
	get_tree().change_scene_to_file("res://scenes/loading.tscn")


func _ask_for_folder() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(520, 0)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	var title := Label.new()
	title.text = "Select your LEGO Island 2 install folder (the one that contains _data)."
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message = Label.new()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var button := Button.new()
	button.text = "Choose folder"
	button.pressed.connect(func(): dialog.popup_centered_ratio(0.6))
	box.add_child(title)
	box.add_child(button)
	box.add_child(message)
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(box)
	add_child(layer)
	dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.dir_selected.connect(_chosen)
	add_child(dialog)


func _chosen(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder.path_join("_data")):
		message.text = "That folder has no _data folder inside it."
		return
	var config := ConfigFile.new()
	config.load("user://config.cfg")
	config.set_value("data", "root", folder)
	if config.save("user://config.cfg") != OK:
		message.text = "Could not save the setting."
		return
	get_tree().reload_current_scene()
