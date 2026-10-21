class_name SmfSong
extends DmSong

## A Standard MIDI File played through the same DLS bank and voice pool as the
## DirectMusic music.
##
## Confirmed in the game data: `sounds/z02LGI/MidiAmbient/` holds `Birds.mid`,
## `Birds'n'Bees.MID` and `Seagulls.mid` alongside a dedicated `DLS Birds.dls`
## (1,171,894 bytes). They are the town ambience - birdsong and gulls on the
## island - and nothing in the original port was playing them, which is a whole
## missing audio layer rather than a wrong note.
##
## Measured from the files themselves:
##   Birds.mid / Birds'n'Bees.MID - 87 notes, 79,728 ticks, 540540 us per quarter
##                                 (111 bpm), program 0, CC7 volume 99, CC10 pan 63
##   Seagulls.mid                 - 202 notes, 76,800 ticks, program 0, CC7 127, CC10 63
## Both are format 1 with a "Control Track" and a "Brds" track.
##
## These files are 768 ticks per quarter, which is the same as
## `DmSong.TICKS_PER_QUARTER`, so the player's clock arithmetic is reused unchanged.

const AMBIENT_DIR := "_data/sounds/z02LGI/MidiAmbient/"
const AMBIENT_DLS := AMBIENT_DIR + "DLS Birds.dls"
const DRUM_CHANNEL := 9


static func load_ambient(path: String) -> SmfSong:
	var bytes := Data.read(path)
	if bytes.size() < 14 or bytes.slice(0, 4).get_string_from_ascii() != "MThd":
		return null
	var song := SmfSong.new()
	song.directory = AMBIENT_DIR
	song.is_directmusic = false
	if not song._parse(bytes):
		return null
	song.bank = DlsBank.parse(Data.read(AMBIENT_DLS))
	if song.bank == null:
		return null
	if song.tempo <= 0.0:
		song.tempo = 120.0
	# Ambience loops forever.
	song.loops = -1
	return song


func _parse(bytes: PackedByteArray) -> bool:
	# The header's division is ticks per quarter note; DmPlayer's clock assumes
	# DmSong.TICKS_PER_QUARTER, so reject anything that would skew it rather than
	# silently playing at the wrong speed.
	var division := (bytes[12] << 8) | bytes[13]
	if division & 0x8000:
		return false  # SMPTE timecode, not ticks
	if division != DmSong.TICKS_PER_QUARTER:
		return false

	# channel -> {patch, pan, volume, transpose}
	var programs := {}
	var volumes := {}
	var pans := {}
	var note_ons := {}   # "ch:note" -> [tick, velocity]
	var events: Array = []
	var tempo_us := 0
	var end_tick := 0

	var at := 14
	while at + 8 <= bytes.size() and bytes.slice(at, at + 4).get_string_from_ascii() == "MTrk":
		var length := _be32(bytes, at + 4)
		var end: int = mini(at + 8 + length, bytes.size())
		var i := at + 8
		var tick := 0
		var running := -1
		while i < end:
			var delta := _vlq(bytes, i)
			i = int(delta[1])
			tick += int(delta[0])
			if i >= end:
				break
			var lead := bytes[i]

			# Meta event: variable length, and the only place tempo and the end of
			# track live.
			if lead == 0xFF:
				i += 1
				if i >= end:
					break
				var meta_type := bytes[i]
				i += 1
				var mlen := _vlq(bytes, i)
				var mstart := int(mlen[1])
				i = mstart + int(mlen[0])
				if meta_type == 0x51 and tempo_us == 0 and i - 3 >= mstart:
					tempo_us = (bytes[mstart] << 16) | (bytes[mstart + 1] << 8) | bytes[mstart + 2]
				elif meta_type == 0x2F:
					end_tick = maxi(end_tick, tick)
				continue

			# System exclusive: variable length, carries no notes.
			if lead == 0xF0 or lead == 0xF7:
				i += 1
				var slen := _vlq(bytes, i)
				i = int(slen[1]) + int(slen[0])
				continue

			# Channel voice message, honouring running status.
			var status := lead
			if status & 0x80:
				running = status
				i += 1
			elif running >= 0:
				status = running
			else:
				break
			if i >= end:
				break
			var kind := status & 0xF0
			var channel := status & 0x0F
			var needed := 2
			if kind == 0xC0 or kind == 0xD0:
				needed = 1
			if i + needed > end:
				break
			var a := bytes[i]
			var b := 0
			if needed == 2:
				b = bytes[i + 1]
			i += needed

			if kind == 0x90 and b > 0:
				note_ons["%d:%d" % [channel, a]] = [tick, b]
			elif (kind == 0x80 or (kind == 0x90 and b == 0)):
				var key := "%d:%d" % [channel, a]
				if key in note_ons:
					var start: Array = note_ons[key]
					note_ons.erase(key)
					if tick > int(start[0]):
						events.append({
							"tick": int(start[0]),
							"duration": tick - int(start[0]),
							"channel": channel,
							"value": a,
							"velocity": int(start[1]),
							"mode": 0x0E,
							"level": 0,
						})
			elif kind == 0xC0:
				programs[channel] = a
			elif kind == 0xB0:
				if a == 7:
					volumes[channel] = b
				elif a == 10:
					pans[channel] = b
		at = end

	if tempo_us > 0:
		tempo = 60_000_000.0 / float(tempo_us)

	for channel in programs:
		# A Standard MIDI File carries "drum" in the channel (channel 9 is the
		# General MIDI percussion channel), not in the patch word the way a
		# DirectMusic band does. DmPlayer reads the flag from bit 31 of the patch,
		# so set it here - without it, "DLS Birds.dls" (one drum instrument,
		# `insh` = 0x80000001) never matches and the whole ambience is silent.
		var patch := int(programs[channel])
		if int(channel) == DRUM_CHANNEL:
			patch |= 0x80000000
		instruments[channel] = {
			"patch": patch,
			"pan": int(pans.get(channel, 64)),
			"volume": int(volumes.get(channel, 100)),
			"transpose": 0,
		}

	# A note still sounding when the track ends gets a tail rather than nothing.
	length = maxi(end_tick, 1)
	for key in note_ons:
		var st: Array = note_ons[key]
		var parts := String(key).split(":")
		events.append({
			"tick": int(st[0]),
			"duration": maxi(length - int(st[0]), 1),
			"channel": int(parts[0]),
			"value": int(parts[1]),
			"velocity": int(st[1]),
			"mode": 0x0E,
			"level": 0,
		})
	events.sort_custom(func(x, y): return int(x.tick) < int(y.tick))
	self.events = events
	return events.size() > 0


## A Standard MIDI note-on carries the note directly, so there is nothing to
## decode the way the DirectMusic note format needs.
func midi_note(value: int, _level: int, _tick: int) -> int:
	return value


static func _be32(b: PackedByteArray, at: int) -> int:
	return (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3]


static func _vlq(b: PackedByteArray, at: int) -> Array:
	var value := 0
	while at < b.size():
		var byte := b[at]
		at += 1
		value = (value << 7) | (byte & 0x7F)
		if byte & 0x80 == 0:
			break
	return [value, at]