class_name SmokeEmitter
extends Node3D

const SHEET := "_data/z60FRE/Particle/Text000.tga"
const CELL := 32
const FIRST_SPRITE := 8
const LAST_SPRITE := 11
const MAX_PARTICLES := 5
const LIFESPAN := 0.5
const SPAWN_PER_SECOND := 10.0
const START_SIZE := 0.5
const END_SIZE := 5.0
const FORCE := 0.8
const AIR := 0.97
const GRAVITY := Vector3(-0.01, 0.01, 0.0)
const START_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const END_COLOR := Color(0.846, 0.846, 0.846, 0.0)

var sheet: ImageTexture
var particles: Array = []
var spawn_clock := 0.0
var world: Node
var sheet_path := SHEET


func _ready() -> void:
	if world == null:
		world = get_parent().get_parent()
	var image := Image.new()
	if image.load_tga_from_buffer(Data.read(sheet_path)) == OK:
		sheet = ImageTexture.create_from_image(image)


func _process(delta: float) -> void:
	if sheet == null or world == null:
		return
	if is_visible_in_tree():
		spawn_clock += delta * SPAWN_PER_SECOND
		while spawn_clock >= 1.0:
			spawn_clock -= 1.0
			if particles.size() < MAX_PARTICLES:
				_spawn()
	var keep := []
	for p in particles:
		p.age += delta
		if p.age >= LIFESPAN:
			p.node.queue_free()
			continue
		var t: float = p.age / LIFESPAN
		p.velocity = p.velocity * pow(AIR, delta * 30.0) + GRAVITY * delta * 30.0
		p.node.position += p.velocity * delta * 30.0
		var size := lerpf(START_SIZE, END_SIZE, t)
		p.node.pixel_size = size / CELL
		p.node.modulate = START_COLOR.lerp(END_COLOR, t)
		var frame := FIRST_SPRITE + int(t * (LAST_SPRITE - FIRST_SPRITE + 1))
		frame = mini(frame, LAST_SPRITE)
		p.node.region_rect = Rect2((frame % 8) * CELL, (frame / 8) * CELL, CELL, CELL)
		keep.append(p)
	particles = keep


func _spawn() -> void:
	var node := Sprite3D.new()
	node.texture = sheet
	node.region_enabled = true
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.shaded = false
	node.transparent = true
	node.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	node.region_rect = Rect2((FIRST_SPRITE % 8) * CELL, (FIRST_SPRITE / 8) * CELL, CELL, CELL)
	node.pixel_size = START_SIZE / CELL
	world.add_child(node)
	node.global_position = global_position
	particles.append({"node": node, "age": 0.0, "velocity": Vector3(0, FORCE, 0) * 0.1})
