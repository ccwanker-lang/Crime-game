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

## AIM / RUN_GUN: armed NPCs (police, rivals), only on the CharacterArmature models.
## TALK (point 30): a hand gesture while talking (Interact; the other models stand).
enum Anim { IDLE, WALK, SIT, RUN, DEAD, AIM, RUN_GUN, TALK }

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
## Point 32: keep running (leg after leg) until this far from the shot AND out of its sight,
## at most FLEE_MAX seconds.
const FLEE_SAFE_DISTANCE: float = 40.0
const FLEE_MAX: float = 45.0
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
## Point 34: a player accepted the deal by phone (synced): it waits at its spot, green "€",
## and the meeting can be confirmed. Before that the "€" is yellow and E only says "text first".
var deal_ok: bool = false:
	set(v):
		deal_ok = v
		_customer_changed()
## First name in its texts (synced: the deal window shows it).
var customer_name: String = ""
## The door this NPC wants to pass; NetDoor opens itself for it.
var target_door: Node = null
## Host: hit points; at 0 -> dead (anim_state DEAD is what clients see).
var health: int = MAX_HEALTH
var dead: bool = false
## Host: running away from gunfire until this time (msec ticks).
var _flee_until: int = 0
## Host (point 32): where the danger is, and whether the flee loop runs.
var _flee_from: Vector3 = Vector3.INF
var _flee_running: bool = false
var _sit_front: Vector3 = Vector3.INF
## Debug counters (self-test): how often it did each activity.
var stats: Dictionary = {"walk": 0, "idle": 0, "sit": 0, "visit": 0, "stuck": 0, "cross": 0}
## Point 29: the navmesh keeps people off the asphalt (except zebras); to cross the road
## anywhere (people) or cut straight across it (police, Crows) they walk a straight line
## without the navmesh. Host only. Cars brake for them like for anyone in their lane.
var crossing_road: bool = false
## Point 30: an officer is talking to this pedestrian (host): stand still, face them.
var _talk_with: Node3D = null
var _talk_until: float = 0.0
var _direct: bool = false
var _direct_target: Vector3 = Vector3.INF
## Chance that a wander step is crossing the road where the pedestrian stands (scenarios raise it).
const JAYWALK_DEFAULT: float = 0.2
static var jaywalk_chance: float = JAYWALK_DEFAULT
const CROSS_MAX: float = 16.0

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
## Host (point 34): the player already made a counter-offer for this deal (one try).
var _countered: bool = false
## Point 34: chance that the customer takes a counter-offer = clamp(1.05 - markup * COUNTER_PICKY).
const COUNTER_PICKY: float = 1.9
## Counter-offer markups the phone offers.
const COUNTER_STEPS: Array[float] = [0.1, 0.25, 0.5]
## Tests: force the answer to the next counter-offer ("yes", "no", "leave").
static var force_counter: String = ""
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
			var fixed: Dictionary = uniform_colors()
			if fixed.has(mat.resource_name):
				m.set_surface_override_material(s, _matte(mat, -1, fixed[mat.resource_name]))
			else:
				m.set_surface_override_material(s, _matte(mat, tint))

	_anim = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	if not stationary:
		# "€" over the head of a customer.
		_deal_label = Label3D.new()
		_deal_label.text = "€"
		_deal_label.font_size = 96
		_deal_label.pixel_size = 0.004
		_deal_label.outline_size = 18
		_deal_label.modulate = DEAL_OK_COLOR if deal_ok else DEAL_OPEN_COLOR
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
		elif short == "Idle_Gun_Pointing":
			_anim_names[Anim.AIM] = a
		elif short == "Run_Shoot":
			_anim_names[Anim.RUN_GUN] = a
		elif short == "Interact" or short.ends_with("_Standing"):
			_anim_names[Anim.TALK] = a
	for key: int in _anim_names:
		_anim.get_animation(_anim_names[key]).loop_mode = Animation.LOOP_NONE if key == Anim.DEAD else Animation.LOOP_LINEAR


## Subclasses (police): clothing material name -> fixed colour (a uniform).
func uniform_colors() -> Dictionary:
	return {}


