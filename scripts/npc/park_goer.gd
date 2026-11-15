class_name ParkGoer
extends Pedestrian
## Point 46 (park + agora): people who use the park. HOST AUTHORITATIVE like every NPC;
## `role` (and `team`) are synced once at spawn, the looks follow from them on every peer.
## - DOG: walks the park loop (Markers/ParkPath) with a dog on a lead (ProcDog, local
##   visual), stops now and then so the dog can sniff; after a few laps goes home.
## - SMOKER: a group of youths standing in a circle at the park's smoke spot, talking,
##   puffs of smoke (local particles). Can become a customer (they stay put).
## - FOOTBALL: plays on the agora; the Agora node drives it (team shirt colour).
## Spawned and removed by World._park_loop / Agora (not replaced by the pedestrian respawn).

enum Role { NONE, DOG, SMOKER, FOOTBALL }

const TEAM_SHIRTS: Array[Color] = [Color(0.75, 0.16, 0.12), Color(0.15, 0.3, 0.7)]
const SMOKE_RADIUS: float = 0.85

## Synced at spawn.
var role: int = Role.NONE
var team: int = 0

## Host: the park loop (DOG), the circle centre + this one's place in it (SMOKER).
var path: Array[Vector3] = []
var spot: Vector3 = Vector3.INF
var slot: float = 0.0
## Host: leave after this many laps (DOG) / at this time (SMOKER, seconds).
var laps_left: int = 3
var stay_until: float = 0.0
## Host: set by the Agora (FOOTBALL) or by World when it wants it gone.
var agora: Node = null
var leaving: bool = false

var _smoke: CPUParticles3D
var _next_puff: float = 0.0


func _ready() -> void:
	ambient = false
	super._ready()
	add_to_group(&"park_goers")
	if role == Role.DOG:
		pass  # Roadmap 67 (session B): the dog is a real NPC now (Dog, made by the Ambience autoload on every peer)
	elif role == Role.SMOKER:
		_build_smoke()
	if _is_host():
		_park_brain.call_deferred()


func uniform_colors() -> Dictionary:
	if role == Role.FOOTBALL:
		return {"White": TEAM_SHIRTS[team % TEAM_SHIRTS.size()], "Red_Dark": TEAM_SHIRTS[team % TEAM_SHIRTS.size()].darkened(0.3)}
	return {}


## Only the smokers stand still long enough to meet a customer deal.
func can_be_customer() -> bool:
	return role == Role.SMOKER and not leaving


## The park loop replaces its own people (no extra pedestrian after a death).
func _on_died(_world: Node) -> void:
	pass


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- Host brain ------------------------------------------------------------------------

func _park_brain() -> void:
	await get_tree().create_timer(randf_range(0.2, 1.0)).timeout
	while is_inside_tree() and not dead:
		if is_fleeing():
			await get_tree().create_timer(0.5).timeout
			continue
		if leaving:
			await _leave()
			return
		match role:
			Role.DOG:
				await _dog_step()
			Role.SMOKER:
				await _smoker_step()
			Role.FOOTBALL:
				if agora == null or not is_instance_valid(agora):
					leaving = true
					continue
				await agora.call("football_step", self)
			_:
				await get_tree().create_timer(1.0).timeout


## Walk the park loop, one corner at a time; a sniff stop now and then.
func _dog_step() -> void:
	if path.is_empty():
		leaving = true
		return
	for i: int in path.size():
		if leaving or dead or not is_inside_tree():
			return
		await walk_to(path[i])
		if randf() < 0.35:
			var dog: Dog = Dog.of(self)
			if dog and Dog.auto_fetch and randf() < 0.5:
				await dog.host_fetch()  # Roadmap 67: a game of fetch instead of a sniff stop
			else:
				await idle(randf_range(3.0, 8.0))
	laps_left -= 1
	if laps_left <= 0:
		leaving = true


## Stand in the circle, face the middle, talk / listen in turns.
func _smoker_step() -> void:
	if spot == Vector3.INF:
		leaving = true
		return
	if stay_until > 0.0 and _now() > stay_until and wants <= 0:
		leaving = true
		return
	var place: Vector3 = spot + Vector3(cos(slot), 0, sin(slot)) * SMOKE_RADIUS
	if Vector2(global_position.x - place.x, global_position.z - place.z).length() > 0.6:
		var map: RID = get_world_3d().navigation_map
		if not await walk_to(NavigationServer3D.map_get_closest_point(map, place)):
			await idle(1.0)
			return
	face(spot)
	anim_state = Anim.TALK if randf() < 0.35 else Anim.IDLE
	await get_tree().create_timer(randf_range(3.0, 6.0)).timeout


## Walk off to a pavement spot away from the park and disappear.
func _leave() -> void:
	if wants > 0:
		wants = 0
	var map: RID = get_world_3d().navigation_map
	var best: Vector3 = Vector3.INF
	for i: int in 8:
		var p: Vector3 = random_sidewalk_point(self, 20)
		if p != Vector3.INF and p.distance_to(global_position) > 25.0:
			best = p
			break
	if best != Vector3.INF:
		await walk_to(NavigationServer3D.map_get_closest_point(map, best))
	if is_inside_tree() and not dead:
		queue_free()


# --- Looks (every peer) ------------------------------------------------------------------

func _build_smoke() -> void:
	_smoke = CPUParticles3D.new()
	_smoke.name = "Smoke"
	_smoke.position = Vector3(0, 1.62, -0.22)
	_smoke.emitting = false
	_smoke.one_shot = false
	_smoke.amount = 10
	_smoke.lifetime = 2.6
	_smoke.local_coords = false
	_smoke.direction = Vector3(0, 1, -0.4)
	_smoke.spread = 25.0
	_smoke.initial_velocity_min = 0.15
	_smoke.initial_velocity_max = 0.35
	_smoke.gravity = Vector3(0.05, 0.12, 0)
	_smoke.damping_min = 0.1
	_smoke.damping_max = 0.3
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.6))
	_smoke.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.85, 0.85, 0.82, 0.45))
	grad.set_color(1, Color(0.9, 0.9, 0.88, 0.0))
	_smoke.color_ramp = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _puff_texture()
	quad.material = mat
	_smoke.mesh = quad
	_smoke.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 5, 4))
	add_child(_smoke)
	_next_puff = _now() + randf_range(1.0, 6.0)


static var _puff_tex: Texture2D


static func _puff_texture() -> Texture2D:
	if _puff_tex == null:
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(0.5, 0.0)
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		g.gradient = grad
		g.width = 32
		g.height = 32
		_puff_tex = g
	return _puff_tex


func _process(_delta: float) -> void:
	if _smoke == null:
		return
	# A puff every 5-11 s for about a second (local, not synced: looks only).
	var t: float = _now()
	if dead:
		_smoke.emitting = false
	elif t >= _next_puff:
		_smoke.emitting = true
		if t >= _next_puff + 1.1:
			_smoke.emitting = false
			_next_puff = t + randf_range(5.0, 11.0)


## Debug / tests: is the smoke on right now?
func puffing() -> bool:
	return _smoke != null and _smoke.emitting
