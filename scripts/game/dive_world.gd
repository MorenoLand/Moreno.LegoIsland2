class_name DiveWorld
extends RefCounted

## The dive zone's (z08BKD) shared state and helpers, the exe's file-scope globals and the small
## functions of 0x00520F5F..0x0052102D / 0x00521134.

const TAU_F := 6.2831854820251465
const PI_F := 3.1415927410125732
const TICK_SECONDS := 0.033333335

## FUN_00533070: the sounds the zone creates (global address, sound id).
const SOUNDS := [
	[0x5D4C84C, 0x33], [0x5D4C7F8, 0x34], [0x5D4C844, 0x3E], [0x5D4C834, 0x43], [0x5D4C810, 0x42],
	[0x5D4C854, 0x41], [0x5D4C808, 0x40], [0x5D4C824, 0x3F], [0x5D4C814, 0x3C], [0x5D4C7F4, 0x31],
	[0x5D4C830, 0x30], [0x5D4C7FC, 0x36], [0x5D4C7F0, 0x37], [0x5D4C804, 0x38], [0x5D4C818, 0x39],
	[0x5D4C81C, 0x3A], [0x5D4C820, 0x3B], [0x5D4C828, 0x46], [0x5D4C82C, 0x47], [0x5D4C7EC, 0x3D],
	[0x5D4C840, 0x44], [0x5D4C83C, 0x45], [0x5D4C80C, 0x32], [0x5D4C800, 0x35], [0x5D4C838, 0x334],
	[0x5D4C848, 0x48], [0x5D4C850, 0x49], [0x5D4C858, 0x4A],
]
const SOUND_CLAM_CREAK := 0x5D4C84C
const SOUND_CLAM_SHUT := 0x5D4C7F8

## FUN_00520F5F sets the step each tick: DAT_008A0850 (1.0) * 1.0 * 1/30.
static var dt := TICK_SECONDS
## The fraction of a second the pulse clock is into the current second.
static var phase := 0.0


## FUN_00520F5F: advance the clocks once per tick.
static func tick_clock() -> void:
	dt = 1.0 * 1.0 * TICK_SECONDS
	phase += dt
	while 1.0 < phase:
		phase -= 1.0


## FUN_00520FCD(levels): which of `levels` pulse bands the clock is in (0 when it is past the last).
static func pulse_level(levels: int) -> int:
	var edge := 0.95 / float(levels)
	for level in levels:
		if phase < edge:
			return level
		edge += edge
	return 0


## FUN_00521134: an angle brought into [0, 2 pi).
static func wrap_angle(angle: float) -> float:
	while TAU_F <= angle:
		angle -= TAU_F
	while angle < 0.0:
		angle += TAU_F
	return angle


## FUN_0052102D(a, b): the shortest way from angle b to a. Returns [direction (0 equal, 1 or -1),
## ratio of the half turn, angle apart].
static func angle_gap(a: float, b: float) -> Array:
	if a == b:
		return [0, 1.0, 0.0]
	if a <= b:
		var apart := b - a
		if apart <= PI_F:
			return [-1, apart / PI_F, apart]
		return [1, (TAU_F - apart) / PI_F, TAU_F - apart]
	var apart_up := a - b
	if apart_up <= PI_F:
		return [1, apart_up / PI_F, apart_up]
	return [-1, (TAU_F - apart_up) / PI_F, TAU_F - apart_up]


## ---- The zone's records (indices of the offsets the exe adds to DAT_00975E44, offset / 0x68).
const R_SEA := 1
const R_SWIMMER := 5
const R_SWIMMER_HURT := 6
const R_OCTOPUS := 25
const R_PIRATES := [21, 22, 24]
const R_CLAM := 52
const R_CHEST := 53
const R_ANCHOR := 54
const R_CANNON := 57
const R_BALLS := [67, 56, 59, 60, 61, 62, 63, 64, 65, 66]
const R_OCTOPUS_ARM := 69
const R_WALL := 72
const R_PAGE := 82
const R_BRICKS := [51, 89, 90, 91, 92]

