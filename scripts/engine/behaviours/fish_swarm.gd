class_name FishSwarm
extends Behaviour

## FUN_00522562 (ctor) / FUN_005223D5 (update, vtable 0x008C5C00, returns 2). A fish of the dive
## swims round a ring of route nodes and steers to the next one (FUN_00521D32), moving on when it
## is within 3 units.
##
## Descriptor: +0 group tag of the ring, +4 which neighbour of the first node closes it, +8 the
## fraction of the ring it starts at, +12..+60 the steering block copied to the node (its first nine
## entries are cleared again by the constructor).
## Node: +0x18 steering block (13 floats), +0x4C position copy, +0x58 route index, +0x6C route,
## +0xE4 ring length.

const REACH_SQUARED := 9.0

var steering := DiveSteering.new()
var route: Array = []
var index := 0
var group := 0

var services: ActorServices
var graph: DiveGraph


static func from_descriptor(desc: Descriptor, services_in: ActorServices, graph_in: DiveGraph, actor) -> FishSwarm:
	var b := FishSwarm.new()
	b.services = services_in
	b.graph = graph_in
	b.group = desc.s32(0)
	var start := graph_in.first_with_tag(b.group)
	var ring := graph_in.ring_route(start, desc.s32(4), desc.f32(8))
	b.route = ring["route"]
	b.index = ring["index"]
	var at := graph_in.positions[ring["node"]]
	actor.x = at.x
	actor.y = at.y
	actor.z = at.z
	b.steering.load_block(desc, 12)
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func update(actor, _block: BehaviourBlock, _var_value: int) -> int:
	var here := Vector3(actor.x, actor.y, actor.z)
	var target: Vector3 = graph.positions[route[index]]
	if here.distance_squared_to(target) < REACH_SQUARED:
		index += 1
		if index == route.size():
			index = 0
	steering.steer(actor, target, 1.0, services)
	return 2
