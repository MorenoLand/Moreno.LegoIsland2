class_name Wav
extends RefCounted


static func parse(bytes: PackedByteArray) -> AudioStreamWAV:
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	var channels := 1
	var rate := 22050
	var bits := 16
	var pos := 12
	var pcm := PackedByteArray()
	while pos + 8 <= bytes.size():
		var tag := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var length := bytes.decode_u32(pos + 4)
		var body := pos + 8
		if tag == "fmt ":
			var format := bytes.decode_u16(body)
			if format != 1:
				return null
			channels = bytes.decode_u16(body + 2)
			rate = bytes.decode_u32(body + 4)
			bits = bytes.decode_u16(body + 14)
		elif tag == "data":
			pcm = bytes.slice(body, mini(body + length, bytes.size()))
			break
		pos = body + length + (length & 1)
	if pcm.is_empty() or (bits != 16 and bits != 8):
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
	stream.stereo = channels == 2
	stream.mix_rate = rate
	if bits == 8:
		var signed := PackedByteArray()
		signed.resize(pcm.size())
		for i in pcm.size():
			signed[i] = (pcm[i] - 128) & 0xFF
		pcm = signed
	stream.data = pcm
	return stream
