@tool
class_name Watchtower
extends StaticBody3D
## Map zone 2 (the army base): a guard tower - four legs with cross braces, a platform with a railing, a cabin
## with windows, a roof, a ladder on the -Z side and a searchlight (lit at night). Origin on the ground.

@export var height: float = 8.0:
	set(v): height = v; _queue_rebuild()
@export var tint: Color = Color(0.42, 0.45, 0.32):
	set(v): tint = v; _queue_rebuild()

const HALF: float = 1.8

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
	var b := MeshBuilder.new()
	b.collide = true
	b.color = tint.darkened(0.2)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			b.box(&"item_metal", Vector3(sx * (HALF - 0.2), height / 2.0, sz * (HALF - 0.2)), Vector3(0.22, height, 0.22))
	b.collide = false
	for y: float in [height * 0.33, height * 0.66]:
		b.box(&"item_metal", Vector3(0, y, -HALF + 0.2), Vector3(HALF * 2.0 - 0.4, 0.12, 0.12))
		b.box(&"item_metal", Vector3(0, y, HALF - 0.2), Vector3(HALF * 2.0 - 0.4, 0.12, 0.12))
		b.box(&"item_metal", Vector3(-HALF + 0.2, y, 0), Vector3(0.12, 0.12, HALF * 2.0 - 0.4))
		b.box(&"item_metal", Vector3(HALF - 0.2, y, 0), Vector3(0.12, 0.12, HALF * 2.0 - 0.4))
	b.collide = true
	b.color = tint
	b.box(&"planks", Vector3(0, height, 0), Vector3(HALF * 2.0 + 0.6, 0.2, HALF * 2.0 + 0.6))
	# Cabin: half-height walls, window band, posts, roof.
	b.box(&"planks", Vector3(0, height + 0.6, -HALF - 0.2), Vector3(HALF * 2.0 + 0.6, 1.0, 0.1))
	b.box(&"planks", Vector3(0, height + 0.6, HALF + 0.2), Vector3(HALF * 2.0 + 0.6, 1.0, 0.1))
	b.box(&"planks", Vector3(-HALF - 0.2, height + 0.6, 0), Vector3(0.1, 1.0, HALF * 2.0 + 0.6))
	b.box(&"planks", Vector3(HALF + 0.2, height + 0.6, 0), Vector3(0.1, 1.0, HALF * 2.0 + 0.6))
	b.collide = false
	b.color = tint.darkened(0.25)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			b.box(&"item_metal", Vector3(sx * (HALF + 0.15), height + 1.5, sz * (HALF + 0.15)), Vector3(0.14, 2.8, 0.14))
	b.color = tint.darkened(0.1)
	b.box(&"corrugated", Vector3(0, height + 2.95, 0), Vector3(HALF * 2.0 + 1.2, 0.12, HALF * 2.0 + 1.2))
	# Ladder (-Z side).
	b.color = Color(0.35, 0.35, 0.35)
	for lx: float in [-0.25, 0.25]:
		b.box(&"item_metal", Vector3(lx, height / 2.0, -HALF - 0.05), Vector3(0.06, height, 0.06))
	var y: float = 0.4
	while y < height:
		b.box(&"item_metal", Vector3(0, y, -HALF - 0.05), Vector3(0.5, 0.05, 0.05))
		y += 0.4
	# Searchlight on the roof edge.
	b.color = Color(0.2, 0.2, 0.2)
	b.cylinder(&"item_metal", Vector3(0, height + 3.0, HALF + 0.3), Vector3(0, height + 3.0, HALF + 0.9), 0.32, 0.38, 10)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	_generated.append(mi)
	for box: Dictionary in b.collision_boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box["size"]
		cs.shape = shape
		cs.transform = box["xform"]
		add_child(cs)
		_generated.append(cs)
	if Engine.is_editor_hint() or DisplayServer.get_name() == "headless":
		return
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.97, 0.88)
	spot.spot_range = 45.0
	spot.spot_angle = 14.0
	spot.light_energy = 0.0
	spot.position = Vector3(0, height + 3.0, HALF + 0.9)
	spot.rotation = Vector3(deg_to_rad(-28.0), PI, 0)
	spot.add_to_group(&"night_spots")
	add_child(spot)
	_generated.append(spot)


func _process(_delta: float) -> void:
	if _generated.is_empty() or Engine.is_editor_hint():
		return
	var spot: SpotLight3D = _generated[-1] as SpotLight3D
	if spot == null:
		return
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	var night: bool = dn != null and dn.is_night()
	spot.light_energy = 6.0 if night else 0.0
	spot.rotation.y = PI + sin(Time.get_ticks_msec() / 2600.0 + position.x) * 0.9
