extends Node

const VAR_COUNT := 0x4FC / 4
const VAR_FIRST_BLOCK := 15
const BLOCK_BYTES := 0x370
const SAVE_BYTES := 0x4C0
const SLOTS := 7
const MARK_HEADER := 0x0D
const MARK_HEADER_END := 0x08088008
const MARK_VARS_END := 0x0F0FF00F
const MARK_OBJECTS_BEGIN := 0x0E0EE00E
const MARK_ZONE := 0x0A0AA00A
const MARK_ACTORS := 0x0D0DD00D
const CHECKSUM_TAIL := 8
const CHECKSUM_MARK_GAP := 12

const VAR_ZONE := 5
const VAR_NEXT_ZONE := 0x59
const VAR_STATE := 0x58
const VAR_PREVIOUS_ZONE := 0xA3

## The option screens' values. CONFIRMED defaults from the exe's settings reset
## (FUN_004040cc slots): music 0x50, sound 0x50, speech volume 0x50, speech on 1,
## subtitles on 1, high detail 1, joystick 1, mouse 0x2d, fog distance 0x32.
## Slot writes: menu 11 -> slots 0/1/0x16, menu 12 -> slots 2/3, menu 10 -> 0x15/0x12,
## menu 9 -> 0x13/0x14 (FUN_00420152 handler in chunk_0023).
signal options_changed
const OPTIONS_PATH := "user://options.cfg"
const OPTION_ITEMS := {"!FEMUSVOL": "music", "!FESNDVOL": "sound", "!FESPCVOL": "speech_volume",
	"!FOG": "fog", "!GraphM1": "detail", "!FESPEECH": "speech", "!FESUBTLE": "subtitles",
	"!CtrlM2": "joystick", "!FEMOUSEN": "mouse"}
const AUDIO_BUSES := {"Music": "music", "Sound": "sound", "Speech": "speech_volume"}
var options := {"music": 80, "sound": 80, "speech_volume": 80, "fog": 50, "detail": 1,
	"speech": 1, "subtitles": 1, "joystick": 1, "mouse": 45}
var vars := PackedInt32Array()
var slot := -1
var pending_zone := -1
var pending_zone_code := ""
var state_keys: Array[String] = []


func _init() -> void:
	# _init, not _ready: _ready does not run until the node enters the tree, so
	# anything touching vars before that would be silently reading and writing a
	# zero-length array - set_var/get_var both become no-ops with no error.
	vars.resize(VAR_COUNT)
	_load_options()


func _ready() -> void:
	for bus_name in AUDIO_BUSES:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var at := AudioServer.bus_count - 1
			AudioServer.set_bus_name(at, bus_name)
			AudioServer.set_bus_send(at, "Master")
	apply_audio()


func option(key: String) -> int:
	return int(options.get(key, 0))


## Stores an option from its screen. The cut-scene screen keeps at least one of
## speech and subtitles on (the exe flips the other one back on).
func set_option(key: String, value: int) -> void:
	options[key] = value
	if key == "speech" and value == 0 and option("subtitles") == 0:
		options["subtitles"] = 1
	elif key == "subtitles" and value == 0 and option("speech") == 0:
		options["speech"] = 1
	_save_options()
	apply_audio()
	options_changed.emit()


func apply_audio() -> void:
	for bus_name in AUDIO_BUSES:
		var at := AudioServer.get_bus_index(bus_name)
		if at >= 0:
			var linear := clampf(float(option(AUDIO_BUSES[bus_name])) / 80.0, 0.0001, 2.0)
			AudioServer.set_bus_volume_db(at, linear_to_db(linear))


func _load_options() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(OPTIONS_PATH) != OK:
		return
	for key in options.keys():
		options[key] = int(cfg.get_value("options", key, options[key]))


func _save_options() -> void:
	var cfg := ConfigFile.new()
	for key in options.keys():
		cfg.set_value("options", key, options[key])
	cfg.save(OPTIONS_PATH)


func read_state_keys() -> void:
	state_keys.clear()
	for row in Table.rows("res://data/state_keys.tsv"):
		if row.size() >= 2:
			state_keys.append(String(row[1]))


func get_var(index: int) -> int:
	return vars[index] if index >= 0 and index < vars.size() else 0


func set_var(index: int, value: int) -> void:
	if index >= 0 and index < vars.size():
		vars[index] = value


