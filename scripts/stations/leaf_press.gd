class_name LeafPress
extends ProcessStation
## Cocaine step 2 (milestone 3, DESIGN "processing machine"): a steel drum machine with a crank.
## 12 Coca Leaves + 1 Process Fluid -> PRESS_HOURS -> 1 Coca Paste. Abstract game mechanic.

const PRESS_HOURS: float = 2.0
const WIDTH: float = 0.9
const DEPTH: float = 0.7
const HEIGHT: float = 1.1

var _drum: MeshInstance3D
var _lamp: MeshInstance3D
var _lamp_mat: StandardMaterial3D


func _init() -> void:
	inputs = {"coca_leaves": 12, "process_fluid": 1}
	output_id = "coca_paste"
	output_count = 1
	hours = PRESS_HOURS
	label = "Leaf press"
	start_verb = "Press the leaves"
	work_start = "pack"
	work_take = "take"


func _build() -> void:
	var b := MeshBuilder.new()
	b.box(&"metal_dark", Vector3(0, 0.3, 0), Vector3(WIDTH, 0.6, DEPTH), 0.01)  # base cabinet
	b.box(&"zinc", Vector3(0, 0.61, 0), Vector3(WIDTH + 0.02, 0.03, DEPTH + 0.02))
	b.box(&"metal_dark", Vector3(-0.28, 0.85, -0.2), Vector3(0.08, 0.5, 0.08))  # frame posts
	b.box(&"metal_dark", Vector3(0.28, 0.85, -0.2), Vector3(0.08, 0.5, 0.08))
	b.box(&"metal_dark", Vector3(0, 1.1, -0.2), Vector3(0.66, 0.06, 0.1))
	b.cylinder(&"item_metal", Vector3(0.48, 0.85, 0.0), Vector3(0.56, 0.85, 0.0), 0.03, 0.03, 8, true)  # crank axle
	b.box(&"item_metal", Vector3(0.58, 0.75, 0.0), Vector3(0.03, 0.22, 0.03))
	b.color = Color(0.3, 0.45, 0.2)
	b.box_mm(&"item_matte", Vector3(-0.42, 0.62, 0.15), Vector3(-0.15, 0.72, 0.33), 0.01)  # tub of leaves
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	var d := MeshBuilder.new()
	d.cylinder(&"item_metal", Vector3(0, 0.62, 0), Vector3(0, 1.0, 0), 0.2, 0.2, 14, true)
	_drum = MeshInstance3D.new()
	_drum.mesh = d.build()
	add_child(_drum)
	var l := MeshBuilder.new()
	l.sphere(&"item_glossy", Vector3(0.3, 0.68, 0.3), 0.03)
	_lamp = MeshInstance3D.new()
	_lamp.mesh = l.build()
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.emission_enabled = true
	_lamp.material_override = _lamp_mat
	add_child(_lamp)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, HEIGHT, DEPTH)
	cs.shape = shape
	cs.position.y = HEIGHT * 0.5
	add_child(cs)


func state_changed() -> void:
	if _lamp == null:
		return
	var stage: int = int(state["stage"])
	var c: Color = Color(0.3, 0.3, 0.3)
	if stage == Stage.RUNNING:
		c = Color(1.0, 0.7, 0.1)
	elif stage == Stage.DONE:
		c = Color(0.2, 1.0, 0.3)
	_lamp_mat.albedo_color = c
	_lamp_mat.emission = c * (0.0 if stage == Stage.IDLE else 1.5)


func tick(h: float) -> bool:
	var running: bool = int(state["stage"]) == Stage.RUNNING
	super(h)
	if running and _drum:
		_drum.rotation.y += h * 40.0  # the drum turns while pressing
	return false
