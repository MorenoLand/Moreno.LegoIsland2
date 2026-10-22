class_name HorseRider
extends Behaviour

## FUN_004DF5D5 (ctor) / FUN_004DF229 (update, vtable 0x008BAC00) / FUN_004DF271 (post). A
## figure that sits on the castle's horse (record 48): Pepper while the horse is ridden (input
## selector 0x10) and the jouster (record 46) whenever the story has him riding. It takes the
## horse's angles and position and plays the clip that goes with the horse's clip at the horse's
## frame.

const HORSE_RECORD := 48
const PEPPER_RECORD := 7
## Story states 0x16..0x18 are the ones where the jouster rides instead of Pepper.
const JOUSTER_FIRST := 0x16
const JOUSTER_LAST := 0x18
## Horse clip -> rider clip, for Pepper (state outside the jouster's) and for the jouster.
const PEPPER_CLIPS := {3: 0xB7, 4: 0xB1, 6: 0xB9}
const PEPPER_DEFAULT := 0xB8
const JOUSTER_CLIPS := {3: 0xC6, 4: 0xB1, 6: 0x8B}
const JOUSTER_DEFAULT := 0xBC

var services: ActorServices
var vars


static func from_descriptor(services_in: ActorServices, vars_in) -> HorseRider:
	var b := HorseRider.new()
	b.services = services_in
	b.vars = vars_in
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func update(actor, _block: BehaviourBlock, var_value: int) -> int:
	var shown := (var_value & 0x10) != 0
	if shown:
		actor.flags |= 2
	else:
		actor.flags &= ~2
	return 1 if shown else 0


func has_post() -> bool:
	return true


func post(actor) -> void:
	var state: int = vars.get_var(0x58)
	var pepper_turn := state < JOUSTER_FIRST or JOUSTER_LAST < state
	var is_pepper: bool = actor == services.record_at(PEPPER_RECORD)
	if is_pepper and pepper_turn:
		actor.flags |= 2
	elif is_pepper or pepper_turn:
		actor.flags &= ~2
	else:
		actor.flags |= 2
	var horse = services.record_at(HORSE_RECORD)
	var clip := services.current_clip(horse)
	var table: Dictionary = PEPPER_CLIPS if pepper_turn else JOUSTER_CLIPS
	var fallback := PEPPER_DEFAULT if pepper_turn else JOUSTER_DEFAULT
	services.set_clip(actor, int(table.get(clip, fallback)), services.anim_frame(horse))
	actor.set_field_f(0x4C, horse.field_f(0x4C))
	actor.set_field_f(0x50, horse.field_f(0x50))
	actor.set_field_f(0x54, horse.field_f(0x54))
	actor.yaw = horse.yaw
	services.set_actor_matrix(actor, Vector3(actor.field_f(0x4C), actor.field_f(0x50), actor.field_f(0x54)), Vector3(horse.x, horse.y, horse.z), Vector3.ONE)
