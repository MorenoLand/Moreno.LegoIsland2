class_name StartCSM
extends Behaviour

## FUN_004B882C (ctor) / FUN_004B840E (update, vtable 0x008B9358), returns 0. A trigger:
## when Pepper stands near one of its waypoints (and the talk prompt state allows it) it
## applies a var change (FUN_004B82E0) that starts the cutscene.
##
## Node: +0x14 waypoint nodes, +0x18 count, +0x19 graph table, +0x1C / +0x20 squared
## near / far range, +0x24 var, +0x28 value, +0x2C kind, +0x2E walk-on flag, +0x2F needs
## visible, +0x30 required game flags, +0x34 var bits to raise when near, +0x38 stage
## (-20 fire, -30 done), +0x3A started, +0x3C nearest step.

var nodes: Array = []
var count := 0
var graph := 0
var range_near := 0.0
var range_far := 0.0
var change_var := 0
var change_value := 0
var change_kind := 0
var walk_on := 0
var needs_visible := 0
var game_flags_needed := 0
var near_bits := 0
var stage := 0
var started := 0
var nearest := -1

var services: ActorServices
var vars


static func from_descriptor(desc: Descriptor, services_in: ActorServices, vars_in) -> StartCSM:
	var b := StartCSM.new()
	b.services = services_in
	b.vars = vars_in
	b.started = 0
	b.stage = desc.s16(0x28)
	b.change_var = desc.u32(0x1C)
	b.change_value = desc.u32(0x20)
	b.change_kind = desc.s16(0x24)
	b.needs_visible = desc.u8(0x2A)
	b.game_flags_needed = desc.u32(0x30)
	if b.game_flags_needed == 0:
		b.near_bits = desc.u32(0x34)
	elif desc.u32(0x34) == 0:
		b.near_bits = 2
	else:
		b.near_bits = desc.u32(0x34)
	b.walk_on = desc.u8(0x26)
	if desc.u8(0x16) == 0:
		if desc.s16(0x14) < 0:
			b.count = -1
		else:
			b.count = 1
			b.nodes = [desc.s16(0x14)]
	else:
		b.count = desc.u8(0x16)
		for i in b.count:
			b.nodes.append(desc.s16(i * 2))
	if b.nodes.is_empty():
		b.graph = 0
		b.range_near = 1.0e38
	else:
		b.graph = desc.u8(0x17)
		b.range_near = desc.f32(0x18) * 8.0
		b.range_near = b.range_near * b.range_near
		b.range_far = desc.f32(0x18) * 8.0
		b.range_far = b.range_far + b.range_far
		b.range_far = b.range_far * b.range_far
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func update(actor, _block: BehaviourBlock, _var_value: int) -> int:
	if stage == -30 or services.scene_active:
		return 0
	if not ((actor.flags & 2) != 0 or needs_visible == 0):
		return 0
	if stage == -20:
		FlagSetterBehaviour.apply_op(vars, change_kind, change_var, change_value, actor, services.talk)
		stage = -30
		return 0
	var v: int = vars.get_var(0x5E)
	var player = services.player
	if started == 0:
		if nodes.is_empty():
			started = 1
		else:
			var best := 1.0e38
			nearest = -1
			for i in count:
				var at = services.waypoint_position(graph, nodes[i])
				var dx: float = at.x - player.x
				var dy: float = at.y - player.y
				var dz: float = at.z - player.z
				var d2 := dz * dz + dy * dy + dx * dx
				if d2 <= best:
					nearest = i
					best = d2
			if game_flags_needed == 0 and near_bits != 0 and best < range_far:
				vars.or_var(0xC, near_bits)
			if range_near < best or (v & 0x1D) == 0:
				return 0
			if (services.talk.game_flags & game_flags_needed) != game_flags_needed:
				vars.or_var(0xC, near_bits)
				return 0
			if game_flags_needed == 0:
				if (v & 8) != 0 and services.talk.list_mode != -1:
					return 0
				started = 1
				if (v & 0x11) == 0:
					vars.or_var(0x5E, 0x1000)
					return 0
			else:
				vars.set_var(0x5E, 0x100)
				started = 1
	elif (v & 0x11) == 0 or (v & 0x401) == 0x401 or services.current_clip(player) == 0x1C:
		return 0
	vars.clear_var(0x5E, 0x1000)
	if stage > -1:
		services.reward_show(stage)
	if walk_on != 0:
		services.walkers.place(player.block.walker, nodes[nearest])
	stage = -20
	return 0
