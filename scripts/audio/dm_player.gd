class_name DmPlayer
extends Node

const MAX_VOICES := 128
const SILENT_DB := -70.0
const MIN_RELEASE := 0.05

var song: DmSong
var playing := false
var tick := 0.0
var cursor := 0
var voices: Array = []
var buses := {}
var elapsed_loops := 0
var master_db := -12.0
var groove_offset := 0
var last_measure := 0.0
var active_events: Array = []
var measure_ticks := 3072


func play(path: String, fallback_bank := "") -> bool:
	return play_song(DmSong.load_segment(path, fallback_bank))


## Play an already-built song. `SmfSong` uses this for the town ambience, which is
## a Standard MIDI File rather than a DirectMusic segment but needs the same DLS
## bank, voice pool and clock.
func play_song(loaded: DmSong, forever := false) -> bool:
	stop()
	if loaded == null or loaded.bank == null or loaded.events.is_empty() or loaded.length <= 0:
		song = null
		return false
	if loaded.tempo <= 0.0:
		loaded.tempo = 120.0
	if forever:
		loaded.loops = -1
	song = loaded
	_ensure_limiter()
	tick = 0.0
	cursor = 0
	elapsed_loops = 0
	active_events = song.events
	groove_offset = 0
	playing = true
	return true


func _ensure_limiter() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master < 0:
		return
	for i in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, i) is AudioEffectLimiter:
			return
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -1.0
	limiter.threshold_db = -6.0
	AudioServer.add_bus_effect(master, limiter)


func _music_bus() -> String:
	var existing := AudioServer.get_bus_index("DmMusic")
	if existing >= 0:
		return "DmMusic"
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, "DmMusic")
	AudioServer.set_bus_send(index, "Master")
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.45
	reverb.damping = 0.6
	reverb.wet = 0.12
	reverb.dry = 1.0
	AudioServer.add_bus_effect(index, reverb)
	return "DmMusic"


func set_groove_offset(offset: int) -> void:
	groove_offset = offset


func _apply_groove() -> void:
	if song == null or not song.is_directmusic:
		return
	var wanted := song.events_for(groove_offset)
	if wanted == active_events:
		return
	active_events = wanted
	cursor = 0
	while cursor < active_events.size() and active_events[cursor].tick < tick:
		cursor += 1


func stop() -> void:
	playing = false
	for voice in voices:
		if is_instance_valid(voice.player):
			voice.player.stop()
			voice.player.queue_free()
	voices.clear()
	for name in buses:
		var index := AudioServer.get_bus_index(name)
		if index >= 0:
			AudioServer.remove_bus(index)
	buses.clear()
	song = null


func _exit_tree() -> void:
	stop()


func _process(delta: float) -> void:
	if not playing or song == null:
		return
	var step := delta * song.tempo / 60.0 * DmSong.TICKS_PER_QUARTER
	tick += step
	var now := tick + elapsed_loops * song.length
	while cursor < active_events.size() and active_events[cursor].tick <= tick:
		_start_note(active_events[cursor], now)
		cursor += 1
	if tick - fmod(tick, measure_ticks) != last_measure:
		last_measure = tick - fmod(tick, measure_ticks)
		_apply_groove()
	if tick >= song.length:
		tick -= song.length
		elapsed_loops += 1
		cursor = 0
		if song.loops > 0 and elapsed_loops > song.loops:
			playing = false
	_release_due(tick + elapsed_loops * song.length)


