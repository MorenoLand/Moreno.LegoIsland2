class_name Swimmer
extends Behaviour

## FUN_00528399 (ctor) / FUN_00526828 (update, vtable 0x008C5FC8, returns 2). Pepper in the dive: he swims
## on the z = 10 plane, turning with the left / right keys and pushing along his heading with the
## up / down keys; the steering block holds the turn rate, heading and velocity (the same layout as
## DiveSteering: +8 turn rate, +0x14 heading, +0x18 / +0x1C velocity, +0x24 turn push, +0x28 turn
## damping, +0x2C thrust, +0x30 drag). He picks bricks up, carries one at a time to the surface,
## is thrown about by fish, the anchor, the octopus arm and cannon balls, and is pulled in by the clam.
##
## Node: +0x1C outline in use (two outlines at +0x28 / +0x58), +0x20 outline wanted, +0xB8 clam sound
## latch, +0xBC steering block, +0xF0 last good position, +0xFC last good heading, +0x100 blocked
## frames, +0x104 the brick he holds, +0x108 / +0x10C / +0x110 timers, +0x114 flicker toggle, +0x118
## which model shows, +0x11C brick-near state, +0x121 surface flag, +0x122 swim sounds on, +0x124
## breath counter.

const SURFACE := 86.5
const OUTLINES := [
	[Vector3(1.0, 4.0, 10.0), Vector3(-1.0, 4.0, 10.0), Vector3(-1.0, 0.0, 10.0), Vector3(1.0, 0.0, 10.0)],
	[Vector3(1.0, 7.0, 10.0), Vector3(-1.0, 7.0, 10.0), Vector3(-1.0, 0.0, 10.0), Vector3(1.0, 0.0, 10.0)],
]
## The debug fill the exe leaves in a stack slot nobody writes (0xCCCCCCCC as a float).
const FILL := Vector3(-1.0737418e+08, -1.0737418e+08, -1.0737418e+08)
## FUN_00533070's sound handles (global address of each).
const S_BREATH := 0x5D4C804
const S_DEEP_A := 0x5D4C810
const S_DEEP_B := 0x5D4C854
const S_MID := 0x5D4C808
const S_SURFACE := 0x5D4C824
const S_SPLASH := 0x5D4C80C
const S_AIR_A := 0x5D4C83C
const S_AIR_B := 0x5D4C840
const S_FISH_A := 0x5D4C818
const S_FISH_B := 0x5D4C81C
const S_ANCHOR := 0x5D4C820
const S_CLAM_NEAR := 0x5D4C82C
const S_CHEST := 0x5D4C828
const S_BALL := 0x5D4C814
const S_OCTOPUS := 0x5D4C7EC
const S_CLAM_HOLD := 0x5D4C800
const S_BLOCKED := 0x5D4C7FC
const S_GRAB := 0x5D4C848
const S_DROP := 0x5D4C850
const S_DELIVER := 0x5D4C858
const S_PAGE := 0x5D4C838
const S_SWIM_A := 0x5D4C7F4
const S_SWIM_B := 0x5D4C830

var steering := DiveSteering.new()
var outline_set := 0
var outline_wanted := 0
var clam_latch := 0
var last_good := Vector3.ZERO
var last_heading := 0.0
var blocked := 0
var held = null
var stun_hit := 0.0
var stun_flash := 0.0
var stun_c := 0.0
var flicker := 0
var view_mode := 0
var brick_near := 0
var at_surface := true
var swim_sounds := true
var breath := 0
var bubbles := 0

var services: ActorServices
var actor_record = null
var solids: Array = []


static func from_descriptor(desc: Descriptor, services_in: ActorServices, actor) -> Swimmer:
	var b := Swimmer.new()
	b.services = services_in
	b.actor_record = actor
	DiveWorld.swimmer = b
	b.bubbles = services_in.particle_create("bubble01.par", actor, Vector3(0.0, 4.0, 0.0), Vector3(0.0, -DiveWorld.PI_F, 0.0), [2, 1, 1])
	services_in.particle_attach(b.bubbles, services_in.record_at(1))
	services_in.record_at(93).flags |= 0x20
	services_in.particle_attach(b.bubbles, services_in.record_at(93))
	services_in.particle_attach(b.bubbles, services_in.record_at(DiveWorld.R_CLAM))
	actor.x = 0.0
	actor.y = 82.5
	actor.z = 10.0
	b.last_good = Vector3(actor.x, actor.y, actor.z)
	b.last_heading = 0.0
	b.steering.load_block(desc, 0)
	b._set_view(0)
	b._mode(0)
	services_in.set_clip(services_in.record_at(DiveWorld.R_SWIMMER_HURT), 3, 0.0)
	for index in [1, 54, 72, 69, 52, 53, 51, 89, 90, 91, 92, 67, 56, 59, 60, 61, 62, 63, 64, 65, 66, 82, 57]:
		b.solids.append(services_in.record_at(index))
	return b


