@tool
class_name GroundArea
extends StaticBody3D
## Flat natural ground (grass/dirt shader) with collision. Top of the collision
## is at y = 0; the visual surface sits 3 cm lower so roads and paths on top
## never z-fight with it.

@export var size: Vector2 = Vector2(40, 40):
	set(v): size = v; _queue_rebuild()
@export var collision: bool = true:
	set(v): collision = v; _queue_rebuild()
@export var material: Material:
	set(v): material = v; _queue_rebuild()
## Point 61: GrassCover grows grass tufts on this ground (off for ground that isn't green).
@export var grass: bool = true

var _generated: Array[Node] = []
var _pending: bool = false


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_pending = false
	for n: Node in _generated:
		n.queue_free()
	_generated.clear()
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = int(size.x / 8.0)
	plane.subdivide_depth = int(size.y / 8.0)
	plane.material = material if material else load("res://prefabs/materials/ground.tres")
	mi.mesh = plane
	mi.position.y = -0.03
	add_child(mi)
	_generated.append(mi)
	if collision:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		# Point 56: a thick slab (top still at y 0) so nothing fast tunnels through it.
		shape.size = Vector3(size.x, 4.0, size.y)
		cs.shape = shape
		cs.position.y = -2.0
		add_child(cs)
		_generated.append(cs)
