class_name Island
extends Node3D

const Waypoints = preload("res://scripts/core/waypoints.gd")
const CsmHostScript = preload("res://scripts/game/csm_host.gd")
const BrickMorphScript = preload("res://scripts/game/brick_morph.gd")
const Story = preload("res://scripts/core/story.gd")

const ISLAND_ZONE := "z02LGI"
const HOUSE_ZONE := "z03PPH"
const PARK_ZONE := "z01BPK"
const TRAVEL_ORDER := ["z02LGI", "z03PPH", "z01BPK", "z04IFC", "z05WAB", "z07CSI", "z08BKD", "z09JST", "z10RGB", "z13CAI", "z14OSD", "z15SSH", "z16PYA", "z17WAS", "z18MMP", "z20DSP", "z21FSH", "z22BIP", "z23DIP", "z27TRX", "z28HAT", "z36CNT", "z38PAR", "z39ASB", "z40OGL", "z40aPO", "z41MAP", "z42BRP", "z50LTC"]
const ISLAND_ZONE_ID := 2
const MUSIC_DIRECTORY := "_data/sounds/DirectMusic/z02LGI/"
const MUSIC_DEFAULT := "Lego Town Main.sgt"
const MUSIC_RADIUS_SQUARED := 1600.0
# Town ambience: birdsong and gulls, played from the game's own MIDI files
# through a dedicated DLS. Ambience_DB keeps them under the score.
const AMBIENCE := [["Birds.mid"], ["Seagulls.mid"]]
const AMBIENCE_DB := -26.0
const MUSIC_SITES := [
	[124, "Infoman1.sgt"],
	[120, "Laura Brick.sgt"],
	[123, "PapaBrick.sgt"],
	[126, "MamaBrick.sgt"],
	[121, "Nick Brick.sgt"],
]
const FOV := 60.0
## The zones whose set-up loads `sky.Msh` (the exe's path strings name it for exactly these; the dive and
## the park have no sky dome).
const SKY_ZONES := ["z02LGI", "z07CSI", "z10RGB", "z28HAT", "z23DIP", "z09JST", "z13CAI", "z14OSD", "z16PYA", "z50LTC"]
const EYE_HEIGHT := 3.0
const PLAYER_SPEED := 10.0
const REFERENCE_RATE := 30.0
const STICK_DEADZONE := 32.0
const ORBIT_SPEED := 1.6
const CAMERA_MIN := 12.0
const CAMERA_MAX := 28.0
const CAMERA_TARGET_UP := 4.0
const CAMERA_RISE := 8.0
const RAMP_RATE := 30.0
const RAMP_PRESS := 3
const RAMP_RELEASE := 4
const RAMP_CENTRE := 16
const RAMP_MAX := 32
const PAUSE_MENU := 5
const COMPUTER_MENU := 21
const HOUSE_RECORD := 32
const RABBIT_SIGHT := {61: 3.2, 62: 2.75, 63: 2.1, 64: 3.0, 65: 2.5}
const RABBIT_SPEED := 0.01
const RABBIT_DROP := 8.0
const SWIFT_PERCH_CLIP := 1
const SEA_LEVEL := 2.4
const CASTLE_ZONE := "z07CSI"
const DIVE_ZONE := "z08BKD"
## The island's water texture, and the castle's sea level (its ground_min is 0).
const WATER_TEXTURE := 4
var sea_y := SEA_LEVEL
const SEA_MARGIN := 120.0
const WALL_LOW := 1.2
const WALL_RADIUS := 0.5
const WALL_HIGH := 2.4
## FUN_00871DB4: the feet sweep sits 1.48 up, the head sweep 4 up and climbs 1.2 along the step.
const WALK_FOOT_UP := 1.48
const WALK_HEAD_UP := 4.0
const WALK_HEAD_RISE := 1.2
const SWIM_CLIP := 9
const TREAD_CLIP := 0x41
const FIGURE_BODY_MESH := "MFG_HR"
const OWN_MESH_GROUP := 5
const PEOPLE_FIRST := 10
const PEOPLE_LAST := 50
const ACTOR_START_CLIP := 1
const SPIN_RECORDS := [161, 162]
# CONFIRMED by FUN_00490AEB at 0x004B429B: the loader pushes the literal 1 as the
# clip for every actor record 9..66, so 1 is the real start clip (the cheer).
const START_CLIP := 1
# CONFIRMED - per-record act clip, from every aligned FUN_0045c6a0 call in the
# island's act builders (record N is at DAT_00975e44 + 0x68 * N, so the offset
# identifies the record). FUN_004c632b calls FUN_004c7230 then FUN_004c9cb1, so
# for records 17..26 the FUN_004c9cb1 value is the one that survives.
# The island has no entry at record 16 because that is PEPP, the player, who is
# driven by the player controller instead of the behaviour system.
const ACTOR_CLIPS := {
	11: 98, 12: 97, 13: 104, 14: 96, 15: 95,
	17: 161, 18: 162, 19: 145, 20: 65, 21: 223,
	22: 27, 23: 15, 24: 201, 25: 43, 26: 138,
	27: 127, 28: 128, 29: 105, 30: 106, 31: 92,
	32: 107, 33: 124, 34: 164, 35: 123, 36: 122,
	37: 126, 38: 103, 39: 115, 40: 116, 41: 117,
	43: 125, 45: 168, 46: 90, 47: 121, 48: 91,
	49: 167, 50: 120,
}
# CONFIRMED - the complete island idle table, i.e. every actor record whose +0x52
# the island's act builders actually write. Extracted by following DAT_05d4a34c
# and pairing each `_memset(DAT_05d4a338,0,0x5c)` block's `+0x52` write with the
# FUN_00459290 (Human1) descriptor it is handed to - all 9 writes are for the same
# record as the descriptor, so none of them is stale scratch.
#   FUN_004c7230 gives 9: recs 27,30,33,40,43,47,50 (33 and 50 are written twice,
#   115 then 0xFFFF, so the later branch wins and they never idle).
#   FUN_004c9cb1 (recs 17-26) and FUN_004c5830 write NO +0x52 and build NO Human1
#   descriptor at all.
# NO_IDLE means FUN_0045889f never runs for that record, so the actor never leaves
# its current clip - it is NOT "go to a neutral pose".
const NO_IDLE := -1
const ACTOR_IDLE_CLIPS := {
	27: 115,
	30: 115,
	33: NO_IDLE,
	40: 114,
	43: 261,
	47: NO_IDLE,
	50: NO_IDLE,
}
# How long each stage of an actor's clip sequence lasts before advancing.
const START_CLIP_SECONDS := 2.0
const ACT_CLIP_SECONDS := 4.0
const SPECTATOR_FIRST := 37
const SPECTATOR_LAST := 55
const SPECTATOR_FACING := 0.9
const SPECTATOR_TURN := 0.3927
const SPIN_RATE := 0.0087
const SPIN_TICKS := 30.0
const TEXTURE_TICKS := 30.0

# Re-skinning an actor rebuilds its vertex buffers, which is by far the most
# expensive thing the island does per frame. People further off than this are a
# few pixels tall, so leave them standing until the player gets close.
const CHEER_RANGE := 110.0
const SWIFT_FIRST := 51
const SWIFT_LAST := 60
const BUTTERFLY_FIRST := 134
const BUTTERFLY_LAST := 153
const BUTTERFLY_SIGHT := 2.0
const BUTTERFLY_WIDE := {149: 3.0}
# ---------------------------------------------------------------------------
# The island train (records 158 TRNL / 159 TRNT / 160 TRNC) is a path follower,
# not a static prop. CONFIRMED in Ghidra:
#   * `FUN_004d7cb1` (create, behaviour vtable 0x008ba458) gives every car a
#     W_ROAD walker with `FUN_00447a0f(0, actor, 99)` (table 0 = W_ROAD, start
#     node 99), sets its goal with `FUN_004468e4(handle, 0x65 = 101, 0)`, and
#     gives the lead car the `trainsmoke01.par` emitter.
#   * `FUN_004d6d30` (update) steps the walker with `FUN_00447390`, rebuilds the
#     actor matrix from the walker's position and heading, and when the walker's
#     next node is one of `DAT_008ba470` = [0x5f,0x61,0x63,0x65,0x69] =
#     [95,97,99,101,105] it advances that table and re-targets the walker.
#   * Those five W_ROAD nodes are the corners of a loop around the island:
#     99 (-260, 42, -442), 101 (-227, 42, 158), 105 (202, 42, 158),
#     95 (308, 42, -3), 97 (73, 42, -524).
# The route between two of them is the game's own next-hop lookup
# (`FUN_00448049`, see scripts/core/waypoints.gd), so the polyline below is the
# original's route, not an approximation.
#   * Speed: `FUN_0044947a` steps the walker by `+0x44 * +0x80` = 0.1 * 1.0
#     walker units per tick, and `FUN_00449eb6` scales the walker position back
#     to world units with `_DAT_008870f4` = 8.0, so 0.8 world units per tick
#     (= 24 units/s at the original's 30 Hz). OPEN: the original's tick rate.
#   * Car spacing: the placement table puts the three cars at
#     x -259.72, z 36.217 / 19.769 / 6.000, i.e. ~15 units apart.
const TRAIN_RECORDS := [158, 159, 160]
const TRAIN_LOOP := [99, 101, 105, 95, 97]
const TRAIN_SPEED := 24.0
const TRAIN_CAR_GAP := 15.0
const TRAIN_WAYPOINT := "_data/z02LGI/waypoints/w_road_c.wpt"
## The train's own controller, `FUN_004d6d30` (read with REA). CONFIRMED:
##   * `DAT_008ba470` is the 5-node schedule [95, 97, 99, 101, 105]; arriving at a
##     scheduled node re-schedules the next one.
##   * Nodes 97 and 105 are the station stops: the speed factor ramps down
##     (0.05/frame), the train waits 150 frames at the stop (`0x43160000` = 150.0,
##     5 s at 30 Hz), then resumes and ramps back to 1.0.
##   * A rider turns the station schedule off (the `+0x28` gate) and drives
##     instead: key mask 0x84 (UP or SPACE) accelerates toward 2.0, mask 0x28
##     (DOWN or ALT) brakes toward 0.1.
##   * The rider sits (`0x43` = PEP_SITTING, clip 67) on the car, at the car's
##     origin offset to one side, and slides across it with the left/right key
##     masks 1/2, between +-1.0 at 0.1/frame, twisting +-45 degrees with the
##     slide (`DAT_008ba494` = -0.7854).
##   * Boarding is the mask-0x10 key (CTRL) while the train's interact slot
##     `FUN_004d78f2` owns the boarded car; the port mounts on the action key
##     inside the exe's own 8.0-unit probe reach, like the skateboard. That slot
##     is where the ride flag `+0x28` lives: boarding writes it, forces the speed
##     factor to 0.1 and cancels a stop; stepping off clears it, arms the
##     150-tick dwell and plays the rider's `0x1b` PEP_INTOWALK.
##   * `FUN_004d6baa(actor, out, 8.0)` - once misread as the boarding test - is
##     the *step-off* probe: the car position +-8 units fore/aft at +8 height,
##     ray down 16, with the player records 5 and 6 special-cased so the out
##     point takes the hit height.
const TRAIN_STATIONS := [97, 105]
const TRAIN_DWELL := 5.0
const TRAIN_FACTOR_STEP := 1.5         # factor per second (0.05 per 30 Hz frame)
const TRAIN_BRAKE_DIST := 40.0         # where the station approach starts
const TRAIN_FACTOR_MAX := 2.0          # full speed while a rider drives
const TRAIN_FACTOR_MIN := 0.1
const TRAIN_MOUNT_RADIUS := 8.0        # = the exe's probe reach
const TRAIN_RIDE_CLIP := 67            # PEP_SITTING
const TRAIN_OFF_CLIP := 27             # PEP_INTOWALK, the step-off animation
const TRAIN_SLIDE_LIMIT := 1.0         # DAT_008ba488
const TRAIN_SLIDE_STEP := 3.0          # 0.1 per 30 Hz frame

## Island road traffic. CONFIRMED (Ghidra `FUN_004c7230`, the island act builder):
## it registers `FUN_004d27b6` - the W_ROAD route follower - on records 166 (AMBU)
## and 167/168/169 (SPD0/1/2). `FUN_004d27b6` allocates the walker object and calls
## `FUN_00447a0f(0, actor, node)` (table 0 = W_ROAD) with the first word of its
## behaviour descriptor as the node: 166 -> 0x6b (107), 167 -> -1, 168 -> 0x36 (54),
## 169 -> 0x13 (19). The exe puts the walker on the graph at that node, so the
## actor's in-game position is the node rather than the placement row - and record
## 166's placement (-202.99, 15.26, -176.81) is node 107 to within 1.3 units, which
## is what validates the reading. Node -1 keeps the actor where the placement table
## put it. OPEN: the original's patrol target and per-car speed; the train's road
## loop and speed are reused so the cars circulate the island road.
## The descriptor's second word is 0 for all four cars, i.e. node 0 - the street
## node at (-32.5, 21.2, 352.9) in edge group 2. CONFIRMED that driving there keeps
## the cars on the streets (both legs stay at y 15.3..23.4), unlike the train's
## circuit, which is the rail loop at y 42.4.
const ROAD_VEHICLES := {166: 107, 167: -1, 168: 54, 169: 19}
const ROAD_GOAL := 0
const ROAD_SPEED := 24.0
const WheelSpin = preload("res://scripts/game/wheel_spin.gd")
const NpcWalker = preload("res://scripts/game/npc_walker.gd")
const WALKER_HOME_RADIUS := 60.0
var walkers: Array = []
var bridge: EngineBridge
var talk_view := {}
var turn_clips := {}
var csm_host: Node
## True while Pepper rides a machine through the behaviour engine (set by EngineBridge).
var ride_on := false
## The record whose own collision shape the ground queries ignore (the machine being ridden).
var ground_skip := -1
## The skateboard (record 9) and its clips (SKBD.blk). While the board is ridden the engine hands
## over the tilt of Pepper's matrix in `ride_basis`.
const BOARD_RECORD := 9
const SKATE_SELECTOR := 4
var board_blk: BlkFile
var board_skin: SkinnedMesh
var board_node: MeshInstance3D
var board_clip := 0
var board_time := 0.0
var ride_basis := Basis()
var ride_tilted := false
## The step-off clip of the board (0x1C) plays on after the engine lets go; -1 when it does not.
var dismount_t := -1.0
## The record the last wall hit belonged to (-2: the land itself).
var wall_record := -1
var brick_morph: Node3D
const ROAD_PROBE := 4.5
## Cut-out vehicle wheels per record, turned while the vehicle moves.
var wheel_sets := {}


## The act hide rules now live in scripts/core/story.gd, next to the 72-row
## state table they are keyed on.
const STORY_GETO_RECORD := 68
const STORY_START_NODE := 0xF6
const STORY_LATE_START_NODE := 0xBF
const WAYPOINT_HEADER_BYTES := 20
const WAYPOINT_NODE_BYTES := 32
const RABBIT_PROBE_HEIGHT := 40.0
const RABBIT_WAYPOINTS := [Vector3(27.4, 0.0, -340.0), Vector3(20.2, 0.0, -336.4), Vector3(25.6, 0.0, -334.5)]
const SHELF_POINT := Vector3(-15.0, 7.0, -6.0)
const SHELF_OFFSET := 2.8
const TROPHY_FIRST_RECORD := 8
const TROPHY_COUNT := 23
const TROPHY_VARS := [
	[143, 37, 40, 22],
	[185, 23, 0, 21],
	[73, 18, 2, 19],
	[144, 206, 7, 20],
	[61, 47, 8, 2],
	[203, 24, 9, 3],
	[209, 170, 38, 16],
	[72, 20, 18, 7],
	[136, 56, 21, 18],
	[141, 192, 2, 0],
	[64, 32, 5, 1],
	[213, 200, 17, 6],
	[157, 74, 28, 11],
	[134, 155, 36, 12],
	[63, 218, 41, 14],
	[207, 150, 0, 15],
	[35, 59, 10, 4],
	[67, 44, 39, 17],
	[147, 75, 15, 5],
	[220, 30, 20, 8],
	[214, 39, 22, 9],
	[26, 135, 27, 10],
	[68, 41, 39, 13],
]
const TROPHY_SOUNDS := [
	"z03PPH/BoardPark", "z03PPH/Whakabot", "z03PPH/BrickDive", "z03PPH/Joust", "z03PPH/RagingBull",
	"z03PPH/SnakeShoot", "z03PPH/Wakasnake", "z03PPH/Matching", "z03PPH/desertsp", "z03PPH/biplane",
	"z03PPH/Trex", "z03PPH/MrHATES", "z03PPH/Centrifuge", "z03PPH/Asteroids", "z03PPH/MakadPizza",
	"z03PPH/Palace", "z38PAR/thru_ring", "z40APO/rockmonster", "z21FSH/Fishy Flap", "z02LGI/Piza_Hit",
	"z07CSI/horse showoff", "z90ADV/Scorpian_move", "z40OGL/space_chimp1",
]
const TROPHY_LOCKED_SOUND := "z03PPH/Error"
const TROPHY_EASE := 0.2
const TROPHY_TICKS := 30.0
const TROPHY_EYE_UP := 1.44
const TROPHY_EYE_BACK := 2.24
const TROPHY_LOOK_UP := 0.64
const FOOTSTEP_SETS := {0: "GRASS", 1: "ROAD", 3: "SAND", 4: "ROCK", 6: "GRAVEL", 7: "PLASTIC", 8: "ROAD", 9: "PLASTIC", 10: "PLASTIC"}
const FOOTSTEP_FILES := {"GRASS": "GRASS_%d", "ROAD": "ROAD_%d", "SAND": "SAND_%d", "ROCK": "ROCK_%d", "GRAVEL": "GRAVEL_%d", "PLASTIC": "PLAS_%d", "BRIDGE": "BRIDGE_%d"}
const HOUSE_PROMPTS := {"computer": 2, "exit": 0, "trophies": 1}
const HIDDEN_NAME_PARTS := ["collision", "_temp", "wormhole", "wake_", "ripple", "splash", "radio_pulse"]
const JUMP_SPEED := 15.0
const GRAVITY := -10.0
const JUMP_TIME_STEP := 0.1
const JUMP_MAX_TIME := 3.0
const JUMP_CLIP := 1

## The skateboard is driven by the engine's records (IslandMode and Skate on the island and in the
## castle, ParkProgram in the park); the island only draws it and plays Pepper's clips.
## Clip numbers are the island loader's clip indices: `FUN_00490aeb` loads each clip name in order
## and the index is the name's position in that sequence minus 15 (PEP_SWIM 9, PEP_JUMPINAIR 1,
## PEP_THROWPIZZA 11, PEP_TWOPIZZASPLAT 12, PEP_WALK 13, PEP_RUN 36, PEP_IDLE 58, PEP_TREADWATER 65).
## Riding camera: how fast the view catches up with the engine's eye, and the distance after which it jumps.
const RIDE_GLIDE := 20.0
const RIDE_SNAP := 40.0
const BOARD_CODE := "SKBD"
const BOARD_MOUNT_RADIUS := 3.0
const BOARD_REMOUNT_RADIUS := 8.0
const BOARD_ON_CLIP := 22
const BOARD_OFF_CLIP := 28
const BOARD_CYCLE_CLIP := 41
const BOARD_STEER_CLIP := 81
## How long a mount/dismount pose is held if the clip's own length cannot be read.
const BOARD_POSE_FRAMES := 30.0
const HOUSE_EXIT_Z := 15.0
const HOUSE_FACING := 0.78
const HOUSE_SPOTS := [
	[-6.52, -6.54, 8.0, "computer"],
	[-15.0, 6.0, 8.0, "shelf"],
	[-6.0, 10.0, 8.0, "exit"],
	[10.77, 3.8, 80.0, "trophies"],
]
const STEP_UP := 6.0
const WALK_STEP_UP := 0.8
const WALK_FALL_PROBE := 4.0
const WALK_SLOPE := 1.8