func _start_note(event: Dictionary, now: float) -> void:
	var channel: int = event.channel
	var band: Dictionary = song.instruments.get(channel, {})
	if band.is_empty():
		return
	var patch: int = band.patch
	var drum := (patch & 0x80000000) != 0
	var bank_number := (((patch >> 16) & 0x7F) << 8) | ((patch >> 8) & 0x7F)
	var program := patch & 0x7F
	var instrument := song.bank.find_instrument(bank_number, program, drum)
	if instrument.is_empty():
		return
	var note: int
	if int(event.get("mode", 0x0E)) == 0 or (drum and (int(event.value) >> 8) == 0):
		note = clampi(int(event.value) & 0x7F, 0, 127)
	else:
		note = song.midi_note(event.value, event.level, event.tick)
	# The band transpose DOES apply to the pitch. Measured: every region's sample is
	# genuinely recorded above its declared `unity` - comparing each region's unity
	# against a Goertzel peak of the wave it points at gives offsets of +24 (14
	# regions) and +36 (10 regions), and the z02LGI band carries transpose of -24
	# and -36 on exactly those channels. The two cancel, so the note that gets
	# sounded is the written one. Dropping the transpose from the pitch (tried, and
	# it makes the music sound two to three octaves sharp) skips the compensation.
	note += int(band.transpose)
	var velocity: int = event.velocity
	var region := song.bank.find_region(instrument, note, velocity)
	if region.is_empty():
		return
	var wave := song.bank.wave(region.wave)
	if wave.is_empty():
		return
	var unity: int = region.unity if region.unity >= 0 else wave.unity
	var fine: int = region.fine if region.unity >= 0 else wave.fine
	var stream: AudioStreamWAV = wave.stream
	var loop_start: int = region.loop_start if region.unity >= 0 and region.loop_start >= 0 else wave.loop_start
	var loop_length: int = region.loop_length if region.unity >= 0 and region.loop_start >= 0 else wave.loop_length
	var voice_stream := stream
	if loop_start >= 0 and loop_length > 1:
		voice_stream = stream.duplicate()
		voice_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		voice_stream.loop_begin = loop_start
		voice_stream.loop_end = loop_start + loop_length
	var player := _free_player()
	if player == null:
		return
	player.stream = voice_stream
	player.bus = _bus(channel, band, region.art)
	player.pitch_scale = clampf(pow(2.0, (note - unity) / 12.0 + fine / 1200.0), 0.05, 128.0)
	var gain := 40.0 * log(maxf(velocity, 1) / 127.0) / log(10.0)
	gain += 40.0 * log(maxf(band.volume, 1) / 127.0) / log(10.0)
	gain += region.attenuation
	player.volume_db = clampf(gain + master_db, SILENT_DB, 6.0)
	var art: Dictionary = region.art
	var release := MIN_RELEASE
	if art.has(DlsBank.CONN_EG1_RELEASE):
		release = maxf(DlsBank.seconds(int(art[DlsBank.CONN_EG1_RELEASE])), MIN_RELEASE)
	var attack := 0.0
	if art.has(DlsBank.CONN_EG1_ATTACK):
		attack = DlsBank.seconds(int(art[DlsBank.CONN_EG1_ATTACK]))
	player.play()
	var target := player.volume_db
	if attack > 0.02:
		player.volume_db = SILENT_DB
		var tween := player.create_tween()
		tween.tween_property(player, "volume_db", target, attack)
	var end: float = now + float(event.duration)
	if drum and loop_start < 0:
		end = INF
	voices.append({"player": player, "end": end, "release": release, "released": false})


func _release_due(now: float) -> void:
	for i in range(voices.size() - 1, -1, -1):
		var voice: Dictionary = voices[i]
		var player: AudioStreamPlayer = voice.player
		if not is_instance_valid(player):
			voices.remove_at(i)
			continue
		if not voice.released and now >= voice.end:
			voice.released = true
			var tween := player.create_tween()
			tween.tween_property(player, "volume_db", SILENT_DB, voice.release)
			tween.tween_callback(player.stop)
		elif voice.released and not player.playing:
			voices.remove_at(i)
			player.queue_free()
		elif not voice.released and not player.playing:
			voices.remove_at(i)
			player.queue_free()


func _free_player() -> AudioStreamPlayer:
	if voices.size() >= MAX_VOICES:
		var steal := 0
		for i in voices.size():
			if voices[i].released:
				steal = i
				break
		var oldest: Dictionary = voices[steal]
		if is_instance_valid(oldest.player):
			oldest.player.stop()
			oldest.player.queue_free()
		voices.remove_at(steal)
	var player := AudioStreamPlayer.new()
	player.bus = "Music"
	add_child(player)
	return player


func _bus(channel: int, band: Dictionary, art: Dictionary = {}) -> String:
	var name := "DmChannel%d" % channel
	if not buses.has(name):
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, name)
		AudioServer.set_bus_send(index, _music_bus())
		var panner := AudioEffectPanner.new()
		panner.pan = clampf((float(band.pan) - 64.0) / 64.0, -1.0, 1.0)
		AudioServer.add_bus_effect(index, panner)
		if art.has(DlsBank.CONN_FILTER_CUTOFF):
			var cents := float(int(art[DlsBank.CONN_FILTER_CUTOFF])) / 65536.0
			var hertz := 440.0 * pow(2.0, (cents - 6900.0) / 1200.0)
			if hertz < 19000.0:
				var filter := AudioEffectLowPassFilter.new()
				filter.cutoff_hz = clampf(hertz, 100.0, 20000.0)
				AudioServer.add_bus_effect(index, filter)
		buses[name] = true
	return name
