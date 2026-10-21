extends RefCounted

## The game's cut-scene manager (`COMMON\CSM`), driven straight from the shipped
## `_data/<zone>/Cutscene/<name>.txt` scripts.
##
## CONFIRMED from the executable (Manager.c / Loader.c / Convert.c, pseudocode
## `FUN_0043dde9` and the event executors `FUN_00442670` / `FUN_0044321d`):
##
##   * A script is a list of events `sync delay actor VERB args... [next [delay]]`.
##   * Every event has a "sync" label. Events that name a `next` label raise a
##     counter on that label (`FUN_0043d8e5`); an event with sync S may start only
##     when the counter of S is zero, i.e. when EVERY event that points at S has
##     finished (`FUN_0043dde9`: state 0 -> 1 only if `counts[sync] == 0`). Sync 0
##     is never pointed at, so it starts at once. Finishing an event with a
##     `next` lowers that counter (`FUN_0043e2e8`).
##   * The script ends on the first tick where no event is running.
##   * `delay` counts down 1/30 s per tick (`_DAT_00887130` = 0.03333) before the
##     event first acts; the talk key (0x40) zeroes it and finishes the event.
##   * The camera aims at an actor's position + 3.37 up (`_DAT_00887200`).
##   * Camera glide (`FUN_00442b79` / `FUN_00442d3c` / `FUN_00442e74`): velocity
##     V = (goal - start) * speed, scaled by a ramp t that rises by `accel` per
##     tick while the distance travelled is below the distance left and falls by
##     `accel` afterwards; the move ends when the distance left is no more than
##     one step, snapping to the goal. Defaults speed 0.4, accel 0.08;
##     SETMOVESPEED / SETTARGETSPEED set `accel = arg2 * 0.02`, `speed = arg1 * 0.1`.
##   * Camera placement around an actor (`FUN_0041b8b1` / `FUN_0041b7c6`, table
##     `0x008a81b0` = (4, 2, -10)): HEAD = (0, 0, -1.75), FRONT = (-4, 2, 10),
##     BEHIND = (4, 2, -10), LSIDE = (10, 2, 4), RSIDE = (-10, 2, 4), each rotated
##     by the actor's heading.
##   * Walking (`FUN_004433eb`): speed 0.05 walker units per tick, one walker unit
##     being 8 world units (`_DAT_008870f4`), i.e. 0.4 units per 1/30 s tick.
##
## The host (the island scene) owns the actors, speech and camera; this class is
## only the timeline.

const TICK := 1.0 / 30.0
const HEAD_UP := 3.37
const CAM_DEFAULT_SPEED := 0.4
const CAM_DEFAULT_ACCEL := 0.08
const WALK_STEP := 0.4
const ARRIVE := 1.5
const TURN_STEP := 0.2

const PLACE_HEAD := 0
const PLACE_FRONT := 1
const PLACE_BEHIND := 2
const PLACE_LSIDE := 3
const PLACE_RSIDE := 4
const CAM_TABLE := Vector3(4.0, 2.0, -10.0)

var name := ""
var events: Array = []
var counts := {}
var running := false
var host: Object
var clock := 0.0
var cam_pos := Vector3.ZERO
var cam_target := Vector3.ZERO
var cam_follow := ""
var cam_fov := -1.0
var move_speed := CAM_DEFAULT_SPEED
var move_accel := CAM_DEFAULT_ACCEL
var target_speed := CAM_DEFAULT_SPEED
var target_accel := CAM_DEFAULT_ACCEL
var follow_owner := {}
var follows := {}


static func parse_text(text: String) -> Array:
	var out: Array = []
	var in_script := false
	for raw in text.replace("\r", "").split("\n"):
		var line := String(raw).strip_edges()
		if line == "" or line.begins_with("//"):
			continue
		if line.begins_with("["):
			in_script = line.to_upper().begins_with("[SCRIPT")
			continue
		if not in_script:
			continue
		var tokens: Array = []
		for t in line.split("\t", false):
			var s := String(t).strip_edges()
			if s != "":
				tokens.append(s)
		if tokens.size() < 4 or not String(tokens[0]).is_valid_int():
			continue
		var event := {
			"sync": int(tokens[0]),
			"delay": float(tokens[1]),
			"actor": String(tokens[2]).to_lower(),
			"verb": String(tokens[3]).to_lower(),
			"args": [],
			"next": 0,
			"state": 0,
			"wait": 0.0,
			"started": false,
		}
		var rest: Array = tokens.slice(4)
		event.args = rest
		out.append(event)
	return out


func load_script(script_name: String, text: String) -> bool:
	name = script_name
	events = parse_text(text)
	for e in events:
		_resolve_next(e)
	return not events.is_empty()


