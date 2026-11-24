class_name Footsteps
extends Node3D
## Footsteps (session B, user list item 2): a child of every Player on every peer (made by the Soundscape autoload).
## Steps by distance walked on the ground (so the rhythm follows the speed: walk, sprint, crouch), the sound by what
## is under the feet: stone (roads, pavements, concrete, tiles), grass / dirt, snow (mountains above the snow line),
## wood (wooden floors), metal (cars). A collider with meta "surface" overrides it. Positional (others hear you).

const SURFACES: Dictionary = {
	"stone": ["res://assets/audio/footsteps/stone_%d.ogg", 6, -6.0],
	"grass": ["res://assets/audio/footsteps/grass_%d.ogg", 6, -4.0],
	"snow": ["res://assets/audio/footsteps/snow_%d.ogg", 6, 6.0],
	"wood": ["res://assets/audio/footsteps/wood_%d.ogg", 4, -8.0],
	"metal": ["res://assets/audio/footsteps/metal_%d.ogg", 4, -10.0],
}
const STRIDE_WALK: float = 1.45
const STRIDE_SPRINT: float = 2.1
const STRIDE_CROUCH: float = 1.0
const MIN_SPEED: float = 0.6

static var _cache: Dictionary = {}

var player: Player
var surface: String = "stone"
var steps: int = 0  # (tests)
var _audio: AudioStreamPlayer3D
var _last: Vector3 = Vector3.INF
var _walked: float = 0.0
var _last_index: int = -1


func _ready() -> void:
	player = get_parent() as Player
	_audio = AudioStreamPlayer3D.new()
	_audio.bus = &"SFX"
	_audio.max_distance = 28.0
	_audio.unit_size = 4.0
	_audio.max_polyphony = 2
	add_child(_audio)


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var pos: Vector3 = player.global_position
	if _last == Vector3.INF:
		_last = pos
		return
	var moved: Vector3 = pos - _last
	_last = pos
	var flat: float = Vector2(moved.x, moved.z).length()
	var speed: float = flat / maxf(delta, 0.0001)
	if player.dead or player.vehicle != null or player.bus_ride != null or player.admin_noclip or player.sleeping \
			or speed < MIN_SPEED or speed > 12.0 or absf(moved.y) > 0.25:
		_walked = minf(_walked, 0.6)  # the first step after stopping comes soon
		return
	var hit: Dictionary = _ground(pos)
	if hit.is_empty():
		return  # in the air
	_walked += flat
	var crouch: bool = player.net_crouch
	var stride: float = STRIDE_CROUCH if crouch else (STRIDE_SPRINT if speed > 5.0 else STRIDE_WALK)
	if _walked >= stride:
		_walked = 0.0
		surface = surface_of(hit)
		_play(surface, crouch, speed > 5.0)


func _ground(pos: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.4, pos + Vector3.DOWN * 0.45, 1 | 2)
	q.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)


## "stone" / "grass" / "snow" / "wood" / "metal" for a ray hit on the ground.
static func surface_of(hit: Dictionary) -> String:
	var c: Object = hit.get("collider")
	if c == null:
		return "stone"
	if c is Node and (c as Node).has_meta(&"surface"):
		return str((c as Node).get_meta(&"surface"))
	if c is RoadTile or c is PavedArea or c is GreyboxBlock:
		return "stone"
	if c is GroundArea:
		return "grass" if (c as GroundArea).grass else "stone"
	var terrain: bool = c is Mountain or c is BorderRange
	if not terrain and c is Node and (c as Node).get_parent() != null:
		var par: Node = (c as Node).get_parent()
		# (the pass mountain is one body per part: TerrainBody / RoadBody / RailsBody / RocksBody; only the ground is soft)
		terrain = (par is Mountain or par is BorderRange) and str((c as Node).name) == "TerrainBody"
	if terrain:
		return "snow" if (hit["position"] as Vector3).y > Mountain.SNOW_LINE else "grass"
	if c is Building:
		return "wood" if (c as Building).floor_material == "wood_floor" else "stone"
	if c is Car or c is PlayerCar:
		return "metal"
	if c is Node and str((c as Node).name).begins_with("Ground"):
		return "grass"
	return "stone"


func _play(kind: String, crouch: bool, sprint: bool) -> void:
	steps += 1
	if DisplayServer.get_name() == "headless":
		return
	var def: Array = SURFACES.get(kind, SURFACES["stone"])
	var i: int = randi() % int(def[1])
	if i == _last_index:
		i = (i + 1) % int(def[1])
	_last_index = i
	_audio.stream = _load(str(def[0]) % (i + 1))
	_audio.volume_db = float(def[2]) + (-7.0 if crouch else (3.0 if sprint else 0.0))
	_audio.pitch_scale = randf_range(0.92, 1.08)
	_audio.play()


static func _load(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]
