class_name Car
extends AnimatableBody3D
## AI car driving along a Traffic route (right-hand traffic).
##
## HOST AUTHORITATIVE: the host moves the car along its route, brakes for
## anything in front (cars, pedestrians, players) and syncs net_pos / net_yaw /
## net_speed; clients smooth towards that and spin the wheels. The body is on
## layer 2 (solid for players, hit by bullets, not baked into the navmesh).
##
## Gunfire (host): a shot within HEAR_DISTANCE panics the car for PANIC_TIME (faster,
## honks, swerves) or, close by, it stops and the driver gets out and runs. A car that
## is shot always stops and the driver runs; at 0 health it is a wreck that is towed
## away (removed) after WRECK_TIME and Traffic brings a new car. A fled driver walks
## back after DRIVER_AWAY and drives on. Cars behind a stopped car wait and honk.

const CRUISE: float = 8.5         # m/s (~30 km/h)
## Sideways grip in bends (m/s2): bend speed = sqrt(LAT_ACCEL * radius).
const LAT_ACCEL: float = 2.4
## Comfortable braking towards a bend (m/s2).
const BEND_BRAKE: float = 2.8
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
const HEAR_DISTANCE: float = 35.0
const PANIC_TIME: float = 10.0
## Point 32: a panicking car never stops for people (honks, squeezes past at this speed).
const PANIC_MIN_SPEED: float = 3.5
const PANIC_SPEED: float = 1.5  # x CRUISE
const MAX_HEALTH: int = 150
const DRIVER_AWAY: float = 8.0  # a stopped (not wrecked) car drives on after this
const WRECK_TIME: float = 20.0
const SWERVE_TIME: float = 1.2
const HORN := preload("res://assets/audio/vehicles/car_horn.ogg")
const HORN_SHORT := preload("res://assets/audio/vehicles/car_horn_short.ogg")

@export var kind: int = 0
@export var color_seed: int = 0
@export var route_id: int = 0
## Point 10: a police patrol car (white with blue stripes and a light bar). It doesn't
## panic: a crime nearby (report_crime) stops it and the officer gets out and takes
## the culprit on; afterwards the officer gets back in and it patrols on.
@export var police: bool = false
## Synced: the light bar flashes (officer out on a call).
var siren: bool = false:
	set(v):
		siren = v
		for l: OmniLight3D in _bar_lights:
			l.visible = v
		if not v:
			for m: MeshInstance3D in _bar_meshes:
				m.visible = false
## Host: distance driven along the route (m).
@export var progress: float = 0.0

var net_pos: Vector3 = Vector3.ZERO
var net_yaw: float = 0.0
var net_speed: float = 0.0

## Tests: "panic" / "uturn" forces the reaction to a gunshot ("" = by where the shot was).
static var force_reaction: String = ""
## Point 23: one horn at a time in the whole town (msec of the last honk).
static var _last_honk_ms: int = -100000
const HONK_GAP_MS: int = 1800
const HONK_CHANCE: float = 0.35
## Point 24: a shot ahead closer than this makes the car turn round.
const UTURN_DISTANCE: float = 30.0
const UTURN_TIME: float = 2.2
## Host: U-turn in progress ({} = none): from transform, target route + progress, time.
var _uturn: Dictionary = {}

