class_name SwiftFlock
extends RefCounted

const TICK_RATE := 30.0
const PATH_RATE := 0.0001
const FORMATION_DROP := 16.0
const STEER_SCALE := 0.125
const THRESHOLD := 1.0
const TURN_RATE := 0.0333
const SPEED := 2.0
const BANK_RANGE := PI / 4.0
const BANK_CENTRE := PI / 8.0
const BANK_TICKS := 20
const FLIGHT_CLIP := 1
const CLIP_STEP := 2.0
const HEADER_BYTES := 12
const FRAME_BYTES := 36
const POSITION_OFFSET := 12

var points: PackedVector3Array = PackedVector3Array()
var time := 0.0
var clock := 0.0
var followers: Array = []
var blk: BlkFile
var rng := RandomNumberGenerator.new()


static func load_points(bytes: PackedByteArray) -> PackedVector3Array:
	var out := PackedVector3Array()
	if bytes.size() < HEADER_BYTES + FRAME_BYTES:
		return out
	var count := (bytes.size() - HEADER_BYTES) / FRAME_BYTES
	for i in count:
		var at := HEADER_BYTES + i * FRAME_BYTES + POSITION_OFFSET
		out.append(Vector3(bytes.decode_float(at), bytes.decode_float(at + 4), bytes.decode_float(at + 8)))
	return out


func add_follower(node: MeshInstance3D, skin: SkinnedMesh, start: Vector3, basis_fn: Callable) -> void:
	followers.append({
		"node": node, "skin": skin, "position": start, "yaw": 0.0, "pitch": 0.0, "roll": 0.0,
		"near": false, "count": 0, "bank_pitch": 0.0, "bank_yaw": 0.0, "clip_time": 0.0, "basis": basis_fn,
	})
	rng.randomize()


func sample(t: float) -> Vector3:
	var n := points.size()
	if n == 0:
		return Vector3.ZERO
	var u := t * n
	var i := int(floor(u))
	var f := u - i
	var p0 := points[clampi(i - 1, 0, n - 1)]
	var p1 := points[clampi(i, 0, n - 1)]
	var p2 := points[clampi(i + 1, 0, n - 1)]
	var p3 := points[clampi(i + 2, 0, n - 1)]
	var f2 := f * f
	var f3 := f2 * f
	return 0.5 * ((2.0 * p1) + (p2 - p0) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * f3)


func update(delta: float) -> void:
	clock += delta * TICK_RATE
	while clock >= 1.0:
		clock -= 1.0
		_tick()
	for follower in followers:
		_apply(follower)


func _tick() -> void:
	time += PATH_RATE
	if time >= 1.0:
		time = 0.0
	var target := sample(time) - Vector3(0.0, FORMATION_DROP, 0.0)
	for follower in followers:
		_fly(follower, target)


func _fly(follower: Dictionary, target: Vector3) -> void:
	var position: Vector3 = follower.position
	var gap := target - position
	var distance := gap.length()
	var step := distance * STEER_SCALE
	if THRESHOLD < step:
		var wanted_yaw := atan2(gap.x, gap.z)
		var wanted_pitch := atan2(-gap.y, sqrt(gap.x * gap.x + gap.z * gap.z))
		var limit := step * TURN_RATE
		follower.yaw = _turn(follower.yaw, wanted_yaw, limit)
		follower.pitch = _turn(follower.pitch, wanted_pitch, limit)
		follower.near = false
	else:
		if not follower.near:
			follower.near = true
			follower.count = 0
			follower.bank_pitch = BANK_CENTRE - rng.randf() * BANK_RANGE
			follower.bank_yaw = BANK_CENTRE - rng.randf() * BANK_RANGE
		else:
			var before: int = follower.count
			follower.count += 1
			if before < BANK_TICKS:
				follower.pitch = wrapf(follower.pitch + follower.bank_pitch, -PI, PI)
				follower.yaw = wrapf(follower.yaw + follower.bank_yaw, -PI, PI)
	var yaw: float = follower.yaw
	var pitch: float = follower.pitch
	var forward := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	follower.position = position + forward * SPEED
	follower.clip_time += CLIP_STEP


func _turn(current: float, wanted: float, limit: float) -> float:
	var difference := wanted - current
	if difference > PI:
		difference -= TAU
	elif difference < -PI:
		difference += TAU
	if absf(difference) < limit:
		return wanted
	return wrapf(current + (limit if difference >= 0.0 else -limit), -PI, PI)


func _apply(follower: Dictionary) -> void:
	var node: MeshInstance3D = follower.node
	if node == null:
		return
	var position: Vector3 = follower.position
	node.position = Vector3(position.x, position.y, -position.z)
	var basis_fn: Callable = follower.basis
	if basis_fn.is_valid():
		node.basis = basis_fn.call(follower.pitch, follower.yaw, follower.roll)
	var skin: SkinnedMesh = follower.skin
	if skin != null and blk != null and FLIGHT_CLIP < blk.anims.size():
		var frames: int = maxi(int(blk.anims[FLIGHT_CLIP].frames), 1)
		var pose := blk.pose(FLIGHT_CLIP, int(follower.clip_time) % frames)
		if pose.size() >= blk.offsets.size():
			skin.update(pose)
			node.mesh = skin.mesh
