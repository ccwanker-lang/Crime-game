class_name TrafficLight
extends Node3D
## Point 63: one traffic light pole at a junction corner (local visual on every peer, no collision). Its head faces
## the traffic of `axis` coming from `facing` and shows Traffic.light_state(junction, axis).

var junction: int = 0
var axis: StringName = &"x"
var facing: Vector3 = Vector3.FORWARD

var _lamps: Array[MeshInstance3D] = []  # red, amber, green
var _shown: StringName = &""

static var _mats: Dictionary = {}


static func _mat(colour: Color, lit: bool) -> StandardMaterial3D:
	var key: String = "%s%s" % [colour.to_html(), lit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	if lit:
		m.albedo_color = colour
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = 2.5
	else:
		m.albedo_color = colour.darkened(0.8)
	_mats[key] = m
	return m


func _ready() -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.13, 0.13)
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.07
	cyl.height = 3.0
	cyl.radial_segments = 8
	cyl.material = dark
	pole.mesh = cyl
	pole.position.y = 1.5
	add_child(pole)
	var head := Node3D.new()
	head.position.y = 2.7
	add_child(head)
	head.rotation = Vector3(0, atan2(facing.x, facing.z), 0)  # +Z of the head points at the drivers
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.32, 0.86, 0.22)
	bm.material = dark
	box.mesh = bm
	head.add_child(box)
	var cols: Array[Color] = [Color(1.0, 0.12, 0.08), Color(1.0, 0.62, 0.05), Color(0.15, 1.0, 0.35)]
	for i: int in 3:
		var lamp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.085
		sm.height = 0.17
		sm.radial_segments = 10
		sm.rings = 5
		lamp.mesh = sm
		lamp.position = Vector3(0, 0.26 - i * 0.26, 0.1)
		lamp.set_meta("col", cols[i])
		head.add_child(lamp)
		_lamps.append(lamp)
	_show(&"red")


func _process(_delta: float) -> void:
	var traffic := get_parent() as Traffic
	if traffic:
		_show(traffic.light_state(junction, axis))


func _show(state: StringName) -> void:
	if state == _shown:
		return
	_shown = state
	var on: Array[bool] = [state == &"red", state == &"amber", state == &"green"]
	for i: int in 3:
		_lamps[i].material_override = _mat(_lamps[i].get_meta("col"), on[i])