var speed: float = 0.0
## Host: stopped with nobody at the wheel (driver fled) / shot to pieces.
var abandoned: bool = false
var wrecked: bool = false
var health: int = MAX_HEALTH
var panic: float = 0.0  # host: seconds of panic left
var _swerve: float = 0.0  # host: seconds of swerve left
var _swerve_side: float = 1.0
var _driver: Node = null  # the pedestrian that got out
var _ahead_stopped: bool = false  # host: the car ahead is abandoned (wait, don't creep through)
var _honk_cooldown: float = 0.0
var _horn: AudioStreamPlayer3D
## Host: what made it stop last (debug/tests): "", "car", "person", "junction".
var blocked_by: String = ""
var _wheels: Array[Node3D] = []
var _wheel_sign: Array[float] = []  # left wheels face the other way
var _wait_car: float = 0.0
var _ignore_cars: float = 0.0
var _steer: float = 0.0  # front wheel angle (rad, + = left)
var _steer_pivots: Array[Node3D] = []
var _hold: float = 0.0  # stay stopped this long after the way is clear (no creeping)
var _sense_shape := BoxShape3D.new()
var _bar_lights: Array[OmniLight3D] = []
## Host (police car): officers in the car, and the ones out on a call.
var crew_size: int = 2
var crew_out: Array[PoliceOfficer] = []
var _bar_meshes: Array[MeshInstance3D] = []
## Point 28 (wanted system, host): sent after a wanted player (removed when done), the
## player it is after, a heavy team (SMGs), parked across the road as a road block.
var dispatched: bool = false
var chase: Player = null
var heavy: bool = false
var roadblock: bool = false
var _chase_t: float = 0.0
var _chase_best: float = INF       # closest it got to the last known spot
var _chase_at: Vector3 = Vector3.INF
var _responded_at: Vector3 = Vector3.INF
## Point 30 (host, patrol cars): seconds until it looks for someone to question; officers
## that stayed in the car meanwhile.
var question_in: float = -1.0
var _in_car: int = 0
const QUESTION_EVERY: Vector2 = Vector2(50.0, 110.0)
var _flash_t: float = 0.0


func _ready() -> void:
	add_to_group(&"cars")
	collision_layer = 2
	collision_mask = 0
	sync_to_physics = false  # we set the transform directly each physics frame
	var rng := RandomNumberGenerator.new()
	rng.seed = color_seed
	var paint: Color = ProcCar.PAINTS[rng.randi() % ProcCar.PAINTS.size()]
	if police:
		paint = Color(0.92, 0.93, 0.95)
		add_to_group(&"police")
	ProcCar.build(self, kind, paint)
	if police:
		_build_police_gear()
	for c: Node in find_children("Wheel*", "", true, false):
		var w := c as Node3D
		_wheels.append(w)
		_wheel_sign.append(1.0 if w.rotation.y == 0.0 else -1.0)  # left wheels are turned around
	for c: Node in find_children("Steer*", "", true, false):
		_steer_pivots.append(c as Node3D)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = ProcCar.collision_size(kind)
	shape.shape = box
	shape.position.y = 0.3 + box.size.y / 2.0
	add_child(shape)
	_horn = AudioStreamPlayer3D.new()
	_horn.unit_size = 5.0
	_horn.volume_db = -12.0
	_horn.max_distance = 55.0
	_horn.position = Vector3(0, 0.8, -1.5)
	add_child(_horn)
	Net.limit_sync_to_world($Sync)
	if _is_host():
		_place_on(_route())
		net_pos = global_position
		net_yaw = rotation.y
	else:
		global_position = net_pos
		rotation.y = net_yaw


func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _route() -> TrafficRoute:
	return (get_parent() as Traffic).routes[route_id]


func _process(delta: float) -> void:
	if not siren or _bar_lights.size() != 2:
		return
	# Alternate the two lamps of the light bar.
	_flash_t += delta
	var left: bool = fmod(_flash_t, 0.5) < 0.25
	_bar_lights[0].light_energy = 2.0 if left else 0.0
	_bar_lights[1].light_energy = 0.0 if left else 2.0
	_bar_meshes[0].visible = left
	_bar_meshes[1].visible = not left


