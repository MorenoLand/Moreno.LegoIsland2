extends RefCounted

## The island story state machine.
##
## CONFIRMED from `LEGO Island 2.exe` (sha256 117c111d8de6ce6179c70b2ff88f74766a3417b9997e83b186e1c56fca873198):
## REA reads of FUN_00404a40 / FUN_00404a96 / FUN_00404ae3 / FUN_00404b52 /
## FUN_00404b87 / FUN_00404ba7 / FUN_00404cb4 / FUN_00404d69, plus a direct byte
## read of the table: file offset 0x48f640 == VA 0x0088f640 (RVA == file offset
## in this image's mapping for .data), 72 rows of 8 bytes, terminated by
## 0xffffffff 0xffffffff at 0x48f9e0 (verified in the shipped exe).
##
## Row = [zone:int16, var:int16, mask:int16, value:int16]. Every row uses mask
## 0x7fff except row 30 (mask 2) and row 34 (mask 1).
##
##   * `var 0x58` is the story state, 0..71.
##   * FUN_00404b87() = `zone_of`: table[var 0x58].zone. That is the zone the
##     main loop FUN_00404d69 loads.
##   * FUN_00404a40() = `done`: (var[row.var] & row.mask) == row.value, "the
##     current objective is finished". Its only caller is the VM, so in the exe
##     a level script decides when to ask; the port polls it once a frame.
##   * FUN_00404b52() = `advance`: var 0x58 += 1, plus a snapshot of the
##     objective values into DAT_00975e94. The port does not keep the snapshot
##     (nothing rewinds mid-objective).
##   * FUN_00404ba7(state) = `set_state`, also the exe's own debug skip
##     (FUN_004015cc / FUN_0041f7e5 case 1 call it with var 0x58 + 1): write
##     table[state].var = value FIRST - the state is born "done" - then
##     var 0x58 = state and var 5 = table[state].zone.
##   * FUN_00404a96() = step back one and restore the value snapshotted on
##     entry. `jump(game, -1)` decrements and moves var 5 without the restore.
##   * FUN_00404cb4 (called by the level functions) is the "level complete"
##     check: when var 0x59 (the next zone) equals zone_of(state) it either
##     rewinds (a p2/p3 argument is 0) or advances. The island's own exit path
##     returns FUN_00411495(5) - the same zone - which is how a chapter change
##     inside the island reloads it.
##
## Zone index -> archive, CONFIRMED from the archive string each zone function
## passes to FUN_0041c50d. 2, 31, 32 and 33 all name z02LGI: the island's
## chapter acts are four zone numbers over one archive (FUN_0044da05 dispatches
## the act setup from var 0x58: <7 act 0, <0x1e act 1, <0x34 act 2, <0x3d act 3,
## else act 4). Zones 22 and 23 do not appear in the table.

const VAR_STATE := 0x58
const VAR_ZONE := 5

