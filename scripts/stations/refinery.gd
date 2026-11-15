class_name Refinery
extends ProcessStation
## Cocaine step 3 (milestone 3, DESIGN "refinery"): a tank on a small furnace with pipes and a gauge.
## 1 Coca Paste -> REFINE_HOURS; at 60% the pressure needs venting (E, or a cook): vented = 8 Cocaine,
## not vented = 5. Package Cocaine + Baggies at the packaging table. Abstract game mechanic.

const REFINE_HOURS: float = 3.0
const OUT: int = 8
const WIDTH: float = 1.0
const DEPTH: float = 0.7
const HEIGHT: float = 1.5

var _glow: MeshInstance3D
var _flag: Label3D
var _bricks: MeshInstance3D


func _init() -> void:
	inputs = {"coca_paste": 1}
	output_id = "cocaine"
	quality_step = true
	mix_id = "pure_solvent"
	output_count = OUT
	missed_count = 5
	hours = REFINE_HOURS
	label = "Refinery"
	start_verb = "Load the paste"
	work_start = "pack"
	work_take = "take"
	attend_at = 0.6
	attend_verb = "Vent the pressure"
	attend_flag = "VENT!"
	attend_done = "Vented. A clean batch (8 Cocaine)."
	work_attend = "water"


func _build() -> void:
	var b := MeshBuilder.new()
	b.box(&"brick_old", Vector3(-0.15, 0.25, 0), Vector3(0.65, 0.5, 0.6), 0.01)  # furnace
	b.box(&"metal_dark", Vector3(-0.15, 0.2, 0.301), Vector3(0.3, 0.2, 0.01))  # furnace door
	b.cylinder(&"item_metal", Vector3(-0.15, 0.5, 0), Vector3(-0.15, 1.15, 0), 0.26, 0.26, 16, true)  # tank
	b.sphere(&"item_metal", Vector3(-0.15, 1.15, 0), 0.26, 4, 16, Vector3(1, 0.45, 1))
	b.cylinder(&"metal_dark", Vector3(-0.15, 1.27, 0), Vector3(0.3, 1.27, 0), 0.03, 0.03, 8, false)  # pipe over
	b.cylinder(&"metal_dark", Vector3(0.3, 1.27, 0), Vector3(0.3, 0.75, 0), 0.03, 0.03, 8, false)  # pipe down
	b.box(&"zinc", Vector3(0.3, 0.37, 0), Vector3(0.36, 0.74, 0.5), 0.01)  # collecting table
	b.color = Color(0.95, 0.95, 0.9)
	b.cylinder(&"item_glossy", Vector3(0.12, 0.85, 0.19), Vector3(0.12, 0.85, 0.24), 0.06, 0.06, 12, true)  # gauge
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	var g := MeshBuilder.new()
	g.color = Color(1.0, 0.45, 0.1)
	g.box(&"item_glossy", Vector3(-0.15, 0.2, 0.307), Vector3(0.26, 0.16, 0.005))
	_glow = MeshInstance3D.new()
	_glow.mesh = g.build()
	add_child(_glow)
	var k := MeshBuilder.new()
	for i: int in 4:
		k.color = Color(0.96, 0.96, 0.94)
		k.box(&"item_matte", Vector3(0.22 + (i % 2) * 0.15, 0.77 + floorf(i / 2.0) * 0.05, -0.05), Vector3(0.13, 0.05, 0.1), 0.006)
	_bricks = MeshInstance3D.new()
	_bricks.mesh = k.build()
	add_child(_bricks)
	_flag = make_attend_label(Vector3(-0.15, 1.7, 0))
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, HEIGHT, DEPTH)
	cs.shape = shape
	cs.position.y = HEIGHT * 0.5
	add_child(cs)


func state_changed() -> void:
	if _glow == null:
		return
	var stage: int = int(state["stage"])
	_glow.visible = stage == Stage.RUNNING
	_bricks.visible = stage == Stage.DONE
	_flag.visible = needs_attention() and not ghost