## The trailing integer of an event is its `next` label (and an optional float
## after it a delay). Which verbs carry one follows the exe's own `sscanf`
## formats (`Convert.c`): SETANIM, SAYTEXT, MOVEPOSITION/MOVETARGET, FOLLOW,
## SETSWITCH (value first) and the camera moves.
func _resolve_next(e: Dictionary) -> void:
	var args: Array = e.args
	var verb: String = e.verb
	var next_at := -1
	match verb:
		"setanim", "saytext", "follow":
			next_at = 1
		"moveposition", "movetarget":
			next_at = 2
		"setswitch":
			next_at = 2
	if next_at >= 0 and args.size() > next_at and String(args[next_at]).is_valid_int():
		e.next = int(args[next_at])
		if args.size() > next_at + 1 and String(args[next_at + 1]).is_valid_float():
			e["post"] = float(args[next_at + 1])
		args = args.slice(0, next_at)
		e.args = args
	elif verb == "setanim" or verb == "saytext" or verb == "follow":
		# `follow pepp 10` has the label right after the target
		pass


func start(host_object: Object) -> void:
	host = host_object
	counts.clear()
	for e in events:
		e.state = 0
		e.started = false
		e.erase("body_done")
		e.erase("post_left")
		e.wait = float(e.delay)
		if int(e.next) != 0:
			counts[int(e.next)] = int(counts.get(int(e.next), 0)) + 1
	running = true
	clock = 0.0
	follows.clear()
	follow_owner.clear()
	for i in events.size():
		events[i]["uid"] = i
		events[i].erase("follow_started")
	cam_follow = ""
	cam_fov = -1.0
	move_speed = CAM_DEFAULT_SPEED
	move_accel = CAM_DEFAULT_ACCEL
	target_speed = CAM_DEFAULT_SPEED
	target_accel = CAM_DEFAULT_ACCEL


## Advance by wall-clock `delta` seconds in whole 1/30 s ticks. Returns false
## once the script has finished.
func tick(delta: float, skip: bool) -> bool:
	if not running:
		return false
	clock += delta
	while clock >= TICK and running:
		clock -= TICK
		_step(skip)
	return running


func _step(skip: bool) -> void:
	var any_running := false
	for e in events:
		if e.state == 0 and int(counts.get(int(e.sync), 0)) == 0:
			e.state = 1
	for e in events:
		if e.state != 1:
			continue
		any_running = true
		if skip:
			e.wait = 0.0
		if float(e.wait) > 0.0:
			e.wait = float(e.wait) - TICK
			continue
		if not bool(e.get("body_done", false)):
			if not _run(e, skip):
				continue
			e["body_done"] = true
			e["post_left"] = float(e.get("post", 0.0))
		if skip:
			e["post_left"] = 0.0
		if float(e.get("post_left", 0.0)) > 0.0:
			e["post_left"] = float(e.post_left) - TICK
			continue
		e.state = 2
		if int(e.next) != 0:
			counts[int(e.next)] = int(counts.get(int(e.next), 1)) - 1
	_follow_tick()
	_camera_tick()
	if not any_running:
		running = false
		host.call("csm_finished", self)


func _actor_arg(args: Array) -> String:
	var i := 0
	if args.size() > 0 and (String(args[0]).to_lower() == "actor" or String(args[0]).to_lower() == "waypoint"):
		i = 1
	return String(args[i]).to_lower() if args.size() > i else ""


func _is_waypoint(args: Array) -> bool:
	return args.size() > 0 and String(args[0]).to_lower() == "waypoint"


func _place_of(args: Array) -> int:
	for a in args:
		match String(a).to_lower():
			"head":
				return PLACE_HEAD
			"front", "infront":
				return PLACE_FRONT
			"behind":
				return PLACE_BEHIND
			"lside":
				return PLACE_LSIDE
			"rside":
				return PLACE_RSIDE
	return PLACE_HEAD


func place_offset(place: int, yaw: float) -> Vector3:
	var t := CAM_TABLE
	var local := Vector3.ZERO
	match place:
		PLACE_HEAD:
			local = Vector3(0.0, 0.0, -1.75)
		PLACE_FRONT:
			local = Vector3(-t.x, t.y, -t.z)
		PLACE_BEHIND:
			local = Vector3(t.x, t.y, t.z)
		PLACE_LSIDE:
			local = Vector3(-t.z, t.y, t.x)
		PLACE_RSIDE:
			local = Vector3(t.z, t.y, t.x)
	# game space: heading yaw turns +z toward (sin yaw, cos yaw)
	var s := sin(yaw)
	var c := cos(yaw)
	return Vector3(local.x * c + local.z * s, local.y, -local.x * s + local.z * c)


