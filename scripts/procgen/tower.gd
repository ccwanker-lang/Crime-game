@tool
class_name Tower
extends StaticBody3D
## Map zone 7 (the city): an office tower / skyscraper. Origin = the centre of its footprint at street level; the
## front faces -Z. Glass bands per floor between spandrel bands, mullions, a lobby with a canopy, an optional
## setback for the upper floors, roof plant and an antenna on tall ones. Not enterable (one collision box per
## volume, layer 1 = the navmesh goes round it).

@export var width: float = 20.0:
	set(v): width = v; _queue_rebuild()
@export var depth: float = 20.0:
	set(v): depth = v; _queue_rebuild()
@export_range(3, 60) var floors: int = 12:
	set(v): floors = v; _queue_rebuild()
@export var floor_height: float = 3.4:
	set(v): floor_height = v; _queue_rebuild()
## glass = curtain wall, bands = concrete with window strips, brick = older office block.
@export_enum("glass", "bands", "brick") var style: String = "glass":
	set(v): style = v; _queue_rebuild()
@export var tint: Color = Color(0.62, 0.66, 0.7):
	set(v): tint = v; _queue_rebuild()
## Floors from this one up are set back (0 = none).
@export var setback_from: int = 0:
	set(v): setback_from = v; _queue_rebuild()
@export var setback: float = 3.0:
	set(v): setback = v; _queue_rebuild()
@export var antenna: bool = false:
	set(v): antenna = v; _queue_rebuild()
@export var sign_text: String = "":
	set(v): sign_text = v; _queue_rebuild()
@export var variation_seed: int = 1:
	set(v): variation_seed = v; _queue_rebuild()

const MULLION: float = 1.6  # metres between vertical mullions

var _generated: Array[Node] = []
var _pending: bool = false


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


func height() -> float:
	return floors * floor_height


func _rebuild() -> void:
	_pending = false
	for n: Node in _generated:
		n.queue_free()
	_generated.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = variation_seed
	var b := MeshBuilder.new()
	var lower: int = floors if setback_from <= 0 or setback_from >= floors else setback_from
	_volume(b, Vector2(width, depth), 0, lower, true, rng)
	var top_size := Vector2(width, depth)
	if lower < floors:
		top_size = Vector2(maxf(6.0, width - 2.0 * setback), maxf(6.0, depth - 2.0 * setback))
		_volume(b, top_size, lower, floors, false, rng)
	_roof(b, top_size, height(), rng)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	_generated.append(mi)
	# Collision: one box per volume.
	_box_shape(Vector3(width, lower * floor_height, depth), Vector3(0, lower * floor_height / 2.0, 0))
	if lower < floors:
		var h: float = (floors - lower) * floor_height
		_box_shape(Vector3(top_size.x, h, top_size.y), Vector3(0, lower * floor_height + h / 2.0, 0))
	if sign_text != "":
		var lbl := Label3D.new()
		lbl.text = sign_text
		lbl.font_size = 220
		lbl.pixel_size = 0.01
		lbl.modulate = Color(0.95, 0.95, 0.92)
		lbl.outline_size = 0
		lbl.position = Vector3(0, height() - 2.0, -top_size.y / 2.0 - 0.12)
		lbl.rotation.y = PI
		lbl.double_sided = false
		add_child(lbl)
		_generated.append(lbl)


