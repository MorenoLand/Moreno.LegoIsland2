class_name ParkProgram
extends ZoneProgram

## z01BPK (the skate park), loop FUN_007E6E1F with the set-up FUN_007E7D56 and the restart FUN_007E8138.
## Pepper is record 35 and the board is record 36. His behaviours (FUN_007E7C14) are the run keeper
## (ParkSwitch, always), the walk to the board (ParkWalk, selector 1) and the board (Skate, selector 4).
## The behaviours only run in the playing state: the zone first fades in, shows its message panel until a
## key is pressed, plays, shows the result when the clock is out, and fades out when it is left.
##
## States of the loop: 7 fade in, 1 waiting for a key, 2 playing, 3 the pause menu, 4 the result, 5 the
## menu after it, 8 fade out. The way out is a code: 0 to the front end, 2 / 4 to the next zone.

const PLAYER := 35
const BOARD := 36
const SPECTATOR_FIRST := 37
const SPECTATOR_LAST := 55
const ZONE_NUMBER := 1
const SELECTOR := 0x5E
const ZONE_VAR := 0x59
const PREVIOUS_ZONE_VAR := 0xA3
const GRAVITY := -10.0
const STATE_FADE_IN := 7
const STATE_WAIT := 1
const STATE_PLAY := 2
const STATE_PAUSE := 3
const STATE_RESULT := 4
const STATE_MENU := 5
const STATE_FADE_OUT := 8
const EXIT_FRONT := 0
const EXIT_CONTINUE := 2
const EXIT_RESTART := 3
const EXIT_LEAVE := 4
const FADE_STEP := 0.0625
const PAUSE_MENU := 18
const MENU_DONE := 16
const MENU_FAILED := 19
const VALUE_LEAVE := 1
const VALUE_RESTART := 0xF
const VALUE_CONTINUE := 0x10
const START_POSITION := Vector3(0.25, 16.0, -38.0)
## FUN_007E7D56: the matrix Pepper starts with (rows of record +0xC, +0x1C, +0x2C).
const START_ROWS := [
	Vector3(0.9995338, -0.0029288, 0.0470407),
	Vector3(0.0025617, 0.9999,  0.0075112),
	Vector3(-0.0470407, -0.0073815, 0.9988),
]
## FUN_0041B4E0 at the start: the eye is the offset (0, 12, -16) turned half a circle about Pepper, the
## target is 3 above him.
const CAMERA_OFFSET := Vector3(0.0, 12.0, -16.0)
const CAMERA_RISE := 3.0
const CLIP_IDLE := 0x1B
const CLIP_CHEER_EVEN := 0x7A
const CLIP_CHEER_ODD := 0x7B
const MEDAL_KEYS := {1: "SGBRONZE", 2: "SGSILVER", 3: "SGGOLD"}
const MEDAL_WRAP := {1: 8, 2: 8, 3: 6}
## FUN_007E6A8D: the message of the trick Pepper is doing, by his clip.
const TRICKS := {
	0x0A: "BPK6", 0x0F: "BPK4", 0x10: "BPK7", 0x11: "BPK5", 0x19: "BPK8", 0x52: "BPK3", 0x54: "BPK10",
	0x5C: "BPK12", 0x5E: "BPK9", 0x5F: "BPK14", 0x60: "BPK13", 0x64: "BPK20", 0x65: "BPK17", 0x66: "BPK19",
	0x67: "BPK11", 0x68: "BPK16", 0x69: "BPK15", 0x6A: "BPK21", 0x6B: "BPK18", 0x6C: "BPK23", 0x6D: "BPK22",
}
## FUN_007E7710: the sounds the zone creates (global address, sound id).
const SOUNDS := [
	[0x5D50E14, 0x94], [0x5D50E7C, 0x95], [0x5D50DF4, 0x12C], [0x5D50E64, 0x97], [0x5D50E5C, 0x98],
	[0x5D50E68, 0x99], [0x5D50E58, 0x9A], [0x5D50DE4, 0xA0], [0x5D50E2C, 0x1A8], [0x5D50E28, 0x1A9],
	[0x5D50DD8, 0x1AA], [0x5D50E60, 0x1AB], [0x5D50E78, 0x1AC], [0x5D50E00, 0x1AD], [0x5D50E24, 0x1AE],
	[0x5D50E08, 0x1AF], [0x5D50DF0, 0x1B0], [0x5D50E38, 0x1B1], [0x5D50DE0, 0x1B2], [0x5D50E34, 0x1B3],
	[0x5D50DE8, 0x1B4], [0x5D50E80, 0x1B5], [0x5D50E18, 0x1B6], [0x5D50DD4, 0x1B7], [0x5D50E10, 0x1B8],
	[0x5D50E1C, 0x1B9], [0x5D50DF8, 0x1BA], [0x5D50DDC, 0x1BB], [0x5D50E54, 0x1BC], [0x5D50DEC, 0x1BD],
	[0x5D50E74, 0x1BE], [0x5D50E70, 0x1BF], [0x5D50E4C, 0x1C0], [0x5D50E50, 0x1C1], [0x5D50E30, 0x2AD],
	[0x5D50E3C, 0x2A9], [0x5D50E40, 0x2AA], [0x5D50E44, 0x2AC], [0x5D50E48, 0x2AB],
]