static func _matte(source: StandardMaterial3D, tint: int, color: Color = Color(0, 0, 0, 0)) -> StandardMaterial3D:
	var key: String = "%d:%d:%s" % [source.get_instance_id(), tint, color.to_html()]
	if not _material_cache.has(key):
		var copy := source.duplicate() as StandardMaterial3D
		copy.metallic = 0.0
		copy.roughness = 0.6 if source.resource_name.begins_with("Skin") else 0.85
		copy.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP  # point 27: one light model for everything
		copy.metallic_specular = 0.3
		if source.resource_name in ["Eyes", "Eye"]:
			copy.roughness = 0.3
		if tint >= 0:
			copy.albedo_color = PALETTE[tint]
		elif color.a > 0.0:
			copy.albedo_color = color
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
	_anim_changed()
	if anim_state == Anim.DEAD:
		_anim.process_mode = Node.PROCESS_MODE_INHERIT  # fall even if off screen
	if anim_state == Anim.IDLE:
		_anim.seek(randf() * _anim.current_animation_length)  # not everyone in sync


## Every peer, after anim_state changed (armed NPCs show/hide their gun).
func _anim_changed() -> void:
	pass


# --- Movement (host) ----------------------------------------------------------------

## Walking / running speed for the current move (subclasses: police run to a crime).
func _move_speed() -> float:
	return RUN_SPEED if is_fleeing() or anim_state == Anim.RUN else WALK_SPEED

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
	if _moving and _direct:
		_direct_step(delta)
	elif _moving:
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
			var speed: float = _move_speed()
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


## Point 29: one physics step of a straight walk (no navmesh) to _direct_target.
func _direct_step(delta: float) -> void:
	var to := Vector3(_direct_target.x - global_position.x, 0, _direct_target.z - global_position.z)
	if to.length() < 0.35:
		_finish_move(true)
		return
	_on_velocity_computed(to.normalized() * _move_speed())
	if global_position.distance_to(_last_pos) > 0.5:
		_last_pos = global_position
		_stuck_time = 0.0
	else:
		_stuck_time += delta
		if _stuck_time > 3.0:
			stats["stuck"] += 1
			_finish_move(false)


## Where the current move goes (straight or over the navmesh).
func move_target() -> Vector3:
	return _direct_target if _direct else agent.target_position


func _finish_move(ok: bool) -> void:
	_moving = false
	_direct = false
	crossing_road = false
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
	_direct = false
	agent.target_position = target
	_moving = true
	_stuck_time = 0.0
	_last_pos = global_position
	anim_state = anim
	return await arrived


## Point 29: walk in a straight line to `target`, off the navmesh (road crossings, police
## cutting across). Check the way first with `straight_way_clear`.
func _go_direct(target: Vector3, anim: int) -> bool:
	if _moving:
		_finish_move(false)
	_direct = true
	_direct_target = target
	_moving = true
	_stuck_time = 0.0
	_last_pos = global_position
	anim_state = anim
	return await arrived


## Host: can it walk straight from here to `target`? Nothing solid in between (rays at knee
## and chest height, cars included), ground all the way with no step higher than a kerb.
func straight_way_clear(target: Vector3, max_len: float = 30.0) -> bool:
	var a := Vector3(global_position.x, 0, global_position.z)
	var b := Vector3(target.x, 0, target.z)
	var length: float = a.distance_to(b)
	if length > max_len or length < 0.5:
		return false
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var base: float = global_position.y
	for h: float in [0.5, 1.3]:
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * h, Vector3(target.x, base + h, target.z), 1 | 2,
				[get_rid()])
		if not space.intersect_ray(q).is_empty():
			return false
	var steps: int = int(length)
	for i: int in steps + 1:
		var p: Vector3 = a.lerp(b, float(i) / maxf(1.0, float(steps)))
		var down := PhysicsRayQueryParameters3D.create(Vector3(p.x, base + 1.0, p.z), Vector3(p.x, base - 1.0, p.z), 1)
		var hit: Dictionary = space.intersect_ray(down)
		if hit.is_empty() or absf((hit["position"] as Vector3).y - base) > 0.35:
			return false
	return true


