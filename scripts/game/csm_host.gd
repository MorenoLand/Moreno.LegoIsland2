extends Node

## Runs `Csm` scripts inside the island scene: actors by their 4-letter record
## code, the cut-scene camera, speech with subtitles, and clip names.
##
## All positions the timeline sees are GAME space (x, y, z); the scene is Godot
## space with z negated, so every crossing goes through `_to_game` / `_to_scene`.

const Waypoints = preload("res://scripts/core/waypoints.gd")
const CsmScript = preload("res://scripts/game/csm.gd")
const SPEECH_DIR := "_data/sounds/speech/English/"
const SUBTITLE_PAD := 40
const SUBTITLE_SIZE := 28
const SPEECH_DB := 0.0
const CLIP_RATE := 30.0
# Characters are drawn facing their model -z, which is game direction
# (sin yaw, cos yaw) for a placement basis; Pepper's own body basis is
# Basis(UP, -yaw) (derived from `Basis(UP, player_yaw + PI)` with
# player_yaw = PI - yaw).
const TALK_KEY := KEY_SHIFT
# CONFIRMED (FUN_004450c0 / FUN_00445118 / FUN_00445211): a cut scene draws a black
# bar across the top and bottom of the screen (mode 1; mode 2 = bottom only). Each
# bar grows by viewport_height / 30 pixels per tick up to
# viewport_height * 0.4375 * 0.5 (the 800x600 original leaves a 2.37:1 picture). On a
# wider window the picture keeps that 2.37:1 shape instead of getting thinner.
const BAR_ASPECT := 800.0 / 337.5
const BAR_RISE_TICKS := 30.0
# CONFIRMED (act builder FUN_004c7230): every NPC's talk node gets link
# `((state > 0x3a) - 1 & MASK) - 1` = MASK - 1 and that link is the CSM index
# registered by FUN_0045af0a for acts below state 8 (0 = bpk01, 1..25 = lgici01..25).
# Each entry is [csm index, the NPC's own game variable (the behaviour tag)].
const TALK_LINKS := {
	"darr": [1, 0x78, 2, true], "djab": [2, 0x6B, 2, true], "clik": [3, 0x67, 2, true],
	"mail": [4, 0x7D, 0, false], "jack": [8, 0x7E, 0, false], "lick": [9, 0x69, 2, true],
	"post": [10, 0x7A, 1, true], "mama": [11, 0x68, 0, false], "nanc": [12, 0x7F, 1, true],
	"nick": [13, 0x60, 2, true], "nubb": [14, 0x80, 2, false], "papa": [15, 0x61, 2, false],
	"pete": [16, 0xA7, 0, false], "redg": [17, 0x79, 2, true], "hogg": [18, 0x5A, 0, false],
	"rich": [19, 0xA4, 0, false], "robb": [20, 0x7B, 2, true], "snap": [21, 0x5B, 0, false],
	"stev": [22, 0x7C, 0, false], "tbob": [24, 0x5C, 2, true], "vals": [25, 0x6A, 2, true],
}
# [csm index, behaviour tag var, kind (FUN_0045c6a0's third argument), pizza helper
# (FUN_0045c945 = true, FUN_0045c838 = false)]. After the talk ends FUN_0087d310 adds
# 1000 to vars 0xA6 and 0x12 when kind != 0; for kind 2 it also starts CSM
# `0x1A + var 0xAD` (lgiph01..11, Pepper's house growing) and bumps var 0xAD / var 0x4F;
# the pizza helper takes one off var 0xB0 (SWITCH_GME_NUM_PIZZAS) and sets 0x40003 on the
# tag, the plain one sets 0x40001.
const VAR_SCORE_A := 0xA6
const VAR_SCORE_B := 0x12
const Story = preload("res://scripts/core/story.gd")
const VAR_DELIVERED := 0xAD
const VAR_PIZZAS := 0xB0
const VAR_PIZZA_TRIP := 0x4F
const DELIVERY_SCORE := 1000
const HOUSE_SCRIPT_BASE := 0x1A
const TALK_DONE_BITS := 0x40001
const TALK_DONE_TEST := 0x40000
const TALK_RANGE := 16.0
const ACT0_LAST_STATE := 7
# CONFIRMED (FUN_0045b339 / FUN_0045ad9c / FUN_0045a7ee / FUN_0045a40d and their
# registrars FUN_0045af0a, FUN_0045aa4d, FUN_0045a4db, FUN_00459ceb): the act is chosen
# from var 0x58 (<7, <0x1E, <0x34, <0x3D, else) and each act registers its own list of
# cut scenes; the index a trigger or talk node carries is the position in that list.
const ACT_SCRIPTS := [
	["bpk01", "lgici01", "lgici02", "lgici03", "lgici04", "lgici05", "lgici06", "lgici07", "lgici08",
		"lgici09", "lgici10", "lgici11", "lgici12", "lgici13", "lgici14", "lgici15", "lgici16", "lgici17",
		"lgici18", "lgici19", "lgici20", "lgici21", "lgici22", "lgici23", "lgici24", "lgici25",
		"lgiph01", "lgiph02", "lgiph03", "lgiph04", "lgiph05", "lgiph06", "lgiph07", "lgiph08",
		"lgiph09", "lgiph10", "lgiph11", "lgi01", "lgi02", "lgi03", "lgi04"],
	["lgi05", "lgibr01", "lgibr02", "lgibr03", "lgibr04", "lgi06", "lgi07"],
	["lgibr05", "lgibr06", "lgibr07", "lgi08"],
	["lgibr08", "lgibr09", "lgibr10", "lgibr11", "lgibr12", "lgi09", "lgi10", "lgi11", "lgi12"],
	["lgi13"],
]
const ACT_LIMITS := [7, 0x1E, 0x34, 0x3D]
const TRIGGER_TABLES := {0: "w_road_c", 1: "w_path_c"}
const WALKER_UNIT := 8.0
const MODE_SET := 1
const MODE_OR := 2
const MODE_CLEAR := 4
const MODE_NOTIFY_OR := 0x10
const MODE_NOTIFY_CLEAR := 0x20
const MODE_DELIVER := 0x40

