class_name Pedestrian
extends CharacterBody3D
## Animated person walking around the map. Base for every human NPC: ambient
## pedestrians now; customers, dealers, police and rivals later (set
## `ambient = false` and drive them with walk_to()/idle()/sit_on()).
##
## HOST AUTHORITATIVE: only the host runs the AI, navigation and physics.
## Clients receive net_pos / net_yaw / anim_state through the
## MultiplayerSynchronizer (10x per second) and smooth between updates.
## The model variant and colour seed are sent once, when the NPC spawns.
##
## Combat (host): bullets call host_damage(); at 0 health the NPC dies (death
## animation, not solid any more), lies there corpse_time seconds and is then
## removed; World spawns a fresh pedestrian respawn_time after the death.
## Gunshots nearby (hear_gunshot) make it run away from the shooter.

enum Anim { IDLE, WALK, SIT, RUN, DEAD }

## Quaternius CC0 characters. "scale" brings them to ~1.75 m; "walk" is the
## animation speed that matches WALK_SPEED (no foot sliding).
const VARIANTS: Array[Dictionary] = [
	{"model": "man_tshirt", "scale": 0.37, "walk": 1.0},
	{"model": "man_casual", "scale": 0.37, "walk": 1.0},
	{"model": "man_suit_grey", "scale": 0.36, "walk": 0.95},
	{"model": "woman_purple_hair", "scale": 0.37, "walk": 1.0},
	{"model": "woman_tank_top", "scale": 0.37, "walk": 1.0},
	{"model": "woman_casual", "scale": 0.37, "walk": 1.0},
	{"model": "woman_dress", "scale": 0.37, "walk": 1.0},
	{"model": "man_longsleeve", "scale": 0.95, "walk": 1.2},
	{"model": "business_man", "scale": 0.96, "walk": 1.2},
	{"model": "worker", "scale": 0.95, "walk": 1.15},
	{"model": "hoodie", "scale": 0.94, "walk": 1.2},
	{"model": "punk", "scale": 0.93, "walk": 1.2},
	{"model": "woman_green_dress", "scale": 0.95, "walk": 1.3},
	{"model": "woman_orange_pants", "scale": 0.95, "walk": 1.3},
]
const MODEL_DIR: String = "res://assets/characters/quaternius/%s.glb"
## Clothing materials that get a random colour (skin/hair stay untouched).
const TINTABLE: Array[String] = ["Shirt", "Shirt2", "Pants", "Jacket", "LightJacket", "Dress", "Purple", "Suit"]
const PALETTE: Array[Color] = [
	Color(0.12, 0.16, 0.28), Color(0.2, 0.2, 0.22), Color(0.55, 0.5, 0.42), Color(0.3, 0.33, 0.2),
	Color(0.4, 0.12, 0.12), Color(0.25, 0.35, 0.5), Color(0.5, 0.5, 0.52), Color(0.32, 0.22, 0.14),
	Color(0.08, 0.08, 0.09), Color(0.8, 0.78, 0.72), Color(0.18, 0.3, 0.3), Color(0.6, 0.35, 0.2),
]

const WALK_SPEED: float = 1.3
const TURN_SPEED: float = 8.0
const STEP_HEIGHT: float = 0.3
const SIT_OFFSET: float = 0.03  # from the seat marker towards the front of the bench
const SIT_HEIGHT: float = 0.08  # the sit animation expects a slightly higher seat
const RUN_SPEED: float = 4.0
const MAX_HEALTH: int = 100
## Gunshots closer than this make the NPC flee.
const HEAR_DISTANCE: float = 35.0
const FLEE_TIME: float = 8.0
## Customers stop walking and face a player this close.
const CUSTOMER_STOP_DISTANCE: float = 3.5
## Deal outcomes (host roll): runs off with the bags without paying / pays only part.
const RIP_RUN_CHANCE: float = 0.12
const RIP_SHORT_CHANCE: float = 0.15
## Seconds a dead NPC lies on the ground; a new one appears respawn_time after the death.
static var corpse_time: float = 20.0
static var respawn_time: float = 60.0

signal arrived(ok: bool)