## Host (point 29): a way across the road from where it stands: [kerb here, kerb across]
## or [] (not next to a road, or no clear straight way). Picks the shortest crossing.
func plan_road_crossing() -> Array:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var map: RID = get_world_3d().navigation_map
	var best: Array = []
	var best_len: float = INF
	for k: int in 12:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 12.0 + randf_range(-0.1, 0.1))
		var start: Vector3 = Vector3.INF
		var end: Vector3 = Vector3.INF
		var on_road: bool = false
		var tile: RoadTile = null  # the road tile of the pavement it stands on
		for i: int in int(CROSS_MAX * 2.0):
			var p: Vector3 = global_position + dir * (i * 0.5)
			var down := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.0, p + Vector3.DOWN * 1.0, 1)
			var hit: Dictionary = space.intersect_ray(down)
			if hit.is_empty():
				break
			var y: float = (hit["position"] as Vector3).y
			if hit["collider"] is RoadTile:
				tile = hit["collider"]
			# (the ray may hit the flat ground under the asphalt instead of the tile)
			var asphalt: bool = y < 0.08 and tile != null and tile.is_on_asphalt(hit["position"])
			if not on_road:
				if asphalt:
					if i * 0.5 > 6.0:
						break  # the road isn't right here
					on_road = true
					start = global_position + dir * maxf(0.0, i * 0.5 - 0.6)
				elif y < -0.05 or y > 0.3:
					break
			elif not asphalt:
				if y < 0.1 or y > 0.3:
					break  # not a pavement on the other side
				end = (hit["position"] as Vector3) + dir * 0.6
				break
		if start == Vector3.INF or end == Vector3.INF:
			continue
		var len: float = start.distance_to(end)
		if len >= best_len or len > CROSS_MAX:
			continue
		var on_nav: Vector3 = NavigationServer3D.map_get_closest_point(map, end)
		if Vector2(on_nav.x - end.x, on_nav.z - end.z).length() > 0.4:
			continue
		best_len = len
		best = [start, end]
	return best


## Host (point 29): cross the road here if there is a way: kerb, look both ways (wait for
## cars that are close), walk straight over. Returns false when there was no crossing.
func cross_road() -> bool:
	var plan: Array = plan_road_crossing()
	if plan.is_empty():
		return false
	if global_position.distance_to(plan[0]) > 0.6 and not await walk_to(plan[0]):
		return false
	var start: Vector3 = plan[0]
	var end: Vector3 = plan[1]
	var mid: Vector3 = (start + end) * 0.5
	for i: int in 8:
		await idle(randf_range(0.6, 1.2))  # look left, look right
		if dead or is_fleeing() or not is_inside_tree():
			return false
		var coming: bool = false
		for c: Node in get_tree().get_nodes_in_group(&"cars"):
			var car := c as Car
			if car and not car.abandoned and car.speed > 0.5 and car.global_position.distance_to(mid) < 22.0:
				coming = true
				break
		if not coming:
			break
	if not straight_way_clear(end, CROSS_MAX + 1.0):
		return false
	crossing_road = true
	var ok: bool = await _go_direct(end, Anim.WALK)
	if ok:
		stats["cross"] = int(stats.get("cross", 0)) + 1
		if "--scenario-quit" in OS.get_cmdline_user_args():
			print("[Pedestrian] %s crossed the road %s -> %s" % [name, start.snapped(Vector3.ONE * 0.1), end.snapped(Vector3.ONE * 0.1)])
	return ok


## Host (point 30): `by` (an officer) wants a word: stop and wait up to `seconds`.
func hold_for_talk(by: Node3D, seconds: float) -> void:
	_talk_with = by
	_talk_until = Time.get_ticks_msec() / 1000.0 + seconds
	if _moving:
		_finish_move(false)
	if not dead:
		anim_state = Anim.IDLE
		face(by.global_position)


func release_talk() -> void:
	_talk_with = null
	if not dead and not _moving and not is_fleeing():
		anim_state = Anim.IDLE


func is_talking() -> bool:
	return _talk_with != null and is_instance_valid(_talk_with) and Time.get_ticks_msec() / 1000.0 < _talk_until


## Host: turn towards `p` (synced yaw).
func face(p: Vector3) -> void:
	var d: Vector3 = p - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		rotation.y = atan2(-d.x, -d.z)
		net_yaw = rotation.y


## Host (point 30): could an officer stop this one for a chat?
func free_for_talk() -> bool:
	return ambient and not dead and not _sitting and not is_fleeing() and not is_talking() and wants <= 0 \
			and not crossing_road and not stationary


