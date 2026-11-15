class_name Wildlife
extends Node3D
## Roadmap 68 (session B): the town's ambient animals, LOCAL on every peer (node <World>/Wildlife, made by the
## `Ambience` autoload; nothing is networked, nothing collides, no map changes).
## - Roof spots: worked out from every `Building` (ridge of gable/hip roofs, front gutter, flat-roof parapet), skipped
##   when something sits above them.
## - Birds (AmbientBird BIRD) perch there and hop from roof to roof.
## - Pigeon flocks on the ground (park path, shop fronts); they fly onto a roof when scared.
## - Cats (AmbientCat) on pavements / gardens in front of and behind houses.
## - Ducks on the sea by the quay (only when the map has a `Sea`).
## Threats: players + cars (+ group "wildlife_threats" for tests) nearby; gunshots via `scare_at` (WeaponFX.flash).

static var current: Wildlife
## Tests: animals far from the camera keep updating too.
static var always_active: bool = false

const ACTIVE_RANGE: float = 110.0
const GUNSHOT_RANGE: float = 45.0
const DUCK_AREA: Rect2 = Rect2(-125.0, 109.0, 43.0, 20.0)
## Same waves as prefabs/materials/shaders/water.gdshader (wave_height, wave_scale, speed).
const WAVE_HEIGHT: float = 0.12
const WAVE_SCALE: float = 0.08
const WAVE_SPEED: float = 0.35

@export var bird_count: int = 24
@export var pigeon_flocks: int = 3
@export var cat_count: int = 6
@export var duck_count: int = 7

var roof_spots: Array[Dictionary] = []
var cat_spots: Array[Vector3] = []
var flock_homes: Array[Vector3] = []
var birds: Array[AmbientBird] = []
var cats: Array[AmbientCat] = []
var has_sea: bool = false
var sea_y: float = -0.9
var ready_done: bool = false

var _threats: Array = []
var _threat_t: float = 0.0
var _flock_up_ms: Dictionary = {}
var _day_night: Node
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	current = self
	_rng.seed = 6800
	await get_tree().create_timer(1.0).timeout  # (buildings have built their collision)
	if not is_inside_tree():
		return
	_day_night = get_tree().get_first_node_in_group(&"day_night")
	var sea: Node3D = get_parent().get_node_or_null("Sea") as Node3D
	has_sea = sea != null
	if sea:
		sea_y = sea.global_position.y
	_find_spots()
	_spawn()
	ready_done = true


func _exit_tree() -> void:
	if current == self:
		current = null


static func scare_at(pos: Vector3, radius: float = GUNSHOT_RANGE) -> void:
	if current and current.ready_done:
		current.scare(pos, radius)


## Everything within `radius` of `pos` gets a fright.
func scare(pos: Vector3, radius: float) -> void:
	for b: AmbientBird in birds:
		if is_instance_valid(b) and b.global_position.distance_to(pos) < radius:
			b.scare(pos)
	for c: AmbientCat in cats:
		if is_instance_valid(c) and c.global_position.distance_to(pos) < radius:
			c.scare(pos)


func census() -> Dictionary:
	var n: Dictionary = {"birds": 0, "pigeons": 0, "ducks": 0, "cats": cats.size(), "roof_spots": roof_spots.size(),
			"cat_spots": cat_spots.size(), "flocks": flock_homes.size()}
	for b: AmbientBird in birds:
		var key: String = ["birds", "pigeons", "ducks"][b.kind]
		n[key] = int(n[key]) + 1
	return n


func is_night() -> bool:
	return _day_night != null and _day_night.call("is_night")


func near_view(pos: Vector3) -> bool:
	if always_active:
		return true
	var cam: Camera3D = get_viewport().get_camera_3d()
	return cam == null or cam.global_position.distance_to(pos) < ACTIVE_RANGE


# --- Spots --------------------------------------------------------------------------------------------------------

func _find_spots() -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var buildings: Array[Node] = get_parent().find_children("*", "Building", true, false)
	for n: Node in buildings:
		var b := n as Building
		if b == null or not b.is_visible_in_tree():
			continue
		for s: Dictionary in _roof_spots_of(b):
			if _clear_above(space, s["pos"]):
				roof_spots.append(s)
		for k: int in 2:
			var local := Vector3(_rng.randf_range(-b.width / 2.0 + 0.6, b.width / 2.0 - 0.6), 0, 1.5 if k == 0 else -b.depth - 1.5)
			var p: Vector3 = b.global_transform * local
			var y: float = _ground_spot(space, p)
			if not is_nan(y):
				cat_spots.append(Vector3(p.x, y, p.z))
	# Pigeons: two spots on the park path + a shop front.
	var park: Array = get_parent().call("park_path") if get_parent().has_method("park_path") else []
	var tries: Array[Vector3] = []
	if park.size() >= 2:
		tries.append(park[0])
		tries.append(park[park.size() / 2])
	for n: Node in buildings:
		var b := n as Building
		if b and b.ground_floor == "shop":
			tries.append(b.global_transform * Vector3(0, 0, 2.2))
	for p: Vector3 in tries:
		if flock_homes.size() >= pigeon_flocks:
			break
		var y: float = _ground_spot(space, p)
		if not is_nan(y) and flock_homes.all(func(h: Vector3) -> bool: return h.distance_to(p) > 20.0):
			flock_homes.append(Vector3(p.x, y, p.z))