## Model + clothing variation (synced once at spawn).
@export var variant: int = 0
@export var color_seed: int = 0
## Run the built-in wander behaviour (host only).
@export var ambient: bool = true
## Placed in a prefab on every peer (shopkeepers): no AI, physics or network
## sync, just stands there idling. Its parent handles interaction/collision.
@export var stationary: bool = false

var net_pos: Vector3 = Vector3.ZERO
var net_yaw: float = 0.0
var anim_state: int = Anim.IDLE:
	set(v):
		anim_state = v
		_apply_anim()
## Customer (step 7): bags of product it wants to buy (0 = not a customer) and
## what it pays for them. Synced; set by World.make_customer on the host.
var wants: int = 0:
	set(v):
		wants = v
		_customer_changed()
var offer: int = 0
## The door this NPC wants to pass; NetDoor opens itself for it.
var target_door: Node = null
## Host: hit points; at 0 -> dead (anim_state DEAD is what clients see).
var health: int = MAX_HEALTH
var dead: bool = false
## Host: running away from gunfire until this time (msec ticks).
var _flee_until: int = 0
var _sit_front: Vector3 = Vector3.INF
## Debug counters (self-test): how often it did each activity.
var stats: Dictionary = {"walk": 0, "idle": 0, "sit": 0, "visit": 0, "stuck": 0}

static var _taken_seats: Dictionary = {}
static var _material_cache: Dictionary = {}

@onready var agent: NavigationAgent3D = $NavAgent
@onready var collision: CollisionShape3D = $Collision

var _anim: AnimationPlayer
var _ragdoll: Ragdoll
var _anim_names: Dictionary = {}
var _anim_walk_speed: float = 1.0
var _moving: bool = false
var _sitting: bool = false
var _stuck_time: float = 0.0
var _last_pos: Vector3
var _trail: Array[Vector3] = []  # positions of the last seconds (to back off when stuck)
var _backoff: Vector3 = Vector3.INF
var _stuck_spot: Vector3 = Vector3.INF  # where it got stuck last time
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _deal_label: Label3D
## Host: customer gives up at this time (msec ticks); bags it ran off with.
var _customer_until: int = 0
var _stolen: int = 0
## Host: first name in texts; true once a player answered "On my way" (it waits).
var customer_name: String = ""
var _meet_accepted: bool = false
const CUSTOMER_NAMES: Array[String] = ["Kevin", "Jens", "Lotte", "Sam", "Dylan", "Inge", "Bram", "Nora", "Wout",
		"Femke", "Robbe", "Elke", "Senne", "Jana", "Milan", "Lisa"]


func _ready() -> void:
	if stationary:
		$Sync.free()
		collision.disabled = true
		set_physics_process(false)
		_build_model()
		_apply_anim()
		return
	add_to_group(&"npc")
	Net.limit_sync_to_world($Sync)
	_build_model()
	if _is_host():
		net_pos = global_position
		net_yaw = rotation.y
		agent.velocity_computed.connect(_on_velocity_computed)
		if ambient:
			_wander.call_deferred()
	else:
		global_position = net_pos
		rotation.y = net_yaw
		collision.disabled = true
	_apply_anim()
	_customer_changed()


func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


# --- Model + animation -------------------------------------------------------------

