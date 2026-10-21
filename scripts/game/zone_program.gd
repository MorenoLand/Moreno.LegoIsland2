class_name ZoneProgram
extends RefCounted

## What one zone adds to the engine bridge: which record is Pepper, the behaviours its set-up
## routine attaches to the records (as the exe's per-zone builder does), the records another
## system still moves, and a per-tick hook. The island keeps its own code inside EngineBridge.

var player_record := 0


func build(_bridge) -> void:
	pass


func legacy(_index: int) -> bool:
	return false


func tick() -> void:
	pass
