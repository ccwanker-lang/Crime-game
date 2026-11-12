class_name Car
extends AnimatableBody3D
## AI car driving along a Traffic route (right-hand traffic).
##
## HOST AUTHORITATIVE: the host moves the car along its route, brakes for
## anything in front (cars, pedestrians, players) and syncs net_pos / net_yaw /
## net_speed; clients smooth towards that and spin the wheels. The body is on
## layer 2 (solid for players, hit by bullets, not baked into the navmesh).

const CRUISE: float = 8.5         # m/s (~30 km/h)
const CORNER_SPEED: float = 4.5
const ACCEL: float = 2.5
const BRAKE: float = 9.0
const SENSE_MASK: int = 2 | 4 | 8  # cars/props, npcs, players
## Waiting this long for another car: assume a deadlock and creep on through it.
const DEADLOCK_TIME: float = 12.0
## Ask for a junction this far before its edge (m, from the front bumper).
const JUNCTION_APPROACH: float = 9.0
## Lane check ahead: this many boxes of SENSE_LEN metres along the route.
const SENSE_SEGMENTS: int = 3
const SENSE_LEN: float = 4.5

@export var kind: int = 0
@export var color_seed: int = 0
@export var route_id: int = 0
## Host: distance driven along the route (m).
@export var progress: float = 0.0

var net_pos: Vector3 = Vector3.ZERO
var net_yaw: float = 0.0
var net_speed: float = 0.0

var speed: float = 0.0
## Host: what made it stop last (debug/tests): "", "car", "person", "junction".
var blocked_by: String = ""
var _wheels: Array[Node3D] = []
var _wheel_sign: Array[float] = []  # left wheels face the other way
var _wait_car: float = 0.0
var _ignore_cars: float = 0.0
var _hold: float = 0.0  # stay stopped this long after the way is clear (no creeping)
var _sense_shape := BoxShape3D.new()