var camera: Camera3D
var yaw := 0.0
# When true, nothing moves the camera. Screenshot tests set this and place it
# themselves; without it the follow logic re-aims the camera every frame and the
# rendered "view" is wherever the player happens to be, not the requested one.
var camera_locked := false
# While a cut scene plays the story does not advance (the exe's objective poll waits
# for the scene: FUN_004410dc only starts one when var 0xB is clear and the level
# loop reloads afterwards), so the host raises this for its duration.
var story_hold := false
var player: MeshInstance3D
var player_pos := Vector3.ZERO
var player_yaw := 0.0
var ramp := 16
var ramp_clock := 0.0
var land_col: ColFile
var col_paths := {}
var col_cache := {}
var colliders: Array = []
var collider_slots: Array = []
const FIRST_SOLID_SLOT := 5
var sky: MeshInstance3D
var ready_to_walk := false
var pause_layer: CanvasLayer
var runs := {}
var mesh_names := {}
var mesh_cache := {}
var start := Vector3.ZERO
var pepper_blk: BlkFile
var pepper_parts: Array = []
var pepper_clip := 58
## Var 0x5E bit 0x20 is Pepper hurt (scorpion bite and the like, FUN_00603A46): clip 0x70 plays
## once with the controls held, then the bit is cleared. -1 when not hurt.
var hurt_t := -1.0
const HURT_CLIP := 0x70
const HURT_BIT := 0x20
var pepper_skin: SkinnedMesh
var pepper_body: MeshInstance3D
var pepper_foot := 0.0
var pepper_time := 0.0
var park_board: MeshInstance3D
var board_home := Vector3.ZERO
var board_home_basis := Basis()
var board_on := false
var board_t := 0.0
var board_off := -1.0
var board_lock := false
var board_key_held := false
var board_centre := Vector3.ZERO
var board_half := 0.2
var board_flat := Basis(Vector3(0, 0, 1), -PI * 0.5)
var board_measured := false
var placed := 0
var throw_t := -1.0
var throw_target := -1
# FUN_008742d5 returns 1 for the normal throw (target at least 4.8 units away)
# and 2 for the close-range Two-Pizza Splat (target inside that radius).
var throw_melee := false
# FUN_00871db4's throw switch: true when the throw was raised out of a running
# movement state (the exe's 0x24/0x3f/0x40), which selects PEP_THROWPIZZARUN.
var throw_running := false
var pizza_spawned := false
var pizza_held: MeshInstance3D
var pizzas: Array = []
var pizza_slot := 0
var pizza_player: AudioStreamPlayer
# Why records were dropped, counted by reason. A record silently skipped by
# `continue` is indistinguishable from one that was never placed, which made a
# missing object (shop01 / record 118) impossible to attribute to a cause.
var skip_reasons := {}
# Set to a record number to have the placement loop print what it decided for it.
var trace_record := -1
## Story state machine (scripts/core/story.gd). `_story_travelling` latches once
## a chapter change has asked for the zone reload, so the poll cannot fire twice
## while the scene swap is pending.
var _story_travelling := false
var f6_held := false
var f7_held := false
var music: DmPlayer
var ambience: Array = []
var ambience_songs: Array = []
var ambience_gulls := false
var shelf_view := false
var swimming := false
var rabbits: Array = []
var butterflies: Array = []
var swift_flock: SwiftFlock
var spinners: Array = []
var spectators: Array = []
var cheerers: Array = []
var rabbit_waypoints: Array = []
# The island train. `train_cars` is record -> MeshInstance3D; the route polyline
# is built on the first frame from the game's own W_ROAD waypoint graph.
var train_cars := {}
var train_path: Array = []
var train_length := 0.0
var train_dist := 0.0
var train_built := false
var train_tried := false
var train_factor := 1.0
var train_dwell := 0.0
# The step-off animation clock (FUN_004d78f2 plays PEP_INTOWALK 0x1b), -1 when
# the player is not in the step-off pose.
var train_off := -1.0
var train_armed := true
var train_resuming := false
var train_stations: Array = []
var train_points: Array = []
var train_forwards: Array = []
var train_on := false
var train_car := 0
var train_lateral := 0.0
var train_roof := 1.0
var train_measured := false
var road_cars := {}
var road_home := {}
var road_paths := {}
var road_lengths := {}
var road_dist := {}
var road_tried := false
var trophy_view := false
var trophy_index := 0
var trophy_text: Label
var trophy_heard := -1
var trophy_player: AudioStreamPlayer
var trophy_key_held := false
var trophy_point := Vector3.ZERO
var ground_surface := 0
var foot_stage := 0
var foot_cycle := 0
var foot_player: AudioStreamPlayer
var foot_streams := {}
var hud: Hud
var npc_pose: Array = []
var rig_cache := {}
var jump_t := -1.0
var jump_y0 := 0.0
var jump_velocity := Vector3.ZERO
var jump_held := false
var action_held := false
var travel_held := false
var music_current := ""
var music_bank := ""
var music_clock := 0.0
var music_sites := {}
var zone := ISLAND_ZONE
var prefix := "island"
var first_record := 5
var pepper_parts_table: Array = []


func _ready() -> void:
	if Game.pending_zone == 3:
		zone = HOUSE_ZONE
		prefix = "pph"
		first_record = 0
	elif Game.pending_zone == 1:
		zone = PARK_ZONE
		prefix = "bpk"
		first_record = 0
	if Game.pending_zone_code != "":
		zone = Game.pending_zone_code
		prefix = zone.substr(3).to_lower()
		first_record = 0
		Game.pending_zone_code = ""
	pepper_parts_table = PEPPER_PARTS if zone == ISLAND_ZONE else (HOUSE_PARTS if zone == HOUSE_ZONE else [])
	_load_lights()
	var land := MeshBuilder.build(zone, "land", 0, true, _run(_land_run()), true)
	if land != null:
		add_child(land)
		land_col = ColFile.parse(Data.read("_data/%s/col/land.col" % zone))
	# A zone that places its own SEAB / SEAE records (the castle: at -13.9 and -58.0, their
	# meshes are authored offset to match) must not get a second copy at the origin.
	var places_sea := _places_own_sea()
	var seabed := MeshBuilder.build(zone, "SeaBed", 0, true, _run(0)) if not places_sea else null
	if seabed != null:
		seabed.name = "SeaBed"
		add_child(seabed)
		seabed_mesh = seabed
	var sea := MeshBuilder.build(zone, "Sea", 0, true, _run(2)) if not places_sea else null
	if sea != null:
		sea.name = "Sea"
		add_child(sea)
		sea_mesh = sea
		sea_materials.clear()
		_collect_sea(sea)
	if zone == ISLAND_ZONE or zone == CASTLE_ZONE:
		_build_water_plane()
	sky = MeshBuilder.build(zone, "sky", 0, true, _run(_sky_run())) if SKY_ZONES.has(zone) else null
	if sky != null:
		sky.scale = Vector3.ONE * 900.0
		add_child(sky)
	_load_runs()
	_place_objects()
	if places_sea:
		# The zone's builder puts the sea animation on record 2 (SEAE) itself.
		for child in get_children():
			if child is MeshInstance3D and String(child.name) == "Sea_2":
				_collect_sea(child)
	_load_cols()
	if zone == ISLAND_ZONE:
		_snap_people()
	if zone == ISLAND_ZONE or ZonePrograms.for_zone(zone) != null:
		bridge = EngineBridge.new()
		bridge.setup(self)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.near = 0.5
	camera.far = 3000.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(camera)
	camera.position = MeshBuilder.flip(start) + Vector3(0, 60.0, 0)
	camera.current = true
	await get_tree().process_frame
	ready_to_walk = true
	if zone == ISLAND_ZONE:
		csm_host = CsmHostScript.new()
		add_child(csm_host)
		csm_host.house_stage()
		brick_morph = BrickMorphScript.new()
		add_child(brick_morph)
		brick_morph.setup(self)
	if zone == ISLAND_ZONE or zone == HOUSE_ZONE or zone == CASTLE_ZONE or zone == DIVE_ZONE:
		var hud_layer := CanvasLayer.new()
		hud_layer.layer = 5
		hud = Hud.new()
		if zone == HOUSE_ZONE:
			hud.corners = false
			hud.overlay_folder = "_data/Overlays/z03pph/text%03d.tga"
		else:
			hud.kind = {ISLAND_ZONE: "island", CASTLE_ZONE: "castle", DIVE_ZONE: "dive"}[zone]
			hud.overlay_folder = "_data/Overlays/%s/text%%03d.tga" % zone
		hud_layer.add_child(hud)
		add_child(hud_layer)
	if DisplayServer.get_name() != "headless" and zone != ISLAND_ZONE:
		var path := _zone_music_path()
		if path != "":
			music = DmPlayer.new()
			add_child(music)
			music.play(path, music_bank)
	if zone == ISLAND_ZONE and DisplayServer.get_name() != "headless":
		music = DmPlayer.new()
		add_child(music)
		music_current = MUSIC_DEFAULT
		music.play(MUSIC_DIRECTORY + MUSIC_DEFAULT)
		_start_ambience()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.65, 0.95)
	if zone == ISLAND_ZONE:
		# CONFIRMED (island init FUN_0044DA05 calls FUN_00429D30(4, 100, 800, 500,
		# 0x00FFFF, 1) -> FUN_00407F30/00407E00): linear D3D fog in cyan. End =
		# (800 - 100) * (100 - draw setting) * 0.01 + 100 with the default setting
		# 50 (settings slot 0x15, default 0x32) = 450; start = end - 500 * end / 800.
		# The deep seabed fades into this colour, which is the water.
		env.environment.fog_enabled = true
		env.environment.fog_mode = Environment.FOG_MODE_DEPTH
		env.environment.fog_light_color = Color(0.0, 1.0, 1.0)
		env.environment.fog_density = 1.0
		world_env = env
		env.environment.fog_depth_curve = 1.0
		env.environment.fog_sky_affect = 0.0
		if sky != null:
			_sky_without_fog()
		_apply_fog()
		Game.options_changed.connect(_apply_fog)
	elif ZONE_FOG.has(zone):
		var row: Array = ZONE_FOG[zone]
		var tint := Color.from_rgba8((int(row[3]) >> 16) & 0xFF, (int(row[3]) >> 8) & 0xFF, int(row[3]) & 0xFF)
		env.environment.background_color = tint
		env.environment.fog_enabled = bool(row[4])
		env.environment.fog_mode = Environment.FOG_MODE_DEPTH
		env.environment.fog_light_color = tint
		env.environment.fog_density = 1.0
		env.environment.fog_depth_curve = 1.0
		world_env = env
		fog_row = row
		_apply_fog()
		Game.options_changed.connect(_apply_fog)
	add_child(env)


## The zone functions' FUN_00429D30(near, a, b, c, colour) calls (FUN_00407F30 / FUN_00407E00):
## linear fog from end - c * end / b to end = (b - a) * (100 - draw setting) * 0.01 + a, in
## the colour, which also clears the screen; the last argument is D3DRS_FOGENABLE (FUN_00407CC0), so
## a zone that passes 0 has no fog, only the clear colour. Rows: [a, b, c, colour, fog on].
const ZONE_FOG := {
	"z03PPH": [100.0, 800.0, 500.0, 0x00FFFF, true],
	"z07CSI": [100.0, 800.0, 500.0, 0xFF9966, true],
	"z08BKD": [200.0, 200.0, 120.0, 0x000000, true],
	"z01BPK": [100.0, 200.0, 20.0, 0x000000, true],
	"z14OSD": [100.0, 800.0, 500.0, 0x00FFFF, true],
	"z16PYA": [400.0, 400.0, 100.0, 0x00FFFF, true],
	"z36CNT": [52.5, 52.5, 10.0, 0x000000, false],
}
var fog_row: Array = [100.0, 800.0, 500.0, 0x00FFFF]


## The materials the sea animation (FUN_00457172 / FUN_00456FF4) scrolls.
func _collect_sea(holder: MeshInstance3D) -> void:
	for i in holder.mesh.get_surface_count():
		var sea_material := holder.mesh.surface_get_material(i)
		if sea_material is StandardMaterial3D:
			sea_material.texture_repeat = true
			sea_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sea_materials.append(sea_material)
		elif sea_material is ShaderMaterial:
			sea_materials.append(sea_material)


## True when the zone's own placement has a sea record at a height other than 0.
func _places_own_sea() -> bool:
	for row in _rows("res://data/%s_placement.tsv" % prefix):
		if (String(row[1]) == "SEAB" or String(row[1]) == "SEAE") and absf(float(row[6])) > 0.001:
			return true
	return false


## Fog distance from the Graphics screen (settings slot 0x15, default 50):
## end = (800 - 100) * (100 - S) * 0.01 + 100, start = end - 500 * end / 800
## (FUN_00407E00).
func _apply_fog() -> void:
	if world_env == null:
		return
	fog_end = (float(fog_row[1]) - float(fog_row[0])) * float(100 - Game.option("fog")) * 0.01 + float(fog_row[0])
	world_env.environment.fog_depth_end = fog_end
	world_env.environment.fog_depth_begin = fog_end - float(fog_row[2]) * fog_end / float(fog_row[1])


func _sky_without_fog() -> void:
	_fog_free(sky)


## Draw a mesh without fog (the sky and a zone's backdrop sit beyond the fog's end).
func _fog_free(holder: MeshInstance3D) -> void:
	var seen := {}
	for i in holder.mesh.get_surface_count():
		var material := holder.mesh.surface_get_material(i)
		if material == null or seen.has(material):
			continue
		seen[material] = true
		if material is StandardMaterial3D:
			material.disable_fog = true
		elif material is ShaderMaterial and not material.shader.code.contains("fog_disabled"):
			var shader := Shader.new()
			shader.code = material.shader.code.replace("render_mode ", "render_mode fog_disabled, ")
			material.shader = shader


const SEA_PHASE_RISE := 0.05235959589481354
const SEA_PHASE_FALL := 0.0174533
const SEA_DRIFT := 0.003
const TICK_RATE := 30.0

var sea_materials: Array = []
# Named and kept so the two water layers can be told apart - see tests/shot_water.gd.
var sea_mesh: MeshInstance3D
var seabed_mesh: MeshInstance3D
var sea_phase := 0.0
var sea_scroll := 0.0
var sea_clock := 0.0


## The water body: record 1 (SSEA) is `pPlane1`, a 1 x 1 plane of 10 x 10 tiles of
## texture 4 (teal, alpha 0.5). CONFIRMED FUN_0086e0e3 (its update): scaled to
## 2.5 x the fog end (1125), centred under the camera in steps of a tenth of that
## so the tiles never slide, y = sea level - 2.0, and wobbled by
## ((cos b + sin a) * 4, (sin b + cos a) * 4) with a += 1 degree and
## b += 0.011694 rad per tick.
const WATER_SCALE := 2.5
const WATER_STEP := 0.1
const WATER_DROP := 2.0
const WATER_WOBBLE := 4.0
const WATER_RATE_A := 0.01745319925248623
const WATER_RATE_B := 0.011693643406033516
var fog_end := 450.0
var world_env: WorldEnvironment
var water_mesh: MeshInstance3D
var water_anchor := Vector2.ZERO
var water_a := 0.0
var water_b := 0.0
var water_clock := 0.0


## CONFIRMED FUN_0087d84e (the talk node every speaking actor gets): the actor is
## dropped onto the ground with a ray from 4.0 above its placement (FUN_00428a60),
## falling back to the terrain height when the ray hits nothing. Without it the
## placement heights leave people hanging in the air.
func _snap_people() -> void:
	for child in get_children():
		if not (child is MeshInstance3D):
			continue
		var tail := String(child.name).get_slice("_", String(child.name).get_slice_count("_") - 1)
		if not tail.is_valid_int():
			continue
		var record := int(tail)
		if record < PEOPLE_FIRST or record > PEOPLE_LAST or not String(child.name).begins_with("MFG"):
			continue
		var ground := _ground(Vector3(child.position.x, child.position.y + 4.0, child.position.z), STEP_UP, true)
		if ground > -INF:
			child.position.y = ground


## People who walk a patrol in the first act (state < 7). Node lists and gates are
## extracted from FUN_004c7230 (data/island_walkers.tsv). A list whose first node is
## far from where the person is placed belongs to a later phase of the story and is
## left out, so nobody sets off across the island on a guess.
## Standing clips from the Turn2Pep step every talking actor gets (FUN_0045CA69 ->
## FUN_004CA5C9: +0x14 notice, +0x16 idle, +0x18 turn-in). Most people wave when they
## notice Pepper (xwave 0x74) and otherwise stand in xidle (0x78); the football
## players dance, the postman has his own set. The old "act clip" table was the
## variable id (tag) each builder passes beside the record, not a clip.
func _apply_turn_clips() -> void:
	turn_clips.clear()
	for row in _rows("res://data/island_turn.tsv"):
		turn_clips["%d:%d" % [int(row[0]), int(row[1])]] = [int(row[2]), int(row[3]), int(row[4])]
	var act := _walker_act(Game.get_var(Game.VAR_STATE))
	for item in cheerers:
		var n: MeshInstance3D = item.node
		var tail := String(n.name).get_slice("_", String(n.name).get_slice_count("_") - 1)
		if not tail.is_valid_int():
			continue
		var turn: Array = turn_clips.get("%d:%d" % [int(tail), act], [])
		if turn.is_empty():
			continue
		item["turn"] = turn
		item["yaw"] = atan2(-n.basis.z.x, n.basis.z.z)
		item.stage = 3
		_set_clip(item, int(turn[1]))


func _build_walkers() -> void:
	var graph := Waypoints.new()
	if not graph.parse(Data.read("_data/%s/waypoints/w_path_c.wpt" % zone)):
		return
	var placement := {}
	for row in _rows("res://data/%s_placement.tsv" % prefix):
		placement[int(row[0])] = Vector3(float(row[5]), float(row[6]), float(row[7]))
	var by_record := {}
	var act := _walker_act(Game.get_var(Game.VAR_STATE))
	for row in _rows("res://data/island_walkers.tsv"):
		if int(row[8]) != act:
			continue
		var nodes: Array = []
		for token in String(row[4]).split(" ", false):
			nodes.append(int(token))
		if nodes.is_empty() or not placement.has(int(row[0])):
			continue
		var first: Vector3 = graph.nodes[nodes[0]]
		var home: Vector3 = placement[int(row[0])]
		if Vector2(first.x - home.x, first.z - home.z).length() > WALKER_HOME_RADIUS:
			continue
		var list: Dictionary = by_record.get(int(row[0]), {"tag": int(row[1]), "behaviours": []})
		(list.behaviours as Array).append({"mask": int(row[2]), "value": int(row[3]), "nodes": nodes,
			"clip": int(row[5]), "speed": float(row[6])})
		by_record[int(row[0])] = list
	for record in by_record:
		for item in cheerers:
			var n: MeshInstance3D = item.node
			if not String(n.name).ends_with("_%d" % record):
				continue
			var walker := NpcWalker.new()
			walker.node = n
			walker.item = item
			walker.record = record
			walker.yaw = float(item.get("yaw", 0.0))
			walker.tag = int(by_record[record].tag)
			walker.behaviours = by_record[record].behaviours
			walker.graph = graph
			walker.others = walkers
			walkers.append(walker)


