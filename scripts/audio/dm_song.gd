class_name DmSong
extends RefCounted

const TICKS_PER_QUARTER := 768

var tempo := 0.0
var length := 0
# False for a Standard MIDI File (see SmfSong), which has no patterns or groove -
# DmPlayer checks this rather than the concrete type so the two audio formats do
# not have to know about each other.
var is_directmusic := true
var loops := 0
var events: Array = []
# Pattern channels whose part could not be found in the style, and how many were
# matched. A part that does not match is dropped whole, which sounds like a
# missing instrument.
var channels_matched := 0
var channels_missing := 0
var style_parts := 0
# Where the note events actually came from: the segment's own evtl sequences, or
# the .sty patterns it loads.
var events_from_sequence := 0
var events_from_patterns := 0
var base_groove_offset := 0
var _event_sets := {}
var instruments := {}
var bank: DlsBank
var chords: Array = []
var directory := ""
var dls_name := ""
var style_entries: Array = []
var commands: Array = []
var _style_cache := {}


static func load_segment(path: String, fallback_bank := "") -> DmSong:
	var bytes := Data.read(path)
	if bytes.size() < 12 or bytes.slice(8, 12).get_string_from_ascii() != "DMSG":
		return null
	var song := DmSong.new()
	song.directory = path.get_base_dir()
	var top := Riff.children(bytes, 12, bytes.size())
	var segh := Riff.find(top, "segh")
	if not segh.is_empty():
		song.loops = bytes.decode_u32(segh.start)
		song.length = bytes.decode_u32(segh.start + 4)
	var tracks := Riff.find(top, "LIST", "trkl")
	if tracks.is_empty():
		return null
	for track in Riff.children(bytes, tracks.start, tracks.end):
		if track.tag != "RIFF" or track.form != "DMTK":
			continue
		for item in Riff.children(bytes, track.start, track.end):
			if item.tag == "tetr" and song.tempo <= 0.0:
				song.tempo = bytes.decode_double(item.start + 12)
			elif item.tag == "LIST" and item.form == "cord":
				song._read_chords(bytes, item)
			elif item.tag == "LIST" and item.form == "sttr":
				song._read_style_track(bytes, item)
			elif item.tag == "cmnd":
				song._read_commands(bytes, item)
			elif item.tag == "seqt":
				song._read_sequence(bytes, item)
			elif item.tag == "RIFF" and item.form == "DMBT":
				song._walk_band(bytes, item.start, item.end)
	if song.style_entries.is_empty() and song.events.is_empty():
		return null
	if song.dls_name != "":
		song.bank = DlsBank.parse(Data.read(song.directory.path_join(song.dls_name)))
	if song.bank == null and fallback_bank != "":
		song.bank = DlsBank.parse(Data.read(song.directory.path_join(fallback_bank)))
	song._build_events()
	return song


func _first_reference_file(bytes: PackedByteArray, start: int, end: int) -> String:
	for item in Riff.children(bytes, start, end):
		if item.tag == "LIST" and item.form == "DMRF":
			var file := Riff.find(Riff.children(bytes, item.start, item.end), "file")
			if not file.is_empty():
				return Riff.utf16(bytes, file.start, file.end)
		elif item.tag == "LIST" or item.tag == "RIFF":
			var inner := _first_reference_file(bytes, item.start, item.end)
			if inner != "":
				return inner
	return ""


func _walk_band(bytes: PackedByteArray, start: int, end: int) -> void:
	for item in Riff.children(bytes, start, end):
		if item.tag == "LIST" and item.form == "lbin":
			var parts := Riff.children(bytes, item.start, item.end)
			var bins := Riff.find(parts, "bins")
			if bins.is_empty():
				continue
			var channel := bytes.decode_u32(bins.start + 24)
			instruments[channel] = {
				"patch": bytes.decode_u32(bins.start),
				"pan": bytes.decode_u8(bins.start + 32),
				"volume": bytes.decode_u8(bins.start + 33),
				"transpose": bytes.decode_s8(bins.start + 34),
			}
			var ref := _first_reference_file(bytes, item.start, item.end)
			if ref != "" and dls_name == "":
				dls_name = ref
		elif item.tag == "LIST" or item.tag == "RIFF":
			_walk_band(bytes, item.start, item.end)


func _read_chords(bytes: PackedByteArray, list: Dictionary) -> void:
	var crdb := Riff.find(Riff.children(bytes, list.start, list.end), "crdb")
	if crdb.is_empty():
		return
	var at: int = crdb.start
	var chord_size := bytes.decode_u32(at)
	at += 4
	while at + chord_size + 8 <= crdb.end:
		var time := bytes.decode_s32(at + 32)
		var count := bytes.decode_u32(at + chord_size)
		var sub_size := bytes.decode_u32(at + chord_size + 4)
		var sub_at := at + chord_size + 8
		var subs: Array = []
		for k in count:
			var s := sub_at + k * sub_size
			subs.append({
				"chord": bytes.decode_u32(s),
				"scale": bytes.decode_u32(s + 4),
				"levels": bytes.decode_u32(s + 12),
				"chord_root": bytes.decode_u8(s + 16),
				"scale_root": bytes.decode_u8(s + 17),
			})
		chords.append({"time": time, "subs": subs})
		at = sub_at + count * sub_size
	chords.sort_custom(func(a, b): return a.time < b.time)