var island: Node
var csm
var active := false
var records := {}
var nodes := {}
var yaws := {}
var holds := {}
var clip_names := {}
var switches := {}
var subtitles := {}
var waypoints: Dictionary = {}
var layer: CanvasLayer
var label: Label
var speech: AudioStreamPlayer
var saved_fov := 0.0
var library: Array = []
var library_at := 0
var f8_held := false
var script_name := ""
var talk_held := false
var talk_tag := -1
var bar_top: ColorRect
var bar_bottom: ColorRect
var bar_px := 0.0
var bars_mode := 0
var talk_npc := ""
var triggers: Array = []
var fired := {}
var graphs := {}
var queued := ""
## True while the ported behaviours (talk nodes, zone triggers, start nodes) start the scenes;
## the hand-written talk key and trigger table below are then off.
var engine_driven := false


func _ready() -> void:
	island = get_parent()
	_load_codes()
	_load_clip_names()
	layer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	label = Label.new()
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -SUBTITLE_PAD * 3
	label.offset_bottom = -SUBTITLE_PAD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", SUBTITLE_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.visible = false
	layer.add_child(label)
	speech = AudioStreamPlayer.new()
	speech.bus = "Speech"
	add_child(speech)
	var bars := CanvasLayer.new()
	bars.layer = 49
	add_child(bars)
	bar_top = ColorRect.new()
	bar_bottom = ColorRect.new()
	for bar in [bar_top, bar_bottom]:
		bar.color = Color.BLACK
		bar.visible = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bars.add_child(bar)


func _load_codes() -> void:
	records.clear()
	for row in Table.rows("res://data/%s_placement.tsv" % island.prefix):
		if row.size() < 8:
			continue
		var code := String(row[1]).to_lower()
		if not records.has(code):
			records[code] = int(row[0])
		yaws[int(row[0])] = float(row[3])


