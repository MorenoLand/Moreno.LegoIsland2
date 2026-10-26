class_name ZoneProgram
extends RefCounted

## What one zone adds to the engine bridge: which record is Pepper, the behaviours its set-up
## routine attaches to the records (as the exe's per-zone builder does), the records another
## system still moves, and a per-tick hook. The island keeps its own code inside EngineBridge.

var player_record := 0
## True when the zone's own behaviours move Pepper (the dive's swimmer): the island's walk
## controller stays off and the player node follows the record.
var drives_player := false
## True when the engine's records own Pepper's pose and the camera all the time (the park): the
## island's walk controller is not used and the player node follows the record.
var engine_pepper := false


func build(_bridge) -> void:
	pass


func legacy(_index: int) -> bool:
	return false


## Whether the update pass and the post pass of the behaviours run this tick.
func running() -> bool:
	return true


## Runs before the behaviours each tick (the exe's per-frame code ahead of FUN_0041ABFE).
func pre_tick() -> void:
	pass


func tick() -> void:
	pass


## The eye and target of a camera the program drives (game coordinates), or {} for the
## island's own camera.
func camera_pose() -> Dictionary:
	return {}
