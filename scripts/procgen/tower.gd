@tool
class_name Tower
extends StaticBody3D
## Map zone 7 (the city): an office tower / skyscraper. Origin = the centre of its footprint at street level; the
## front faces -Z. Glass bands per floor between spandrel bands, mullions, a lobby with a canopy, an optional
## setback for the upper floors, roof plant and an antenna on tall ones. Not enterable (one collision box per
## volume, layer 1 = the navmesh goes round it).
## Point 76: style "apartment" = a residential block (brick or plaster, punched windows with curtains, balconies on
## the front and back, an entrance with a canopy). `enterable` apartment blocks (>= 14 x 12 m) get a lobby, a
## stairwell (two flights per floor) and a lift (`ApartmentLift`) up to a stair-house on a walkable roof.

@export var width: float = 20.0:
	set(v): width = v; _queue_rebuild()
@export var depth: float = 20.0:
	set(v): depth = v; _queue_rebuild()
@export_range(3, 60) var floors: int = 12:
	set(v): floors = v; _queue_rebuild()
@export var floor_height: float = 3.4:
	set(v): floor_height = v; _queue_rebuild()
## glass = curtain wall, bands = concrete with window strips, brick = older office block, apartment = flats.
@export_enum("glass", "bands", "brick", "apartment") var style: String = "glass":
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
## Point 76: an apartment block you can walk into (lobby, stairs + lift to the roof). Needs style "apartment".
@export var enterable: bool = false:
	set(v): enterable = v; _queue_rebuild()
## Point 101: shops on the ground floor of these faces (bit 1 = -Z, 2 = +X, 4 = +Z, 8 = -X; see ShopFront).
@export_flags("Front -Z", "Right +X", "Back +Z", "Left -X") var shop_faces: int = 0:
	set(v): shop_faces = v; _queue_rebuild()
## Point 101: the middle shop on the -Z face is a real shop you can walk into (not for apartment blocks).
@export var open_shop: bool = false:
	set(v): open_shop = v; _queue_rebuild()

const MULLION: float = 1.6  # metres between vertical mullions
const APT_CELL: float = 3.2  # apartment window bay width
const ROOM_COLORS: Array[Color] = [
	Color(0.85, 0.8, 0.68), Color(0.75, 0.8, 0.82), Color(0.8, 0.84, 0.74),
	Color(0.88, 0.86, 0.82), Color(0.82, 0.72, 0.62), Color(0.7, 0.68, 0.72)]
const CORE_X: float = 4.0  # enterable: the lobby + core strip is x -4..4
const SHAFT: float = 6.0  # enterable: depth of the stair + lift core at the back

var _generated: Array[Node] = []
var _pending: bool = false
var _apt_wall: StringName = &"plaster"
var _ent: bool = false
var _room: Rect2 = Rect2()  # point 101: the walk-in shop cut out of the ground floor (local x, z)


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
	_apt_wall = &"plaster" if rng.randf() < 0.55 else &"brick_mixed"
	_ent = enterable and style == "apartment" and width >= 14.0 and depth >= 12.0 and floors >= 3
	var lower: int = floors if setback_from <= 0 or setback_from >= floors or _ent else setback_from
	_room = Rect2()
	if has_open_shop():
		_room = ShopFront.room_rect(width, depth)
	_volume(b, Vector2(width, depth), 0, lower, true, rng)
	var top_size := Vector2(width, depth)
	if lower < floors:
		top_size = Vector2(maxf(6.0, width - 2.0 * setback), maxf(6.0, depth - 2.0 * setback))
		_volume(b, top_size, lower, floors, false, rng)
	_roof(b, top_size, height(), rng)
	var shop_nodes: Array[Node] = []
	if shop_faces != 0 and not _ent:
		var srng := RandomNumberGenerator.new()
		srng.seed = variation_seed * 31 + 101
		shop_nodes = ShopFront.build(self, b, _faces(Vector2(width, depth)), shop_faces, srng, _room.has_area(),
				style == "apartment")
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	_generated.append(mi)
	if _ent:
		_build_inside(rng)
	# Collision: one box per volume (point 101: round the walk-in shop's room on the ground floor).
	elif _room.has_area():
		var fh: float = floor_height
		if lower > 1:
			_box_shape(Vector3(width, (lower - 1) * fh, depth), Vector3(0, fh + (lower - 1) * fh / 2.0, 0))
		var hw: float = width / 2.0
		var hd: float = depth / 2.0
		var r: Rect2 = _room
		for box: Rect2 in [Rect2(-hw, -hd, r.position.x + hw, depth), Rect2(r.end.x, -hd, hw - r.end.x, depth),
				Rect2(r.position.x, r.end.y, r.size.x, hd - r.end.y)]:
			if box.size.x > 0.05 and box.size.y > 0.05:
				_box_shape(Vector3(box.size.x, fh, box.size.y), Vector3(box.get_center().x, fh / 2.0, box.get_center().y))
	else:
		_box_shape(Vector3(width, lower * floor_height, depth), Vector3(0, lower * floor_height / 2.0, 0))
	if lower < floors:
		var h: float = (floors - lower) * floor_height
		_box_shape(Vector3(top_size.x, h, top_size.y), Vector3(0, lower * floor_height + h / 2.0, 0))
	for n: Node in shop_nodes:
		add_child(n)
		_generated.append(n)
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


