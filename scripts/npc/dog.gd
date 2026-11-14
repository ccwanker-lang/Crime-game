class_name Dog
extends CharacterBody3D
## A real dog (Roadmap 67, session B): the dog of a dog-walking ParkGoer, now a body of its own on the NPC layer, so
## bullets and cars hit it. HOST AUTHORITATIVE; `Ambience` makes one per DOG ParkGoer on EVERY peer at the same
## path (World/Dogs/Dog_<owner name>), the host drives it and sends `_net` (position, yaw, state) ~10x a second;
## clients smooth towards that. The looks are the old ProcDog in its `driven` mode.
## - FOLLOW: trots beside its owner on the lead.
## - Fetch: `host_fetch()` (the owner's sniff stop, ParkGoer._dog_step): the owner throws a ball (BALL_FLIGHT s),
##   the dog runs off the lead to it, brings it back and drops it at the owner's feet; FETCH_ROUNDS times.
## - The owner dies: the dog stays by the body for MOURN seconds, then runs off (FLEE) and is gone after GONE_AFTER.
## - It can be killed (HEALTH; shots, cars): a simple ragdoll (one rigid body carrying the visual, pushed away from
##   the hit) on every peer, removed after CORPSE_TIME. Killing a dog is an assault for the police (no murder).

enum State { FOLLOW, FETCH_OUT, FETCH_BACK, MOURN, FLEE, DEAD }

const HEALTH: int = 30
const WALK_SPEED: float = 4.5
const RUN_SPEED: float = 6.5
const SIDE: Vector3 = Vector3(0.75, 0.0, -0.55)
const FETCH_ROUNDS: Vector2i = Vector2i(2, 3)
const THROW_MIN: float = 7.0
const THROW_MAX: float = 13.0
const BALL_FLIGHT: float = 0.9
const MOURN: float = 2.5
const FLEE_DIST: float = 35.0
const GONE_AFTER: float = 45.0
const CORPSE_TIME: float = 60.0
const NET_RATE: float = 0.1

## Host: dog walkers start a game of fetch on their own at a sniff stop (tests turn it off).
static var auto_fetch: bool = true

var owner_npc: ParkGoer = null
var state: int = State.FOLLOW
var health: int = HEALTH
## Host: a fetch is going on (ParkGoer waits for it).
var fetching: bool = false
## Every peer: the fetch ball (world position, visible while not in the mouth).
var ball: MeshInstance3D

var _visual: ProcDog
var _net_pos: Vector3
var _net_yaw: float = 0.0
var _net_timer: float = 0.0
var _path: PackedVector3Array = PackedVector3Array()
var _path_i: int = 0
var _path_goal: Vector3 = Vector3.INF
var _state_since: float = 0.0
var _flight_from: Vector3
var _flight_to: Vector3
var _flight_t: float = -1.0
var _mourn_at: Vector3 = Vector3.INF
var _gone: bool = false
var _born: float = 0.0


static func of(npc: Node) -> Dog:
	if npc == null or not npc.is_inside_tree():
		return null
	var scene: Node = npc.get_tree().current_scene
	return scene.get_node_or_null("Dogs/Dog_%s" % npc.name) as Dog if scene else null


