class_name BehaviourBlock
extends RefCounted

## The per-actor behaviour block (record + 0x5C, 0x68 bytes, FUN_0086D47C).
## head +0, current +4, active mask +8, flags +0xC (starts 6: bit 1 = runs,
## bit 2 = a current behaviour may be kept), +0x18 squared XZ distance to Pepper
## (FUN_0041AAFF), +0x1C range 512.0.

const FLAG_RUNS := 2
const FLAG_KEEP_CURRENT := 4

var head: Behaviour = null
var current: Behaviour = null
var active_mask := 0
var flags := 6
var distance_squared := 0.0
var range_limit := 512.0
var slots := 0
## Walker slot handle (1-based) stored at +0x10 by the walker constructors (FUN_00447A0F).
var walker := 0
## +0x14: facing bits set by the talk behaviour (2 = left, 4 / 8 = side), 0x10 = sticky.
var look_flags := 0
## The actor's move request written by FUN_008765F4 and resolved by the pass FUN_00876813
## (GameServices.resolve_hits): +0x20 origin, +0x38 push, +0x44 blend, +0x48 rate (sweep radius),
## +0x4C kind (0 = no request), +0x5C flags, +0x60 throttle counter, +0x64 hold (what the pass found:
## 0 nothing, 1 ground, a record when something was struck).
var hint_origin := Vector3.ZERO
var hint_target := Vector3.ZERO
var hint_blend := 0.0
var hint_rate := 0.0
var hint_mode := 0
var hint_flags := 0
var hint_distance := 0.0
var hint_hold := 0
var hint_up := Vector3.ZERO
## DAT_009CCAFC as seen by this block's behaviours (set by BehaviourSystem.tick).
var frame_counter := 0


## FUN_0086D507: the slot count stored at +0xC (the same field as the flags).
func set_flags(value: int) -> void:
	flags = value


## FUN_0086D182: insert a behaviour at `index` (0 = replace the head of the list, as the
## constructor path does, otherwise insert before the index-th node).
func add(behaviour: Behaviour, index: int = 0) -> Behaviour:
	if index == 0:
		behaviour.next = null
		head = behaviour
		return behaviour
	var position := 1
	var previous := head
	var node := head.next if head != null else null
	while node != null:
		if position == index:
			behaviour.next = node
			previous.next = behaviour
			return behaviour
		previous = node
		node = node.next
		position += 1
	if previous == null:
		head = behaviour
	else:
		previous.next = behaviour
	return behaviour


## FUN_008765F4: fill in the camera hint (the caller passes the origin and target
## offsets, a mode and extra flags).
func set_hint(origin: Vector3, target: Vector3, mode: int, extra_flags: int) -> void:
	hint_hold = 0
	hint_blend = 0.0
	hint_rate = 0.10000000149011612
	hint_target = target
	hint_origin = origin
	hint_mode = mode
	hint_flags = extra_flags | 0x1003
	if hint_distance < 0.0:
		hint_distance = 32.0


## FUN_00876719: the full form of the hint (also sets the blend, rate and an up vector).
func set_hint_full(origin: Vector3, target: Vector3, up: Vector3, mode: int, rate: float, blend: float, flags_in: int) -> void:
	hint_hold = 0
	hint_blend = blend
	hint_rate = rate
	hint_target = target
	hint_origin = origin
	hint_mode = mode
	hint_flags = flags_in
	if hint_distance < 0.0:
		hint_distance = 32.0
	if (hint_flags & 4) != 0:
		hint_up = up

