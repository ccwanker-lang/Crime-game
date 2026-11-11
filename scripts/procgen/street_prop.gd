@tool
class_name StreetProp
extends StaticBody3D
## Small procedural street furniture. Origin at the bottom centre.

enum Kind { BOLLARD, POST_BOX, BIKE_RACK, SIGN_POST, MANHOLE, PLANTER, LIGHT_POLE }

@export var kind: Kind = Kind.BOLLARD:
	set(v): kind = v; _queue_rebuild()
@export var sign_text: String = "":
	set(v): sign_text = v; _queue_rebuild()

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
	var col_size := Vector3.ZERO
	var mi := MeshInstance3D.new()
	match kind:
		Kind.BOLLARD:
			b.cylinder(&"metal_dark", Vector3.ZERO, Vector3(0, 0.85, 0), 0.065, 0.06, 10)
			b.cylinder(&"zinc", Vector3(0, 0.85, 0), Vector3(0, 0.92, 0), 0.07, 0.03, 10)
			b.cylinder(&"zinc", Vector3(0, 0.7, 0), Vector3(0, 0.74, 0), 0.068, 0.068, 10, false)
			col_size = Vector3(0.14, 0.92, 0.14)
		Kind.POST_BOX:
			b.cylinder(&"metal_dark", Vector3.ZERO, Vector3(0, 0.75, 0), 0.05, 0.05, 8)
			b.box(&"door_paint", Vector3(0, 1.05, 0), Vector3(0.42, 0.6, 0.32), 0.04)
			b.box(&"metal_dark", Vector3(0, 1.22, 0.165), Vector3(0.26, 0.03, 0.01))
			mi.set_instance_shader_parameter(&"door_tint", Color(0.75, 0.12, 0.1))
			col_size = Vector3(0.42, 1.35, 0.32)
		Kind.BIKE_RACK:
			for x: float in [-0.9, -0.3, 0.3, 0.9]:
				b.cylinder(&"zinc", Vector3(x - 0.25, 0, 0), Vector3(x - 0.25, 0.7, 0), 0.025, 0.025, 6, false)
				b.cylinder(&"zinc", Vector3(x + 0.25, 0, 0), Vector3(x + 0.25, 0.7, 0), 0.025, 0.025, 6, false)
				b.cylinder(&"zinc", Vector3(x - 0.25, 0.7, 0), Vector3(x + 0.25, 0.7, 0), 0.025, 0.025, 6, false)
			col_size = Vector3(2.4, 0.75, 0.1)
		Kind.SIGN_POST:
			# The board grows with the text, so the name always fits; the
			# name is printed on both faces.
			var font_size: int = 48
			var pixel: float = 0.004
			var text_w: float = 0.0
			if sign_text != "":
				text_w = ThemeDB.fallback_font.get_string_size(sign_text, HORIZONTAL_ALIGNMENT_LEFT, -1,
						font_size).x * pixel
			var board_w: float = maxf(0.6, text_w + 0.2)
			b.cylinder(&"zinc", Vector3.ZERO, Vector3(0, 2.6, 0), 0.035, 0.035, 8)
			b.box(&"trim_paint", Vector3(0, 2.35, 0.055), Vector3(board_w, 0.3, 0.03), 0.005)
			# Thin white border on both faces.
			for z: float in [0.0705, 0.0395]:
				b.box(&"zinc", Vector3(0, 2.488, z), Vector3(board_w - 0.03, 0.012, 0.001))
				b.box(&"zinc", Vector3(0, 2.212, z), Vector3(board_w - 0.03, 0.012, 0.001))
			mi.set_instance_shader_parameter(&"trim_tint", Color(0.1, 0.25, 0.55))
			if sign_text != "":
				for side: int in 2:
					var label := Label3D.new()
					label.text = sign_text
					label.font_size = font_size
					label.pixel_size = pixel
					label.outline_size = 0
					label.double_sided = false
					label.modulate = Color(0.95, 0.95, 0.95)
					label.position = Vector3(0, 2.35, 0.072 if side == 0 else 0.038)
					label.rotation.y = 0.0 if side == 0 else PI
					add_child(label)
					_generated.append(label)
			col_size = Vector3(0.08, 2.6, 0.08)
		Kind.MANHOLE:
			b.cylinder(&"metal_dark", Vector3(0, 0.0, 0), Vector3(0, 0.012, 0), 0.33, 0.33, 16)
		Kind.LIGHT_POLE:
			# Steel pole (5 m) with a short arm towards +Z for a flood light.
			b.box(&"metal_dark", Vector3(0, 0.01, 0), Vector3(0.28, 0.02, 0.28))
			b.cylinder(&"zinc", Vector3.ZERO, Vector3(0, 5.0, 0), 0.075, 0.055, 10)
			b.cylinder(&"zinc", Vector3(0, 4.85, 0), Vector3(0, 4.85, 0.42), 0.035, 0.035, 8)
			col_size = Vector3(0.16, 5.0, 0.16)
		Kind.PLANTER:
			b.box(&"concrete", Vector3(0, 0.25, 0), Vector3(1.2, 0.5, 1.2), 0.04)
			b.box(&"soil", Vector3(0, 0.46, 0), Vector3(1.05, 0.06, 1.05))
			col_size = Vector3(1.2, 0.5, 1.2)
	mi.mesh = b.build()
	add_child(mi)
	_generated.append(mi)
	if col_size != Vector3.ZERO:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = col_size
		cs.shape = shape
		cs.position.y = col_size.y / 2.0
		add_child(cs)
		_generated.append(cs)