func idle(seconds: float) -> void:
	if not is_inside_tree():
		return  # the world is being left / reloaded
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
	return _flee_running or Time.get_ticks_msec() < _flee_until


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
	_flee_from = Vector3.INF
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
	_on_died(world)
	await get_tree().create_timer(corpse_time).timeout
	if is_inside_tree():
		queue_free()  # NPCSpawner removes it on the clients too


## Host: after the death (a new pedestrian turns up later; not for car drivers).
func _on_died(world: Node) -> void:
	if world and world.has_method("respawn_pedestrian_later") and not has_meta(&"driver"):
		world.call("respawn_pedestrian_later", respawn_time)


## Host (called on the "npc" group for every shot): run away from `origin`.
func hear_gunshot(origin: Vector3, hit: bool = false) -> void:
	if not _is_host() or dead or stationary or not is_inside_tree():
		return
	var away := Vector3(global_position.x - origin.x, 0, global_position.z - origin.z)
	if not hit and away.length() > HEAR_DISTANCE:
		return
	_flee_from = origin
	_flee_until = maxi(_flee_until, Time.get_ticks_msec() + int(FLEE_TIME * 1000.0))
	if _flee_running:
		return  # keep running; the loop checks the new danger spot after this leg
	if _sitting:
		_stand_up()
	stats["flee"] = int(stats.get("flee", 0)) + 1
	_flee_loop()


## Host (point 32): run away leg after leg until far from the danger and out of its sight.
func _flee_loop() -> void:
	_flee_running = true
	var give_up: int = Time.get_ticks_msec() + int(FLEE_MAX * 1000.0)
	var legs: int = 0
	while is_inside_tree() and not dead and Time.get_ticks_msec() < give_up:
		_flee_until = maxi(_flee_until, Time.get_ticks_msec() + 4000)
		if legs > 0 and flee_safe():
			break
		var spot: Vector3 = _flee_spot()
		legs += 1
		if spot.distance_to(global_position) < 2.0:
			await get_tree().create_timer(0.5).timeout  # cornered: try another direction soon
			continue
		await _go(spot, Anim.RUN)
	_flee_running = false
	if not dead and is_inside_tree():
		_flee_until = 0
		if not _moving:
			anim_state = Anim.IDLE