## Act of a story state (FUN_0044DA05: < 7, < 0x1E, < 0x34, < 0x3D, else). The last
## act is built by the same wrapper as the first (FUN_0045B339 -> FUN_004C632B), so it
## uses the first act's walk lists.
static func _walker_act(state: int) -> int:
	if state < 7 or state >= 0x3D:
		return 0
	if state < 0x1E:
		return 1
	return 2 if state < 0x34 else 3


## Collectible pages PAG1..PAG4 (records 69..72), FUN_004CF428: while story state is below
## 10 a page that Pepper touches (squared distance <= 4.0 after taking 2.5 off the height
## difference) adds 1 to var 0xA5 and disappears. State 7 ends when 0xA5 reaches 4.
const PAGE_RECORDS := [69, 70, 71, 72]
const PAGE_VAR := 0xA5
const PAGE_REACH_SQUARED := 4.0
const PAGE_HEIGHT_SLACK := 2.5
const PAGE_SPIN := 0.1
var pages_taken := {}


## Brickster bots (records 17..26): the act-1 builder FUN_004C44E8 gives each one a
## BrickBot controller and a defeat check; a bot that has been hit is switched off, its
## own var gets bit 0x4000 (the "defeated" mark the builders test at load), and the
## coloured four (BBR0 23, BBG0 24, BBB0 25, BBY0 26) OR 0x8E with 2 / 4 / 8 / 1 by the
## 3rd letter of their code (FUN_004CCBE7). Hit also: var 0x52 = 1, 0xA6 and 0x12 += 1000.
## The bot's real hit counter and movement (FUN_004CC527) are not ported: one pizza
## defeats it.
const BOT_TAGS := {17: 0xa1, 18: 0xa2, 19: 0x91, 20: 0x41, 21: 0xdf, 22: 0x1b, 23: 0xf, 24: 0xc9, 25: 0x2b, 26: 0x8a}
const BOT_COLOUR_BITS := {23: 2, 24: 4, 25: 8, 26: 1}


func _bot_hit(node: Node) -> void:
	var tail := String(node.name).get_slice("_", String(node.name).get_slice_count("_") - 1)
	if not tail.is_valid_int() or not BOT_TAGS.has(int(tail)) or not node.visible:
		return
	var record := int(tail)
	var state := Game.get_var(Game.VAR_STATE)
	if state < 7 or state >= 0x34:
		return
	node.visible = false
	Game.set_var(BOT_TAGS[record], Game.get_var(BOT_TAGS[record]) | 0x4000)
	if BOT_COLOUR_BITS.has(record):
		Game.set_var(0x8E, Game.get_var(0x8E) | int(BOT_COLOUR_BITS[record]))
	Game.set_var(0x52, 1)
	Game.set_var(0xA6, Game.get_var(0xA6) + 1000)
	Game.set_var(0x12, Game.get_var(0x12) + 1000)
	print("[bot] defeated record %d, 0x8E=%d" % [record, Game.get_var(0x8E)])


## Island portals, records 161 (PORS aerial portal) and 162: FUN_004B90CC descriptor
## half sizes 21 x 21 x 21, zone id in the descriptor (162 -> zone 6, the castle
## archive z07CSI, active from story state 10, FUN_004C4F19). Staying inside the box
## writes var 5 = zone id and the game loads that zone.
const PORTAL_RECORD := 162
const PORTAL_HALF := 21.0
const PORTAL_ZONE := 6
const PORTAL_FIRST_STATE := 10
var portal_at := Vector3.INF


func _update_portals() -> void:
	if zone != ISLAND_ZONE or story_hold or _story_travelling or not ready_to_walk or player == null:
		return
	if Game.get_var(Game.VAR_STATE) < PORTAL_FIRST_STATE:
		return
	if portal_at == Vector3.INF:
		for row in _rows("res://data/%s_placement.tsv" % prefix):
			if int(row[0]) == PORTAL_RECORD:
				portal_at = MeshBuilder.flip(Vector3(float(row[5]), float(row[6]), float(row[7])))
		if portal_at == Vector3.INF:
			portal_at = Vector3(INF, 0, 0)
			return
	if portal_at.x == INF:
		return
	var gap: Vector3 = (player_pos - portal_at).abs()
	if gap.x <= PORTAL_HALF and gap.y <= PORTAL_HALF and gap.z <= PORTAL_HALF:
		_story_travelling = true
		Game.set_var(5, PORTAL_ZONE)
		var code: String = Story.ZONE_ARCHIVE.get(PORTAL_ZONE, "")
		print("[portal] record %d -> zone %d (%s)" % [PORTAL_RECORD, PORTAL_ZONE, code])
		var load := Story.load_zone(code)
		Game.pending_zone = int(load[0])
		Game.pending_zone_code = String(load[1])
		get_tree().change_scene_to_file("res://scenes/loading.tscn")


func _update_pages(delta: float) -> void:
	if zone != ISLAND_ZONE or story_hold or Game.get_var(Game.VAR_STATE) >= 10 or player == null:
		return
	for child in get_children():
		if not (child is MeshInstance3D) or not child.visible:
			continue
		var tail := String(child.name).get_slice("_", String(child.name).get_slice_count("_") - 1)
		if not tail.is_valid_int() or not PAGE_RECORDS.has(int(tail)) or pages_taken.has(int(tail)):
			continue
		var gap: Vector3 = player_pos - child.position
		var dy := absf(gap.y)
		dy = 0.0 if dy <= PAGE_HEIGHT_SLACK else dy - PAGE_HEIGHT_SLACK
		child.rotate_y(PAGE_SPIN * delta * TICK_RATE)
		if gap.x * gap.x + gap.z * gap.z + dy * dy <= PAGE_REACH_SQUARED:
			pages_taken[int(tail)] = true
			child.visible = false
			Game.set_var(PAGE_VAR, Game.get_var(PAGE_VAR) + 1)
			print("[page] taken %s, pages %d" % [child.name, Game.get_var(PAGE_VAR)])


func _update_walkers(delta: float) -> void:
	if story_hold:
		return
	var walking := {}
	for walker in walkers:
		walker.step(delta, Game, self)
		walking[walker.node] = true
		var item: Dictionary = walker.item
		var clip: int = walker.walk_clip()
		var turn: Array = item.get("turn", [])
		if walker.moving and clip != NpcWalker.NO_CLIP:
			item.stage = 3
			if int(item.clip) != clip:
				_set_clip(item, clip)
		elif not turn.is_empty():
			var want := int(turn[0]) if walker.hold > 0.0 else int(turn[1])
			if int(item.clip) != want:
				_set_clip(item, want)
	# People who stand still: wave when Pepper comes up in front, otherwise idle.
	for item in cheerers:
		var turn: Array = item.get("turn", [])
		if turn.is_empty() or walking.has(item.node):
			continue
		var n: MeshInstance3D = item.node
		var gap := Vector2(player_pos.x - n.position.x, -(player_pos.z - n.position.z))
		var near := gap.length() < NpcWalker.NOTICE_RANGE and absf(wrapf(atan2(gap.x, gap.y) - float(item.yaw), -PI, PI)) < NpcWalker.NOTICE_ANGLE
		if near:
			item.yaw = NpcWalker._turn(float(item.yaw), atan2(gap.x, gap.y), NpcWalker.TURN_STEP * delta * NpcWalker.TICK)
			n.basis = _placement_basis(0.0, float(item.yaw), 0.0)
		var want := int(turn[0]) if near else int(turn[1])
		if int(item.clip) != want:
			_set_clip(item, want)


func _build_water_plane() -> void:
	var plane := MeshBuilder.build(zone, "pPlane1", 0, true, _run(1))
	if plane == null:
		return
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.texture_repeat = true
	material.albedo_texture = MeshBuilder.texture(zone, int(_run(1)[0]) if not _run(1).is_empty() else WATER_TEXTURE)
	material.render_priority = -1
	for i in plane.mesh.get_surface_count():
		plane.mesh.surface_set_material(i, material)
	if zone == CASTLE_ZONE:
		sea_y = 0.0
	plane.name = "WaterPlane"
	plane.scale = Vector3(fog_end * WATER_SCALE, 1.0, fog_end * WATER_SCALE)
	add_child(plane)
	water_mesh = plane


func _water_step(delta: float) -> void:
	if water_mesh == null or camera == null:
		return
	water_clock += delta * TICK_RATE
	while water_clock >= 1.0:
		water_clock -= 1.0
		water_a += WATER_RATE_A
		water_b += WATER_RATE_B
	water_mesh.scale = Vector3(fog_end * WATER_SCALE, 1.0, fog_end * WATER_SCALE)
	var step := fog_end * WATER_SCALE * WATER_STEP
	var cam := Vector2(camera.global_position.x, -camera.global_position.z)
	var guard := 0
	while guard < 200 and (absf(cam.x - water_anchor.x) > step or absf(cam.y - water_anchor.y) > step):
		guard += 1
		if absf(cam.x - water_anchor.x) > step:
			water_anchor.x += step * signf(cam.x - water_anchor.x)
		if absf(cam.y - water_anchor.y) > step:
			water_anchor.y += step * signf(cam.y - water_anchor.y)
	var wobble := Vector2(cos(water_b) + sin(water_a), sin(water_b) + cos(water_a)) * WATER_WOBBLE
	water_mesh.position = Vector3(water_anchor.x + wobble.x, sea_y - WATER_DROP, -(water_anchor.y + wobble.y))


func _sea_step(delta: float) -> void:
	if sea_materials.is_empty():
		return
	sea_clock += delta * TICK_RATE
	while sea_clock >= 1.0:
		sea_clock -= 1.0
		var drift := sin(sea_phase) * SEA_DRIFT
		sea_phase += SEA_PHASE_RISE if drift >= 0.0 else SEA_PHASE_FALL
		sea_scroll += drift
	for material in sea_materials:
		if material is ShaderMaterial:
			material.set_shader_parameter("uv_offset", Vector2(0.0, sea_scroll))
		else:
			material.uv1_offset = Vector3(0.0, sea_scroll, 0.0)


func _process(delta: float) -> void:
	_sea_step(delta)
	_water_step(delta)
	if not ready_to_walk or pause_layer != null:
		return
	if shelf_view and not camera_locked:
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel") or absf(_forward_axis()) > 0.0:
			shelf_view = false
		else:
			camera.position = SHELF_POINT + Vector3(SHELF_OFFSET, 0.0, 0.0)
			camera.look_at(SHELF_POINT, Vector3.UP)
	if trophy_view and not camera_locked:
		_trophy_step(delta)
	if not talk_view.is_empty() and not camera_locked:
		camera.position = talk_view.eye
		camera.look_at(talk_view.look, Vector3.UP)
	elif camera_locked or shelf_view or trophy_view:
		pass
	elif player == null:
		_free_camera(delta)
	elif bridge != null and bridge.program != null and bridge.program.drives_player:
		_drive_program()
	else:
		_drive_player(delta)
	if zone == ISLAND_ZONE:
		_update_pizza(delta)
	for rabbit in rabbits:
		rabbit.update(delta, _rabbit_ground)
	for fly in butterflies:
		fly.update(delta)
	if swift_flock != null:
		swift_flock.update(delta)
	MeshBuilder.step_animated(int(Time.get_ticks_msec() * 0.001 * TEXTURE_TICKS))
	_turn_spectators(delta)
	if bridge != null:
		bridge.update(delta)
	if zone == ISLAND_ZONE:
		_ambience_tick()
	_update_pages(delta)
	_update_portals()
	_cheer(delta)
	_update_train(delta)
	_update_road(delta)
	_update_board(delta)
	for spin in spinners:
		spin.rx = wrapf(spin.rx + SPIN_RATE * SPIN_TICKS * delta, -PI, PI)
		(spin.node as MeshInstance3D).basis = _placement_basis(spin.rx, spin.ry, spin.rz)
	if sky != null:
		sky.position = camera.position
	_update_music(delta)
	var travel := Input.is_physical_key_pressed(KEY_F3)
	if travel and not travel_held:
		var at := TRAVEL_ORDER.find(zone)
		var next_code: String = TRAVEL_ORDER[(at + 1) % TRAVEL_ORDER.size()]
		Game.pending_zone = -1
		Game.pending_zone_code = next_code
		if next_code == ISLAND_ZONE:
			Game.pending_zone = ISLAND_ZONE_ID
			Game.pending_zone_code = ""
		elif next_code == HOUSE_ZONE:
			Game.pending_zone = 3
			Game.pending_zone_code = ""
		elif next_code == PARK_ZONE:
			Game.pending_zone = 1
			Game.pending_zone_code = ""
		get_tree().change_scene_to_file("res://scenes/loading.tscn")
	travel_held = travel
	# Chapter keys: F7 = the exe's own next-chapter debug (FUN_0041f7e5 case 1
	# -> FUN_00404ba7(var 0x58 + 1)), F6 = one back (FUN_00404a96).
	var f7 := Input.is_physical_key_pressed(KEY_F7)
	var f6 := Input.is_physical_key_pressed(KEY_F6)
	if f7 and not f7_held:
		_story_step(1)
	elif f6 and not f6_held:
		_story_step(-1)
	f7_held = f7
	f6_held = f6
	_story_poll()
	if Input.is_action_just_pressed("ui_cancel"):
		_open_pause()
	elif zone == HOUSE_ZONE:
		_house_triggers()


## A zone whose program moves Pepper through its own behaviours: the player node follows his record
## and the camera is the program's.
func _drive_program() -> void:
	var record: Record = bridge.records[bridge.player_record]
	player_pos = Vector3(record.x, record.y, -record.z)
	player.position = player_pos
	player.basis = _placement_basis(record.field_f(0x4C), record.yaw, record.field_f(0x54))
	var pose: Dictionary = bridge.program.camera_pose()
	if not pose.is_empty():
		camera.position = Vector3(pose.eye.x, pose.eye.y, -pose.eye.z)
		camera.look_at(Vector3(pose.target.x, pose.target.y, -pose.target.z), Vector3.UP)


func _free_camera(delta: float) -> void:
	yaw += _turn_axis() * ORBIT_SPEED * delta
	var forward := _forward_axis()
	camera.position += Vector3(-sin(yaw), 0, -cos(yaw)) * forward * PLAYER_SPEED * 4.0 * delta
	camera.rotation = Vector3(0, yaw, 0)


func _drive_player(delta: float) -> void:
	if player_pos == Vector3.ZERO:
		player_pos = player.position
		camera.position = _clear_spot(player_pos)
	var to_player := player_pos - camera.position
	to_player.y = 0.0
	var look := to_player.normalized() if to_player.length() > 0.001 else Vector3(0, 0, 1)
	var orbit := _turn_axis() * ORBIT_SPEED * delta
	var offset := camera.position - player_pos
	if orbit != 0.0:
		var flat := Vector3(offset.x, 0, offset.z).rotated(Vector3.UP, orbit)
		offset = Vector3(flat.x, offset.y, flat.z)
	var forward := _ramped(_forward_axis(), delta)
	# CONFIRMED (exe table at 0x0089e1b0 + manual): the default keyboard binds
	# Left ALT to action mask 0x20 (jump) and SPACE to action mask 0x80 (throw
	# pizza). FUN_0086f12f raises the jump from mask 0x20; FUN_00871db4 fires the
	# pizza from mask 0x80. They are separate buttons, so the throw can never
	# steal the jump.
	#
	# DELIBERATE DEVIATION from the exe defaults (user request): Left ALT is
	# unusable in the browser build - the browser and the window manager swallow
	# the bare key - so the player could not jump at all. Jump is therefore on
	# SPACE, where every player reaches for it (the exe's ALT still works too), and
	# the pizza throw moved to F, which is action mask 0x4000 in the exe's own
	# table at 0x0089e1b0 - a real action button, just not the pizza one.
	var action := Input.is_physical_key_pressed(KEY_F)
	var jump := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_ALT)
	if action and not action_held and throw_t < 0.0 and not ride_on:
		if train_on:
			_train_step_off()
		elif zone == ISLAND_ZONE and _train_near() >= 0:
			_train_mount(_train_near())
		elif zone == ISLAND_ZONE:
			_start_throw(absf(forward) >= RUN_THRESHOLD)
	if ride_on:
		# Riding a machine (FUN_0087FB26) or the board: the engine drives it, Pepper and the camera;
		# the action key (CTRL) gets off, through the island controller.
		action_held = action
		jump_held = jump
		player.position = player_pos + Vector3(0, pepper_foot, 0)
		player.basis = ride_basis if ride_tilted else Basis(Vector3.UP, player_yaw + PI)
		_pose_pepper()
		var ride_eye: Vector3 = bridge.services.camera_eye
		var ride_target: Vector3 = bridge.services.camera_target
		# The engine moves the eye at 30 Hz; glide to it between ticks.
		var wanted := Vector3(ride_eye.x, ride_eye.y, -ride_eye.z)
		camera.position = wanted if camera.position.distance_to(wanted) > RIDE_SNAP else camera.position.lerp(wanted, 1.0 - exp(-delta * RIDE_GLIDE))
		camera.look_at(Vector3(ride_target.x, ride_target.y + CAMERA_TARGET_UP, -ride_target.z), Vector3.UP)
		return
	if train_on:
		# Riding the train (FUN_004d6d30): sit on the car, slide across it with
		# the turn keys, camera behind. The body is seated on this frame's car
		# transform by `_update_train`, after the train advances. Jump and the
		# pizza throw do not fire while seated; the action key steps off above.
		action_held = action
		jump_held = jump
		train_lateral = move_toward(train_lateral, _turn_axis() * TRAIN_SLIDE_LIMIT, TRAIN_SLIDE_STEP * delta)
		player.position = player_pos + Vector3(0, pepper_foot, 0)
		player.basis = Basis(Vector3.UP, player_yaw + PI)
		_animate_train(delta)
		var seat_target := player_pos + Vector3(0, CAMERA_TARGET_UP, 0)
		var seat_flat := Vector3(offset.x, 0, offset.z)
		var seat_len := clampf(seat_flat.length(), CAMERA_MIN, CAMERA_MAX)
		seat_flat = seat_flat.normalized() * seat_len if seat_flat.length() > 0.001 else -look * CAMERA_MIN
		camera.position = seat_target + seat_flat + Vector3(0, CAMERA_RISE - CAMERA_TARGET_UP, 0)
		camera.look_at(seat_target, Vector3.UP)
		return
	if jump and not jump_held and jump_t < 0.0 and hurt_t < 0.0:
		if zone != HOUSE_ZONE:
			jump_t = 0.0
			jump_y0 = player_pos.y
			jump_velocity = look * signf(forward) * minf(absf(forward), 1.0) * REFERENCE_RATE if absf(forward) > 0.01 else Vector3.ZERO
	action_held = action
	jump_held = jump
	if jump_t >= 0.0:
		jump_t += JUMP_TIME_STEP * REFERENCE_RATE * delta
		var next_air := player_pos + _slide(player_pos, jump_velocity * delta)
		var air_y := jump_y0 + (JUMP_SPEED + GRAVITY * jump_t) * jump_t + 0.5 * GRAVITY * jump_t * jump_t
		var floor_y := _surface(Vector3(next_air.x, air_y + STEP_UP, next_air.z))
		if jump_t > JUMP_SPEED / absf(GRAVITY) * 0.5 and floor_y > -INF and air_y <= floor_y:
			player_pos = Vector3(next_air.x, floor_y, next_air.z)
			jump_t = -1.0
		elif jump_t > JUMP_MAX_TIME:
			jump_t = -1.0
			if floor_y > -INF:
				player_pos = Vector3(next_air.x, floor_y, next_air.z)
		else:
			player_pos = Vector3(next_air.x, air_y, next_air.z)
		if jump_velocity.length() > 0.01:
			player_yaw = atan2(jump_velocity.x, jump_velocity.z)
	elif absf(forward) > 0.01 and throw_t < 0.0 and hurt_t < 0.0:
		var move := look * signf(forward) * minf(absf(forward), 1.0) * REFERENCE_RATE * delta
		move = _slide(player_pos, move)
		var next := player_pos + move
		# The exe's step-up is 0.8 (1.6 on your own object), _DAT_0088708C in
		# FUN_0086f12f's probe code; the rise a slope adds over one step is allowed on top.
		var climb := maxf(WALK_STEP_UP, move.length() * WALK_SLOPE)
		var ground := _surface(Vector3(next.x, player_pos.y, next.z), climb)
		if ground > -INF and ground < player_pos.y - WALK_STEP_UP:
			# A slope too steep for the step-up has no face inside the probe window, so the
			# probe would drop to a surface far below; the higher face ahead blocks instead.
			var top := _ground(Vector3(next.x, player_pos.y, next.z), WALK_FALL_PROBE, true)
			if top > ground and top <= player_pos.y + WALK_FALL_PROBE:
				ground = -INF
		if ground > -INF:
			next.y = ground
			player_pos = next
			player_yaw = atan2(move.x, move.z)
	player.position = player_pos + Vector3(0, pepper_foot, 0)
	_animate_pepper(1.0 if jump_t >= 0.0 else absf(forward), delta, jump_t >= 0.0)
	player.basis = Basis(Vector3.UP, player_yaw + PI)
	var target := player_pos + Vector3(0, CAMERA_TARGET_UP, 0)
	var flat_offset := Vector3(offset.x, 0, offset.z)
	var distance := clampf(flat_offset.length(), CAMERA_MIN, CAMERA_MAX)
	flat_offset = flat_offset.normalized() * distance if flat_offset.length() > 0.001 else -look * CAMERA_MIN
	camera.position = target + flat_offset + Vector3(0, CAMERA_RISE - CAMERA_TARGET_UP, 0)
	camera.look_at(target, Vector3.UP)


