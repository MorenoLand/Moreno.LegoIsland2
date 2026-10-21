class_name BotDefeat
extends Behaviour

## FUN_004CCE41 (ctor) / FUN_004CC527 (update, vtable 0x008B9D90) / FUN_004CCBE7 (post),
## update returns 1. What happens to a BrickBot when it is hit: it is knocked about
## (clips 0x94 / 0xCF / 0x95 / 0x11B), explodes and swirls with particles, shrinks away
## and finally sets its var to 0x4000 (the post starts the shrink when Pepper is close
## and credits the score and the colour var 0x8E).
##
## Node: +0x14 explosion particle, +0x18 swirl particle, +0x1C shrink scale, +0x20 stage,
## +0x22 dying (10 = shrinking, -1 = gone), +0x24 armed, +0x25 waiting for the hit, +0x26
## hit kind, +0x28 linked var, +0x2A idle clip running, +0x2C idle timer.

const SOUND_DEFEAT := 0x5DE1CE0
const SOUND_HIT := 0x5D49E30
const NEAR_SQUARED := 4.0

var explosion := 0
var swirl := 0
var shrink := 0.0
var stage := 0
var dying := 0
var armed := 1
var waiting := 1
var hit := 0
var linked_var := 0
var idle_running := 0
var idle_timer := 0.0

var services: ActorServices
var vars


static func from_descriptor(desc: Descriptor, services_in: ActorServices, vars_in, actor) -> BotDefeat:
	var b := BotDefeat.new()
	b.services = services_in
	b.vars = vars_in
	b.explosion = services_in.particle_create("Explode01.par", actor, Vector3(0.0, 4.0, 0.0), Vector3(-1.5707963705062866, 0.0, 0.0))
	b.swirl = services_in.particle_create("swirl01.swl", actor, Vector3(0.0, 3.200000047683716, -2.0), Vector3(-1.5707963705062866, 0.0, 0.0))
	b.dying = 0
	services_in.walkers.set_option_flags(actor.block.walker, 1, 2)
	b.armed = 1
	b.waiting = 1
	b.idle_running = 0
	b.idle_timer = 0.0
	b.linked_var = desc.s16(0)
	if b.linked_var > 1:
		vars_in.or_var(b.linked_var, 0x20000)
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	mask = 0
	value = 0


func _finish(actor) -> void:
	services.particles(swirl, 1)
	services.particles(explosion, 1)
	actor.flags &= ~2
	stage = 0


func update(actor, block: BehaviourBlock, var_value: int) -> int:
	var g := services.talk
	var v := var_value
	var health: int = vars.get_var(0x58)
	if dying != 0:
		if dying == -1:
			vars.set_var(tag, 0x4000)
			_finish(actor)
		else:
			shrink = shrink - 0.20000000298023224 * 1.0
			if 0.0 < shrink:
				services.set_actor_matrix(actor,
						Vector3(actor.field_f(0x4C), actor.field_f(0x50), actor.field_f(0x54)),
						Vector3(actor.x, actor.y, actor.z), Vector3(shrink, shrink, shrink))
			else:
				dying = -1
				vars.set_var(tag, 0x4000)
				_finish(actor)
		return 1
	if (v & 0x1000000) == 0:
		if (v & 0x4020000) == 0 and (v & 0x3000) == 0:
			if idle_running == 0:
				if 0x33 < health:
					if 0.0 < idle_timer:
						idle_timer = idle_timer - 1.0 * 1.0
					if (v & 0x200) != 0 and idle_timer <= 0.0:
						idle_running = 1
						services.set_clip(actor, 0x70, 0.0)
			elif services.clip_finished(actor, 1.0):
				idle_running = 0
				idle_timer = 60.0
			return 1
		if 0x33 < health:
			return 1
	else:
		hit = -1
		v |= 0x3000
	if (v & 0x1000) == 0:
		if dying < 0:
			vars.set_var(tag, 0)
			actor.flags &= ~2
			block.flags &= ~2
			_finish_particles(actor)
	else:
		if (v & 0x10000) == 0:
			if armed != 0:
				if (v & 0x1000000) == 0:
					if (v & 0x2000) == 0:
						vars.clear_var(tag, 0x1000)
					else:
						hit = g.hit_kind(actor, vars)
						if hit != 0:
							armed = 0
							vars.clear_var(tag, 0xFE)
							vars.or_var(tag, 1)
							services.sound_follow(SOUND_HIT, Vector3(actor.x, actor.y, actor.z))
						if 2 < linked_var:
							vars.or_var(linked_var, 1)
							g.notify_group(actor, 1, 0, vars)
							vars.clear_var(linked_var, 0x20000)
					return 1
				hit = -1
				armed = 0
				vars.clear_var(tag, 0xFE)
				vars.or_var(tag, 1)
		else:
			armed = 0
			hit = 3
			vars.clear_var(tag, 0x10000)
		if waiting == 0:
			if stage == 0:
				if services.clip_finished(actor, 1.0):
					actor.flags |= 0x40
					services.walkers.relink(block.walker)
					vars.clear_var(tag, 0x1000)
					vars.clear_var(tag, 0x1000000)
					services.particles(swirl, 1)
					armed = 1
					waiting = 1
			else:
				block.look_flags |= 0x10
				if (v & 0x2000) != 0:
					hit = g.hit_kind(actor, vars)
					if hit != 0:
						stage = 5
				if services.clip_finished(actor, 1.0):
					if stage == 5:
						services.set_clip(actor, 0x95, 0.0)
						stage -= 1
					else:
						stage -= 1
						if stage == 0:
							services.set_clip(actor, 0x11B, 0.0)
		else:
			services.particle_attach(swirl, actor)
			services.particles(swirl, 2)
			actor.flags &= ~0x40
			if hit == 1:
				services.set_clip(actor, 0x94, 0.0)
				stage = 5
			elif hit == 2:
				services.set_clip(actor, 0xCF, 0.0)
				stage = 5
			else:
				services.set_clip(actor, 0x95, 0.0)
				stage = 4
			waiting = 0
	return 1


func _finish_particles(actor) -> void:
	services.particles(swirl, 1)
	services.particles(explosion, 1)
	stage = 0


func has_post() -> bool:
	return true


func post(actor) -> void:
	if (actor.flags & 1) != 0 and dying == 0:
		if actor.block.distance_squared < NEAR_SQUARED:
			dying = 10
			shrink = 0.8999999761581421
			vars.add_var(0x52, 1)
			vars.add_var(0xA6, 1000)
			vars.add_var(0x12, 1000)
			services.sound_play(SOUND_DEFEAT)
			services.particle_attach(explosion, actor)
			services.particles(explosion, 2)
			match String(actor.code).unicode_at(2):
				0x42:
					vars.or_var(0x8E, 8)
				0x47:
					vars.or_var(0x8E, 4)
				0x52:
					vars.or_var(0x8E, 2)
				0x59:
					vars.or_var(0x8E, 1)
