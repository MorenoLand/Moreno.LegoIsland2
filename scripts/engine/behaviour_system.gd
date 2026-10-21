class_name BehaviourSystem
extends RefCounted

## FUN_0041ABFE: the per-frame behaviour dispatcher. `actors` is the record array
## (each element has `.block: BehaviourBlock` or null, and `.x`/`.z` in game
## coordinates); `player` is the Pepper record (DAT_009CCB00). `vars` supplies the game
## variables (FUN_00411495 = get).

var paused := false
## DAT_009CCAFC: frame counter. A behaviour whose status equals it ran last frame.
var frame := 0


static func xz_distance_squared(actor, player) -> float:
	var dx: float = player.x - actor.x
	var dz: float = player.z - actor.z
	return dx * dx + dz * dz


func tick(actors: Array, player, vars) -> void:
	if paused:
		return
	var running: Behaviour = null
	for actor in actors:
		var block: BehaviourBlock = actor.block
		if block == null or (block.flags & BehaviourBlock.FLAG_RUNS) == 0:
			continue
		block.distance_squared = xz_distance_squared(actor, player)
		block.frame_counter = frame
		block.active_mask = 0
		var result := 0
		if block.current == null:
			result = 0
		elif (block.flags & BehaviourBlock.FLAG_KEEP_CURRENT) == 0:
			result = 0
			block.current = null
		else:
			var cur := block.current
			var value: int = vars.get_var(cur.tag)
			if (value & cur.mask) == cur.value:
				if not cur.has_update():
					result = 1
				else:
					result = cur.update(actor, block, value)
					running = cur
			else:
				result = 0
				block.current = null
		if result == 1:
			continue
		var bit := 1
		var node := block.head
		while node != null:
			if running == node:
				block.active_mask |= bit
			else:
				var node_value: int = vars.get_var(node.tag)
				if (node_value & node.mask) == node.value:
					if node.has_update():
						result = node.update(actor, block, node_value)
					if result == 3:
						block.active_mask |= bit
						if block.current != null:
							var rerun_bit := 1
							var other := block.head
							while other != null and other != block.current:
								rerun_bit <<= 1
								other = other.next
							if other != null:
								var other_value: int = vars.get_var(other.tag)
								if (other_value & other.mask) == other.value and other.has_update():
									result = other.update(actor, block, other_value)
									if result != 0:
										block.active_mask |= rerun_bit
										if result == 1:
											break
					else:
						if result == 1:
							block.active_mask |= bit
							break
						if result == 2:
							block.active_mask |= bit
			bit <<= 1
			node = node.next


## FUN_0041AF55: after the update pass, run the post hook of every behaviour that was
## active this frame and stamp its status with frame + 1; then advance the counter.
func post_pass(actors: Array) -> void:
	if paused:
		return
	var stamp := frame + 1
	for actor in actors:
		var block: BehaviourBlock = actor.block
		if block == null or (block.flags & BehaviourBlock.FLAG_RUNS) == 0:
			continue
		if block.active_mask == 0:
			if block.current != null:
				if block.current.has_post():
					block.current.post(actor)
				block.current.status = stamp
		else:
			var bit := 1
			var node := block.head
			while node != null and bit <= block.active_mask:
				if (block.active_mask & bit) != 0:
					if node.has_post():
						node.post(actor)
					node.status = stamp
				node = node.next
				bit <<= 1
	frame += 1
