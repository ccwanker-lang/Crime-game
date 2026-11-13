class_name DryingRack
extends Station
## Wooden rack with strings. E hangs the Fresh Weed you carry (up to CAPACITY);
## after DRY_HOURS in-game hours it is dried Weed Bud, E takes it off again.
## Buds hung later join the batch (the batch progress is averaged).

const CAPACITY: int = 12
const DRY_HOURS: float = 3.0
const WIDTH: float = 1.1
const DEPTH: float = 0.42
const HEIGHT: float = 1.6
const STRING_HEIGHTS: Array[float] = [1.5, 1.2, 0.9]

var _bud_mesh_wet: ArrayMesh
var _bud_mesh_dry: ArrayMesh
var _buds: Array[MeshInstance3D] = []


func default_state() -> Dictionary:
	return {"wet": 0, "dry": 0, "progress": 0.0}


func pick_up_blocker() -> String:
	return "Take the weed off the rack first." if int(state["wet"]) + int(state["dry"]) > 0 else ""


func _build() -> void:
	var b := MeshBuilder.new()
	b.collide = true
	var hw: float = WIDTH * 0.5
	var hd: float = DEPTH * 0.5
	for x: float in [-hw, hw]:
		for z: float in [-hd, hd]:
			b.box(&"planks", Vector3(x, HEIGHT * 0.5, z), Vector3(0.04, HEIGHT, 0.04))
		b.box(&"planks", Vector3(x, 0.15, 0), Vector3(0.035, 0.035, DEPTH))
		b.box(&"planks", Vector3(x, HEIGHT - 0.02, 0), Vector3(0.035, 0.035, DEPTH))
	for z: float in [-hd, hd]:
		b.box(&"planks", Vector3(0, HEIGHT - 0.02, z), Vector3(WIDTH, 0.035, 0.035))
	b.collide = false
	# Strings along the length, two rows (front and back) per height.
	for y: float in STRING_HEIGHTS:
		for z: float in [-hd * 0.45, hd * 0.45]:
			b.cylinder(&"string", Vector3(-hw, y, z), Vector3(hw, y, z), 0.003, 0.003, 4, false)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	# One flat collision slab for the whole rack (simple to target with E).
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH + 0.04, HEIGHT, DEPTH + 0.04)
	cs.shape = shape
	cs.position.y = HEIGHT * 0.5
	add_child(cs)

	_bud_mesh_wet = _hanging_bud(Vector2(0.0, 0.5))
	_bud_mesh_dry = _hanging_bud(Vector2(0.5, 0.5))
	# Fixed spots: CAPACITY buds spread over the strings.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var spots_per_string: int = ceili(CAPACITY / (STRING_HEIGHTS.size() * 2.0))
	for i: int in CAPACITY:
		var row: int = i % (STRING_HEIGHTS.size() * 2)
		var k: int = i / (STRING_HEIGHTS.size() * 2)
		var y: float = STRING_HEIGHTS[row / 2]
		var z: float = (-hd if row % 2 == 0 else hd) * 0.45
		var x: float = lerpf(-hw + 0.15, hw - 0.15, (k + 0.5) / spots_per_string) + rng.randf_range(-0.05, 0.05)
		var bud := MeshInstance3D.new()
		bud.position = Vector3(x, y, z)
		bud.rotation.y = rng.randf() * TAU
		bud.scale = Vector3.ONE * rng.randf_range(0.85, 1.15)
		add_child(bud)
		_buds.append(bud)


## Upside-down cola hanging from the string by a short stem (crossed cards).
static func _hanging_bud(cell: Vector2) -> ArrayMesh:
	var b := MeshBuilder.new()
	b.color = Color(0, 0, 0)
	b.cylinder(&"weed_stem", Vector3(0, 0, 0), Vector3(0, -0.04, 0), 0.003, 0.003, 4, false)
	var h: float = 0.2
	var w: float = h * 0.9
	b.color = Color(0.5, 0.5, 0.5)
	for k: int in 3:
		var a: float = k * PI / 3.0
		var side := Vector3(cos(a), 0, sin(a)) * w * 0.5
		var top := Vector3(0, -0.035, 0)
		var bottom := top + Vector3(0, -h, 0)
		# Texture is upright (tip at the top of the cell) -> tip points down here.
		b.card(&"weed_leaves", top - side, top + side, bottom + side, bottom - side, Vector3(-sin(a), 0, cos(a)),
				PackedVector2Array([Vector2(cell.x, cell.y + 0.5), Vector2(cell.x + 0.5, cell.y + 0.5),
						Vector2(cell.x + 0.5, cell.y), Vector2(cell.x, cell.y)]))
	return b.build()


func state_changed() -> void:
	if _buds.is_empty():
		return
	var wet: int = int(state["wet"])
	var dry: int = int(state["dry"])
	for i: int in _buds.size():
		var bud: MeshInstance3D = _buds[i]
		bud.visible = i < wet + dry
		bud.mesh = _bud_mesh_dry if i < dry else _bud_mesh_wet


func tick(hours: float) -> bool:
	if int(state["wet"]) <= 0:
		return false
	state["progress"] = float(state["progress"]) + hours / DRY_HOURS
	if float(state["progress"]) >= 1.0 and _is_host():
		state["dry"] = int(state["dry"]) + int(state["wet"])
		state["wet"] = 0
		state["progress"] = 0.0
		changed()
	return false


func status_text() -> String:
	var parts: PackedStringArray = []
	if int(state["wet"]) > 0:
		parts.append("%d drying %d%%" % [int(state["wet"]), int(float(state["progress"]) * 100.0)])
	if int(state["dry"]) > 0:
		parts.append("%d dry" % int(state["dry"]))
	return "Drying rack" + (": " + ", ".join(parts) if not parts.is_empty() else " (empty)")


func prompt_for(player: Player) -> String:
	var status: String = status_text()
	if int(state["dry"]) > 0:
		return "Take %d Dried Weed   [%s]" % [int(state["dry"]), status]
	var free: int = CAPACITY - int(state["wet"]) - int(state["dry"])
	var fresh: int = carried(player, "fresh_weed")
	if fresh > 0 and free > 0:
		return "Hang %d Fresh Weed to dry   [%s]" % [mini(fresh, free), status]
	if fresh > 0:
		return "Rack is full   [%s]" % status
	return status if int(state["wet"]) > 0 else "Drying rack - bring Fresh Weed from a plant"


func do_action(player: Player) -> String:
	var who: String = player.player_name
	var dry: int = int(state["dry"])
	if dry > 0:
		var take: int = mini(dry, GameState.space_for(who, "weed_bud"))
		if take <= 0:
			return "Your pockets are full."
		GameState.give(who, 0, [{"id": "weed_bud", "count": take}])
		state["dry"] = dry - take
		changed()
		work = "take"
		return "Took %d Dried Weed." % take
	var wet: int = int(state["wet"])
	var hang: int = mini(GameState.count_item(who, "fresh_weed"), CAPACITY - wet)
	if hang <= 0:
		return "Nothing to hang." if wet < CAPACITY else "The rack is full."
	GameState.remove_item(who, "fresh_weed", hang)
	# New buds join the batch: weighted progress.
	state["progress"] = float(state["progress"]) * wet / float(wet + hang)
	state["wet"] = wet + hang
	changed()
	work = "hang"
	return "Hung %d Fresh Weed. Dry in about %d hours." % [hang, ceili(DRY_HOURS * (1.0 - float(state["progress"])))]
