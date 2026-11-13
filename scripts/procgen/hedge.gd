@tool
class_name Hedge
extends StaticBody3D
## Trimmed hedge: a dark core box covered with leaf cards. Origin at the
## bottom centre; it runs along X.

@export var size: Vector3 = Vector3(4, 1.4, 0.8):
	set(v): size = v; _queue_rebuild()
@export var hedge_seed: int = 1:
	set(v): hedge_seed = v; _queue_rebuild()

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
	var rng := RandomNumberGenerator.new()
	rng.seed = hedge_seed
	var b := MeshBuilder.new()
	var h: Vector3 = size * 0.5
	if ArtStyle.stylized:
		_build_stylized(b, rng)
		return
	var core_inset: float = 0.12
	b.box(&"hedge_core", Vector3(0, h.y - core_inset / 2.0, 0), size - Vector3(core_inset, core_inset, core_inset) * 2.0, 0.1)
	var uv := PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	# Cards on the four sides and the top, roughly 2 per square metre.
	var faces: Array[Array] = [
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP, size.x, size.y],
		[Vector3.FORWARD, Vector3.RIGHT, Vector3.UP, size.x, size.y],
		[Vector3.RIGHT, Vector3.BACK, Vector3.UP, size.z, size.y],
		[Vector3.LEFT, Vector3.BACK, Vector3.UP, size.z, size.y],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK, size.x, size.z]]
	for f: Array in faces:
		var n: Vector3 = f[0]
		var a1: Vector3 = f[1]
		var a2: Vector3 = f[2]
		var count: int = maxi(2, int(f[3] * f[4] * 3.0))
		for i: int in count:
			var c: Vector3 = Vector3(0, h.y, 0) + Vector3(n.x * h.x, n.y * h.y, n.z * h.z) * 0.92
			c += a1 * rng.randf_range(-0.5, 0.5) * f[3] + a2 * rng.randf_range(-0.5, 0.5) * f[4]
			var s: float = rng.randf_range(0.55, 0.85)
			var rot: float = rng.randf() * TAU
			var u: Vector3 = (a1 * cos(rot) + a2 * sin(rot)) * s * 0.5
			var v: Vector3 = (a2 * cos(rot) - a1 * sin(rot)) * s * 0.5
			var nn: Vector3 = (n + a1 * rng.randf_range(-0.3, 0.3) + Vector3.UP * 0.2).normalized()
			b.color = Color(0.25, 0, 0)
			b.card(&"leaves", c - u - v, c + u - v, c + u + v, c - u + v, nn, uv)
	b.color = Color.WHITE
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	_generated.append(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position.y = h.y
	add_child(cs)
	_generated.append(cs)


## Point 27 art direction: a rounded green box with a row of soft faceted bumps on top
## (no leaf cards).
func _build_stylized(b: MeshBuilder, rng: RandomNumberGenerator) -> void:
	var h: Vector3 = size * 0.5
	b.color = Palette.color(&"leaf_dark")
	b.box(&"leaves", Vector3(0, h.y * 0.92, 0), Vector3(size.x - 0.1, size.y * 0.92, size.z - 0.1), 0.12)
	var n: int = maxi(2, int(size.x / 0.7))
	for i: int in n:
		var x: float = -h.x + 0.35 + (size.x - 0.7) * float(i) / maxf(1.0, n - 1)
		b.blob(&"leaves", Vector3(x, size.y * 0.86, 0), 1.0, Vector3(0.42, 0.22, h.z * 1.02), rng,
				ArtStyle.colors(["leaf_dark", "leaf", "leaf_light"]), 0.12, 1, -0.2)
	b.color = Color.WHITE
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	_generated.append(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position.y = h.y
	add_child(cs)
	_generated.append(cs)
