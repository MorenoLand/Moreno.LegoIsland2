extends Node

## Performance readout. F1 shows and hides it, drag it with the left mouse button,
## F3 clears the worst-frame counters. The position is remembered between runs.

const PANEL_MARGIN := 6.0
const LINE_HEIGHT := 15
const PAD := 8
const CFG_PATH := "user://debug_overlay.cfg"
const DRAG_THRESHOLD := 3

var visible_now := false
var font: Font
var lines: PackedStringArray = PackedStringArray()
var panel_size := Vector2.ZERO
var anchor := Vector2.ZERO

var worst_ms := 0.0
var worst_hold := 0
var drag_from := Vector2.ZERO
var drag_anchor_from := Vector2.ZERO
var dragging := false
var drag_moved := false

var _canvas: CanvasLayer
var _panel: Control


func _ready() -> void:
	if _canvas != null:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = ThemeDB.fallback_font
	_canvas = CanvasLayer.new()
	_canvas.layer = 128
	add_child(_canvas)
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.draw.connect(_draw_panel)
	_canvas.add_child(_panel)
	_load_cfg()
	_canvas.visible = visible_now
	_panel.position = anchor
	if visible_now:
		_rebuild()


func _process(_delta: float) -> void:
	if not visible_now:
		return
	var ms := _delta * 1000.0
	if _delta > 0.0 and ms > worst_ms:
		worst_ms = ms
		worst_hold = 0
	elif worst_hold < 180:
		worst_hold += 1
	_rebuild()


func _rebuild() -> void:
	var fps := Engine.get_frames_per_second()
	var frame_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var nav_ms := Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objects := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var vram := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	var tex := int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	var buffers := int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED))
	var static_mem := OS.get_static_memory_usage()
	var vp := _viewport_size()

	lines = PackedStringArray()
	lines.append("%.0f fps   %.2f ms   worst %.1f ms (%.0f fps)" % [
		fps, frame_ms, worst_ms, (1000.0 / worst_ms) if worst_ms > 0.01 else 0.0])
	lines.append("cpu  process %.2f  physics %.2f  nav %.2f ms" % [frame_ms, physics_ms, nav_ms])
	lines.append("draw %d   objects %d   prims %d" % [draws, objects, prims])
	lines.append("vram %s   texture %s   buffers %s   static %s" % [
		_bytes(vram), _bytes(tex), _bytes(buffers), _bytes(static_mem)])
	lines.append("%s   %dx%d   %s" % [
		_adapter(), int(vp.x), int(vp.y), ProjectSettings.get_setting(
			"rendering/renderer/rendering_method", "gl_compatibility")])
	lines.append("F1 hide   drag to move   F3 reset worst")

	var width := 0.0
	for line in lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x)
	panel_size = Vector2(width + PAD * 2.0, lines.size() * LINE_HEIGHT + PAD * 2.0 + 2.0)
	_clamp_anchor()
	if _panel == null:
		return
	_panel.position = anchor
	_panel.size = panel_size
	_panel.queue_redraw()


func _draw_panel() -> void:
	if not visible_now or _panel == null:
		return
	var r := Rect2(Vector2.ZERO, panel_size)
	_panel.draw_rect(r, Color(0.05, 0.06, 0.08, 0.82), true)
	_panel.draw_rect(r, Color(0.55, 0.75, 1.0, 0.45), false, 1.0)
	for i in lines.size():
		_panel.draw_string(
			font, Vector2(PAD, PAD + (i + 1) * LINE_HEIGHT), lines[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.88, 0.94, 1.0))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		visible_now = not visible_now
		if _canvas != null:
			_canvas.visible = visible_now
		if visible_now:
			worst_ms = 0.0
			_rebuild()
		_save_cfg()
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return
	if not visible_now:
		return
	if event.is_action_pressed("reset_debug_stats"):
		worst_ms = 0.0
		worst_hold = 0
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _hit((event as InputEventMouseButton).position):
				dragging = true
				drag_moved = false
				drag_from = (event as InputEventMouseButton).position
				drag_anchor_from = anchor
		elif dragging:
			dragging = false
			if drag_moved:
				_save_cfg()
		return
	if event is InputEventMouseMotion and dragging:
		var delta: Vector2 = (event as InputEventMouseMotion).position - drag_from
		if delta.length() > DRAG_THRESHOLD:
			drag_moved = true
		anchor = drag_anchor_from + delta
		_clamp_anchor()


func _viewport_size() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2(1280, 720)
	return viewport.get_visible_rect().size


func _hit(screen_pos: Vector2) -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2(anchor, panel_size).has_point(screen_pos)
	var canvas_pos := viewport.get_canvas_transform().affine_inverse() * screen_pos
	return Rect2(anchor, panel_size).has_point(canvas_pos)


func _clamp_anchor() -> void:
	var vp := _viewport_size()
	anchor.x = clampf(anchor.x, -panel_size.x * 0.5, vp.x - PANEL_MARGIN)
	anchor.y = clampf(anchor.y, PANEL_MARGIN, vp.y - panel_size.y - PANEL_MARGIN)


func _adapter() -> String:
	# this build reports the adapter as a list of strings
	var info: Variant = OS.get_video_adapter_driver_info()
	if info is PackedStringArray:
		var parts: PackedStringArray = info
		return parts[0] if parts.size() > 0 else "unknown adapter"
	var text := String(info)
	return text if text != "" else "unknown adapter"


func _bytes(value: int) -> String:
	if value <= 0:
		return "-"
	if value < 1024:
		return "%d B" % value
	if value < 1024 * 1024:
		return "%.1f KB" % (value / 1024.0)
	if value < 1024 * 1024 * 1024:
		return "%.1f MB" % (value / 1048576.0)
	return "%.2f GB" % (value / 1073741824.0)


func _save_cfg() -> void:
	var file := FileAccess.open(CFG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_var(anchor)
	file.store_var(visible_now)


func _load_cfg() -> void:
	anchor = Vector2(16, 16)
	if not FileAccess.file_exists(CFG_PATH):
		return
	var file := FileAccess.open(CFG_PATH, FileAccess.READ)
	if file == null:
		return
	var pos: Variant = file.get_var()
	if pos is Vector2:
		anchor = pos
	if not file.eof_reached():
		visible_now = bool(file.get_var())