func _clear_spot(centre: Vector3) -> Vector3:
	if zone == HOUSE_ZONE:
		return centre + Vector3(0, CAMERA_RISE, CAMERA_MIN)
	var first_angle := PI
	for step in 8:
		var angle := first_angle + step * PI / 4.0
		var spot := centre + Vector3(sin(angle) * CAMERA_MIN, CAMERA_RISE, cos(angle) * CAMERA_MIN)
		var inside := false
		for child in get_children():
			if child is MeshInstance3D and child != sky and child.get_index() > 2:
				var box: AABB = child.global_transform * child.get_aabb()
				if box.grow(1.0).has_point(spot):
					inside = true
					break
		if not inside:
			return spot
	return centre + Vector3(0, CAMERA_RISE, -CAMERA_MIN)


func _house_triggers() -> void:
	var site: Vector3 = music_sites.get(HOUSE_RECORD, Vector3.ZERO)
	var here := Vector2(player_pos.x, -player_pos.z)
	if here.y > HOUSE_EXIT_Z:
		_leave_house()
		return
	var active := _house_spot(here, site)
	if hud != null:
		hud.set_prompt(HOUSE_PROMPTS.get(active, -1))
	if not Input.is_action_just_pressed("ui_accept"):
		return
	if active == "computer":
		_open_pause(COMPUTER_MENU)
	elif active == "exit":
		_leave_house()
	elif active == "shelf":
		shelf_view = true
	elif active == "trophies":
		trophy_view = true
		trophy_index = 0
		trophy_heard = -1
		trophy_point = _trophy_target()
		_trophy_label(true)


func _trophy_label(show: bool) -> void:
	if not show:
		if trophy_text != null:
			trophy_text.queue_free()
			trophy_text = null
		return
	trophy_text = Label.new()
	trophy_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	trophy_text.position = Vector2(540.0, 640.0)
	trophy_text.add_theme_font_size_override("font_size", 28)
	hud.add_child(trophy_text)


func _trophy_sound() -> void:
	var entry: Array = TROPHY_VARS[trophy_index]
	var name: String = TROPHY_SOUNDS[entry[3]] if Game.get_var(entry[0]) != 0 else TROPHY_LOCKED_SOUND
	var path := "_data/sounds/%s.wav" % name
	if not foot_streams.has(path):
		foot_streams[path] = Wav.parse(Data.read(path))
	var stream: AudioStream = foot_streams[path]
	if stream == null or DisplayServer.get_name() == "headless":
		return
	if trophy_player == null:
		trophy_player = AudioStreamPlayer.new()
		trophy_player.bus = "Sound"
		add_child(trophy_player)
	trophy_player.stream = stream
	trophy_player.play()


func _trophy_target() -> Vector3:
	return music_sites.get(TROPHY_FIRST_RECORD + trophy_index, Vector3.ZERO)


func _trophy_step(delta: float) -> void:
	if Input.is_action_just_pressed("ui_left") or Input.is_key_pressed(KEY_A) and not trophy_key_held:
		trophy_index = (trophy_index + TROPHY_COUNT - 1) % TROPHY_COUNT
		trophy_heard = -1
	elif Input.is_action_just_pressed("ui_right") or Input.is_key_pressed(KEY_D) and not trophy_key_held:
		trophy_index = (trophy_index + 1) % TROPHY_COUNT
		trophy_heard = -1
	elif Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_down"):
		trophy_view = false
		_trophy_label(false)
		return
	trophy_key_held = Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_D)
	if trophy_text != null:
		trophy_text.text = "HiScore: %d" % Game.get_var(TROPHY_VARS[trophy_index][1])
	var target := _trophy_target()
	var gap := target - trophy_point
	if trophy_heard != trophy_index and gap.length() < 0.1:
		trophy_heard = trophy_index
		_trophy_sound()
	var follow := 1.0 - pow(1.0 - TROPHY_EASE, delta * TROPHY_TICKS)
	trophy_point = target if gap.length() < 0.1 else trophy_point + gap * follow
	var shown := MeshBuilder.flip(trophy_point)
	camera.position = shown + Vector3(0.0, TROPHY_EYE_UP, TROPHY_EYE_BACK)
	camera.look_at(shown + Vector3(0.0, TROPHY_LOOK_UP, 0.0), Vector3.UP)


func _house_spot(here: Vector2, site: Vector3) -> String:
	for spot in HOUSE_SPOTS:
		var centre := Vector2(site.x + spot[0], site.z + spot[1])
		if absf(here.x - centre.x) > spot[2] or absf(here.y - centre.y) > spot[2]:
			continue
		if spot[3] == "exit" and absf(wrapf(player_yaw - PI, -PI, PI)) > HOUSE_FACING:
			continue
		return String(spot[3])
	return ""


func _leave_house() -> void:
	if get_tree() == null:
		return
	Game.pending_zone = ISLAND_ZONE_ID
	get_tree().change_scene_to_file("res://scenes/loading.tscn")


func _zone_music_path() -> String:
	var wanted := zone.to_upper()
	for parts in _rows("res://data/music.tsv"):
		var name := String(parts[0]).to_upper()
		if not name.begins_with(wanted):
			continue
		var segment := String(parts[1]).replace("\\", "/")
		var tail := segment.get_file()
		if tail.to_lower().begins_with(zone.to_lower()) and tail.length() > 6:
			music_bank = String(parts[2]) if parts.size() > 2 else ""
			return "_data/sounds/DirectMusic/%s/%s" % [zone, tail.substr(6)]
		return ""
	return ""


func _start_ambience() -> void:
	# CONFIRMED present in the game data and previously played by nothing:
	# sounds/z02LGI/MidiAmbient/ holds Birds.mid, Birds'n'Bees.MID and Seagulls.mid
	# with their own 1.1 MB "DLS Birds.dls". Birds and gulls are the island's
	# background sound; without them the town is silent apart from the score.
	# FUN_00452ADD / FUN_00453987 play one of them at a time: the birds from the start, the gulls
	# once Pepper is lower than 8 above the sea, the birds again above 16 (see `_ambience_tick`).
	for entry in AMBIENCE:
		var amb := DmPlayer.new()
		add_child(amb)
		# Ambience sits well under the music so it never competes with it.
		amb.master_db = AMBIENCE_DB
		var song := SmfSong.load_ambient(SmfSong.AMBIENT_DIR + String(entry[0]))
		if song == null:
			amb.queue_free()
			continue
		ambience.append(amb)
		ambience_songs.append(song)
	ambience_gulls = false
	if ambience.size() == AMBIENCE.size():
		ambience[0].play_song(ambience_songs[0], true)


## FUN_00453987 as the island controller calls it every tick: the gulls when Pepper is lower than 8
## above the sea level, the birds when he is higher than 16, whatever plays between.
func _ambience_tick() -> void:
	if ambience.size() != AMBIENCE.size():
		return
	var height := player_pos.y
	var wants_gulls := false
	if height >= SEA_LEVEL + 8.0:
		if height > 16.0:
			wants_gulls = false
		else:
			return
	else:
		wants_gulls = true
	if wants_gulls == ambience_gulls:
		return
	ambience[1 if not wants_gulls else 0].stop()
	ambience_gulls = wants_gulls
	var next := 1 if wants_gulls else 0
	ambience[next].play_song(ambience_songs[next], true)


func _update_music(delta: float) -> void:
	if music == null or player == null:
		return
	music_clock += delta
	if music_clock < 0.25:
		return
	music_clock = 0.0
	var wanted := MUSIC_DEFAULT
	for site in MUSIC_SITES:
		if not music_sites.has(site[0]):
			continue
		var offset: Vector3 = music_sites[site[0]] - Vector3(player_pos.x, player_pos.y, -player_pos.z)
		if offset.length_squared() <= MUSIC_RADIUS_SQUARED:
			wanted = site[1]
			break
	if wanted != music_current:
		music_current = wanted
		music.play(MUSIC_DIRECTORY + wanted)
	music.set_groove_offset(_music_groove(wanted == MUSIC_DEFAULT))


const INPUT_LEFT := 0x01
const INPUT_UP := 0x04
const INPUT_DOWN := 0x08
const INPUT_ACTION := 0x10
const INPUT_ALT := 0x20
const INPUT_TALK := 0x40
const INPUT_SPACE := 0x80
const GROOVE_RUN_CLIPS := [0x24, 0x3F, 0x40]


func _input_bits() -> int:
	var bits := 0
	if _turn_axis() > 0.0:
		bits |= INPUT_LEFT
	if _turn_axis() < 0.0:
		bits |= 0x02
	if _forward_axis() > 0.0:
		bits |= INPUT_UP
	if _forward_axis() < 0.0:
		bits |= INPUT_DOWN
	if Input.is_physical_key_pressed(KEY_CTRL):
		bits |= INPUT_ACTION
	if Input.is_physical_key_pressed(KEY_ALT):
		bits |= INPUT_ALT
	if Input.is_physical_key_pressed(KEY_SHIFT):
		bits |= INPUT_TALK
	if Input.is_physical_key_pressed(KEY_SPACE):
		bits |= INPUT_SPACE
	return bits


func _music_groove(main_theme: bool) -> int:
	if not main_theme:
		return 0
	match _input_bits() & 0xFFF:
		INPUT_LEFT:
			return -1 if GROOVE_RUN_CLIPS.has(pepper_clip) else -2
		INPUT_UP, INPUT_DOWN, INPUT_TALK:
			return 0
	return -2


func _open_pause(start_menu := PAUSE_MENU) -> void:
	var menu: Control = load("res://scenes/front_menu.tscn").instantiate()
	menu.with_backdrop = false
	menu.transparent = true
	menu.start_menu = start_menu
	menu.movie_requested.connect(_play_movie)
	menu.resume_requested.connect(_close_pause)
	menu.leave_requested.connect(func():
		get_tree().change_scene_to_file("res://scenes/front_menu.tscn"))
	menu.zone_requested.connect(func(target: int):
		Game.pending_zone = ISLAND_ZONE_ID if zone == HOUSE_ZONE else target
		get_tree().change_scene_to_file("res://scenes/loading.tscn"))
	menu.load_requested.connect(func(_slot: int):
		Game.pending_zone = Game.get_var(Game.VAR_NEXT_ZONE)
		get_tree().change_scene_to_file("res://scenes/loading.tscn"))
	pause_layer = CanvasLayer.new()
	pause_layer.add_child(menu)
	add_child(pause_layer)


func _play_movie(name: String) -> void:
	if pause_layer != null:
		return
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 4
	add_child.call_deferred(pause_layer)
	var path: String = await Data.fetch_movie(name)
	if path == "":
		push_warning("movie unavailable: " + name)
		if pause_layer != null:
			pause_layer.queue_free()
			pause_layer = null
		return
	var movie: Control = load("res://scenes/movie.tscn").instantiate()
	movie.finished.connect(movie.queue_free)
	pause_layer.add_child(movie)
	movie.play(path, true)


func _close_pause() -> void:
	pause_layer.queue_free()
	pause_layer = null


## The texture run of the land: the one with a texture for each group of Land.msh (the island's is run 4,
## the castle's run 3).
func _land_run() -> int:
	var file := MeshFile.parse(Data.read("_data/%s/meshes/land.msh" % zone))
	if file == null:
		return 4
	var wanted := file.groups.size()
	if _run(4).size() == wanted:
		return 4
	for index in 8:
		if _run(index).size() == wanted:
			return index
	return 4


## The sky is loaded just before the land: the island's run 3 before its run 4, the castle's run 2 before 3.
func _sky_run() -> int:
	return _land_run() - 1


