class_name StubBehaviour
extends Behaviour

## A behaviour whose constructor is not ported yet. It keeps the constructor address
## and the descriptor it was registered with, so the act builders can run whole and
## the real behaviour can replace the stub later without touching the builders.

var ctor := 0
var descriptor: Descriptor
var slot := 0


func update(_actor, _block, _var_value: int) -> int:
	return 0
