class_name DlsBank
extends RefCounted

const CONN_EG1_ATTACK := 0x206
const CONN_EG1_DECAY := 0x207
const CONN_EG1_RELEASE := 0x209
const CONN_EG1_SUSTAIN := 0x20A
const CONN_FILTER_CUTOFF := 0x500

var bytes := PackedByteArray()
var instruments: Array = []
var wave_offsets := PackedInt32Array()
var wave_base := 0
var _waves := {}


static func parse(data: PackedByteArray) -> DlsBank:
	if data.size() < 12 or data.slice(0, 4).get_string_from_ascii() != "RIFF" or data.slice(8, 12).get_string_from_ascii() != "DLS ":
		return null
	var bank := DlsBank.new()
	bank.bytes = data
	var top := Riff.children(data, 12, data.size())
	var wvpl := Riff.find(top, "LIST", "wvpl")
	if not wvpl.is_empty():
		bank.wave_base = wvpl.start
		# Wave index is the ordinal position of the LIST 'wave' chunk in 'wvpl'.
		# Measured across all 31 DLS files in the game: every one of them stores a
		# 'ptbl' whose first u32 is the wave COUNT and whose remaining entries are
		# not a plain index table, so reading 'ptbl' as one both truncates the
		# bank to 8 waves and shifts every index. Scanning 'wvpl' is unambiguous.
		for child in Riff.children(data, wvpl.start, wvpl.end):
			if child.tag == "LIST" and child.form == "wave":
				# Relative to 'wvpl', pointing at the chunk header, because wave()
				# adds wave_base back on.
				bank.wave_offsets.append(child.start - 12 - wvpl.start)
	var lins := Riff.find(top, "LIST", "lins")
	if not lins.is_empty():
		for ins in Riff.children(data, lins.start, lins.end):
			if ins.tag == "LIST" and ins.form == "ins ":
				bank.instruments.append(bank._parse_instrument(ins))
	return bank


func _parse_instrument(ins: Dictionary) -> Dictionary:
	var parts := Riff.children(bytes, ins.start, ins.end)
	var insh := Riff.find(parts, "insh")
	var bank_value := bytes.decode_u32(insh.start + 4)
	var out := {
		"bank": bank_value & 0x7F7F,
		"drum": (bank_value & 0x80000000) != 0,
		"program": bytes.decode_u32(insh.start + 8),
		"regions": [],
		"art": _parse_art(parts),
	}
	var lrgn := Riff.find(parts, "LIST", "lrgn")
	if not lrgn.is_empty():
		for rgn in Riff.children(bytes, lrgn.start, lrgn.end):
			if rgn.tag == "LIST" and rgn.form == "rgn ":
				out.regions.append(_parse_region(rgn, out.art))
	return out


func _parse_region(rgn: Dictionary, inherited: Dictionary) -> Dictionary:
	var parts := Riff.children(bytes, rgn.start, rgn.end)
	var rgnh := Riff.find(parts, "rgnh")
	var wlnk := Riff.find(parts, "wlnk")
	var region := {
		"key_low": bytes.decode_u16(rgnh.start),
		"key_high": bytes.decode_u16(rgnh.start + 2),
		"vel_low": bytes.decode_u16(rgnh.start + 4),
		"vel_high": bytes.decode_u16(rgnh.start + 6),
		"wave": bytes.decode_u32(wlnk.start + 8),
		"unity": -1,
		"fine": 0,
		"attenuation": 0.0,
		"loop_start": -1,
		"loop_length": 0,
		"art": inherited,
	}
	var wsmp := Riff.find(parts, "wsmp")
	if not wsmp.is_empty():
		_read_wsmp(wsmp.start, region, wsmp.end)
	var own := _parse_art(parts)
	if not own.is_empty():
		region.art = own
	return region