## Point 101: a walk-in shop is built (needs a street face at -Z, a deep enough block, not an apartment block).
func has_open_shop() -> bool:
	return open_shop and shop_faces & 1 and style != "apartment" and not _ent and depth >= ShopFront.ROOM_DEPTH + 4.0 			and width >= ShopFront.UNIT


func _box_shape(size: Vector3, at: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = Transform3D(basis, at)
	add_child(cs)
	_generated.append(cs)


## Floors f0..f1 of a box volume `size` (x, z) centred on the origin.
func _volume(b: MeshBuilder, size: Vector2, f0: int, f1: int, lobby: bool, rng: RandomNumberGenerator) -> void:
	if style == "apartment":
		_apt_volume(b, size, f0, f1, lobby, rng)
		return
	var y0: float = f0 * floor_height
	var y1: float = f1 * floor_height
	var wall_key: StringName = &"concrete" if style != "brick" else &"brick_mixed"
	var core: Color = tint if style != "glass" else tint.darkened(0.35)
	# The solid core (a little inside the glass). Point 101: round the walk-in shop's room on the ground floor.
	b.color = core
	if lobby and f0 == 0 and _room.has_area():
		var hx: float = size.x / 2.0 - 0.15
		var hz: float = size.y / 2.0 - 0.15
		var fh: float = floor_height
		b.box_mm(wall_key, Vector3(-hx, fh, -hz), Vector3(hx, y1, hz))
		b.box_mm(wall_key, Vector3(-hx, 0, -hz), Vector3(_room.position.x - 0.05, fh, hz))
		b.box_mm(wall_key, Vector3(_room.end.x + 0.05, 0, -hz), Vector3(hx, fh, hz))
		b.box_mm(wall_key, Vector3(_room.position.x - 0.05, 0, _room.end.y + 0.05), Vector3(_room.end.x + 0.05, fh, hz))
	else:
		b.box(wall_key, Vector3(0, (y0 + y1) / 2.0, 0), Vector3(size.x - 0.3, y1 - y0, size.y - 0.3))
	var glass_h: float = floor_height * (0.78 if style == "glass" else 0.48)
	for f: int in range(f0, f1):
		var fy: float = f * floor_height
		if lobby and f == 0:
			if shop_faces != 0:
				continue  # point 101: ShopFront draws the ground floor
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
	if lobby and shop_faces == 0:
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
	b.color = tint.darkened(0.2) if style != "apartment" else tint.darkened(0.1)
	# Parapet.
	for side: int in 4:
		var horiz: bool = side % 2 == 0
		var run_len: float = size.x if horiz else size.y
		var off: float = (size.y if horiz else size.x) / 2.0 * (-1.0 if side < 2 else 1.0)
		var c := Vector3(0, top + 0.5, off) if horiz else Vector3(off, top + 0.5, 0)
		b.box(&"concrete", c, Vector3(run_len, 1.0, 0.3) if horiz else Vector3(0.3, 1.0, run_len))
	b.color = Color(0.5, 0.5, 0.52)
	b.box(&"concrete", Vector3(0, top + 0.05, 0), Vector3(size.x - 0.4, 0.1, size.y - 0.4))
	if _ent:
		return  # the stair-house + parapet collision come from _build_inside
	# Plant room + AC units.
	b.color = tint.darkened(0.1)
	b.box(&"concrete", Vector3(rng.randf_range(-1, 1), top + 1.6, rng.randf_range(-1, 1)), Vector3(size.x * 0.4, 3.2, size.y * 0.35))
	b.color = Color(0.7, 0.71, 0.72)
	for i: int in rng.randi_range(2, 5):
		b.box(&"item_metal", Vector3(rng.randf_range(-0.35, 0.35) * size.x, top + 0.7, rng.randf_range(-0.35, 0.35) * size.y), Vector3(1.6, 1.2, 1.2))
	if antenna:
		b.color = Color(0.75, 0.75, 0.78)
		b.cylinder(&"item_metal", Vector3(0, top + 3.2, 0), Vector3(0, top + 3.2 + floors * 0.35, 0), 0.25, 0.06, 6)


# --- apartments (point 76) ------------------------------------------------------------------------------------

## The four faces of a volume `size`: [start, end (along the face), outward normal].
func _faces(size: Vector2) -> Array:
	var hx: float = size.x / 2.0 - 0.15
	var hz: float = size.y / 2.0 - 0.15
	return [[Vector2(-hx, -hz), Vector2(hx, -hz), Vector3.FORWARD], [Vector2(hx, -hz), Vector2(hx, hz), Vector3.RIGHT],
			[Vector2(hx, hz), Vector2(-hx, hz), Vector3.BACK], [Vector2(-hx, hz), Vector2(-hx, -hz), Vector3.LEFT]]


## A point on a face: `t` m along it, height `y`, `out` m in front of it.
func _fp(face: Array, t: float, y: float, out: float) -> Vector3:
	var a: Vector2 = face[0]
	var d: Vector2 = ((face[1] as Vector2) - a).normalized()
	var p: Vector2 = a + d * t
	return Vector3(p.x, y, p.y) + (face[2] as Vector3) * out


## A box on a face: `along` wide, `h` high, `thick` deep, centred at (t, y, out).
func _fbox(b: MeshBuilder, key: StringName, face: Array, t: float, y: float, along: float, h: float, out: float,
		thick: float) -> void:
	var d: Vector2 = ((face[1] as Vector2) - (face[0] as Vector2)).normalized()
	var size := Vector3(along, h, thick) if absf(d.x) > 0.5 else Vector3(thick, h, along)
	b.box(key, _fp(face, t, y, out), size)


func _apt_room_color(rng: RandomNumberGenerator) -> Color:
	var c: Color = ROOM_COLORS[rng.randi() % ROOM_COLORS.size()]
	c.a = 1.0 if rng.randf() < 0.25 else rng.randf() * 0.2
	return c


func _apt_volume(b: MeshBuilder, size: Vector2, f0: int, f1: int, lobby: bool, rng: RandomNumberGenerator) -> void:
	var y0: float = f0 * floor_height
	var y1: float = f1 * floor_height
	if not _ent:  # (an enterable block draws its solid parts in _build_inside)
		b.color = tint
		b.box(_apt_wall, Vector3(0, (y0 + y1) / 2.0, 0), Vector3(size.x - 0.3, y1 - y0, size.y - 0.3))
	var faces: Array = _faces(size)
	for fi: int in 4:
		var face: Array = faces[fi]
		var length: float = (face[0] as Vector2).distance_to(face[1])
		var n: int = maxi(2, int(length / APT_CELL))
		var cw: float = length / n
		var phase: int = rng.randi() % 2
		for f: int in range(f0, f1):
			var fy: float = f * floor_height
			if f > 0:  # a string course per floor
				b.color = tint.darkened(0.15)
				_fbox(b, _apt_wall, face, length / 2.0, fy + 0.05, length + 0.1, 0.22, 0.03, 0.08)
			for i: int in n:
				var t: float = cw * (i + 0.5)
				if lobby and f == 0 and fi == 0:
					if _ent and absf(t - length / 2.0) < CORE_X + cw / 2.0:
						continue  # the glass lobby front (below)
					if not _ent and i == n / 2:
						_apt_entrance(b, face, t, cw)
						continue
				var balcony: bool = fi % 2 == 0 and f > 0 and (i + phase) % 2 == 0 and i > 0 and i < n - 1
				_apt_window(b, face, t, fy, balcony, rng)
				if balcony:
					_apt_balcony(b, face, t, cw, fy)
		if lobby and fi == 0 and _ent:
			_apt_lobby_front(b, face, length)


func _apt_window(b: MeshBuilder, face: Array, t: float, fy: float, balcony: bool, rng: RandomNumberGenerator) -> void:
	var ww: float = 1.3 if balcony else 1.5
	var sill: float = fy + (0.1 if balcony else 0.85)
	var top: float = fy + 2.4
	b.color = _apt_room_color(rng)
	b.quad(&"glass_interior", _fp(face, t - ww / 2.0, sill, 0.02), _fp(face, t + ww / 2.0, sill, 0.02),
			_fp(face, t + ww / 2.0, top, 0.02), _fp(face, t - ww / 2.0, top, 0.02), face[2],
			PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))
	b.color = Color(0.93, 0.92, 0.89)
	for s: float in [-1.0, 1.0]:
		_fbox(b, &"trim_paint", face, t + s * (ww / 2.0 + 0.04), (sill + top) / 2.0, 0.1, top - sill, 0.05, 0.1)
	_fbox(b, &"trim_paint", face, t, top + 0.06, ww + 0.2, 0.12, 0.05, 0.1)
	_fbox(b, &"trim_paint", face, t, (sill + top) / 2.0, 0.06, top - sill, 0.04, 0.06)
	if not balcony:
		_fbox(b, &"trim_paint", face, t, sill - 0.05, ww + 0.25, 0.1, 0.08, 0.16)


