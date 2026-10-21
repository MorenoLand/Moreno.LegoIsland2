class_name HoloGuide
extends Behaviour

## FUN_0087E961 (ctor) / FUN_0087DE2F (update, vtable 0x00974F78) / FUN_0087E076 (post),
## update returns 0 / 1. The hologram guide ("HOLO"): it appears next to Pepper with a
## hint (a speech line named HOLO + a letter), turns toward the talk target, wobbles
## while it speaks and folds away again.
##
## Node: +0x18 timer, +0x1C state (0 idle, 1 gone, 2 showing, 3 waiting), +0x1D animation
## (0 talk, 1 grow, 2 shrink, 3 wobble, 4 blink), +0x1E hide when gone, +0x1F line letter,
## +0x20..+0x28 / +0x2C..+0x34 saved position / angles, +0x38..+0x40 last Pepper position,
## +0x44 scale, +0x48 wobble amount, +0x4C animation timer, +0x50 line name, +0x57 aim mode,
## +0x58 queued speech.

const SHOWING_TICKS := 210.0
const WAIT_TICKS := 20.0
const SCALE_STEP := 0.10000000149011612
const FULL_SCALE := 0.75
const LINE_BASE := "HOLO"

var timer := 0.0
var state := 1
var animation := 0
var hide_when_gone := 0
var letter := 0x40
var saved_position := Vector3.ZERO
var saved_angles := Vector3.ZERO
var last_player := Vector3.ZERO
var scale_now := 0.0
var wobble := 0.0
var animation_timer := 0.0
var line_name := ""
var aim_mode := 0
var queued_speech := -1

var services: ActorServices
var vars


static func from_descriptor(services_in: ActorServices, vars_in, actor) -> HoloGuide:
	var b := HoloGuide.new()
	b.services = services_in
	b.vars = vars_in
	actor.flags |= 0x10
	b.hide_when_gone = 0
	b.state = 1
	b.timer = 0.0
	b.letter = 0x40
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


## FUN_0087DCDB: the guide shows up.
func _start(actor) -> void:
	var g := services.talk
	g.helper_ready = 0
	letter += 1
	line_name = LINE_BASE + char(letter)
	var looked := services.speech_lookup(g.helper_table, line_name)
	if String(looked[0]).substr(0, 5) == line_name.substr(0, 5):
		letter = 0x40
		line_name = LINE_BASE + char(0x41)
	saved_position = Vector3(actor.x, actor.y, actor.z)
	saved_angles = Vector3(actor.field_f(0x4C), actor.field_f(0x50), actor.field_f(0x54))
	vars.set_var(0xC6, 1)
	animation = 1
	scale_now = 0.0
	wobble = 0.0
	aim_mode = 1
	state = 2
	timer = 0.0
	actor.flags |= 2
	services.prompt_mode(2)
	g.busy = 1
	services.set_clip(actor, 0x82, 0.0)


func update(actor, _block: BehaviourBlock, _var_value: int) -> int:
	var g := services.talk
	if 0.0 < g.helper_timer:
		g.helper_timer = g.helper_timer - 1.0 * 1.0
		if g.helper_timer <= 0.0:
			g.helper_ready = 1
	match state:
		0:
			if g.helper_ready == 0:
				if (g.game_flags & 0x40) != 0:
					timer = 0.0
					state = 3
				return 0
			_start(actor)
		1:
			vars.set_var(0xC6, 0)
			state = 0
			g.busy = 0
			return 0
		2:
			timer = 1.0 * 1.0 + timer
			if timer <= SHOWING_TICKS:
				if not services.scene_active:
					if (g.game_flags & 0x40) != 0:
						if vars.get_var(9) != 0:
							services.speech_clear()
						animation = 2
				else:
					animation = 2
					scale_now = 0.0
			else:
				animation = 2
		3:
			if g.helper_ready == 0:
				if services.scene_active or g.busy != 0 or (vars.get_var(0x5E) & 4) != 0:
					state = 0
					return 0
				if (g.game_flags_b & 0x40) == 0:
					state = 1
					return 0
				timer = 1.0 * 1.0 + timer
				if timer <= WAIT_TICKS:
					return 0
				_start(actor)
			else:
				_start(actor)
	g.helper_ready = 0
	return 1


