class_name PlayerCar
extends CharacterBody3D
## Point 45: a car the crew owns and drives itself (bought at Carlo's Cars).
##
## Arcade driving, no wheel physics: speed along the nose + a bicycle steering model, moved with
## move_and_slide (walls, cars and props stop it; it bounces off), the height comes from a ray down
## to the ground (kerbs and slopes; the collision box starts 0.35 m up so kerbs pass under it).
##
## Network: the host owns the car and its seats. The DRIVER's peer simulates it (no input lag) and
## sends its state to the host (`_drive`), which checks the speed and passes it on through the
## synchronizer; everybody else smooths towards net_pos / net_yaw. Without a driver the host lets
## it roll out. People hit at speed are hurt on the host (`_host_hits`); a crime like a shot.

const GROUND_MASK: int = 1
const BODY_LIFT: float = 0.35  # bottom of the collision box above the ground
const BRAKE: float = 14.0
const DRAG: float = 3.0
const REVERSE_MAX: float = 5.0
const STEER_MAX: float = 0.6  # rad, at walking speed
const STEER_RATE: float = 2.6
const HIT_SPEED: float = 3.0  # below this a car only nudges people
const KILL_SPEED: float = 10.0
const MAX_DRIVE_RATE: float = 1.5  # host check: x the model's top speed
## Fuel (point 48 rest): a full tank lasts this many metres; litres per tank and price per litre at the pump.
const FUEL_RANGE: float = 3000.0
const TANK_LITRES: float = 45.0
const FUEL_PRICE: float = 2.0
const LOW_FUEL: float = 0.15

var uid: String = ""
var model_id: String = "hatch"
var paint_index: int = 0
var spec: Dictionary = {}

## Synced (host -> everyone; the driver ignores them for its own car).
var net_pos: Vector3 = Vector3.ZERO
var net_yaw: float = 0.0
var net_speed: float = 0.0
var net_steer: float = 0.0
## Point 94: how much the tyres really slip (0-1): handbrake at speed, or turning harder than GRIP allows.
## Set by whoever simulates (the driver), synced like the rest; VehicleSound screeches only on this.
var net_skid: float = 0.0
const GRIP: float = 14.0  # m/s² of sideways acceleration the tyres hold before they slide
## Peer id per seat (0 = free); seat 0 drives.
var seats: PackedInt32Array = PackedInt32Array([0, 0, 0, 0]):
	set(v):
		seats = v
		if is_inside_tree():
			_sync_riders()

## Local simulation state (the driver, or the host when nobody drives).
var speed: float = 0.0
var steer: float = 0.0
## Tests drive without a keyboard: x = steer (+ left), y = throttle (+ forward), z = handbrake.
## 0..1, host-owned, synced (on change, in 0.5% steps) and saved with the car.
var fuel: float = 1.0
var _fuel_from: Vector3 = Vector3.INF
var _fuel_used: float = 0.0
var test_input: Vector3 = Vector3.ZERO
var test_drive: bool = false

var hits: int = 0  # host: people hit (tests)
var _hit_until: Dictionary = {}  # host: victim -> msec it may be hit again
var _hit_yaw: float = 0.0  # host: last yaw + yaw rate for hits from any side (Roadmap 64, session B)
var _hit_yaw_rate: float = 0.0
var _hit_yaw_ms: int = 0
var _last_drive_ms: int = 0
var _wheels: Array[Node3D] = []
var _steer_pivots: Array[Node3D] = []
var _wheel_spin: float = 0.0
var _visual: Node3D
var _riders_check: float = 0.0
var _honk: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group(&"player_cars")
	spec = CarCatalog.get_model(model_id)
	if seats.size() < 4:
		seats.resize(4)
	collision_layer = 2
	collision_mask = 1 | 2
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var kind: int = int(spec["kind"])
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	ProcCar.build(_visual, kind, ProcCar.PAINTS[paint_index % ProcCar.PAINTS.size()])
	for n: Node in _visual.get_children():
		if n.name.begins_with("Wheel"):
			_wheels.append(n as Node3D)
		elif n.name.begins_with("Steer"):
			_steer_pivots.append(n as Node3D)
			_wheels.append(n.get_child(0) as Node3D)
	var size: Vector3 = ProcCar.collision_size(kind)
	CarShapes.add(self, kind, BODY_LIFT)  # body + cabin: people can stand on the bonnet and the roof (Roadmap 65, B)
	var label := Label3D.new()  # "F" hint above the roof, only close by
	label.name = "Hint"
	label.text = spec["name"]
	label.font_size = 28
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = size.y + 0.75
	label.visibility_range_end = 9.0
	label.modulate = Color(1, 1, 1, 0.8)
	label.outline_size = 8
	add_child(label)
	_honk = AudioStreamPlayer3D.new()
	_honk.stream = Car.HORN_SHORT
	_honk.volume_db = -6.0
	_honk.max_distance = 60.0
	add_child(_honk)
	global_position = net_pos
	rotation.y = net_yaw
	_sync_riders.call_deferred()


