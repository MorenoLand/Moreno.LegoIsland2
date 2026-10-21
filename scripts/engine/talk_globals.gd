class_name TalkGlobals
extends RefCounted

## Global state shared by the talk behaviours (FUN_0087D84E family). Addresses are the
## exe globals each field stands for.

## DAT_00975E80: game flags; bit 0x40 = talk prompts enabled, bit 0x80 = pizza throw.
var game_flags := 0
## _DAT_05DE1EE8 / DAT_05DE1F78: nearest talkable actor this frame and its distance (squared).
var nearest_distance := 1.0e38
var nearest_actor = null
## DAT_05DE20EC: a talk is running. DAT_05DE20F0: face timer. DAT_05DE2078: face frame.
var busy := 0
var face_timer := 0.0
var face_frame := 0
## DAT_05DE207C: record of the actor Pepper is talking to.
var talker = null
## DAT_05DE2088: groups of up to three records that react together (count at DAT_05DE20D0).
var groups: Array = []
## DAT_05DE20D4 mode (0 none, 1 actor, 2 actor+range, 3 waypoint, 4 any of four),
## DAT_05DE20D8..E4 targets, DAT_05DE20E8 range squared, DAT_00974F18 waypoint index.
var target_mode := 0
var targets: Array = [null, null, null, null]
var target_range := 0.0
var target_waypoint := -1
## DAT_05DE1E7C: record index hidden while a talk starts (-1 = none).
var hidden_record := -1
## DAT_05DE1CA0: lowest ground height an actor may fall to.
var ground_min := 0.0
## DAT_009749B8: clip last forced on Pepper.
var pepper_clip := 0
## DAT_05DE1F7C: name of the speech line being prepared.
var speech_name := ""


## FUN_0087B7BF: remember a group of three records that react to each other.
func add_group(a, b, c) -> void:
	if groups.size() < 6:
		groups.append([a, b, c])


## FUN_0087B91F: clear the talk target.
func clear_target() -> void:
	targets = [null, null, null, null]
	target_waypoint = -1
	target_mode = 0


## FUN_0087B8DF / 0087B970 / 0087B9B0 / 0087B9F9: choose what the talk prompt looks at.
func set_target_any(a, b, c, d) -> void:
	clear_target()
	target_range = 256.0
	target_mode = 4
	targets = [a, b, c, d]


func set_target_actor_range(actor, other, range_units: float) -> void:
	clear_target()
	target_mode = 2
	targets[0] = actor
	targets[1] = other
	target_range = range_units * 8.0 * range_units * 8.0


func set_target_actor(actor, range_units: float) -> void:
	clear_target()
	target_mode = 1 if actor != null else 0
	targets[0] = actor
	target_range = range_units * 8.0 * range_units * 8.0


func set_target_waypoint(index: int, range_units: float) -> void:
	clear_target()
	target_mode = 3
	target_waypoint = index
	target_range = range_units * 8.0 * range_units * 8.0

## DAT_008929AC / DAT_008929C8: current and default talk distance.
var talk_distance := 5.0
var talk_distance_default := 4.0
## DAT_05DE2080: the speech table; DAT_05DE1EF0: matrix of the actor Pepper talks to.
var speech_table = null
var talk_matrix = null
## DAT_05DE1EC8 (+2): list mode (-1 none, -2 / -3 pick the nearest waypoint of list B / A).
## Lists hold {table, node, used}.
var list_mode := -1
var list_a: Array = []
var list_b: Array = []
## DAT_05DE1DBC / DAT_05DE1DC8: up to three moving platforms (record, node) that carry
## talkers; DAT_05DE1DD4 / DAT_05DE1DDC / DAT_05DE1DB8: the ride record, its node and actor.
var platform_records: Array = []
var platform_nodes: Array = []
var ride_record = null
var ride_node = null
var ride_actor = null


## FUN_0087B811(actor, mask, op): the other members of the actor's group get the same
## change on their first behaviour's var (FUN_0086D549: op 0 or, 1 and, 2 clear, 3 set;
## vars below 3 are left alone).
func notify_group(actor, mask_in: int, op: int, vars) -> void:
	for group in groups:
		if group.has(actor):
			for member in group:
				if member == null or member == actor or member.block == null or member.block.head == null:
					continue
				head_op(member.block, mask_in, op, vars)
			return

## DAT_05D4A358: up to six groups of three records (the party members of the portals).
var parties: Array = []

## DAT_00975E7C: second game flag word. DAT_05D4A3B0 / DAT_05D4A3AC: the vehicle whose siren
## is playing and the crash flag of the emergency vehicles.
var game_flags_b := 0
var vehicle_siren_owner = null
var vehicle_crashed := 0

## DAT_05DE20F4 / DAT_05DE20FC / DAT_05DE20F8: the hologram guide's speech table, its
## delay timer and the "show now" flag.
var helper_table = null
var helper_timer := 0.0
var helper_ready := 0

## FUN_0086D549(block, mask, op): change the var of a block's first behaviour (op 0 or,
## 1 and, 2 clear, 3 set); vars below 3 are left alone.
func head_op(block, mask_in: int, op: int, vars) -> void:
	if block == null or block.head == null:
		return
	var head: Behaviour = block.head
	if head.tag < 3:
		return
	match op:
		0:
			vars.or_var(head.tag, mask_in)
		1:
			vars.set_var(head.tag, vars.get_var(head.tag) & mask_in)
		2:
			vars.clear_var(head.tag, mask_in)
		3:
			vars.set_var(head.tag, mask_in)


## _DAT_05D4A370: frame limit the BrickBot waits for; DAT_05D4A374: counter of the
## BrickBot formation slots (0..2).
var brickbot_frame := 0.0
var brickbot_slot := 0


## FUN_00875C16(actor): 1 when one of the three moving platforms carries the actor, 2 when
## Pepper's ride has picked it, else 0 (and 0 while var 0x58 is 0x34 or more).
func hit_kind(actor, vars) -> int:
	if vars.get_var(0x58) >= 0x34:
		return 0
	for node in platform_nodes:
		if node != null and node.get("occupant") == actor:
			return 1
	if ride_record == null or (ride_record.flags & 2) == 0 or ride_node == null or ride_node.get("actor") != actor:
		return 0
	return 2

## DAT_05DE1E80: the machine Pepper rides (record); DAT_00974CF8: the distance the next
## rideable has to beat; DAT_05DE2100: ride taken. DAT_05DE1CA0 is `ground_min`.
var machine_actor = null
var machine_distance := 12.0
var machine_taken := 0

## DAT_00975E8C / DAT_00975E90: the analog steering and throttle axes (-127..127);
## DAT_05DE1EE0: a boat was taken.
var axis_x := 0
var axis_y := 0
var boat_taken := 0

## DAT_05DE1D98: kind of the machine in play (9 / 10 call the flying craft). DAT_05D4A3B8 /
## DAT_05D4A3BC: ticks and flag of the craft's lift; DAT_05D50EC5: seen flag.
var machine_kind := 0
var craft_ticks := 0
var craft_flag := 0
var craft_seen := 0

## DAT_05D4A3A4: a music emitter is playing.
var music_flag := 0