func _load_clip_names() -> void:
	for row in Table.rows("res://data/island_clipnames.tsv"):
		if row.size() >= 2:
			clip_names[String(row[0])] = int(row[1])


func library_names() -> Array:
	var out: Array = []
	for key in Data._index.keys():
		var k := String(key)
		if k.begins_with("_data/z02lgi/cutscene/") and k.ends_with(".txt") and not k.ends_with("psx.txt") and not k.contains("test"):
			out.append(k.get_file().get_basename())
	out.sort()
	return out


func play(name: String) -> bool:
	if active:
		return false
	var text := Data.read("_data/z02LGI/Cutscene/%s.txt" % name).get_string_from_ascii()
	if text == "":
		return false
	csm = CsmScript.new()
	if not csm.load_script(name, text):
		return false
	script_name = name
	_load_subtitles(name)
	_load_waypoints()
	nodes.clear()
	holds.clear()
	saved_fov = island.camera.fov
	island.camera_locked = true
	island.story_hold = true
	bar_px = 0.0
	island.bridge.services.prompt_mode(1)
	csm.cam_pos = _to_game(island.camera.position)
	csm.cam_target = _to_game(island.camera.position + (-island.camera.global_transform.basis.z) * 10.0)
	csm.start(self)
	active = true
	print("[csm] play %s (%d events)" % [name, csm.events.size()])
	return true


func _load_subtitles(name: String) -> void:
	subtitles.clear()
	var path := "_data/messages/li/english/%s.str" % name.to_lower()
	for line in Data.read(path).get_string_from_ascii().replace("\r", "").split("\n"):
		var colon := String(line).find(":")
		if colon <= 0:
			continue
		var key := String(line).substr(0, colon).to_upper()
		var rest := String(line).substr(colon + 1)
		var space := rest.find(" ")
		subtitles[key] = rest.substr(space + 1).strip_edges() if space >= 0 else ""


func _load_waypoints() -> void:
	if not waypoints.is_empty():
		return
	for file in ["w_csm_c", "w_path_c"]:
		var bytes := Data.read("_data/z02LGI/waypoints/%s.wpt" % file)
		var graph := Waypoints.new()
		if not graph.parse(bytes):
			continue
		var names := _read_names(bytes, graph)
		for key in names.keys():
			if not waypoints.has(key):
				var p: Vector3 = graph.nodes[int(names[key])]
				waypoints[key] = p
	print("[csm] %d named waypoints" % waypoints.size())


## `FUN_00884370` tail: after the edge matrices comes a u32 blob size, one i32
## offset per node, then the NUL-terminated name blob.
func _read_names(bytes: PackedByteArray, graph: Waypoints) -> Dictionary:
	var at := 20 + graph.node_count * 32 + graph.edge_count * 16
	for edge in graph.edges:
		at += int(edge.w) * int(edge.h) * 2
	if at + 4 > bytes.size():
		return {}
	var blob_size := bytes.decode_u32(at)
	at += 4
	var offsets_at := at
	var blob_at := at + graph.node_count * 4
	var out := {}
	for i in graph.node_count:
		var off := bytes.decode_s32(offsets_at + i * 4)
		if blob_at + off < 0 or blob_at + off >= bytes.size() or off >= blob_size:
			continue
		var end := blob_at + off
		while end < bytes.size() and bytes[end] != 0:
			end += 1
		var label := bytes.slice(blob_at + off, end).get_string_from_ascii().to_lower()
		if label != "" and not out.has(label):
			out[label] = i
	return out


func _process(delta: float) -> void:
	_debug_keys()
	_talk_keys()
	_triggers_tick()
	if island.pause_layer == null:
		_letterbox(delta)
	if not active:
		return
	if island.pause_layer != null:
		return
	var skip := Input.is_physical_key_pressed(TALK_KEY)
	_animate(delta)
	_lip_tick(delta)
	csm.tick(delta, skip)