var state := STATE_FADE_IN
var saved_state := STATE_WAIT
var fade := 0.0
var exit_code := 1
var exit_wanted := 0
var left := false
var screen: ParkScreen
var messages := {}
var standard := {}
var menu_open := false
var _bridge


func _init() -> void:
	player_record = PLAYER
	engine_pepper = true


func running() -> bool:
	return state == STATE_PLAY


func holds_music() -> bool:
	return true


func legacy(index: int) -> bool:
	return index >= SPECTATOR_FIRST and index <= SPECTATOR_LAST


## FUN_007E7D56 / FUN_007E7C14.
func build(bridge) -> void:
	_bridge = bridge
	var services = bridge.services
	var records: Array = bridge.records
	var vars = bridge.vars
	var g: TalkGlobals = services.talk
	g.ground_min = 0.0
	g.gravity = GRAVITY
	g.hidden_record = BOARD
	g.pepper_clip = CLIP_IDLE
	vars.set_var(ZONE_VAR, ZONE_NUMBER)
	for row in SOUNDS:
		services.sound_define(int(row[0]), int(row[1]))
	messages = services.load_lines("_data/messages/li/English/BPK.str")
	standard = services.load_lines("_data/messages/FE/English/STD.str")
	var pepper: Record = records[PLAYER]
	pepper.block = BehaviourBlock.new()
	var keeper := ParkSwitch.from_descriptor(services, vars)
	keeper.tag = SELECTOR
	var walker := ParkWalk.from_descriptor(services, vars)
	walker.tag = SELECTOR
	walker.mask = 1
	walker.value = 1
	var board := Skate.from_descriptor(services, vars)
	board.tag = SELECTOR
	board.mask = 4
	board.value = 4
	pepper.block.add(keeper, 0)
	pepper.block.add(walker, 1)
	pepper.block.add(board, 2)
	vars.set_var(SELECTOR, 1)
	screen = ParkScreen.new()
	screen.services = services
	var layer := CanvasLayer.new()
	layer.layer = 6
	layer.add_child(screen)
	bridge.island.add_child(layer)
	_restart()


## FUN_007E8138 (and the end of FUN_007E7D56): everything back to the start of the run.
func _restart() -> void:
	var services = _bridge.services
	var records: Array = _bridge.records
	var g: TalkGlobals = services.talk
	var pepper: Record = records[PLAYER]
	var board: Record = records[BOARD]
	pepper.x = START_POSITION.x
	pepper.y = START_POSITION.y
	pepper.z = START_POSITION.z
	for k in 3:
		var row: Vector3 = START_ROWS[k]
		pepper.set_field_f(0x0C + k * 0x10, row.x)
		pepper.set_field_f(0x10 + k * 0x10, row.y)
		pepper.set_field_f(0x14 + k * 0x10, row.z)
	pepper.matrix_valid = true
	pepper.flags |= 2
	board.flags &= ~2
	services.set_clip(pepper, CLIP_IDLE, 0.0)
	services.set_clip(board, 0, 0.0)
	var eye := START_POSITION + Vector3(-CAMERA_OFFSET.x, CAMERA_OFFSET.y, -CAMERA_OFFSET.z)
	services.camera_eye = eye
	services.camera_target = Vector3(START_POSITION.x, START_POSITION.y + CAMERA_RISE, START_POSITION.z)
	services.camera_rig = pepper
	_bridge.vars.set_var(SELECTOR, 1)
	g.pepper_clip = CLIP_IDLE
	g.trick_score = 0.0
	g.score_taken = false
	g.park_score = 0
	g.park_medal = 0
	g.park_high = false
	g.park_end = 0
	g.park_hud = false
	g.park_clock_text = ""
	g.park_score_text = ""
	g.park_trick_text = ""
	g.park_line_text = ""
	var keeper := pepper.block.head as ParkSwitch
	keeper.time_left = ParkSwitch.TIME
	keeper.score = 0.0
	keeper.waiting = 0.0
	keeper.paying = false
	keeper.expired = false
	(pepper.block.head.next as ParkWalk).turned = false
	(pepper.block.head.next as ParkWalk).clip = ParkWalk.CLIP_INTO_WALK
	_bridge.island.board_clip = 0
	_bridge.island.board_time = 0.0
	screen.panel = false
	screen.trick_text = ""


## The key of FUN_008764C0: the loop goes to the pause menu from wherever it is.
func request_pause() -> void:
	if state == STATE_PAUSE or menu_open:
		return
	saved_state = state
	state = STATE_PAUSE
	screen.panel = false
	menu_open = true
	var menu: Control = _bridge.island.open_menu(PAUSE_MENU, true)
	menu.resume_requested.connect(_menu_resume)
	menu.leave_requested.connect(func(): _menu_exit(EXIT_FRONT))
	menu.chosen.connect(_pause_chosen)


