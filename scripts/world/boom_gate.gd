@tool
class_name BoomGate
extends Node3D
## Point 93: a red-and-white boom barrier (the prison gate). The arm lifts by itself when a player, a crew car or a
## traffic car comes within `reach` m and drops again behind them. Purely visual and local on every
## peer (the arm has no collision, so it can never trap anyone on a late or lagging peer); the post is solid.
## Origin = the foot of the post; the arm points along -X.

@export var length: float = 6.5:
	set(v): length = v; _queue_rebuild()
@export var reach: float = 10.0

const CHECK_EVERY: float = 0.2
const OPEN_ANGLE: float = deg_to_rad(84.0)
const SPEED: float = 1.6  # rad/s

var is_open: bool = false
var _arm: Node3D
var _generated: Array[Node] = []
var _pending: bool = false
var _t: float = 0.0


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
	var post := StaticBody3D.new()
	add_child(post)
	_generated.append(post)
	var pb := MeshBuilder.new()
	pb.color = Color(0.85, 0.85, 0.82)
	pb.box(&"item_matte", Vector3(0, 0.55, 0), Vector3(0.45, 1.1, 0.45), 0.03)
	pb.color = Color(0.2, 0.2, 0.22)
	pb.box(&"item_matte", Vector3(0, 1.12, 0), Vector3(0.5, 0.06, 0.5))
	var pm := MeshInstance3D.new()
	pm.mesh = pb.build()
	post.add_child(pm)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.45, 1.1, 0.45)
	cs.shape = shape
	cs.position.y = 0.55
	post.add_child(cs)
	_arm = Node3D.new()
	_arm.position = Vector3(0, 1.0, 0)
	add_child(_arm)
	_generated.append(_arm)
	var ab := MeshBuilder.new()
	var stripes: int = maxi(3, int(length / 0.6))
	var step: float = length / stripes
	for i: int in stripes:
		ab.color = Color(0.85, 0.12, 0.1) if i % 2 == 0 else Color(0.95, 0.95, 0.92)
		ab.box(&"item_matte", Vector3(-0.15 - step * (i + 0.5), 0, 0), Vector3(step, 0.12, 0.08))
	ab.color = Color(0.2, 0.2, 0.22)
	ab.box(&"item_matte", Vector3(0.35, 0, 0), Vector3(0.5, 0.22, 0.14))  # counterweight
	var am := MeshInstance3D.new()
	am.mesh = ab.build()
	_arm.add_child(am)
	_arm.rotation.z = -OPEN_ANGLE if is_open else 0.0  # (the arm points -X: a negative turn lifts it)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _arm == null:
		return
	_t -= delta
	if _t <= 0.0:
		_t = CHECK_EVERY
		is_open = _someone_near()
	var target: float = -OPEN_ANGLE if is_open else 0.0
	_arm.rotation.z = move_toward(_arm.rotation.z, target, SPEED * delta)


func _someone_near() -> bool:
	var at: Vector3 = global_position + global_basis.x * (-length / 2.0)
	for group: StringName in [&"players", &"player_cars", &"cars"]:
		for n: Node in get_tree().get_nodes_in_group(group):
			var n3 := n as Node3D
			if n3 and n3.is_visible_in_tree() and n3.global_position.distance_to(at) < reach:
				return true
	return false