func _read_wsmp(at: int, target: Dictionary, limit: int = -1) -> void:
	# DLS sample chunk:
	#   +0 cbSize  +4 usUnity  +6 sPitchFraction  +8 lSampleDataSize
	#   +12 cSampleLoop  +16 ulSampleDataOffset  +20 first loop record
	#   loop record: +0 ulLoopType  +4 ulLoopStart  +8 ulLoopLength
	# The loop count is at +12, NOT +16 (+16 is the data offset), so reading it
	# there made every sample look like it had a loop, and then the start and
	# length were taken from the wrong words - the "start" was the loop LENGTH.
	# Some chunks here are only 20 bytes yet claim one loop, so the loop array is
	# simply not there; reading anyway pulled bytes out of the next chunk.
	if limit < 0:
		limit = bytes.size()
	target.unity = bytes.decode_u16(at + 4)
	target.fine = bytes.decode_s16(at + 6)
	target.attenuation = bytes.decode_s32(at + 8) / 65536.0
	var loops := bytes.decode_u32(at + 12)
	if loops > 0 and at + 32 <= limit:
		target.loop_start = bytes.decode_u32(at + 24)
		target.loop_length = bytes.decode_u32(at + 28)


func _parse_art(parts: Array) -> Dictionary:
	var art := {}
	var lart := Riff.find(parts, "LIST", "lart")
	if lart.is_empty():
		return art
	for chunk in Riff.children(bytes, lart.start, lart.end):
		if chunk.tag != "art1" and chunk.tag != "art2":
			continue
		var count := bytes.decode_u32(chunk.start + 4)
		for k in count:
			var at: int = chunk.start + 8 + k * 12
			var dst := bytes.decode_u16(at + 4)
			var scale := bytes.decode_s32(at + 8)
			art[dst] = scale
	return art


func find_instrument(bank: int, program: int, drum := false) -> Dictionary:
	for ins in instruments:
		if ins.bank == bank and ins.program == program and ins.drum == drum:
			return ins
	for ins in instruments:
		if ins.program == program and ins.drum == drum:
			return ins
	return {}


func find_region(instrument: Dictionary, key: int, velocity: int) -> Dictionary:
	for region in instrument.get("regions", []):
		if key >= region.key_low and key <= region.key_high and velocity >= region.vel_low and velocity <= region.vel_high:
			return region
	return {}


func wave(index: int) -> Dictionary:
	if _waves.has(index):
		return _waves[index]
	var result := {}
	if index >= 0 and index < wave_offsets.size():
		var at := wave_base + wave_offsets[index]
		var form := bytes.slice(at + 8, at + 12).get_string_from_ascii()
		if bytes.slice(at, at + 4).get_string_from_ascii() == "LIST" and form == "wave":
			var size := bytes.decode_u32(at + 4)
			var parts := Riff.children(bytes, at + 12, at + 8 + size)
			var fmt := Riff.find(parts, "fmt ")
			var data := Riff.find(parts, "data")
			if not fmt.is_empty() and not data.is_empty() and bytes.decode_u16(fmt.start) == 1 and bytes.decode_u16(fmt.start + 14) == 16 and bytes.decode_u16(fmt.start + 2) == 1:
				var stream := AudioStreamWAV.new()
				stream.format = AudioStreamWAV.FORMAT_16_BITS
				stream.mix_rate = bytes.decode_u32(fmt.start + 4)
				stream.data = bytes.slice(data.start, data.end)
				result = {"stream": stream, "unity": 60, "fine": 0, "attenuation": 0.0, "loop_start": -1, "loop_length": 0, "frames": (data.end - data.start) / 2}
				var wsmp := Riff.find(parts, "wsmp")
				if not wsmp.is_empty():
					_read_wsmp(wsmp.start, result, wsmp.end)
	_waves[index] = result
	return result


static func seconds(scale: int) -> float:
	if scale == -2147483648:
		return 0.0
	return pow(2.0, float(scale) / 65536.0 / 1200.0)
