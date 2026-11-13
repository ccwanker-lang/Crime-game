class_name CookStation
extends ProcessStation
## Meth step 1 (milestone 3, DESIGN "Products"): a steel lab bench with a burner and a kettle.
## Load 2 Lab Chemicals + 1 Activator -> cooks for COOK_HOURS. Halfway the batch needs a stir
## (E, or a cook on staff): stirred = 2 Hot Trays, never stirred = 1. Abstract, no real procedure.

const COOK_HOURS: float = 3.0
const STIR_AT: float = 0.4
const WIDTH: float = 1.2
const DEPTH: float = 0.6
const HEIGHT: float = 0.9

var _kettle_glow: MeshInstance3D
var _steam: GPUParticles3D
var _stir_label: Label3D
var _trays: Array[MeshInstance3D] = []


func _init() -> void:
	inputs = {"lab_chemicals": 2, "activator": 1}
	output_id = "meth_tray"
	output_count = 2
	hours = COOK_HOURS
	label = "Cooking station"
	start_verb = "Start a cook"
	work_start = "pack"
	work_take = "take"
	attend_at = STIR_AT
	missed_count = 1
	attend_verb = "Stir the batch"
	attend_flag = "STIR!"
	attend_done = "Stirred. The batch will come out right (2 trays)."


func _build() -> void:
	var b := MeshBuilder.new()
	var hw: float = WIDTH * 0.5
	var hd: float = DEPTH * 0.5
	b.box(&"zinc", Vector3(0, HEIGHT - 0.02, 0), Vector3(WIDTH, 0.04, DEPTH), 0.004)
	for x: float in [-hw + 0.04, hw - 0.04]:
		for z: float in [-hd + 0.04, hd - 0.04]:
			b.box(&"metal_dark", Vector3(x, (HEIGHT - 0.04) * 0.5, z), Vector3(0.04, HEIGHT - 0.04, 0.04))
	b.box(&"metal_dark", Vector3(0, 0.15, 0), Vector3(WIDTH - 0.08, 0.02, DEPTH - 0.08))
	var top: float = HEIGHT
	# Burner + kettle on the left.
	b.box_mm(&"metal_dark", Vector3(-0.5, top, -0.2), Vector3(-0.1, top + 0.08, 0.2), 0.01)
	b.cylinder(&"item_metal", Vector3(-0.3, top + 0.08, 0), Vector3(-0.3, top + 0.3, 0), 0.15, 0.14, 14, true)
	b.cylinder(&"metal_dark", Vector3(-0.3, top + 0.3, 0), Vector3(-0.3, top + 0.32, 0), 0.155, 0.155, 14, true)
	# Gas bottle under the bench, jugs + a measuring jar on the right.
	b.cylinder(&"pot_plastic", Vector3(-0.35, 0.17, 0), Vector3(-0.35, 0.6, 0), 0.12, 0.12, 12, true)
	for i: int in 2:
		b.color = Color(0.85, 0.85, 0.8) if i == 0 else Color(0.3, 0.45, 0.75)
		b.box_mm(&"item_matte", Vector3(0.12 + i * 0.16, top, -0.2), Vector3(0.24 + i * 0.16, top + 0.22, -0.08), 0.01)
	b.color = Color(0.95, 0.97, 1.0, 0.35)
	b.cylinder(&"item_clear", Vector3(0.45, top, 0.1), Vector3(0.45, top + 0.16, 0.1), 0.05, 0.05, 10, true)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	# Kettle glow (visible while cooking).
	var g := MeshBuilder.new()
	g.color = Color(1.0, 0.45, 0.1)
	g.cylinder(&"item_glossy", Vector3(-0.3, top + 0.075, 0), Vector3(-0.3, top + 0.085, 0), 0.13, 0.13, 12, true)
	_kettle_glow = MeshInstance3D.new()
	_kettle_glow.mesh = g.build()
	add_child(_kettle_glow)
	# Finished trays on the bench.
	for i: int in 2:
		var t := MeshBuilder.new()
		t.color = Color(0.55, 0.55, 0.58)
		t.box_mm(&"item_metal", Vector3(0.05, top, 0.0 + i * 0.0), Vector3(0.38, top + 0.03, 0.26), 0.004)
		t.color = Color(0.82, 0.9, 0.95)
		t.box_mm(&"item_glossy", Vector3(0.07, top + 0.01, 0.02), Vector3(0.36, top + 0.032, 0.24))
		var tm := MeshInstance3D.new()
		tm.mesh = t.build()
		tm.position.y = i * 0.035
		add_child(tm)
		_trays.append(tm)
	_steam = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.4
	pm.gravity = Vector3(0, 0.15, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	_steam.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var sm := StandardMaterial3D.new()
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.9, 0.92, 0.95, 0.25)
	quad.material = sm
	_steam.draw_pass_1 = quad
	_steam.amount = 12
	_steam.lifetime = 1.6
	_steam.position = Vector3(-0.3, top + 0.34, 0)
	add_child(_steam)
	_stir_label = make_attend_label(Vector3(-0.3, top + 0.6, 0))
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, HEIGHT + 0.3, DEPTH)
	cs.shape = shape
	cs.position.y = (HEIGHT + 0.3) * 0.5
	add_child(cs)


func state_changed() -> void:
	if _kettle_glow == null:
		return
	var running: bool = int(state["stage"]) == Stage.RUNNING
	_kettle_glow.visible = running
	_steam.emitting = running and not ghost
	_stir_label.visible = needs_attention() and not ghost
	var out: int = int(state["out"]) if int(state["stage"]) == Stage.DONE else 0
	for i: int in _trays.size():
		_trays[i].visible = i < out
