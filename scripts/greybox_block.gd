@tool
class_name GreyboxBlock
extends StaticBody3D
## Greybox building block: a box mesh with matching collision.
## Select it in the editor and change Size / Color in the Inspector.
## The mesh and collision are generated (not saved in the scene).

@export var size: Vector3 = Vector3(2, 2, 2):
	set(value):
		size = value
		_rebuild()

@export var color: Color = Color(0.6, 0.6, 0.6):
	set(value):
		color = value
		_rebuild()

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	# Setters also run while the scene loads; wait until we are in the tree.
	if not is_inside_tree():
		return
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		add_child(_mesh_instance)
		_collision = CollisionShape3D.new()
		add_child(_collision)

	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	_mesh_instance.mesh = mesh

	var shape := BoxShape3D.new()
	shape.size = size
	_collision.shape = shape