func _build_model() -> void:
	var v: Dictionary = VARIANTS[variant % VARIANTS.size()]
	var model: Node3D = (load(MODEL_DIR % v["model"]) as PackedScene).instantiate()
	model.name = "Model"
	model.scale = Vector3.ONE * float(v["scale"])
	model.rotation.y = PI  # the models face +Z, Godot's forward is -Z
	add_child(model)
	_anim_walk_speed = v["walk"]

	# Matte clothing/skin (the models ship with metallic 0.4, which looks like
	# shiny plastic), plus random clothing colours. Materials are shared
	# between NPCs through a cache, so they batch well.
	var rng := RandomNumberGenerator.new()
	rng.seed = color_seed
	for mi: Node in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		# Moving meshes must not be voxelized into SDFGI (blocky dark self-occlusion).
		m.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		m.visibility_range_end = 90.0
		m.visibility_range_end_margin = 5.0
		for s: int in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(s) as StandardMaterial3D
			if mat == null:
				continue
			var tint: int = -1
			if mat.resource_name in TINTABLE and rng.randf() < 0.75:
				tint = rng.randi() % PALETTE.size()
			m.set_surface_override_material(s, _matte(mat, tint))

	_anim = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	if not stationary:
		# "€" over the head of a customer.
		_deal_label = Label3D.new()
		_deal_label.text = "€"
		_deal_label.font_size = 96
		_deal_label.pixel_size = 0.004
		_deal_label.outline_size = 18
		_deal_label.modulate = Color(0.45, 1.0, 0.45)
		_deal_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_deal_label.position.y = 2.15
		_deal_label.visible = wants > 0
		add_child(_deal_label)
	_ragdoll = Ragdoll.new()
	(model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D).add_child(_ragdoll)
	# Skip animating NPCs that no camera sees (cheap CPU when many are around).
	var notifier := VisibleOnScreenNotifier3D.new()
	notifier.aabb = AABB(Vector3(-0.6, 0, -0.6), Vector3(1.2, 2.0, 1.2))
	notifier.screen_entered.connect(func() -> void: _anim.process_mode = Node.PROCESS_MODE_INHERIT)
	notifier.screen_exited.connect(func() -> void: _anim.process_mode = Node.PROCESS_MODE_DISABLED)
	add_child(notifier)
	for a: String in _anim.get_animation_list():
		var short: String = a.get_slice("|", a.get_slice_count("|") - 1)
		if short.ends_with("Walk") and not short.contains("Run"):
			_anim_names[Anim.WALK] = a
		elif short == "Idle" or short.ends_with("_Idle"):
			_anim_names[Anim.IDLE] = a
		elif short.ends_with("Sitting"):
			_anim_names[Anim.SIT] = a
		elif short == "Run" or short.ends_with("_Run"):
			_anim_names[Anim.RUN] = a
		elif short.ends_with("Death"):
			_anim_names[Anim.DEAD] = a
	for key: int in _anim_names:
		_anim.get_animation(_anim_names[key]).loop_mode = Animation.LOOP_NONE if key == Anim.DEAD else Animation.LOOP_LINEAR


static func _matte(source: StandardMaterial3D, tint: int) -> StandardMaterial3D:
	var key: String = "%d:%d" % [source.get_instance_id(), tint]
	if not _material_cache.has(key):
		var copy := source.duplicate() as StandardMaterial3D
		copy.metallic = 0.0
		copy.roughness = 0.6 if source.resource_name.begins_with("Skin") else 0.85
		if source.resource_name in ["Eyes", "Eye"]:
			copy.roughness = 0.3
		if tint >= 0:
			copy.albedo_color = PALETTE[tint]
		_material_cache[key] = copy
	return _material_cache[key]


func can_sit() -> bool:
	return _anim_names.has(Anim.SIT)


func _apply_anim() -> void:
	if _anim == null:
		return
	if anim_state == Anim.DEAD:
		_go_limp()
		return
	var a: String = _anim_names.get(anim_state, _anim_names.get(Anim.IDLE, ""))
	if a == "" or _anim.current_animation == a:
		return
	_anim.play(a, 0.15 if anim_state == Anim.DEAD else 0.3)
	_anim.speed_scale = _anim_walk_speed if anim_state == Anim.WALK else 1.0
	if anim_state == Anim.DEAD:
		_anim.process_mode = Node.PROCESS_MODE_INHERIT  # fall even if off screen
	if anim_state == Anim.IDLE:
		_anim.seek(randf() * _anim.current_animation_length)  # not everyone in sync