func _run(index: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var file := FileAccess.open("res://data/%s_texsets.tsv" % prefix, FileAccess.READ)
	if file == null:
		return out
	file.get_line()
	while not file.eof_reached():
		var parts := file.get_line().split("	")
		if parts.size() >= 3 and int(parts[0]) == index:
			for id in parts[2].split(" "):
				out.append(int(id))
			break
	return out


func _rows(path: String) -> Array:
	var out := []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	file.get_line()
	while not file.eof_reached():
		var line := file.get_line()
		if line != "":
			out.append(line.split("	"))
	return out


func _load_lights() -> void:
	MeshBuilder.load_lighting(zone)


func _load_runs() -> void:
	for parts in _rows("res://data/%s_texsets.tsv" % prefix):
		var ids := PackedInt32Array()
		for id in String(parts[2]).split(" "):
			ids.append(int(id))
		runs[int(parts[0])] = ids
	for parts in _rows("res://data/%s_meshes.tsv" % prefix):
		var path := String(parts[2]).replace("\\", "/")
		mesh_names[int(parts[0])] = path.get_file().get_basename()
	for parts in _rows("res://data/%s_cols.tsv" % prefix):
		var col_path := String(parts[2]).replace("\\", "/")
		if col_path.begins_with("_data"):
			col_paths[int(parts[0])] = col_path


## How many leading meshes of a list are the same mesh at different detail (HR, MR, LR, SLR, BGR).
func _lod_group_length(slots: PackedStringArray) -> int:
	var first := String(mesh_names.get(int(slots[0]), ""))
	var stem := first.replace("_HR", "_@").replace("HR", "@")
	var count := 1
	for i in range(1, slots.size()):
		var name := String(mesh_names.get(int(slots[i]), ""))
		var same := false
		for lod in ["HR", "MR", "LR", "SLR", "BGR"]:
			if name == stem.replace("_@", "_" + lod).replace("@", lod):
				same = true
		if not same:
			break
		count += 1
	return count


func _place_objects() -> void:
	var models := {}
	var part_models := {}
	var attaches := {}
	for row in _rows("res://data/%s_attach.tsv" % prefix):
		var list: Array = attaches.get(int(row[0]), [])
		list.append([int(row[1]), int(row[2])])
		attaches[int(row[0])] = list
	for row in _rows("res://data/%s_models.tsv" % prefix):
		var a_mesh := String(row[2]).split(" ", false) if row.size() > 2 else PackedStringArray()
		var a_tex := String(row[3]).split(" ", false) if row.size() > 3 else PackedStringArray()
		if not a_mesh.is_empty() and not a_tex.is_empty():
			part_models[int(String(row[0]).get_slice(":", 0))] = [int(a_mesh[0]), int(a_tex[0])]
	var record_slots := {}
	for parts in _rows("res://data/%s_models.tsv" % prefix):
		var record := int(String(parts[0]).get_slice(":", 0))
		var every: Array = []
		# The record's own meshes come first: its collision file is the one named like its model
		# (the pizzeria's is `pizzeria_LOD5.col` on slot 79), not one of the parts it carries.
		for column in [4, 2]:
			if parts.size() > column:
				for token in String(parts[column]).split(" ", false):
					every.append(int(token))
		record_slots[record] = every
		var b_mesh := String(parts[4]).split(" ", false) if parts.size() > 4 else PackedStringArray()
		var b_tex := String(parts[5]).split(" ", false) if parts.size() > 5 else PackedStringArray()
		if b_mesh.is_empty() or b_tex.is_empty():
			b_mesh = String(parts[2]).split(" ", false) if parts.size() > 2 else PackedStringArray()
			b_tex = String(parts[3]).split(" ", false) if parts.size() > 3 else PackedStringArray()
		if b_mesh.is_empty() or b_tex.is_empty():
			continue
		var pick := 0
		if zone == HOUSE_ZONE and record >= TROPHY_FIRST_RECORD and record < TROPHY_FIRST_RECORD + TROPHY_COUNT:
			var medal := Game.get_var(TROPHY_VARS[record - TROPHY_FIRST_RECORD][0])
			if medal < 1 or medal > 3 or b_mesh.size() < 3:
				continue
			pick = 3 - medal
		elif zone != ISLAND_ZONE:
			var code_name := String(parts[1])
			pick = -1
			if zone == PARK_ZONE and code_name == BOARD_CODE:
				# bpk_models.tsv row 36 lists two meshes for SKBD: slot 318
				# `OBJT_Spanner` and slot 468 `SkBoard`. The record's code is the
				# board and the board is what the player rides, so take that mesh
				# instead of falling through to the first non-PEPP mesh (which is
				# the spanner).
				for i in b_mesh.size():
					if String(mesh_names.get(int(b_mesh[i]), "")).contains("Board"):
						pick = i
						break
			for i in b_mesh.size():
				if String(mesh_names.get(int(b_mesh[i]), "")).begins_with(FIGURE_BODY_MESH) and code_name != "PEPP":
					pick = i
					break
			var own_start := OWN_MESH_GROUP
			if zone == CASTLE_ZONE:
				# The castle's mesh lists run part group (what a parent attaches), then the
				# record's own group; the part group is the LOD set of the first mesh.
				own_start = _lod_group_length(b_mesh)
			if pick < 0 and b_mesh.size() >= own_start + (1 if zone == CASTLE_ZONE else 2):
				var own_name := String(mesh_names.get(int(b_mesh[own_start]), ""))
				if code_name == "PEPP" or not own_name.begins_with("PEPP_"):
					pick = own_start
			for i in b_mesh.size():
				if pick >= 0:
					break
				var mesh_name := String(mesh_names.get(int(b_mesh[i]), ""))
				if mesh_name.begins_with("PEPP_") and code_name != "PEPP":
					continue
				if mesh_name.ends_with("_Gold"):
					break
				pick = i
				break
			if pick < 0 or pick >= b_tex.size():
				continue
		models[record] = [int(b_mesh[pick]), int(b_tex[pick])]
	for parts in _rows("res://data/%s_placement.tsv" % prefix):
		var record := int(parts[0])
		var code := String(parts[1])
		var position := Vector3(float(parts[5]), float(parts[6]), float(parts[7]))
		music_sites[record] = position
		if code == "PEPP" and zone == ISLAND_ZONE:
			var spot := _story_start(Game.get_var(Game.VAR_STATE))
			if spot != Vector3.INF:
				position = spot
		if code == "PEPP":
			start = position
		if record == trace_record:
			print("[trace] loop row record=%d models_has=%s first_record=%d rows=%d"
				% [record, str(models.has(record)), first_record, models.size()])
		if not models.has(record) or record < first_record:
			_skip("no_model", record)
			continue
		var slot: int = models[record][0]
		if record == trace_record:
			print("[trace] past models, slot=%d model=%s hidden_at_start=%s story_hidden=%s state=%d"
				% [slot, str(models[record]),
					str(zone == ISLAND_ZONE and _hidden_at_start(String(mesh_names.get(slot, "")), position) != ""),
					str(zone == ISLAND_ZONE and _story_hidden(record, Game.get_var(Game.VAR_STATE))),
					Game.get_var(Game.VAR_STATE)])
		var hide := _hidden_at_start(String(mesh_names.get(slot, "")), position) if zone == ISLAND_ZONE else ""
		if hide != "":
			# A collision record (the pizzeria's walls are `collision_pizzeria`) is not drawn but is solid.
			if hide == "name:collision" and col_paths.has(slot) and slot >= FIRST_SOLID_SLOT:
				collider_slots.append([slot, position, float(parts[3]), record])
			_skip("hidden:" + hide + ":" + String(mesh_names.get(slot, "")), record)
			continue
		var board_hidden := zone == ISLAND_ZONE and record == BOARD_RECORD
		if zone == ISLAND_ZONE and not board_hidden and _story_hidden(record, Game.get_var(Game.VAR_STATE)):
			_skip("story_hidden", record)
			continue
		var solid := slot >= FIRST_SOLID_SLOT and not (slot >= 303 and slot <= 317)
		if zone != ISLAND_ZONE:
			solid = col_paths.has(slot) and code != "PEPP"
		if solid and col_paths.has(slot):
			collider_slots.append([slot, position, float(parts[3]), record])
		elif code != "PEPP" and zone == ISLAND_ZONE:
			for candidate in record_slots.get(record, []):
				if col_paths.has(candidate) and candidate >= FIRST_SOLID_SLOT:
					collider_slots.append([candidate, position, float(parts[3]), record])
					break
		var run: int = models[record][1]
		var key := "%d:%d" % [slot, run]
		if not mesh_cache.has(key):
			# A zone's backdrop is a painted picture, not a lit object (its inside faces would go black).
			var backdrop := String(mesh_names.get(slot, "")).to_lower() == "backdrop"
			var built := MeshBuilder.build(zone, String(mesh_names.get(slot, "")), 0, true, runs.get(run, PackedInt32Array()), not backdrop)
			mesh_cache[key] = built.mesh if built != null else null
		var mesh: Mesh = mesh_cache[key]
		if record == trace_record:
			print("[trace] built key=%s mesh=%s run_known=%s"
				% [key, "null" if mesh == null else "ok", str(runs.has(run))])
		if mesh == null:
			_skip("null_mesh:" + String(mesh_names.get(slot, "")), record)
			continue
		if code != "PEPP":
			mesh = _static_skin(key, String(mesh_names.get(slot, "")), mesh)
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.name = "%s_%d" % [mesh_names.get(slot, "obj"), record]
		if record == trace_record:
			print("[trace] instance named %s mesh=%s"
				% [instance.name, "null" if instance.mesh == null else "ok"])
		instance.position = MeshBuilder.flip(position)
		if code == "PEPP":
			instance.basis = _placement_basis(0.0, float(parts[3]), 0.0)
		else:
			instance.basis = _placement_basis(float(parts[2]), float(parts[3]), float(parts[4]))
		add_child(instance)
		if String(mesh_names.get(slot, "")).to_lower() == "backdrop":
			_fog_free(instance)
		if board_hidden:
			# The skateboard exists from the start and the engine shows it when Pepper gets on.
			instance.visible = false
			_board_skin_setup(instance, String(mesh_names.get(slot, "")))
		if zone == ISLAND_ZONE and code == "HOLO":
			# The hologram of the Info Maniac only appears while he talks through
			# Pepper's headset; the cut scene scripts show it, never the free walk.
			instance.visible = false
		placed += 1
		if zone == PARK_ZONE and record >= SPECTATOR_FIRST and record <= SPECTATOR_LAST:
			spectators.append({"node": instance, "home": position, "yaw": float(parts[3]), "rx": float(parts[2]), "rz": float(parts[4])})
			_cheer_setup(record, instance, key, String(mesh_names.get(slot, "")))
		if zone == PARK_ZONE and code == BOARD_CODE:
			# The rideable board. See the BOARD_* constants for the mount rule.
			park_board = instance
			board_home = instance.position
			board_home_basis = instance.basis
		if zone == ISLAND_ZONE and record >= PEOPLE_FIRST and record <= PEOPLE_LAST and code != "PEPP":
			_cheer_setup(record, instance, key, String(mesh_names.get(slot, "")), ACTOR_START_CLIP)
		if zone != ISLAND_ZONE and zone != PARK_ZONE and zone != HOUSE_ZONE and code != "PEPP" and attaches.has(record):
			# A skinned actor of a zone (the records that carry parts): the rig is the smallest of the
			# zone's animation files with a bone for every part's bone.
			zone_rig = _rig_by_bones(attaches[record])
			if not zone_rig.is_empty():
				_cheer_setup(record, instance, key, String(mesh_names.get(slot, "")), 0)
			zone_rig = {}
		if zone == CASTLE_ZONE and String(mesh_names.get(slot, "")).to_lower().begins_with("hors_hors"):
			# The horse: its own animation file (HORS.blk); the horse behaviour picks the clips.
			_cheer_setup(record, instance, key, String(mesh_names.get(slot, "")))
		if zone == ISLAND_ZONE and SPIN_RECORDS.has(record):
			spinners.append({"node": instance, "rx": float(parts[2]), "ry": float(parts[3]), "rz": float(parts[4])})
		if zone == ISLAND_ZONE and record >= SWIFT_FIRST and record <= SWIFT_LAST:
			_add_swift(instance, key, String(mesh_names.get(slot, "")), position)
		if zone == ISLAND_ZONE and record >= BUTTERFLY_FIRST and record <= BUTTERFLY_LAST:
			var fly := Butterfly.new()
			fly.node = instance
			fly.setup(BUTTERFLY_WIDE.get(record, BUTTERFLY_SIGHT), position, float(parts[3]))
			butterflies.append(fly)
		if zone == ISLAND_ZONE and RABBIT_SIGHT.has(record):
			_add_rabbit(record, instance, key, String(mesh_names.get(slot, "")), position, float(parts[3]))
		if zone == ISLAND_ZONE and TRAIN_RECORDS.has(record):
			train_cars[record] = instance
			wheel_sets[record] = WheelSpin.split(instance)
			if record == TRAIN_RECORDS[0]:
				# CONFIRMED FUN_004d7cb1: the lead car carries the trainsmoke01
				# emitter via FUN_004335f0(.., 0, 10.0, 7.25, -pi/2, ..), which is
				# the funnel top of the locomotive mesh (0, 9.94, 7.31).
				var smoke := SmokeEmitter.new()
				smoke.world = self
				smoke.sheet_path = "_data/%s/particle/Text000.tga" % zone
				smoke.position = Vector3(0.0, 10.0, -7.25)
				instance.add_child(smoke)
		if zone == ISLAND_ZONE and ROAD_VEHICLES.has(record):
			road_cars[record] = instance
			wheel_sets[record] = WheelSpin.split(instance)
			road_home[record] = MeshBuilder.flip(position)
		if code == "PEPP":
			player = instance
			# Only the island's and the castle's tables line Pepper's parts up with their attach
			# list (the castle's children 0..4 are model rows 0..4: helmet, head, hat, hands). In the house the same lookup lands on the room's scenery, so
			# the hand-written part list is used there instead.
			if zone != HOUSE_ZONE and attaches.has(record):
				var generated: Array = []
				for entry in attaches[record]:
					if part_models.has(entry[0]):
						generated.append([String(mesh_names.get(part_models[entry[0]][0], "")), part_models[entry[0]][1], entry[1]])
				if not generated.is_empty() and zone != HOUSE_ZONE:
					pepper_parts_table = generated
			_attach_pepper(instance)
		elif attaches.has(record):
			var attached := _attach_parts(instance, attaches[record], part_models, record)
			if not cheerers.is_empty() and cheerers.back().node == instance:
				cheerers.back().parts = attached


const CREEP_THRESHOLD := 0.01
const WALK_THRESHOLD := 0.05
const RUN_THRESHOLD := 0.4
const PEPPER_IDLE_CLIP := 58
const HOUSE_PARTS := [
	["PEPP_HRhead", 83, 10],
	["PEPP_HRhat", 91, 10],
	["PEPP_HRrhand", 95, 14],
	["PEPP_HRlhand", 87, 16],
]
const PEPPER_PARTS := [
	["PEPP_HRbag", 1014, 8],
	["PEPP_HRhead", 1018, 10],
	["PEPP_HRhat", 1022, 10],
	["PEPP_HRrhand", 1026, 14],
	["PEPP_HRlhand", 1030, 16],
]
# Throwing a pizza. FUN_00873d10 is the player's pizza action; FUN_00871db4's
# action branch plays a clip and spawns the pizza from the hand.
#
# The clip names are registered by index in FUN_00490aeb (0x004B5180..):
#   PUSH 0xb / "PEP_THROWPIZZA"      -> clip 11 = the normal throw
#   PUSH 0xc / "PEP_TWOPIZZASPLAT"   -> clip 12 = the close-range splat
#   PUSH 0x42 / "PEP_THROWPIZZARUN"  -> clip 66 = the throw while running
#
# FUN_008742d5 / FUN_0087402e pick the target: the nearest hittable actor inside
# the 45-degree cone (0x3f490f94). FUN_008742d5 then compares its squared
# distance with _DAT_00887300 = 23.04 (4.8 units):
#   >= 23.04  -> 1: a throw. FUN_00871db4 then switches on the *movement* state:
#                     SNEAK/WALK/INTOWALK (8, 0xd, 0x1b) -> state 0xb (clip 11),
#                     FUN_00873e90(14.0, 42.0) shows the pizza on frame 14 and
#                     releases it on frame 42;
#                     RUN/RUNLEFT/RUNRIGHT (0x24, 0x3f, 0x40) -> state 0x42
#                     (clip 66), FUN_00873e90(0x40800000, 0x41200000) = show
#                     frame 4.0, release frame 10.0 - the running throw is over
#                     in a third of a second, and when it finishes the exe drops
#                     back to state 0x24 (RUN).
#   <  23.04  -> 2: state 0xc (clip 12, the Two-Pizza Splat), FUN_008750ca(10,
#                     0x28) shows it on frame 10 and splats it on frame 40
# The manual says the same: "SPACE bar - Throw Pizza (Use near a Brickster-Bot
# to perform a Two-Pizza Splat!)".
const THROW_CLIP := 11
const THROW_SHOW_FRAME := 14.0
const THROW_LAUNCH_FRAME := 42.0
const THROW_RUN_CLIP := 66
const THROW_RUN_SHOW_FRAME := 4.0
const THROW_RUN_LAUNCH_FRAME := 10.0
const SPLAT_CLIP := 12
const SPLAT_SHOW_FRAME := 10.0
const SPLAT_FRAME := 40.0
const THROW_CONE := 0.70710678
const THROW_RANGE_SQUARED := 23.04
const THROW_ARC := 2.66664
const THROW_SPEED := 4.0
# FUN_008744c2: while the pizza flies its age += DAT_008a0850 * 4.0 every tick
# and it is retired the moment the age passes 144.0 - 36 ticks, 1.2 s at the
# exe's fixed 30 Hz - silently, in mid-air (the case-4 cleanup; only a real
# impact reaches the splat). DAT_008a0850 was read at 0x008a0850 = 0x3f800000
# (1.0), so this is per tick, not per dt. The port's flight is slower than the
# exe's step of 4 * offset per tick, so the wall-clock figure is the half of
# the behaviour that carries over unwarped.
const PIZZA_LIFETIME := 1.2
const PIZZA_GRAVITY := -6.0
const PIZZA_MESHES := ["Pizza", "Pizza1", "Pizza2"]
const PIZZA_RUNS := [23, 24, 25]


func _attach_pepper(body: MeshInstance3D) -> void:
	pepper_blk = BlkFile.parse(Data.read("_data/%s/anim/MFIG.blk" % zone))
	board_blk = BlkFile.parse(Data.read("_data/%s/anim/SKBD.blk" % zone))
	if pepper_blk == null:
		return
	var materials: Array = []
	for i in body.mesh.get_surface_count():
		materials.append(body.mesh.surface_get_material(i))
	pepper_skin = SkinnedMesh.create(MeshFile.parse(Data.read("_data/%s/meshes/PEPP_HR.msh" % zone)), materials)
	for part in pepper_parts_table:
		var built := MeshBuilder.build(zone, part[0], 0, true, runs.get(part[1], PackedInt32Array()), true)
		if built == null:
			continue
		body.add_child(built)
		built.name = String(part[0])
		_register_faces("16", built)
		pepper_parts.append([built, part[2]])
	pepper_body = body
	var idle := pepper_blk.pose(PEPPER_IDLE_CLIP, 0)
	if pepper_skin != null and idle.size() >= 17:
		pepper_skin.update(idle)
		pepper_foot = -pepper_skin.mesh.get_aabb().position.y
	_pose_pepper()


func _footsteps(clip: int) -> void:
	if pepper_blk == null or zone != ISLAND_ZONE or jump_t >= 0.0:
		return
	if clip >= pepper_blk.anims.size():
		return
	var frames: int = maxi(int(pepper_blk.anims[clip].frames), 1)
	if pepper_time >= frames:
		pepper_time = fmod(pepper_time, float(frames))
		foot_stage = 0
	var first := 6.0
	var second := 16.0
	if clip == 36:
		first = 4.0
		second = 14.0
	elif clip != 8 and clip != 13:
		foot_stage = 0
		return
	if foot_stage == 0 and pepper_time > first:
		foot_stage = 1
		_play_footstep()
	elif foot_stage == 1 and pepper_time > second:
		foot_stage = 2
		_play_footstep()


func _play_footstep() -> void:
	var set_name: String = FOOTSTEP_SETS.get(ground_surface, "GRASS")
	foot_cycle = (foot_cycle + 1) % 4
	var file: String = FOOTSTEP_FILES[set_name] % (foot_cycle + 1)
	var folder := "BRIDGE" if set_name == "BRIDGE" else set_name
	var path := "_data/sounds/z02LGI/Footsteps/%s/%s.WAV" % [folder, file]
	if not foot_streams.has(path):
		foot_streams[path] = Wav.parse(Data.read(path))
	var stream: AudioStream = foot_streams[path]
	if stream == null or DisplayServer.get_name() == "headless":
		return
	if foot_player == null:
		foot_player = AudioStreamPlayer.new()
		foot_player.bus = "Sound"
		add_child(foot_player)
	foot_player.stream = stream
	foot_player.volume_db = -4.0
	foot_player.play()


func _pose_pepper() -> void:
	if pepper_blk == null:
		return
	var pose := pepper_blk.pose(pepper_clip, int(pepper_time))
	if pose.size() < 17:
		return
	if pepper_skin != null and pepper_body != null:
		pepper_skin.update(pose)
		pepper_body.mesh = pepper_skin.mesh
	var flip := Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))
	for entry in pepper_parts:
		var bone: Transform3D = pose[entry[1]]
		entry[0].transform = Transform3D(flip * bone.basis * flip, MeshBuilder.flip(bone.origin))


func _animate_pepper(magnitude: float, delta: float, jumping := false) -> void:
	if (Game.get_var(0x5E) & HURT_BIT) != 0:
		if hurt_t < 0.0:
			hurt_t = 0.0
		hurt_t += RAMP_RATE * delta
		pepper_clip = HURT_CLIP
		pepper_time = hurt_t
		_pose_pepper()
		if hurt_t > _clip_frames(HURT_CLIP):
			Game.set_var(0x5E, Game.get_var(0x5E) & ~HURT_BIT)
			hurt_t = -1.0
		return
	if throw_t >= 0.0:
		# FUN_00871db4: the action plays the throw clip (11 standing, 66 running)
		# or the splat clip (12) and holds the player still. pepper_time tracks the
		# action clock so the hand lines up with the frame the pizza is shown and
		# released on.
		throw_t += RAMP_RATE * delta
		pepper_clip = _throw_clip()
		pepper_time = throw_t
		_pose_pepper()
		return
	if dismount_t >= 0.0:
		# FUN_00452ADD: getting off the board plays PEP_OFFBOARD (0x1C) before the walk takes over.
		dismount_t += RAMP_RATE * delta
		pepper_clip = BOARD_OFF_CLIP
		pepper_time = dismount_t
		if dismount_t >= _clip_frames(BOARD_OFF_CLIP) - 1.0:
			dismount_t = -1.0
		_pose_pepper()
		return
	if not jumping and train_off >= 0.0:
		# FUN_004d78f2: stepping off keeps the rider in 0x1b PEP_INTOWALK, the
		# transition back into the walk cycle.
		train_off += RAMP_RATE * delta
		pepper_clip = TRAIN_OFF_CLIP
		pepper_time = train_off
		if train_off > _clip_frames(TRAIN_OFF_CLIP):
			train_off = -1.0
		_pose_pepper()
		return
	if not jumping and (board_on or (board_off >= 0.0 and board_off < _clip_frames(BOARD_OFF_CLIP))):
		# Skateboard poses. There is no skate key (see the BOARD_* constants), so
		# the clip is chosen from the mount state alone: PEP_ONTOBOARD while the
		# mount pose holds, PEP_BOARDSTEER while rolling, PEP_BOARDCYCLE while
		# standing still on the board, PEP_OFFBOARD for the dismount.
		var board_clip := BOARD_CYCLE_CLIP
		if board_off >= 0.0:
			board_clip = BOARD_OFF_CLIP
		elif board_t < _clip_frames(BOARD_ON_CLIP):
			board_clip = BOARD_ON_CLIP
		elif magnitude >= CREEP_THRESHOLD:
			board_clip = BOARD_STEER_CLIP
		if board_clip != pepper_clip:
			pepper_clip = board_clip
			pepper_time = 0.0
		pepper_time += RAMP_RATE * delta
		_pose_pepper()
		return
	var clip := PEPPER_IDLE_CLIP
	var rate := 0.666
	if jumping:
		magnitude = 0.0
		clip = JUMP_CLIP
		rate = 1.0
	if jumping:
		pass
	elif swimming:
		clip = SWIM_CLIP if magnitude >= CREEP_THRESHOLD else TREAD_CLIP
		rate = 1.0
	elif magnitude >= RUN_THRESHOLD:
		clip = 36
		rate = 1.25
	elif magnitude >= WALK_THRESHOLD:
		clip = 13
		rate = 1.0
	elif magnitude >= CREEP_THRESHOLD:
		clip = 8
		rate = 1.0
	if clip != pepper_clip:
		pepper_clip = clip
		pepper_time = 0.0
	pepper_time += rate * RAMP_RATE * delta
	_footsteps(clip)
	_pose_pepper()