func driver_peer() -> int:
	return seats[0] if seats.size() > 0 else 0


func seat_count() -> int:
	return int(spec.get("seats", 4))


func is_free_seat(i: int) -> bool:
	return i < seat_count() and seats[i] == 0


## Seat transform (car space): the rider's feet; the model is hidden, the camera chases the car.
func seat_offset(i: int) -> Vector3:
	var s: Dictionary = ProcCar.SPECS[int(spec["kind"])]
	var front: float = (float(s["cab_f"]) + float(s["cab_b"])) / 2.0 - 0.35
	var row: int = i / 2
	var side: float = -0.4 if i % 2 == 0 else 0.4
	return Vector3(side, 0.15, front + row * 0.8)


## Where a rider gets out: beside their door (or the other side / behind if that is blocked).
func exit_spot(i: int) -> Vector3:
	var hw: float = float(ProcCar.SPECS[int(spec["kind"])]["w"]) / 2.0 + 0.6
	var z: float = seat_offset(i).z
	var side: float = -1.0 if i % 2 == 0 else 1.0
	for local: Vector3 in [Vector3(side * hw, 0, z), Vector3(-side * hw, 0, z),
			Vector3(0, 0, float(ProcCar.SPECS[int(spec["kind"])]["len"]) / 2.0 + 0.8)]:
		var p: Vector3 = global_transform * local
		if _spot_free(p):
			return p + Vector3.UP * 0.05
	return global_position + Vector3.UP * 2.2  # boxed in: on the roof


