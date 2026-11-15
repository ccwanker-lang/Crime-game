class_name AmbientCat
extends Node3D
## Roadmap 68 (session B): an ambient street cat, LOCAL on every peer (no collision, no networking; made by
## `Wildlife`). Sits on a pavement / in a garden (tail swishing), strolls to another spot nearby (straight lines; a
## forward ray stops it at walls, a down ray keeps it on the ground), and bolts away from a player who comes close,
## a car on top of it or a gunshot. More strolling at night.

enum State { SIT, WALK, FLEE }

const COATS: Array = [
	[Color(0.07, 0.07, 0.08), Color(0.12, 0.12, 0.13)],
	[Color(0.85, 0.5, 0.2), Color(0.95, 0.85, 0.7)],
	[Color(0.45, 0.45, 0.47), Color(0.75, 0.75, 0.76)],
	[Color(0.9, 0.88, 0.84), Color(0.97, 0.96, 0.94)],
	[Color(0.4, 0.3, 0.2), Color(0.8, 0.72, 0.6)],
]
const WALK_SPEED: float = 0.9
const FLEE_SPEED: float = 5.5
const SCARE_DIST: float = 4.5
const FLEE_DIST: Vector2 = Vector2(9.0, 15.0)
const HIP_Y: float = 0.2

var wildlife: Wildlife
var state: State = State.SIT
var flees: int = 0
var blocked: int = 0

var _to: Vector3
var _timer: float = 0.0
var _check: float = 0.0
var _ray_t: float = 0.0
var _phase: float = 0.0
var _rng := RandomNumberGenerator.new()
var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _legs: Array[Node3D] = []


func setup(w: Wildlife, seed_value: int) -> void:
	wildlife = w
	_rng.seed = seed_value


func _ready() -> void:
	var coat: Array = COATS[_rng.randi() % COATS.size()]
	scale = Vector3.ONE * _rng.randf_range(0.9, 1.1)
	_body = Node3D.new()
	_body.position = Vector3(0, HIP_Y + 0.05, 0)
	add_child(_body)
	_body.add_child(CritterMesh.instance(CritterMesh.cat_body(coat[0], coat[1])))
	_head = Node3D.new()
	_head.position = Vector3(0, 0.08, -0.17)
	_body.add_child(_head)
	_head.add_child(CritterMesh.instance(CritterMesh.cat_head(coat[0])))
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.03, 0.16)
	_body.add_child(_tail)
	_tail.add_child(CritterMesh.instance(CritterMesh.cat_tail(coat[0])))
	var leg: ArrayMesh = CritterMesh.cat_leg(coat[0])
	for p: Vector3 in [Vector3(-0.04, -0.03, -0.12), Vector3(0.04, -0.03, -0.12), Vector3(-0.04, -0.03, 0.12), Vector3(0.04, -0.03, 0.12)]:
		var l := Node3D.new()
		l.position = p
		_body.add_child(l)
		l.add_child(CritterMesh.instance(leg))
		_legs.append(l)
	_phase = _rng.randf() * TAU
	_sit(_rng.randf_range(2.0, 20.0))


func _process(delta: float) -> void:
	if wildlife == null:
		return
	if state != State.FLEE and not wildlife.near_view(global_position):
		return
	_phase += delta
	_check -= delta
	if _check <= 0.0 and state != State.FLEE:
		_check = 0.25
		var t: Dictionary = wildlife.nearest_threat(global_position)
		if not t.is_empty() and float(t["dist"]) < (3.0 if t["car"] else SCARE_DIST):
			scare(t["pos"])
	match state:
		State.SIT:
			_timer -= delta
			if _timer <= 0.0:
				_wander()
		_:
			_move(delta)
	_animate(delta)


## Bolts away from `from`.
func scare(from: Vector3) -> void:
	var away: Vector3 = (global_position - from) * Vector3(1, 0, 1)
	if away.length() < 0.1:
		away = Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1))
	away = away.normalized().rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
	_to = global_position + away * _rng.randf_range(FLEE_DIST.x, FLEE_DIST.y)
	state = State.FLEE
	flees += 1


func _sit(time: float) -> void:
	state = State.SIT
	_timer = time


func _wander() -> void:
	var spot: Vector3 = wildlife.cat_spot_near(global_position, 25.0, _rng)
	if spot == Vector3.INF:
		spot = global_position + Vector3(_rng.randf_range(-5, 5), 0, _rng.randf_range(-5, 5))
	_to = spot
	state = State.WALK


func _move(delta: float) -> void:
	var d: Vector3 = (_to - global_position) * Vector3(1, 0, 1)
	var sp: float = FLEE_SPEED if state == State.FLEE else WALK_SPEED
	if d.length() < 0.2:
		_sit(_rng.randf_range(4.0, 12.0) if wildlife.is_night() else _rng.randf_range(8.0, 30.0))
		return
	var dir: Vector3 = d.normalized()
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 10.0))
	_ray_t -= delta
	if _ray_t <= 0.0:
		_ray_t = 0.12
		var ground: float = wildlife.ground_y(global_position + dir * 0.4, global_position.y)
		if wildlife.wall_ahead(global_position, dir, 0.6) or is_nan(ground) or absf(ground - global_position.y) > 0.35:
			blocked += 1
			if state == State.FLEE:
				# Turn and keep running for a bit.
				var turn: Vector3 = dir.rotated(Vector3.UP, (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(1.2, 2.2))
				_to = global_position + turn * _rng.randf_range(3.0, 6.0)
				if blocked % 4 == 0:
					_sit(_rng.randf_range(5.0, 12.0))
			else:
				_sit(_rng.randf_range(3.0, 8.0))
			return
		global_position.y = ground
	global_position += dir * minf(d.length(), sp * delta)


func _animate(delta: float) -> void:
	var moving: bool = state != State.SIT
	var freq: float = 14.0 if state == State.FLEE else 7.0
	for i: int in _legs.size():
		var off: float = 0.0 if i in [0, 3] else PI
		_legs[i].rotation.x = sin(_phase * freq + off) * (0.7 if state == State.FLEE else 0.45) if moving else 0.0
	if state == State.SIT:
		# Sitting: front up, hind legs folded; the tail swishes.
		_body.rotation.x = lerpf(_body.rotation.x, 0.5, minf(1.0, delta * 6.0))
		_body.position.y = lerpf(_body.position.y, HIP_Y - 0.02, minf(1.0, delta * 6.0))
		_legs[2].rotation.x = -1.2
		_legs[3].rotation.x = -1.2
		_tail.rotation = Vector3(-0.2, sin(_phase * 1.6) * 0.5, 0)
		_head.rotation.x = -0.45 + sin(_phase * 0.3) * 0.1
	else:
		_body.rotation.x = lerpf(_body.rotation.x, 0.0, minf(1.0, delta * 8.0))
		_body.position.y = HIP_Y + 0.05 + absf(sin(_phase * freq)) * (0.03 if state == State.FLEE else 0.0)
		_tail.rotation = Vector3(0.6 if state == State.FLEE else 0.25, sin(_phase * 3.0) * 0.15, 0)
		_head.rotation.x = 0.0
	_head.rotation.y = 0.0 if moving else sin(_phase * 0.7) * 0.6
