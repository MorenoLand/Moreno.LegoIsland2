class_name Gem
extends Behaviour

## FUN_00600E30 (ctor) / FUN_00600C50 (update, vtable 0x008E7998), slot 1 returns 1. A gem
## that is taken when Pepper comes within 2 units: it adds 1000 to the score vars 0xCA and
## 0x17, shows the shared twinkle on itself for 3 ticks, plays a chime and hides; when the
## twinkle is over it sets its var bits so it stays gone. Gems already taken (their bits
## match mask / value) start hidden.
##
## Node: +0x18 own GEM01 sparkle, +0x1C state (0 waiting, else the ticks of twinkle left).

const NEAR_SQUARED := 4.0
const SCORE := 1000
const CHIME := 0x5DE1CE0

var sparkle := -1
var state := 0

var services: ActorServices
var vars


var actor_record = null


static func from_descriptor(services_in: ActorServices, vars_in, actor) -> Gem:
	var b := Gem.new()
	b.services = services_in
	b.vars = vars_in
	b.actor_record = actor
	return b


## The rest of the constructor, which needs the var mask and value the registration passes.
func configure(mask_in: int, value_in: int) -> void:
	services.model_set_field(actor_record, 0xFF, 2)
	if (vars.get_var(tag) & mask_in) == value_in:
		state = 0
		actor_record.flags |= 0x10
		sparkle = services.particle_create("GEM01.par", actor_record, Vector3.ZERO, Vector3.ZERO)
		services.particles(sparkle, 2)
	else:
		state = 1
		actor_record.flags &= ~2
	if not services.shared.has("gem_twinkle"):
		services.shared["gem_twinkle"] = services.particle_create("TWINKLE01.par", actor_record, Vector3(0.0, 4.0, 0.0), Vector3.ZERO)


func update(actor, block: BehaviourBlock, _var_value: int) -> int:
	var twinkle: int = services.shared["gem_twinkle"]
	if state == 0:
		if block.distance_squared < NEAR_SQUARED:
			vars.add_var(0xCA, SCORE)
			vars.add_var(0x17, SCORE)
			services.particle_attach(twinkle, actor)
			services.particles(twinkle, 2)
			services.particles(sparkle, 1)
			actor.flags &= ~2
			state = 3
			services.sound_play(CHIME)
	else:
		state -= 1
		if state == 0:
			services.particles(twinkle, 1)
			vars.or_var(tag, mask)
	return 0
