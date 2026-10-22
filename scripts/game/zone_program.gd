class_name ZoneProgram
extends RefCounted

## What one zone adds to the engine bridge: which record is Pepper, the behaviours its set-up
## routine attaches to the records (as the exe's per-zone builder does), the records another
## system still moves, and a per-tick hook. The island keeps its own code inside EngineBridge.

var player_record := 0
## True when the zone's own behaviours move Pepper (the dive's swimmer): the island's walk
## controller stays off and the player node follows the record.
var drives_player := false


func build(_bridge) -> void:
	pass


func legacy(_index: int) -> bool:
	return false


## Runs before the behaviours each tick (the exe's per-frame code ahead of FUN_0041ABFE).
func pre_tick() -> void:
	pass


func tick() -> void:
	pass


## The eye and target of a camera the program drives (game coordinates), or {} for the
## island's own camera.
func camera_pose() -> Dictionary:
	return {}
