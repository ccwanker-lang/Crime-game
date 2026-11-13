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

var uid: String = ""
var model_id: String = "hatch"
var paint_index: int = 0
var spec: Dictionary = {}

## Synced (host -> everyone; the driver ignores them for its own car).
var net_pos: Vector3 = Vector3.ZERO
var net_yaw: float = 0.0
var net_speed: float = 0.0
var net_steer: float = 0.0
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
var test_input: Vector3 = Vector3.ZERO
var test_drive: bool = false

var hits: int = 0  # host: people hit (tests)
var _hit_until: Dictionary = {}  # host: victim -> msec it may be hit again
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
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	var h: float = size.y + 0.25 - BODY_LIFT - 0.02
	box.size = Vector3(size.x, h, size.z)
	shape.shape = box
	shape.position.y = BODY_LIFT + h / 2.0
	add_child(shape)
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
			_drive.rpc_id(1, net_pos, net_yaw, net_speed, net_steer)
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
	var throttle: float = clampf(input.y, -1.0, 1.0)
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
func _drive(pos: Vector3, yaw: float, spd: float, st: float) -> void:
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


@rpc("authority", "call_remote", "reliable")
func _correct(pos: Vector3, yaw: float) -> void:
	global_position = pos
	rotation.y = yaw
	speed = 0.0


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


## Host: keep the save record up to date (where it is parked).
func _save_record() -> void:
	var cars: Dictionary = GameState.world.get_or_add("vehicles", {})
	cars[uid] = {"model": model_id, "paint": paint_index, "pos": global_position, "yaw": rotation.y}


# --- Hitting people (host) ------------------------------------------------------------

func _host_hits() -> void:
	var v: float = absf(net_speed)
	if v < HIT_SPEED:
		return
	var size: Vector3 = ProcCar.collision_size(int(spec["kind"]))
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x + 0.1, 1.4, 0.9)
	q.shape = box
	var front: float = -(size.z / 2.0 + 0.2) * signf(net_speed)
	q.transform = global_transform * Transform3D(Basis(), Vector3(0, 0.9, front))
	q.collision_mask = 4 | 8  # npcs, players
	q.exclude = [get_rid()]
	var now: int = Time.get_ticks_msec()
	var driver := _player(driver_peer())
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(q, 8):
		var victim: Node = hit["collider"]
		while victim and not victim.has_method("host_damage"):
			victim = victim.get_parent()
		if victim == null or now < int(_hit_until.get(victim, 0)):
			continue
		if victim is Player and ((victim as Player).vehicle != null or (victim as Player).dead):
			continue
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
		elif victim is Pedestrian or victim is Player:
			Wanted.report(driver, &"assault", at)


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