func _box_shape(size: Vector3, at: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = at
	add_child(cs)
	_generated.append(cs)


## Floors f0..f1 of a box volume `size` (x, z) centred on the origin.
func _volume(b: MeshBuilder, size: Vector2, f0: int, f1: int, lobby: bool, rng: RandomNumberGenerator) -> void:
	var y0: float = f0 * floor_height
	var y1: float = f1 * floor_height
	var wall_key: StringName = &"concrete" if style != "brick" else &"brick_mixed"
	var core: Color = tint if style != "glass" else tint.darkened(0.35)
	# The solid core (a little inside the glass).
	b.color = core
	b.box(wall_key, Vector3(0, (y0 + y1) / 2.0, 0), Vector3(size.x - 0.3, y1 - y0, size.y - 0.3))
	var glass_h: float = floor_height * (0.78 if style == "glass" else 0.48)
	for f: int in range(f0, f1):
		var fy: float = f * floor_height
		if lobby and f == 0:
			# Lobby: tall shop glass, a dark band and a canopy over the entrance.
			b.color = Color.WHITE
			_band(b, size, fy + 0.2, fy + floor_height - 0.5, &"glass_shop", 0.02)
			b.color = tint.darkened(0.45)
			_band(b, size, fy + floor_height - 0.5, fy + floor_height, &"trim_paint", 0.06)
			continue
		b.color = Color.WHITE
		var gy0: float = fy + (floor_height - glass_h) * 0.5
		_glass_band(b, size, gy0, gy0 + glass_h, f, 0.03)
		if style != "glass":
			b.color = tint
			_band(b, size, fy, gy0, wall_key, 0.06)
			_band(b, size, gy0 + glass_h, fy + floor_height, wall_key, 0.06)
		else:
			b.color = tint.lightened(0.15)
			_band(b, size, fy - 0.12, fy + 0.12, &"trim_paint", 0.05)
	# Mullions over the full height of the volume.
	b.color = tint.lightened(0.1) if style == "glass" else tint.darkened(0.1)
	var y_lo: float = y0 + (floor_height if lobby else 0.0)
	if y1 - y_lo > 0.5:
		for side: int in 4:
			var along: float = size.x if side % 2 == 0 else size.y
			var n: int = maxi(2, int(along / MULLION))
			for i: int in range(1, n):
				var t: float = -along / 2.0 + along * i / n
				var c: Vector3
				var s: Vector3
				match side:
					0: c = Vector3(t, 0, -size.y / 2.0); s = Vector3(0.12, 0, 0.16)
					1: c = Vector3(size.x / 2.0, 0, t); s = Vector3(0.16, 0, 0.12)
					2: c = Vector3(t, 0, size.y / 2.0); s = Vector3(0.12, 0, 0.16)
					_: c = Vector3(-size.x / 2.0, 0, t); s = Vector3(0.16, 0, 0.12)
				c.y = (y_lo + y1) / 2.0
				s.y = y1 - y_lo
				b.box(&"trim_paint", c, s)
	# Corner piers.
	b.color = tint
	for cx: float in [-size.x / 2.0, size.x / 2.0]:
		for cz: float in [-size.y / 2.0, size.y / 2.0]:
			b.box(wall_key, Vector3(cx, (y0 + y1) / 2.0, cz), Vector3(0.5, y1 - y0, 0.5))
	if lobby:
		b.color = tint.darkened(0.3)
		b.box(&"trim_paint", Vector3(0, floor_height - 0.35, -size.y / 2.0 - 1.4), Vector3(minf(8.0, size.x * 0.5), 0.25, 2.8))


## The glass of floor `f` round the volume: one quad per face with UV x = window number, y = floor number
## (tower_glass.gdshader gives every window its own look).
func _glass_band(b: MeshBuilder, size: Vector2, ya: float, yb: float, f: int, out: float) -> void:
	var hx: float = size.x / 2.0 - 0.15 + out
	var hz: float = size.y / 2.0 - 0.15 + out
	var faces: Array = [  # corner a, corner b (along the face), outward
		[Vector2(-hx, -hz), Vector2(hx, -hz), Vector3.FORWARD], [Vector2(hx, -hz), Vector2(hx, hz), Vector3.RIGHT],
		[Vector2(hx, hz), Vector2(-hx, hz), Vector3.BACK], [Vector2(-hx, hz), Vector2(-hx, -hz), Vector3.LEFT]]
	for face: Array in faces:
		var a: Vector2 = face[0]
		var c: Vector2 = face[1]
		var n: float = float(maxi(2, int(a.distance_to(c) / MULLION)))
		b.quad(&"tower_glass", Vector3(a.x, ya, a.y), Vector3(c.x, ya, c.y), Vector3(c.x, yb, c.y), Vector3(a.x, yb, a.y),
				face[2], PackedVector2Array([Vector2(0, f), Vector2(n, f), Vector2(n, f + 1), Vector2(0, f + 1)]))


## A ring of quads round the volume between heights ya..yb, `out` m proud of the core face.
func _band(b: MeshBuilder, size: Vector2, ya: float, yb: float, key: StringName, out: float) -> void:
	var hx: float = size.x / 2.0 - 0.15 + out
	var hz: float = size.y / 2.0 - 0.15 + out
	b.box(key, Vector3(0, (ya + yb) / 2.0, -hz), Vector3(hx * 2.0, yb - ya, 0.02), 0.0)
	b.box(key, Vector3(0, (ya + yb) / 2.0, hz), Vector3(hx * 2.0, yb - ya, 0.02), 0.0)
	b.box(key, Vector3(-hx, (ya + yb) / 2.0, 0), Vector3(0.02, yb - ya, hz * 2.0), 0.0)
	b.box(key, Vector3(hx, (ya + yb) / 2.0, 0), Vector3(0.02, yb - ya, hz * 2.0), 0.0)


func _roof(b: MeshBuilder, size: Vector2, top: float, rng: RandomNumberGenerator) -> void:
	b.color = tint.darkened(0.2)
	# Parapet.
	for side: int in 4:
		var horiz: bool = side % 2 == 0
		var run_len: float = size.x if horiz else size.y
		var off: float = (size.y if horiz else size.x) / 2.0 * (-1.0 if side < 2 else 1.0)
		var c := Vector3(0, top + 0.5, off) if horiz else Vector3(off, top + 0.5, 0)
		b.box(&"concrete", c, Vector3(run_len, 1.0, 0.3) if horiz else Vector3(0.3, 1.0, run_len))
	b.color = Color(0.5, 0.5, 0.52)
	b.box(&"concrete", Vector3(0, top + 0.05, 0), Vector3(size.x - 0.4, 0.1, size.y - 0.4))
	# Plant room + AC units.
	b.color = tint.darkened(0.1)
	b.box(&"concrete", Vector3(rng.randf_range(-1, 1), top + 1.6, rng.randf_range(-1, 1)), Vector3(size.x * 0.4, 3.2, size.y * 0.35))
	b.color = Color(0.7, 0.71, 0.72)
	for i: int in rng.randi_range(2, 5):
		b.box(&"item_metal", Vector3(rng.randf_range(-0.35, 0.35) * size.x, top + 0.7, rng.randf_range(-0.35, 0.35) * size.y), Vector3(1.6, 1.2, 1.2))
	if antenna:
		b.color = Color(0.75, 0.75, 0.78)
		b.cylinder(&"item_metal", Vector3(0, top + 3.2, 0), Vector3(0, top + 3.2 + floors * 0.35, 0), 0.25, 0.06, 6)