func _pizza_target() -> int:
	# CONFIRMED FUN_0087402e: the nearest visible talking actor (one with a talk node)
	# within 200 units (squared limit 40000, 3D) whose bearing is inside the cone.
	# The bearing error is halved for targets under 80 units (squared 6400:
	# _DAT_00974b28/2c = 1600/6400, both factors 0.5) and must then be <= 0.7854, so
	# the cone is 90 degrees up close and 45 degrees at range. -1 when nothing
	# qualifies; FUN_008742d5 then throws straight ahead, and the distance (< 23.04
	# squared) chooses the close-range splat.
	if cheerers.is_empty() or csm_host == null:
		return -1
	var talkers := {}
	for code in csm_host.TALK_LINKS.keys():
		talkers[int(csm_host.records.get(code, -1))] = true
	for bot in BOT_TAGS.keys():
		talkers[bot] = true
	var facing := Vector3(sin(player_yaw), 0.0, cos(player_yaw))
	var best := -1
	var best_d := 40000.0
	for i in cheerers.size():
		var node: MeshInstance3D = cheerers[i].node
		var record := int(String(node.name).get_slice("_", String(node.name).get_slice_count("_") - 1))
		if not talkers.has(record) or not node.visible:
			continue
		var gap := node.global_position - player_pos
		var d2 := gap.length_squared()
		if d2 > best_d or d2 < 0.0001:
			continue
		var flat := Vector3(gap.x, 0.0, gap.z)
		if flat.length_squared() < 0.0001:
			continue
		var angle := acos(clampf(facing.dot(flat.normalized()), -1.0, 1.0))
		if d2 < 6400.0:
			angle *= 0.5
		if angle > 0.7853981:
			continue
		best = i
		best_d = d2
	return best


func _start_throw(running := false) -> void:
	throw_target = _pizza_target()
	if throw_target < 0:
		# FUN_008742d5 returns 1 (the throw) when no target is in the cone: the
		# pizza flies straight ahead instead of being refused.
		throw_melee = false
		throw_running = running
		throw_t = 0.0
		pepper_clip = _throw_clip()
		pepper_time = 0.0
		pizza_spawned = false
		return
	# FUN_008742d5: beyond _DAT_00887300 = 23.04 (squared) it is the normal
	# throw, inside it the Two-Pizza Splat. Only the throw has a running variant;
	# the exe's a == 2 branch plays clip 12 from any movement state.
	var node: MeshInstance3D = cheerers[throw_target].node
	var flat := node.global_position - player_pos
	flat.y = 0.0
	throw_melee = (node.global_position - player_pos).length_squared() < THROW_RANGE_SQUARED
	throw_running = running and not throw_melee
	throw_t = 0.0
	pepper_clip = _throw_clip()
	pepper_time = 0.0
	pizza_spawned = false


func _build_pizza() -> MeshInstance3D:
	var slot: int = pizza_slot % PIZZA_MESHES.size()
	pizza_slot += 1
	var key := "pizza:%d" % slot
	if not mesh_cache.has(key):
		var built := MeshBuilder.build(zone, PIZZA_MESHES[slot], 0, true,
			runs.get(PIZZA_RUNS[slot], PackedInt32Array()), true)
		mesh_cache[key] = built.mesh if built != null else null
	var mesh: Mesh = mesh_cache[key]
	if mesh == null:
		return null
	var node := MeshInstance3D.new()
	node.mesh = mesh
	add_child(node)
	return node


func _hand_point() -> Vector3:
	for entry in pepper_parts:
		if int(entry[1]) == 14:
			return (entry[0] as MeshInstance3D).global_position
	return player_pos + Vector3(0.0, 2.0, 0.0)


func _throw_clip() -> int:
	if throw_melee:
		return SPLAT_CLIP
	return THROW_RUN_CLIP if throw_running else THROW_CLIP


func _throw_frames() -> float:
	var clip := _throw_clip()
	if pepper_blk == null or clip >= pepper_blk.anims.size():
		return _release_frame() + 15.0
	return float(int(pepper_blk.anims[clip].frames))


func _show_frame() -> float:
	if throw_melee:
		return SPLAT_SHOW_FRAME
	return THROW_RUN_SHOW_FRAME if throw_running else THROW_SHOW_FRAME


func _release_frame() -> float:
	if throw_melee:
		return SPLAT_FRAME
	return THROW_RUN_LAUNCH_FRAME if throw_running else THROW_LAUNCH_FRAME


func _update_pizza(delta: float) -> void:
	if throw_t >= 0.0:
		if throw_t >= _show_frame() and not pizza_spawned:
			pizza_spawned = true
			pizza_held = _build_pizza()
		if pizza_held != null:
			pizza_held.global_position = _hand_point()
		if throw_t >= _release_frame() and pizza_held != null:
			if throw_melee:
				# FUN_008750ca: the Two-Pizza Splat never leaves the hand, it
				# splats on the spot in front of the player.
				_splat_in_hand()
			else:
				_launch_pizza()
		if throw_t >= _throw_frames():
			throw_t = -1.0
			if pizza_held != null:
				pizza_held.queue_free()
				pizza_held = null
	for i in range(pizzas.size() - 1, -1, -1):
		var p: Dictionary = pizzas[i]
		var node: MeshInstance3D = p.node
		node.global_position += (p.velocity as Vector3) * delta
		p.life = float(p.life) + delta
		if float(p.life) > PIZZA_LIFETIME:
			# FUN_008744c2's age > 144 branch (case 4): retired silently, in
			# mid-air, with no splat.
			node.queue_free()
			pizzas.remove_at(i)
			continue
		if _pizza_landed(p):
			_splat(p)
			pizzas.remove_at(i)


func _launch_pizza() -> void:
	var from := pizza_held.global_position
	var aim := from + Vector3(sin(player_yaw), 0.0, cos(player_yaw)) * 20.0
	if throw_target >= 0 and throw_target < cheerers.size():
		aim = (cheerers[throw_target].node as MeshInstance3D).global_position + Vector3(0.0, THROW_ARC, 0.0)
	# FUN_0087402e hands the raw target offset to FUN_008744c2, which advances the
	# pizza by _DAT_00887088 (4) times that offset each second - a straight shot.
	pizzas.append({"node": pizza_held, "velocity": (aim - from) * THROW_SPEED,
		"target": throw_target, "life": 0.0})
	pizza_held = null
	_play_pizza_sound("Throw.WAV")


func _pizza_landed(p: Dictionary) -> bool:
	var pos: Vector3 = (p.node as MeshInstance3D).global_position
	for i in cheerers.size():
		# The shot is aimed _DAT_0088d9c8 (2.66664) above the actor's feet, so the
		# hit sphere has to cover the body, not just the origin point.
		var node: MeshInstance3D = cheerers[i].node
		if node.global_position.distance_squared_to(pos) < 16.0:
			_bot_hit(node)
			return true
	var ground := _surface(pos)
	return ground > -INF and pos.y <= ground


func _splat(p: Dictionary) -> void:
	(p.node as MeshInstance3D).queue_free()
	_play_pizza_sound("Piza_Hit.WAV")


func _splat_in_hand() -> void:
	# The close-range splat: the pizza in the hand is spent on the spot.
	if throw_target >= 0 and throw_target < cheerers.size():
		_bot_hit(cheerers[throw_target].node)
	pizza_held.queue_free()
	pizza_held = null
	_play_pizza_sound("Piza_Hit.WAV")


func _play_pizza_sound(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var path := "_data/sounds/z02LGI/%s.wav" % name
	if not foot_streams.has(path):
		foot_streams[path] = Wav.parse(Data.read(path))
	var stream: AudioStream = foot_streams[path]
	if stream == null:
		return
	if pizza_player == null:
		pizza_player = AudioStreamPlayer.new()
		pizza_player.bus = "Sound"
		add_child(pizza_player)
	pizza_player.stream = stream
	pizza_player.play()


## Face frames. The face texture is a 4 x 4 sheet of 64 x 64 expressions (the .wib
## frames) and every head mesh points at frame 0; SETEXPRESSION n (0..15 in the cut
## scenes) moves the UV by whole tiles. Each head gets its own copy of the face
## material so people change expression one at a time.
var faces := {}


func _register_faces(key: String, node: MeshInstance3D) -> void:
	if node.mesh == null:
		return
	for i in node.mesh.get_surface_count():
		var material := node.mesh.surface_get_material(i)
		if material != null and material.has_meta("face"):
			var own := material.duplicate()
			node.set_surface_override_material(i, own)
			var list: Array = faces.get(key, [])
			list.append(own)
			faces[key] = list


func set_face(key: String, frame: int) -> void:
	var offset := Vector2(float(frame % 4) * 0.25, -float(frame / 4) * 0.25)
	for material in faces.get(key, []):
		(material as ShaderMaterial).set_shader_parameter("uv_offset", offset)


func reset_faces() -> void:
	for key in faces:
		set_face(key, 0)


func _attach_parts(instance: MeshInstance3D, list: Array, part_models: Dictionary, record := -1) -> Array:
	var attached: Array = []
	var rig := _rig_for("MFG_HR")
	var blk: BlkFile = rig.blk
	if blk == null:
		return attached
	if npc_pose.is_empty():
		npc_pose = blk.pose(PEPPER_IDLE_CLIP, 0)
	if npc_pose.size() < 17:
		return attached
	var flip := Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))
	for entry in list:
		var child: int = entry[0]
		var bone: int = entry[1]
		if not part_models.has(child) or bone >= npc_pose.size():
			continue
		var slot: int = part_models[child][0]
		var run: int = part_models[child][1]
		var key := "part:%d:%d" % [slot, run]
		if not mesh_cache.has(key):
			var built := MeshBuilder.build(zone, String(mesh_names.get(slot, "")), 0, true, runs.get(run, PackedInt32Array()), true)
			mesh_cache[key] = built.mesh if built != null else null
		var mesh: Mesh = mesh_cache[key]
		if mesh == null:
			continue
		var transform_bone: Transform3D = npc_pose[bone]
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.transform = Transform3D(flip * transform_bone.basis * flip, MeshBuilder.flip(transform_bone.origin))
		instance.add_child(node)
		_register_faces(str(record), node)
		attached.append([node, bone])
	return attached


## The scene basis of a game matrix given by its three rows (row vectors, z mirrored).
func rows_basis(row0: Vector3, row1: Vector3, row2: Vector3) -> Basis:
	var rows := [row0, row1, row2]
	var flipped := Basis()
	for i in 3:
		var column := Vector3.ZERO
		for j in 3:
			var value: float = rows[i][j]
			var sign_i := -1.0 if i == 2 else 1.0
			var sign_j := -1.0 if j == 2 else 1.0
			column[j] = value * sign_i * sign_j
		flipped[i] = column
	return flipped


func camera_game_position() -> Vector3:
	var at := camera.global_position
	return Vector3(at.x, at.y, -at.z)


## Move a record's collision shape with it (a machine that is driven away).
func move_collider(record: int, scene_position: Vector3, yaw: float) -> void:
	for item in colliders:
		if int(item.get("record", -1)) == record:
			item.position = scene_position
			item.basis = Basis(Vector3.UP, -yaw).inverse()


func _placement_basis(rx: float, ry: float, rz: float) -> Basis:
	var cx := cos(rx)
	var sx := sin(rx)
	var cy := cos(ry)
	var sy := sin(ry)
	var cz := cos(rz)
	var sz := sin(rz)
	var row0 := Vector3(cz * cy, sz * cy, -sy)
	var row1 := Vector3(cz * sy * sx - sz * cx, cz * cx + sz * sy * sx, cy * sx)
	var row2 := Vector3(sz * sx + cz * sy * cx, sz * sy * cx - cz * sx, cy * cx)
	var rows := [row0, row1, row2]
	var flipped := Basis()
	for i in 3:
		var column := Vector3.ZERO
		for j in 3:
			var value: float = rows[i][j]
			var sign_i := -1.0 if i == 2 else 1.0
			var sign_j := -1.0 if j == 2 else 1.0
			column[j] = value * sign_i * sign_j
		flipped[i] = column
	return flipped


func _story_start(state: int) -> Vector3:
	var node := -1
	if state < 4:
		node = STORY_START_NODE
	elif state == 0x3D:
		node = STORY_LATE_START_NODE
	if node < 0:
		return Vector3.INF
	var bytes := Data.read("_data/z02LGI/waypoints/w_path_c.wpt")
	var at := WAYPOINT_HEADER_BYTES + node * WAYPOINT_NODE_BYTES
	if bytes.size() < at + 12:
		return Vector3.INF
	return Vector3(bytes.decode_float(at), bytes.decode_float(at + 4), bytes.decode_float(at + 8))


func _story_hidden(record: int, state: int) -> bool:
	return Story.hidden(record, state, Game)


## F6/F7: the exe's own chapter debug keys. F7 is FUN_0041f7e5 case 1 ->
## FUN_00404ba7(var 0x58 + 1), which writes the new row's objective first - the
## state is born "done", and the per-frame poll then cascades while rows report
## complete, exactly like the exe's debug skip. F6 is one back (FUN_00404a96
## without the snapshot restore).
func _story_step(delta: int) -> void:
	if _story_travelling:
		return
	var from := Game.get_var(Game.VAR_STATE)
	var next := Story.jump(Game, delta)
	print("[story] F%d: state %d -> %d" % [7 if delta > 0 else 6, from, next])
	_story_goto(next, from)


## FUN_00404a40 + FUN_00404b52: when this zone's own objective reports finished,
## advance one state. A chapter change reloads the zone in the exe too
## (FUN_00404d69 runs the zone function again after the island returns the same
## zone), so the port reloads - that reload is what re-applies the act.
## Returns true when an advance was taken.
func _story_poll() -> bool:
	if _story_travelling or story_hold or not ready_to_walk or pause_layer != null:
		return false
	var state := Game.get_var(Game.VAR_STATE)
	if Story.archive_of(state) != zone:
		return false
	if not Story.done(state, Game):
		return false
	var next := Story.advance(Game)
	print("[story] objective done: state %d -> %d" % [state, next])
	_story_goto(next, state)
	return true


## Load the zone the new state lives in. Inside the island the exe reloads the
## same zone; a different archive is the real zone change.
func _story_goto(next: int, from_state: int) -> void:
	if _story_travelling:
		return
	_story_travelling = true
	var code := Story.archive_of(next)
	print("[story] state %d -> %d lands in %s" % [from_state, next, code])
	var load := Story.load_zone(code)
	Game.pending_zone = int(load[0])
	Game.pending_zone_code = String(load[1])
	get_tree().change_scene_to_file("res://scenes/loading.tscn")


func _cheer_setup(record: int, instance: MeshInstance3D, key: String, mesh_name: String, forced_clip := -1) -> void:
	var rig := _rig_for(mesh_name)
	var blk: BlkFile = rig.blk
	var base: Mesh = mesh_cache.get(key)
	var file := MeshFile.parse(Data.read("_data/%s/meshes/%s.msh" % [zone, mesh_name]))
	if blk == null or base == null or file == null:
		return
	var materials: Array = []
	for i in base.get_surface_count():
		materials.append(base.surface_get_material(i))
	var skin := SkinnedMesh.create(file, materials)
	if skin == null:
		return
	# FUN_00490AEB at 0x004B429B pushes the literal 1 for the clip on every actor
	# record 9..66, so clip 1 is the confirmed start clip. The former
# CHEER_CLIP_A/B (122/123), which findings/11 records as having no evidence behind
# them, have been deleted.
	# were placeholders with no evidence behind them.
	var clip := START_CLIP
	if forced_clip >= 0:
		clip = forced_clip
	# The behaviour system gives every actor a three-stage clip sequence: the
	# loader puts it on the cheer (clip 1), the act descriptor makes it play its
	# own signature act, and once the idle timer runs out FUN_0045889f drops it
	# onto its idle clip. Anything not in ACTOR_CLIPS has no act, so it goes
	# straight from the cheer to the idle.
	var act := int(ACTOR_CLIPS.get(record, -1))
	# CONFIRMED: only the seven records in ACTOR_IDLE_CLIPS have a Human1
	# descriptor, so only they ever switch off their current clip. Everything else
	# keeps whatever the act left it on.
	cheerers.append({"node": instance, "skin": skin, "blk": blk, "clip": clip,
		"time": 0.0, "frame": -1, "parts": [], "since": 0.0, "stage": 0,
		"act": act, "idle": int(ACTOR_IDLE_CLIPS.get(record, NO_IDLE)), "key": key})


func _set_clip(item: Dictionary, clip: int) -> void:
	item.clip = clip
	item.time = 0.0
	item.frame = -1
	item.since = 0.0


func _cheer(delta: float) -> void:
	if cheerers.is_empty():
		return
	var flip := Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))
	var eye := camera.position
	var range_sq := CHEER_RANGE * CHEER_RANGE
	for item in cheerers:
		if not bool(item.get("driven", false)):
			item.time += delta * SPIN_TICKS
		# Three stages, mirroring the behaviour layer the loader only starts:
		#   0  the loader's clip (the cheer)  - FUN_00490AEB at 0x004B429B
		#   1  the record's own act clip      - FUN_0045c6a0 descriptor, ACTOR_CLIPS
		#   2  the idle clip                  - FUN_0045889f, when the timer at
		#                                       descriptor +0x2C runs out, from
		#                                       actor record +0x52
		item.since += delta
		if int(item.stage) == 0:
			if item.since >= START_CLIP_SECONDS:
				if int(item.act) >= 0:
					item.stage = 1
					_set_clip(item, int(item.act))
				elif int(item.idle) >= 0:
					item.stage = 2
					_set_clip(item, int(item.idle))
				else:
					item.stage = 3
		elif int(item.stage) == 1:
			if item.since >= ACT_CLIP_SECONDS:
				if int(item.idle) >= 0:
					item.stage = 2
					_set_clip(item, int(item.idle))
				else:
					item.stage = 3
		var node: MeshInstance3D = item.node
		if node.global_position.distance_squared_to(eye) > range_sq:
			continue
		var blk: BlkFile = item.blk
		var frames := 1
		if item.clip < blk.anims.size():
			frames = maxi(int(blk.anims[item.clip].frames), 1)
		var frame := int(item.time) % frames
		if frame == item.frame:
			continue
		item.frame = frame
		var pose := blk.pose(item.clip, frame)
		if pose.size() < blk.offsets.size():
			continue
		var skin: SkinnedMesh = item.skin
		skin.update(pose)
		node.mesh = skin.mesh
		for entry in item.parts:
			var bone: int = entry[1]
			if bone < pose.size():
				var bone_transform: Transform3D = pose[bone]
				(entry[0] as MeshInstance3D).transform = Transform3D(flip * bone_transform.basis * flip, MeshBuilder.flip(bone_transform.origin))


