class_name CocaBed
extends ProcessStation
## Cocaine step 1 (milestone 3, DESIGN "Products": grow bed): a raised wooden planter.
## 2 Coca Seedlings + 1 Soil -> grows GROW_HOURS; halfway it needs water (E, or a grower):
## watered = 12 Coca Leaves, dry = 6. Abstract game mechanic.

const GROW_HOURS: float = 10.0
const LEAVES: int = 12
const WIDTH: float = 1.4
const DEPTH: float = 0.7
const HEIGHT: float = 0.45

var _soil: MeshInstance3D
var _plants: Array[Node3D] = []
var _flag: Label3D


func _init() -> void:
	inputs = {"coca_seedling": 2, "soil": 1}
	output_id = "coca_leaves"
	output_count = LEAVES
	missed_count = 6
	hours = GROW_HOURS
	label = "Coca bed"
	start_verb = "Plant the seedlings"
	work_start = "plant"
	work_take = "harvest"
	attend_at = 0.5
	attend_verb = "Water the plants"
	attend_flag = "WATER!"
	attend_done = "Watered. They'll give a full harvest."
	work_attend = "water"


func _build() -> void:
	var b := MeshBuilder.new()
	var hw: float = WIDTH * 0.5
	var hd: float = DEPTH * 0.5
	# Plank box: four sides + corner posts.
	b.box(&"planks", Vector3(0, HEIGHT * 0.5, -hd + 0.025), Vector3(WIDTH, HEIGHT, 0.05))
	b.box(&"planks", Vector3(0, HEIGHT * 0.5, hd - 0.025), Vector3(WIDTH, HEIGHT, 0.05))
	b.box(&"planks", Vector3(-hw + 0.025, HEIGHT * 0.5, 0), Vector3(0.05, HEIGHT, DEPTH - 0.1))
	b.box(&"planks", Vector3(hw - 0.025, HEIGHT * 0.5, 0), Vector3(0.05, HEIGHT, DEPTH - 0.1))
	for x: float in [-hw + 0.03, hw - 0.03]:
		for z: float in [-hd + 0.03, hd - 0.03]:
			b.box(&"metal_dark", Vector3(x, HEIGHT * 0.5 + 0.02, z), Vector3(0.06, HEIGHT + 0.04, 0.06))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	var sb := MeshBuilder.new()
	sb.box(&"soil", Vector3(0, HEIGHT - 0.06, 0), Vector3(WIDTH - 0.1, 0.04, DEPTH - 0.1))
	_soil = MeshInstance3D.new()
	_soil.mesh = sb.build()
	add_child(_soil)
	# Two shrubs (scaled with growth): woody stem + oval leaf blobs.
	for i: int in 2:
		var p := MeshBuilder.new()
		p.color = Color(0.35, 0.25, 0.15)
		p.cylinder(&"item_matte", Vector3.ZERO, Vector3(0, 0.35, 0), 0.015, 0.01, 6, false)
		var rng := RandomNumberGenerator.new()
		rng.seed = 30 + i
		for k: int in 14:
			p.color = Color(0.22, 0.45, 0.16).lerp(Color(0.35, 0.58, 0.2), rng.randf())
			var at := Vector3(rng.randf_range(-0.16, 0.16), rng.randf_range(0.18, 0.5), rng.randf_range(-0.12, 0.12))
			p.sphere(&"item_matte", at, 0.05, 4, 6, Vector3(1.4, 0.5, 0.9))
		var plant := MeshInstance3D.new()
		plant.mesh = p.build()
		plant.position = Vector3(-0.32 + i * 0.64, HEIGHT - 0.04, 0)
		add_child(plant)
		_plants.append(plant)
	_flag = make_attend_label(Vector3(0, HEIGHT + 0.8, 0))
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, HEIGHT, DEPTH)
	cs.shape = shape
	cs.position.y = HEIGHT * 0.5
	add_child(cs)


func state_changed() -> void:
	if _soil == null:
		return
	var stage: int = int(state["stage"])
	_soil.visible = stage != Stage.IDLE or ghost
	var grown: float = 1.0 if stage == Stage.DONE else (float(state["progress"]) if stage == Stage.RUNNING else 0.0)
	for p: Node3D in _plants:
		p.visible = stage != Stage.IDLE
		p.scale = Vector3.ONE * lerpf(0.25, 1.0, grown)
	_flag.visible = needs_attention() and not ghost


func tick(h: float) -> bool:
	var was: int = int(float(state["progress"]) * 20.0)
	super(h)
	return int(float(state["progress"]) * 20.0) != was
