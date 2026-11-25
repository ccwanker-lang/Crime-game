@tool
class_name ProcStairs
extends StaticBody3D
## Point 99: a straight flight of steps (prison galleries, army barracks, building-site scaffolds) - solid steps you
## see + one invisible ramp over their nosings that players and the navmesh walk (same trick as Building's
## stairwell). Origin = the foot of the flight at the middle of its width; it climbs `height` towards -Z over `run`.
## Optional handrail on the open side(s).

@export var width: float = 1.2:
	set(v): width = v; _queue_rebuild()
@export var height: float = 3.5:
	set(v): height = v; _queue_rebuild()
@export var run: float = 5.0:
	set(v): run = v; _queue_rebuild()
@export var material_key: StringName = &"metal_dark":
	set(v): material_key = v; _queue_rebuild()
## Handrails: 0 none, 1 on +X, 2 on -X, 3 both.
@export var rails: int = 3:
	set(v): rails = v; _queue_rebuild()

const RISE: float = 0.2

var _generated: Array[Node] = []
var _pending: bool = false


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


func step_count() -> int:
	return maxi(2, ceili(height / RISE))


func _rebuild() -> void:
	_pending = false
	for n: Node in _generated:
		n.queue_free()
	_generated.clear()
	var n: int = step_count()
	var rise: float = height / n
	var tread: float = run / n
	var hw: float = width / 2.0
	var b := MeshBuilder.new()
	b.color = Color(0.42, 0.43, 0.45)
	for i: int in n:
		var top: float = rise * (i + 1)
		var z0: float = -tread * i
		# Each step is a solid block down to the floor (no gaps to see through or fall in).
		b.box_mm(material_key, Vector3(-hw, 0.0, z0 - tread - 0.01), Vector3(hw, top, z0), 0.0)
	b.color = Color(0.2, 0.21, 0.23)
	for side: float in [1.0, -1.0]:
		if not (rails & (1 if side > 0.0 else 2)):
			continue
		var x: float = side * (hw - 0.04)
		var a := Vector3(x, 0.95, 0.0)
		var c := Vector3(x, height + 0.95, -run)
		b.cylinder(&"item_metal", a, c, 0.025, 0.025, 6)
		for k: int in 3:
			var t: float = (k + 0.5) / 3.0
			var p: Vector3 = Vector3(x, height * t, -run * t)
			b.box(&"item_metal", p + Vector3(0, 0.48, 0), Vector3(0.04, 0.95, 0.04))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	_generated.append(mi)
	# The ramp: a thin box along the slope from the first nosing to the top edge.
	var along := Vector3(0.0, height, -run)
	var tilt: float = atan2(along.y, -along.z)
	var basis := Basis(Vector3.RIGHT, tilt)
	var thick: float = 0.12
	var centre: Vector3 = along * 0.5 - basis.y * (thick * 0.5)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, thick, along.length() + 0.1)
	cs.shape = shape
	cs.transform = Transform3D(basis, centre)
	add_child(cs)
	_generated.append(cs)
	# A solid block under the slope (nothing walks into the space beneath the steps).
	var under := CollisionShape3D.new()
	var us := BoxShape3D.new()
	us.size = Vector3(width, height * 0.5, run * 0.5)
	under.shape = us
	under.position = Vector3(0.0, height * 0.25, -run * 0.75)
	add_child(under)
	_generated.append(under)
