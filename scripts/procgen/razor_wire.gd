@tool
class_name RazorWire
extends Node3D
## Point 99: barbed / razor wire on a wall or fence top - Y-shaped arms every ARM_STEP m carrying two coils. Visual
## only (the wall below already stops you), cheap: one mesh per run, cached per length, drawn up to DRAW_RANGE m.
## Origin = the start of the run on the wall top; it runs along +X for `length` m.

@export var length: float = 10.0:
	set(v): length = v; _queue_rebuild()

const ARM_STEP: float = 3.0
const COIL_R: float = 0.2
const PITCH: float = 0.32
const SEGMENTS: int = 6  # per turn
const DRAW_RANGE: float = 140.0

static var _cache: Dictionary = {}  # rounded length -> ArrayMesh

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
	mi.mesh = mesh_for(length)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = DRAW_RANGE
	mi.visibility_range_end_margin = 10.0
	add_child(mi)
	_generated.append(mi)


static func mesh_for(len: float) -> ArrayMesh:
	var key: int = roundi(len * 10.0)
	if _cache.has(key):
		return _cache[key]
	var b := MeshBuilder.new()
	b.color = Color(0.3, 0.31, 0.32)
	var arms: int = maxi(1, ceili(len / ARM_STEP))
	for i: int in arms + 1:
		var x: float = minf(i * ARM_STEP, len)
		b.box(&"item_metal", Vector3(x, 0.2, 0), Vector3(0.05, 0.4, 0.05))
		for side: float in [-1.0, 1.0]:
			b.cylinder(&"item_metal", Vector3(x, 0.38, 0), Vector3(x, 0.75, side * 0.32), 0.022, 0.022, 4, false)
	b.color = Color(0.55, 0.57, 0.6)
	for side: float in [-1.0, 1.0]:
		var c := Vector3(0, 0.62, side * 0.2)
		var turns: int = maxi(1, int(len / PITCH))
		var prev := Vector3.ZERO
		for k: int in turns * SEGMENTS + 1:
			var a: float = TAU * k / SEGMENTS
			var p := c + Vector3(k * PITCH / SEGMENTS, sin(a) * COIL_R, cos(a) * COIL_R)
			if k > 0:
				b.cylinder(&"item_metal", prev, p, 0.012, 0.012, 3, false)
			prev = p
	var mesh: ArrayMesh = b.build()
	_cache[key] = mesh
	return mesh
