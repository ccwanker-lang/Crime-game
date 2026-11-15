class_name AmbientBird
extends Node3D
## Roadmap 68 (session B): one ambient bird, LOCAL on every peer (no collision, no networking; made by `Wildlife`).
## Kinds:
## - BIRD: sits on roof ridges / gutters, looks round, now and then flies to another roof (an arc with flapping wings
##   and glides), a gunshot sends it off.
## - PIGEON: one of a flock on the ground (park, shop fronts): walks, pecks, head bobs. A player or car close by or a
##   gunshot -> the flock flies up onto a roof; after a while it comes back down (not at night: then it stays up).
## - DUCK: swims on the sea by the quay (bobs on the same waves as the water shader), dabbles; swims away from
##   people on the quay edge, a gunshot makes it fly low over the water and land further on.

enum Kind { BIRD, PIGEON, DUCK }
enum State { SIT, WALK, FLY, SWIM }

const LOOKS: Dictionary = {
	Kind.BIRD: [[Color(0.22, 0.18, 0.15), Color(0.55, 0.45, 0.35), Color(0.2, 0.17, 0.14), Color(0.9, 0.65, 0.15)],
			[Color(0.08, 0.08, 0.09), Color(0.12, 0.12, 0.13), Color(0.08, 0.08, 0.09), Color(0.95, 0.65, 0.1)],
			[Color(0.45, 0.33, 0.22), Color(0.8, 0.72, 0.6), Color(0.35, 0.3, 0.28), Color(0.3, 0.25, 0.2)]],
	Kind.PIGEON: [[Color(0.5, 0.52, 0.58), Color(0.6, 0.62, 0.66), Color(0.34, 0.4, 0.44), Color(0.2, 0.2, 0.22)],
			[Color(0.42, 0.43, 0.48), Color(0.55, 0.56, 0.6), Color(0.3, 0.42, 0.38), Color(0.2, 0.2, 0.22)],
			[Color(0.72, 0.7, 0.68), Color(0.82, 0.8, 0.78), Color(0.55, 0.55, 0.58), Color(0.25, 0.22, 0.2)]],
	Kind.DUCK: [[Color(0.5, 0.4, 0.3), Color(0.62, 0.55, 0.45), Color(0.1, 0.38, 0.2), Color(0.95, 0.75, 0.15)],
			[Color(0.55, 0.42, 0.3), Color(0.68, 0.58, 0.45), Color(0.5, 0.38, 0.28), Color(0.85, 0.55, 0.2)]],
}
## Size per kind (a sparrow-sized mesh scaled up).
const SIZE: Dictionary = { Kind.BIRD: 1.0, Kind.PIGEON: 1.7, Kind.DUCK: 2.5 }
const FLY_SPEED: Dictionary = { Kind.BIRD: 9.0, Kind.PIGEON: 7.5, Kind.DUCK: 8.0 }
## A player / car this close scares it (pigeons fly, ducks swim away; roof birds only if someone is on the roof).
const NEAR: Dictionary = { Kind.BIRD: 3.0, Kind.PIGEON: 3.2, Kind.DUCK: 6.0 }
const CAR_NEAR: float = 5.0

## Seconds a scared pigeon flock stays on the roof (tests shorten it).
static var return_time: Vector2 = Vector2(12.0, 28.0)

var kind: Kind = Kind.BIRD
var wildlife: Wildlife
var state: State = State.SIT
## Pigeons: the flock's ground spot (they walk within FLOCK_R of it). Ducks: unused.
var home: Vector3 = Vector3.INF
var flock: int = -1
## True while a pigeon waits on a roof after a scare.
var up_on_roof: bool = false
var flights: int = 0
var scares: int = 0

var _from: Vector3
var _to: Vector3
var _arc: float = 0.0
var _t: float = 0.0
var _dur: float = 1.0
var _timer: float = 0.0
var _check: float = 0.0
var _phase: float = 0.0
var _land_yaw: float = 0.0
var _then: State = State.SIT
var _body: Node3D
var _head: Node3D
var _wing_l: Node3D
var _wing_r: Node3D
var _look_timer: float = 0.0
var _head_yaw_goal: float = 0.0
var _peck: float = 0.0
var _rng := RandomNumberGenerator.new()

const FLOCK_R: float = 2.6


func setup(k: Kind, w: Wildlife, seed_value: int) -> void:
	kind = k
	wildlife = w
	_rng.seed = seed_value


