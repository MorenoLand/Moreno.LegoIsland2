class_name ParkSwitch
extends Behaviour

## The park's run keeper: constructor FUN_007ED641, update FUN_007ED388 (returns 2), clock and bank
## FUN_007ED150, result FUN_007ED47D. It runs on every tick (mask 0) and works while the input
## selector (var 0x5E) is exactly 4, the board: the two minutes count down once the board is mounted,
## the points of a taken trick go to the score ten at a time, and when the time is out the run is
## scored and given a medal.
##
## Fields of the original object: +0x18 the bank is paying out, +0x19 the time is out, +0x1C the time
## left (3600 ticks), +0x20 the score, +0x24 the points waiting to be paid.

const CLIP_MOUNT := 0x16
const TIME := 3600.0
const TICKS_PER_SECOND := 30.0
const PAYOUT := 10.0
const BRONZE_FROM := 1
const SILVER_OVER := 0x9C4
const GOLD_FROM := 0x1389
const VAR_MEDAL := 0x8D
const VAR_HIGH_SCORE := 0xC0
const FRAME := 1.0

var paying := false
var expired := false
var time_left := TIME
var score := 0.0
var waiting := 0.0
var advance_result := 0

var services: ActorServices
var vars


static func from_descriptor(services_in: ActorServices, vars_in) -> ParkSwitch:
	var b := ParkSwitch.new()
	b.services = services_in
	b.vars = vars_in
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


func update(actor, _block: BehaviourBlock, var_value: int) -> int:
	var g := services.talk
	if var_value == 4:
		_clock(actor)
		if expired:
			_finish(int(score))
			expired = false
			advance_result = services.clip_advance(actor, 1.0)
			services.clip_advance(services.record_at(g.hidden_record), 1.0)
	return 2


## FUN_007ED150: the clock, the bank and the texts of the HUD.
func _clock(actor) -> void:
	var g := services.talk
	var counting := false
	if time_left > 0.0:
		if services.current_clip(actor) != CLIP_MOUNT:
			time_left -= FRAME
			counting = true
	if not counting and time_left <= 0.0:
		time_left = 0.0
		g.trick_score = 0.0
	g.park_time_left = time_left
	if time_left <= 0.0:
		expired = true
	var seconds := int(time_left / TICKS_PER_SECOND)
	if g.score_taken:
		paying = true
		g.score_taken = false
		waiting = g.trick_score + waiting
		g.trick_score = 0.0
	if paying and waiting > 0.0:
		score += PAYOUT
		waiting -= PAYOUT
		if waiting < 0.0:
			score += waiting
			waiting = 0.0
			paying = false
	if time_left >= 0.0:
		g.park_clock_text = "%d:%02d" % [int(seconds / 60.0), seconds % 60]
	g.park_score_text = "%d" % int(score)
	if g.trick_score != 0.0:
		g.park_trick_text = "%d" % int(g.trick_score)
	else:
		g.park_line_text = ""
		g.park_trick_text = ""
	g.park_hud = true


## FUN_007ED47D: the medal of the run, kept when it beats the best, and the high score.
func _finish(points: int) -> void:
	var g := services.talk
	var best: int = vars.get_var(VAR_HIGH_SCORE)
	var medal := 0
	if points < GOLD_FROM:
		if points > SILVER_OVER:
			medal = 2
		elif points >= BRONZE_FROM:
			medal = 1
	else:
		medal = 3
	if medal != 0:
		g.park_medal = medal
	var kept: int = vars.get_var(VAR_MEDAL)
	if kept <= medal:
		vars.set_var(VAR_MEDAL, medal)
		kept = medal
	g.park_end = 2 - (1 if kept != 0 else 0)
	g.park_score = points
	if best < points:
		vars.set_var(VAR_HIGH_SCORE, points)
		g.park_high = true
