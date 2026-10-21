extends Control

signal finished

var player: VideoStreamPlayer
var skippable := false
var done := false


func _ready() -> void:
	player = VideoStreamPlayer.new()
	player.expand = true
	player.finished.connect(_end)
	add_child(player)


func play(path: String, can_skip: bool) -> void:
	skippable = can_skip
	done = false
	var stream := VideoStreamTheora.new()
	stream.file = path
	player.stream = stream
	player.play()


func _process(_delta: float) -> void:
	var rect := Display.ui_rect(size)
	player.position = rect.position
	player.size = rect.size


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)


func _input(event: InputEvent) -> void:
	if skippable and event is InputEventKey and event.pressed and not event.echo:
		_end()


func _end() -> void:
	if done:
		return
	done = true
	player.stop()
	finished.emit()