## Camera position/target are kept in GAME space (x, y, z); the host flips z.
func _run(e: Dictionary, skip: bool) -> bool:
	var actor: String = e.actor
	var args: Array = e.args
	var is_cam := actor == "cmra"
	match String(e.verb):
		"setposition":
			if is_cam:
				if _is_waypoint(args):
					cam_pos = host.call("waypoint", _actor_arg(args))
				else:
					var who := _actor_arg(args)
					var p: Vector3 = host.call("actor_pos", who)
					var yaw: float = host.call("actor_yaw", who)
					cam_target = p + Vector3(0.0, HEAD_UP, 0.0)
					cam_pos = cam_target + place_offset(_place_of(args), yaw)
					cam_follow = who
			else:
				if _is_waypoint(args):
					var wp: Vector3 = host.call("waypoint", _actor_arg(args))
					if wp != Vector3.INF:
						host.call("actor_place", actor, wp, host.call("actor_yaw", actor))
			return true
		"settarget":
			if is_cam:
				if _is_waypoint(args):
					cam_target = host.call("waypoint", _actor_arg(args))
					cam_follow = ""
				else:
					var who2 := _actor_arg(args)
					cam_target = host.call("actor_pos", who2) + Vector3(0.0, HEAD_UP, 0.0)
					cam_follow = who2
			else:
				var focus: Vector3 = Vector3.INF
				if _is_waypoint(args):
					focus = host.call("waypoint", _actor_arg(args))
				else:
					focus = host.call("actor_pos", _actor_arg(args))
				if focus != Vector3.INF:
					var from: Vector3 = host.call("actor_pos", actor)
					host.call("actor_place", actor, from, atan2(focus.x - from.x, focus.z - from.z))
			return true
		"follow":
			if is_cam:
				cam_follow = _actor_arg(args)
				if cam_follow == "":
					cam_follow = ""
				return true
			var target := _actor_arg(args)
			if target == "nobody" or target == "":
				follows.erase(actor)
				return true
			follows[actor] = target
			# One facing target per actor: the follow that started last owns it,
			# earlier ones finish at once (two follows on one actor at the same
			# label would otherwise turn it back and forth forever).
			if not bool(e.get("follow_started", false)):
				e["follow_started"] = true
				follow_owner[actor] = int(e.uid)
			if int(follow_owner.get(actor, -1)) != int(e.uid):
				return true
			return _faces(actor, target)
		"setvisibility", "enableai":
			if String(e.verb) == "setvisibility":
				host.call("actor_visible", actor, String(args[0]).to_lower() == "true")
			return true
		"setanim":
			return _run_anim(e, skip)
		"saytext":
			return _run_say(e, skip)
		"setswitch":
			host.call("set_switch", String(args[0]), int(args[1]) if args.size() > 1 else 1)
			return true
		"setfov":
			cam_fov = float(args[0]) if args.size() > 0 else cam_fov
			return true
		"setexpression":
			host.call("set_expression", actor, int(args[0]) if args.size() > 0 else 0)
			return true
		"attach":
			host.call("attach", actor, String(args[0]).to_lower() if args.size() > 0 else "null", String(args[1]).to_lower() if args.size() > 1 else "")
			return true
		"setmovespeed":
			if args.size() >= 2:
				move_speed = float(args[0]) * 0.1
				move_accel = float(args[1]) * 0.02
			return true
		"settargetspeed":
			if args.size() >= 2:
				target_speed = float(args[0]) * 0.1
				target_accel = float(args[1]) * 0.02
			return true
		"moveposition", "movetarget":
			return _run_move(e, skip, is_cam)
		"wav", "midi":
			return true
	return true


func _faces(actor: String, target: String) -> bool:
	var a: Vector3 = host.call("actor_pos", actor)
	var b: Vector3 = host.call("actor_pos", target)
	if not a.is_finite() or not b.is_finite():
		return true  # an actor this act does not have: nothing to turn
	var want := atan2(b.x - a.x, b.z - a.z)
	var yaw: float = host.call("actor_yaw", actor)
	var diff := wrapf(want - yaw, -PI, PI)
	if absf(diff) <= TURN_STEP:
		host.call("actor_place", actor, a, want)
		return true
	host.call("actor_place", actor, a, wrapf(yaw + signf(diff) * TURN_STEP, -PI, PI))
	return false