func new_game(on_slot: int) -> void:
	vars.fill(0)
	var template := Data.read("_data/SaveDef.lgo")
	if template.size() >= 24 + SAVE_BYTES and template.decode_u32(4) == MARK_HEADER and template.decode_u32(20) == MARK_HEADER_END:
		for i in SAVE_BYTES / 4:
			if VAR_FIRST_BLOCK + i < vars.size():
				vars[VAR_FIRST_BLOCK + i] = template.decode_s32(24 + i * 4)
	else:
		var bytes := Data.read("_data/sw.dat")
		for i in mini(BLOCK_BYTES, bytes.size()) / 4:
			vars[VAR_FIRST_BLOCK + i] = bytes.decode_s32(i * 4)
		set_var(0x4F, 0xB)
		set_var(0xB0, 0xB)
		set_var(0xB3, 0)
		set_var(0xB4, 0)
		set_var(0xB5, 1)
		set_var(0x26, 0)
	slot = on_slot
	set_var(VAR_ZONE, 2)
	# A new island campaign starts at story state 2 (zone 2, z02LGI). The exe's
	# own level-reset path FUN_00414819 writes exactly that pair, and state 2 is
	# the island's first state; the park prologue (states 0-1) is not ported, so
	# the menu opens in the island at state 2.
	set_var(VAR_STATE, 2)


func save_dir() -> String:
	return "user://saves"


func save_path(index: int) -> String:
	return save_dir().path_join("Save%02d.lgo" % index)


func slot_info(index: int) -> Dictionary:
	var file := FileAccess.open(save_path(index), FileAccess.READ)
	if file == null or file.get_length() < 24:
		return {}
	var head := file.get_buffer(24)
	if head.decode_u32(4) != MARK_HEADER or head.decode_u32(20) != MARK_HEADER_END:
		return {}
	return {"zone": head.decode_s32(8), "time": head.decode_u32(12), "state": head.decode_s32(16)}


func slot_label(index: int, messages: Dictionary) -> String:
	var info := slot_info(index)
	if info.is_empty():
		return "<unused>"
	var state: int = info.state
	if state < 0 or state >= state_keys.size():
		return "<unused>"
	return messages.get(state_keys[state], state_keys[state])


func save(index: int) -> bool:
	DirAccess.make_dir_recursive_absolute(save_dir())
	var body := PackedByteArray()
	body.resize(4)
	body.encode_u32(0, MARK_HEADER)
	var resume := get_var(VAR_NEXT_ZONE)
	if resume <= 0:
		resume = get_var(VAR_ZONE)
	body.append_array(_u32(resume))
	body.append_array(_u32(int(Time.get_unix_time_from_system())))
	body.append_array(_u32(get_var(VAR_STATE)))
	body.append_array(_u32(MARK_HEADER_END))
	for i in SAVE_BYTES / 4:
		body.append_array(_u32(vars[VAR_FIRST_BLOCK + i] if VAR_FIRST_BLOCK + i < vars.size() else 0))
	body.append_array(_u32(MARK_VARS_END))
	var template := Data.read("_data/SaveDef.lgo")
	var tail_start := 24 + SAVE_BYTES + 4
	var template_size := template.decode_u32(0) if template.size() >= 4 else 0
	if template.size() >= template_size and template_size > tail_start:
		body.append_array(template.slice(tail_start, template_size))
	var out := PackedByteArray()
	out.append_array(_u32(body.size() + 4))
	out.append_array(body)
	_seal(out)
	var file := FileAccess.open(save_path(index), FileAccess.WRITE)
	if file == null:
		return false
	if template.size() > out.size():
		out.resize(template.size())
	file.store_buffer(out)
	return true


func _seal(out: PackedByteArray) -> void:
	var total := out.size()
	if total < CHECKSUM_TAIL + 8:
		return
	var sum := 0
	var at := 8
	while at < total - CHECKSUM_MARK_GAP:
		sum ^= out.decode_u32(at)
		at += 4
	out.encode_u32(total - CHECKSUM_TAIL, sum)


func load_slot(index: int) -> bool:
	var file := FileAccess.open(save_path(index), FileAccess.READ)
	if file == null:
		return false
	var bytes := file.get_buffer(file.get_length())
	if bytes.size() < 24 + SAVE_BYTES or bytes.decode_u32(4) != MARK_HEADER or bytes.decode_u32(20) != MARK_HEADER_END:
		return false
	vars.fill(0)
	for i in SAVE_BYTES / 4:
		if VAR_FIRST_BLOCK + i < vars.size():
			vars[VAR_FIRST_BLOCK + i] = bytes.decode_s32(24 + i * 4)
	set_var(VAR_NEXT_ZONE, bytes.decode_s32(8))
	set_var(VAR_STATE, bytes.decode_s32(16))
	slot = index
	return true


func erase(index: int) -> void:
	# Go through the DirAccess instance, not DirAccess.remove_absolute on a
	# globalised path. On the web export user:// is a virtual filesystem backed
	# by IndexedDB, and an absolute OS path simply is not there to remove, so
	# the slot came back after "deleting" it. DirAccess.remove() is routed
	# through the same VFS the write went through.
	var dir := DirAccess.open(save_dir())
	if dir == null:
		return
	dir.remove(save_path(index).get_file())


func erase_all() -> void:
	for i in SLOTS:
		erase(i)


func _u32(value: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_u32(0, value & 0xFFFFFFFF)
	return b
