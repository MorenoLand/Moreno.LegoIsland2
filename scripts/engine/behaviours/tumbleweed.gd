class_name Tumbleweed
extends Behaviour

## FUN_0060297E (ctor) / FUN_00602430 (update, vtable 0x008E7AB0) / FUN_0060266E (post) /
## FUN_00602AB5 (destroy). A tumbleweed that rolls along (-0.4, -0.4) a tick while it falls
## in three phases: 0 drops for 30 ticks, 1 bounces down to the ground (a hit by something
## kicks it up again) and 2 sinks and waits 120 ticks before it starts over from its start
## spot. While it is in phase 1 it leaves a move request on its own block (a ground probe from
## 4 above it, resolved by FUN_00876813: it clamps the record onto the ground and the hit state
## the post reads says it touched). The record is lifted 2.1 for the update and put back in the post.
##
## Node: +0x14 / +0x18 / +0x1C start, +0x20 vertical speed, +0x24 height, +0x28 timer,
## +0x2C phase, +0x30 spin.

const DRIFT := -0.4000000059604645
const GRAVITY := 0.004000000189989805
const TERMINAL := 0.4000000059604645
const KICK := 0.07999999821186066
const SPIN_START := 0.1745319962501526
const SPIN_MIN := 0.03490639850497246
const SPIN_STEP := 0.0043633
const SPIN_FLOOR := 0.0349064
const LIFT := 2.1
const GROUND := 0.008
const HIT_KIND := 1
const HIT_VAR := 0x110
## Record code (first four letters) -> the rolling sounds that play while it is on screen
## (the exe compares TUM1's second literal as "TUM0", so TUM1 itself plays none).
const SOUNDS := {
	"TUM0": [0x5D4DAC8, 0x5D4DAB8], "TUM2": [0x5D4DABC], "TUM3": [0x5D4DAC0],
	"TUM4": [0x5D4DAC4], "TUM5": [0x5D4DAB0],
}

var start := Vector3.ZERO
var vertical := 0.0
var height := 0.0
var timer := 0.0
var phase := 0
var spin := 0.0
var sound_keys: Array = []

var services: ActorServices
var vars


static func from_descriptor(services_in: ActorServices, vars_in, actor) -> Tumbleweed:
	var b := Tumbleweed.new()
	b.services = services_in
	b.vars = vars_in
	b.start = Vector3(actor.x, actor.y, actor.z)
	b.vertical = TERMINAL
	b.timer = 0.0
	b.phase = 0
	b.spin = SPIN_START
	b.sound_keys = SOUNDS.get(String(actor.code).substr(0, 4), [])
	actor.yaw = atan2(DRIFT, DRIFT)
	actor.flags |= 0x10
	services_in.model_set_field(actor, 0xFF, 2)
	services_in.model_tint(actor, 0x14, 0xFF555555)
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func update(actor, block: BehaviourBlock, _var_value: int) -> int:
	if (actor.flags & 1) != 0:
		for key in sound_keys:
			services.sound_follow(key, Vector3(actor.x, actor.y, actor.z))
	actor.y -= LIFT
	height = actor.y
	actor.x = DRIFT * 1.0 + actor.x
	actor.z = DRIFT * 1.0 + actor.z
	if phase == 1:
		services.request_hit(block, Vector3(0.0, 4.0, 0.0), Vector3(0.0, -(vertical * 1.0 + 4.0), 0.0), HIT_KIND, HIT_VAR)
	actor.set_field_f(0x4C, spin * 1.0 + actor.field_f(0x4C))
	services.set_rotation(actor, actor.field_f(0x4C), actor.field_f(0x50), actor.field_f(0x54))
	return 1


func has_post() -> bool:
	return true


func post(actor) -> void:
	if phase == 0:
		vertical = vertical - GRAVITY * 1.0
		if vertical < -TERMINAL:
			vertical = -TERMINAL
		timer = 1.0 * 1.0 + timer
		if 30.0 < timer:
			phase = 1
	elif phase == 1:
		var struck := services.block_hit_state(actor.block)
		if struck == 0 or struck == -0x45454546:
			actor.y = vertical * 1.0 + height
			vertical = vertical - GRAVITY * 1.0
			if vertical < -TERMINAL:
				vertical = -TERMINAL
			spin = spin - 1.0 * SPIN_STEP
			if spin < SPIN_FLOOR:
				spin = SPIN_MIN
		else:
			vertical = KICK
			spin = SPIN_START
		if actor.y <= GROUND:
			phase = 2
			timer = 0.0
			vertical = 0.0
			spin = SPIN_MIN
	elif phase == 2:
		actor.y = actor.y - GRAVITY
		timer = 1.0 * 1.0 + timer
		if 120.0 < timer:
			timer = 0.0
			actor.y = start.y
			actor.x = start.x
			actor.z = start.z
			vertical = KICK
			phase = 0
			spin = SPIN_START
	actor.y = actor.y + LIFT
