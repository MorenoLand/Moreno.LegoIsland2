class_name ScriptContext
extends RefCounted

## The shared state of the island script builders (pseudocode chunk_0008 0x45C6A0..):
## scratch descriptor DAT_05D4A338, current actor DAT_05D4A34C, slot counter
## DAT_05D4A348, builder parameters DAT_05D4A334 (the tag var), DAT_05D4A340 (kind),
## DAT_05D4A33C (tail), the alternate-talk flag DAT_05D4A344 and the walker defaults
## DAT_008AA32C (idle clip, 0x73) / DAT_008AA330 (speed, 1.0).

var scratch := Descriptor.new()
var actor = null
var slot := 0
var tag := 0
var kind := 0
var tail := 0
var alternate := 0
var idle_clip := 0x73
var walker_speed := 1.0
var player = null
## ctor address -> Callable(descriptor, slot, ctx, tag) -> Behaviour, filled by
## the behaviour ports. Anything missing becomes a StubBehaviour.
var services = null
var factories := {}
var registered := 0
var state := 0
var pepper_start_record = null


func register(ctor: int, desc: Descriptor, slot_index: int, behaviour_tag: int, mask: int, value: int) -> Behaviour:
	var behaviour: Behaviour
	if factories.has(ctor):
		behaviour = (factories[ctor] as Callable).call(desc.copy(), slot_index, self, behaviour_tag)
	else:
		var stub := StubBehaviour.new()
		stub.ctor = ctor
		stub.descriptor = desc.copy()
		stub.slot = slot_index
		behaviour = stub
	behaviour.tag = behaviour_tag
	behaviour.mask = mask & 0xFFFF
	behaviour.value = value & 0xFFFF
	if behaviour.has_method("configure"):
		behaviour.call("configure", mask & 0xFFFF, value & 0xFFFF)
	if "forced_tag" in behaviour and behaviour.forced_tag >= 0:
		behaviour.tag = behaviour.forced_tag
	if actor != null and actor.block != null:
		actor.block.add(behaviour, slot_index)
	registered += 1
	return behaviour
