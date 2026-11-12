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
const PANIC_TIME: float = 6.0
const PANIC_SPEED: float = 1.5  # x CRUISE
## A shot closer than this may make the driver bail out (else the car races off).
const BAIL_DISTANCE: float = 18.0
const BAIL_CHANCE: float = 0.35
const MAX_HEALTH: int = 150
const DRIVER_AWAY: float = 25.0
const WRECK_TIME: float = 45.0
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

## Tests: "panic" / "bail" forces the reaction to a gunshot ("" = random).
static var force_reaction: String = ""

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
var _bar_meshes: Array[MeshInstance3D] = []
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
	_horn.unit_size = 12.0
	_horn.max_distance = 90.0
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
		_spin_wheels(speed, delta)
		net_pos = global_position
		net_yaw = rotation.y
		net_speed = speed
		return
	panic = maxf(0.0, panic - delta)
	_swerve = maxf(0.0, _swerve - delta)
	# Slow down for corners ahead, stop for anything in the way (faster when panicking).
	var target: float = CRUISE * (PANIC_SPEED if panic > 0.0 else 1.0)
	target = minf(target, _bend_speed(route) * (1.25 if panic > 0.0 else 1.0))
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
	if blocker == "car" and _ahead_stopped:
		_wait_car = 0.0  # a stopped car ahead: wait (and toot) instead of creeping through it
		if _honk_cooldown <= 0.0 and speed < 0.5:
			honk(false)
			_honk_cooldown = randf_range(6.0, 12.0)
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
func hear_gunshot(origin: Vector3, _hit: bool = false) -> void:
	if not _is_host() or abandoned or police or not is_inside_tree():
		return
	var d: float = global_position.distance_to(origin)
	if d > HEAR_DISTANCE:
		return
	var bail: bool = d < BAIL_DISTANCE and randf() < BAIL_CHANCE
	if force_reaction != "":
		bail = force_reaction == "bail"
	if bail and panic <= 0.0:
		abandon(origin)
		return
	if panic <= 0.0:
		honk(true)
		_swerve = SWERVE_TIME
		_swerve_side = -1.0 if randf() < 0.5 else 1.0
	panic = PANIC_TIME


## Host: a bullet hit the car: it stops and the driver runs. Cars don't "die" (returns false).
func host_damage(amount: int, attacker: Node = null, from: Vector3 = Vector3.INF) -> bool:
	if not _is_host() or wrecked or amount <= 0:
		return false
	health = maxi(0, health - amount)
	if health == 0:
		wrecked = true
	if police and attacker is Player:
		if not abandoned:
			report_crime(attacker as Player, from if from != Vector3.INF else global_position, false)
		elif is_instance_valid(_driver) and _driver is PoliceOfficer:
			(_driver as PoliceOfficer)._alert(attacker as Player, (attacker as Player).global_position)
		return false
	if not abandoned:
		abandon(from if from != Vector3.INF else global_position)
	return false


## Host (group "police"): a crime nearby. The car stops, the officer gets out and
## goes after the culprit; when that's over it walks back and the car drives on.
func report_crime(culprit: Player, origin: Vector3, murder: bool) -> void:
	if not _is_host() or not police or abandoned or wrecked or culprit == null or culprit.dead:
		return
	if global_position.distance_to(origin) > (PoliceOfficer.MURDER_RANGE if murder else PoliceOfficer.HEAR_RANGE):
		return
	var world: Node = get_tree().current_scene
	if world == null or not world.has_method("add_officer"):
		return
	abandoned = true
	panic = 0.0
	_swerve = 0.0
	siren = true
	var side: Vector3 = global_position + global_basis.x * 1.4
	side.y = global_position.y + 0.1
	var cop: PoliceOfficer = world.call("add_officer", side, global_position, self)
	cop._alert(culprit, origin)
	_driver = cop
	print("[Police] patrol car %s stops, officer out after %s" % [name, culprit.player_name])
	_police_come_back()


func _police_come_back() -> void:
	# Wait until the officer is done (culprit dead / lost), then it walks back and gets in.
	while is_inside_tree() and is_instance_valid(_driver) and not (_driver as Pedestrian).dead and (_driver as PoliceOfficer).target != null:
		await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	if not is_instance_valid(_driver) or (_driver as Pedestrian).dead:
		await get_tree().create_timer(WRECK_TIME).timeout
		_remove_driver()
		if is_inside_tree():
			(get_parent() as Traffic).replace_car(self)
		return
	await get_tree().create_timer(2.0).timeout
	var door: Vector3 = global_position + global_basis.x * 1.4
	for attempt: int in 3:
		if not is_instance_valid(_driver) or (_driver as Pedestrian).dead or (_driver as PoliceOfficer).target != null:
			break
		await (_driver as Pedestrian).walk_to(door)
		if is_instance_valid(_driver) and (_driver as Node3D).global_position.distance_to(door) < 3.0:
			break
	if not is_inside_tree():
		return
	if is_instance_valid(_driver) and not (_driver as Pedestrian).dead and (_driver as PoliceOfficer).target != null:
		_police_come_back()  # a new call came in on the way back
		return
	_remove_driver()
	siren = false
	abandoned = false


## Host: stop; the driver gets out on the kerb side and runs from `origin`, comes back later.
func abandon(origin: Vector3) -> void:
	abandoned = true
	panic = 0.0
	_swerve = 0.0
	var world: Node = get_tree().current_scene
	if world and world.has_method("_add_pedestrian"):
		var side: Vector3 = global_position + global_basis.x * 1.4
		side.y = global_position.y + 0.1
		var ped: Pedestrian = world.call("_add_pedestrian", side, randi() % 4)
		ped.ambient = false
		ped.set_meta(&"driver", true)
		_driver = ped
		ped.hear_gunshot.call_deferred(origin, true)
	_come_back()


func _come_back() -> void:
	await get_tree().create_timer(WRECK_TIME if wrecked else DRIVER_AWAY).timeout
	if not is_inside_tree():
		return
	var alive: bool = is_instance_valid(_driver) and not (_driver as Pedestrian).dead
	if wrecked or not alive:
		if not wrecked:
			# Driver dead: the car waits for the tow truck.
			await get_tree().create_timer(WRECK_TIME - DRIVER_AWAY).timeout
		_remove_driver()
		if is_inside_tree():
			(get_parent() as Traffic).replace_car(self)
		return
	# The driver walks back to the car, gets in and drives on.
	var door: Vector3 = global_position + global_basis.x * 1.4
	for attempt: int in 3:
		if not is_instance_valid(_driver) or (_driver as Pedestrian).dead:
			break
		await (_driver as Pedestrian).walk_to(door)
		if is_instance_valid(_driver) and (_driver as Node3D).global_position.distance_to(door) < 3.0:
			break
		await get_tree().create_timer(3.0).timeout
	if not is_inside_tree():
		return
	_remove_driver()
	abandoned = false


func _remove_driver() -> void:
	if is_instance_valid(_driver) and not (_driver as Pedestrian).dead:
		_driver.queue_free()
	_driver = null


## Host -> everyone: horn (long = startled, short = impatient toot).
func honk(long: bool) -> void:
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