func _spot_free(p: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	q.shape = cap
	q.transform = Transform3D(Basis(), p + Vector3.UP * 0.95)
	q.collision_mask = 1 | 2
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Distance from a point to the car's body (0 inside), for "close enough to get in".
func distance_to_body(p: Vector3) -> float:
	var local: Vector3 = global_transform.affine_inverse() * p
	var size: Vector3 = ProcCar.collision_size(int(spec["kind"]))
	var c := Vector3(clampf(local.x, -size.x / 2, size.x / 2), local.y, clampf(local.z, -size.z / 2, size.z / 2))
	return Vector2(local.x - c.x, local.z - c.z).length()


# --- Entering / leaving (host decides) ------------------------------------------------

func request_enter() -> void:
	if multiplayer.is_server():
		_host_enter(multiplayer.get_unique_id())
	else:
		_request_enter.rpc_id(1)


func request_exit() -> void:
	if multiplayer.is_server():
		_host_exit(multiplayer.get_unique_id())
	else:
		_request_exit.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_enter() -> void:
	if multiplayer.is_server():
		_host_enter(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _request_exit() -> void:
	if multiplayer.is_server():
		_host_exit(multiplayer.get_remote_sender_id())


func _player(peer: int) -> Player:
	return get_tree().current_scene.get_node_or_null("Players/%d" % peer) as Player


## Host: the driver's seat if it is free, else the first free passenger seat. Returns the seat or -1.
func host_enter(p: Player, want_seat: int = -1) -> int:
	if p == null or p.dead or p.vehicle != null or p.sleeping:
		return -1
	if p.global_position.distance_to(global_position) > 8.0:
		return -1
	var seat: int = -1
	if want_seat >= 0 and is_free_seat(want_seat):
		seat = want_seat
	else:
		for i: int in seat_count():
			if seats[i] == 0:
				seat = i
				break
	if seat < 0:
		p.show_message("The %s is full." % spec["name"])
		return -1
	var s: PackedInt32Array = seats.duplicate()
	s[seat] = p.peer_id
	seats = s
	print("[Car] %s gets in the %s (%s)" % [p.player_name, spec["name"], "driver" if seat == 0 else "seat %d" % seat])
	return seat


func _host_enter(peer: int) -> void:
	host_enter(_player(peer))


## Host: a rider gets out beside their door.
func host_exit(p: Player) -> void:
	if p == null:
		return
	var i: int = seats.find(p.peer_id)
	if i < 0:
		return
	var s: PackedInt32Array = seats.duplicate()
	s[i] = 0
	seats = s
	if not p.dead:
		p.teleport(exit_spot(i))
	print("[Car] %s gets out of the %s" % [p.player_name, spec["name"]])


func _host_exit(peer: int) -> void:
	host_exit(_player(peer))


## Every peer: tell the players in the seats where they sit (and the ones who left that they are out).
func _sync_riders() -> void:
	var players: Node = get_tree().current_scene.get_node_or_null("Players") if get_tree() else null
	if players == null:
		return
	for i: int in seats.size():
		if seats[i] == 0:
			continue
		var p := players.get_node_or_null(str(seats[i])) as Player
		if p and (p.vehicle != self or p.seat != i):
			p.enter_vehicle(self, i)
	for n: Node in players.get_children():
		var p := n as Player
		if p and p.vehicle == self and not p.peer_id in seats:
			p.leave_vehicle()


# --- Driving --------------------------------------------------------------------------

func _is_my_drive() -> bool:
	var d: int = driver_peer()
	if d == 0 or not multiplayer.has_multiplayer_peer():
		return false
	return d == multiplayer.get_unique_id()


func _physics_process(delta: float) -> void:
	var host: bool = multiplayer.has_multiplayer_peer() and multiplayer.is_server()
	if _is_my_drive():
		var input: Vector3 = test_input if test_drive else _read_input()
		_simulate(delta, input)
		net_pos = global_position
		net_yaw = rotation.y
		net_speed = speed
		net_steer = steer
		if not host:
			_drive.rpc_id(1, net_pos, net_yaw, net_speed, net_steer, net_skid)
	elif host and driver_peer() == 0:
		_simulate(delta, Vector3(0, 0, 0.0))  # rolls out and stops
		net_pos = global_position
		net_yaw = rotation.y
		net_speed = speed
		net_steer = steer
	else:
		# Remote (or the host for a client's drive): smooth towards the synced state.
		if global_position.distance_to(net_pos) > 6.0:
			global_position = net_pos
		else:
			global_position = global_position.lerp(net_pos, minf(1.0, 18.0 * delta))
		rotation.y = lerp_angle(rotation.y, net_yaw, minf(1.0, 18.0 * delta))
		speed = net_speed
		steer = net_steer
	if host:
		_host_hits()
		_host_fuel()
		_host_fall_net(delta)
	_riders_check -= delta
	if _riders_check <= 0.0:
		_riders_check = 0.5
		if host:
			_host_check_riders()
		_sync_riders()  # (late joiners: players that spawned after the seats arrived)
	_animate_wheels(delta)
	$Hint.visible = driver_peer() == 0


func _read_input() -> Vector3:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return Vector3.ZERO
	var me := _player(multiplayer.get_unique_id())
	if me and (me.ui and me.ui.phone.is_open()):
		return Vector3.ZERO
	return Vector3(Input.get_axis("move_right", "move_left"), Input.get_axis("move_back", "move_forward"),
			1.0 if Input.is_action_pressed("jump") else 0.0)


## One physics step of the arcade model. input: x steer (+ left), y throttle, z handbrake.
func _simulate(delta: float, input: Vector3) -> void:
	var max_speed: float = float(spec["max_speed"])
	var accel: float = float(spec["accel"])
	var throttle: float = clampf(input.y, -1.0, 1.0) if fuel > 0.0 else 0.0  # empty tank: it only rolls
	if throttle > 0.05:
		speed = move_toward(speed, 0.0, BRAKE * delta) if speed < -0.3 \
				else move_toward(speed, max_speed * throttle, accel * delta)
	elif throttle < -0.05:
		speed = move_toward(speed, 0.0, BRAKE * delta) if speed > 0.3 \
				else move_toward(speed, -REVERSE_MAX, accel * 0.8 * delta)
	else:
		speed = move_toward(speed, 0.0, DRAG * delta)
	if input.z > 0.5:
		speed = move_toward(speed, 0.0, BRAKE * 1.3 * delta)
	# Steering: less lock at speed, so it stays drivable at the top speed.
	var lock: float = STEER_MAX / (1.0 + absf(speed) / 9.0)
	steer = move_toward(steer, clampf(input.x, -1.0, 1.0) * lock, STEER_RATE * delta)
	var base: float = float(ProcCar.SPECS[int(spec["kind"])]["base"])
	rotation.y += speed / base * tan(steer) * delta
	var lateral: float = speed * speed / base * absf(tan(steer))
	var skid: float = clampf((lateral - GRIP) / 8.0, 0.0, 1.0)
	if input.z > 0.5 and absf(speed) > 3.0:
		skid = maxf(skid, clampf(absf(speed) / 12.0, 0.4, 1.0))
	net_skid = skid
	var fwd: Vector3 = -global_transform.basis.z
	velocity = Vector3(fwd.x, 0, fwd.z) * speed
	var before: Vector3 = global_position
	move_and_slide()
	if get_slide_collision_count() > 0 and absf(speed) > 1.0:
		# Hit something: lose most of the speed (a small bounce back when it was hard).
		var moved: float = Vector2(global_position.x - before.x, global_position.z - before.z).length()
		var real: float = moved / maxf(delta, 0.0001)
		if real < absf(speed) * 0.6:
			speed = -signf(speed) * minf(1.5, absf(speed) * 0.15) if absf(speed) > 8.0 else signf(speed) * real
	_follow_ground(delta)


## Height from the ground under the middle of the car (kerbs, slopes, ramps).
func _follow_ground(delta: float) -> void:
	var from: Vector3 = global_position + Vector3.UP * 1.2
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 4.0, GROUND_MASK)
	q.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var y: float = (hit["position"] as Vector3).y
	global_position.y = y if y > global_position.y else move_toward(global_position.y, y, 9.0 * delta)


func _animate_wheels(delta: float) -> void:
	_wheel_spin += speed / ProcCar.WHEEL_R * delta
	for w: Node3D in _wheels:
		w.rotation.x = -_wheel_spin
	for p: Node3D in _steer_pivots:
		p.rotation.y = steer


## Driver -> host, every physics frame.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _drive(pos: Vector3, yaw: float, spd: float, st: float, skid: float = 0.0) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != driver_peer():
		return
	var now: int = Time.get_ticks_msec()
	var dt: float = clampf((now - _last_drive_ms) / 1000.0, 0.016, 0.5)
	_last_drive_ms = now
	var limit: float = float(spec["max_speed"]) * MAX_DRIVE_RATE * dt + 1.0
	if Vector2(pos.x - net_pos.x, pos.z - net_pos.z).length() > limit + 4.0:
		_correct.rpc_id(multiplayer.get_remote_sender_id(), net_pos, net_yaw)  # too fast: back
		return
	net_pos = pos
	net_yaw = yaw
	net_speed = clampf(spd, -REVERSE_MAX, float(spec["max_speed"]))
	net_steer = st
	net_skid = clampf(skid, 0.0, 1.0)


@rpc("authority", "call_remote", "reliable")
func _correct(pos: Vector3, yaw: float) -> void:
	global_position = pos
	rotation.y = yaw
	speed = 0.0


## Point 56: host safety net - a car below Player.FALL_Y goes back to the last spot it stood on the ground.
var _safe_pos: Vector3 = Vector3.INF
var _safe_yaw: float = 0.0
var _safe_check: float = 0.0


func _host_fall_net(delta: float) -> void:
	if global_position.y < Player.FALL_Y:
		var back: Vector3 = _safe_pos if _safe_pos != Vector3.INF else Vector3(0, 0.2, 2.0)
		print("[Car] %s fell out of the world -> back to %s" % [name, back.snapped(Vector3.ONE * 0.1)])
		global_position = back
		rotation.y = _safe_yaw
		speed = 0.0
		net_pos = back
		net_yaw = _safe_yaw
		net_speed = 0.0
		var d: int = driver_peer()
		if d != 0 and d != multiplayer.get_unique_id():
			_correct.rpc_id(d, back, _safe_yaw)
		return
	_safe_check -= delta
	if _safe_check > 0.0:
		return
	_safe_check = 0.5
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, global_position + Vector3.DOWN * 1.5, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and (hit["normal"] as Vector3).y > 0.8 and absf(speed) < 12.0:
		_safe_pos = (hit["position"] as Vector3) + Vector3.UP * 0.1
		_safe_yaw = rotation.y


## Host: riders who died, left the game or are gone lose their seat.
func _host_check_riders() -> void:
	var changed: bool = false
	var s: PackedInt32Array = seats.duplicate()
	for i: int in s.size():
		if s[i] == 0:
			continue
		var p := _player(s[i])
		if p == null or p.dead or p.is_queued_for_deletion():
			s[i] = 0
			changed = true
	if changed:
		seats = s
	_save_record()


## Host: keep the save record up to date (where it is parked, how much fuel).
func _save_record() -> void:
	var cars: Dictionary = GameState.world.get_or_add("vehicles", {})
	cars[uid] = {"model": model_id, "paint": paint_index, "pos": global_position, "yaw": rotation.y, "fuel": fuel}


## Host: fuel burnt by the distance the car moved with someone at the wheel.
func _host_fuel() -> void:
	if driver_peer() == 0:
		_fuel_from = Vector3.INF
		return
	if _fuel_from != Vector3.INF:
		host_use_fuel(Vector2(net_pos.x - _fuel_from.x, net_pos.z - _fuel_from.z).length())
	_fuel_from = net_pos


## Host: `metres` driven (also tests). Updates `fuel` in 0.5% steps; texts the driver once when it runs low/out.
func host_use_fuel(metres: float) -> void:
	if fuel <= 0.0 or metres <= 0.0 or metres > 30.0:
		return
	_fuel_used += metres / FUEL_RANGE
	if _fuel_used < 0.005:
		return
	var before: float = fuel
	fuel = maxf(0.0, fuel - _fuel_used)
	_fuel_used = 0.0
	var driver := _player(driver_peer())
	if driver and before > LOW_FUEL and fuel <= LOW_FUEL:
		driver.show_message("Low fuel (%d%%). Fill up at the gas station on North Road." % roundi(fuel * 100.0))
	elif driver and before > 0.0 and fuel <= 0.0:
		driver.show_message("Out of fuel. Push... or call the roadside team.")


## Host: fill the tank up; returns the litres put in.
func host_refuel() -> float:
	var litres: float = (1.0 - fuel) * TANK_LITRES
	fuel = 1.0
	_fuel_used = 0.0
	_save_record()
	return litres


func litres_missing() -> int:
	return ceili((1.0 - fuel) * TANK_LITRES - 0.01)


# --- Hitting people (host) ------------------------------------------------------------

func _host_hits() -> void:
	# Roadmap 64 (session B): people are hit from ANY side - the front, reversing over someone, the side or the
	# swinging rear in a slide. Impact speed = the velocity of the car's point nearest to the person, towards them
	# (straight motion + the yaw rate's swing); someone merely standing beside a passing car is not hit.
	var now: int = Time.get_ticks_msec()
	var dt: float = (now - _hit_yaw_ms) / 1000.0
	if dt > 0.0 and dt < 0.5:
		_hit_yaw_rate = lerpf(_hit_yaw_rate, angle_difference(_hit_yaw, global_rotation.y) / dt, 0.5)
	elif dt >= 0.5:
		_hit_yaw_rate = 0.0
	_hit_yaw = global_rotation.y
	_hit_yaw_ms = now
	var size: Vector3 = ProcCar.collision_size(int(spec["kind"]))
	var reach: float = Vector2(size.x, size.z).length() * 0.5
	if absf(net_speed) < HIT_SPEED and absf(_hit_yaw_rate) * reach < HIT_SPEED:
		return
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x + 0.7, 1.4, size.z + 0.7)  # the whole car + 35 cm all round
	q.shape = box
	q.transform = global_transform * Transform3D(Basis(), Vector3(0, 0.9, 0))
	q.collision_mask = 4 | 8  # npcs, players
	q.exclude = [get_rid()]
	var vel: Vector3 = -global_basis.z * net_speed
	var driver := _player(driver_peer())
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(q, 8):
		var victim: Node = hit["collider"]
		while victim and not victim.has_method("host_damage"):
			victim = victim.get_parent()
		if victim == null or now < int(_hit_until.get(victim, 0)):
			continue
		if victim is Player and ((victim as Player).vehicle != null or (victim as Player).dead):
			continue
		var v: float = impact_speed((victim as Node3D).global_position, vel, _hit_yaw_rate)
		if v < HIT_SPEED:
			continue  # a nudge
		_hit_until[victim] = now + 1200
		var dmg: int = 200 if v >= KILL_SPEED else int(10.0 + (v - HIT_SPEED) * 11.0)
		hits += 1
		var killed: bool = victim.call("host_damage", dmg, driver, global_position)
		print("[Car] %s hit %s at %.1f m/s (%d dmg%s)" % [spec["name"], victim.name, v, dmg, ", killed" if killed else ""])
		if driver == null:
			continue
		var at: Vector3 = (victim as Node3D).global_position
		if killed:
			var kind: StringName = &"kill"
			if victim is Rival:
				kind = &"kill_rival"
			elif victim is PoliceOfficer:
				kind = &"kill_officer"
			get_tree().call_group(&"police", "report_crime", driver, at, true)
			Wanted.report(driver, kind, at)
			Progression.host_kill(driver, victim)
			get_tree().call_group(&"kill_hooks", "on_kill", driver, victim)  # territory, like a shot
		elif victim is Pedestrian or victim is Player:
			Wanted.report(driver, &"assault", at)


