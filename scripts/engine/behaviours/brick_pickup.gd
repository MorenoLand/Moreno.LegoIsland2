class_name BrickPickup
extends Behaviour

## FUN_004DC5AB (ctor) / FUN_004DC3DF (update, vtable 0x008BAB38), slot 1 returns 1. The
## castle's collectible brick (GOB records): taken when Pepper comes within 2 units, it adds
## 1000 to the score vars 0xAF and 0xCE, shows the zone's shared twinkle on itself for 3 ticks,
## plays the chime and hides; when the twinkle is over it sets its var bits so it stays gone.
## A brick already taken (its bits match mask / value) starts hidden.
##
## Node: +0x18 state (0 waiting, 1 hidden at start, else the ticks of twinkle left).

const NEAR_SQUARED := 4.0
const SCORE := 1000
const CHIME := 0x5DE1CE0

var state := 0

var services: ActorServices
var vars
var actor_record = null


static func from_descriptor(services_in: ActorServices, vars_in, actor) -> BrickPickup:
	var b := BrickPickup.new()
	b.services = services_in
	b.vars = vars_in
	b.actor_record = actor
	return b


func configure(mask_in: int, value_in: int) -> void:
	if (vars.get_var(tag) & mask_in) == value_in:
		state = 0
		actor_record.flags |= 0x10
	else:
		state = 1
		actor_record.flags &= ~2
	if not services.shared.has("brick_twinkle"):
		services.shared["brick_twinkle"] = services.particle_create("TWINKLE01.par", actor_record, Vector3(0.0, 4.0, 0.0), Vector3.ZERO)


func update(actor, block: BehaviourBlock, _var_value: int) -> int:
	var twinkle: int = services.shared["brick_twinkle"]
	if state == 0:
		if block.distance_squared < NEAR_SQUARED:
			vars.add_var(0xAF, SCORE)
			vars.add_var(0xCE, SCORE)
			services.particle_attach(twinkle, actor)
			services.particles(twinkle, 2)
			actor.flags &= ~2
			state = 3
			services.sound_play(CHIME)
	else:
		state -= 1
		if state == 0:
			services.particles(twinkle, 1)
			vars.or_var(tag, mask)
	return 0
