@tool
class_name ProcTree
extends StaticBody3D
## Procedural deciduous tree: bark trunk + branches and a crown of alpha-tested
## leaf cards (one mesh, two materials). Card normals point away from the crown
## centre so the crown is lit like a soft volume.

@export var tree_seed: int = 1:
	set(v): tree_seed = v; _queue_rebuild()
@export var height: float = 8.0:
	set(v): height = v; _queue_rebuild()
@export var crown_radius: float = 2.8:
	set(v): crown_radius = v; _queue_rebuild()
@export var trunk_radius: float = 0.18:
	set(v): trunk_radius = v; _queue_rebuild()
@export_range(20, 600) var leaf_cards: int = 120:
	set(v): leaf_cards = v; _queue_rebuild()
@export var leaf_tint: Color = Color.WHITE:
	set(v): leaf_tint = v; _apply_tint()

var _generated: Array[Node] = []
var _mesh_instance: MeshInstance3D
var _pending: bool = false


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


func _apply_tint() -> void:
	if _mesh_instance:
		_mesh_instance.set_instance_shader_parameter(&"foliage_tint", leaf_tint)


func _rebuild() -> void:
	_pending = false
	for n: Node in _generated:
		n.queue_free()
	_generated.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	var b := MeshBuilder.new()

	var trunk_h: float = height * rng.randf_range(0.42, 0.52)
	var crown_c := Vector3(rng.randf_range(-0.2, 0.2), trunk_h + (height - trunk_h) * 0.5, rng.randf_range(-0.2, 0.2))
	var crown_r := Vector3(crown_radius, maxf((height - trunk_h) * 0.6, crown_radius * 0.8), crown_radius) * rng.randf_range(0.9, 1.1)

	# Trunk in two slightly bent segments.
	var mid := Vector3(rng.randf_range(-0.15, 0.15), trunk_h * 0.55, rng.randf_range(-0.15, 0.15))
	var top := Vector3(crown_c.x * 0.6, trunk_h, crown_c.z * 0.6)
	b.cylinder(&"bark", Vector3(0, -0.1, 0), mid, trunk_radius * 1.25, trunk_radius, 9, false, 1.0)
	b.cylinder(&"bark", mid, top, trunk_radius, trunk_radius * 0.8, 9, false, 1.0)
	# Main branches into the crown.
	var branch_ends: Array[Vector3] = []
	var branches: int = rng.randi_range(4, 6)
	for i: int in branches:
		var a: float = TAU * float(i) / branches + rng.randf_range(-0.4, 0.4)
		var start: Vector3 = top.lerp(mid, rng.randf_range(0.0, 0.35))
		var end: Vector3 = crown_c + Vector3(cos(a) * crown_r.x * 0.75, rng.randf_range(-0.1, 0.6) * crown_r.y, sin(a) * crown_r.z * 0.75)
		b.cylinder(&"bark", start, end, trunk_radius * 0.55, trunk_radius * 0.15, 6, false, 1.0)
		branch_ends.append(end)
	b.cylinder(&"bark", top, crown_c + Vector3(0, crown_r.y * 0.7, 0), trunk_radius * 0.6, trunk_radius * 0.12, 6, false, 1.0)

	# Leaf cards: clustered around branch ends and spread through the crown.
	var uv := PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	for i: int in leaf_cards:
		var p: Vector3
		if i % 2 == 0 or branch_ends.is_empty():
			# Random point in the crown ellipsoid, biased towards its surface.
			var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
			d.y = d.y * 0.85 + 0.1
			p = crown_c + d * crown_r * pow(rng.randf(), 0.35) * 0.95
		else:
			p = branch_ends[rng.randi() % branch_ends.size()] + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 0.8), rng.randf_range(-1, 1)) * crown_radius * 0.45
		var outward: Vector3 = ((p - crown_c) / crown_r)
		var wind: float = clampf(outward.length(), 0.2, 1.0)
		var n: Vector3 = outward.normalized() if outward.length() > 0.05 else Vector3.UP
		n = (n + Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(0.0, 0.8), rng.randf_range(-0.9, 0.9))).normalized()
		var s: float = rng.randf_range(1.1, 1.8)
		# Random card orientation around its normal.
		var t1: Vector3 = n.cross(Vector3.UP if absf(n.y) < 0.95 else Vector3.RIGHT).normalized()
		var t2: Vector3 = n.cross(t1).normalized()
		var rot: float = rng.randf() * TAU
		var u: Vector3 = (t1 * cos(rot) + t2 * sin(rot)) * s * 0.5
		var v: Vector3 = (t2 * cos(rot) - t1 * sin(rot)) * s * 0.5
		b.color = Color(wind, 0, 0)
		b.card(&"leaves", p - u - v, p + u - v, p + u + v, p - u + v, n, uv)
	b.color = Color.WHITE

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = b.build()
	add_child(_mesh_instance)
	_generated.append(_mesh_instance)
	_apply_tint()

	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = trunk_radius * 1.2
	shape.height = trunk_h
	cs.shape = shape
	cs.position.y = trunk_h / 2.0
	add_child(cs)
	_generated.append(cs)