func _ready() -> void:
	var looks: Array = LOOKS[kind]
	var look: Array = looks[_rng.randi() % looks.size()]
	var duck: bool = kind == Kind.DUCK
	_body = Node3D.new()
	add_child(_body)
	_body.scale = Vector3.ONE * float(SIZE[kind]) * _rng.randf_range(0.9, 1.1)
	_body.add_child(CritterMesh.instance(CritterMesh.bird_body(look[0], look[1], duck)))
	_head = Node3D.new()
	_head.position = Vector3(0, 0.1 if duck else 0.13, -0.08)
	_body.add_child(_head)
	_head.add_child(CritterMesh.instance(CritterMesh.bird_head(look[2], look[3], duck)))
	var wing: ArrayMesh = CritterMesh.bird_wing(look[0], look[0].darkened(0.3))
	_wing_r = Node3D.new()
	_wing_r.position = Vector3(0.04, 0.11 if not duck else 0.07, -0.02)
	_body.add_child(_wing_r)
	_wing_r.add_child(CritterMesh.instance(wing))
	_wing_l = Node3D.new()
	_wing_l.position = Vector3(-0.04, _wing_r.position.y, -0.02)
	_wing_l.scale = Vector3(-1, 1, 1)
	_body.add_child(_wing_l)
	_wing_l.add_child(CritterMesh.instance(wing))
	_phase = _rng.randf() * TAU
	_timer = _rng.randf_range(4.0, 40.0)
	if kind == Kind.DUCK:
		state = State.SWIM
		_pick_swim()
	_fold(1.0)


## Folds (1) or spreads (0) the wings.
func _fold(f: float) -> void:
	# Folded = lying back along the body sides.
	_wing_r.rotation = Vector3(0, -1.35 * f, -0.25 * f)
	_wing_l.rotation = Vector3(0, 1.35 * f, 0.25 * f)
	_wing_l.scale = Vector3(-1, 1, 1)


func _process(delta: float) -> void:
	if wildlife == null:
		return
	if state != State.FLY and not wildlife.near_view(global_position):
		return
	_phase += delta
	_check -= delta
	if _check <= 0.0 and state != State.FLY:
		_check = 0.25
		_check_threats()
	match state:
		State.FLY:
			_fly_step(delta)
		State.SWIM:
			_swim_step(delta)
		State.WALK:
			_walk_step(delta)
		_:
			_sit_step(delta)
	_animate_head(delta)


# --- Behaviour ----------------------------------------------------------------------------------------------------

func _check_threats() -> void:
	var near: float = float(NEAR[kind])
	var t: Dictionary = wildlife.nearest_threat(global_position)
	if t.is_empty():
		return
	var d: float = t["dist"]
	var is_car: bool = t["car"]
	if kind == Kind.DUCK:
		if d < near:
			_swim_away(t["pos"])
		return
	if d < (CAR_NEAR if is_car else near):
		scare(t["pos"])


## Something frightening at `from` (gunshot, player, car).
func scare(from: Vector3) -> void:
	scares += 1
	match kind:
		Kind.PIGEON:
			if up_on_roof and state != State.FLY:
				_timer = _rng.randf_range(return_time.x, return_time.y)
				return
			wildlife.flock_up(flock, from)
		Kind.DUCK:
			if state == State.FLY:
				return
			# Away from the shot, but inside the duck water: of a few headings the one that ends furthest from it.
			var best: Vector3 = global_position
			var best_d: float = -1.0
			for i: int in 10:
				var dir := Vector3(0, 0, 1).rotated(Vector3.UP, i * TAU / 10.0 + _rng.randf() * 0.3)
				var p: Vector3 = wildlife.water_point_near(global_position + dir * _rng.randf_range(16.0, 28.0))
				if p.distance_to(global_position) < 12.0:
					continue
				var d: float = p.distance_to(from)
				if d > best_d:
					best_d = d
					best = p
			if best_d < 0.0:
				best = wildlife.water_point_near(global_position + (global_position - from) * Vector3(1, 0, 1))
			fly_to(best, 2.5, State.SWIM)
		_:
			if state == State.FLY:
				return
			var spot: Dictionary = wildlife.roof_spot_near(global_position, 70.0, 12.0)
			if not spot.is_empty():
				fly_to(spot["pos"], 6.0, State.SIT, spot["yaw"])


## Pigeon: (flock) flies up onto `spot`.
func flee_to_roof(spot: Dictionary) -> void:
	up_on_roof = true
	var off := Vector3(_rng.randf_range(-1.2, 1.2), 0, 0).rotated(Vector3.UP, float(spot["yaw"]))
	fly_to(spot["pos"] + off, 4.0, State.SIT, float(spot["yaw"]) + _rng.randf_range(-0.4, 0.4))
	_timer = _dur + _rng.randf_range(return_time.x, return_time.y)


## Starts a flight to `target` (an arc `arc` m above the straight line), then `then` (SIT / SWIM).
func fly_to(target: Vector3, arc: float, then: State = State.SIT, land_yaw: float = NAN) -> void:
	_from = global_position
	_to = target
	var dist: float = _from.distance_to(_to)
	_arc = arc + dist * 0.12
	_dur = maxf(0.6, dist / float(FLY_SPEED[kind]))
	_t = 0.0
	_then = then
	_land_yaw = land_yaw if not is_nan(land_yaw) else _rng.randf() * TAU
	state = State.FLY
	flights += 1