## FUN_00445118 / FUN_00445211: the bars of the prompt mode (1: top and bottom, 2: bottom only)
## slide in over a few ticks; mode 0 takes them away at once.
func _letterbox(delta: float) -> void:
	var mode: int = island.bridge.services.prompt_state if island.bridge != null else 0
	if mode != bars_mode:
		bars_mode = mode
		bar_px = 0.0
	if mode == 0:
		bar_top.visible = false
		bar_bottom.visible = false
		return
	var size := get_viewport().get_visible_rect().size
	var picture := minf(size.y, size.x / BAR_ASPECT)
	var limit := (size.y - picture) * 0.5
	bar_px = minf(bar_px + size.y / BAR_RISE_TICKS * delta * 30.0, limit)
	bar_top.position = Vector2.ZERO
	bar_top.size = Vector2(size.x, bar_px)
	bar_bottom.position = Vector2(0.0, size.y - bar_px)
	bar_bottom.size = Vector2(size.x, bar_px)
	bar_top.visible = bar_px > 0.5 and mode == 1
	bar_bottom.visible = bar_px > 0.5


func _talk_keys() -> void:
	if engine_driven:
		return
	var held := Input.is_physical_key_pressed(TALK_KEY)
	if held and not talk_held and not active and island.ready_to_walk and island.pause_layer == null:
		talk_to_nearest()
	talk_held = held


## The talk key near an NPC that still has its conversation: play the CSM script
## its link names, then mark it done in the NPC's own variable like the exe does
## (`FUN_0041153b(tag, 0x40001)`).
func talk_to_nearest() -> bool:
	if Game.get_var(Game.VAR_STATE) > ACT0_LAST_STATE:
		return false
	var pepper: Vector3 = actor_pos("pepp")
	var best := ""
	var best_d := TALK_RANGE * TALK_RANGE
	for code in TALK_LINKS.keys():
		var tag: int = TALK_LINKS[code][1]
		if (Game.get_var(tag) & TALK_DONE_TEST) != 0:
			continue
		var at: Vector3 = actor_pos(code)
		if at == Vector3.INF:
			continue
		var d := Vector2(at.x - pepper.x, at.z - pepper.z).length_squared()
		if d <= best_d:
			best_d = d
			best = code
	if best == "":
		return false
	var index: int = TALK_LINKS[best][0]
	talk_npc = best
	talk_tag = TALK_LINKS[best][1]
	var name := script_for(index)
	if play(name):
		return true
	if not active and name != "" and Data.read("_data/z02LGI/Cutscene/%s.txt" % name).size() > 0:
		# Some conversation scripts are only a header (the three footballer
		# meetings): nothing plays, but the conversation still counts as held.
		_talk_finished()
		talk_tag = -1
		return true
	talk_tag = -1
	return false


func act_of(state: int) -> int:
	for i in ACT_LIMITS.size():
		if state < int(ACT_LIMITS[i]):
			return i
	return ACT_LIMITS.size()


func script_for(index: int) -> String:
	var list: Array = ACT_SCRIPTS[act_of(Game.get_var(Game.VAR_STATE))]
	return String(list[index]) if index >= 0 and index < list.size() else ""


func _load_triggers() -> void:
	triggers.clear()
	for row in Table.rows("res://data/story_triggers.tsv"):
		if row.size() < 14:
			continue
		var acts: Array = []
		for a in String(row[0]).split(","):
			acts.append(int(a))
		var nodes: Array = []
		for n in String(row[5]).split(" ", false):
			nodes.append(int(n))
		triggers.append({
			"acts": acts, "record": int(row[1]), "gate_var": int(row[2]), "gate_mask": int(row[3]),
			"gate_value": int(row[4]), "nodes": nodes, "table": int(row[6]), "radius": float(row[7]),
			"csm": int(row[8]), "mode": int(row[9]), "var": int(row[10]), "value": int(row[11]),
		})


