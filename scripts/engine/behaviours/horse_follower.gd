class_name HorseFollower
extends Behaviour

## FUN_004DF7F8 (ctor) / FUN_004DF67F (update, vtable 0x008BAC18, returns 1 while the record is
## shown, else 0) / FUN_004DF72E (post, returns 1). The saddle, the red saddle and the cloak of the
## castle (records 51..53): each takes the horse's whole matrix, angles, clip and frame every tick,
## so it moves with the horse. The ctor keeps its descriptor's two words (the story range) at
## +0x14 / +0x18; nothing reads them back.

const HORSE_RECORD := 48
const MATRIX_CELLS := [0x0C, 0x10, 0x14, 0x1C, 0x20, 0x24, 0x2C, 0x30, 0x34]

var services: ActorServices


static func from_descriptor(services_in: ActorServices) -> HorseFollower:
	var b := HorseFollower.new()
	b.services = services_in
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func update(actor, _block: BehaviourBlock, _var_value: int) -> int:
	var horse = services.record_at(HORSE_RECORD)
	for cell in MATRIX_CELLS:
		actor.set_field_f(cell, horse.field_f(cell))
	actor.x = horse.x
	actor.y = horse.y
	actor.z = horse.z
	actor.set_field_f(0x4C, horse.field_f(0x4C))
	actor.set_field_f(0x50, horse.field_f(0x50))
	actor.set_field_f(0x54, horse.field_f(0x54))
	services.set_clip(actor, services.current_clip(horse), services.anim_frame(horse))
	return 1 if (actor.flags & 2) != 0 else 0


func has_post() -> bool:
	return true


func post(_actor) -> void:
	pass
