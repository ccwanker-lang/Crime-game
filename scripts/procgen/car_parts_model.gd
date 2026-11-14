@tool
extends Node3D
## Point 52: the "Spare Parts" item model: a small cardboard parts box with a brake disc and a filter on top.
## Origin = where the hand grips it (bottom middle), front = -Z.


func _ready() -> void:
	var b := MeshBuilder.new()
	b.color = Color(0.62, 0.48, 0.3)
	b.box(&"item_matte", Vector3(0, 0.07, 0), Vector3(0.26, 0.14, 0.18), 0.008)
	b.color = Color(0.85, 0.32, 0.12)
	b.box(&"item_matte", Vector3(0, 0.1, 0.091), Vector3(0.2, 0.05, 0.004))  # printed band
	b.color = Color(0.55, 0.56, 0.58)
	b.cylinder(&"item_matte", Vector3(-0.05, 0.14, 0), Vector3(-0.05, 0.16, 0), 0.075, 0.075, 16, true)  # brake disc
	b.color = Color(0.2, 0.2, 0.22)
	b.cylinder(&"item_matte", Vector3(-0.05, 0.16, 0), Vector3(-0.05, 0.17, 0), 0.03, 0.03, 10, true)
	b.color = Color(0.15, 0.3, 0.6)
	b.cylinder(&"item_matte", Vector3(0.07, 0.14, 0.01), Vector3(0.07, 0.22, 0.01), 0.04, 0.04, 12, true)  # oil filter
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	mi.visibility_range_end = 40.0
	add_child(mi)