func _fly_step(delta: float) -> void:
	_t = minf(1.0, _t + delta / _dur)
	# Ease in/out so the take-off and landing are slow.
	var s: float = smoothstep(0.0, 1.0, _t)
	var p: Vector3 = _from.lerp(_to, s) + Vector3.UP * (4.0 * _arc * s * (1.0 - s))
	var dir: Vector3 = p - global_position
	global_position = p
	if Vector2(dir.x, dir.z).length() > 0.001:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 10.0))
	_body.rotation.x = clampf(dir.y / maxf(0.001, delta) * 0.06, -0.5, 0.5)
	# Flapping; glide in the middle of a long flight.
	var gliding: bool = _dur > 3.0 and _t > 0.3 and _t < 0.7 and fmod(_phase, 2.0) < 1.1
	var flap: float = 0.0 if gliding else sin(_phase * (22.0 if kind == Kind.BIRD else 15.0)) * 1.0
	_wing_r.rotation = Vector3(0, 0, flap + (0.08 if gliding else 0.0))
	_wing_l.rotation = Vector3(0, 0, -flap - (0.08 if gliding else 0.0))
	if _t >= 1.0:
		_body.rotation.x = 0.0
		rotation.y = _land_yaw
		_fold(1.0)
		state = _then
		if state == State.SWIM:
			_pick_swim()
		elif kind == Kind.BIRD:
			_timer = _rng.randf_range(20.0, 80.0)


func _sit_step(delta: float) -> void:
	_timer -= delta
	if kind == Kind.PIGEON:
		if up_on_roof:
			if _timer <= 0.0:
				if wildlife.is_night():
					_timer = 20.0  # (stays on the roof until morning)
				else:
					up_on_roof = false
					fly_to(wildlife.flock_point(flock, _rng), 3.0, State.SIT)
					_timer = _rng.randf_range(1.0, 4.0)
			return
		# On the ground: peck, then a few steps.
		_peck = maxf(0.0, _peck - delta)
		if _peck <= 0.0 and _rng.randf() < delta * 0.8:
			_peck = 0.35
		if _timer <= 0.0:
			_to = wildlife.flock_point(flock, _rng)
			state = State.WALK
		return
	if _timer <= 0.0:
		_timer = _rng.randf_range(25.0, 90.0)
		if wildlife.is_night():
			return
		var spot: Dictionary = wildlife.roof_spot_near(global_position, 60.0, 4.0)
		if not spot.is_empty():
			fly_to(spot["pos"], 5.0, State.SIT, spot["yaw"])


func _walk_step(delta: float) -> void:
	var d: Vector3 = (_to - global_position) * Vector3(1, 0, 1)
	var step: float = 0.45 * delta
	if d.length() <= step:
		global_position = Vector3(_to.x, global_position.y, _to.z)
		state = State.SIT
		_timer = _rng.randf_range(1.5, 6.0)
		return
	global_position += d.normalized() * step
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(1.0, delta * 8.0))
	# Head bob while walking.
	_head.position.z = -0.08 + sin(_phase * 12.0) * 0.012


func _pick_swim() -> void:
	_to = wildlife.water_point_near(global_position + Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6)))
	_timer = _rng.randf_range(6.0, 16.0)


func _swim_away(from: Vector3) -> void:
	var away: Vector3 = (global_position - from) * Vector3(1, 0, 1)
	if away.length() < 0.1:
		away = Vector3(0, 0, 1)
	_to = wildlife.water_point_near(global_position + away.normalized() * 9.0)
	_timer = 10.0


func _swim_step(delta: float) -> void:
	_timer -= delta
	var d: Vector3 = (_to - global_position) * Vector3(1, 0, 1)
	if d.length() > 0.3:
		var sp: float = 0.45 if _timer < 9.0 else 1.1
		global_position += d.normalized() * minf(d.length(), sp * delta)
		rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(1.0, delta * 2.0))
	elif _timer <= 0.0:
		_pick_swim()
	global_position.y = wildlife.water_y_at(global_position)
	# Dabbling now and then.
	_peck = maxf(0.0, _peck - delta)
	if _peck <= 0.0 and _rng.randf() < delta * 0.08:
		_peck = 1.4
	_body.rotation.x = -1.0 if _peck > 0.3 else lerpf(_body.rotation.x, 0.0, minf(1.0, delta * 4.0))


func _animate_head(delta: float) -> void:
	_look_timer -= delta
	if _look_timer <= 0.0:
		_look_timer = _rng.randf_range(0.4, 2.0)
		_head_yaw_goal = _rng.randf_range(-1.0, 1.0)
	_head.rotation.y = lerp_angle(_head.rotation.y, _head_yaw_goal if state != State.FLY else 0.0, minf(1.0, delta * 12.0))
	_head.rotation.x = -0.9 if (kind == Kind.PIGEON and state == State.SIT and not up_on_roof and _peck > 0.15) else 0.0


## Tests: the wing rotation (changes while flapping).
func wing_angle() -> float:
	return _wing_r.rotation.z