# --- Movement (host) ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _is_host():
		# Clients: smooth towards the last synced state.
		if global_position.distance_to(net_pos) > 4.0:
			global_position = net_pos
		else:
			global_position = global_position.lerp(net_pos, minf(1.0, 10.0 * delta))
		rotation.y = lerp_angle(rotation.y, net_yaw, minf(1.0, 10.0 * delta))
		return

	if dead:
		_on_velocity_computed(Vector3.ZERO)  # just gravity
		net_pos = global_position
		return
	if _sitting:
		return
	if wants > 0:
		_customer_tick()
	if _moving:
		if agent.is_navigation_finished():
			_finish_move(true)
		else:
			var next: Vector3 = agent.get_next_path_position()
			var dir := Vector3(next.x - global_position.x, 0, next.z - global_position.z)
			# Corner cutting: if the way to the next point is blocked by a wall,
			# first go back to the corner point the agent just skipped
			var idx: int = agent.get_current_navigation_path_index()
			# (tested 0.35 m up, so curbs and doorsteps don't count as walls)
			if idx > 0 and dir.length() > 0.01 					and test_move(global_transform.translated(Vector3.UP * 0.35), dir.normalized() * 0.25):
				var corner: Vector3 = agent.get_current_navigation_path()[idx - 1]
				var back := Vector3(corner.x - global_position.x, 0, corner.z - global_position.z)
				# Already at the corner: keep heading for the next point and slide along.
				if back.length() > 0.15:
					dir = back
			# Pressing against a wall (navmesh corner slightly too tight): walk along
			# the wall at full speed instead of grinding into it.
			for i: int in get_slide_collision_count():
				var n: Vector3 = get_slide_collision(i).get_normal()
				n.y = 0.0
				if n.length() > 0.7 and dir.normalized().dot(n.normalized()) < -0.05:
					n = n.normalized()
					var along: Vector3 = dir - n * dir.dot(n)
					if along.length() < 0.05 * dir.length():
						along = n.cross(Vector3.UP)
					dir = along + n * 0.1 * along.length()
			var speed: float = RUN_SPEED if is_fleeing() else WALK_SPEED
			var wish: Vector3 = dir.normalized() * speed if dir.length() > 0.01 else Vector3.ZERO
			if agent.avoidance_enabled:
				agent.velocity = wish  # -> velocity_computed -> _on_velocity_computed
			else:
				_on_velocity_computed(wish)
			# Breadcrumbs every 1.5 m walked (to back off when stuck).
			if _trail.is_empty() or _trail[-1].distance_to(global_position) > 1.5:
				_trail.append(global_position)
				if _trail.size() > 4:
					_trail.pop_front()
			# Stuck check: barely moved for 4 s -> give up this target.
			if global_position.distance_to(_last_pos) > 0.5:
				_last_pos = global_position
				_stuck_time = 0.0
			else:
				_stuck_time += delta
				if _stuck_time > 4.0:
					stats["stuck"] += 1
					if "--selftest" in OS.get_cmdline_user_args():
						var hits: PackedStringArray = []
						for i: int in get_slide_collision_count():
							var c: Object = get_slide_collision(i).get_collider()
							hits.append(str((c as Node).get_path()).get_slice("/", 4) + "/" + (c as Node).name if c is Node else "?")
						print("[SelfTest]   %s stuck at %s -> %s next %s hits %s" % [name, global_position, agent.target_position, agent.get_next_path_position(), hits])
					_unstick()
					_finish_move(false)
	else:
		_on_velocity_computed(Vector3.ZERO)
	net_pos = global_position
	net_yaw = rotation.y


func _on_velocity_computed(safe: Vector3) -> void:
	if _sitting or not is_inside_tree():
		return
	var delta: float = get_physics_process_delta_time()
	velocity.x = safe.x
	velocity.z = safe.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta
	_try_step_up(delta)
	move_and_slide()
	var flat := Vector2(safe.x, safe.z)
	if flat.length() > 0.2 and not dead:
		rotation.y = lerp_angle(rotation.y, atan2(-safe.x, -safe.z), minf(1.0, TURN_SPEED * delta))


## Same as the player: walk up curbs and doorsteps.
func _try_step_up(delta: float) -> void:
	if not is_on_floor():
		return
	var motion := Vector3(velocity.x, 0, velocity.z) * delta
	if motion.length() < 0.001 or not test_move(global_transform, motion):
		return
	var raised := global_transform.translated(Vector3.UP * STEP_HEIGHT)
	if test_move(global_transform, Vector3.UP * STEP_HEIGHT) or test_move(raised, motion):
		return
	var hit := KinematicCollision3D.new()
	if test_move(raised.translated(motion.normalized() * 0.1), Vector3.DOWN * STEP_HEIGHT, hit):
		var lift: float = STEP_HEIGHT - hit.get_travel().length()
		if lift > 0.01:
			global_position.y += lift + 0.01