## state: [zone, var, mask, value] - all 72 rows of DAT_0088f640.
const TABLE := [
	[0, 2, 0x7FFF, 1],          # 0  front end
	[1, 250, 0x7FFF, 1],        # 1  park
	[2, 277, 0x7FFF, 16],       # 2  island act 0
	[2, 79, 0x7FFF, 0],         # 3  island
	[2, 303, 0x7FFF, 1],        # 4  island
	[2, 277, 0x7FFF, 1],        # 5  island
	[2, 81, 0x7FFF, 1],         # 6  island
	[31, 165, 0x7FFF, 4],       # 7  island act 1
	[31, 142, 0x7FFF, 15],      # 8  island
	[31, 5, 0x7FFF, 5],         # 9  island
	[5, 83, 0x7FFF, 1],         # 10 z05WAB
	[31, 277, 0x7FFF, 256],     # 11 island
	[31, 277, 0x7FFF, 512],     # 12 island
	[31, 94, 0x7FFF, 8],        # 13 island
	[31, 302, 0x7FFF, 1],       # 14 island
	[6, 94, 0x7FFF, 1],         # 15 z07CSI
	[6, 86, 0x7FFF, 12],        # 16 z07CSI
	[6, 86, 0x7FFF, 2],         # 17 z07CSI
	[7, 83, 0x7FFF, 1],         # 18 z08BKD
	[6, 86, 0x7FFF, 17],        # 19 z07CSI
	[6, 86, 0x7FFF, 2],         # 20 z07CSI
	[6, 86, 0x7FFF, 3],         # 21 z07CSI
	[6, 86, 0x7FFF, 4],         # 22 z07CSI
	[8, 83, 0x7FFF, 1],         # 23 z09JST
	[6, 86, 0x7FFF, 5],         # 24 z07CSI
	[6, 86, 0x7FFF, 6],         # 25 z07CSI
	[9, 83, 0x7FFF, 1],         # 26 z10RGB
	[6, 86, 0x7FFF, 37],        # 27 z07CSI
	[6, 94, 0x7FFF, 8],         # 28 z07CSI
	[6, 5, 0x7FFF, 32],         # 29 z07CSI (the objective is to be in zone 32)
	[32, 165, 2, 2],            # 30 island act 2
	[32, 277, 0x7FFF, 2],       # 31 island
	[32, 281, 0x7FFF, 2],       # 32 island
	[10, 5, 0x7FFF, 11],        # 33 z13CAI (the objective is to be in zone 11)
	[11, 257, 1, 1],            # 34 z14OSD
	[12, 83, 0x7FFF, 1],        # 35 z15SSH
	[13, 254, 0x7FFF, 1],       # 36 z16PYA
	[14, 83, 0x7FFF, 1],        # 37 z17WAS
	[13, 255, 0x7FFF, 1],       # 38 z16PYA
	[15, 83, 0x7FFF, 1],        # 39 z18MMP
	[13, 256, 0x7FFF, 1],       # 40 z16PYA
	[16, 83, 0x7FFF, 1],        # 41 z20DSP
	[17, 252, 0x7FFF, 1],       # 42 z21FSH
	[17, 83, 0x7FFF, 1],        # 43 z21FSH
	[17, 252, 0x7FFF, 2],       # 44 z21FSH
	[11, 259, 0x7FFF, 7],       # 45 z14OSD
	[18, 83, 0x7FFF, 1],        # 46 z22BIP
	[19, 257, 0x7FFF, 2],       # 47 z23DIP
	[20, 83, 0x7FFF, 1],        # 48 z27TRX
	[21, 83, 0x7FFF, 1],        # 49 z28HAT
	[19, 257, 0x7FFF, 1],       # 50 z23DIP
	[10, 250, 0x7FFF, 1],       # 51 z13CAI
	[33, 94, 0x7FFF, 1],        # 52 island act 3
	[33, 277, 0x7FFF, 4],       # 53 island
	[33, 38, 0x7FFF, 15],       # 54 island
	[33, 277, 0x7FFF, 12],      # 55 island
	[33, 142, 0x7FFF, 15],      # 56 island
	[33, 277, 0x7FFF, 7],       # 57 island
	[33, 284, 0x7FFF, 1],       # 58 island
	[24, 83, 0x7FFF, 1],        # 59 z36CNT
	[25, 83, 0x7FFF, 1],        # 60 z38PAR
	[2, 284, 0x7FFF, 2],        # 61 island
	[26, 83, 0x7FFF, 1],        # 62 z39ASB
	[30, 83, 0x7FFF, 1],        # 63 z40aPO
	[27, 256, 0x7FFF, 1],       # 64 z40OGL
	[28, 83, 0x7FFF, 1],        # 65 z41MAP
	[27, 257, 0x7FFF, 1],       # 66 z40OGL
	[29, 83, 0x7FFF, 1],        # 67 z42BRP
	[2, 1, 0x7FFF, 1],          # 68 island
	[3, 1, 0x7FFF, 1],          # 69 house
	[4, 1, 0x7FFF, 1],          # 70 z04IFC
	[34, 1, 0x7FFF, 1],         # 71 z50LTC
]

const ZONE_ARCHIVE := {
	0: "z60FRE",
	1: "z01BPK",
	2: "z02LGI",
	3: "z03PPH",
	4: "z04IFC",
	5: "z05WAB",
	6: "z07CSI",
	7: "z08BKD",
	8: "z09JST",
	9: "z10RGB",
	10: "z13CAI",
	11: "z14OSD",
	12: "z15SSH",
	13: "z16PYA",
	14: "z17WAS",
	15: "z18MMP",
	16: "z20DSP",
	17: "z21FSH",
	18: "z22BIP",
	19: "z23DIP",
	20: "z27TRX",
	21: "z28HAT",
	24: "z36CNT",
	25: "z38PAR",
	26: "z39ASB",
	27: "z40OGL",
	28: "z41MAP",
	29: "z42BRP",
	30: "z40aPO",
	31: "z02LGI",
	32: "z02LGI",
	33: "z02LGI",
	34: "z50LTC",
}