func _read_style_track(bytes: PackedByteArray, list: Dictionary) -> void:
	for entry in Riff.children(bytes, list.start, list.end):
		if entry.tag == "LIST" and entry.form == "strf":
			var kids := Riff.children(bytes, entry.start, entry.end)
			var stmp := Riff.find(kids, "stmp")
			var file := _first_reference_file(bytes, entry.start, entry.end)
			if not stmp.is_empty() and file != "":
				style_entries.append({"time": bytes.decode_u32(stmp.start), "file": file})
	style_entries.sort_custom(func(a, b): return a.time < b.time)


func _read_sequence(bytes: PackedByteArray, item: Dictionary) -> void:
	for chunk in Riff.children(bytes, item.start, item.end):
		if chunk.tag != "evtl":
			continue
		var size := bytes.decode_u32(chunk.start)
		if size < 17:
			continue
		var count: int = (chunk.end - chunk.start - 4) / size
		for k in count:
			var at: int = chunk.start + 4 + k * size
			if bytes.decode_u8(at + 14) & 0xF0 != 0x90:
				continue
			var velocity := bytes.decode_u8(at + 16)
			if velocity == 0:
				continue
			events.append({
				"tick": maxi(bytes.decode_s32(at) + bytes.decode_s16(at + 12), 0),
				"duration": maxi(bytes.decode_s32(at + 4), 1),
				"channel": bytes.decode_u32(at + 8),
				"value": bytes.decode_u8(at + 15),
				"velocity": velocity,
				"level": 0,
				"mode": 0,
			})


func _read_commands(bytes: PackedByteArray, item: Dictionary) -> void:
	var size := bytes.decode_u32(item.start)
	if size < 9:
		return
	var count: int = (item.end - item.start - 4) / size
	for k in count:
		var at: int = item.start + 4 + k * size
		commands.append({"time": bytes.decode_s32(at), "groove": bytes.decode_u8(at + 8)})
	commands.sort_custom(func(a, b): return a.time < b.time)


func _groove_at(tick: int) -> int:
	var level := 1
	for command in commands:
		if command.time <= tick:
			level = maxi(int(command.groove), 1)
	return level


func events_for(offset: int) -> Array:
	if offset == base_groove_offset:
		return events
	if not _event_sets.has(offset):
		var saved := events
		events = []
		_fill_events(offset)
		_event_sets[offset] = events
		events = saved
	return _event_sets[offset]


func _build_events() -> void:
	var sequenced := events.duplicate()
	events = []
	_fill_events(0)
	events_from_patterns = events.size()
	events.append_array(sequenced)
	events_from_sequence = sequenced.size()
	if length <= 0:
		for e in events:
			length = maxi(length, int(e.tick) + int(e.duration))
	events.sort_custom(func(a, b): return a.tick < b.tick)


func _fill_events(offset: int) -> void:
	for i in style_entries.size():
		var start: int = style_entries[i].time
		var finish: int = style_entries[i + 1].time if i + 1 < style_entries.size() else length
		if length <= 0 and i + 1 >= style_entries.size():
			finish = start
		_add_pattern(directory.path_join(style_entries[i].file), maxi(_groove_at(start) + offset, 1), start, finish - start, offset)
	events.sort_custom(func(a, b): return a.tick < b.tick)


func _style(path: String) -> Dictionary:
	if _style_cache.has(path):
		return _style_cache[path]
	var bytes := Data.read(path)
	var out := {}
	if bytes.size() > 12 and bytes.slice(8, 12).get_string_from_ascii() == "DMST":
		var top := Riff.children(bytes, 12, bytes.size())
		var styh := Riff.find(top, "styh")
		var beats := bytes.decode_u8(styh.start)
		var beat_unit := maxi(bytes.decode_u8(styh.start + 1), 1)
		var grids := maxi(bytes.decode_u16(styh.start + 2), 1)
		out = {
			"bytes": bytes,
			"top": top,
			"measure": beats * TICKS_PER_QUARTER * 4 / beat_unit,
			"grid": TICKS_PER_QUARTER * 4 / beat_unit / grids,
			"tempo": bytes.decode_double(styh.start + 4),
			"parts": {},
		}
		for item in Riff.find_all(top, "LIST", "part"):
			var kids := Riff.children(bytes, item.start, item.end)
			var prth := Riff.find(kids, "prth")
			out.parts[bytes.slice(prth.start + 132, prth.start + 148)] = Riff.find(kids, "note")
		style_parts = out.parts.size()
	_style_cache[path] = out
	return out