func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _ready() -> void:
	collision_layer = 4  # npcs: bullets + cars hit it
	collision_mask = 0  # (moved along the navmesh, not by physics)
	add_to_group(&"dogs")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.26, 0.5, 0.66)
	cs.shape = box
	cs.position = Vector3(0, 0.33, -0.03)
	add_child(cs)
	_visual = ProcDog.new()
	_visual.driven = true
	_visual.setup(owner_npc, owner_npc.color_seed if owner_npc else 0)
	add_child(_visual)
	var b := MeshBuilder.new()
	b.color = Color(0.85, 0.95, 0.2)
	b.sphere(&"item_matte", Vector3.ZERO, 0.045, 5, 8)
	ball = MeshInstance3D.new()
	ball.mesh = b.build()
	ball.top_level = true
	ball.visible = false
	add_child(ball)
	if owner_npc:
		global_position = owner_npc.global_position + owner_npc.global_basis * SIDE
		rotation.y = owner_npc.global_rotation.y
	_net_pos = global_position
	_net_yaw = rotation.y
	_state_since = _now()
	_born = _now()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_ball_flight(delta)
	if not _is_host():
		global_position = global_position.lerp(_net_pos, minf(1.0, 12.0 * delta)) \
				if global_position.distance_to(_net_pos) < 6.0 else _net_pos
		rotation.y = lerp_angle(rotation.y, _net_yaw, minf(1.0, 10.0 * delta))
		_visual.lead_on = state == State.FOLLOW
		return
	var owner_ok: bool = owner_npc != null and is_instance_valid(owner_npc)
	if not owner_ok and state in [State.FOLLOW, State.FETCH_OUT, State.FETCH_BACK]:
		_host_gone()  # the owner went home with... nobody: the dog leaves with them
		return
	if owner_ok and owner_npc.dead and state in [State.FOLLOW, State.FETCH_OUT, State.FETCH_BACK]:
		_set_state(State.MOURN)
		_mourn_at = owner_npc.global_position
		_visual.carrying = false
		fetching = false
	var want_speed: float = 0.0
	var target: Vector3 = global_position
	match state:
		State.FOLLOW:
			target = owner_npc.global_position + owner_npc.global_basis * SIDE
			if global_position.distance_to(target) > 10.0:
				global_position = target  # (a teleported owner)
			want_speed = WALK_SPEED
		State.FETCH_OUT:
			if _flight_t < 0.0:  # the ball lies there
				target = _path_point(_flight_to)
				want_speed = RUN_SPEED
				if _flat(global_position, _flight_to) < 0.45:
					_pick_up()
		State.FETCH_BACK:
			var drop: Vector3 = owner_npc.global_position - owner_npc.global_basis.z * 0.8
			target = _path_point(drop)
			want_speed = RUN_SPEED
			if _flat(global_position, owner_npc.global_position) < 1.3:
				_drop_ball()
		State.MOURN:
			target = _mourn_at
			want_speed = 2.0
			if _now() - _state_since > MOURN:
				_start_flee()
		State.FLEE:
			target = _path_point(_path[_path.size() - 1] if _path.size() > 0 else global_position)
			want_speed = RUN_SPEED if _now() - _state_since < 12.0 else 1.5
			if _now() - _state_since > GONE_AFTER:
				_host_gone()
				return
	_move_towards(target, want_speed, delta)
	_net_timer -= delta
	if _net_timer <= 0.0 and _now() - _born > 1.5:  # (give the clients time to make their copy)
		_net_timer = NET_RATE
		var peers: Array = Net.peers_in_world if multiplayer.has_multiplayer_peer() else []
		for peer: int in peers:
			_net.rpc_id(peer, global_position, rotation.y, state)
	_visual.lead_on = state == State.FOLLOW


func _move_towards(target: Vector3, speed: float, delta: float) -> void:
	# Kinematic along the navmesh path (kerbs and steps would stop a small physics body); the height follows the
	# path point / the owner. The body stays on the NPC layer for bullets and cars.
	var to := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	var d: float = to.length()
	if d > 0.08 and speed > 0.0:
		global_position += to / d * minf(speed * delta, d)
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(1.0, 8.0 * delta))
	var want_y: float = target.y if state != State.FOLLOW or owner_npc == null else owner_npc.global_position.y
	global_position.y = lerpf(global_position.y, want_y, minf(1.0, 10.0 * delta))


## Host: next point of the navmesh path to `goal` (re-planned when the goal moves).
func _path_point(goal: Vector3) -> Vector3:
	if _path.is_empty() or _path_goal.distance_to(goal) > 1.0:
		var map: RID = get_world_3d().navigation_map
		_path = NavigationServer3D.map_get_path(map, global_position, NavigationServer3D.map_get_closest_point(map, goal), true)
		_path_i = 0
		_path_goal = goal
		if _path.is_empty():
			return goal
	while _path_i < _path.size() - 1 and _flat(global_position, _path[_path_i]) < 0.4:
		_path_i += 1
	return _path[_path_i]


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _set_state(s: int) -> void:
	state = s
	_state_since = _now()


