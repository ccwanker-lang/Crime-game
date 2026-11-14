@tool
class_name HiddenShelfDoor
extends NetDoor
## Point 52: the secret door of the cover garage: a full tool shelf that slides aside (along +X) and shows the
## hidden room behind it. Works like every NetDoor (E, host authoritative, late-join state); only the look and
## the movement differ. Origin = the left edge of the opening at floor height, the room is on the -Z side.

@export var depth: float = 0.45


func _rebuild() -> void:
	_pending = false
	if _pivot:
		_pivot.queue_free()
	var body := AnimatableBody3D.new()
	body.collision_layer = 1 << (DOOR_LAYER - 1)
	body.collision_mask = 0
	_pivot = body
	add_child(body)
	var b := MeshBuilder.new()
	var d: float = depth
	# Frame: two uprights, top and bottom, a thin back panel; four shelves with tins, boxes and tools.
	for x: float in [0.03, width - 0.03]:
		b.box(&"planks", Vector3(x, height / 2.0, -d / 2.0), Vector3(0.06, height, d))
	b.box(&"planks", Vector3(width / 2.0, height - 0.03, -d / 2.0), Vector3(width, 0.06, d))
	b.box(&"planks", Vector3(width / 2.0, 0.05, -d / 2.0), Vector3(width, 0.1, d))
	b.box(&"planks", Vector3(width / 2.0, height / 2.0, -d + 0.01), Vector3(width, height, 0.02))
	var rng := RandomNumberGenerator.new()
	rng.seed = 52
	for i: int in 4:
		var y: float = 0.1 + i * (height - 0.2) / 4.0
		b.box(&"planks", Vector3(width / 2.0, y + 0.015, -d / 2.0), Vector3(width - 0.1, 0.03, d - 0.03))
		var x: float = 0.12
		while x < width - 0.2:
			var w: float = rng.randf_range(0.1, 0.24)
			var h: float = rng.randf_range(0.12, 0.38)
			b.color = [Color(0.75, 0.2, 0.12), Color(0.2, 0.35, 0.6), Color(0.85, 0.7, 0.2), Color(0.3, 0.3, 0.32),
					Color(0.6, 0.48, 0.3)][rng.randi() % 5]
			b.box(&"item_matte", Vector3(x + w / 2.0, y + 0.03 + h / 2.0, -d / 2.0), Vector3(w, h, d * 0.6), 0.005)
			x += w + rng.randf_range(0.02, 0.08)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = b.build()
	body.add_child(_mesh)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, d)
	cs.shape = shape
	cs.position = Vector3(width / 2.0, height / 2.0, -d / 2.0)
	body.add_child(cs)
	_pivot.position.x = width if is_open else 0.0


func set_color(_c: Color) -> void:
	pass  # (painted wood, not a door colour)


func get_interaction_prompt() -> String:
	return "Push the shelf back" if is_open else "Pull the tool shelf aside"


@rpc("authority", "call_local", "reliable")
func _set_open(open: bool) -> void:
	is_open = open
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_pivot, "position:x", width if open else 0.0, 0.8)


func apply_net_state(state: Dictionary) -> void:
	is_open = state.get("open", false)
	if _pivot:
		_pivot.position.x = width if is_open else 0.0
