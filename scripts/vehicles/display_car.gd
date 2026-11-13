@tool
class_name DisplayCar
extends StaticBody3D
## Point 45: a car on show at Carlo's Cars (static, world layer so the navmesh goes around it) with a
## price card above it. Look + price come from CarCatalog.

@export var model_id: String = "hatch":
	set(v):
		model_id = v
		_queue_rebuild()

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
	for c: Node in get_children():
		c.queue_free()
	var m: Dictionary = CarCatalog.get_model(model_id)
	var kind: int = int(m["kind"])
	var visual := Node3D.new()
	add_child(visual)
	ProcCar.build(visual, kind, ProcCar.PAINTS[int(CarCatalog.LOT_PAINT.get(model_id, 0))])
	var size: Vector3 = ProcCar.collision_size(kind)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y / 2.0 + 0.1
	add_child(shape)
	var card := Label3D.new()
	card.text = "%s\n€%s" % [m["name"], CarCatalog.money(int(m["price"]))]
	card.font_size = 56
	card.pixel_size = 0.006
	card.outline_size = 10
	card.modulate = Color(1.0, 0.9, 0.35)
	card.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	card.position.y = size.y + 0.9
	card.visibility_range_end = 30.0
	add_child(card)
