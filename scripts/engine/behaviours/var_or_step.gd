class_name VarOrStep
extends Behaviour

## FUN_004CAF83 (ctor) / FUN_004CAEC2 (update, vtable 0x008B9C60): once armed, ORs
## `value` into game var `var_id`; when the armed flag is 1 it disarms (-1).
## Node: +0x14 amount, +0x18 var id, +0x1C armed flag. Update returns 0 (xor eax,eax).

var amount := 0
var var_id := 0
var armed := 0
var vars


static func from_descriptor(desc: Descriptor, vars_in) -> VarOrStep:
	var b := VarOrStep.new()
	b.amount = desc.s32(0)
	b.var_id = desc.s32(4)
	b.armed = desc.s32(8)
	b.vars = vars_in
	return b


func update(_actor, _block, _var_value: int) -> int:
	if armed != -1:
		vars.or_var(var_id, amount)
		if armed == 1:
			armed = -1
	return 0