## Zone numbers the loading screen and island.gd handle by the plain number path
## (`Game.pending_zone`): 1 park, 3 house, and the island's four act numbers
## (the island is the default, so 2/31/32/33 need no branch).
const NUMBER_PATH := [1, 2, 3, 31, 32, 33]

## Act hide rules, ported from the island loader's own filtering (the tables the
## chapter setup functions FUN_0045b339 / FUN_0045ad9c / FUN_0045a7ee /
## FUN_0045a40d apply through the actor flags). Records listed here are dropped
## before their mesh is built, so the act changes the world visibly.
const STORY_START_HIDDEN := [9, 69, 70, 71, 72, 75, 76, 77, 78, 79, 157, 294, 295, 296, 297, 298, 299, 300, 301, 302, 303, 304, 380]
const STORY_ACT1_FIRST := 7
const STORY_ACT1_LAST := 0x1D
const STORY_ACT1_HIDDEN := [112, 113, 114, 115, 117, 118, 119, 120, 121, 122, 123, 126, 127, 129, 130, 131, 164, 165, 166, 167, 168, 169, 170, 171, 173, 374, 375, 376, 377, 378, 379, 155]
const STORY_ACT1_FIRST_STATE := [116, 124, 125, 128]
const STORY_BOT_VARS := {17: 0xA1, 18: 0xA2, 19: 0x91, 20: 0x41, 21: 0xDF, 22: 0x1B}
const STORY_ACT2_FIRST := 0x1E
const STORY_ACT2_LAST := 0x33
const STORY_ACT2_VAR := 0x54
const STORY_ACT2_HIDDEN := [112, 113, 114, 115, 117, 118, 119, 120, 123, 126, 127, 155]
const STORY_ACT2_NO_BIT2 := [130, 131, 375, 376, 377]
const STORY_ACT2_FIRST_STATE := [121, 122, 129, 165, 169, 173, 374, 378, 379]
const STORY_EARLY_HIDDEN := [156, 161, 162, 172]
const STORY_EARLY_LIMIT := 0x35
const STORY_ACT0_HIDDEN := [17, 18, 19, 20, 21, 22, 23, 24, 25, 26]
const STORY_ACT0_LIMIT := 7
const STORY_WORMHOLE_RECORD := 370
const STORY_WORMHOLE_VAR := 0xD
const STORY_PAGE_FIRST := 318
const STORY_PAGE_LAST := 346
const STORY_PTERO_RECORD := 66
const STORY_PTERO_STATE := 0x34


## FUN_00404b87: the zone the state lives in, or -1 when out of range.
const HOUSE_SITE_RECORD := 125
const HOUSE_STAGE_FIRST := 350
const HOUSE_STAGES := 10
const HOUSE_STAGE_VAR := 0xAD


static func zone_of(state: int) -> int:
	return int(TABLE[state][0]) if state >= 0 and state < TABLE.size() else -1


## The kind of each zone (the second word of the zone table at 0x88F8B0); the way back (FUN_00404AE3)
## stops at a state whose zone is of kind 1.
const ZONE_KIND := [1, 1, 1, 3, 3, 3, 1, 3, 4, 4, 1, 1, 2, 1, 3, 3, 2, 3, 2, 1, 2, 4, 1, 1, 3, 3, 2, 1, 3, 3, 0, 1, 1, 1, 1]


## FUN_00404AE3: step back to the last state in a zone of kind 1 and set the variable of that state's
## objective (the exe restores the value snapshotted when it was left; the port keeps no snapshot, so it
## stays as it is).
static func rewind(game: Node) -> int:
	var state: int = game.get_var(VAR_STATE) - 1
	while state > 0 and int(ZONE_KIND[zone_of(state)]) != 1:
		state -= 1
	state = maxi(state, 0)
	game.set_var(VAR_STATE, state)
	game.set_var(VAR_ZONE, zone_of(state))
	return state


## FUN_00404a40: is the current objective finished?
static func done(state: int, game: Node) -> bool:
	if state < 0 or state >= TABLE.size():
		return false
	var row: Array = TABLE[state]
	return (game.get_var(int(row[1])) & int(row[2])) == int(row[3])


## The archive of a state's zone ("" when the state or zone is unknown).
static func archive_of(state: int) -> String:
	return String(ZONE_ARCHIVE.get(zone_of(state), ""))