## Blue/yellow side stripes, "POLICE" on the doors and a roof light bar.
func _build_police_gear() -> void:
	var s: Dictionary = ProcCar.SPECS[kind]
	var hw: float = float(s["w"]) / 2.0 + 0.004
	var hl: float = float(s["len"]) / 2.0
	var roof: float = float(s["roof"])
	var stripe_y: float = float(s["body"]) - 0.22
	var b := MeshBuilder.new()
	b.color = Color(0.05, 0.15, 0.6)
	for side: float in [-1.0, 1.0]:
		b.box(&"item_glossy", Vector3(side * hw, stripe_y, 0.0), Vector3(0.01, 0.16, hl * 1.7))
	b.color = Color(0.95, 0.75, 0.1)
	for side: float in [-1.0, 1.0]:
		b.box(&"item_glossy", Vector3(side * hw, stripe_y - 0.11, 0.0), Vector3(0.01, 0.05, hl * 1.7))
	b.color = Color(0.1, 0.1, 0.12)
	var cab: float = (float(s["cab_f"]) + float(s["cab_b"])) / 2.0
	b.box(&"item_matte", Vector3(0, roof + 0.03, cab), Vector3(1.1, 0.07, 0.22))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	for side: float in [-1.0, 1.0]:
		var c: Color = Color(0.35, 0.5, 1.0) if side < 0 else Color(1.0, 0.25, 0.2)
		var lb := MeshBuilder.new()
		lb.color = c
		lb.box(&"item_glossy", Vector3(side * 0.3, roof + 0.1, cab), Vector3(0.42, 0.08, 0.18))
		var dim := MeshInstance3D.new()
		dim.mesh = lb.build()
		add_child(dim)
		var gm := StandardMaterial3D.new()
		gm.albedo_color = c
		gm.emission_enabled = true
		gm.emission = c
		gm.emission_energy_multiplier = 6.0
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var box := BoxMesh.new()
		box.size = Vector3(0.43, 0.085, 0.19)
		box.material = gm
		var glow := MeshInstance3D.new()
		glow.mesh = box
		glow.position = Vector3(side * 0.3, roof + 0.1, cab)
		glow.visible = false
		add_child(glow)
		_bar_meshes.append(glow)
		var light := OmniLight3D.new()
		light.light_color = c
		light.omni_range = 7.0
		light.position = Vector3(side * 0.3, roof + 0.35, cab)
		light.visible = false
		add_child(light)
		_bar_lights.append(light)
	for side: float in [-1.0, 1.0]:
		var label := Label3D.new()
		label.text = "POLICE"
		label.font_size = 64
		label.pixel_size = 0.004
		label.modulate = Color(0.05, 0.15, 0.6)
		label.outline_size = 0
		label.position = Vector3(side * (hw + 0.006), stripe_y + 0.2, cab - 0.2)
		label.rotation.y = side * PI / 2.0
		label.double_sided = false
		add_child(label)
	siren = siren