## Off the navmesh: slide back onto the closest navmesh point.
func _unstick() -> void:
	var map: RID = get_world_3d().navigation_map
	var p: Vector3 = NavigationServer3D.map_get_closest_point(map, global_position)
	if Vector2(p.x - global_position.x, p.z - global_position.z).length() > 0.1:
		global_position = Vector3(p.x, global_position.y + 0.05, p.z)
	if _trail.size() < 2:
		return
	if _stuck_spot != Vector3.INF and _stuck_spot.distance_to(global_position) < 1.0:
		# Stuck at the same spot again: hop back to where it was a few seconds ago.
		global_position = _trail[0]
		_stuck_spot = Vector3.INF
	else:
		_stuck_spot = global_position
		_backoff = _trail[0]  # first walk back there, then pick a new target
	_trail.clear()


func _finish_move(ok: bool) -> void:
	_moving = false
	agent.velocity = Vector3.ZERO
	if not dead:
		anim_state = Anim.IDLE
	arrived.emit(ok)


# --- Actions (host); await them --------------------------------------------------

## Walks to a point over the navigation mesh. Returns false if it got stuck.
func walk_to(target: Vector3) -> bool:
	if dead or is_fleeing():
		# Busy dying / running away: whatever the caller planned is cancelled.
		await get_tree().process_frame
		return false
	return await _go(target, Anim.WALK)


func _go(target: Vector3, anim: int) -> bool:
	if _moving:
		_finish_move(false)  # release whoever awaited the previous move
	agent.target_position = target
	_moving = true
	_stuck_time = 0.0
	_last_pos = global_position
	anim_state = anim
	return await arrived


func idle(seconds: float) -> void:
	if not dead and not is_fleeing():
		anim_state = Anim.IDLE
	await get_tree().create_timer(seconds).timeout


## Walks to a bench seat (Marker3D in group "bench_seat"), sits, stands up again.
func sit_on(seat: Node3D, seconds: float) -> bool:
	if not can_sit() or _taken_seats.has(seat):
		return false
	_taken_seats[seat] = self
	var front: Vector3 = seat.global_position + seat.global_basis.z * 0.8
	var ok: bool = await walk_to(front)
	if ok and is_inside_tree() and not dead and not is_fleeing():
		_sitting = true
		_sit_front = front
		collision.disabled = true
		var fwd: Vector3 = seat.global_basis.z
		global_position = seat.global_position + fwd * SIT_OFFSET + Vector3.UP * SIT_HEIGHT
		rotation.y = atan2(-fwd.x, -fwd.z)
		net_pos = global_position
		net_yaw = rotation.y
		anim_state = Anim.SIT
		await get_tree().create_timer(seconds).timeout
		if _sitting:  # (not already jumped up by a gunshot)
			_stand_up()
			anim_state = Anim.IDLE
	_taken_seats.erase(seat)
	return ok


## Walks in through a door (NetDoor), stays inside a while and comes back out.
func visit(door: NetDoor, seconds: float) -> bool:
	var out: Vector3 = door.get_outward()
	var center: Vector3 = door.get_center()
	var front: Vector3 = center + out * 1.4
	if not await walk_to(front):
		return false
	var map: RID = get_world_3d().navigation_map
	var inside: Vector3 = center - out * randf_range(2.5, 4.0) + door.global_basis.x.normalized() * randf_range(-1.5, 1.5)
	inside = NavigationServer3D.map_get_closest_point(map, inside)
	target_door = door
	await idle(0.5)  # door swings open
	var ok: bool = await walk_to(inside)
	target_door = null
	if not ok:
		return false
	await idle(seconds)
	target_door = door
	await walk_to(center - out * 0.8)
	await idle(0.4)
	ok = await walk_to(front)
	target_door = null
	return ok


func _stand_up() -> void:
	_sitting = false
	if _sit_front != Vector3.INF:
		global_position = _sit_front
		net_pos = global_position
	_sit_front = Vector3.INF
	collision.disabled = false


# --- Combat (host) -----------------------------------------------------------------

func is_fleeing() -> bool:
	return Time.get_ticks_msec() < _flee_until


