class_name NoteEmitter
extends Behaviour

## FUN_004CFE5B (ctor) / FUN_004CFB15 (update, vtable 0x008B9F28): the music-note particle
## emitter (notes01.par) of an instrument/record. Visible record: particles on and a note
## puffs at the record, timer +0x60 advances by 1; hidden: particles off. Returns 2.

var timer := 0.0
var services: ActorServices


static func from_descriptor(_desc: Descriptor, services_in: ActorServices) -> NoteEmitter:
	var b := NoteEmitter.new()
	b.services = services_in
	return b


func update(actor, _block, _var_value: int) -> int:
	if not actor.visible():
		services.particles(0, 1)
		return 0
	else:
		services.particles(0, 2)
		services.emit_particle(0, actor)
		timer += 1.0
	return 2