func _add_pattern(path: String, groove: int, start: int, span: int, groove_offset: int = 0) -> void:
	var style := _style(path)
	if style.is_empty() or span <= 0:
		return
	var bytes: PackedByteArray = style.bytes
	if tempo <= 0.0:
		tempo = style.tempo
	# A style stores each bar of the arrangement as its own one-measure pattern and
	# uses the groove field as a sequence index: TownTheme.sty holds 18 patterns
	# with grooves 1..18 (414 channels between them), Town Main 19.sty holds 3 with
	# grooves 1..3. So the span has to be walked one measure at a time, asking the
	# groove track which pattern is in force. Picking a single pattern and holding
	# it for the whole span plays only the first bar.
	var by_groove := {}
	for item in Riff.find_all(style.top, "LIST", "pttn"):
		var ptnh := Riff.find(Riff.children(bytes, item.start, item.end), "ptnh")
		if ptnh.is_empty():
			continue
		if (bytes.decode_u16(ptnh.start + 6) & 0xFF) != 0:
			continue
		by_groove[bytes.decode_u8(ptnh.start + 4)] = {
			"item": item,
			"measures": bytes.decode_u16(ptnh.start + 8),
		}
	if by_groove.is_empty():
		return
	var measure: int = maxi(int(style.measure), 1)
	var at := 0
	var guard := 0
	while at < span and guard < 4096:
		guard += 1
		var level := groove if at == 0 else maxi(_groove_at(start + at) + groove_offset, 1)
		var picked: Dictionary = by_groove.get(level, {})
		if picked.is_empty():
			# No pattern carries this groove level: hold the nearest one in force.
			var best := 1 << 30
			for g in by_groove:
				var d: int = absi(int(g) - level)
				if d < best:
					best = d
					picked = by_groove[g]
		if picked.is_empty():
			return
		var length: int = mini(maxi(int(picked["measures"]) * measure, 1), span - at)
		_emit_pattern(bytes, style, picked["item"], start + at, length, length)
		at += length


func _emit_pattern(bytes: PackedByteArray, style: Dictionary, p: Dictionary, start: int,
		span: int, pattern_ticks: int) -> void:
	for ref in Riff.find_all(Riff.children(bytes, p.start, p.end), "LIST", "pref"):
		var prfc := Riff.find(Riff.children(bytes, ref.start, ref.end), "prfc")
		var guid := bytes.slice(prfc.start, prfc.start + 16)
		var channel := bytes.decode_u16(prfc.start + 16)
		var level := bytes.decode_u8(prfc.start + 19)
		var note: Dictionary = style.parts.get(guid, {})
		if note.is_empty():
			channels_missing += 1
			continue
		channels_matched += 1
		var struct_size := bytes.decode_u32(note.start)
		var count: int = (note.end - note.start - 4) / struct_size
		for k in count:
			var at: int = note.start + 4 + k * struct_size
			var tick: int = bytes.decode_s32(at) * int(style.grid) + bytes.decode_s16(at + 12)
			if tick < 0:
				tick = 0
			var play_mode := bytes.decode_u8(at + 21) if struct_size > 21 else 0x0E
			var rep := 0
			while rep < span:
				var absolute := start + rep + tick
				if rep + tick < span:
					events.append({
						"tick": absolute,
						"duration": maxi(bytes.decode_s32(at + 8), 1),
						"channel": channel,
						"value": bytes.decode_u16(at + 14),
						"velocity": bytes.decode_u8(at + 16),
						"level": level,
						"mode": play_mode,
					})
				rep += pattern_ticks


func midi_note(value: int, level: int, tick: int) -> int:
	var octave := (value >> 12) & 0xF
	var position := (value >> 8) & 0xF
	var offset := (value >> 4) & 0xF
	var accidental := value & 0xF
	if accidental > 7:
		accidental -= 16
	var chord := {"chord": 0x91, "scale": 0xAB5AB5, "chord_root": 12, "levels": 0xF}
	var active: Array = []
	for item in chords:
		if item.time <= tick or active.is_empty():
			active = item.subs
	for sub in active:
		if (int(sub.levels) & (1 << level)) != 0:
			chord = sub
			break
	var tones: Array = []
	var scale_tones: Array = []
	for bit in 12:
		if (int(chord.chord) & (1 << bit)) != 0:
			tones.append(bit)
		if (int(chord.scale) & (1 << bit)) != 0:
			scale_tones.append(bit)
	if tones.is_empty():
		tones = [0]
	if scale_tones.is_empty():
		scale_tones = [0, 2, 4, 5, 7, 9, 11]
	if tones.size() < 4:
		var root_index := 0
		for i in scale_tones.size():
			if scale_tones[i] <= tones[0] % 12:
				root_index = i
		var seventh: int = scale_tones[(root_index + 6) % scale_tones.size()]
		var interval: int = (seventh - tones[0] % 12 + 12) % 12
		if interval > int(tones[tones.size() - 1]):
			tones.append(interval)
	var base: int = tones[position % tones.size()] + 12 * (position / tones.size())
	var pitch_class: int = base % 12
	var index := 0
	for i in scale_tones.size():
		if scale_tones[i] <= pitch_class:
			index = i
	index += offset
	var scale_note: int = scale_tones[index % scale_tones.size()] + 12 * (index / scale_tones.size())
	return octave * 12 + (base / 12) * 12 + scale_note + accidental + (int(chord.chord_root) % 12)