## Host: did a bullet that hit at `pos` hit the head?
func is_head_hit(pos: Vector3) -> bool:
	return pos.y - global_position.y > 1.5


## Host: bullet damage. Returns true if this killed the NPC.
func host_damage(amount: int, _attacker: Node = null, from: Vector3 = Vector3.INF) -> bool:
	if not _is_host() or dead or stationary or amount <= 0:
		return false
	health = maxi(0, health - amount)
	if health > 0:
		hear_gunshot(from if from != Vector3.INF else global_position, true)
		return false
	_die(from)
	return true


## Every peer: dead -> the animation stops and the ragdoll takes over.
func _go_limp() -> void:
	if _ragdoll == null or _ragdoll.running:
		return
	_anim.pause()
	_ragdoll.start(velocity if _is_host() else Vector3.ZERO)


## Host -> peers: the death shot's push on the ragdoll.
@rpc("authority", "call_remote", "reliable")
func _ragdoll_push(impulse: Vector3, at: Vector3) -> void:
	_go_limp()
	_ragdoll.push(impulse, at)


func _die(from: Vector3 = Vector3.INF) -> void:
	dead = true
	_flee_until = 0
	if _sitting:
		_stand_up()
	collision_layer = 0  # bullets and people pass through the body
	if _moving:
		_finish_move(false)
	anim_state = Anim.DEAD
	net_pos = global_position
	var away := Vector3(global_position.x - from.x, 0, global_position.z - from.z) if from != Vector3.INF else -global_basis.z
	var impulse: Vector3 = away.normalized() * 90.0 + Vector3.UP * 15.0
	var at: Vector3 = global_position + Vector3.UP * 1.25
	_ragdoll_push(impulse, at)
	for peer: int in Net.peers_in_world:
		_ragdoll_push.rpc_id(peer, impulse, at)
	print("[NPC] %s died at %s" % [name, global_position.snapped(Vector3.ONE * 0.1)])
	var world: Node = get_tree().current_scene
	wants = 0
	if _stolen > 0 and world and world.has_method("spawn_loot_bag"):
		# The rip-off customer drops what it ran off with.
		world.call("spawn_loot_bag", global_position, "Customer", 0, [{"id": "weed_bag", "count": _stolen}])
		_stolen = 0
	if world and world.has_method("respawn_pedestrian_later") and not has_meta(&"driver"):
		world.call("respawn_pedestrian_later", respawn_time)
	await get_tree().create_timer(corpse_time).timeout
	if is_inside_tree():
		queue_free()  # NPCSpawner removes it on the clients too


## Host (called on the "npc" group for every shot): run away from `origin`.
func hear_gunshot(origin: Vector3, hit: bool = false) -> void:
	if not _is_host() or dead or stationary or not is_inside_tree():
		return
	var away := Vector3(global_position.x - origin.x, 0, global_position.z - origin.z)
	if not hit and away.length() > HEAR_DISTANCE:
		return
	var was_fleeing: bool = is_fleeing()
	_flee_until = Time.get_ticks_msec() + int(FLEE_TIME * 1000.0)
	if was_fleeing:
		return  # keep running to the spot it picked
	if _sitting:
		_stand_up()
	if away.length() < 0.1:
		away = -global_basis.z
	var map: RID = get_world_3d().navigation_map
	var best: Vector3 = global_position
	for i: int in 8:
		var dir: Vector3 = away.normalized().rotated(Vector3.UP, randf_range(-0.9, 0.9))
		var p: Vector3 = NavigationServer3D.map_get_closest_point(map, global_position + dir * randf_range(14.0, 22.0))
		if p.distance_to(origin) > best.distance_to(origin):
			best = p
	stats["flee"] = int(stats.get("flee", 0)) + 1
	_go(best, Anim.RUN)


# --- Ambient behaviour (host) -----------------------------------------------------