func has_post() -> bool:
	return true


func _face(actor, from: Vector3, to: Vector3) -> void:
	actor.yaw = atan2(to.x - from.x, to.z - from.z)


func post(actor) -> void:
	var g := services.talk
	var player = services.player
	var camera_forward := services.camera_forward
	var camera_right := services.camera_right
	var spot := Vector3(
		player.x + camera_forward.x * -4.0 + camera_right.x + camera_right.x,
		player.y + camera_forward.y * -4.0 + camera_right.y + camera_right.y,
		player.z + camera_forward.z * -4.0 + camera_right.z + camera_right.z)
	var player_at := Vector3(player.x, player.y, player.z)
	var aim := aim_mode
	var face_player := false
	if aim == 1:
		var target = TalkNode.pick_target(services, vars, actor)
		if target != null:
			services.set_clip(actor, 0x81, 0.0)
			_face(actor, spot, target)
			aim_mode = 2
		else:
			aim_mode = 3
			aim = 2
	if aim == 2:
		var target2 = TalkNode.pick_target(services, vars, actor)
		if target2 == null:
			face_player = true
		else:
			_face(actor, spot, target2)
			if services.anim_frame(actor) < 15.0:
				services.clip_finished(actor, 1.0)
	elif aim == 0 or aim == 3:
		face_player = true
	if face_player:
		_face(actor, spot, player_at)
		services.clip_finished(actor, 1.0)
	match animation:
		0:
			var mood: int = vars.get_var(0x58)
			var strength := 0.0
			if mood < 7 or 8 < mood:
				var d := player_at - spot
				var near_squared := d.z * d.z + d.y * d.y + d.x * d.x
				strength = 0.5 if 0.00800000037997961 <= near_squared else 0.3
			else:
				strength = 0.75
			if queued_speech > -1 and services.speech_idle():
				services.speech_queue(queued_speech, -1)
				queued_speech = -1
			var roll := services.random_float(10.0)
			if roll <= 10.0 - strength:
				if 10.0 - (strength + strength) < roll:
					animation = 3
					animation_timer = 0.0
					wobble = services.random_float(1.0) - 0.5
			else:
				animation = 4
				animation_timer = 0.0
		1:
			scale_now = 0.10000000149011612 + scale_now
			if FULL_SCALE < scale_now:
				animation = 0
				var found := services.speech_lookup(g.helper_table, line_name)
				if vars.get_var(9) == 0:
					queued_speech = -1
				else:
					if services.speech_idle():
						services.speech_queue(int(found[1]), -1)
						queued_speech = -1
					else:
						queued_speech = int(found[1])
				g.speech_name = String(found[0])
				if vars.get_var(0) != 0:
					services.subtitle_show(g.speech_name)
		2:
			scale_now = scale_now - SCALE_STEP
			if scale_now < SCALE_STEP:
				actor.set_field_f(0x4C, saved_angles.x)
				actor.set_field_f(0x50, saved_angles.y)
				actor.set_field_f(0x54, saved_angles.z)
				services.set_matrix_at(actor, saved_position)
				if hide_when_gone != 0:
					actor.flags &= ~2
				state = 1
				if services.get_prompt_mode() == 2:
					services.prompt_mode(0)
				services.subtitle_clear()
				return
	var drop := scale_now + scale_now
	spot.y = (2.0 - drop) + spot.y + 3.0
	services.set_actor_matrix(actor,
			Vector3(actor.field_f(0x4C), actor.field_f(0x50), actor.field_f(0x54)),
			spot, Vector3(scale_now, scale_now, scale_now))
	if animation == 3:
		animation_timer = 1.0 * 1.0 + animation_timer
		if animation_timer <= 3.0:
			services.shear_matrix(actor, wobble)
		else:
			animation = 0
	elif animation == 4:
		animation_timer = 1.0 * 1.0 + animation_timer
		if animation_timer <= 3.0:
			actor.flags &= ~1
		else:
			animation = 0
	last_player = Vector3(player.x, player.y, player.z)
