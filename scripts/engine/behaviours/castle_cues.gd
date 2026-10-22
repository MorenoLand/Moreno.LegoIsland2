class_name CastleCues
extends Behaviour

## FUN_004DB9F4 (ctor) / FUN_004DB260 (update, returns 2) / FUN_004DB523 (post), vtable
## 0x008BA6C8. The castle's sound and music cues: sounds started from game vars, the
## animation-frame footsteps and chimes of the other characters, the lamp particle on a bone of
## record 47, and the music level that follows what Pepper and the horse are doing.
##
## Node: +0x18 music level, +0x1C last music level, +0x20 lamp particle, +0x24 its matrix.

## FUN_004DB260's table at 0x008BA6E0: (game var, sound index, record whose spot plays it).
const SOUND_ROWS := [
	[191, 0, 74], [51, 1, 42], [219, 2, 42], [154, 3, 42], [216, 4, 67], [158, 5, 24], [139, 6, 47],
	[48, 7, 48], [71, 8, 48], [148, 9, 48], [50, 4, 7], [159, 10, 70], [28, 11, 48], [28, 12, 7], [54, 13, 47],
]
## Sound index -> the zone's sound key (the handles FUN_004D8DA0 creates).
const SOUND_KEYS := [
	0x5D4A3FC, 0x5D4A404, 0x5D4A450, 0x5D4A42C, 0x5D4A3F4, 0x5D4A428, 0x5D4A410,
	0x5D4A3F0, 0x5D4A498, 0x5D4A408, 0x5D4A454, 0x5D4A430, 0x5D4A414, 0x5D4A458,
]
## FUN_004DB523: (record, clip, frame, sound key): the sound plays on that frame of that clip.
const FRAME_SOUNDS := [
	[37, 0x79, 2, 0x5D4A448], [38, 0x91, 1, 0x5D4A444], [26, 0x91, 3, 0x5D4A44C], [27, 0x92, 3, 0x5D4A444],
	[28, 0x91, 1, 0x5D4A44C], [39, 0x92, 6, 0x5D4A448], [40, 0x91, 4, 0x5D4A44C],
]
const LAMP_RECORD := 47
const LAMP_BONE := 0x10
const HORSE_RECORD := 48
const PEPPER_RECORD := 7
const SCENE_FLAG_RECORDS := [48, 29]
const LAST_FRAME_START := 100
const RIDING_CLIPS := [0x24, 0x3F, 0x40]

var music_level := 1
var last_level := 1
var lamp := 0
var lamp_matrix := PackedFloat32Array()
var last_clip := 0
var last_frame := LAST_FRAME_START

var services: ActorServices
var vars


static func from_descriptor(services_in: ActorServices, vars_in) -> CastleCues:
	var b := CastleCues.new()
	b.services = services_in
	b.vars = vars_in
	var lamp_record = services_in.record_at(LAMP_RECORD)
	b.lamp_matrix = services_in.actor_matrix(lamp_record)
	b.lamp = services_in.particle_create("cedric.par", lamp_record, Vector3(0.0, -0.4, 1.6), Vector3.ZERO)
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func _position(index: int) -> Vector3:
	var record = services.record_at(index)
	return Vector3(record.x, record.y, record.z)


func update(_actor, _block: BehaviourBlock, _var_value: int) -> int:
	for row in SOUND_ROWS:
		var state: int = vars.get_var(row[0])
		var key: int = SOUND_KEYS[row[1]]
		if state == 1:
			services.sound_follow(key, _position(row[2]))
			vars.set_var(row[0], 2)
		elif state == 4:
			services.sound_follow(key, _position(row[2]))
		elif state == 8:
			services.sound_release(key)
			vars.set_var(row[0], 2)
	var visible := services.scene_active
	for index in SCENE_FLAG_RECORDS:
		var flagged = services.record_at(index)
		if visible:
			flagged.flags |= 0x10
		else:
			flagged.flags &= ~0x10
	var lamp_base = services.record_at(LAMP_RECORD)
	var light: int = vars.get_var(0x113)
	if light == 1:
		lamp_matrix = ActorServices.matrix_multiply(services.anim_node_matrix(lamp_base, LAMP_BONE), services.actor_matrix(lamp_base))
		services.particles(lamp, 2)
		services.particle_attach_matrix(lamp, lamp_matrix)
		vars.set_var(0x113, 2)
	elif light == 2:
		lamp_matrix = ActorServices.matrix_multiply(services.anim_node_matrix(lamp_base, LAMP_BONE), services.actor_matrix(lamp_base))
	elif light == 3:
		services.particles(lamp, 1)
		vars.set_var(0x113, 0)
	return 2


func has_post() -> bool:
	return true


func post(_actor) -> void:
	for row in FRAME_SOUNDS:
		var record = services.record_at(row[0])
		if (record.flags & 1) == 0:
			continue
		if services.current_clip(record) == row[1] and int(services.anim_frame(record)) == row[2]:
			services.sound_follow(row[3], Vector3(record.x, record.y, record.z))
	var horse = services.record_at(HORSE_RECORD)
	if (horse.flags & 1) == 0:
		var pepper = services.record_at(PEPPER_RECORD)
		var status: int = vars.get_var(0x5E)
		if (status & 1) == 0:
			music_level = 3 if (status & 4) != 0 else 1
		else:
			music_level = 2 if services.current_clip(pepper) in RIDING_CLIPS else 1
	else:
		var clip := services.current_clip(horse)
		var frame := int(services.anim_frame(horse))
		if clip == last_clip and frame == last_frame:
			return
		music_level = 3 if clip == 3 and last_frame != frame else 1
		last_clip = clip
		last_frame = frame
	if music_level != last_level:
		services.music_level(music_level - 3)
		last_level = music_level