func _apt_balcony(b: MeshBuilder, face: Array, t: float, cw: float, fy: float) -> void:
	var bw: float = minf(cw - 0.5, 2.8)
	b.color = Color(0.8, 0.79, 0.76)
	_fbox(b, &"concrete", face, t, fy, bw, 0.18, 0.65, 1.3)
	b.color = Color(0.22, 0.24, 0.26)
	_fbox(b, &"item_metal", face, t, fy + 1.0, bw, 0.06, 1.27, 0.06)
	for s: float in [-1.0, 1.0]:
		_fbox(b, &"item_metal", face, t + s * (bw / 2.0 - 0.03), fy + 0.55, 0.05, 0.9, 0.65, 1.3)
	b.color = tint.darkened(0.35)
	_fbox(b, &"trim_paint", face, t, fy + 0.5, bw - 0.1, 0.7, 1.25, 0.04)


## The front door of a (closed) block: glass doors, a frame, a step and a canopy.
func _apt_entrance(b: MeshBuilder, face: Array, t: float, w: float) -> void:
	var dw: float = minf(w - 0.6, 2.4)
	b.color = Color.WHITE
	b.quad(&"glass_shop", _fp(face, t - dw / 2.0, 0.1, 0.02), _fp(face, t + dw / 2.0, 0.1, 0.02),
			_fp(face, t + dw / 2.0, 2.6, 0.02), _fp(face, t - dw / 2.0, 2.6, 0.02), face[2])
	b.color = Color(0.2, 0.21, 0.22)
	for s: float in [-1.0, 0.0, 1.0]:
		_fbox(b, &"item_metal", face, t + s * dw / 2.0, 1.35, 0.1, 2.6, 0.05, 0.1)
	_fbox(b, &"item_metal", face, t, 2.65, dw + 0.1, 0.12, 0.05, 0.1)
	_apt_canopy(b, face, t, dw)