func configure(_mask_in: int, _value_in: int) -> void:
	pass


## FUN_00527F33: which of the two models is shown.
func _set_view(mode: int) -> void:
	view_mode = mode
	var hurt = services.record_at(DiveWorld.R_SWIMMER_HURT)
	var normal = services.record_at(DiveWorld.R_SWIMMER)
	if mode == 1:
		hurt.flags |= 2
		normal.flags &= ~2
	else:
		hurt.flags &= ~2
		normal.flags |= 2


## FUN_00527D99: the swimmer's pose.
func _mode(which: int) -> void:
	var swimmer = services.record_at(DiveWorld.R_SWIMMER)
	match which:
		0:
			services.set_clip(swimmer, 1, 0.0)
		1, 2:
			services.set_clip(swimmer, 2, 0.0)
		3:
			swim_sounds = false


## FUN_00527D14: change pose keeping the frame.
func _pose(which: int) -> void:
	var swimmer = services.record_at(DiveWorld.R_SWIMMER)
	var start := services.anim_frame(swimmer)
	if which == 0:
		services.set_clip(swimmer, 1, start)
	elif which == 1:
		services.set_clip(swimmer, 2, start)


## FUN_00522370: the shove fish and the like give. The exe reads three floats of its own outline
## block (the z of the first point, the x and y of the second) and doubles them with z cleared.
func _shove() -> void:
	var set_a: Array = OUTLINES[0]
	steering.values[6] = (set_a[0].z) * 2.0
	steering.values[7] = (set_a[1].x) * 2.0
	steering.values[8] = 0.0


## FUN_00527AC1: let go of the brick.
func drop() -> void:
	if held == null:
		return
	services.sound_play(S_DROP)
	var swimmer = actor_record
	var matrix := ActorServices.rotation_rows(swimmer.field_f(0x4C), swimmer.yaw, swimmer.field_f(0x54))
	var spot := RecordCollision.rotate(matrix, Vector3(-1.0, 4.0, 0.0)) + Vector3(swimmer.x, swimmer.y, swimmer.z)
	_behaviour_of(held, DiveBrick).drop(held, spot)
	held = null
	_mode(0)
	outline_wanted = 0


## FUN_00527B97: take a brick.
func _grab(brick) -> void:
	if held != null:
		return
	if not _behaviour_of(brick, DiveBrick).take(brick):
		return
	held = brick
	_mode(2)
	services.sound_play(S_GRAB)
	outline_wanted = 1
	if brick == services.record_at(DiveWorld.R_BRICKS[4]):
		for index in DiveWorld.R_PIRATES:
			var pirate = _behaviour_of(services.record_at(index), DivePirate)
			if pirate != null:
				pirate.enable()


## FUN_00527C56: arrive at the surface with a brick.
func deliver() -> void:
	if held == null:
		return
	services.sound_play(S_DELIVER)
	DiveWorld.brick_delivered(held)
	held = null
	_mode(0)
	outline_wanted = 0


## FUN_00527CD9: the page.
func _take_page(page) -> void:
	page.flags &= ~2
	services.sound_play(S_PAGE)
	Game.set_var(0xC2, 1)
	DiveWorld.finished = true
	DiveWorld.finish_timer = 4.0


func _behaviour_of(record, kind):
	var item = record.block.head if record.block != null else null
	while item != null:
		if is_instance_of(item, kind):
			return item
		item = item.next
	return null


## FUN_005278E4: what a record of the zone is to the swimmer.
func _role(record) -> int:
	var index: int = record.index
	if index == 1 or index == 57 or index == 72:
		return 0
	if index == 69:
		return 7
	if DiveWorld.R_BRICKS.has(index):
		return 1
	if index == 82:
		return 2
	if index == 54:
		return 3
	if index == 52:
		return 4
	if index == 53:
		return 5
	if DiveWorld.R_BALLS.has(index):
		return 6
	return -1


func _outline_at(set_index: int, heading: float, spot: Vector3) -> PackedVector3Array:
	var points := DiveWorld.rotate_points(PackedVector3Array(OUTLINES[set_index]), heading + 1.5707964)
	for i in points.size():
		points[i] = Vector3(spot.x + points[i].x, spot.y + points[i].y, points[i].z)
	return points