func _graph(table: int):
	if graphs.has(table):
		return graphs[table]
	var g = null
	if TRIGGER_TABLES.has(table):
		g = Waypoints.new()
		if not g.parse(Data.read("_data/z02LGI/waypoints/%s.wpt" % TRIGGER_TABLES[table])):
			g = null
	graphs[table] = g
	return g


## CONFIRMED (StartCSM.c, FUN_004b840e / FUN_004b82e0): a story trigger is armed
## while its gate (`var & mask == value`, usually var 0x58 == state) holds. With no
## node list it fires at once; otherwise when Pepper is within `radius * 8` units
## (3-D, squared test) of the nearest node. Firing starts the act's CSM `csm` (when
## >= 0) and applies `mode` to `var` with `value`: 1 set, 2 or, 4 clear (0x10/0x20 are
## the same plus a notify), 0x40 = 1000 points to vars 0xA6 and 0x12 and one pizza off
## var 0xB0, then set.
func _triggers_tick() -> void:
	if engine_driven:
		return
	if active or not island.ready_to_walk or island.pause_layer != null:
		return
	if triggers.is_empty():
		_load_triggers()
	var act := act_of(Game.get_var(Game.VAR_STATE))
	var pepper: Vector3 = actor_pos("pepp")
	for i in triggers.size():
		var t: Dictionary = triggers[i]
		if fired.has(i) or not (t.acts as Array).has(act):
			continue
		if (Game.get_var(int(t.gate_var)) & int(t.gate_mask)) != int(t.gate_value):
			continue
		var nodes: Array = t.nodes
		if not nodes.is_empty():
			var graph = _graph(int(t.table))
			if graph == null:
				continue
			var reach := float(t.radius) * WALKER_UNIT
			var near := false
			for n in nodes:
				var p: Vector3 = graph.nodes[int(n)]
				if p.distance_squared_to(pepper) <= reach * reach:
					near = true
					break
			if not near:
				continue
		fired[i] = true
		_apply_trigger(t)
		return


func _apply_trigger(t: Dictionary) -> void:
	var var_id: int = t.var
	var value: int = t.value
	match int(t.mode):
		MODE_SET:
			Game.set_var(var_id, value)
		MODE_OR, MODE_NOTIFY_OR:
			Game.set_var(var_id, Game.get_var(var_id) | value)
		MODE_CLEAR, MODE_NOTIFY_CLEAR:
			Game.set_var(var_id, Game.get_var(var_id) & ~value)
		MODE_DELIVER:
			Game.set_var(VAR_SCORE_A, Game.get_var(VAR_SCORE_A) + DELIVERY_SCORE)
			Game.set_var(VAR_SCORE_B, Game.get_var(VAR_SCORE_B) + DELIVERY_SCORE)
			Game.set_var(VAR_PIZZAS, Game.get_var(VAR_PIZZAS) - 1)
			Game.set_var(var_id, value)
	var csm_name := script_for(int(t.csm)) if int(t.csm) >= 0 else ""
	print("[csm] trigger fired: csm %d (%s), var %d set by mode %d" % [int(t.csm), csm_name, var_id, int(t.mode)])
	if csm_name != "":
		play(csm_name)


func _debug_keys() -> void:
	var f8 := Input.is_physical_key_pressed(KEY_F8)
	if f8 and not f8_held and not active and island.ready_to_walk:
		if library.is_empty():
			library = library_names()
		if not library.is_empty():
			play(String(library[library_at % library.size()]))
			library_at += 1
	f8_held = f8


# ---- host interface used by Csm ------------------------------------------

func _record(name: String) -> int:
	return int(records.get(name, -1))


func _node_of(name: String) -> Node3D:
	if name == "pepp":
		return island.player
	var record := _record(name)
	if record < 0:
		return null
	if nodes.has(record):
		return nodes[record]
	for child in island.get_children():
		if child is Node3D and String(child.name).ends_with("_%d" % record):
			nodes[record] = child
			return child
	nodes[record] = null
	return null