func _apt_canopy(b: MeshBuilder, face: Array, t: float, dw: float) -> void:
	b.color = tint.darkened(0.3)
	_fbox(b, &"concrete", face, t, 3.0, dw + 1.4, 0.2, 0.9, 1.8)
	b.color = Color(0.7, 0.7, 0.68)
	_fbox(b, &"concrete", face, t, 0.06, dw + 0.8, 0.12, 0.5, 1.0)


## Enterable block: the lobby front = glass either side of an open doorway.
func _apt_lobby_front(b: MeshBuilder, face: Array, length: float) -> void:
	var mid: float = length / 2.0
	b.color = Color.WHITE
	for s: float in [-1.0, 1.0]:
		var ta: float = mid + s * 1.25
		var tb: float = mid + s * (CORE_X - 0.05)
		b.quad(&"glass_clear", _fp(face, minf(ta, tb), 0.1, 0.02), _fp(face, maxf(ta, tb), 0.1, 0.02),
				_fp(face, maxf(ta, tb), floor_height - 0.4, 0.02), _fp(face, minf(ta, tb), floor_height - 0.4, 0.02), face[2])
	b.color = Color(0.2, 0.21, 0.22)
	for x: float in [-CORE_X, -1.2, 1.2, CORE_X]:
		_fbox(b, &"item_metal", face, mid + x, floor_height / 2.0, 0.14, floor_height, 0.05, 0.14)
	_fbox(b, &"item_metal", face, mid, floor_height - 0.35, CORE_X * 2.0, 0.14, 0.05, 0.14)
	_fbox(b, &"item_metal", face, mid, 2.6, 2.4, 0.12, 0.05, 0.12)
	_apt_canopy(b, face, mid, 2.4)