func _turn_spectators(delta: float) -> void:
	if spectators.is_empty():
		return
	var steps := delta * SPIN_TICKS
	var focus: Vector3 = player_pos if player != null else camera.position
	var target := Vector3(focus.x, focus.y, -focus.z)
	for item in spectators:
		var home: Vector3 = item.home
		var gap := target - home
		var yaw: float = item.yaw
		var facing := Vector3(sin(yaw), 0.0, cos(yaw)).dot(gap)
		if facing > SPECTATOR_FACING:
			yaw = atan2(gap.x, gap.z)
		elif facing <= 0.0:
			yaw -= SPECTATOR_TURN * steps
		else:
			yaw += SPECTATOR_TURN * steps
		item.yaw = wrapf(yaw, -PI, PI)
		(item.node as MeshInstance3D).basis = _placement_basis(item.rx, item.yaw, item.rz)


func _add_swift(instance: MeshInstance3D, key: String, mesh_name: String, position: Vector3) -> void:
	var rig := _rig_for(mesh_name)
	var blk: BlkFile = rig.blk
	var base: Mesh = mesh_cache.get(key)
	var file := MeshFile.parse(Data.read("_data/%s/meshes/%s.msh" % [zone, mesh_name]))
	if blk == null or base == null or file == null:
		return
	if swift_flock == null:
		swift_flock = SwiftFlock.new()
		swift_flock.blk = blk
		swift_flock.points = SwiftFlock.load_points(Data.read("_data/%s/matanim/swift.man" % zone))
		if swift_flock.points.is_empty():
			swift_flock = null
			return
	var materials: Array = []
	for i in base.get_surface_count():
		materials.append(base.surface_get_material(i))
	var skin := SkinnedMesh.create(file, materials)
	if skin == null:
		return
	swift_flock.add_follower(instance, skin, position, _placement_basis)


## Build the train's route once: the loop of W_ROAD corner nodes that
## `DAT_008ba470` cycles, expanded into every intermediate node with the game's
## own next-hop lookup (`FUN_00448049`). Nothing is invented - the node ids and
## positions come from the shipped `w_road_c.wpt`.
func _build_train_route() -> void:
	if train_built or train_tried:
		return
	train_tried = true
	var graph: Waypoints = Waypoints.new()
	if not graph.parse(Data.read(TRAIN_WAYPOINT)):
		push_warning("[train] %s did not parse" % TRAIN_WAYPOINT)
		return
	var ids: Array = []
	for i in TRAIN_LOOP.size():
		var from_id: int = TRAIN_LOOP[i]
		var to_id: int = TRAIN_LOOP[(i + 1) % TRAIN_LOOP.size()]
		var leg := graph.route(from_id, to_id)
		if leg.is_empty():
			push_warning("[train] no route from node %d to %d" % [from_id, to_id])
			return
		for k in leg.size():
			if i > 0 and k == 0:
				continue  # a leg starts on the previous leg's last node
			ids.append(int(leg[k]))
	train_path.clear()
	for id in ids:
		# Same flip the placement loop uses: (x, y, -z).
		var p: Vector3 = graph.nodes[id]
		train_path.append(Vector3(p.x, p.y, -p.z))
	if train_path.size() > 1 and (train_path[0] as Vector3).distance_to(train_path[train_path.size() - 1]) < 0.0001:
		train_path.remove_at(train_path.size() - 1)
	train_length = 0.0
	for i in train_path.size():
		train_length += (train_path[i] as Vector3).distance_to(train_path[(i + 1) % train_path.size()])
	train_built = train_length > 0.0
	# Where along this same polyline the train passes the schedule's two station
	# nodes (FUN_004d6d30), so the dwell can trigger on the way past.
	train_stations.clear()
	var walked := 0.0
	for i in train_path.size():
		if i < ids.size() and TRAIN_STATIONS.has(int(ids[i])):
			train_stations.append(walked)
		walked += (train_path[i] as Vector3).distance_to(train_path[(i + 1) % train_path.size()])
	print("[train] route %d nodes, %.1f units, stations %s" % [train_path.size(), train_length, str(train_stations)])


## Position and heading `distance` units along a closed loop of points.
func _loop_at(path: Array, length: float, distance: float) -> Array:
	var d := fposmod(distance, length)
	var walked := 0.0
	var last := path.size() - 1
	for i in path.size():
		var a: Vector3 = path[i]
		var b: Vector3 = path[(i + 1) % path.size()]
		var seg := a.distance_to(b)
		if walked + seg >= d or i == last:
			var t := 0.0 if seg <= 0.0001 else clampf((d - walked) / seg, 0.0, 1.0)
			var forward := b - a
			if forward.length() < 0.0001:
				forward = Vector3.FORWARD
			return [a.lerp(b, t), forward.normalized()]
		walked += seg
	return [path[0], Vector3.FORWARD]


## Position and heading of the train `distance` units along the loop.
func _train_at(distance: float) -> Array:
	return _loop_at(train_path, train_length, distance)


## Build each road vehicle's loop. `FUN_00447a0f(0, actor, node)` puts the walker on
## the W_ROAD graph at the descriptor's first word (the start node above); the
## descriptor's second word is 0 for all four, so the drive is the graph's own route
## to node 0 and back. That stays on the street grid - unlike the train's
## `TRAIN_LOOP` circuit, which is the rail loop (y 42.4) and put the cars on the
## tracks. OPEN: what the exe does with the descriptor's other two words and what
## happens when a car reaches node 0.
func _build_road_routes() -> void:
	if road_tried:
		return
	road_tried = true
	var graph := Waypoints.new()
	if not graph.parse(Data.read(TRAIN_WAYPOINT)):
		push_warning("[road] %s did not parse" % TRAIN_WAYPOINT)
		return
	for record in ROAD_VEHICLES.keys():
		if not road_cars.has(record):
			continue
		var start: int = int(ROAD_VEHICLES[record])
		if start < 0:
			# Node -1: the walker keeps the actor's placement position, so join the
			# graph at the graph node nearest that spot.
			var home: Vector3 = road_home.get(record, Vector3.ZERO)
			var best := -1
			var best_d := INF
			for n in graph.node_count:
				var p: Vector3 = graph.nodes[n]
				var d := Vector3(p.x, p.y, -p.z).distance_squared_to(home)
				if d < best_d:
					best_d = d
					best = n
			if best < 0:
				continue
			start = best
		var out := graph.route(start, ROAD_GOAL)
		var back := graph.route(ROAD_GOAL, start)
		if out.is_empty() or back.is_empty():
			push_warning("[road] record %d: no route between node %d and node %d"
				% [record, start, ROAD_GOAL])
			continue
		var ids: Array = []
		for id in out:
			ids.append(int(id))
		for k in back.size():
			if k == 0 and not ids.is_empty() and int(back[k]) == int(ids[ids.size() - 1]):
				continue  # the return leg starts where the outbound leg ended
			ids.append(int(back[k]))
		if ids.size() < 2:
			continue
		var path: Array = []
		for id in ids:
			var p: Vector3 = graph.nodes[id]
			path.append(Vector3(p.x, p.y, -p.z))
		if (path[0] as Vector3).distance_to(path[path.size() - 1]) < 0.0001:
			path.remove_at(path.size() - 1)
		if path.size() < 2:
			continue
		var length := 0.0
		for i in path.size():
			length += (path[i] as Vector3).distance_to(path[(i + 1) % path.size()])
		if length <= 0.0:
			continue
		road_paths[record] = path
		road_lengths[record] = length
		road_dist[record] = 0.0
		print("[road] record %d route %d nodes, %.1f units" % [record, path.size(), length])


## Road cars stay parked where they are placed. They only drive when their owner takes
## them out (the doctor with the ambulance), which is story script work that is not
## ported, so nothing drives by itself - and the collision shape stays under the car.
const ROAD_TRAFFIC := false


func _update_road(delta: float) -> void:
	if not ROAD_TRAFFIC or road_cars.is_empty():
		return
	_build_road_routes()
	for record in road_cars.keys():
		if not road_paths.has(record):
			continue
		var node: MeshInstance3D = road_cars[record]
		var length: float = road_lengths[record]
		var d: float = fposmod(float(road_dist[record]) + ROAD_SPEED * delta, length)
		road_dist[record] = d
		var at := _loop_at(road_paths[record], length, d)
		var point: Vector3 = at[0]
		var forward: Vector3 = at[1]
		# Same convention as the train: the walker heading is `atan2(dx, dz)` and
		# the port's z axis is negated, so the actor yaw is `atan2(f.x, -f.z)`.
		node.position = point
		var base := _placement_basis(0.0, atan2(forward.x, -forward.z), 0.0)
		var flat := Vector3(forward.x, 0.0, forward.z).normalized()
		var local_forward := base.inverse() * flat
		var sign := 1.0 if local_forward.z >= 0.0 else -1.0
		# Ride the terrain: the nodes are sparse, so a hill between two of them
		# used to swallow the car and a downhill end left it in the air.
		var front := _road_height(point + flat * ROAD_PROBE, point.y)
		var back := _road_height(point - flat * ROAD_PROBE, point.y)
		var here := _road_height(point, point.y)
		if here > -INF:
			node.position.y = here
			if front > -INF and back > -INF:
				var pitch := atan2(front - back, ROAD_PROBE * 2.0)
				base = Basis(base.x.normalized(), -pitch * sign) * base
		node.basis = base
		if wheel_sets.has(record):
			(wheel_sets[record] as Object).spin(ROAD_SPEED * delta, sign)


## Terrain height under a road point, or -INF when there is none near the route.
func _road_height(point: Vector3, route_y: float) -> float:
	var g := _ground(Vector3(point.x, route_y + 4.0, point.z))
	if g == -INF or absf(g - route_y) > 8.0:
		return -INF
	return g


## Frames in a clip, from the shipped anim block, so a mount/dismount pose is held
## for exactly as long as the clip lasts.
## The board is a two-bone mesh: each vertex follows one bone of the clip the board plays
## (SKBD.blk), so the mesh is rebuilt from the pose whenever it is shown.
func _board_skin_setup(instance: MeshInstance3D, mesh_name: String) -> void:
	var file := MeshFile.parse(Data.read("_data/%s/meshes/%s.msh" % [zone, mesh_name]))
	var materials: Array = []
	for i in instance.mesh.get_surface_count():
		materials.append(instance.mesh.surface_get_material(i))
	board_skin = SkinnedMesh.create(file, materials)
	board_node = instance
	if board_blk == null:
		board_blk = BlkFile.parse(Data.read("_data/%s/anim/SKBD.blk" % zone))


func pose_board() -> void:
	if board_skin == null or board_blk == null:
		return
	var pose := board_blk.pose(board_clip, int(board_time))
	if pose.size() >= 2:
		board_skin.update(pose)
		board_node.mesh = board_skin.mesh


func _board_frames(clip: int) -> float:
	if board_blk == null or clip < 0 or clip >= board_blk.anims.size():
		return 1.0
	return maxf(float(int(board_blk.anims[clip].frames)), 1.0)


func _clip_frames(clip: int) -> float:
	if pepper_blk == null or clip < 0 or clip >= pepper_blk.anims.size():
		return BOARD_POSE_FRAMES
	return maxf(float(int(pepper_blk.anims[clip].frames)), 1.0)


## Step off the board. Bound to the action key in `_update_board`; also called
## directly by `tests/board_check.gd`, because a headless run cannot press a key.
func _board_step_off() -> void:
	if not board_on:
		return
	board_on = false
	board_lock = true
	board_off = 0.0
	print("[board] off the board at %s" % str(player_pos))


## The park's skateboard. There is no skate key to port (see the BOARD_* constants),
## so the port mounts on contact - walk onto the board - and the action key both mounts
## (from beside the board) and steps off (while riding). The board rides under the
## player's feet.
func _update_board(delta: float) -> void:
	if zone != PARK_ZONE or park_board == null or player == null:
		return
	if not board_measured:
		# Where the board's own geometry sits inside its mesh, and how thick it is.
		# Read off the mesh, so the ridden board lands under the player's feet
		# whatever the mesh's origin is.
		board_measured = true
		var box: AABB = park_board.get_aabb()
		board_centre = box.get_center()
		# The shipped board mesh stands on its tail - its 3.4-unit length runs along
		# the mesh's Y - so riding it means laying it down first. `board_flat` is
		# that quarter turn; `board_half` is how tall the box then stands.
		board_half = 0.0
		for i in 3:
			board_half += absf(board_flat.y[i]) * box.size[i] * 0.5
		board_half = maxf(board_half, 0.02)
	board_t += delta * RAMP_RATE
	if board_off >= 0.0:
		board_off += delta * RAMP_RATE
	var rack := board_home + board_home_basis * board_centre
	var gap := Vector2(player_pos.x - rack.x, player_pos.z - rack.z).length()
	if board_lock and gap > BOARD_REMOUNT_RADIUS:
		board_lock = false
	var key := Input.is_physical_key_pressed(KEY_F)
	var tapped := key and not board_key_held
	if not board_on:
		if (not board_lock and gap <= BOARD_MOUNT_RADIUS) \
				or (tapped and gap <= BOARD_REMOUNT_RADIUS):
			# On contact, or with the action key while standing next to it.
			board_on = true
			board_t = 0.0
			board_off = -1.0
			board_lock = false
			print("[board] on the board at %s" % str(player_pos))
	elif tapped:
		_board_step_off()
	board_key_held = key
	if board_on:
		# The board is laid flat and turned to face the way the player faces, and its
		# own centre is put under his feet, so it pivots in place instead of swinging
		# around a mesh origin that is not the board.
		var facing := Basis(Vector3.UP, player_yaw - PI * 0.5) * board_flat
		park_board.basis = facing
		var feet := player_pos + Vector3(0.0, board_half + 0.02, 0.0)
		park_board.position = feet - facing * board_centre
	elif board_off >= 0.0 and board_off >= _clip_frames(BOARD_OFF_CLIP):
		board_off = -1.0
	if not board_on and board_off < 0.0:
		park_board.position = board_home
		park_board.basis = board_home_basis


func _update_train(delta: float) -> void:
	if train_cars.is_empty():
		return
	_build_train_route()
	if not train_built:
		return
	_update_train_factor(delta)
	var train_step := TRAIN_SPEED * train_factor * delta
	train_dist = fposmod(train_dist + train_step, train_length)
	train_points.clear()
	train_forwards.clear()
	for i in TRAIN_RECORDS.size():
		var record: int = TRAIN_RECORDS[i]
		if not train_cars.has(record):
			train_points.append(Vector3.ZERO)
			train_forwards.append(Vector3.FORWARD)
			continue
		var node: MeshInstance3D = train_cars[record]
		var at := _train_at(train_dist - float(i) * TRAIN_CAR_GAP)
		var point: Vector3 = at[0]
		var forward: Vector3 = at[1]
		# The exe writes the walker heading into the actor's Y rotation
		# (`*(float *)(actor + 0x50) = heading`) and the walker heading is
		# `atan2(dx, dz)` with the step `pos += (sin h, cos h) * v`. The port's
		# z axis is negated, so the equivalent yaw is `atan2(f.x, -f.z)`, and
		# `_placement_basis` is used so the actor keeps the exe's own convention.
		node.position = point
		node.basis = _placement_basis(0.0, atan2(forward.x, -forward.z), 0.0)
		train_points.append(point)
		train_forwards.append(forward)
		if wheel_sets.has(record):
			var local_forward := node.basis.inverse() * Vector3(forward.x, 0.0, forward.z).normalized()
			(wheel_sets[record] as Object).spin(train_step, 1.0 if local_forward.z >= 0.0 else -1.0)
	if train_on:
		# After the cars move, so the rider rides this frame's car transform.
		_ride_attach()


## The station schedule and speed factor from `FUN_004d6d30`: cruise at 1.0, ramp
## down approaching a station node, hold `TRAIN_DWELL` at it, ramp back up. A rider
## drives instead - stations are not scheduled while someone rides (the exe gates
## the station branch on the ride flag) - throttle and brake with the forward
## axis, the port's stand-in for the exe's UP/SPACE and DOWN/ALT.
func _update_train_factor(delta: float) -> void:
	var ahead := _train_station_ahead()
	if ahead > TRAIN_BRAKE_DIST:
		train_armed = true
	if train_dwell > 0.0:
		train_dwell -= delta
		train_factor = 0.0
		if train_dwell <= 0.0:
			train_resuming = true
		return
	if train_on:
		var throttle := _forward_axis()
		if throttle > 0.05:
			train_factor = minf(TRAIN_FACTOR_MAX, train_factor + TRAIN_FACTOR_STEP * delta)
		elif throttle < -0.05:
			train_factor = maxf(TRAIN_FACTOR_MIN, train_factor - TRAIN_FACTOR_STEP * delta)
		return
	if train_resuming:
		train_factor = minf(1.0, train_factor + TRAIN_FACTOR_STEP * delta)
		if ahead > TRAIN_BRAKE_DIST:
			train_resuming = false
		return
	var target := clampf(ahead / TRAIN_BRAKE_DIST, 0.0, 1.0)
	if target < train_factor:
		train_factor = maxf(target, train_factor - TRAIN_FACTOR_STEP * delta)
	else:
		train_factor = minf(target, train_factor + TRAIN_FACTOR_STEP * delta)
	if train_armed and ahead < 1.0:
		train_dwell = TRAIN_DWELL
		train_factor = 0.0
		train_armed = false


## Distance from the train to the next station node along the loop.
func _train_station_ahead() -> float:
	var ahead := INF
	for sd in train_stations:
		ahead = minf(ahead, fposmod(float(sd) - train_dist, train_length))
	return ahead


## The car the player can board, as an index into `TRAIN_RECORDS`, or -1.
func _train_near() -> int:
	if train_cars.is_empty() or not train_built:
		return -1
	var best := -1
	var best_d := TRAIN_MOUNT_RADIUS
	for i in TRAIN_RECORDS.size():
		if not train_cars.has(TRAIN_RECORDS[i]):
			continue
		var p: Vector3 = (train_cars[TRAIN_RECORDS[i]] as MeshInstance3D).position
		var d := Vector2(player_pos.x - p.x, player_pos.z - p.z).length()
		if d <= best_d:
			best_d = d
			best = i
	return best