func update(actor, _block: BehaviourBlock, _var_value: int) -> int:
	var dt := DiveWorld.dt
	var values := steering.values
	var turn_push := 0.0
	var thrust := 0.0
	var keys: int = services.talk.game_flags_b
	if keys != 0 and stun_hit == 0.0:
		if (keys & 1) != 0:
			turn_push = 0.0 - values[9]
		if (keys & 2) != 0:
			turn_push = turn_push + values[9]
		if (keys & 4) != 0:
			thrust = values[11] + 0.0
		if (keys & 8) != 0:
			thrust = thrust - values[11]
	var prev := Vector3(actor.x, actor.y, actor.z)
	values[2] = (turn_push + values[2] * values[10]) * dt + values[2]
	var heading := DiveWorld.wrap_angle(values[2] * dt + values[5])
	var ahead := Vector3(cos(heading + 1.5707964), sin(heading + 1.5707964), 0.0)
	values[6] = (ahead.x * thrust + values[6] * values[12]) * dt + values[6]
	values[7] = (ahead.y * thrust + values[7] * values[12]) * dt + values[7]
	var spot := Vector3(values[6] * dt + prev.x, values[7] * dt + prev.y, 10.0)
	if spot.y <= SURFACE:
		if breath == 0:
			services.sound_play(S_BREATH)
		else:
			breath += 1
			if 180.0 < float(breath):
				breath = 0
		services.sound_release(S_SURFACE)
		if at_surface:
			services.sound_play(S_SPLASH)
			at_surface = false
		if SURFACE <= spot.y or spot.y <= 0.0:
			if 0.0 <= spot.y or spot.y <= -100.0:
				if spot.y < -100.0:
					services.sound_play(S_DEEP_A)
					services.sound_release(S_DEEP_B)
			else:
				services.sound_play(S_DEEP_B)
				services.sound_release(S_MID)
				services.sound_release(S_DEEP_A)
		else:
			services.sound_play(S_MID)
			services.sound_release(S_DEEP_B)
	else:
		deliver()
		spot.y = SURFACE
		services.sound_play(S_SURFACE)
		services.sound_release(S_MID)
		var gulp := int(services.random_float(dt * 60.0))
		if float(gulp) <= dt * 50.0:
			if float(gulp) < dt * 10.0:
				services.sound_play(S_AIR_A)
		else:
			services.sound_play(S_AIR_B)
		at_surface = true
	var points := _outline_at(outline_set, heading, spot)
	var group := DiveWorld.group_hit(points)
	match int(group["kind"]) - 1:
		0:
			drop()
			_shove()
		1:
			drop()
			_shove()
			stun_flash = 2.0
			stun_hit = 2.0
			if int(services.random_float(2.0)) < 1:
				services.sound_play(S_FISH_B)
			else:
				services.sound_play(S_FISH_A)
			DiveWorld.say("CASGBD05")
		2:
			drop()
			_shove()
		3:
			var pirate = _behaviour_of(group["record"], DivePirate)
			if pirate != null and pirate.attacking():
				pirate.rest()
				drop()
	var blocked_now := false
	var touch_clam := false
	var touch_chest := false
	var touches := DiveWorld.edge_hits(points, actor, solids)
	var normal: Vector3 = touches["normal"]
	var point: Vector3 = touches["point"]
	for record in touches["records"]:
		match _role(record):
			0:
				blocked_now = true
			1:
				_grab(record)
			2:
				_take_page(record)
			3:
				var push := DiveWorld.bump(record, DiveWorld.anchor_speed(record), record.field_f(0x54), prev)
				values[6] = push.x
				values[7] = push.y
				values[8] = push.z
				values[2] = DiveWorld.side_turn(prev, point, FILL)
				services.sound_play(S_ANCHOR)
				drop()
			4:
				services.sound_play(S_CLAM_NEAR)
				touch_clam = true
			5:
				services.sound_play(S_CHEST)
				touch_chest = true
			6:
				services.sound_play(S_BALL)
				var ball: CannonBall = _behaviour_of(record, CannonBall)
				var speed: Vector3 = ball.velocity
				values[6] = speed.x
				values[7] = speed.y
				values[8] = speed.z
				values[2] = DiveWorld.side_turn(prev, point, FILL)
				ball.retire(record)
				drop()
			7:
				var arm = services.record_at(DiveWorld.R_OCTOPUS_ARM)
				var shove := DiveWorld.bump(arm, DiveWorld.octopus_speed(), arm.field_f(0x54) + 1.5707964, prev)
				values[6] = shove.x
				values[7] = shove.y
				values[8] = shove.z
				services.sound_play(S_OCTOPUS)
				drop()
	var clam = services.record_at(DiveWorld.R_CLAM)
	var clam_hinge: ClamHinge = _behaviour_of(clam, ClamHinge)
	if clam_hinge.opened == 0:
		services.sound_release(S_CLAM_HOLD)
		clam_latch = 0
	else:
		touch_clam = true
		touch_chest = false
		if clam_latch == 0:
			services.sound_play(S_CLAM_HOLD)
			clam_latch = 1
	if touch_clam:
		DiveWorld.clam_pull(clam, clam_hinge, prev, heading, self)
	if touch_chest:
		blocked_now = true
	if blocked_now:
		blocked += 1
	if blocked == 2:
		blocked = 0
		actor.x = last_good.x
		actor.y = last_good.y
		actor.z = 10.0
		values[5] = last_heading
		values[6] = 0.0
		values[7] = 0.0
		values[2] = 0.0
	elif not blocked_now:
		if outline_set != outline_wanted:
			if outline_wanted == 0:
				outline_set = 0
			else:
				if DiveWorld.edge_hits(_outline_at(1, heading, spot), actor, solids)["records"].is_empty():
					outline_set = 1
		blocked = 0
		last_good = Vector3(spot.x, spot.y, 10.0)
		last_heading = heading
		actor.x = spot.x
		actor.y = spot.y
		actor.z = 10.0
		values[5] = heading
		actor.set_field_f(0x54, heading)
		actor.yaw = -heading
		if view_mode != 0:
			var hurt = services.record_at(DiveWorld.R_SWIMMER_HURT)
			hurt.x = actor.x
			hurt.y = actor.y
			hurt.z = actor.z
			hurt.set_field_f(0x4C, actor.field_f(0x4C))
			hurt.yaw = 0.0
			hurt.set_field_f(0x54, actor.field_f(0x54))
	else:
		var wall_angle := atan2(normal.x, normal.z)
		var gap := DiveWorld.angle_gap(wall_angle, heading)
		services.sound_play(S_BLOCKED)
		if gap[0] == 1:
			values[2] = values[2] - ((1.0 - gap[1]) + (1.0 - gap[1]))
		if gap[0] == -1:
			values[2] = (1.0 - gap[1]) + (1.0 - gap[1]) + values[2]
		values[6] = (1.0 - gap[1]) * 2.8 * normal.x
		values[7] = (1.0 - gap[1]) * 2.8 * normal.y
	_flicker(dt)
	_timers(dt)
	_near_bricks()
	if stun_hit == 0.0:
		services.clip_finished(actor, 1.0)
	services.clip_finished(services.record_at(DiveWorld.R_SWIMMER_HURT), 1.0)
	if swim_sounds:
		var frame := services.anim_frame(actor)
		if frame < 16.0:
			services.sound_release(S_SWIM_A)
			services.sound_play(S_SWIM_B)
		else:
			services.sound_release(S_SWIM_B)
			services.sound_play(S_SWIM_A)
	return 2


