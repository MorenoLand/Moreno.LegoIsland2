class_name Riff
extends RefCounted


static func children(bytes: PackedByteArray, start: int, end: int) -> Array:
	var out := []
	var at := start
	while at + 8 <= end:
		var tag := bytes.slice(at, at + 4).get_string_from_ascii()
		var size := bytes.decode_u32(at + 4)
		var item := {"tag": tag, "size": size, "form": ""}
		if tag == "RIFF" or tag == "LIST":
			item["form"] = bytes.slice(at + 8, at + 12).get_string_from_ascii()
			item["start"] = at + 12
		else:
			item["start"] = at + 8
		item["end"] = mini(at + 8 + size, end)
		out.append(item)
		at += 8 + size + (size & 1)
	return out


static func find(items: Array, tag: String, form := "") -> Dictionary:
	for item in items:
		if item.tag == tag and (form == "" or item.form == form):
			return item
	return {}


static func find_all(items: Array, tag: String, form := "") -> Array:
	var out := []
	for item in items:
		if item.tag == tag and (form == "" or item.form == form):
			out.append(item)
	return out


static func utf16(bytes: PackedByteArray, start: int, end: int) -> String:
	var text := ""
	var at := start
	while at + 2 <= end:
		var c := bytes.decode_u16(at)
		if c == 0:
			break
		text += String.chr(c)
		at += 2
	return text
