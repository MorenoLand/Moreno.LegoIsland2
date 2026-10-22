class_name RiderClips
extends Behaviour

## FUN_006D25E6 (ctor) / FUN_006D2252 (update, vtable 0x009007B8, returns 1). The rider's
## clip chooser on record 0: it starts the clip for its state, waits for it to end and moves on
## to the clip CarouselWorld.next_rider_clip names; state 4 picks one of four flourishes at
## random, more often the faster the ride.
##
## Node: +0x18 spare, +0x1C state (starts 7), +0x20 rate (starts 1).

const S_FLOURISH := [0x5D4E1F0, 0x5D4E1EC, 0x5D4E1E8, 0x5D4E1E0]

var state := 7
var rate := 1.0

var services: ActorServices


static func from_descriptor(services_in: ActorServices) -> RiderClips:
	var b := RiderClips.new()
	b.services = services_in
	CarouselWorld.set_rider_next(0)
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func update(actor, _block: BehaviourBlock, _var_value: int) -> int:
	match state:
		0:
			services.set_clip(actor, 5, 0.0)
			state = 7
		1:
			services.set_clip(actor, 9, 0.0)
			CarouselWorld.next_rider_clip = 2
			state = 7
		2:
			services.set_clip(actor, 10, 0.0)
			CarouselWorld.next_rider_clip = 3
			state = 7
		3:
			services.set_clip(actor, 5, 0.0)
			state = 7
		4:
			if CarouselWorld.rider_chance <= services.random_float(1.0):
				services.set_clip(actor, 5, 0.0)
			else:
				match int(services.random_float(4.0)):
					0:
						services.set_clip(actor, 9, 0.0)
						services.sound_play(S_FLOURISH[0])
					1:
						services.set_clip(actor, 10, 0.0)
						services.sound_play(S_FLOURISH[1])
					2:
						services.set_clip(actor, 11, 0.0)
						services.sound_play(S_FLOURISH[2])
					3:
						services.set_clip(actor, 6, 0.0)
						services.sound_play(S_FLOURISH[3])
			rate = CarouselWorld.rider_chance * 3.0 + 1.0
			state = 7
		5:
			services.set_clip(actor, 7, 0.0)
			CarouselWorld.next_rider_clip = 3
			state = 7
		6:
			services.set_clip(actor, 4, 0.0)
			CarouselWorld.next_rider_clip = 3
			state = 7
		7:
			if services.clip_ends_within(actor, rate):
				state = CarouselWorld.next_rider_clip
	services.clip_finished(actor, rate)
	return 1