## The state the dive keeps in file-scope globals.
static var services: ActorServices
static var graph: DiveGraph
static var groups: Array = []
static var swimmer = null
static var cannon_balls_out := 0
static var air_used := 0.0
static var bricks_taken := 0
static var finished := false
static var finish_timer := 0.0
static var halfway_said := false
static var hint := 0
static var delivered := false
static var speech := {}
static var dolphin_hint := 0
static var dolphin_jumping := false


static func reset(services_in: ActorServices, graph_in: DiveGraph) -> void:
	services = services_in
	graph = graph_in
	groups = []
	swimmer = null
	cannon_balls_out = 0
	air_used = 0.0
	bricks_taken = 0
	finished = false
	finish_timer = 0.0
	halfway_said = false
	hint = 0
	delivered = false
	dolphin_hint = 0
	dolphin_jumping = false
	phase = 0.0


## FUN_00421C4D(table, name) + FUN_0041DD01: play a line of the zone's speech file.
static func say(name: String) -> void:
	var found := services.speech_lookup(speech, name)
	services.subtitle_show(String(found[0]))
	services.speech_queue(int(found[1]), -1)
	services.speech_start()


## FUN_00520880(out, in, count, angle): the points turned about the z axis (row vectors; cos is
## FUN_00842294, sin FUN_008421E4).
static func rotate_points(points: PackedVector3Array, angle: float) -> PackedVector3Array:
	var cosine := cos(angle)
	var sine := sin(angle)
	var out := PackedVector3Array()
	for p in points:
		out.append(Vector3(cosine * p.y + sine * p.x, sine * p.y - cosine * p.x, p.z))
	return out


## FUN_005205A7 + the groups of FUN_00520540: collision spheres that follow a record. A group is a
## record, its kind, an offset sphere and member spheres, all in the record's own space.
const TEMPLATES := {
	"A": {"offset": Vector3(0.0, 3.0, 0.5), "radius": 2.5, "members": [[Vector3(0.0, 3.0, 0.5), 2.5]]},
	"B": {"offset": Vector3.ZERO, "radius": 2.700000047683716, "members": [
		[Vector3(0.0, 0.0, 2.0), 1.0], [Vector3.ZERO, 1.0], [Vector3(0.0, 0.0, -2.0), 1.0],
		[Vector3(-2.0, 0.0, 0.30000001192092896), 1.0], [Vector3(2.0, 0.0, 0.30000001192092896), 1.0]]},
	"C": {"offset": Vector3.ZERO, "radius": 2.799999952316528, "members": [
		[Vector3(0.0, 0.20000000298023224, 2.0), 1.0], [Vector3(0.0, 0.20000000298023224, 0.0), 1.0],
		[Vector3(0.0, 0.20000000298023224, -2.0), 1.0]]},
}


## FUN_00520540(record, kind, template)
static func register_group(record, kind: int, template: String) -> void:
	var spec: Dictionary = TEMPLATES[template]
	var group := {"record": record, "kind": kind, "offset": spec["offset"], "radius": spec["radius"], "members": []}
	for member in spec["members"]:
		group["members"].append({"local": member[0], "world": Vector3.ZERO, "radius": member[1]})
	groups.append(group)


## FUN_005205A7: put every group and member sphere at its record.
static func update_groups() -> void:
	for group in groups:
		var record = group["record"]
		var matrix := ActorServices.rotation_rows(record.field_f(0x4C), record.yaw, record.field_f(0x54))
		var here := Vector3(record.x, record.y, record.z)
		group["world"] = RecordCollision.rotate(matrix, group["offset"]) + here
		for member in group["members"]:
			member["world"] = RecordCollision.rotate(matrix, member["local"]) + here


## FUN_00520715(points): the kind of the first group whose member sphere an edge of the polygon
## meets (0 for none) and its record.
static func group_hit(points: PackedVector3Array) -> Dictionary:
	for group in groups:
		for member in group["members"]:
			for i in points.size():
				var next := 0 if i == points.size() - 1 else i + 1
				var t := RecordCollision.segment_sphere(points[i], points[next], member["world"], member["radius"])
				if 0.0 < t and t <= 1.0:
					return {"kind": group["kind"], "record": group["record"]}
	return {"kind": 0, "record": null}


