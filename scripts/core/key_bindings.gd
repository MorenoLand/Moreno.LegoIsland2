class_name KeyBindings
extends RefCounted

const SETTINGS := "user://settings.cfg"

var actions: Array[Dictionary] = []
var names := {}
var codes := {}
var backup: Array[int] = []


func load_from_tables() -> void:
	for row in Table.rows("res://data/key_names.tsv"):
		if row.size() < 2:
			continue
		var scan := int(row[0])
		var text := String(row[1])
		names[scan] = text
		if not codes.has(text):
			codes[text] = scan
	for row in Table.rows("res://data/key_actions.tsv"):
		if row.size() < 5:
			continue
		actions.append({"name": String(row[1]), "fixed": int(row[2]),
			"value": int(row[3]), "mask": int(row[4])})
	var config := ConfigFile.new()
	if config.load(SETTINGS) == OK:
		for i in actions.size():
			actions[i].value = int(config.get_value("keys", "a%d" % i, actions[i].value))
	snapshot()


func snapshot() -> void:
	backup.clear()
	for a in actions:
		backup.append(int(a.value))


func revert() -> void:
	for i in actions.size():
		actions[i].value = backup[i]


func commit() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS)
	for i in actions.size():
		config.set_value("keys", "a%d" % i, int(actions[i].value))
	config.save(SETTINGS)
	snapshot()


func key_text(code: int) -> String:
	var device := code >> 16
	var scan := code & 0xFFFF
	if device == 0:
		return "MOUSE %d" % scan
	if device == 2:
		return "JOY %d" % scan
	return names.get(scan, names.get(-1, "---"))


func code_for_event(event: InputEventKey) -> int:
	var key := OS.get_keycode_string(event.keycode).to_upper()
	var right := event.location == KEY_LOCATION_RIGHT
	match key:
		"CTRL":
			key = "RCTRL" if right else "LCTRL"
		"SHIFT":
			key = "RSHIFT" if right else "LSHIFT"
		"ALT":
			key = "RALT" if right else "LALT"
		"ENTER":
			key = "RETURN"
		"ESC":
			key = "ESCAPE"
		"PAGE UP":
			key = "PAGEUP"
		"PAGE DOWN":
			key = "PAGEDOWN"
		"CAPS LOCK":
			key = "CAPSLOCK"
		"KP ENTER":
			key = "ENTER"
		"QUOTELEFT":
			key = "'"
		"APOSTROPHE":
			key = "'"
		"BACKSLASH":
			key = "\\"
		"BRACKETLEFT":
			key = "["
		"BRACKETRIGHT":
			key = "]"
		"SEMICOLON":
			key = ";"
		"MINUS":
			key = "-"
		"EQUAL":
			key = "="
		"COMMA":
			key = ","
		"PERIOD":
			key = "."
		"SLASH":
			key = "/"
	if key.begins_with("KP "):
		key = "NUM" + key.substr(3)
	if codes.has(key):
		return (1 << 16) | int(codes[key])
	return 0