func actor_pos(name: String) -> Vector3:
	var node := _node_of(name)
	if node == null:
		return Vector3.INF
	if name == "pepp":
		return _to_game(island.player_pos)
	return _to_game(node.position)


func actor_yaw(name: String) -> float:
	if name == "pepp":
		return float(yaws.get("pepp", PI - island.player_yaw))
	var record := _record(name)
	return float(yaws.get(record, 0.0))


func actor_place(name: String, pos: Vector3, yaw: float) -> void:
	var node := _node_of(name)
	if node == null:
		return
	if name == "pepp":
		yaws["pepp"] = yaw
		island.player_pos = _to_scene(pos)
		island.player_yaw = PI - yaw
		island.player.position = island.player_pos + Vector3(0.0, island.pepper_foot, 0.0)
		island.player.basis = Basis(Vector3.UP, -yaw)
		return
	yaws[_record(name)] = yaw
	node.position = _to_scene(pos)
	node.basis = island._placement_basis(0.0, yaw, 0.0)


## Pepper's house while the island loads: the original house (PHSE) before the first delivery
## and once all eleven are done, else the stage model of the delivered count. The scenes hide
## the old stage and BrickMorph shows the new one when its bricks have landed.
func house_stage() -> void:
	var count := clampi(Game.get_var(Story.HOUSE_STAGE_VAR), 0, Story.HOUSE_STAGES + 1)
	var site := _record_node(Story.HOUSE_SITE_RECORD)
	if site != null:
		site.visible = count == 0 or count > Story.HOUSE_STAGES
	for i in Story.HOUSE_STAGES:
		var node := _record_node(Story.HOUSE_STAGE_FIRST + i)
		if node != null:
			node.visible = i + 1 == count


func _record_node(record: int) -> Node3D:
	if nodes.has(record):
		return nodes[record]
	for child in island.get_children():
		if child is Node3D and String(child.name).ends_with("_%d" % record):
			nodes[record] = child
			return child
	nodes[record] = null
	return null


func actor_visible(name: String, shown: bool) -> void:
	var node := _node_of(name)
	if node != null:
		node.visible = shown


func clip_index(clip_name: String, _actor: String) -> int:
	return int(clip_names.get(clip_name.to_lower(), -1))


func actor_clip(name: String, clip: int, _loop: bool) -> float:
	if clip < 0:
		return 0.0
	if name == "pepp":
		island.pepper_clip = clip
		island.pepper_time = 0.0
		holds["pepp"] = true
		var frames := 1
		if clip < island.pepper_blk.anims.size():
			frames = maxi(int(island.pepper_blk.anims[clip].frames), 1)
		return float(frames) / CLIP_RATE
	var node := _node_of(name)
	if node == null:
		return 0.0
	for item in island.cheerers:
		if item.node == node:
			item.stage = 3
			island._set_clip(item, clip)
			var blk: BlkFile = item.blk
			var frames2 := 1
			if clip < blk.anims.size():
				frames2 = maxi(int(blk.anims[clip].frames), 1)
			return float(frames2) / CLIP_RATE
	return 0.0


func waypoint(name: String) -> Vector3:
	var key := name.to_lower()
	if waypoints.has(key):
		return waypoints[key]
	for k in waypoints.keys():
		if String(k).begins_with(key):
			return waypoints[k]
	push_warning("[csm] unknown waypoint %s" % name)
	return Vector3.INF


func say(actor: String, key: String) -> float:
	_lip_start(actor)
	var upper := key.to_upper()
	var text := String(subtitles.get(upper, ""))
	label.text = text
	label.visible = text != "" and Game.option("subtitles") != 0
	var length := (float(text.length()) + 20.0) / 20.0
	var bytes := Data.read(SPEECH_DIR + upper + ".mp3")
	if bytes.size() > 0:
		var stream := AudioStreamMP3.new()
		stream.data = bytes
		speech.stream = stream
		if DisplayServer.get_name() != "headless" and Game.option("speech") != 0:
			speech.play()
		length = maxf(length, stream.get_length())
	return length