func _physics_process(delta: float) -> void:
	if not _is_host():
		if global_position.distance_to(net_pos) > 6.0:
			global_position = net_pos
		else:
			global_position = global_position.lerp(net_pos, minf(1.0, 10.0 * delta))
		var yaw0: float = rotation.y
		rotation.y = lerp_angle(rotation.y, net_yaw, minf(1.0, 10.0 * delta))
		# Steering from the turn rate: angle = atan(wheelbase * yaw rate / speed).
		var rate: float = angle_difference(yaw0, rotation.y) / maxf(delta, 0.001)
		var base: float = float(ProcCar.SPECS[kind]["base"])
		var want: float = atan(base * rate / net_speed) if net_speed > 0.5 else _steer
		_steer = lerpf(_steer, clampf(want, -0.6, 0.6), minf(1.0, 8.0 * delta))
		_spin_wheels(net_speed, delta)
		return
	var route: TrafficRoute = _route()
	_honk_cooldown = maxf(0.0, _honk_cooldown - delta)
	if abandoned:
		# Nobody at the wheel: roll to a stop and stay there.
		speed = move_toward(speed, 0.0, BRAKE * delta)
		progress = fposmod(progress + speed * delta, route.length)
		_place_on(route)
		if roadblock:
			# Point 28: across the road, over the middle line.
			global_position -= global_basis.x * 1.75
			rotation.y += PI / 2.0
		_spin_wheels(speed, delta)
		net_pos = global_position
		net_yaw = rotation.y
		net_speed = speed
		return
	if not _uturn.is_empty():
		_drive_uturn(delta)
		return
	if police and chase != null:
		_chase_t -= delta
		if _chase_t <= 0.0:
			_chase_t = 0.4
			_check_chase()
	elif police and not dispatched and not roadblock and not siren and crew_size > 0:
		if question_in < 0.0:
			question_in = randf_range(QUESTION_EVERY.x, QUESTION_EVERY.y)
		question_in -= delta
		if question_in <= 0.0:
			question_in = 4.0  # nobody there: look again in a moment
			_try_question()
	panic = maxf(0.0, panic - delta)
	_swerve = maxf(0.0, _swerve - delta)
	# Slow down for corners ahead, stop for anything in the way (faster when panicking).
	var hurry: bool = panic > 0.0 or (police and siren)
	var target: float = CRUISE * (PANIC_SPEED if panic > 0.0 else 1.0)
	if police and siren and Wanted.current:
		target = CRUISE * Wanted.current.config.siren_speed
	target = minf(target, _bend_speed(route) * (1.25 if hurry else 1.0))
	# Something in the lane: slow down by its distance, stop when it's close.
	var seen: Array = _sense(route)
	var blocker: String = seen[0] if seen[1] == 0 else ""
	blocked_by = blocker
	var fleeing: bool = panic > 0.0 and not police
	if fleeing and seen[0] == "person":
		# Point 32: full panic: no stopping for people, a horn and a crawl past them.
		target = minf(target, maxf(PANIC_MIN_SPEED, sqrt(2.0 * 5.0 * maxf(0.0, SENSE_LEN * seen[1] - 1.5))))
		if _honk_cooldown <= 0.0:
			honk(false)
			_honk_cooldown = randf_range(3.0, 6.0)
		blocker = ""
	elif seen[0] != "":
		target = minf(target, sqrt(2.0 * 5.0 * maxf(0.0, SENSE_LEN * seen[1] - 1.5)))
	if blocker != "":
		_hold = 0.8
	_hold = maxf(0.0, _hold - delta)
	if _hold > 0.0 and not (fleeing and blocker != "car"):
		target = 0.0
	# Junctions: claimed as usual, but a panicking car drops the right of way and goes.
	var junction: float = _junction_limit(route, seen)
	if not fleeing:
		target = minf(target, junction)
	elif blocked_by == "junction":
		blocked_by = ""
	if blocker == "car" and _ahead_stopped:
		_wait_car = 0.0  # a stopped car ahead: wait (and toot) instead of creeping through it
		if _honk_cooldown <= 0.0 and speed < 0.5:
			if randf() < HONK_CHANCE:
				honk(false)
			_honk_cooldown = randf_range(12.0, 25.0)
	elif blocker == "car":
		_wait_car += delta
		if _wait_car > DEADLOCK_TIME:
			_ignore_cars = 2.5
			_wait_car = 0.0
	else:
		_wait_car = 0.0
	_ignore_cars = maxf(0.0, _ignore_cars - delta)
	speed = move_toward(speed, target, (ACCEL if target > speed else BRAKE) * delta)
	progress = fposmod(progress + speed * delta, route.length)
	_place_on(route)
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


## Host: fastest speed that still lets the car brake gently for every bend in
## the next 30 m and take it at sqrt(LAT_ACCEL * radius).
func _bend_speed(route: TrafficRoute) -> float:
	var limit: float = CRUISE
	var x: float = 0.0
	while x <= 30.0:
		var k: float = absf(route.curvature(progress + x))
		if k > 0.01:
			var v_bend: float = sqrt(LAT_ACCEL / k)
			limit = minf(limit, sqrt(v_bend * v_bend + 2.0 * BEND_BRAKE * maxf(0.0, x - 1.0)))
		x += 1.5
	return limit


