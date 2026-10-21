class_name MusicEmitter
extends Behaviour

## FUN_004D14A6 (ctor) / FUN_004D10D4 (update, vtable 0x008BA0E0), update returns 1. A
## character that plays music (music01.par notes) while var 0x22 is set and Pepper is
## near: the notes follow an animation node of the actor, grow with the time spent, and
## the character plays its listening clip frames.
##
## Node: +0x14 particle, +0x18 timer, +0x1C..+0x58 matrix of the notes.

const NOTE_NEAR := 576.0
const FAR_SQUARED := 144.0
const GROWTH := 610.0
const NOTE_BONE := 10

var particle := 0
var timer := 0.0
var matrix := PackedFloat32Array()

var services: ActorServices
var vars


static func from_descriptor(services_in: ActorServices, vars_in) -> MusicEmitter:
	var b := MusicEmitter.new()
	b.services = services_in
	b.vars = vars_in
	b.matrix.resize(16)
	b.particle = services_in.particle_create("music01.par", null, Vector3(0.0, 0.5, 0.0), Vector3.ZERO)
	b.timer = 0.0
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	mask = 0
	value = 0


func _follow(actor) -> void:
	var bone := services.anim_node_matrix(actor, NOTE_BONE)
	matrix = ActorServices.matrix_multiply(bone, services.actor_matrix(actor))


func update(actor, block: BehaviourBlock, var_value: int) -> int:
	if vars.get_var(0x22) == 0:
		if (var_value & 0x4000000) != 0:
			vars.clear_var(tag, 0x4000000)
		return 1
	var playing := block.distance_squared <= NOTE_NEAR
	if not playing:
		timer = timer - 5.0 * 1.0
		playing = 0.0 < timer
	if playing:
		block.look_flags |= 0x10
		services.talk.music_flag = 1
		if status != block.frame_counter:
			timer = 0.0
			services.set_clip(actor, 0xFA, 0.0)
			vars.clear_var(tag, 0x1000000)
			vars.or_var(tag, 1)
			services.particles(particle, 2)
			_follow(actor)
			services.particle_attach_matrix(particle, matrix)
		if (var_value & 0x4000000) == 0:
			vars.or_var(tag, 0x4000000)
		services.set_face(actor, 7)
		timer = 1.0 * 1.0 + timer
		var step := int(timer) / 0x78 + 1
		if 3 < step and FAR_SQUARED < block.distance_squared:
			step = 3
			timer = 240.0
		_follow(actor)
		var level := timer / GROWTH
		services.particle_param(particle, 8, level)
		services.particle_param(particle, 9, level)
		level = level * 0.3 + 0.1
		services.particle_param(particle, 0, level)
		if step < 6:
			services.clip_finished(actor, float(step))
		else:
			vars.clear_var(tag, 0x1000000)
			timer = 0.0
			services.particles(particle, 1)
	elif (var_value & 0x4000000) != 0:
		vars.clear_var(tag, 0x4000000)
		services.set_face(actor, 0)
		services.particles(particle, 1)
	return 1