func say_end(actor: String) -> void:
	_lip_stop(actor)
	speech.stop()
	label.visible = false


## CONFIRMED (FUN_00444330): SETSWITCH writes the value straight into the game
## variable whose index the name has in the switch dictionary (`FUN_004114b7`).
func set_switch(name: String, value: int) -> void:
	if switches.is_empty():
		for row in Table.rows("res://data/island_switches.tsv"):
			if row.size() >= 2:
				switches[String(row[0])] = int(row[1])
	var key := name.strip_edges().to_lower()
	if switches.has(key):
		Game.set_var(int(switches[key]), value)
		_sfx_switch(int(switches[key]), value)
	else:
		push_warning("[csm] unknown switch %s" % name)


## Lip-sync, CONFIRMED from the SAYTEXT executor (FUN_00443CF0): while a line plays,
## the speaker's face frame is re-rolled whenever a countdown (in 30 Hz ticks) runs
## out: frame = int(rand * 10) (0..9); frames below 6 hold for 2 + rand*4 ticks, the
## others for 1 + rand*4. When the line ends the face returns to the expression it had
## before (the byte saved by FUN_004262B0).
var talker := ""
var lip_timer := 0.0
var lip_clock := 0.0
var face_saved := {}


func _lip_start(actor: String) -> void:
	if actor == "":
		return
	talker = actor
	lip_timer = 0.0


func _lip_stop(actor: String) -> void:
	if talker == "":
		return
	set_expression(talker, int(face_saved.get(talker, 0)))
	talker = ""


func _lip_tick(delta: float) -> void:
	if talker == "":
		return
	lip_clock += delta * 30.0
	while lip_clock >= 1.0:
		lip_clock -= 1.0
		lip_timer -= 1.0
		if lip_timer <= 0.0:
			var frame := int(randf() * 10.0)
			var record := 16 if talker == "pepp" else _record(talker)
			if record >= 0:
				island.set_face(str(record), frame)
			lip_timer = (2.0 + randf() * 4.0) if frame < 6 else (1.0 + randf() * 4.0)


## CONFIRMED (the sound behaviour at chunk_0007 ~3560 and its table at VA 0x8A8460,
## rows var / handle index / gate): when a CSM SFX switch var reads 1 the matching
## sound is started and the var is cleared again; reading 4 stops it; reading 8 stops
## it and clears the var. data/island_sfx.tsv holds var -> wav from the exe's own
## tables (handle order at chunk_0007 ~2330, sound table at VA 0x959030).
var sfx := {}
var sfx_players := {}


func _sfx_switch(var_id: int, value: int) -> void:
	if sfx.is_empty():
		for row in Table.rows("res://data/island_sfx.tsv"):
			if row.size() >= 4 and String(row[0]).is_valid_int():
				sfx[int(row[0])] = String(row[3])
	if not sfx.has(var_id):
		return
	if value == 1:
		_sfx_play(var_id)
		Game.set_var(var_id, 0)
	elif value == 4 or value == 8:
		if sfx_players.has(var_id) and is_instance_valid(sfx_players[var_id]):
			(sfx_players[var_id] as AudioStreamPlayer).stop()
		if value == 8:
			Game.set_var(var_id, 0)


