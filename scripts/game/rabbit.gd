class_name Rabbit
extends RefCounted

const TICK_RATE := 30.0
const RANGE_SCALE := 8.0
const NEAR_RATIO := 0.5
const YAW_STEP := 0.25
const YAW_SNAP := 0.1
const FAR := 1.0e38
const CLIP_BY_STATE := {0: 1, 1: 3, 2: 2, 6: 4}
const RUN_CHANCE := 0.93
const RUN_SCALE := 1.5
const ARRIVE := 1.0
const DIVE_PITCH := 0.75
const DIVE_DEPTH := 2.0
const RUN_COUNTER := 100
const SETTLE_LIMIT := 10

var node: MeshInstance3D
var skin: SkinnedMesh
var blk: BlkFile
var home := Vector3.ZERO
var position := Vector3.ZERO
var yaw := 0.0
var sight := 0.0
var sight_squared := 0.0
var near_squared := 0.0
var speed := 0.0
var state := 2
var counter := 0
var settled := 0
var time := 0.0
var clock := 0.0
var rng := RandomNumberGenerator.new()
var waypoints: Array = []
var waypoint := 0
var pitch := 0.0
var basis_fn: Callable


func setup(sight_param: float, speed_param: float, start: Vector3, start_yaw: float) -> void:
	sight = sight_param * RANGE_SCALE
	sight_squared = sight * sight
	var near := sight * NEAR_RATIO
	near_squared = near * near
	speed = speed_param * RANGE_SCALE
	home = start
	position = start
	yaw = start_yaw
	state = 2
	rng.randomize()
	_enter_clip(2)


func forward() -> Vector3:
	return Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))


func update(delta: float, ground: Callable) -> void:
	clock += delta * TICK_RATE
	while clock >= 1.0:
		clock -= 1.0
		_tick(ground)
	_apply()


func _tick(ground: Callable) -> void:
	var step := 1.0 if state == 0 or state == 1 or state == 6 else 2.0
	time += step
	var frames := 1.0
	if blk != null and CLIP_BY_STATE.get(state, 2) < blk.anims.size():
		frames = maxf(float(blk.anims[CLIP_BY_STATE.get(state, 2)].frames), 1.0)
	var finished := false
	if time > frames - 1.0:
		time = fmod(time, maxf(frames - 1.0, 1.0))
		finished = true
	if finished:
		counter -= 1
		if counter < 0:
			_choose_state()
		elif state == 2:
			_turn_toward_home()
	if state == 2:
		var gap := home - position
		var squared := FAR
		if gap.x <= sight and gap.z <= sight:
			squared = gap.length_squared()
		if sight_squared < squared:
			var wanted := atan2(gap.x, gap.z)
			if absf(yaw - wanted) > YAW_SNAP:
				yaw = wanted
		position += forward() * speed
		_follow_ground(ground)
	elif state == 3:
		var gap: Vector3 = waypoints[waypoint] - position
		if absf(gap.x) < ARRIVE and absf(gap.z) < ARRIVE:
			state = 4
			pitch = DIVE_PITCH
		else:
			position += forward() * speed * RUN_SCALE
			_follow_ground(ground)
	elif state == 4:
		if waypoints[waypoint].y - position.y > DIVE_DEPTH:
			state = 5
			yaw = wrapf(yaw + PI, -PI, PI)
			pitch = -DIVE_PITCH
			var next := waypoint
			while next == waypoint:
				next = mini(int(rng.randf() * 3.0), 2)
			var offset: Vector3 = position - waypoints[waypoint]
			waypoint = next
			position = offset + waypoints[waypoint]
		else:
			position += forward() * speed * RUN_SCALE
	elif state == 5:
		if waypoints[waypoint].y - position.y < 0.0:
			state = 2
			counter = int(rng.randf() * 4.0) + 2
			pitch = 0.0
		else:
			position += forward() * speed * RUN_SCALE


func _follow_ground(ground: Callable) -> void:
	var floor_y: float = ground.call(position)
	if floor_y > -INF:
		position.y = floor_y


func _turn_toward_home() -> void:
	var gap := home - position
	var squared := FAR
	if gap.x <= sight and gap.z <= sight:
		squared = gap.length_squared()
	if squared <= near_squared:
		yaw += (YAW_SNAP - rng.randf())
	else:
		var wanted := atan2(gap.x, gap.z)
		var difference := wanted - yaw
		if difference > PI:
			difference -= TAU
		elif difference < -PI:
			difference += TAU
		if absf(difference) >= YAW_STEP:
			yaw += YAW_STEP if difference >= 0.0 else -YAW_STEP
		else:
			yaw = wanted
	yaw = wrapf(yaw, -PI, PI)


func _choose_state() -> void:
	if state == 6:
		_set_state(2)
		return
	if settled < SETTLE_LIMIT:
		settled += 1
	elif rng.randf() > RUN_CHANCE and waypoints.size() >= 3:
		settled = 0
		waypoint = mini(int(rng.randf() * 3.0), 2)
		_set_state(3)
		return
	var next := state
	while next == state:
		next = mini(int(rng.randf() * 4.0), 2)
	_set_state(next)


func _set_state(next: int) -> void:
	state = next
	match next:
		0:
			counter = int(rng.randf() * 2.0)
		1:
			counter = 0
		2:
			counter = int(rng.randf() * 5.0)
			_turn_toward_home()
		3:
			counter = RUN_COUNTER
			var gap: Vector3 = waypoints[waypoint] - position
			yaw = atan2(gap.x, gap.z)
		6:
			counter = 0
	_enter_clip(next)


func _enter_clip(for_state: int) -> void:
	time = 0.0


func _apply() -> void:
	if node == null:
		return
	node.position = Vector3(position.x, position.y, -position.z)
	if basis_fn.is_valid():
		node.basis = basis_fn.call(pitch, yaw, 0.0)
	else:
		node.rotation.y = -yaw
	if skin != null and blk != null:
		var clip: int = CLIP_BY_STATE.get(state, 2)
		var pose := blk.pose(clip, int(time))
		if pose.size() >= blk.offsets.size():
			skin.update(pose)
			node.mesh = skin.mesh