## FUN_00520977(points, count, self, ..., list): every distinct record of the list (self left out)
## that an edge of the polygon touches, tested with FUN_00428AB0 (surface mask 2, radii 0.01 and 0).
## Returns {"records", "normal", "point"}: the hit normal and point are those of the last hit.
static func edge_hits(points: PackedVector3Array, self_record, list: Array) -> Dictionary:
	var found: Array = []
	var normal := Vector3(-1.0737418e+08, -1.0737418e+08, -1.0737418e+08)
	var point := Vector3(-1.0737418e+08, -1.0737418e+08, -1.0737418e+08)
	for i in points.size():
		var next := 0 if i == points.size() - 1 else i + 1
		var edge := points[next] - points[i]
		for record in list:
			if record == self_record:
				continue
			var hit := services.collide_record(record, points[i], edge, 2, 0.009999999776482582, 0.0)
			if hit.is_empty():
				continue
			normal = hit["normal"]
			point = hit["point"]
			if not found.has(record):
				found.append(record)
	return {"records": found, "normal": normal, "point": point}


## FUN_00522164(velocity, spin, position, normal, hit point): a bounce off a wall. Returns the new
## velocity and spin in a dictionary, and "rest" true when the ball has come to rest (FUN_00522164
## returns 1).
static func bounce(velocity: Vector3, position: Vector3, normal: Vector3, hit_point: Vector3) -> Dictionary:
	var n := Vector3(normal.x, normal.y, 0.0)
	var length := n.length()
	if length != 0.0:
		n = n / length
	var along := -(n.dot(velocity))
	var scaled := Vector3(n.x * along, n.y * along, 0.0)
	var reflected := Vector3(scaled.x * 2.0 + velocity.x, scaled.y * 2.0 + velocity.y, 0.0)
	var speed := velocity.length()
	var keep := absf(along) / speed * 0.5
	if keep < 0.4:
		keep = 0.4
	keep = 1.0 - keep
	reflected = Vector3(reflected.x * keep, reflected.y * keep, 0.0)
	if 0.2 <= speed:
		var away := (position - hit_point).normalized()
		var side := reflected.normalized()
		var spin := -1.5707879 if side.dot(away) <= 0.0 else 1.5707879
		return {"velocity": reflected, "spin": keep * spin, "rest": false}
	return {"velocity": Vector3.ZERO, "spin": 0.0, "rest": true}


## FUN_00524630 (anchor) / FUN_005240D0 (octopus arm): the speed a player is pushed away with by a
## swinging part. `swing` is the part's own swing speed, `angle` its roll plus a quarter turn
## for the arm.
static func bump(part, swing_speed: float, angle: float, player: Vector3) -> Vector3:
	var along := Vector3(cos(angle), sin(angle), 0.0)
	var away := -along
	var to_part := Vector3(part.x, part.y, part.z) - player
	var distance := to_part.length()
	var direction := to_part.normalized()
	var side := direction.dot(along)
	var strength := absf(swing_speed) * distance * 1.1
	if 0.0 <= side:
		return away * strength
	return along * strength


## FUN_0052782E(player, hit point, normal): which side of the surface the player is on, as a quarter
## turn (-pi/2 or +pi/2). The normal passed by the swimmer is never filled in (the exe leaves its
## debug fill 0xCCCCCCCC there), so the test uses that fill.
static func side_turn(player: Vector3, hit_point: Vector3, normal: Vector3) -> float:
	var n := normal.normalized()
	var d := player - hit_point
	return -1.5707879 if n.dot(d) <= 0.0 else 1.5707879


## The swing speed of the anchor / the octopus arm, read from the behaviours on their records.
static func anchor_speed(anchor) -> float:
	var item = anchor.block.head if anchor.block != null else null
	while item != null:
		if item is AnchorSwing:
			return item.speed
		item = item.next
	return 0.0


static func octopus_speed() -> float:
	var body = services.record_at(R_OCTOPUS)
	var item = body.block.head if body.block != null else null
	while item != null:
		if item is OctopusArm:
			return item.speed
		item = item.next
	return 0.0


