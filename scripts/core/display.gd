extends Node

signal stretch_changed(stretched: bool)

const DESIGN_SIZE := Vector2(800, 600)

var stretched := true:
	set(value):
		stretched = value
		stretch_changed.emit(stretched)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_stretch"):
		stretched = not stretched


func ui_rect(size: Vector2) -> Rect2:
	if stretched:
		return Rect2(Vector2.ZERO, size)
	var scale := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	var fitted := DESIGN_SIZE * scale
	return Rect2((size - fitted) * 0.5, fitted)