## Host (point 32): far enough from the danger and nothing sees it from there?
func flee_safe() -> bool:
	if _flee_from == Vector3.INF:
		return true
	if global_position.distance_to(_flee_from) < FLEE_SAFE_DISTANCE:
		return false
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.5, _flee_from + Vector3.UP * 1.5, 1,
			[get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Host: a navmesh spot 14-22 m further away from the danger (or here when cornered).
func _flee_spot() -> Vector3:
	var away := Vector3(global_position.x - _flee_from.x, 0, global_position.z - _flee_from.z)
	if away.length() < 0.1:
		away = -global_basis.z
	var map: RID = get_world_3d().navigation_map
	var best: Vector3 = global_position
	for i: int in 10:
		var dir: Vector3 = away.normalized().rotated(Vector3.UP, randf_range(-1.1, 1.1))
		var p: Vector3 = NavigationServer3D.map_get_closest_point(map, global_position + dir * randf_range(14.0, 22.0))
		if p.distance_to(_flee_from) > best.distance_to(_flee_from):
			best = p
	return best


# --- Ambient behaviour (host) -----------------------------------------------------

func _wander() -> void:
	await idle(randf_range(0.5, 3.0))
	while is_inside_tree() and ambient and not dead:
		if is_fleeing() or _sitting or is_talking() \
				or (wants > 0 and (deal_ok or _player_near(CUSTOMER_STOP_DISTANCE) != null)):
			await get_tree().create_timer(0.5).timeout
			if is_talking() and not is_fleeing():
				face(_talk_with.global_position)
			elif not is_fleeing() and not _moving and not dead and not _sitting:
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
		if randf() < jaywalk_chance and await cross_road():
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
const DEAL_OK_COLOR: Color = Color(0.45, 1.0, 0.45)
const DEAL_OPEN_COLOR: Color = Color(1.0, 0.82, 0.3)


## Every peer: show/hide the "€" and make the body hittable by the E ray.
func _customer_changed() -> void:
	if _deal_label:
		_deal_label.visible = wants > 0
		_deal_label.modulate = DEAL_OK_COLOR if deal_ok else DEAL_OPEN_COLOR
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


## Host: make this pedestrian a customer for `seconds`. Point 34: it texts a proposal
## (bags, price, place); only a player's "Accept" (or an accepted counter-offer) fixes the meeting.
func become_customer(bags: int, price: int, seconds: float) -> void:
	offer = price
	deal_ok = false
	_countered = false
	wants = bags
	_customer_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	customer_name = CUSTOMER_NAMES.pick_random()
	var world: Node = get_tree().current_scene
	if world and world.has_method("phone_all"):
		var where: String = world.call("describe_location", global_position)
		world.call("phone_all", customer_name, "Hey, it's %s. I need %d bag%s, I'll pay €%d. Meet me %s?" % [
				customer_name, bags, "" if bags == 1 else "s", price, where], str(name))


## Host: the meeting is on: wait here (3 more minutes), green "€".
func accept_deal() -> void:
	deal_ok = true
	_customer_until = maxi(_customer_until, Time.get_ticks_msec() + 180000)
	if _moving:
		_finish_move(false)


## Host (point 34): a player answered the proposal: "accept", "decline" or "counter" (with `price`).
func answer_text(from: Player, action: String, price: int = 0) -> void:
	if wants <= 0 or deal_ok:
		return
	match action:
		"accept":
			accept_deal()
			from.phone_message(customer_name, "Cool. I'll wait right here, €%d. Look for the green €." % offer, "")
		"decline":
			wants = 0
			from.phone_message(customer_name, "Your loss.", "")
		"counter":
			if _countered:
				from.phone_message(customer_name, "We already talked price. €%d, take it or leave it." % offer, str(name) + "#fixed")
				return
			_countered = true
			var markup: float = float(price) / maxf(1.0, float(offer)) - 1.0
			var answer: String = force_counter
			force_counter = ""
			if answer == "":
				var chance: float = clampf(1.05 - markup * COUNTER_PICKY, 0.05, 0.95)
				answer = "yes" if randf() < chance else ("leave" if markup >= 0.4 and randf() < 0.5 else "no")
			match answer:
				"yes":
					offer = maxi(offer, price)
					accept_deal()
					from.phone_message(customer_name, "Ugh, fine. €%d. I'll wait right here, look for the green €." % offer, "")
				"leave":
					wants = 0
					from.phone_message(customer_name, "€%d?! Forget it, I'll find someone else." % price, "")
				_:
					from.phone_message(customer_name, "No way. €%d is my price, take it or leave it." % offer, str(name) + "#fixed")
	print("[Deal] %s answered %s: %s%s -> %s" % [from.player_name, customer_name, action,
			" €%d" % price if action == "counter" else "", "on" if deal_ok else ("off" if wants == 0 else "open")])


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
		if world and world.has_method("phone_all") and deal_ok:
			world.call("phone_all", customer_name, "Forget it, you're too slow.", "")
		return
	if deal_ok and _moving:
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
	if not deal_ok:
		return "%s wants to buy. Answer the text first  [Tab]" % (customer_name if customer_name != "" else "Customer")
	return "Talk to %s  (%d bag%s, €%d)" % [customer_name, wants, "" if wants == 1 else "s", offer]


func _local_player() -> Player:
	for p: Node in get_tree().get_nodes_in_group(&"players"):
		if (p as Player).is_local():
			return p as Player
	return null


## Owner (E): point 34: a short talk with "Confirm deal" (Player.open_deal) instead of selling at once.
func interact() -> void:
	var me: Player = _local_player()
	if me and me.ui:
		if deal_ok:
			me.open_deal(self)
		else:
			me.ui.toast("Text %s back first: Tab > Hush > Accept / Counter." % customer_name)


## Owner: "Confirm deal" in the talk window: the host sells (and rolls the outcome).
func confirm_deal() -> void:
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
	if not deal_ok:
		seller.show_message("\"Text me first, man.\" (accept the deal on your phone)")
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
	deal_ok = false
	# Hook for other systems (ranks/XP, point 43): group "progression" gets every finished sale.
	get_tree().call_group(&"progression", "on_sale", seller, bags, paid, outcome)
	seller.send_wallet()
	seller.show_message(msg)
	if outcome == "run":
		hear_gunshot(seller.global_position, true)  # run away from the seller
