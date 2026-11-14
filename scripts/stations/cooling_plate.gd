class_name CoolingPlate
extends ProcessStation
## Meth step 2 (milestone 3): a steel plate on a frame. Pour a Hot Tray on it -> it cools for
## COOL_HOURS -> E breaks it into Meth Shards (package them at the packaging table).

const COOL_HOURS: float = 1.5
const SHARDS: int = 6
const WIDTH: float = 0.9
const DEPTH: float = 0.6
const HEIGHT: float = 0.85

var _slab: MeshInstance3D
var _slab_mat: StandardMaterial3D
var _shards: MeshInstance3D


func _init() -> void:
	inputs = {"meth_tray": 1}
	output_id = "meth_shard"
	output_count = SHARDS
	hours = COOL_HOURS
	label = "Cooling plate"
	start_verb = "Pour a Hot Tray to cool"
	work_start = "hang"
	work_take = "take"


func _build() -> void:
	var b := MeshBuilder.new()
	var hw: float = WIDTH * 0.5
	var hd: float = DEPTH * 0.5
	for x: float in [-hw + 0.04, hw - 0.04]:
		for z: float in [-hd + 0.04, hd - 0.04]:
			b.box(&"metal_dark", Vector3(x, HEIGHT * 0.5, z), Vector3(0.04, HEIGHT, 0.04))
	b.box(&"metal_dark", Vector3(0, 0.2, 0), Vector3(WIDTH - 0.08, 0.02, DEPTH - 0.08))
	b.box(&"zinc", Vector3(0, HEIGHT, 0), Vector3(WIDTH, 0.04, DEPTH), 0.004)
	# Cooling fins under the plate.
	for i: int in 7:
		var x: float = -hw + 0.1 + i * (WIDTH - 0.2) / 6.0
		b.box(&"item_metal", Vector3(x, HEIGHT - 0.08, 0), Vector3(0.012, 0.12, DEPTH - 0.1))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	var top: float = HEIGHT + 0.02
	var s := MeshBuilder.new()
	s.box_mm(&"item_glossy", Vector3(-0.3, top, -0.2), Vector3(0.3, top + 0.025, 0.2), 0.004)
	_slab = MeshInstance3D.new()
	_slab.mesh = s.build()
	_slab_mat = StandardMaterial3D.new()
	_slab_mat.emission_enabled = true
	_slab.material_override = _slab_mat
	add_child(_slab)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var c := MeshBuilder.new()
	for i: int in 14:
		c.color = Color(0.78, 0.9, 0.97).lerp(Color(0.95, 0.98, 1.0), rng.randf())
		var p := Vector3(rng.randf_range(-0.25, 0.25), top + 0.015, rng.randf_range(-0.16, 0.16))
		c.box(&"item_glossy", p, Vector3(rng.randf_range(0.04, 0.09), 0.025, rng.randf_range(0.03, 0.07)))
	_shards = MeshInstance3D.new()
	_shards.mesh = c.build()
	add_child(_shards)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, HEIGHT + 0.05, DEPTH)
	cs.shape = shape
	cs.position.y = (HEIGHT + 0.05) * 0.5
	add_child(cs)


func state_changed() -> void:
	if _slab == null:
		return
	var stage: int = int(state["stage"])
	_slab.visible = stage == Stage.RUNNING
	_shards.visible = stage == Stage.DONE
	if stage == Stage.RUNNING:
		var hot: float = 1.0 - float(state["progress"])
		_slab_mat.albedo_color = Color(0.8, 0.88, 0.95).lerp(Color(0.95, 0.55, 0.25), hot)
		_slab_mat.emission = Color(1.0, 0.4, 0.1) * hot * 0.8


func tick(h: float) -> bool:
	var was: int = int(float(state["progress"]) * 20.0)
	super(h)
	return int(float(state["progress"]) * 20.0) != was  # recolour the slab now and then