## The zone number to record in var 5 when `code` is loaded. A state that
## already lives in that archive keeps its own act number (the island's 31/32/33
## all load z02LGI but stay distinct in var 5); otherwise the first number the
## table uses for that archive wins.
static func travel_zone(code: String, game: Node) -> int:
	var state: int = game.get_var(VAR_STATE)
	if archive_of(state) == code:
		return zone_of(state)
	for zone in ZONE_ARCHIVE:
		if String(ZONE_ARCHIVE[zone]) == code:
			return int(zone)
	return game.get_var(VAR_ZONE)


## The (number, code) pair the loading screen and island.gd expect for an
## archive. The island must use the number path: island.gd derives a placement
## prefix from the code, and z02LGI would become "lgi", not "island".
static func load_zone(code: String) -> Array:
	match code:
		"z01BPK":
			return [1, ""]
		"z02LGI":
			return [2, ""]
		"z03PPH":
			return [3, ""]
	return [-1, code]


## FUN_00404b52: advance one state. Also moves var 5 (this is the "travel sets
## var 5" step: the objective rows for the reached zones test var 5 itself).
static func advance(game: Node) -> int:
	var next: int = mini(game.get_var(VAR_STATE) + 1, TABLE.size() - 1)
	game.set_var(VAR_STATE, next)
	game.set_var(VAR_ZONE, zone_of(next))
	return next


## FUN_00404ba7 (forward, the exe's debug chapter skip) and FUN_00404a96
## (back, without the snapshot restore).
static func jump(game: Node, delta: int) -> int:
	var target: int = clampi(game.get_var(VAR_STATE) + delta, 0, TABLE.size() - 1)
	if delta > 0:
		set_state(game, target)
	else:
		game.set_var(VAR_STATE, target)
		game.set_var(VAR_ZONE, zone_of(target))
	return target


static func set_state(game: Node, state: int) -> void:
	var row: Array = TABLE[state]
	game.set_var(int(row[1]), int(row[3]))
	game.set_var(VAR_STATE, state)
	game.set_var(VAR_ZONE, zone_of(state))


## The island loader's act filtering, keyed on the story state and a few game
## vars. Returns true when the record must not be placed at all.
static func hidden(record: int, state: int, game: Node) -> bool:
	# FUN_004C4F19 (act 1) registers the four collectible pages PAG1..PAG4 (records
	# 69..72, FUN_004CF911) while the state is below 10, which shows them.
	if record >= 69 and record <= 72 and state >= 7 and state < 10:
		return false
	if STORY_START_HIDDEN.has(record) or (record >= STORY_PAGE_FIRST and record <= STORY_PAGE_LAST):
		return true
	if record == STORY_PTERO_RECORD and state < STORY_PTERO_STATE:
		return true
	if STORY_EARLY_HIDDEN.has(record) and state < STORY_EARLY_LIMIT:
		return true
	if STORY_ACT0_HIDDEN.has(record) and state < STORY_ACT0_LIMIT:
		return true
	if record == STORY_WORMHOLE_RECORD and game.get_var(STORY_WORMHOLE_VAR) == 0:
		return true
	if state >= STORY_ACT1_FIRST and state <= STORY_ACT1_LAST:
		if STORY_ACT1_HIDDEN.has(record):
			return true
		if STORY_ACT1_FIRST_STATE.has(record) and state == STORY_ACT1_FIRST:
			return true
		if record == 163 and state < 10:
			return true
	if state >= STORY_ACT2_FIRST and state <= STORY_ACT2_LAST:
		if STORY_ACT2_HIDDEN.has(record):
			return true
		if STORY_ACT2_NO_BIT2.has(record) and (game.get_var(STORY_ACT2_VAR) & 2) == 0:
			return true
		if STORY_ACT2_FIRST_STATE.has(record) and state == STORY_ACT2_FIRST:
			return true
		if record >= 23 and record <= 26:
			return true
		if STORY_BOT_VARS.has(record) and (game.get_var(STORY_BOT_VARS[record]) & 0x4000) != 0:
			return true
	match record:
		68:
			return state < 0x37 or state > 0x3A
		11:
			return state == 9
		14, 29:
			return state >= 0x1E and state <= 0x33
		12, 13:
			return state >= 0x35 and state <= 0x3F
		32:
			return state == 0x36 or state == 0x37
		31:
			return state >= 0x3A and state <= 0x3D
		10:
			return state >= 7
		44:
			return state >= 0x44
		15:
			return true
		155, 113, 114, 115, 118:
			return state < 0x36
		112, 120, 126:
			return state >= 0x34 and state < 0x36
		119:
			return state >= 0x34
	return false