func _close_menu() -> void:
	menu_open = false
	_bridge.island.close_menu()


func _menu_resume() -> void:
	_close_menu()
	state = saved_state


func _pause_chosen(value: int) -> void:
	if value == VALUE_LEAVE:
		_menu_exit(EXIT_LEAVE)
	elif value == VALUE_RESTART:
		_close_menu()
		_restart_zone()


func _menu_exit(code: int) -> void:
	_close_menu()
	exit_wanted = code
	state = STATE_FADE_OUT


func _restart_zone() -> void:
	_restart()
	state = STATE_FADE_IN
	fade = minf(fade, 1.0)


## FUN_0086CD11: the menu after the result.
func _result_chosen(value: int) -> void:
	var g: TalkGlobals = _bridge.services.talk
	var code := 0
	match value:
		VALUE_CONTINUE:
			code = EXIT_CONTINUE if g.park_end == 1 else EXIT_LEAVE
		VALUE_LEAVE:
			code = EXIT_LEAVE
		VALUE_RESTART:
			code = EXIT_RESTART
		_:
			return
	g.park_end = 0
	_close_menu()
	if code == EXIT_RESTART:
		_restart_zone()
	else:
		exit_wanted = code
		state = STATE_FADE_OUT


func _result_dismissed() -> void:
	_result_chosen(VALUE_LEAVE)


func pre_tick() -> void:
	if screen != null:
		screen.services.talk.park_hud = false


func tick() -> void:
	var services = _bridge.services
	var g: TalkGlobals = services.talk
	screen.brightness = 1.0
	if state != STATE_PLAY:
		screen.trick_text = ""
	match state:
		STATE_FADE_IN:
			screen.brightness = fade
			if fade >= 1.0:
				fade = 1.0
				screen.brightness = 1.0
				state = STATE_WAIT
			else:
				fade += FADE_STEP
		STATE_WAIT:
			_wait_panel()
			if g.game_flags != 0:
				state = STATE_PLAY
				_bridge.island.start_zone_music()
		STATE_PLAY:
			screen.panel = false
			_trick_text()
			if g.park_end != 0:
				state = STATE_RESULT
		STATE_RESULT:
			_result_panel()
			if g.park_score < 1 or g.game_flags != 0:
				state = STATE_MENU
				screen.panel = false
				_open_result_menu()
		STATE_FADE_OUT:
			screen.brightness = fade
			if fade <= 0.0:
				fade = 0.0
				_leave()
			else:
				fade -= FADE_STEP
	screen.queue_redraw()


func _wait_panel() -> void:
	screen.panel = true
	screen.panel_lines = [[String(messages.get("BPK2", [0, ""])[1]), 320, 60, 30]]
	screen.trick_text = ""


## FUN_007E6A8D.
func _trick_text() -> void:
	var services = _bridge.services
	var clip: int = services.current_clip(_bridge.records[PLAYER])
	var key: String = TRICKS.get(clip, "")
	screen.trick_text = String(messages[key][1]) if key != "" and messages.has(key) else ""


## FUN_007E6941.
func _result_panel() -> void:
	var g: TalkGlobals = _bridge.services.talk
	screen.panel = true
	screen.trick_text = ""
	var lines: Array = []
	if g.park_score > 0:
		lines.append(["%d" % g.park_score, 320, 50, 10])
	if MEDAL_KEYS.has(g.park_medal):
		var medal: String = MEDAL_KEYS[g.park_medal]
		lines.append([String(standard.get(medal, [0, ""])[1]), 320, 100, int(MEDAL_WRAP[g.park_medal])])
	if g.park_high:
		lines.append([String(messages.get("BPK1", [0, ""])[1]), 320, 150, 20])
	screen.panel_lines = lines


func _open_result_menu() -> void:
	var g: TalkGlobals = _bridge.services.talk
	menu_open = true
	var menu: Control = _bridge.island.open_menu(MENU_DONE if g.park_end == 1 else MENU_FAILED, true)
	menu.resume_requested.connect(_result_dismissed)
	menu.chosen.connect(_result_chosen)


## The loop is left: FUN_007E80E7, then FUN_00404CB4 chooses the zone that comes next.
func _leave() -> void:
	if left:
		return
	left = true
	_bridge.island.leave_zone(_exit_zone(exit_wanted))


## FUN_00404CB4: when the zone is the one the story is in, leaving moves the story (on, or back); the
## zone to go to is then the story's. Otherwise it is the zone before this one (var 0xA3).
func _exit_zone(code: int) -> int:
	if code == EXIT_FRONT:
		return -1
	var vars = _bridge.vars
	var state_now: int = vars.get_var(Story.VAR_STATE)
	if vars.get_var(ZONE_VAR) == Story.zone_of(state_now):
		if code == EXIT_CONTINUE and _bridge.services.talk.park_end == 1:
			Story.advance(Game)
		else:
			Story.rewind(Game)
		return Story.zone_of(vars.get_var(Story.VAR_STATE))
	return vars.get_var(PREVIOUS_ZONE_VAR)
