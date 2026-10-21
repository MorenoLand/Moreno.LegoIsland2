class_name BotEndBehaviour
extends Behaviour

## FUN_004CD15C (ctor) / FUN_004CCFC9 (update, vtable 0x008B9DB0). Registered by
## FUN_0045D07C / FUN_0045D13F next to every BrickBot. Ctor: if the tag var has no 0x4000
## (defeated) mark, clear the var; timer = 6.0. Update: re-roll the bot's face every 6
## ticks; when its walker has arrived and its target is not yet engaged (0x2000000 clear)
## hand the target to the first BrickBot of the block and set tag bit 8. Returns 0.

const TIMER_RESET := 6.0

var timer := TIMER_RESET
var services: ActorServices
var vars


static func from_descriptor(_desc: Descriptor, services_in: ActorServices, vars_in, tag_id: int) -> BotEndBehaviour:
	var b := BotEndBehaviour.new()
	b.services = services_in
	b.vars = vars_in
	if (vars_in.get_var(tag_id) & 0x4000) == 0:
		vars_in.set_var(tag_id, 0)
	return b


func update(actor, block: BehaviourBlock, _var_value: int) -> int:
	timer -= 1.0
	if timer <= 0.0:
		services.set_face(actor, int(randf() * 6.0))
		timer = TIMER_RESET
	if services.walker_blocked(actor):
		var target = services.walker_ahead(actor)
		if target != null and target.block != null and (target.block.flags & 0x2000000) == 0:
			var node := block.head
			while node != null:
				if node is BrickBot and node.mask != 1:
					node.target = target
					vars.or_var(tag, 8)
					break
				node = node.next
	return 0
