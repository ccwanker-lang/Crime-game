@tool
class_name WashingMachine
extends StaticBody3D
## Point 9: a front-loading washing machine (laundromat), procedural. Origin at the
## bottom centre, front (the round door) towards +Z.

const SIZE: Vector3 = Vector3(0.6, 0.85, 0.6)


func _ready() -> void:
	for c: Node in get_children():
		if c.has_meta(&"generated"):
			c.queue_free()
	var b := MeshBuilder.new()
	var h: float = SIZE.y
	var fz: float = SIZE.z * 0.5
	b.box(&"item_glossy", Vector3(0, h * 0.5, 0), SIZE, 0.02)
	# Control panel strip, knob and the round door (chrome ring + dark glass).
	b.box(&"metal_dark", Vector3(0, h - 0.07, fz + 0.002), Vector3(SIZE.x - 0.06, 0.09, 0.01))
	b.cylinder(&"zinc", Vector3(0.18, h - 0.07, fz), Vector3(0.18, h - 0.07, fz + 0.025), 0.025, 0.025, 12, true)
	b.cylinder(&"car_chrome", Vector3(0, 0.4, fz), Vector3(0, 0.4, fz + 0.03), 0.2, 0.19, 24, true)
	b.cylinder(&"car_glass", Vector3(0, 0.4, fz + 0.03), Vector3(0, 0.4, fz + 0.04), 0.155, 0.15, 24, true)
	b.box(&"metal_dark", Vector3(0, 0.03, 0), Vector3(SIZE.x - 0.04, 0.06, SIZE.z - 0.04))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	mi.set_meta(&"generated", true)
	add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = SIZE
	cs.shape = shape
	cs.position.y = h * 0.5
	cs.set_meta(&"generated", true)
	add_child(cs)