func _sfx_play(var_id: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var path := String(sfx[var_id]).replace("//", "/")
	var stream := Wav.parse(Data.read(path))
	if stream == null:
		return
	var player: AudioStreamPlayer = sfx_players.get(var_id)
	if player == null or not is_instance_valid(player):
		player = AudioStreamPlayer.new()
		player.bus = "Sound"
		add_child(player)
		sfx_players[var_id] = player
	player.stream = stream
	player.play()


func set_expression(actor: String, value: int) -> void:
	face_saved[actor] = value
	var record := 16 if actor == "pepp" else _record(actor)
	if record >= 0:
		island.set_face(str(record), clampi(value, 0, 15))


var attached_props := {}


## ATTACH <prop> <holder|null> <bone>: put a prop (the pizza box, the Constructopedia)
## in a hand (bone 14 right, 16 left on the figure rig), or take it away with `null`.
## Only the pizza is built here (the other props are placed records with no mesh yet).
func attach(prop: String, holder: String, bone: String) -> void:
	if attached_props.has(prop):
		var old: Node = attached_props[prop]
		if is_instance_valid(old):
			old.queue_free()
		attached_props.erase(prop)
	if holder == "null" or holder == "":
		return
	if not prop.begins_with("piz"):
		return
	var part_bone := 16 if bone == "lefthand" else (14 if bone == "righthand" else -1)
	if part_bone < 0:
		return
	var hand: Node3D = null
	var list: Array = island.pepper_parts if holder == "pepp" else _parts_of(holder)
	for entry in list:
		if int(entry[1]) == part_bone:
			hand = entry[0]
	if hand == null:
		return
	var pizza: MeshInstance3D = island._build_pizza()
	if pizza == null:
		return
	pizza.get_parent().remove_child(pizza)
	hand.add_child(pizza)
	pizza.position = Vector3.ZERO
	attached_props[prop] = pizza


func _parts_of(holder: String) -> Array:
	var record := _record(holder)
	for item in island.cheerers:
		if record >= 0 and String(item.node.name).ends_with("_%d" % record):
			return item.parts
	return []


func camera_apply(pos: Vector3, target: Vector3, fov: float) -> void:
	island.camera.position = _to_scene(pos)
	if (_to_scene(target) - island.camera.position).length() > 0.001:
		island.camera.look_at(_to_scene(target), Vector3.UP)
	if fov > 0.0:
		island.camera.fov = rad_to_deg(fov)


func csm_finished(_script) -> void:
	active = false
	if talk_tag >= 0:
		_talk_finished()
		talk_tag = -1
	for k in attached_props.keys():
		if is_instance_valid(attached_props[k]):
			attached_props[k].queue_free()
	attached_props.clear()
	holds.erase("pepp")
	island.reset_faces()
	island.camera_locked = false
	island.camera.fov = saved_fov
	label.visible = false
	speech.stop()
	print("[csm] finished %s" % script_name)
	if queued != "":
		var next := queued
		queued = ""
		play(next)
	if not active:
		if engine_driven:
			Game.set_var(0x5E, Game.get_var(0x5E) & ~0x100)
		island.story_hold = false
		island.bridge.services.prompt_mode(0)
		bar_px = 0.0
		bar_top.visible = false
		bar_bottom.visible = false


func _talk_finished() -> void:
	var meta: Array = TALK_LINKS[talk_npc]
	var tag: int = meta[1]
	var kind: int = meta[2]
	var pizza: bool = meta[3]
	if kind != 0:
		Game.set_var(VAR_SCORE_A, Game.get_var(VAR_SCORE_A) + DELIVERY_SCORE)
		Game.set_var(VAR_SCORE_B, Game.get_var(VAR_SCORE_B) + DELIVERY_SCORE)
		if kind == 2:
			var n := Game.get_var(VAR_DELIVERED)
			queued = "lgiph%02d" % (n + 1)
			Game.set_var(VAR_DELIVERED, n + 1)
			Game.set_var(VAR_PIZZA_TRIP, Game.get_var(VAR_PIZZA_TRIP) - 1)
	var bits := TALK_DONE_BITS
	if pizza:
		Game.set_var(VAR_PIZZAS, Game.get_var(VAR_PIZZAS) - 1)
		bits = 0x40003 | 0x8000
	Game.set_var(tag, Game.get_var(tag) | bits)
	talk_tag = -1
	talk_npc = ""


func _animate(delta: float) -> void:
	if holds.has("pepp"):
		island.pepper_time += CLIP_RATE * delta
		island._pose_pepper()


func _to_game(v: Vector3) -> Vector3:
	return Vector3(v.x, v.y, -v.z)


func _to_scene(v: Vector3) -> Vector3:
	return Vector3(v.x, v.y, -v.z)
