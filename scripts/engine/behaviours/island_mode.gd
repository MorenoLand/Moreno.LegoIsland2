class_name IslandMode
extends Behaviour

## The island's Pepper controller: constructor FUN_00453358, update FUN_00452A90 (returns 2),
## post FUN_00452ADD (vtable 0x008A8DC0). It runs on every tick (mask 0) and moves the input
## selector (var 0x5E, low 12 bits) between walking (1), swimming (2), the skateboard (4),
## a machine (8) and the landing after a machine (0x401).
##
## Ported: walking -> skateboard on the action key, the way off the board (the action key, or
## ground that is under the sea ahead), walking -> swimming and back. The island's walker is
## not the engine's (island.gd walks), so swimming is read from the island instead of from
## Pepper's height. OPEN: getting off a machine and the landing spot (FUN_0087EE00), the
## pickup hand-off (FUN_004B81EC / FUN_004B8267), the one-off flag at story state 0x1E
## (FUN_0087DCCC), and the sea ambience tail (FUN_00453987 and the sound at the island's
## edge).

const STATE_WALK := 1
const STATE_SWIM := 2
const STATE_SKATE := 4
const STATE_MACHINE := 8
const STATE_LANDED := 0x401
const CARRY_BIT := 0x1000
const BOARD_RECORD := 9
const CLIP_STEER := 0x4C
const CLIP_WALK_ON := 0x1B
const CLIP_MOUNT := 0x16
const CLIP_DISMOUNT := 0x1C
const CLIP_DIVE := 0x62
const CLIP_TREAD := 0x63
const BOARD_CLIP_ON := 1
const BOARD_CLIP_OFF := 2
const SOUND_MOUNT := 0x5DE1D64
const SOUND_DISMOUNT := 0x5DE1D2C
## The rolling sounds the board lets go of when it is left (DAT_05D50E9C ...).
const ROLL_SOUNDS := [0x5D50E9C, 0x5D50E8C, 0x5D50EA4, 0x5D50E88, 0x5D50E98, 0x5D50E94, 0x5D50E84, 0x5D50E90]
## FUN_0044B287 / FUN_0044B666: the island sounds the board uses (global address, sound id).
const SOUNDS := [
	[0x5D50E9C, 0x180], [0x5D50E8C, 0x17F], [0x5D50EA4, 0x182], [0x5D50E88, 0x185], [0x5D50E98, 0x185],
	[0x5D50E94, 0x12C], [0x5D50E84, 0x181], [0x5D50E90, 0x184], [0x5D50EB8, 0x2C1], [0x5D50EAC, 0x2C5],
	[0x5D50EB0, 0x2C1], [0x5D50EA8, 0x2C2], [0x5D50EBC, 0x2C3], [0x5D50EA0, 0x2C6], [0x5DE1D64, 0x150],
	[0x5DE1D2C, 0x106], [0x5D49EBC, 0x1AB], [0x5DE1D28, 0x128],
]
## Pepper's clips that stop the board being taken: jump, the dive jump, the tread, the swim exit
## and the like (DAT_009749B8 is 1, 2, 0x57, 0x1F or 0x38).
const NO_BOARD_CLIPS := [1, 2, 0x57, 0x1F, 0x38]
const NO_BOARD_ANIM := [0x63, 0x62]
const NO_DISMOUNT := [0x20, 0x32]
const WATER_STEP := 4.0
const WATER_ABORT := [0x20, 0x21]

var services: ActorServices
var vars


static func from_descriptor(services_in: ActorServices, vars_in) -> IslandMode:
	var b := IslandMode.new()
	b.services = services_in
	b.vars = vars_in
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


## FUN_00452A90.
func update(_actor, _block: BehaviourBlock, _var_value: int) -> int:
	return 2


func has_post() -> bool:
	return true


## FUN_00452ADD.
func post(actor) -> void:
	var g := services.talk
	var full: int = vars.get_var(tag)
	var state := full & 0xFFF
	var next := 0
	var clip := 0
	var board = services.record_at(BOARD_RECORD)
	match state:
		STATE_SKATE:
			if ((g.game_flags & 0x10) != 0 or (full & CARRY_BIT) != 0) and not NO_DISMOUNT.has(g.pepper_clip):
				next = STATE_WALK
				clip = CLIP_DISMOUNT
				services.set_clip(board, BOARD_CLIP_OFF, 0.0)
				for key in ROLL_SOUNDS:
					services.sound_release(key)
				services.sound_play(SOUND_DISMOUNT)
			var forward := Vector3(actor.field_f(0x2C), actor.field_f(0x30), actor.field_f(0x34))
			var ahead := Vector3(actor.x, actor.y, actor.z) + forward * WATER_STEP
			if services.terrain_height(ahead, 4.0) <= g.ground_min and not WATER_ABORT.has(g.pepper_clip) and services.current_clip(actor) != CLIP_MOUNT:
				next = STATE_WALK
				clip = CLIP_DISMOUNT
				services.set_clip(board, BOARD_CLIP_OFF, 0.0)
		STATE_SWIM:
			if not services.swimming():
				next = STATE_WALK
		STATE_WALK, STATE_LANDED:
			if state == STATE_LANDED:
				next = STATE_WALK
			vars.set_var(0xBB, 0)
			var taken: bool = g.machine_actor != null
			if (g.game_flags & 0x10) == 0 or NO_BOARD_CLIPS.has(g.pepper_clip) or NO_BOARD_ANIM.has(services.current_clip(actor)) or taken:
				if taken:
					clip = CLIP_STEER
			else:
				next = STATE_SKATE
				clip = CLIP_MOUNT
				services.set_clip(board, BOARD_CLIP_ON, 0.0)
				services.sound_play(SOUND_MOUNT)
				board.flags |= 2
			if services.swimming():
				next = STATE_SWIM
				clip = CLIP_DIVE
	if clip != 0:
		g.pepper_clip = clip
		services.set_pepper_clip(clip)
	if next != 0:
		vars.set_var(tag, next | (full & CARRY_BIT))