## Enterable block: the solid flats round a hollow strip (lobby at the front, stair + lift core at the back), the
## stairwell (two flights per floor), the lift, the roof stair-house and the parapet collision.
func _build_inside(_rng: RandomNumberGenerator) -> void:
	var h: float = floor_height
	var top: float = height()
	var hx: float = width / 2.0 - 0.15
	var hz: float = depth / 2.0 - 0.15
	var zc1: float = hz - 0.3
	var zc0: float = zc1 - SHAFT
	var b := MeshBuilder.new()
	# The flats (solid) and the walls round the strip.
	_solid(b, Vector3(-hx, 0, -hz), Vector3(-CORE_X, top, hz))
	_solid(b, Vector3(CORE_X, 0, -hz), Vector3(hx, top, hz))
	_solid(b, Vector3(-CORE_X, h, -hz), Vector3(CORE_X, top, zc0))
	_solid(b, Vector3(-CORE_X, 0, zc1), Vector3(CORE_X, top, hz))
	_solid(b, Vector3(0, 0, zc0), Vector3(0.4, top, zc1))  # between the stairs and the lift
	# The lobby front: glass walls either side of the doorway (collision; the facade draws the glass).
	for s: float in [-1.0, 1.0]:
		_box_shape(Vector3(CORE_X - 1.2, h, 0.2), Vector3(s * (CORE_X + 1.2) / 2.0, h / 2.0, -hz + 0.1))
	# Linings: plaster inside the lobby + core, a tiled floor, mailboxes, a bench, a plant.
	var lin := Color(0.88, 0.86, 0.82)
	_lining(b, Vector3(-CORE_X, 0, -hz + 0.2), Vector3(-CORE_X + 0.03, top, zc1), lin)
	_lining(b, Vector3(CORE_X - 0.03, 0, -hz + 0.2), Vector3(CORE_X, top, zc1), lin)
	_lining(b, Vector3(-CORE_X, 0, zc1 - 0.03), Vector3(CORE_X, top, zc1), lin)
	_lining(b, Vector3(-CORE_X, h - 0.03, -hz + 0.2), Vector3(CORE_X, h, zc0), lin)
	_lining(b, Vector3(-CORE_X, h, zc0), Vector3(0, top, zc0 + 0.03), lin)
	b.color = Color(0.92, 0.9, 0.86)
	b.box_mm(&"floor_tiles", Vector3(-CORE_X, 0, -hz + 0.2), Vector3(CORE_X, 0.03, zc1))
	_box_shape(Vector3(CORE_X * 2.0, 0.03, zc1 + hz - 0.2), Vector3(0, 0.015, (zc1 - hz + 0.2) / 2.0))  # (no grass inside)
	b.color = Color(0.7, 0.58, 0.3)
	b.box_mm(&"item_metal", Vector3(-CORE_X + 0.03, 1.0, -hz + 1.2), Vector3(-CORE_X + 0.3, 1.9, -hz + 3.2))
	b.color = Color(0.35, 0.25, 0.18)
	b.box_mm(&"planks", Vector3(CORE_X - 0.6, 0.4, -hz + 1.0), Vector3(CORE_X - 0.03, 0.5, -hz + 2.8))
	b.color = Color(0.3, 0.5, 0.28)
	b.box(&"item_matte", Vector3(-CORE_X + 0.5, 0.6, zc0 - 0.6), Vector3(0.6, 1.2, 0.6))
	# The stairwell: x -4..0, lane A (x -4..-2) climbs to the back, lane B (x -2..0) back to the front.
	var f0z: float = zc0 + 1.2
	var f1z: float = zc1 - 1.2
	var run: float = f1z - f0z
	var rise: float = h / 2.0
	var length: float = Vector2(run, rise).length()
	var steps: int = int(round(rise / 0.17))
	var tread: float = run / steps
	var landing := Color(0.7, 0.69, 0.66)
	for k: int in floors:
		for half: int in 2:
			var y_lo: float = k * h + half * rise
			var sgn: float = 1.0 if half == 0 else -1.0
			var lx: float = -3.0 if half == 0 else -1.0
			var za: float = f0z if half == 0 else f1z
			var zb: float = f1z if half == 0 else f0z
			var dir := Vector3(0, rise, zb - za).normalized()
			var up := Vector3(0, run, -sgn * rise).normalized()
			var centre := Vector3(lx, y_lo + rise / 2.0, (za + zb) / 2.0) - up * 0.1
			_box_shape(Vector3(1.9, 0.2, length), centre, Basis(up.cross(dir), up, dir))
			for i: int in steps:
				var zc: float = za + sgn * tread * (i + 0.5)
				var ytop: float = y_lo + rise * float(i + 1) / steps
				b.color = Color(0.72, 0.71, 0.68) if i % 2 == 0 else Color(0.66, 0.65, 0.62)
				b.box(&"concrete", Vector3(lx, ytop - 0.2, zc), Vector3(1.9, 0.4, tread))
		# The back landing half way up, the front landing at the next floor.
		_solid(b, Vector3(-CORE_X, k * h + rise - 0.25, f1z), Vector3(0, k * h + rise, zc1), &"concrete", landing)
		_solid(b, Vector3(-CORE_X, (k + 1) * h - 0.25, zc0), Vector3(0, (k + 1) * h, f0z), &"concrete", landing)
		if k > 0:  # a flat's front door on every landing
			b.color = Color(0.3, 0.2, 0.14)
			b.box_mm(&"door_paint", Vector3(-3.5, k * h, zc0), Vector3(-2.5, k * h + 2.1, zc0 + 0.06))
	_solid(b, Vector3(-2.05, 0, f0z), Vector3(-1.95, top, f1z), &"concrete", lin)
	_solid(b, Vector3(-CORE_X, top, f0z - 0.05), Vector3(-2.05, top + 1.0, f0z + 0.05), &"item_metal", Color(0.25, 0.26, 0.27))
	# The roof stair-house over the core (door to the roof at the front).
	var sh: float = 3.0
	var z_front: float = zc0 - 2.6
	var wall := tint.darkened(0.08)
	_solid(b, Vector3(-CORE_X - 0.2, top, z_front), Vector3(-1.1, top + sh, z_front + 0.2), _apt_wall, wall)
	_solid(b, Vector3(1.1, top, z_front), Vector3(CORE_X + 0.2, top + sh, z_front + 0.2), _apt_wall, wall)
	_solid(b, Vector3(-1.1, top + 2.4, z_front), Vector3(1.1, top + sh, z_front + 0.2), _apt_wall, wall)
	_solid(b, Vector3(-CORE_X - 0.2, top, z_front), Vector3(-CORE_X, top + sh, hz), _apt_wall, wall)
	_solid(b, Vector3(CORE_X, top, z_front), Vector3(CORE_X + 0.2, top + sh, hz), _apt_wall, wall)
	_solid(b, Vector3(-CORE_X - 0.2, top, hz - 0.2), Vector3(CORE_X + 0.2, top + sh, hz), _apt_wall, wall)
	_solid(b, Vector3(-CORE_X - 0.4, top + sh, z_front - 0.2), Vector3(CORE_X + 0.4, top + sh + 0.25, hz + 0.1), &"concrete",
			tint.darkened(0.25))
	_lining(b, Vector3(-CORE_X, top + sh - 0.03, z_front + 0.2), Vector3(CORE_X, top + sh, hz - 0.2), lin)
	# Parapet collision (the visual parapet comes from _roof) + planters on the roof terrace.
	for s: float in [-1.0, 1.0]:
		_box_shape(Vector3(width, 1.0, 0.3), Vector3(0, top + 0.5, s * depth / 2.0))
		_box_shape(Vector3(0.3, 1.0, depth), Vector3(s * width / 2.0, top + 0.5, 0))
		b.color = Color(0.45, 0.36, 0.28)
		b.box(&"planks", Vector3(s * (hx - 1.2), top + 0.3, -hz + 1.0), Vector3(1.8, 0.6, 0.8))
		b.color = Color(0.3, 0.52, 0.26)
		b.box(&"item_matte", Vector3(s * (hx - 1.2), top + 0.75, -hz + 1.0), Vector3(1.6, 0.4, 0.6))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	_generated.append(mi)
	# The lift (lobby <-> roof) and its two call panels.
	var lift := ApartmentLift.new()
	lift.name = "Lift"
	lift.width = CORE_X - 0.4 - 0.1
	lift.depth = SHAFT - 0.1
	lift.rise = top
	lift.travel_time = clampf(top / 3.0, 4.0, 10.0)
	lift.position = Vector3((0.4 + CORE_X) / 2.0, 0, (zc0 + zc1) / 2.0)
	add_child(lift)
	_generated.append(lift)
	for i: int in 2:
		var btn := BunkerLiftButton.new()
		btn.name = "LiftButtonLobby" if i == 0 else "LiftButtonRoof"
		btn.lift = lift
		btn.upper = i == 0
		btn.here_text = "Ride up to the roof" if i == 0 else "Ride down to the lobby"
		btn.position = Vector3(CORE_X - 0.25, 0.0 if i == 0 else top, zc0 - 0.9)
		btn.rotation.y = PI / 2.0
		add_child(btn)
		_generated.append(btn)
	var m := Marker3D.new()
	m.name = "RoofSpot"
	m.position = Vector3(0, top, -hz + 3.0)
	add_child(m)
	_generated.append(m)
	if DisplayServer.get_name() != "headless" and not Engine.is_editor_hint():
		var spots: Array[Vector3] = [Vector3(0, h - 0.4, (-hz + zc0) / 2.0), Vector3(0, top + sh - 0.4, (z_front + zc0) / 2.0)]
		for k: int in range(1, floors, 2):
			spots.append(Vector3(-2.0, k * h + h - 0.4, zc0 + 0.6))
		for p: Vector3 in spots:
			var light := OmniLight3D.new()
			light.position = p
			light.omni_range = 7.0
			light.light_energy = 0.9
			light.light_color = Color(1.0, 0.92, 0.8)
			add_child(light)
			_generated.append(light)


## A solid box: drawn + collision.
func _solid(b: MeshBuilder, mn: Vector3, mx: Vector3, key: StringName = &"", c: Color = Color(0, 0, 0, 0)) -> void:
	b.color = tint if c.a == 0.0 else c
	b.box_mm(_apt_wall if key == &"" else key, mn, mx)
	_box_shape(mx - mn, (mn + mx) / 2.0)


func _lining(b: MeshBuilder, mn: Vector3, mx: Vector3, c: Color) -> void:
	b.color = c
	b.box_mm(&"interior_plaster", mn, mx)
