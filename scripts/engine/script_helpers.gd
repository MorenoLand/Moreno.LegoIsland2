class_name ScriptHelpers
extends RefCounted

## 1:1 port of the island script helper functions FUN_0045C6A0 .. FUN_0045D313
## (pseudocode chunk_0008 lines 942..1440). Each helper fills the scratch descriptor
## and registers one or two behaviours on the current actor. Byte offsets were derived
## from the pseudocode with each function's own element size (undefined2* / undefined4*).

const C_TALK := 0x0087D84E       # FUN_0087D84E conversation node
const C_TURN2PEP := 0x004CA5C9   # FUN_004CA5C9 Turn2Pep.c
const C_HUMAN1 := 0x00459290     # FUN_00459290 Human1.c walker
const C_MEETPEP := 0x004CAD75    # FUN_004CAD75 MeetPepp.c
const C_FLAG := 0x004CB3F9       # FUN_004CB3F9 flag setter
const C_BRICKBOT := 0x004CC3D5   # FUN_004CC3D5 BrickBot.c
const C_BOTEND := 0x004CD15C     # FUN_004CD15C
const C_STEP274 := 0x004D0510    # FUN_004D0510
const C_STEP313 := 0x004D0B35    # FUN_004D0B35
const BLOCK_SLOTS_FLAGS := 0x83

var ctx: ScriptContext
## FUN_0086D406 / DAT_009747D8: blocks are only created while the script system is on.
var blocks_enabled := true


func _init(context: ScriptContext) -> void:
	ctx = context


func _new_block(actor) -> void:
	if blocks_enabled:
		actor.block = BehaviourBlock.new()


## FUN_0045C6A0(actor, tag, kind, tail)
func begin(actor, tag: int, kind: int, tail: int) -> void:
	ctx.actor = actor
	ctx.tag = tag
	ctx.kind = kind
	ctx.tail = tail
	_new_block(actor)
	ctx.slot = 0


## FUN_0045C6E7(actor)
func begin_slots(actor) -> void:
	ctx.actor = actor
	_new_block(actor)
	ctx.slot = 0
	actor.block.set_flags(BLOCK_SLOTS_FLAGS)


func _reg(ctor: int, tag: int, mask: int, value: int) -> void:
	var slot := ctx.slot
	ctx.slot += 1
	ctx.register(ctor, ctx.scratch, slot, tag, mask, value)


func _talk_base(first: float, second: float, link: int, p1: int, p2: int, p3: int) -> void:
	var d := ctx.scratch
	d.memset(0x30)
	d.set_u16(40, ctx.tail)
	d.set_u32(0, ctx.kind)
	d.set_f32(4, first)
	d.set_f32(8, second)
	d.set_u16(12, 1 if link != -1 else 0)
	d.set_u32(16, p1)
	d.set_u32(20, p2)
	d.set_u32(24, 0)
	d.set_u8(28, 0x41)
	d.set_u8(0x1E, 0x43)
	d.set_u32(32, link)
	d.set_u32(36, p3)


## FUN_0045C72B(a, b, c, link): conversation node with the negative trigger radius.
func talk_negative(p1: int, p2: int, p3: int, link: int) -> void:
	ctx.alternate = 0
	_talk_base(-1.0, 7.0, link, p1, p2, p3)
	_reg(C_TALK, ctx.tag, 0, 0)


## FUN_0045C838(a, b, c, link): conversation node.
func talk(p1: int, p2: int, p3: int, link: int) -> void:
	ctx.alternate = 0
	_talk_base(1.0, 4.0, link, p1, p2, p3)
	_reg(C_TALK, ctx.tag, 0, 0)


## FUN_0045C945(a, b, c, link): conversation node, alternate speech set (flag 1).
func talk_alternate(p1: int, p2: int, p3: int, link: int) -> void:
	ctx.alternate = 1
	_talk_base(1.0, 4.0, link, p1, p2, p3)
	ctx.scratch.set_u16(44, 3)
	ctx.scratch.set_u16(0x2A, 0xB0)
	_reg(C_TALK, ctx.tag, 0, 0)


## FUN_0045CA69(notice, idle, turn, flags): Turn2Pep.c with Pepper's record as target.
func turn_to_pepper(p1: int, p2: int, p3: int, flags: int) -> void:
	var d := ctx.scratch
	d.memset(0x18)
	d.set_u32(0, p1)
	d.set_u32(4, p2)
	d.set_u32(8, p3)
	d.set_u32(16, ctx.player if ctx.player != null else 0x680)  # record 16 (Pepper)
	_reg(C_TURN2PEP, ctx.tag, flags | 0x100, flags | 0x100)


## FUN_0045CB15(count, idle): multi-entry walker header (entries filled by the caller).
func walker_header(count: int, idle: int) -> void:
	var d := ctx.scratch
	d.memset(0x5C)
	d.set_f32(0x58, ctx.walker_speed)
	d.set_u8(0x50, count)
	d.set_u16(0x52, idle)
	_reg(C_HUMAN1, ctx.tag, 0, 0)