## Host: puts the car on the route at `progress`: body between the axles, heading
## along the chord from the rear to the front axle (like a real car), front
## wheels steered into the bend.
func _place_on(route: TrafficRoute) -> void:
	var half_base: float = float(ProcCar.SPECS[kind]["base"]) / 2.0
	var front: Vector3 = route.sample(progress + half_base)[0]
	var rear: Vector3 = route.sample(progress - half_base)[0]
	global_position = (front + rear) * 0.5
	var dir: Vector3 = front - rear
	rotation.y = atan2(-dir.x, -dir.z)
	_steer = atan(2.0 * half_base * route.curvature(progress + half_base * 0.5))
	if _swerve > 0.0:
		# Swerve: a quick sideways jink in the lane (half a sine over SWERVE_TIME).
		var t: float = 1.0 - _swerve / SWERVE_TIME
		global_position += global_basis.x * (_swerve_side * 0.7 * sin(PI * t))
		_steer -= _swerve_side * 0.25 * cos(PI * t)


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
	_ahead_stopped = false
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
			if c is Car and ((c as Car).abandoned or _ignore_cars <= 0.0):
				what = "car"
				_ahead_stopped = _ahead_stopped or (c as Car).abandoned
		if what != "":
			return [what, k]
	return ["", -1]


func _spin_wheels(v: float, delta: float) -> void:
	for p: Node3D in _steer_pivots:
		p.rotation.y = _steer
	var turn: float = -v * delta / ProcCar.WHEEL_R
	for i: int in _wheels.size():
		_wheels[i].rotate_object_local(Vector3.RIGHT, turn * _wheel_sign[i])


# --- Gunfire (host) ------------------------------------------------------------------

## Host (group "cars", every shot): race off honking and swerving, or bail out when close.
## Host (point 24): drivers never get out. A shot ahead -> turn round and drive away;
## anywhere else -> speed off (and maybe a startled honk). Then the normal route again.
func hear_gunshot(origin: Vector3, _hit: bool = false) -> void:
	if not _is_host() or abandoned or police or not is_inside_tree():
		return
	var d: float = global_position.distance_to(origin)
	if d > HEAR_DISTANCE:
		return
	var to_shot: Vector3 = origin - global_position
	to_shot.y = 0.0
	var ahead: bool = to_shot.dot(-global_basis.z) > 0.3 * to_shot.length() and d < UTURN_DISTANCE
	if force_reaction != "":
		ahead = force_reaction == "uturn"
	if ahead and _uturn.is_empty() and start_uturn(origin):
		panic = PANIC_TIME + UTURN_TIME
		return
	if panic <= 0.0:
		if randf() < HONK_CHANCE:
			honk(true)
		if _uturn.is_empty():
			_swerve = SWERVE_TIME
			_swerve_side = -1.0 if randf() < 0.5 else 1.0
	panic = PANIC_TIME


## Host: turn round onto the other lane (any route there that heads away from `origin`).
## False if there is no such lane close by (then it just speeds on).
func start_uturn(origin: Vector3) -> bool:
	var traffic := get_parent() as Traffic
	if traffic == null:
		return false
	var spot: Array = traffic.find_escape(global_position, origin, -global_basis.z)
	if spot.is_empty():
		return false
	for j: int in Traffic.JUNCTIONS.size():
		traffic.release_junction(j, self)
	_uturn = {"from": global_transform, "route": int(spot[0]), "prog": float(spot[1]), "t": 0.0}
	_swerve = 0.0
	return true


func _drive_uturn(delta: float) -> void:
	_uturn["t"] = float(_uturn["t"]) + delta
	var s: float = clampf(float(_uturn["t"]) / UTURN_TIME, 0.0, 1.0)
	var e: float = s * s * (3.0 - 2.0 * s)
	var from: Transform3D = _uturn["from"]
	var route: TrafficRoute = (get_parent() as Traffic).routes[int(_uturn["route"])]
	var to: Array = route.sample(float(_uturn["prog"]))
	var to_pos: Vector3 = to[0]
	var to_dir: Vector3 = to[1]
	var a_yaw: float = from.basis.get_euler().y
	var b_yaw: float = atan2(-to_dir.x, -to_dir.z)
	var turn: float = fposmod(b_yaw - a_yaw, TAU)  # always round to the left (right-hand traffic)
	var fwd: Vector3 = -from.basis.z
	global_position = from.origin.lerp(to_pos, e) + fwd * sin(s * PI) * 3.0
	rotation.y = a_yaw + turn * e
	speed = 3.0
	_steer = 0.5
	_spin_wheels(speed, delta)
	net_pos = global_position
	net_yaw = rotation.y
	net_speed = speed
	if s >= 1.0:
		route_id = int(_uturn["route"])
		progress = float(_uturn["prog"])
		_uturn = {}
		_steer = 0.0
		_place_on(route)