func _ready() -> void:
	add_to_group(&"cars")
	collision_layer = 2
	collision_mask = 0
	sync_to_physics = false  # we set the transform directly each physics frame
	var rng := RandomNumberGenerator.new()
	rng.seed = color_seed
	var paint: Color = ProcCar.PAINTS[rng.randi() % ProcCar.PAINTS.size()]
	ProcCar.build(self, kind, paint)
	for c: Node in get_children():
		if c.name.begins_with("Wheel"):
			_wheels.append(c as Node3D)
			_wheel_sign.append(1.0 if (c as Node3D).position.x > 0.0 else -1.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = ProcCar.collision_size(kind)
	shape.shape = box
	shape.position.y = 0.3 + box.size.y / 2.0
	add_child(shape)
	Net.limit_sync_to_world($Sync)
	if _is_host():
		_place(_route().sample(progress))
		net_pos = global_position
		net_yaw = rotation.y
	else:
		global_position = net_pos
		rotation.y = net_yaw


func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _route() -> TrafficRoute:
	return (get_parent() as Traffic).routes[route_id]


func _physics_process(delta: float) -> void:
	if not _is_host():
		if global_position.distance_to(net_pos) > 6.0:
			global_position = net_pos
		else:
			global_position = global_position.lerp(net_pos, minf(1.0, 10.0 * delta))
		rotation.y = lerp_angle(rotation.y, net_yaw, minf(1.0, 10.0 * delta))
		_spin_wheels(net_speed, delta)
		return
	var route: TrafficRoute = _route()
	# Slow down for corners ahead, stop for anything in the way.
	var target: float = CRUISE
	if route.turn_ahead(progress, 9.0) > 0.35:
		target = CORNER_SPEED
	# Something in the lane: slow down by its distance, stop when it's close.
	var seen: Array = _sense(route)
	var blocker: String = seen[0] if seen[1] == 0 else ""
	blocked_by = blocker
	if seen[0] != "":
		target = minf(target, sqrt(2.0 * 5.0 * maxf(0.0, SENSE_LEN * seen[1] - 1.5)))
	if blocker != "":
		_hold = 0.8
	_hold = maxf(0.0, _hold - delta)
	if _hold > 0.0:
		target = 0.0
	target = minf(target, _junction_limit(route, seen))
	if blocker == "car":
		_wait_car += delta
		if _wait_car > DEADLOCK_TIME:
			_ignore_cars = 2.5
			_wait_car = 0.0
	else:
		_wait_car = 0.0
	_ignore_cars = maxf(0.0, _ignore_cars - delta)
	speed = move_toward(speed, target, (ACCEL if target > speed else BRAKE) * delta)
	progress = fposmod(progress + speed * delta, route.length)
	_place(route.sample(progress))
	_spin_wheels(speed, delta)
	net_pos = global_position
	net_yaw = rotation.y
	net_speed = speed


## Host: claims the junctions the car is in or about to enter and releases the
## ones behind it. Returns the speed limit (0 = wait at the junction edge).
func _junction_limit(route: TrafficRoute, seen: Array) -> float:
	var traffic: Traffic = get_parent() as Traffic
	var hl: float = ProcCar.collision_size(kind).z / 2.0
	var front: float = progress + hl
	var needed: Dictionary = {}
	var limit: float = INF
	var car_ahead: float = SENSE_LEN * seen[1] if seen[0] == "car" else INF
	for st: Array in route.junctions:
		var j: int = st[2]
		var ahead: float = fposmod(st[0] - front, route.length)
		var occupying: bool = fposmod(front - st[0], route.length) < (st[1] - st[0]) + 2.0 * hl
		if occupying:
			needed[j] = true
		elif ahead < JUNCTION_APPROACH and car_ahead > ahead:
			needed[j] = true
			if not traffic.request_junction(j, self):
				limit = minf(limit, sqrt(2.0 * 5.0 * maxf(0.0, ahead - 0.5)))
				if ahead < 1.5:
					blocked_by = "junction"
	for st: Array in route.junctions:
		var j: int = st[2]
		if needed.has(j):
			traffic.request_junction(j, self)
		else:
			traffic.release_junction(j, self)
	return limit


func _exit_tree() -> void:
	var traffic: Traffic = get_parent() as Traffic
	if traffic and _is_host():
		for j: int in Traffic.JUNCTIONS.size():
			traffic.release_junction(j, self)


## Car transform from a route sample [position, direction].
func _place(sample: Array) -> void:
	var pos: Vector3 = sample[0]
	var dir: Vector3 = sample[1]
	global_position = pos
	rotation.y = atan2(-dir.x, -dir.z)


## Host: what is in the lane ahead? Checks SENSE_SEGMENTS boxes following the
## route from the front bumper on; returns [what ("car"/"person"/""), segment].
func _sense(route: TrafficRoute) -> Array:
	var half_len: float = ProcCar.collision_size(kind).z / 2.0
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	_sense_shape.size = Vector3(1.7, 1.4, SENSE_LEN)
	q.shape = _sense_shape
	q.collision_mask = SENSE_MASK
	q.exclude = [get_rid()]
	for k: int in SENSE_SEGMENTS:
		var ahead: Array = route.sample(progress + half_len + SENSE_LEN * (k + 0.5))
		var dir: Vector3 = ahead[1]
		q.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), (ahead[0] as Vector3) + Vector3.UP * 0.9)
		var what: String = ""
		for hit: Dictionary in space.intersect_shape(q, 6):
			var c: Object = hit["collider"]
			if c is Pedestrian or c is Player:
				what = "person"
				break
			if c is Car and _ignore_cars <= 0.0:
				what = "car"
		if what != "":
			return [what, k]
	return ["", -1]


func _spin_wheels(v: float, delta: float) -> void:
	var turn: float = -v * delta / ProcCar.WHEEL_R
	for i: int in _wheels.size():
		_wheels[i].rotate_object_local(Vector3.RIGHT, turn * _wheel_sign[i])