## Host (Roadmap 64): how fast the car's point nearest to `at` moves towards it (m/s, 0 if away/along).
## `vel` = the car's linear velocity, `yaw_rate` = rad/s (+ = turning left).
func impact_speed(at: Vector3, vel: Vector3, yaw_rate: float) -> float:
	var local: Vector3 = to_local(at)
	var size: Vector3 = ProcCar.collision_size(int(spec["kind"]))
	var near_local := Vector3(clampf(local.x, -size.x * 0.5, size.x * 0.5), 0.0,
			clampf(local.z, -size.z * 0.5, size.z * 0.5))
	var near: Vector3 = to_global(near_local)
	var arm: Vector3 = near - global_position
	arm.y = 0.0
	var point_vel: Vector3 = vel + Vector3(0, yaw_rate, 0).cross(arm)
	var dir: Vector3 = at - near
	dir.y = 0.0
	if dir.length() < 0.05:
		dir = arm  # (inside the hull: away from the centre)
	if dir.length() < 0.05:
		return point_vel.length()
	return maxf(0.0, point_vel.dot(dir.normalized()))


## Every peer: H (the driver asks the host, the host plays it everywhere).
func honk() -> void:
	if multiplayer.is_server():
		_host_honk()
	else:
		_ask_honk.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _ask_honk() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == driver_peer():
		_host_honk()


func _host_honk() -> void:
	_play_honk()
	for peer: int in Net.peers_in_world:
		if peer != 1:
			_play_honk.rpc_id(peer)


@rpc("authority", "call_remote", "reliable")
func _play_honk() -> void:
	if not _honk.playing:
		_honk.play()