## FUN_00527FCE: the hurt flash swaps the two models.
func _flicker(dt: float) -> void:
	if stun_flash == 0.0:
		return
	if view_mode != 1:
		_set_view(1)
		flicker = 0
	if flicker != 0:
		swim_sounds = false
	flicker ^= 1
	stun_flash -= dt
	if stun_flash < 0.0:
		stun_flash = 0.0
		_set_view(0)
		swim_sounds = true


## FUN_005280C6
func _timers(dt: float) -> void:
	if stun_c != 0.0:
		stun_c -= dt
		if stun_c < 0.0:
			stun_c = 0.0
	if stun_hit != 0.0:
		stun_hit -= dt
		if stun_hit < 0.0:
			stun_hit = 0.0


## FUN_0052818A: reaching for a brick when one is within 10 units and nothing is carried.
func _near_bricks() -> void:
	if held != null:
		return
	var swimmer = actor_record
	var near := false
	for index in DiveWorld.R_BRICKS:
		var brick = services.record_at(index)
		var d := Vector3(brick.x - swimmer.x, brick.y - swimmer.y, brick.z - swimmer.z)
		if d.length_squared() < 100.0:
			if brick_near != 1 or view_mode == 1:
				_pose(1)
				brick_near = 1
			near = true
			break
	if not near and (brick_near != 0 or view_mode == 1):
		_pose(0)
		brick_near = 0
