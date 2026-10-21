class_name Table
extends RefCounted

## Reads the small tab separated tables under res://data. The first line is a
## header and is skipped; every following non-empty line is split on tabs.

static func rows(path: String) -> Array:
	var out: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("missing table: " + path)
		return out
	file.get_line()
	while not file.eof_reached():
		var line := file.get_line()
		if line != "":
			out.append(line.split("\t"))
	return out


static func column(path: String, at: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for row in rows(path):
		if row.size() > at:
			out.append(int(row[at]))
	return out


static func field(path: String, at: int) -> PackedStringArray:
	var out := PackedStringArray()
	for row in rows(path):
		if row.size() > at:
			out.append(String(row[at]))
	return out