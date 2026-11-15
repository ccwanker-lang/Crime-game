@tool
class_name JetHangar
extends StaticBody3D
## Point 85: an arched aircraft hangar (corrugated barrel roof on low side walls, a closed back, an open front).
## Origin on the ground at the middle of the open front; the hangar runs back along +Z (so it opens towards -Z).
## A jet parks at `jet_spot()` nose out. Layer 1 (world).

@export var width: float = 22.0:
	set(v): width = v; _queue_rebuild()
@export var depth: float = 22.0:
	set(v): depth = v; _queue_rebuild()
@export var wall_height: float = 3.5:
	set(v): wall_height = v; _queue_rebuild()
@export var rise: float = 6.0:  ## arch height above the side walls
	set(v): rise = v; _queue_rebuild()
@export var tint: Color = Color(0.36, 0.4, 0.27):
	set(v): tint = v; _queue_rebuild()
@export var number: String = "":
	set(v): number = v; _queue_rebuild()

const SEGMENTS: int = 10
const T: float = 0.2  # sheet thickness

var _generated: Array[Node] = []
var _pending: bool = false


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


## Where the jet stands (local): in the middle, nose towards the door.
func jet_spot() -> Vector3:
	return global_transform * Vector3(0, 0, depth * 0.5 + 0.5)


## The arch profile across the hangar: points (x, y) from the left wall top to the right wall top.
func _arch() -> PackedVector2Array:
	var half: float = width / 2.0
	var r: float = (half * half + rise * rise) / (2.0 * rise)
	var cy: float = wall_height + rise - r
	var a0: float = asin(clampf(half / r, -1.0, 1.0))
	var pts := PackedVector2Array()
	for i: int in SEGMENTS + 1:
		var a: float = lerpf(-a0, a0, float(i) / SEGMENTS)
		pts.append(Vector2(sin(a) * r, cy + cos(a) * r))
	return pts


func _add_shape(size: Vector3, xf: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = xf
	add_child(cs)
	_generated.append(cs)


func _rebuild() -> void:
	_pending = false
	for n: Node in _generated:
		n.queue_free()
	_generated.clear()
	collision_layer = 1
	collision_mask = 0
	var b := MeshBuilder.new()
	var half: float = width / 2.0
	var arch: PackedVector2Array = _arch()
	# Concrete floor.
	b.color = Color(0.62, 0.62, 0.6)
	b.box(&"concrete", Vector3(0, 0.03, depth / 2.0), Vector3(width, 0.06, depth))
	_add_shape(Vector3(width, 0.06, depth), Transform3D(Basis.IDENTITY, Vector3(0, 0.03, depth / 2.0)))  # (and no grass tufts inside)
	# Side walls.
	b.color = tint
	for s: float in [-1.0, 1.0]:
		b.box(&"corrugated", Vector3(s * (half - T / 2.0), wall_height / 2.0, depth / 2.0), Vector3(T, wall_height, depth))
		_add_shape(Vector3(T, wall_height, depth), Transform3D(Basis.IDENTITY, Vector3(s * (half - T / 2.0), wall_height / 2.0, depth / 2.0)))
	# Barrel roof: outside and inside faces per segment, plus a collision plate per segment.
	for i: int in SEGMENTS:
		var p0: Vector2 = arch[i]
		var p1: Vector2 = arch[i + 1]
		var a := Vector3(p0.x, p0.y, 0)
		var c := Vector3(p1.x, p1.y, 0)
		var mid: Vector2 = (p0 + p1) / 2.0
		var out := Vector3(mid.x, mid.y - (wall_height + rise - (half * half + rise * rise) / (2.0 * rise)), 0).normalized()
		b.color = tint
		b.quad(&"corrugated", a, c, c + Vector3(0, 0, depth), a + Vector3(0, 0, depth), out)
		b.color = tint.darkened(0.35)
		b.quad(&"corrugated", a - out * 0.05, c - out * 0.05, c + Vector3(0, 0, depth) - out * 0.05,
				a + Vector3(0, 0, depth) - out * 0.05, -out)
		var seg: Vector2 = p1 - p0
		var basis := Basis(Vector3.BACK, atan2(seg.y, seg.x))
		_add_shape(Vector3(seg.length(), T, depth), Transform3D(basis, Vector3(mid.x, mid.y, depth / 2.0)))
	# Back wall: the wall rectangle + the arch's half-moon above it.
	b.color = tint.darkened(0.1)
	var back := PackedVector3Array([Vector3(-half, 0, depth), Vector3(half, 0, depth)])
	for i: int in range(arch.size() - 1, -1, -1):
		back.append(Vector3(arch[i].x, arch[i].y, depth))
	b.poly(&"corrugated", back, Vector3.BACK)
	var inner := PackedVector3Array()
	for p: Vector3 in back:
		inner.append(p - Vector3(0, 0, 0.05))
	inner.reverse()
	b.poly(&"corrugated", inner, Vector3.FORWARD)
	_add_shape(Vector3(width, wall_height + rise, T), Transform3D(Basis.IDENTITY, Vector3(0, (wall_height + rise) / 2.0, depth + T / 2.0)))
	# Front: a steel header along the arch edge, door tracks on the ground, the hangar number above the door.
	b.color = Color(0.25, 0.26, 0.25)
	for i: int in SEGMENTS:
		var p0: Vector2 = arch[i]
		var p1: Vector2 = arch[i + 1]
		b.cylinder(&"metal_dark", Vector3(p0.x, p0.y - 0.1, -0.05), Vector3(p1.x, p1.y - 0.1, -0.05), 0.15, 0.15, 6)
	for s: float in [-1.0, 1.0]:
		b.box(&"metal_dark", Vector3(s * (half - 0.25), wall_height / 2.0, -0.1), Vector3(0.5, wall_height, 0.3))
	b.color = Color(0.4, 0.4, 0.38)
	b.box(&"metal_dark", Vector3(0, 0.02, -0.2), Vector3(width, 0.04, 0.3))
	# Strip lights under the roof.
	b.color = Color(1.0, 0.95, 0.85)
	for x: float in [-half * 0.4, half * 0.4]:
		b.box(&"lamp_glow", Vector3(x, wall_height + rise - 0.9, depth / 2.0), Vector3(0.3, 0.1, depth * 0.7))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	_generated.append(mi)
	var light := OmniLight3D.new()
	light.position = Vector3(0, wall_height + rise - 1.5, depth / 2.0)
	light.omni_range = maxf(width, depth) * 0.75
	light.light_energy = 1.2
	light.light_color = Color(1.0, 0.95, 0.85)
	add_child(light)
	_generated.append(light)
	if number != "":
		# Painted on both side walls, outside.
		for s: float in [-1.0, 1.0]:
			var label := Label3D.new()
			label.text = number
			label.font_size = 160
			label.pixel_size = 0.01
			label.modulate = Color(0.95, 0.9, 0.7)
			label.outline_size = 0
			label.position = Vector3(s * (half + 0.02), wall_height * 0.55, depth * 0.3)
			label.rotation.y = s * PI / 2.0
			add_child(label)
			_generated.append(label)
