class_name CastleMode
extends Behaviour

## FUN_004E0429 (ctor) / FUN_004DF8C0 (update, vtable 0x008BACD0, returns 2) / FUN_004DFD6E (post).
## The castle's Pepper controller: the post routine is a state machine on the input selector
## (var 0x5E, low 12 bits) that moves Pepper between walking (1), swimming (2), using a thing (4),
## a boat (8), the horse (0x10) and the landing after a ride (0x401). Only the horse's way off
## (state 0x10 -> 0x401 -> 1) and the landing are ported here; the other states, the pickup
## hand-off (FUN_00518D4F / FUN_00518DE4) and the zone's hum sounds are OPEN.
##
## Descriptor +0x18: the spot Pepper is put on when he gets off the horse.

const PEPPER_RECORD := 7
const STATE_WALK := 1
const STATE_SWIM := 2
const STATE_HORSE := 0x10
const STATE_LANDED := 0x401
const CLIP_WALK_ON := 0x1B
const CLIP_SWIM_IN := 0x15
const RIDER_RECORD := 47
const HORSE_RECORD := 48
const SPOT_STEP := 4.0
const SPOT_RISE := 80.0
const SPOT_DROP := -88.0
const SPOT_TRIES := 16
const WATER_SURFACE := 9
const WATER_DROP := 36.0
const HOME_NODE := 0x72
const STORY_RIVER := 0x11
const RIVER_X := -60.0

var spot := Vector3.ZERO
var services: ActorServices
var vars


static func from_descriptor(services_in: ActorServices, vars_in) -> CastleMode:
	var b := CastleMode.new()
	b.services = services_in
	b.vars = vars_in
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


## FUN_004DF8C0: the tick after getting off, Pepper is put on the spot and walks.
func update(actor, _block: BehaviourBlock, var_value: int) -> int:
	if (var_value & STATE_LANDED) == STATE_LANDED:
		actor.x = spot.x
		actor.y = spot.y
		actor.z = spot.z
		services.set_clip(actor, CLIP_WALK_ON, 0.0)
	if (var_value & 1) != 0:
		actor.flags |= 2
	return 2


func has_post() -> bool:
	return true


func post(actor) -> void:
	var g := services.talk
	var full: int = vars.get_var(tag)
	var next := 0
	var clip := 0
	if vars.get_var(0x58) == STORY_RIVER and full != 8 and actor.x < RIVER_X:
		vars.set_var(0x56, 2)
	var mode := full & 0xFFF
	if mode == STATE_HORSE:
		if (g.game_flags & 0x10) != 0 and (vars.get_var(0x112) & 0x10) == 0 and _find_spot(actor):
			g.machine_actor = null
			actor.flags |= 2
			services.record_at(RIDER_RECORD).flags &= ~2
			next = STATE_LANDED
			clip = CLIP_WALK_ON
	elif mode == STATE_LANDED:
		next = STATE_WALK
		if actor.y <= g.ground_min:
			next = STATE_SWIM
			clip = CLIP_SWIM_IN
		actor.flags |= 2
		services.record_at(RIDER_RECORD).flags &= ~2
	if clip != 0:
		g.pepper_clip = clip
		services.set_clip(actor, clip, 0.0)
	if next != 0:
		vars.set_var(tag, next | (full & 0x1000))


## FUN_004DF946: look for firm ground around the horse. The exe grows the ring by adding to a
## factor it also multiplies the offsets by, so the offsets compound (4, 32, 384, ...); this is
## kept as it is. The first candidate with ground that is above the sea level and not inside a
## record is the spot. It loops until one is found; a cap sends Pepper to a waypoint instead.
func _find_spot(actor) -> bool:
	var g := services.talk
	var scale := SPOT_STEP
	var forward := Vector3(actor.field_f(0x2C), actor.field_f(0x30), actor.field_f(0x34))
	var side := Vector3(actor.field_f(0x0C), actor.field_f(0x10), actor.field_f(0x14))
	var here := Vector3(actor.x, actor.y, actor.z)
	for attempt in SPOT_TRIES:
		side = side * -scale
		forward = forward * scale
		var rise := Vector3(0.0, SPOT_RISE, 0.0)
		var candidates := [here + rise + side, here + rise - side, here + rise + forward, here + rise - forward]
		for candidate in candidates:
			var ground := services.terrain_height(candidate, 0.0)
			if g.ground_min <= ground and services.last_surface == WATER_SURFACE:
				candidate.y -= WATER_DROP
				ground = services.terrain_height(candidate, 0.0)
			if g.ground_min < ground:
				if services.record_under(actor, candidate, Vector3(0.0, SPOT_DROP, 0.0)) == null:
					spot = Vector3(candidate.x, ground, candidate.z)
					return true
		scale += SPOT_STEP
	var home = services.waypoint_position(1, HOME_NODE)
	spot = home if home != null else here
	return true