func _wander() -> void:
	await idle(randf_range(0.5, 3.0))
	while is_inside_tree() and ambient and not dead:
		if is_fleeing() or _sitting or (wants > 0 and (_meet_accepted or _player_near(CUSTOMER_STOP_DISTANCE) != null)):
			await get_tree().create_timer(0.5).timeout
			if not is_fleeing() and not _moving and not dead and not _sitting:
				anim_state = Anim.IDLE
			continue
		if _backoff != Vector3.INF:
			var back: Vector3 = _backoff
			_backoff = Vector3.INF
			await walk_to(back)
		var roll: float = randf()
		if roll < 0.12:
			var doors: Array[Node] = get_tree().get_nodes_in_group(&"public_door")
			if not doors.is_empty() and await visit(doors.pick_random() as NetDoor, randf_range(6.0, 14.0)):
				stats["visit"] += 1
				continue
		elif roll < 0.27 and can_sit():
			var seat: Node3D = _pick_seat()
			if seat and await sit_on(seat, randf_range(10.0, 25.0)):
				stats["sit"] += 1
				continue
		elif roll < 0.45:
			stats["idle"] += 1
			await idle(randf_range(2.0, 7.0))
			continue
		var p: Vector3 = random_sidewalk_point(self)
		if p != Vector3.INF:
			await walk_to(p)
			stats["walk"] += 1
		await idle(randf_range(0.3, 2.0))


func _pick_seat() -> Node3D:
	var free: Array[Node3D] = []
	for s: Node in get_tree().get_nodes_in_group(&"bench_seat"):
		if not _taken_seats.has(s) and (s as Node3D).global_position.distance_to(global_position) < 45.0:
			free.append(s as Node3D)
	return free.pick_random() if not free.is_empty() else null


## A random outdoor point on a sidewalk/square (raised 0.15 m paving, open sky).
static func random_sidewalk_point(from: Node3D, max_tries: int = 60) -> Vector3:
	var world := from.get_world_3d()
	var space := world.direct_space_state
	for i: int in max_tries:
		var p: Vector3 = NavigationServer3D.map_get_random_point(world.navigation_map, 1, true)
		if p.y > 2.0:
			continue  # flat roofs
		# What is actually under this point? (navmesh heights are rounded)
		var down := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.0, p + Vector3.DOWN * 1.5, 1)
		var hit: Dictionary = space.intersect_ray(down)
		if hit.is_empty():
			continue
		var ground: Vector3 = hit["position"]
		var collider: Node = hit["collider"]
		if ground.y < 0.1 or ground.y > 0.25 or not (collider is RoadTile or collider is PavedArea):
			continue  # grass, yards, road, turf, parking...
		var up := PhysicsRayQueryParameters3D.create(ground + Vector3.UP * 0.5, ground + Vector3.UP * 12.0, 1)
		if not space.intersect_ray(up).is_empty():
			continue  # indoors / under something
		return ground
	return Vector3.INF


# --- Customers (step 7) -------------------------------------------------------------
# A pedestrian becomes a customer for a while (World.make_customer): a "€" floats
# over its head and any player can sell it the bags it wants with E. Selling is
# HOST AUTHORITATIVE; the host rolls the outcome: a fair deal, paying short, or
# running off with the bags (kill it to get them back: it drops them in a loot bag).

## Tests: force the next deal's outcome ("fair", "short", "run").
static var force_outcome: String = ""


## Every peer: show/hide the "€" and make the body hittable by the E ray.
func _customer_changed() -> void:
	if _deal_label:
		_deal_label.visible = wants > 0
	if stationary or not is_node_ready():
		return  # _ready calls this again
	if wants > 0:
		add_to_group(&"interactable")
		add_to_group(&"customer")
		if not _is_host():
			collision.disabled = false  # clients only need it for the interact ray
	else:
		remove_from_group(&"interactable")
		remove_from_group(&"customer")
		if not _is_host():
			collision.disabled = true


## Host: make this pedestrian a customer for `seconds`.
func become_customer(bags: int, price: int, seconds: float) -> void:
	offer = price
	wants = bags
	_meet_accepted = false
	_customer_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	customer_name = CUSTOMER_NAMES.pick_random()
	var world: Node = get_tree().current_scene
	if world and world.has_method("phone_all"):
		var where: String = world.call("describe_location", global_position)
		world.call("phone_all", customer_name, "Hey, it's %s. Need %d bag%s, I'll pay €%d. I'm %s." % [
				customer_name, bags, "" if bags == 1 else "s", price, where], str(name))