func _follow_tick() -> void:
	for actor in follows.keys():
		var target: String = follows[actor]
		var a: Vector3 = host.call("actor_pos", actor)
		var b: Vector3 = host.call("actor_pos", target)
		if not a.is_finite() or not b.is_finite():
			continue
		var want := atan2(b.x - a.x, b.z - a.z)
		var yaw: float = host.call("actor_yaw", actor)
		var diff := wrapf(want - yaw, -PI, PI)
		if absf(diff) <= TURN_STEP:
			host.call("actor_place", actor, a, want)
		else:
			host.call("actor_place", actor, a, wrapf(yaw + signf(diff) * TURN_STEP, -PI, PI))


func _run_anim(e: Dictionary, skip: bool) -> bool:
	var actor: String = e.actor
	if not bool(e.started):
		e.started = true
		var clip: int = host.call("clip_index", String(e.args[0]), actor) if e.args.size() > 0 else -1
		e["length"] = host.call("actor_clip", actor, clip, int(e.next) == 0)
		e["age"] = 0.0
	if int(e.next) == 0:
		return true
	e.age = float(e.get("age", 0.0)) + TICK
	return skip or float(e.age) >= float(e.get("length", 0.0))


func _run_say(e: Dictionary, skip: bool) -> bool:
	var actor: String = e.actor
	if not bool(e.started):
		e.started = true
		e["length"] = host.call("say", actor, String(e.args[0]) if e.args.size() > 0 else "")
		e["age"] = 0.0
	e.age = float(e.get("age", 0.0)) + TICK
	if skip or float(e.age) >= float(e.get("length", 0.0)):
		host.call("say_end", actor)
		return true
	return false


func _run_move(e: Dictionary, skip: bool, is_cam: bool) -> bool:
	var args: Array = e.args
	var goal := Vector3.INF
	if _is_waypoint(args):
		goal = host.call("waypoint", _actor_arg(args))
	elif args.size() > 0 and String(args[0]).to_lower() == "actor":
		var base: Vector3 = host.call("actor_pos", _actor_arg(args))
		goal = base + (Vector3(0.0, HEAD_UP, 0.0) if is_cam else Vector3.ZERO)
	if goal == Vector3.INF:
		return true
	if is_cam:
		return _glide(e, goal, skip, String(e.verb) == "moveposition")
	var actor: String = e.actor
	var from: Vector3 = host.call("actor_pos", actor)
	if skip:
		host.call("actor_place", actor, goal, host.call("actor_yaw", actor))
		return true
	var flat := Vector3(goal.x - from.x, 0.0, goal.z - from.z)
	var dist := flat.length()
	if dist <= ARRIVE:
		host.call("actor_place", actor, goal, host.call("actor_yaw", actor))
		return true
	var step := minf(WALK_STEP, dist)
	var yaw := atan2(flat.x, flat.z)
	host.call("actor_place", actor, Vector3(from.x + flat.x / dist * step, goal.y, from.z + flat.z / dist * step), yaw)
	return false


func _glide(e: Dictionary, goal: Vector3, skip: bool, position: bool) -> bool:
	var key := "cam_pos" if position else "cam_target"
	var cur: Vector3 = cam_pos if position else cam_target
	if not bool(e.started):
		e.started = true
		var speed := move_speed if position else target_speed
		e["glide"] = {
			"goal": goal, "v": (goal - cur) * speed,
			"t": 0.0, "travelled": 0.0, "left": (goal - cur).length(),
			"accel": move_accel if position else target_accel,
		}
	var g: Dictionary = e.glide
	if skip:
		_set_cam(position, g.goal)
		return true
	var step := Vector3.ZERO
	if float(g.travelled) < float(g.left):
		if float(g.t) < 1.0:
			g.t = float(g.t) + float(g.accel)
		step = (g.v as Vector3) * float(g.t)
		g.travelled = float(g.travelled) + step.length()
	elif float(g.left) > 0.01:
		var accel := float(g.accel)
		g.t = (float(g.t) - accel) if float(g.t) - accel >= accel else accel
		step = (g.v as Vector3) * float(g.t)
	cur += step
	g.left = (cur - (g.goal as Vector3)).length()
	if float(g.left) <= step.length() or float(g.left) <= 0.001:
		_set_cam(position, g.goal)
		return true
	_set_cam(position, cur)
	return false


func _set_cam(position: bool, value: Vector3) -> void:
	if position:
		cam_pos = value
	else:
		cam_target = value


func _camera_tick() -> void:
	if cam_follow != "":
		var anchor: Vector3 = host.call("actor_pos", cam_follow)
		if anchor != Vector3.INF:
			cam_target = anchor + Vector3(0.0, HEAD_UP, 0.0)
	host.call("camera_apply", cam_pos, cam_target, cam_fov)