func _roof_spots_of(b: Building) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var h: float = b.floors * b.floor_height
	if h <= 0.5:
		return out
	var t: float = tan(deg_to_rad(b.roof_pitch))
	var xf: Transform3D = b.global_transform
	var yaw: float = b.global_rotation.y
	var half: float = b.width / 2.0 - 0.6
	var zc: float = -b.depth / 2.0
	var line: Callable = func(a: Vector3, c: Vector3, n: int, y_off: float, face: float) -> void:
		for i: int in n:
			var f: float = (i + 0.5) / n
			out.append({"pos": xf * a.lerp(c, f) + Vector3(0, y_off, 0), "yaw": face})
	var n: int = clampi(int(b.width / 3.0), 1, 4)
	match b.roof_type:
		"flat":
			line.call(Vector3(-half, h + 0.78, -0.12), Vector3(half, h + 0.78, -0.12), n, 0.0, yaw + PI)
		"hip":
			var o: float = 0.35
			var a: float = b.width / 2.0 + o
			var c: float = b.depth / 2.0 + o
			var ry: float = h - o * t + minf(a, c) * t
			if a >= c:
				line.call(Vector3(-(a - c), ry, zc), Vector3(a - c, ry, zc), n, 0.05, yaw + PI)
			else:
				line.call(Vector3(0, ry, zc - (c - a)), Vector3(0, ry, zc + (c - a)), 2, 0.05, yaw + PI / 2.0)
			line.call(Vector3(-half, h + 0.08, 0.23), Vector3(half, h + 0.08, 0.23), n, 0.0, yaw + PI)
		_:
			var ry: float = h + b.depth / 2.0 * t
			line.call(Vector3(-half, ry, zc), Vector3(half, ry, zc), n, 0.1, yaw + (PI if _rng.randf() < 0.5 else 0.0))
			line.call(Vector3(-half, h + 0.08, 0.23), Vector3(half, h + 0.08, 0.23), n, 0.0, yaw + PI)
	return out


func _clear_above(space: PhysicsDirectSpaceState3D, p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.25, p + Vector3.UP * 20.0, 1)
	if not space.intersect_ray(q).is_empty():
		return false
	var pq := PhysicsPointQueryParameters3D.new()
	pq.position = p + Vector3.UP * 0.1
	pq.collision_mask = 1
	return space.intersect_point(pq, 1).is_empty()


## Ground height at `p` if it is a free, flat spot that is not a road, else NAN.
func _ground_spot(space: PhysicsDirectSpaceState3D, p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.5, p + Vector3.DOWN * 3.0, 1)
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.85 or absf((hit["position"] as Vector3).y - p.y) > 0.8:
		return NAN
	var c: Node = hit["collider"] as Node
	for i: int in 3:
		if c == null:
			break
		if c is RoadTile:
			return NAN
		c = c.get_parent()
	var pq := PhysicsPointQueryParameters3D.new()
	pq.position = (hit["position"] as Vector3) + Vector3.UP * 0.3
	pq.collision_mask = 1 | 2
	if not space.intersect_point(pq, 1).is_empty():
		return NAN
	return (hit["position"] as Vector3).y


## A roof spot between `min_d` and `max_d` from `pos` ({} if none). Prefers nearer ones.
func roof_spot_near(pos: Vector3, max_d: float, min_d: float = 0.0) -> Dictionary:
	var pick: Dictionary = {}
	var best: float = INF
	for s: Dictionary in roof_spots:
		var d: float = (s["pos"] as Vector3).distance_to(pos)
		if d < min_d or d > max_d:
			continue
		var score: float = d * _rng.randf_range(0.5, 1.5)
		if score < best:
			best = score
			pick = s
	return pick


func cat_spot_near(pos: Vector3, max_d: float, rng: RandomNumberGenerator) -> Vector3:
	var near: Array[Vector3] = []
	for s: Vector3 in cat_spots:
		var d: float = s.distance_to(pos)
		if d > 2.0 and d < max_d:
			near.append(s)
	return near[rng.randi() % near.size()] if not near.is_empty() else Vector3.INF


func flock_point(flock: int, rng: RandomNumberGenerator) -> Vector3:
	var home: Vector3 = flock_homes[flock]
	for i: int in 6:
		var p: Vector3 = home + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * AmbientBird.FLOCK_R
		var y: float = ground_y(p, home.y)
		if not is_nan(y):
			return Vector3(p.x, y, p.z)
	return home