## Host: a bullet hit the car: it stops and the driver runs. Cars don't "die" (returns false).
func host_damage(amount: int, attacker: Node = null, from: Vector3 = Vector3.INF) -> bool:
	if not _is_host() or wrecked or amount <= 0:
		return false
	health = maxi(0, health - amount)
	if health == 0:
		wrecked = true
	if police and attacker is Player:
		Wanted.report(attacker as Player, &"assault", (attacker as Player).global_position)
		if not abandoned:
			report_crime(attacker as Player, from if from != Vector3.INF else global_position, false)
		elif is_instance_valid(_driver) and _driver is PoliceOfficer:
			(_driver as PoliceOfficer)._alert(attacker as Player, (attacker as Player).global_position)
		return false
	if not wrecked and not police:
		# Point 24: a hit car speeds off (or turns round), the driver stays in.
		hear_gunshot(from if from != Vector3.INF else global_position, true)
		return false
	if not abandoned:
		abandon(from if from != Vector3.INF else global_position)
	return false


## Host (group "police"): a crime nearby. The car stops, its crew (point 25: officers
## belong to their car) gets out and goes after the culprit: shoot or arrest. When it's
## over (culprit dead / arrested / escaped) they walk back, get in and patrol on.
func report_crime(culprit: Player, origin: Vector3, murder: bool) -> void:
	if not _is_host() or not police or abandoned or wrecked or culprit == null or culprit.dead or crew_size <= 0:
		return
	if global_position.distance_to(origin) > (PoliceOfficer.MURDER_RANGE if murder else PoliceOfficer.HEAR_RANGE):
		return
	Wanted.report(culprit, &"heard", origin)  # point 28: the police heard it: at least 1 star
	respond(culprit, origin)