func _walker_entry(kind_byte: int, nodes: Array, second: int, mask: int, value: int, two_nodes: bool) -> void:
	var d := ctx.scratch
	d.memset(0x5C)
	d.set_f32(0x58, ctx.walker_speed)
	d.set_u8(0x50, 2 if two_nodes else 1)
	d.set_u16(0, nodes[0])
	if two_nodes:
		d.set_u16(2, nodes[1])
	else:
		d.set_u16(0x14, second)
		d.set_u8(0x3C, kind_byte)
	d.set_u16(0x52, ctx.idle_clip)
	_reg(C_HUMAN1, ctx.tag, mask, value)


## FUN_0045CBA8(a, b, mask, value): patrol between two nodes.
func walker_pair(a: int, b: int, mask: int, value: int) -> void:
	_walker_entry(0, [a, b], 0, mask, value, true)


## FUN_0045CC5B(node, second, mask, value): single node, kind 2.
func walker_single(node: int, second: int, mask: int, value: int) -> void:
	_walker_entry(2, [node], second, mask, value, false)


## FUN_0045CD18(node, second, mask, value): single node, kind 4.
func walker_hide(node: int, second: int, mask: int, value: int) -> void:
	_walker_entry(4, [node], second, mask, value, false)


## FUN_0045CDD5(clip, mask, link, delay): speech line (MeetPepp.c).
func speech(clip: int, mask: int, link: int, delay: int) -> void:
	var d := ctx.scratch
	d.memset(0x1C)
	d.set_u16(0, 0x131 if ctx.alternate == 0 else 0x8A)
	d.set_u16(2, 0x43)
	d.set_u16(4, 0x89)
	d.set_u16(6, 0xFFFF)
	d.set_u16(12, delay)
	d.set_u16(14, 1)
	d.set_u16(20, clip)
	d.set_u16(0x1A, 0x96)
	if link == 0:
		d.set_u16(22, 2)
		d.set_u16(24, 0)
	else:
		d.set_u16(22, 0x10)
		d.set_u16(24, link)
	_reg(C_MEETPEP, ctx.tag, mask, mask)


## FUN_0045CEF4(clip, next_record, mask, value): chain to the next actor (MeetPepp.c).
func chain(clip: int, next_actor_pointer, mask: int, value: int) -> void:
	var d := ctx.scratch
	d.memset(0x1C)
	d.set_u16(2, clip)
	d.set_u16(0x1A, 0xFFFF)
	d.set_u16(6, 0xFFFD)
	d.set_u32(8, next_actor_pointer)
	_reg(C_MEETPEP, ctx.tag, mask, value)


func _flag_entry(var_id: int, mask: int) -> void:
	var d := ctx.scratch
	d.set_u32(0, var_id)
	d.set_u16(4, 0)
	d.set_u16(8, 0)
	_reg(C_FLAG, ctx.tag, mask, mask)


## FUN_0045CF96(v)
func flag_pair(v: int) -> void:
	_flag_entry(0x85, 2)
	_flag_entry(v, 4)


## FUN_0045D07C(v)
func flag_clear(v: int) -> void:
	_flag_entry(v, 4)
	_reg(C_BOTEND, ctx.tag, 0, 0)


## FUN_0045D13F(v): BrickBot controller and its end of fight flags.
func bot(v: int) -> void:
	var d := ctx.scratch
	d.memset(0xC)
	d.set_u32(0, 0)
	d.set_f32(4, 0.125)
	_reg(C_BRICKBOT, ctx.tag, 8, 8)
	_flag_entry(v, 4)
	_reg(C_BOTEND, ctx.tag, 0, 0)


func _five(ctor: int, a: int, b: int, c: int, e: int, f: int) -> void:
	var d := ctx.scratch
	d.memset(0x14)
	d.set_u32(0, a)
	d.set_u32(4, b)
	d.set_u32(8, c)
	d.set_u32(12, e)
	d.set_u32(16, f)
	var slot := ctx.slot
	ctx.slot += 1
	ctx.register(ctor, d, slot, 2, 1, 1)


## FUN_0045D274(a, b, c, d, e): raw 32-bit arguments as the builders push them.
func step274(a: int, b: int, c: int, e: int, f: int) -> void:
	_five(C_STEP274, a, b, c, e, f)


## FUN_0045D313(a, b, c, d, e)
func step313(a: int, b: int, c: int, e: int, f: int) -> void:
	_five(C_STEP313, a, b, c, e, f)


## FUN_0045D3B2(record): places Pepper at the entry point of the zone he came from
## (see AGENTS.md). Handled by the glue layer; the request is recorded here.
func pepper_start(record) -> void:
	ctx.pepper_start_record = record


## FUN_004B9290(v): the defeat of a BrickBot (BotDefeat) and its music emitter.
func defeat(v: int) -> void:
	var d := ctx.scratch
	d.memset(4)
	d.set_u32(0, v)
	var slot := ctx.slot
	ctx.slot += 1
	ctx.register(0x004CCE41, d, slot, ctx.tag, 0, 0)
	d.memset(1)
	slot = ctx.slot
	ctx.slot += 1
	ctx.register(0x004D14A6, d, slot, ctx.tag, 0, 0)