# --- Fetch (host) ----------------------------------------------------------------------

## Host (ParkGoer._dog_step): play fetch with the owner. Returns when done.
func host_fetch(rounds: int = -1) -> void:
	if state != State.FOLLOW or owner_npc == null or owner_npc.dead:
		return
	fetching = true
	if rounds < 0:
		rounds = randi_range(FETCH_ROUNDS.x, FETCH_ROUNDS.y)
	var map: RID = get_world_3d().navigation_map
	for r: int in rounds:
		if not fetching or not is_instance_valid(owner_npc) or owner_npc.dead or state == State.DEAD:
			break
		var dir: Vector3 = (-owner_npc.global_basis.z).rotated(Vector3.UP, randf_range(-0.7, 0.7))
		var to: Vector3 = NavigationServer3D.map_get_closest_point(map,
				owner_npc.global_position + dir * randf_range(THROW_MIN, THROW_MAX))
		owner_npc.face(to)
		owner_npc.anim_state = Pedestrian.Anim.TALK  # (the throwing arm)
		var from: Vector3 = owner_npc.global_position + Vector3.UP * 1.5
		_throw(from, to)
		for peer: int in (Net.peers_in_world if multiplayer.has_multiplayer_peer() else []):
			_throw.rpc_id(peer, from, to)
		_set_state(State.FETCH_OUT)
		var t0: float = _now()
		while is_inside_tree() and fetching and state in [State.FETCH_OUT, State.FETCH_BACK] and _now() - t0 < 25.0:
			await get_tree().physics_frame
		if owner_npc and is_instance_valid(owner_npc) and not owner_npc.dead:
			owner_npc.anim_state = Pedestrian.Anim.IDLE
		if state != State.FOLLOW:
			break
		await get_tree().create_timer(randf_range(0.8, 1.6)).timeout
	fetching = false
	if state in [State.FETCH_OUT, State.FETCH_BACK]:
		_set_state(State.FOLLOW)
		_set_ball(Vector3.INF, false)


## Every peer: the ball flies from the hand to `to` (a parabola, BALL_FLIGHT s), then lies there.
@rpc("authority", "call_remote", "reliable")
func _throw(from: Vector3, to: Vector3) -> void:
	_flight_from = from
	_flight_to = to
	_flight_t = 0.0
	ball.visible = true
	_visual.carrying = false


func _ball_flight(delta: float) -> void:
	if _flight_t < 0.0:
		return
	_flight_t += delta / BALL_FLIGHT
	var t: float = minf(_flight_t, 1.0)
	var p: Vector3 = _flight_from.lerp(_flight_to + Vector3.UP * 0.05, t)
	p.y += sin(t * PI) * 2.5
	ball.global_position = p
	if _flight_t >= 1.0:
		_flight_t = -1.0


## Host: the dog reaches the ball.
func _pick_up() -> void:
	_set_ball(Vector3.INF, true)
	_set_state(State.FETCH_BACK)


## Host: the ball lands at the owner's feet; the owner picks it up for the next throw.
func _drop_ball() -> void:
	_set_ball(global_position - global_basis.z * 0.35 + Vector3.UP * 0.05, false)
	_set_state(State.FOLLOW)


## Every peer: the ball lies at `at` (INF = hidden) or is in the mouth.
func _set_ball(at: Vector3, in_mouth: bool) -> void:
	_apply_ball(at, in_mouth)
	for peer: int in (Net.peers_in_world if multiplayer.has_multiplayer_peer() else []):
		_apply_ball.rpc_id(peer, at, in_mouth)


@rpc("authority", "call_remote", "reliable")
func _apply_ball(at: Vector3, in_mouth: bool) -> void:
	_flight_t = -1.0
	_visual.carrying = in_mouth
	ball.visible = at != Vector3.INF and not in_mouth
	if ball.visible:
		ball.global_position = at