## Host: a player answered the customer's text.
func answer_text(from: Player, accept: bool) -> void:
	if accept:
		_meet_accepted = true
		_customer_until = maxi(_customer_until, Time.get_ticks_msec() + 180000)
		if _moving:
			_finish_move(false)
		from.phone_message(customer_name, "Cool. I'll wait right here. Look for the €.", "")
	else:
		wants = 0
		from.phone_message(customer_name, "Your loss.", "")
	print("[Deal] %s answered %s: %s" % [from.player_name, customer_name, "on my way" if accept else "not now"])


func _player_near(dist: float) -> Player:
	var best: Player = null
	var best_d: float = dist
	for p: Node in get_tree().get_nodes_in_group(&"players"):
		var pl := p as Player
		if pl == null or pl.dead:
			continue
		var d: float = pl.global_position.distance_to(global_position)
		if d < best_d:
			best = pl
			best_d = d
	return best


## Host, every physics frame while a customer: give up after a while, stop and
## face a player who comes close.
func _customer_tick() -> void:
	if Time.get_ticks_msec() > _customer_until:
		wants = 0
		var world: Node = get_tree().current_scene
		if world and world.has_method("phone_all") and _meet_accepted:
			world.call("phone_all", customer_name, "Forget it, you're too slow.", "")
		return
	if _meet_accepted and _moving:
		_finish_move(false)  # waiting for the player at the spot it texted
	if is_fleeing():
		return
	var pl: Player = _player_near(CUSTOMER_STOP_DISTANCE)
	if pl == null:
		return
	if _moving:
		_finish_move(false)
	var to: Vector3 = pl.global_position - global_position
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 0.15)


func get_interaction_prompt() -> String:
	var item: String = "Bag of Weed" if wants == 1 else "Bags of Weed"
	var me: Player = _local_player()
	var have: int = Station.carried(me, "weed_bag") if me else 0
	if have < wants:
		return "Customer wants %d %s for €%d (you have %d)" % [wants, item, offer, have]
	return "Sell %d %s for €%d" % [wants, item, offer]


func _local_player() -> Player:
	for p: Node in get_tree().get_nodes_in_group(&"players"):
		if (p as Player).is_local():
			return p as Player
	return null


func interact() -> void:
	if _is_host():
		_server_sell(multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1)
	else:
		_request_sell.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_sell() -> void:
	if multiplayer.is_server():
		_server_sell(multiplayer.get_remote_sender_id())


func _server_sell(peer: int) -> void:
	var seller := get_tree().current_scene.get_node_or_null("Players/%d" % peer) as Player
	if seller == null or seller.dead or dead or wants <= 0:
		return
	if seller.global_position.distance_to(global_position) > Player.INTERACT_DISTANCE + 1.5:
		return
	var who: String = seller.player_name
	var have: int = GameState.count_item(who, "weed_bag")
	if have < wants:
		seller.show_message("\"I need %d bag%s, you've only got %d.\"" % [wants, "" if wants == 1 else "s", have])
		return
	var bags: int = wants
	GameState.remove_item(who, "weed_bag", bags)
	var outcome: String = force_outcome
	force_outcome = ""
	if outcome == "":
		var roll: float = randf()
		outcome = "run" if roll < RIP_RUN_CHANCE else ("short" if roll < RIP_RUN_CHANCE + RIP_SHORT_CHANCE else "fair")
	var paid: int = 0
	var msg: String = ""
	match outcome:
		"run":
			_stolen = bags
			msg = "The customer grabbed the bags and ran! Stop them to get it back."
		"short":
			paid = roundi(offer * randf_range(0.35, 0.7))
			msg = "\"Here's €%d. That's all I got, man.\" (wanted €%d)" % [paid, offer]
		_:
			paid = offer
			msg = "\"Nice doing business.\" +€%d" % paid
	if paid > 0:
		GameState.add_cash(who, paid)
	print("[Deal] %s sold %d bags to %s: %s, paid €%d of €%d" % [who, bags, name, outcome, paid, offer])
	wants = 0
	seller.send_wallet()
	seller.show_message(msg)
	if outcome == "run":
		hear_gunshot(seller.global_position, true)  # run away from the seller
