class_name Behaviour
extends RefCounted

## One entry of an actor's behaviour list. Layout from FUN_0086D182 / FUN_0086D343
## (pseudocode chunk_0023): +0 tag (game var id), +4 vtable (slot 0 = update),
## +8 status, +0xC short mask, +0xE short value, +0x10 next in list.
## The behaviour runs while (var[tag] & mask) == value (FUN_0041ABFE).

const STATUS_NEW := -2

var tag := 0
var mask := 0
var value := 0
var status := STATUS_NEW
var next: Behaviour = null


## Update slot (vtable +0). Returns the dispatcher result: 0 = nothing,
## 1 = this behaviour owns the actor this tick, 2 = ran, 3 = ran and asks for the
## current behaviour to be re-run too. The default is the null update (result 0).
func update(_actor, _block: BehaviourBlock, _var_value: int) -> int:
	return 0


## Slot 1 (vtable +4), called by the post pass FUN_0041AF55 for every behaviour that ran
## this frame (draw/notify hook). Default: no function.
func has_post() -> bool:
	return false


func post(_actor) -> void:
	pass


## True when the vtable slot 0 is empty (the dispatcher then treats it as result 1).
func has_update() -> bool:
	return true