## Board the train (the action key inside `TRAIN_MOUNT_RADIUS`; the exe wants the
## CTRL mask plus an 8.0 probe). Tests call this directly - a headless run cannot
## press a key.
func _train_mount(index: int) -> void:
	if train_on or index < 0 or index >= TRAIN_RECORDS.size():
		return
	if not train_cars.has(TRAIN_RECORDS[index]):
		return
	train_on = true
	train_car = index
	train_lateral = 0.0
	jump_t = -1.0
	# FUN_004d78f2: boarding forces the speed factor to 0x3dcccccd (0.1), zeroes
	# the dwell timer and clears the stop state - a stop in progress is cancelled
	# and the rider throttles up from a crawl.
	train_dwell = 0.0
	train_resuming = false
	train_factor = TRAIN_FACTOR_MIN
	train_off = -1.0
	print("[train] on the train (car %d)" % index)


## Step off the train, beside the car, onto whatever surface is under it.
func _train_step_off() -> void:
	if not train_on:
		return
	train_on = false
	var point: Vector3 = train_points[train_car] if train_car < train_points.size() else Vector3.ZERO
	var forward: Vector3 = train_forwards[train_car] if train_car < train_forwards.size() else Vector3.FORWARD
	var right := Vector3(forward.z, 0.0, -forward.x).normalized()
	var side := 4.0 if train_lateral >= 0.0 else -4.0
	var spot := point + right * side
	var ground := _surface(Vector3(spot.x, point.y + 4.0, spot.z))
	player_pos = Vector3(spot.x, ground if ground > -INF else spot.y, spot.z)
	# FUN_004d78f2: stepping off clears the ride flag, arms the car's dwell timer
	# (param_2+0x20 = 0x43160000 = 150.0, 5 s at 30 Hz) and sets the stop state,
	# so the car brakes where the rider left it; the rider plays 0x1b.
	train_dwell = TRAIN_DWELL
	train_factor = 0.0
	train_off = 0.0
	print("[train] off the train at %s" % str(player_pos))


## The rider: sitting (PEP_SITTING, the exe's 0x43) on the ridden car's roof,
## sliding across it with the turn keys, twisted by the slide (`DAT_008ba494`).
func _ride_attach() -> void:
	if not train_cars.has(TRAIN_RECORDS[train_car]):
		train_on = false
		return
	var node: MeshInstance3D = train_cars[TRAIN_RECORDS[train_car]]
	if not train_measured:
		# The cars stand on the rail, so riding sits on the mesh's own top,
		# read off its box the same way the board reads its deck.
		train_measured = true
		train_roof = node.get_aabb().end.y
	var point: Vector3 = train_points[train_car]
	var forward: Vector3 = train_forwards[train_car]
	var right := Vector3(forward.z, 0.0, -forward.x).normalized()
	player_pos = point + Vector3(0.0, train_roof + 0.05, 0.0) + right * train_lateral
	player_yaw = atan2(forward.x, forward.z) - (PI * 0.25) * (1.0 if train_lateral >= 0.0 else -1.0)
	player.position = player_pos + Vector3(0, pepper_foot, 0)
	player.basis = Basis(Vector3.UP, player_yaw + PI)


## The rider's pose: `PEP_SITTING` (clip 67), held like the idle.
func _animate_train(delta: float) -> void:
	if pepper_blk == null:
		return
	if pepper_clip != TRAIN_RIDE_CLIP:
		pepper_clip = TRAIN_RIDE_CLIP
		pepper_time = 0.0
	pepper_time += RAMP_RATE * delta
	_pose_pepper()


func _add_rabbit(record: int, instance: MeshInstance3D, key: String, mesh_name: String, position: Vector3, yaw: float) -> void:
	var rig := _rig_for(mesh_name)
	var blk: BlkFile = rig.blk
	var base: Mesh = mesh_cache.get(key)
	var file := MeshFile.parse(Data.read("_data/%s/meshes/%s.msh" % [zone, mesh_name]))
	if blk == null or base == null or file == null:
		return
	var materials: Array = []
	for i in base.get_surface_count():
		materials.append(base.surface_get_material(i))
	var skin := SkinnedMesh.create(file, materials)
	if skin == null:
		return
	var rabbit := Rabbit.new()
	rabbit.node = instance
	rabbit.skin = skin
	rabbit.blk = blk
	rabbit.setup(RABBIT_SIGHT[record], RABBIT_SPEED, position, yaw)
	rabbit.basis_fn = _placement_basis
	if rabbit_waypoints.is_empty():
		for point in RABBIT_WAYPOINTS:
			var height := _rabbit_ground(Vector3(point.x, RABBIT_PROBE_HEIGHT, point.z))
			rabbit_waypoints.append(Vector3(point.x, height if height > -INF else point.y, point.z))
	rabbit.waypoints = rabbit_waypoints
	var floor_y := _rabbit_ground(position + Vector3(0.0, RABBIT_DROP, 0.0))
	if floor_y > -INF:
		rabbit.position.y = floor_y
	rabbits.append(rabbit)


func _rabbit_ground(point: Vector3) -> float:
	return _ground(Vector3(point.x, point.y, -point.z))


func _static_skin(key: String, mesh_name: String, mesh: Mesh) -> Mesh:
	var cache_key := "skin:" + key
	if mesh_cache.has(cache_key):
		return mesh_cache[cache_key]
	var result := mesh
	var file := MeshFile.parse(Data.read("_data/%s/meshes/%s.msh" % [zone, mesh_name]))
	if file != null and file.bones.size() == file.positions.size() and not file.bones.is_empty():
		var rig := _rig_for(mesh_name)
		var blk: BlkFile = rig.blk
		if blk != null and blk.offsets.size() > 1:
			var materials: Array = []
			for i in mesh.get_surface_count():
				materials.append(mesh.surface_get_material(i))
			var skin := SkinnedMesh.create(file, materials)
			var pose := blk.pose(rig.clip, 0)
			if skin != null and pose.size() >= blk.offsets.size():
				skin.update(pose)
				result = skin.mesh
	mesh_cache[cache_key] = result
	return result


var zone_rig := {}


## The smallest animation file of the zone that has a bone for every bone the parts name.
func _rig_by_bones(list: Array) -> Dictionary:
	var top := 0
	for entry in list:
		top = maxi(top, int(entry[1]))
	var best := {}
	var folder := "_data/%s/anim/" % zone
	for name in ["MFIG", "PEPD", "SKBD", "PRTB", "RATT", "HORS", "CATP", "SHRK", "PIRO", "DLPH", "MANT", "OCTO"]:
		if not rig_cache.has(name):
			rig_cache[name] = BlkFile.parse(Data.read(folder + name + ".blk"))
		var blk: BlkFile = rig_cache[name]
		if blk != null and blk.offsets.size() > top and (best.is_empty() or blk.offsets.size() < best.blk.offsets.size()):
			best = {"blk": blk, "clip": 0}
	return best


func _rig_for(mesh_name: String) -> Dictionary:
	var lowered := mesh_name.to_lower()
	var file := "MFIG"
	var clip := PEPPER_IDLE_CLIP
	if lowered.begins_with("rbb"):
		file = "RBBT"
		clip = 0
	elif lowered.begins_with("swft"):
		file = "SWFT"
		clip = SWIFT_PERCH_CLIP
	elif lowered.begins_with("pter"):
		file = "PTER"
		clip = 0
	elif lowered.contains("skel"):
		file = "SKBD"
		clip = 0
	elif lowered.begins_with("hors_hors"):
		file = "HORS"
		clip = 0
	if not zone_rig.is_empty() and file != "HORS":
		return zone_rig
	if not rig_cache.has(file):
		rig_cache[file] = BlkFile.parse(Data.read("_data/%s/anim/%s.blk" % [zone, file]))
	return {"blk": rig_cache[file], "clip": clip}


func _skip(reason: String, record := -1) -> void:
	var key := reason if record < 0 else "%s #%d" % [reason, record]
	skip_reasons[key] = int(skip_reasons.get(key, 0)) + 1


func skip_report() -> Array:
	var out: Array = []
	for reason in skip_reasons:
		out.append([reason, int(skip_reasons[reason])])
	out.sort_custom(func(a, b): return String(a[0]) < String(b[0]))
	return out


## Returns the rule that hides this object, or "" when it should be placed.
## Naming the rule matters: "position_zero" is a guard, while the name rules are
## deliberate, and a report that cannot tell them apart flags every intentional
## hide as suspicious.
func _hidden_at_start(mesh_name: String, position: Vector3) -> String:
	var lowered := mesh_name.to_lower()
	for part in HIDDEN_NAME_PARTS:
		if lowered.contains(part):
			return "name:" + part
	if position == Vector3.ZERO:
		return "position_zero"
	return ""


func _load_cols() -> void:
	for parts in _rows("res://data/%s_cols.tsv" % prefix):
		col_paths[int(parts[0])] = String(parts[2]).replace("\\", "/")
	for entry in collider_slots:
		var slot: int = entry[0]
		if not col_cache.has(slot):
			col_cache[slot] = ColFile.parse(Data.read(col_paths[slot])) if col_paths.has(slot) else null
		var col: ColFile = col_cache[slot]
		if col == null or col.count == 0:
			continue
		colliders.append({"col": col, "position": MeshBuilder.flip(entry[1]), "basis": Basis(Vector3.UP, -float(entry[2])).inverse(), "record": int(entry[3]) if entry.size() > 3 else -1, "reach": col.reach_radius()})


## FUN_00428210's static part: sweep a segment of `delta` from `origin` (scene coordinates) through the
## land's collision file and every record's, polygons filtered by `mask`. The closest hit comes back as
## {t, point, normal, record} (the record is -2 for the land itself), or {} for none.
func sweep(origin: Vector3, delta: Vector3, mask: int, radius: float, skin: float, skip_record := -1) -> Dictionary:
	var a := Vector3(origin.x, origin.y, -origin.z)
	var b := Vector3(origin.x + delta.x, origin.y + delta.y, -(origin.z + delta.z))
	var best := ColFile.NO_HIT
	var found := {}
	if land_col != null:
		var hit := land_col.sweep(a, b, radius, skin, mask)
		if not hit.is_empty():
			var n: Vector3 = hit.normal
			var at: Vector3 = hit.point
			found = {"t": hit.t, "point": Vector3(at.x, at.y, -at.z), "normal": Vector3(n.x, n.y, -n.z), "record": -2}
			best = hit.t
	var end := origin + delta
	var reach_margin := delta.length() + maxf(radius, skin) + 1.0
	for item in colliders:
		if skip_record >= 0 and int(item.get("record", -1)) == skip_record:
			continue
		var col: ColFile = item.col
		var gap: Vector2 = Vector2(origin.x - item.position.x, origin.z - item.position.z)
		if gap.length() > float(item.get("reach", INF)) + reach_margin:
			continue
		var la: Vector3 = item.basis * (origin - item.position)
		var lb: Vector3 = item.basis * (end - item.position)
		var hit := col.sweep(Vector3(la.x, la.y, -la.z), Vector3(lb.x, lb.y, -lb.z), radius, skin, mask)
		if hit.is_empty() or hit.t > best:
			continue
		var n: Vector3 = hit.normal
		var at: Vector3 = hit.point
		var turn: Basis = item.basis.inverse()
		found = {"t": hit.t, "point": turn * Vector3(at.x, at.y, -at.z) + item.position, "normal": (turn * Vector3(n.x, n.y, -n.z)).normalized(), "record": int(item.get("record", -1))}
		best = hit.t
	if not found.is_empty():
		wall_record = int(found.record)
	return found


## The collectible pages are not walls (the exe's walker lets a hit on a record named PAG... through).
func _is_page(record: int) -> bool:
	return bridge != null and record >= 0 and record < bridge.records.size() and String(bridge.records[record].code).begins_with("PAG")


## What Pepper's walker (FUN_00871DB4) does with a step: a sphere of radius 0.6 swept 1.48 up at the
## feet; a wall it meets (not a floor, not a page) is slid along, and a second hit stops the step. A
## second sweep at head height, 4 up and rising 1.2 along the step, only answers to surfaces that face
## downward (a ceiling or an overhang): it slides along them and stops on a second hit.
func _slide(from: Vector3, move: Vector3) -> Vector3:
	var step := Vector3(move.x, 0.0, move.z)
	if step.length() < 0.00001:
		return step
	var low := sweep(from + Vector3(0.0, WALK_FOOT_UP, 0.0), step, 1, ColFile.SWEEP_RADIUS, ColFile.SWEEP_SKIN, ground_skip)
	if not low.is_empty() and low.normal.y < 1.0 and not _is_page(int(low.record)):
		var wall: Vector3 = low.normal
		var along := wall.x * step.x + wall.z * step.z
		step.x -= wall.x * along
		step.z -= wall.z * along
		if not sweep(from + Vector3(0.0, WALK_FOOT_UP, 0.0), step, 3, ColFile.SWEEP_RADIUS, ColFile.SWEEP_SKIN, ground_skip).is_empty():
			step = Vector3.ZERO
	var head_step := Vector3(step.x, WALK_HEAD_RISE, step.z)
	var head := sweep(from + Vector3(0.0, WALK_HEAD_UP, 0.0), head_step, 1, ColFile.SWEEP_RADIUS, ColFile.SWEEP_SKIN, ground_skip)
	if not head.is_empty() and head.normal.y < 0.0:
		var roof: Vector3 = head.normal
		var against := roof.x * step.x + roof.z * step.z
		if against < 0.0:
			step.x -= roof.x * against
			step.z -= roof.z * against
			var again := sweep(from + Vector3(0.0, WALK_HEAD_UP, 0.0), Vector3(step.x, WALK_HEAD_RISE, step.z), 1, ColFile.SWEEP_RADIUS, ColFile.SWEEP_SKIN, ground_skip)
			if not again.is_empty() and again.normal.y > -1.0:
				step = Vector3.ZERO
			elif not again.is_empty():
				pass
	return step


func _wall_normal(from: Vector3, to: Vector3, skip_record := -1) -> Vector3:
	var heights := PackedFloat32Array([WALL_LOW, WALL_HIGH])
	var reach := Vector3(to.x - from.x, 0.0, to.z - from.z)
	if reach.length() > 0.0001:
		# The body has a radius: look that far past the step, as the exe's swept sphere does.
		to += reach.normalized() * WALL_RADIUS
	var a := Vector3(from.x, from.y, -from.z)
	var b := Vector3(to.x, to.y, -to.z)
	if land_col != null:
		var n: Vector3 = land_col.wall_hit(a, b, heights)
		if n != Vector3.ZERO:
			wall_record = -2
			return Vector3(n.x, 0.0, -n.z)
	for item in colliders:
		if skip_record >= 0 and int(item.get("record", -1)) == skip_record:
			continue
		var col: ColFile = item.col
		var la: Vector3 = item.basis * (from - item.position)
		var lb: Vector3 = item.basis * (to - item.position)
		var n: Vector3 = col.wall_hit(Vector3(la.x, la.y, -la.z), Vector3(lb.x, lb.y, -lb.z), heights)
		if n != Vector3.ZERO:
			wall_record = int(item.get("record", -1))
			var local := Vector3(n.x, 0.0, -n.z)
			var world: Vector3 = (item.basis.inverse() * local)
			return Vector3(world.x, 0.0, world.z).normalized()
	return Vector3.ZERO


func _surface(point: Vector3, step := STEP_UP) -> float:
	var height := _ground(point, step)
	if zone == ISLAND_ZONE and land_col != null and height < SEA_LEVEL and _in_sea(point):
		swimming = true
		return SEA_LEVEL
	swimming = false
	return height


## The sea slab's own footprint (it is the water the player swims in), with the
## old land-box margin as a floor so nothing that used to be water is lost.
func _in_sea(point: Vector3) -> bool:
	if sea_mesh != null:
		var box: AABB = sea_mesh.global_transform * sea_mesh.get_aabb()
		if point.x >= box.position.x and point.x <= box.end.x and point.z >= box.position.z and point.z <= box.end.z:
			return true
	var low: Vector3 = land_col.box_a
	var high: Vector3 = land_col.box_b
	var game_z := -point.z
	return point.x >= low.x - SEA_MARGIN and point.x <= high.x + SEA_MARGIN and game_z >= low.z - SEA_MARGIN and game_z <= high.z + SEA_MARGIN


func _ground(point: Vector3, step := STEP_UP, terrain_only := false) -> float:
	var best := -INF
	ground_surface = 0
	if land_col != null:
		best = land_col.ground(point.x, -point.z, point.y, step)
		if best > -INF:
			ground_surface = land_col.last_surface
	if terrain_only:
		return best
	for item in colliders:
		if ground_skip >= 0 and int(item.get("record", -1)) == ground_skip:
			continue
		var col: ColFile = item.col
		var local: Vector3 = item.basis * (point - item.position)
		if absf(local.x) > col.box_b.x + 1.0 or absf(local.z) > col.box_b.z + 1.0:
			continue
		var h := col.ground(local.x, -local.z, point.y - item.position.y, step)
		if h > -INF and h + item.position.y > best:
			best = h + item.position.y
			ground_surface = col.last_surface
	return best


## The highest record surface at or below a point (scene axes) and the record it belongs to:
## {"height", "record", "surface"}, empty when none. `skip` is a record to ignore.
func record_ground(point: Vector3, skip := -1) -> Dictionary:
	var best := -INF
	var found := {}
	for item in colliders:
		if skip >= 0 and int(item.get("record", -1)) == skip:
			continue
		var col: ColFile = item.col
		var local: Vector3 = item.basis * (point - item.position)
		if absf(local.x) > col.box_b.x + 1.0 or absf(local.z) > col.box_b.z + 1.0:
			continue
		var h := col.ground(local.x, -local.z, point.y - item.position.y, 0.0)
		if h > -INF and h + item.position.y > best:
			best = h + item.position.y
			found = {"height": best, "record": int(item.get("record", -1)), "surface": col.last_surface}
	return found


func _key(a: Key, b: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b) else 0.0


func _forward_axis() -> float:
	return clampf(Input.get_axis("ui_down", "ui_up") + _key(KEY_W, KEY_W) - _key(KEY_S, KEY_S), -1.0, 1.0)


func _turn_axis() -> float:
	return clampf(Input.get_axis("ui_right", "ui_left") + _key(KEY_A, KEY_A) - _key(KEY_D, KEY_D), -1.0, 1.0)


func _ramped(raw: float, delta: float) -> float:
	ramp_clock += delta * RAMP_RATE
	while ramp_clock >= 1.0:
		ramp_clock -= 1.0
		if raw > 0.0:
			ramp = RAMP_CENTRE if ramp < RAMP_CENTRE else mini(ramp + RAMP_PRESS, RAMP_MAX)
		elif raw < 0.0:
			ramp = RAMP_CENTRE if ramp > RAMP_CENTRE else maxi(ramp - RAMP_PRESS, 0)
		elif ramp > RAMP_CENTRE:
			ramp = maxi(ramp - RAMP_RELEASE, RAMP_CENTRE)
		elif ramp < RAMP_CENTRE:
			ramp = mini(ramp + RAMP_RELEASE, RAMP_CENTRE)
	var level := 255.0 if ramp == RAMP_MAX else float(ramp) * 8.0
	if absf(level - 128.0) <= STICK_DEADZONE:
		return 0.0
	return (level - 128.0) / 128.0