## Host / tests: where the ball is now (INF = in the mouth or not out).
func ball_position() -> Vector3:
	return ball.global_position if ball.visible else Vector3.INF


# --- Owner dead: run off (host) ------------------------------------------------------------

func _start_flee() -> void:
	var away: Vector3 = global_position - _mourn_at
	away.y = 0.0
	if away.length() < 0.1:
		away = -global_basis.z
	var map: RID = get_world_3d().navigation_map
	var goal: Vector3 = NavigationServer3D.map_get_closest_point(map, global_position + away.normalized() * FLEE_DIST)
	_path = NavigationServer3D.map_get_path(map, global_position, goal, true)
	_path_i = 0
	_path_goal = goal
	_set_state(State.FLEE)


func _host_gone() -> void:
	if _gone:
		return
	_gone = true
	for peer: int in (Net.peers_in_world if multiplayer.has_multiplayer_peer() else []):
		_free_rpc.rpc_id(peer)
	queue_free()


@rpc("authority", "call_remote", "reliable")
func _free_rpc() -> void:
	queue_free()


# --- Network ---------------------------------------------------------------------------------

@rpc("authority", "call_remote", "unreliable_ordered")
func _net(pos: Vector3, yaw: float, s: int) -> void:
	_net_pos = pos
	_net_yaw = yaw
	if s != State.DEAD:
		state = s


# --- Getting hurt (host) ---------------------------------------------------------------------

## Host (PlayerCombat / a car): damage. Never counts as a kill of a person (returns false), but an attacking
## player is reported for assault.
func host_damage(amount: int, attacker: Node = null, from: Vector3 = Vector3.INF) -> bool:
	if not _is_host() or state == State.DEAD or amount <= 0:
		return false
	health -= amount
	if attacker is Player:
		Wanted.report(attacker as Player, &"assault", global_position)
	if health > 0:
		return false
	var away: Vector3 = global_position - (from if from != Vector3.INF else global_position + global_basis.z)
	away.y = 0.0
	var impulse: Vector3 = away.normalized() * 6.0 + Vector3.UP * 2.0
	_die(impulse)
	for peer: int in (Net.peers_in_world if multiplayer.has_multiplayer_peer() else []):
		_die.rpc_id(peer, impulse)
	print("[Dog] %s's dog was killed" % (owner_npc.name if owner_npc and is_instance_valid(owner_npc) else "?"))
	return false


func is_head_hit(pos: Vector3) -> bool:
	return to_local(pos).z < -0.25 and to_local(pos).y > 0.4


## Every peer: the dog goes limp - its visual rides a rigid body (world layer only) pushed by `impulse`.
@rpc("authority", "call_remote", "reliable")
func _die(impulse: Vector3) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	fetching = false
	collision_layer = 0
	_visual.lead_on = false
	_visual.carrying = false
	_visual.set_process(false)
	var body := RigidBody3D.new()
	body.name = "Carcass"
	body.collision_layer = 0
	body.collision_mask = 1
	body.mass = 20.0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.24, 0.24, 0.6)
	cs.shape = box
	cs.position = Vector3(0, 0.4, 0)
	body.add_child(cs)
	get_parent().add_child(body)
	body.global_transform = global_transform
	_visual.reparent(body)
	# Legs go loose.
	for leg: Node3D in _visual._legs:
		leg.rotation = Vector3(randf_range(-0.9, 0.9), 0, randf_range(-0.5, 0.5))
	_visual._head.rotation.x = 0.5
	body.apply_impulse(impulse * body.mass * 0.4, Vector3(0, 0.45, 0))
	body.apply_torque_impulse(Vector3(0, 0, 1).rotated(Vector3.UP, rotation.y) * 3.0)
	visible = false
	get_tree().create_timer(CORPSE_TIME).timeout.connect(func() -> void:
		if is_instance_valid(body):
			body.queue_free()
		if is_instance_valid(self):
			queue_free())


## Tests: the corpse's rigid body (null while alive).
func carcass() -> RigidBody3D:
	return _visual.get_parent() as RigidBody3D if state == State.DEAD else null