## FUN_00523E46(mouth, player, angle): is the swimmer in front of the clam's mouth.
static func clam_front(mouth: Vector3, player: Vector3, angle: float) -> bool:
	var normal := Vector3(0.0, cos(angle), sin(angle))
	var d := (mouth - player).normalized()
	return d.dot(normal) < 0.0


const PULL_TURN := 1.3962633609771729
const PULL_TURN_BACK := 4.886921405792236


## FUN_00523960(clam, player, ..., heading, ...): what the clam does to the swimmer: while it is shut
## it shoves him off (up when he is in front of the mouth, down otherwise) and holds him to it
## once it has opened, drawing him in and turning him.
static func clam_pull(clam, hinge, player: Vector3, heading: float, swimmer) -> void:
	var values: Array = swimmer.steering.values
	if hinge.opened == 0:
		var mouth := Vector3(clam.x, clam.y + 3.0, clam.z)
		if not clam_front(mouth, player, clam.field_f(0x4C)):
			if hinge.speed <= 0.0:
				values[6] = 0.0
				values[7] = -1.0
				values[8] = 0.0
			else:
				hinge.opened = 1
		else:
			values[6] = 0.0
			values[7] = 10.0
			values[8] = 0.0
		values[2] = 0.0
	if hinge.opened != 0:
		var d := Vector3(clam.x, clam.y + 2.0, 10.0) - player
		var distance := d.length()
		d = d.normalized()
		values[6] = distance * 4.0 * d.x
		values[7] = distance * 4.0 * d.y
		values[8] = distance * 4.0 * d.z
		var wanted := PULL_TURN_BACK if (heading <= 0.0 or 3.1415927 < heading) else PULL_TURN
		var gap := angle_gap(wanted, heading)
		values[2] = -PULL_TURN if gap[0] == -1 else PULL_TURN


## FUN_0051F00B(brick): a brick has reached the surface: its place on the board lights up, the dolphin
## is told how to leap, the count goes up and the zone speaks.
static func brick_delivered(brick) -> void:
	var shown := [[51, 83, 1], [89, 84, 1], [90, 85, 2], [91, 86, 1], [92, 87, 2]]
	for row in shown:
		if brick.index == row[0]:
			services.record_at(row[1]).flags |= 2
			dolphin_hint = row[2]
	bricks_taken += 1
	if 1 <= bricks_taken and bricks_taken <= 5:
		say("CASGBD%02d" % (7 + bricks_taken))


## FUN_0051EA90: the zone's reset (and part of its set-up).
const START_FRAMES := [[17, 30.0], [18, 45.0], [19, 15.0], [20, 33.0], [26, 30.0], [27, 25.0], [28, 27.0],
	[29, 35.0], [30, 37.0], [31, 30.0], [32, 10.0], [33, 25.0], [34, 27.0], [35, 30.0], [36, 23.0],
	[37, 35.0], [38, 17.0], [39, 23.0], [40, 40.0], [41, 27.0]]


static func start_over() -> void:
	for index in [83, 84, 85, 86, 87]:
		services.record_at(index).flags &= ~2
	air_used = 0.0
	bricks_taken = 0
	Game.set_var(0xC2, 0)
	finished = false
	finish_timer = 0.0
	halfway_said = false
	for row in START_FRAMES:
		services.anim_set_frame(services.record_at(row[0]), row[1])


## FUN_0051ED67: the twenty background animals play at half speed.
static func play_animals() -> void:
	for row in START_FRAMES:
		services.clip_finished(services.record_at(row[0]), 0.5)


## FUN_0051EF74 / FUN_0051EFCA / FUN_0051EFE4: the air runs out after 500 seconds; five bricks win.
static func air_left() -> float:
	return 100.0 - (air_used / 500.0) * 100.0


static func won() -> bool:
	return bricks_taken == 5


static func over() -> bool:
	return bricks_taken == 5 or air_left() < 0.0


## FUN_0051F2A3: the per-tick HUD and timers.
static var gauge := 120.0


static func tick_hud() -> void:
	air_used = dt + air_used
	var left := maxf(air_left(), 0.0)
	gauge = left * 1.2
	if left <= 50.0 and not halfway_said:
		say("CASGBD07")
		halfway_said = true
