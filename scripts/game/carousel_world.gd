class_name CarouselWorld
extends RefCounted

## z36CNT's file-scope globals (the HUD reads them): the score shown, the best-so-far result,
## the speed fraction and the combo, plus the rider's next clip (FUN_006D2210).

static var shown_score := 0
static var gold := false
static var combo := 0
static var speed_fraction := 0.0
static var timer := 0.0
static var hits := 0.0
static var next_rider_clip := 0
static var spoke_bonus := false
static var ended_text := 0
static var rider_chance := 0.0
static var services: ActorServices
static var speech := {}


static func reset() -> void:
	shown_score = 0
	gold = false
	combo = 0
	speed_fraction = 0.0
	timer = 0.0
	hits = 0.0
	next_rider_clip = 0
	spoke_bonus = false
	ended_text = 0
	rider_chance = 0.0


## FUN_006D2210(n): the clip the rider moves on to when the one playing ends.
static func set_rider_next(n: int) -> void:
	var value := maxi(n, 0)
	if 3 < value:
		value = 4
	next_rider_clip = value


## FUN_00421C4D(table, name) + FUN_0041DD01: play a line of the zone's speech file.
static func say(name: String) -> void:
	var found := services.speech_lookup(speech, name)
	services.subtitle_show(String(found[0]))
	services.speech_queue(int(found[1]), -1)
	services.speech_start()