## Host (point 28): the car can see `p` (from the roof, nothing solid in between).
func can_see(p: Player) -> bool:
	var eye: Vector3 = global_position + Vector3.UP * 1.6
	var chest: Vector3 = p.global_position + Vector3.UP * 1.2
	var q := PhysicsRayQueryParameters3D.create(eye, chest, 1 | 2, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Host: go after `culprit` (seen / heard at `origin`): stop, crew out. A crew already out
## (or at a road block) takes the culprit on if it isn't busy.
func respond(culprit: Player, origin: Vector3) -> void:
	if not _is_host() or not police or wrecked or culprit == null or culprit.dead or crew_size <= 0:
		return
	if abandoned:
		for c: PoliceOfficer in _crew_alive():
			if c.target == null:
				c._alert(culprit, origin)
		return
	var world: Node = get_tree().current_scene
	if world == null or not world.has_method("add_officer"):
		return
	chase = culprit
	_responded_at = origin
	abandoned = true
	panic = 0.0
	_swerve = 0.0
	siren = true
	crew_out.clear()
	for i: int in crew_size:
		var side: Vector3 = global_position + global_basis.x * (1.4 if i == 0 else -1.4)
		side.y = global_position.y + 0.1
		var cop: PoliceOfficer = world.call("add_officer", side, global_position, self, heavy)
		cop._alert(culprit, origin)
		crew_out.append(cop)
	_driver = crew_out[0]
	print("[Police] patrol car %s stops, %d officer(s) out after %s" % [name, crew_out.size(), culprit.player_name])
	_police_come_back()


## Host: the crew members that are still alive.
func _crew_alive() -> Array[PoliceOfficer]:
	var out: Array[PoliceOfficer] = []
	for c: PoliceOfficer in crew_out:
		if is_instance_valid(c) and not c.dead:
			out.append(c)
	return out


func _crew_busy() -> bool:
	for c: PoliceOfficer in _crew_alive():
		if c.is_busy():
			return true
	return false


## Host (point 30): a pedestrian on the pavement just ahead on the right: stop (light bar
## on), one officer gets out, has a word with them, gets back in, and the car drives on.
func _try_question() -> void:
	var world: Node = get_tree().current_scene
	if world == null or not world.has_method("add_officer"):
		return
	var fwd: Vector3 = -global_basis.z
	var right: Vector3 = global_basis.x
	var pick: Pedestrian = null
	for n: Node in get_tree().get_nodes_in_group(&"npc"):
		var p := n as Pedestrian
		if p == null or p is PoliceOfficer or not p.free_for_talk():
			continue
		var d: Vector3 = p.global_position - global_position
		var ahead: float = d.dot(fwd)
		var side: float = d.dot(right)
		if ahead > 4.0 and ahead < 22.0 and side > 1.5 and side < 7.0:
			pick = p
			break
	if pick == null:
		return
	question_in = randf_range(QUESTION_EVERY.x, QUESTION_EVERY.y)
	abandoned = true
	panic = 0.0
	siren = true
	_in_car = crew_size - 1
	var door: Vector3 = global_position + right * 1.4
	door.y = global_position.y + 0.1
	var cop: PoliceOfficer = world.call("add_officer", door, global_position, self, heavy)
	crew_out.clear()
	crew_out.append(cop)
	_driver = cop
	print("[Police] patrol car %s stops to question %s" % [name, pick.name])
	await get_tree().create_timer(0.6).timeout  # (the officer's brain starts)
	if is_instance_valid(cop) and is_instance_valid(pick):
		cop.question(pick)
	await get_tree().create_timer(0.5).timeout
	_police_come_back()


func _police_come_back() -> void:
	# Wait until every officer is done, then they walk back and get in.
	while is_inside_tree() and _crew_busy():
		await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	var alive: Array[PoliceOfficer] = _crew_alive()
	crew_size = alive.size() + _in_car
	if alive.is_empty():
		# The whole crew is down: the car is towed and a new patrol turns up.
		await get_tree().create_timer(WRECK_TIME).timeout
		if is_inside_tree():
			(get_parent() as Traffic).replace_car(self)
		return
	await get_tree().create_timer(1.5).timeout
	for attempt: int in 3:
		var walking: Array = []
		for i: int in alive.size():
			var c: PoliceOfficer = alive[i]
			if is_instance_valid(c) and not c.dead and c.target == null:
				var door: Vector3 = global_position + global_basis.x * (1.4 if i == 0 else -1.4)
				if c.global_position.distance_to(door) > 2.5:
					walking.append(c)
					c.walk_to(door)
		if walking.is_empty():
			break
		await get_tree().create_timer(1.0).timeout
		while is_inside_tree() and walking.any(func(c: Variant) -> bool: return is_instance_valid(c) and (c as PoliceOfficer)._moving):
			await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	if _crew_busy():
		_police_come_back()  # a new call came in on the way back
		return
	for c: PoliceOfficer in _crew_alive():
		c.queue_free()
	crew_out.clear()
	_driver = null
	_in_car = 0
	abandoned = false
	# Point 28: still wanted -> drive on with the siren and look again; otherwise a sent
	# car drives off and disappears.
	var still: bool = chase != null and is_instance_valid(chase) and not chase.dead and chase.wanted_stars > 0
	siren = still
	_chase_best = INF
	if not still:
		chase = null
		if dispatched:
			_leave()


## Host (point 28): a sent car is near the last known spot (or passing it, or sees the
## player): stop and get out. No longer wanted: drive off.
func _check_chase() -> void:
	if not is_instance_valid(chase) or chase.dead or chase.wanted_stars == 0:
		chase = null
		siren = false
		if dispatched:
			_leave()
		return
	var at: Vector3 = Wanted.last_known(chase)
	if _chase_at == Vector3.INF or at.distance_to(_chase_at) > 10.0:
		_chase_at = at
		_chase_best = INF
	var d: float = global_position.distance_to(at)
	var sees: bool = global_position.distance_to(chase.global_position) < 30.0 and can_see(chase)
	var fresh: bool = _responded_at == Vector3.INF or at.distance_to(_responded_at) > 10.0
	var arrive: float = Wanted.current.config.arrive_distance if Wanted.current else 25.0
	var passing: bool = _chase_best < 60.0 and d > _chase_best + 3.0
	_chase_best = minf(_chase_best, d)
	if sees or (fresh and (d < arrive or passing)):
		respond(chase, chase.global_position if sees else at)


## Host: a sent car leaves; it is removed once no player is close.
func _leave() -> void:
	if not dispatched or is_queued_for_deletion():
		return
	dispatched = false  # (once)
	while is_inside_tree():
		await get_tree().create_timer(2.0).timeout
		if not is_inside_tree() or abandoned:
			return
		var near: bool = false
		for pl: Node in get_tree().get_nodes_in_group(&"players"):
			if (pl as Node3D).global_position.distance_to(global_position) < 55.0:
				near = true
		if not near:
			print("[Police] sent car %s goes off duty" % name)
			for j: int in Traffic.JUNCTIONS.size():
				(get_parent() as Traffic).release_junction(j, self)
			queue_free()
			return


## Host (point 28): park across the road with the light bar on; the crew stands guard
## next to it and takes on the wanted player when they see them (Wanted ticks).
func start_roadblock() -> void:
	roadblock = true
	abandoned = true
	speed = 0.0
	siren = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	var world: Node = get_tree().current_scene
	if not is_inside_tree() or world == null or not world.has_method("add_officer"):
		return
	crew_out.clear()
	for i: int in crew_size:
		# Along the road (the car's local X now), on both sides of the car.
		var side: float = 3.4 if i % 2 == 0 else -3.4
		var at: Vector3 = global_position + global_basis.x * side + global_basis.z * (1.2 * float(i / 2))
		at.y = global_position.y + 0.1
		crew_out.append(world.call("add_officer", at, global_position, self, heavy))


## Host: the road block is lifted: crew and car disappear.
func end_roadblock() -> void:
	if is_queued_for_deletion():
		return
	print("[Police] road block %s lifted" % name)
	for c: PoliceOfficer in crew_out:
		if is_instance_valid(c):
			c.queue_free()
	crew_out.clear()
	for j: int in Traffic.JUNCTIONS.size():
		(get_parent() as Traffic).release_junction(j, self)
	queue_free()


## Host: stop; the driver gets out on the kerb side and runs from `origin`, comes back later.
## Host: stop where it is (a wreck, or tests). Drivers never get out any more (point 24):
## a wreck is towed away after WRECK_TIME and replaced, anything else drives on after a while.
func abandon(_origin: Vector3) -> void:
	abandoned = true
	panic = 0.0
	_swerve = 0.0
	_come_back()


func _come_back() -> void:
	await get_tree().create_timer(WRECK_TIME if wrecked else DRIVER_AWAY).timeout
	if not is_inside_tree():
		return
	if wrecked:
		(get_parent() as Traffic).replace_car(self)
		return
	abandoned = false


func _remove_driver() -> void:
	if is_instance_valid(_driver) and not (_driver as Pedestrian).dead:
		_driver.queue_free()
	_driver = null


## Host -> everyone: horn (long = startled, short = impatient toot).
func honk(long: bool) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_honk_ms < HONK_GAP_MS:
		return  # somebody else is already honking
	_last_honk_ms = now
	_play_horn(long)
	for peer: int in Net.peers_in_world:
		_play_horn.rpc_id(peer, long)


@rpc("authority", "call_remote", "unreliable")
func _play_horn(long: bool) -> void:
	if _horn == null:
		return
	_horn.stream = HORN if long else HORN_SHORT
	_horn.pitch_scale = randf_range(0.92, 1.08) + float(kind) * 0.04
	_horn.play()
	# Point 23: short toots only.
	var stop_after: float = 0.45 if long else 0.2
	get_tree().create_timer(stop_after).timeout.connect(func() -> void:
		if is_instance_valid(_horn):
			_horn.stop())
