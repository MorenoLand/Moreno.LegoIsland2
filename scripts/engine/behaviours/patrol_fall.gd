class_name PatrolFall
extends Behaviour

## FUN_004D84A3 (ctor) / FUN_004D7FD0 (update, vtable 0x008BA530) / FUN_004D82A5 (post),
## update returns 1. A patrol between two path nodes (a walker told to go to one node and
## then the other): with its var bit 2 set it walks the pair, while bit 2 is clear it
## watches a target actor and warns the target's behaviour when it comes close. The post
## plays the fall clip when the head behaviour says the actor is in the air.
##
## Node: +0x14 / +0x18 the two nodes, +0x1C target record, +0x20 height, +0x24 fall timer,
## +0x28 phase (0 first node, 1 second), +0x2A reached, +0x2B falling.

const TARGET_NEAR := 576.0
const HEIGHT_LIMIT := 96.0
const FALL_DROP := 0.03999999910593033

var nodes := [0, 0]
var target = null
var height := 0.0
var fall_timer := 0.0
var phase := 0
var reached := 0
var falling := 0

var services: ActorServices
var vars


static func from_descriptor(desc: Descriptor, services_in: ActorServices, vars_in) -> PatrolFall:
	var b := PatrolFall.new()
	b.services = services_in
	b.vars = vars_in
	b.nodes = [desc.s32(0), desc.s32(4)]
	b.target = desc.refs.get(8, null)
	b.phase = 0
	b.reached = 0
	b.falling = 0
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func _goto_phase(handle: int) -> void:
	services.walkers.goal_to_alt(handle, services.waypoint_position(1, nodes[phase]))


func update(actor, block: BehaviourBlock, var_value: int) -> int:
	var w := services.walkers
	var handle := block.walker
	if (var_value & 2) == 0:
		if actor.y < HEIGHT_LIMIT and target != null:
			var d := Vector3(target.x - actor.x, target.y - actor.y, target.z - actor.z)
			if d.z * d.z + d.y * d.y + d.x * d.x < TARGET_NEAR:
				if target.block != null and target.block.head != null and target.block.head.tag >= 3:
					vars.or_var(target.block.head.tag, 0x20)
		return 1
	if status != block.frame_counter:
		_goto_phase(handle)
		services.set_clip(actor, 0x118, 0.0)
		fall_timer = 0.0
		falling = 0
	var step := w.step(handle, Vector3(actor.x, actor.y, actor.z), actor.yaw)
	var result: int = step[0]
	if result == -1 or reached != 0:
		if phase == 1:
			vars.clear_var(tag, 2)
			w.place(handle, nodes[phase])
			phase = 0
			falling = 0
			reached = 0
		else:
			phase = 1
			_goto_phase(handle)
			falling = 0
			reached = 0
	else:
		actor.yaw = step[1]
		services.set_matrix_at(actor, step[2])
		block.look_flags |= 0x10
	block.hint_origin = Vector3(actor.field_f(0x2C) * -1.0, 4.0, actor.field_f(0x34) * -1.0)
	height = actor.y
	return 1


func has_post() -> bool:
	return true


func post(actor) -> void:
	var clip := services.current_clip(actor)
	var head: Behaviour = actor.block.head
	var airborne = head.get("airborne") if head != null else 0
	if (airborne != null and int(airborne) != 0) or (falling != 0 and FALL_DROP < height - actor.y):
		fall_timer = 0.0
		falling = 1
		if clip == 0x95:
			services.clip_finished(actor, 1.0)
		else:
			services.set_clip(actor, 0x95, 0.0)
	else:
		fall_timer = 1.0 * 1.0 + fall_timer
		if clip == 0x118 or fall_timer <= 20.0:
			services.clip_finished(actor, 1.0)
		elif falling == 0:
			services.set_clip(actor, 0x118, 0.0)
		else:
			falling = 0
			reached = 1
			vars.or_var(tag, 0x11000)