## The whole flock flies up onto one roof.
func flock_up(flock: int, from: Vector3) -> void:
	var now: int = Time.get_ticks_msec()
	if now - int(_flock_up_ms.get(flock, -100000)) < 1500:
		return
	_flock_up_ms[flock] = now
	var home: Vector3 = flock_homes[flock]
	var spot: Dictionary = roof_spot_near(home, 45.0, 6.0)
	if spot.is_empty():
		var away: Vector3 = ((home - from) * Vector3(1, 0, 1)).normalized()
		spot = {"pos": home + away * 12.0 + Vector3.UP * 6.0, "yaw": 0.0}
	for b: AmbientBird in birds:
		if b.kind == AmbientBird.Kind.PIGEON and b.flock == flock:
			b.flee_to_roof(spot)


func water_point_near(p: Vector3) -> Vector3:
	var x: float = clampf(p.x, DUCK_AREA.position.x, DUCK_AREA.end.x)
	var z: float = clampf(p.z, DUCK_AREA.position.y, DUCK_AREA.end.y)
	return Vector3(x, sea_y, z)


func water_y_at(p: Vector3) -> float:
	var t: float = fmod(Time.get_ticks_msec() / 1000.0, 3600.0) * WAVE_SPEED
	var w: float = sin(p.x * WAVE_SCALE * 6.0 + t) * 0.5 + sin(p.z * WAVE_SCALE * 4.3 - t * 1.3) * 0.35 \
			+ sin((p.x + p.z) * WAVE_SCALE * 9.0 + t * 0.7) * 0.15
	return sea_y + w * WAVE_HEIGHT - 0.01


## Ground height under `p` near `y_ref` (NAN = no ground / a drop).
func ground_y(p: Vector3, y_ref: float) -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, y_ref + 0.6, p.z), Vector3(p.x, y_ref - 1.5, p.z), 1)
	var hit: Dictionary = space.intersect_ray(q)
	return NAN if hit.is_empty() else (hit["position"] as Vector3).y


func wall_ahead(pos: Vector3, dir: Vector3, length: float) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = pos + Vector3.UP * 0.25
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * length, 1 | 2)
	return not space.intersect_ray(q).is_empty()


## Nearest player / car / test threat: {pos, dist, car} or {}.
func nearest_threat(pos: Vector3) -> Dictionary:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _threat_t > 0.2:
		_threat_t = now
		_threats.clear()
		for p: Node in get_tree().get_nodes_in_group(&"players"):
			if p is Node3D and (p as Node3D).is_visible_in_tree():
				_threats.append([(p as Node3D).global_position, false])
		for g: StringName in [&"cars", &"player_cars"]:
			for c: Node in get_tree().get_nodes_in_group(g):
				if c is Node3D:
					_threats.append([(c as Node3D).global_position, true])
		for t: Node in get_tree().get_nodes_in_group(&"wildlife_threats"):
			if t is Node3D:
				_threats.append([(t as Node3D).global_position, bool(t.get_meta("car", false))])
	var best: Dictionary = {}
	var bd: float = INF
	for t: Array in _threats:
		var d: float = (t[0] as Vector3).distance_to(pos)
		if d < bd:
			bd = d
			best = {"pos": t[0], "dist": d, "car": t[1]}
	return best


# --- Spawning -----------------------------------------------------------------------------------------------------

func _spawn() -> void:
	if not roof_spots.is_empty():
		for i: int in bird_count:
			var s: Dictionary = roof_spots[_rng.randi() % roof_spots.size()]
			_add_bird(AmbientBird.Kind.BIRD, s["pos"], s["yaw"])
	for f: int in flock_homes.size():
		for i: int in _rng.randi_range(5, 7):
			var b: AmbientBird = _add_bird(AmbientBird.Kind.PIGEON, flock_point(f, _rng), _rng.randf() * TAU, f)
			b.home = flock_homes[f]
	if not cat_spots.is_empty():
		for i: int in cat_count:
			add_cat(cat_spots[_rng.randi() % cat_spots.size()])
	if has_sea:
		for i: int in duck_count:
			var p := Vector3(_rng.randf_range(DUCK_AREA.position.x, DUCK_AREA.end.x), sea_y,
					_rng.randf_range(DUCK_AREA.position.y, DUCK_AREA.end.y))
			_add_bird(AmbientBird.Kind.DUCK, p, _rng.randf() * TAU)


func _add_bird(k: AmbientBird.Kind, pos: Vector3, yaw: float, flock: int = -1) -> AmbientBird:
	var b := AmbientBird.new()
	b.name = "%s%d" % [["Bird", "Pigeon", "Duck"][k], birds.size()]
	b.setup(k, self, _rng.randi())
	b.flock = flock
	add_child(b)
	b.global_position = pos
	b.rotation.y = yaw
	birds.append(b)
	return b


func add_cat(pos: Vector3) -> AmbientCat:
	var c := AmbientCat.new()
	c.name = "Cat%d" % cats.size()
	c.setup(self, _rng.randi())
	add_child(c)
	c.global_position = pos
	c.rotation.y = _rng.randf() * TAU
	cats.append(c)
	return c


func of_kind(k: AmbientBird.Kind) -> Array[AmbientBird]:
	var out: Array[AmbientBird] = []
	for b: AmbientBird in birds:
		if b.kind == k:
			out.append(b)
	return out
