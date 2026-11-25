class_name ShopFront
extends RefCounted
## Point 101: the city's ground floors become shops. A Tower with `shop_faces` (bit 1 = -Z, 2 = +X, 4 = +Z, 8 = -X:
## the faces on a street) asks this builder for a row of shop units along each of those faces, drawn INTO the
## tower's own mesh (no extra draw calls): a backing wall, pilasters, a shop window with the stylized window glass
## (lit at night), a door, a coloured fascia, an awning for some kinds, and the extras of the kind (barber pole,
## pharmacy cross, florist buckets, café terrace with TerraceSeat markers for session B's CityLife, menu board). The
## name is a Label3D on the fascia (drawn up to SIGN_RANGE m).
## `open_shop`: one unit on the -Z face is a real shop you walk into (Tower cuts the room out of its ground floor):
## lining, a counter, the furniture of its kind and a ShopkeeperSpot marker (meta shop_kind / shop_name) where
## session B's shopkeeper stands.

const UNIT: float = 7.5  # target width of one shop
## Our shop kinds -> session B's ShopTypes (the seller's stock); "-" = no seller (a trade of its own).
const SELLER_TYPE: Dictionary = {"cafe": "cafe", "restaurant": "restaurant", "bakery": "bakery", "florist": "florist",
		"boutique": "clothing", "chips": "snack_bar", "supermarket": "kiosk", "phone": "kiosk", "pharmacy": "kiosk",
		"barber": "-"}
const FLOOR: float = 0.15  # the paved block (= pavement height) the shops and terraces stand on
const ROOM_DEPTH: float = 8.0
const SIGN_RANGE: float = 75.0
const KINDS: Array[String] = ["cafe", "restaurant", "bakery", "florist", "boutique", "barber", "pharmacy",
		"supermarket", "phone", "chips"]
## kind -> [names, fascia colour, awning colours (empty = none), terrace]
const INFO: Dictionary = {
	"cafe": [["Cafe Luna", "Bean There", "Corner Cafe", "Espresso Bar", "Cafe Nova"], Color(0.18, 0.32, 0.26),
			[Color(0.16, 0.42, 0.32), Color(0.92, 0.9, 0.82)], true],
	"restaurant": [["Trattoria Rosa", "The Golden Fork", "Bistro 9", "Dragon Garden", "Casa Verde"],
			Color(0.45, 0.1, 0.1), [Color(0.6, 0.12, 0.12), Color(0.95, 0.92, 0.85)], true],
	"bakery": [["Bakery", "Daily Bread", "Le Croissant", "Golden Crust"], Color(0.55, 0.35, 0.18),
			[Color(0.85, 0.6, 0.3), Color(0.98, 0.94, 0.86)], false],
	"florist": [["Flowers", "Bloom & Co", "Petal Shop"], Color(0.35, 0.5, 0.3),
			[Color(0.9, 0.55, 0.65), Color(0.98, 0.95, 0.95)], false],
	"boutique": [["Boutique", "Mode", "Atelier Noir", "Denim House", "Velvet"], Color(0.12, 0.12, 0.14), [], false],
	"barber": [["Barber", "Sharp Cuts", "Fade Bros"], Color(0.15, 0.2, 0.45), [], false],
	"pharmacy": [["Pharmacy", "City Pharmacy"], Color(0.2, 0.55, 0.35), [], false],
	"supermarket": [["FreshMart", "Super Saver", "Quick Shop"], Color(0.85, 0.35, 0.1), [], false],
	"phone": [["Phone Shop", "Mobile World", "Cell City"], Color(0.1, 0.35, 0.75), [], false],
	"chips": [["Chip Shop", "Frites", "Fish & Chips"], Color(0.95, 0.75, 0.1),
			[Color(0.95, 0.78, 0.15), Color(0.9, 0.2, 0.12)], false],
}
const FURN: String = "res://prefabs/interiors/"


## The walk-in shop's room in the tower's local x/z (front at -Z): the middle unit of the -Z face, ROOM_DEPTH deep.
static func room_rect(width: float, depth: float) -> Rect2:
	var hx: float = width / 2.0 - 0.15
	var u: Array = open_unit(hx * 2.0)
	var x0: float = -hx + float(u[0]) + 0.2
	var x1: float = -hx + float(u[1]) - 0.2
	return Rect2(x0, -depth / 2.0, x1 - x0, ROOM_DEPTH + 0.15)


## Splits a face `length` m long into shop units: [[t0, t1], ...].
static func units(length: float) -> Array:
	var n: int = maxi(1, roundi(length / UNIT))
	var u: float = length / n
	var out: Array = []
	for i: int in n:
		out.append([i * u, (i + 1) * u])
	return out


## The unit that becomes the walk-in shop on the -Z face (the middle one).
static func open_unit(length: float) -> Array:
	var us: Array = units(length)
	return us[us.size() / 2]


## Draws the shops of `t` (a Tower) into `b`; returns the nodes to add (labels, markers, furniture, lights).
## `skip_middle_front`: keep the middle of the -Z face free (an apartment block's own entrance).
static func build(t: Tower, b: MeshBuilder, faces: Array, mask: int, rng: RandomNumberGenerator, open: bool,
		skip_middle_front: bool) -> Array[Node]:
	var nodes: Array[Node] = []
	var fh: float = t.floor_height
	for fi: int in 4:
		if not (mask & (1 << fi)):
			continue
		var face: Array = faces[fi]
		var length: float = (face[0] as Vector2).distance_to(face[1])
		var us: Array = units(length)
		for ui: int in us.size():
			var t0: float = us[ui][0]
			var t1: float = us[ui][1]
			var mid_unit: bool = ui == us.size() / 2
			if fi == 0 and skip_middle_front and mid_unit:
				continue
			var kind: String = KINDS[rng.randi() % KINDS.size()]
			var info: Array = INFO[kind]
			var names: Array = info[0]
			var shop_name: String = names[rng.randi() % names.size()]
			var is_open: bool = open and fi == 0 and mid_unit
			_unit(t, b, face, t0, t1, fh, kind, info, is_open)
			nodes.append(_sign(t, face, (t0 + t1) / 2.0, fh, shop_name, info[1]))
			nodes.append_array(_extras(t, b, face, t0, t1, kind, info, rng))
			if is_open:
				nodes.append_array(_room(t, b, face, t0, t1, fh, kind, shop_name))
	return nodes


static func _unit(t: Tower, b: MeshBuilder, face: Array, t0: float, t1: float, fh: float, kind: String,
		info: Array, is_open: bool) -> void:
	var w: float = t1 - t0
	var mid: float = (t0 + t1) / 2.0
	# Backing wall (covers whatever the tower's own ground floor drew) + pilasters at both ends.
	if not is_open:
		b.color = Color(0.22, 0.2, 0.19)
		t._fbox(b, &"interior_plaster", face, mid, fh / 2.0, w, fh, 0.1, 0.12)  # (front face at 0.16: behind the glass at 0.2)
	b.color = t.tint.darkened(0.2)
	for e: float in [t0, t1]:
		t._fbox(b, &"concrete", face, e, fh / 2.0, 0.4, fh, 0.2, 0.3)
	# Fascia (the sign board) + cornice.
	b.color = info[1]
	t._fbox(b, &"trim_paint", face, mid, fh - 0.55, w - 0.4, 0.75, 0.28, 0.16)
	b.color = t.tint.darkened(0.35)
	t._fbox(b, &"concrete", face, mid, fh - 0.08, w + 0.2, 0.16, 0.3, 0.4)
	# Window + door: the door on the right third.
	var door_t: float = t1 - 1.2
	var win_a: float = t0 + 0.35
	var win_b: float = door_t - 0.65
	if not is_open:
		b.color = Color.WHITE
		b.quad(&"glass_shop", t._fp(face, win_a, 0.5, 0.2), t._fp(face, win_b, 0.5, 0.2),
				t._fp(face, win_b, fh - 1.0, 0.2), t._fp(face, win_a, fh - 1.0, 0.2), face[2])
		b.color = Color(0.25, 0.2, 0.16)  # the door: dark wood with a glass panel
		t._fbox(b, &"door_paint", face, door_t, 1.15, 1.0, 2.3, 0.17, 0.06)
		b.color = Color.WHITE
		b.quad(&"glass_shop", t._fp(face, door_t - 0.35, 1.0, 0.205), t._fp(face, door_t + 0.35, 1.0, 0.205),
				t._fp(face, door_t + 0.35, 2.1, 0.205), t._fp(face, door_t - 0.35, 2.1, 0.205), face[2])
	b.color = Color(0.18, 0.18, 0.2)  # window frame + stall riser
	t._fbox(b, &"item_metal", face, (win_a + win_b) / 2.0, 0.25, win_b - win_a + 0.1, 0.5, 0.2, 0.2)
	t._fbox(b, &"item_metal", face, (win_a + win_b) / 2.0, fh - 0.98, win_b - win_a + 0.1, 0.08, 0.22, 0.08)
	for e: float in [win_a, win_b, door_t - 0.55, door_t + 0.55]:
		t._fbox(b, &"item_metal", face, e, (fh - 0.95) / 2.0, 0.08, fh - 0.95, 0.22, 0.08)
	# Window display: a few product shapes behind the glass (only on closed units: the open one is furnished).
	if not is_open:
		var c: Color = (info[1] as Color).lightened(0.35)
		for k: int in 3:
			var at: float = win_a + (win_b - win_a) * (k + 0.5) / 3.0
			b.color = c.darkened(0.1 * k)
			t._fbox(b, &"item_matte", face, at, 0.75, 0.5, 0.5, 0.14, 0.08)
	# Awning: a sloped striped canvas over window + door.
	var cols: Array = info[2]
	if not cols.is_empty():
		var stripes: int = maxi(4, int((w - 0.6) / 0.5))
		var y_top: float = fh - 1.05
		var y_low: float = fh - 1.65
		var out: float = 1.4
		for k: int in stripes:
			var a: float = t0 + 0.3 + (w - 0.6) * k / stripes
			var z: float = t0 + 0.3 + (w - 0.6) * (k + 1) / stripes
			b.color = cols[k % 2]
			b.quad(&"awning", t._fp(face, a, y_top, 0.3), t._fp(face, z, y_top, 0.3), t._fp(face, z, y_low, out),
					t._fp(face, a, y_low, out), Vector3.UP + (face[2] as Vector3))
			b.quad(&"awning", t._fp(face, a, y_low, out), t._fp(face, z, y_low, out), t._fp(face, z, y_low - 0.25, out),
					t._fp(face, a, y_low - 0.25, out), face[2])


static func _sign(t: Tower, face: Array, at: float, fh: float, text: String, bg: Color) -> Label3D:
	var lbl := Label3D.new()
	lbl.text = text.to_upper()
	lbl.font_size = 56
	lbl.pixel_size = 0.006
	lbl.outline_size = 6
	lbl.modulate = Color(1, 0.97, 0.88) if bg.get_luminance() < 0.55 else Color(0.1, 0.1, 0.1)
	lbl.outline_modulate = bg.darkened(0.4)
	lbl.position = t._fp(face, at, fh - 0.55, 0.37)
	lbl.rotation.y = atan2((face[2] as Vector3).x, (face[2] as Vector3).z)
	lbl.double_sided = false
	lbl.visibility_range_end = SIGN_RANGE
	lbl.visibility_range_end_margin = 5.0
	lbl.name = "ShopSign"
	return lbl


static func _extras(t: Tower, b: MeshBuilder, face: Array, t0: float, t1: float, kind: String, info: Array,
		rng: RandomNumberGenerator) -> Array[Node]:
	var nodes: Array[Node] = []
	var fh: float = t.floor_height
	var along: Vector3 = (t._fp(face, 1.0, 0, 0) - t._fp(face, 0.0, 0, 0)).normalized().abs()
	var nrm: Vector3 = (face[2] as Vector3).abs()
	match kind:
		"barber":  # the striped pole beside the door
			var p: Vector3 = t._fp(face, t1 - 0.45, 1.6, 0.45)
			for k: int in 6:
				b.color = [Color(0.85, 0.1, 0.1), Color(0.95, 0.95, 0.95), Color(0.15, 0.25, 0.7)][k % 3]
				b.cylinder(&"item_glossy", p + Vector3(0, -0.45 + k * 0.15, 0), p + Vector3(0, -0.3 + k * 0.15, 0), 0.09, 0.09, 8)
		"pharmacy":  # the green cross, sticking out from the wall
			var p2: Vector3 = t._fp(face, t0 + 0.6, fh - 0.4, 0.55)
			b.color = Color(0.1, 0.85, 0.35)
			b.box(&"car_headlight", p2, along * 0.2 + Vector3.UP * 0.6 + nrm * 0.12)
			b.box(&"car_headlight", p2, along * 0.6 + Vector3.UP * 0.2 + nrm * 0.12)
		"florist":  # buckets of flowers on the pavement
			for k: int in 4:
				var p3: Vector3 = t._fp(face, t0 + 0.8 + k * 0.6, FLOOR, 0.8 + (k % 2) * 0.25)
				b.color = Color(0.3, 0.32, 0.35)
				b.cylinder(&"item_metal", p3, p3 + Vector3(0, 0.35, 0), 0.16, 0.2, 8)
				b.color = [Color(0.9, 0.2, 0.3), Color(0.95, 0.8, 0.2), Color(0.7, 0.3, 0.8), Color(0.95, 0.5, 0.2)][k]
				b.sphere(&"leaves", p3 + Vector3(0, 0.5, 0), 0.22, 4, 6)
		"restaurant", "chips":  # a menu board on the pavement
			var p4: Vector3 = t._fp(face, t0 + 0.7, FLOOR, 0.9)
			b.color = Color(0.15, 0.15, 0.15)
			b.box(&"item_matte", p4 + Vector3(0, 0.55, 0), along * 0.55 + Vector3.UP * 1.1 + nrm * 0.08)
	if bool(info[3]) and t1 - t0 > 5.0:  # café / restaurant terrace: two tables with two chairs each
		for k: int in 2:
			var at: float = t0 + 1.4 + k * 2.2
			if at > t1 - 2.0:
				break
			var c: Vector3 = t._fp(face, at, FLOOR, 1.15)
			b.color = Color(0.2, 0.2, 0.22)
			b.cylinder(&"item_metal", c, c + Vector3(0, 0.72, 0), 0.04, 0.04, 6)
			b.color = Color(0.92, 0.9, 0.85)
			b.cylinder(&"item_matte", c + Vector3(0, 0.72, 0), c + Vector3(0, 0.75, 0), 0.38, 0.38, 10)
			for s: float in [-1.0, 1.0]:
				var cp: Vector3 = t._fp(face, at + s * 0.62, FLOOR, 1.15)
				b.color = (info[2] as Array)[0] if not (info[2] as Array).is_empty() else Color(0.3, 0.3, 0.3)
				b.box(&"item_matte", cp + Vector3(0, 0.45, 0), Vector3(0.42, 0.06, 0.42))
				b.box(&"item_matte", cp + Vector3(0, 0.22, 0), Vector3(0.06, 0.45, 0.06))
				var back: Vector3 = (cp - c).normalized() * 0.2
				b.box(&"item_matte", cp + back + Vector3(0, 0.7, 0), along * 0.05 + nrm * 0.42 + Vector3.UP * 0.45)
				var seat := Marker3D.new()
				seat.name = "TerraceSeat"
				seat.position = cp + Vector3(0, 0.05, 0)
				seat.rotation.y = atan2(c.x - cp.x, c.z - cp.z) + PI  # (-Z looks at the table)
				nodes.append(seat)
	return nodes


## The walk-in shop: lining, ceiling light, glass front with a door gap (collision), furniture of the kind and the
## counter spot for session B's shopkeeper.
static func _room(t: Tower, b: MeshBuilder, face: Array, t0: float, t1: float, fh: float, kind: String,
		shop_name: String) -> Array[Node]:
	var nodes: Array[Node] = []
	var hx: float = t.width / 2.0 - 0.15
	var hz: float = t.depth / 2.0 - 0.15
	var x0: float = -hx + t0 + 0.2
	var x1: float = -hx + t1 - 0.2
	var z0: float = -hz
	var z1: float = -hz + ROOM_DEPTH
	var wall := Color(0.92, 0.9, 0.84) if kind != "boutique" else Color(0.85, 0.82, 0.86)
	# Floor, ceiling, walls (visual; the tower adds the solid boxes round the room).
	b.color = Color(0.75, 0.73, 0.7)
	b.box_mm(&"floor_tiles", Vector3(x0, FLOOR - 0.04, z0), Vector3(x1, FLOOR + 0.01, z1))
	b.color = Color(0.9, 0.9, 0.88)
	b.box_mm(&"interior_plaster", Vector3(x0, fh - 0.02, z0), Vector3(x1, fh, z1))
	b.color = wall
	b.box_mm(&"interior_plaster", Vector3(x0, 0, z1), Vector3(x1, fh, z1 + 0.05))
	b.box_mm(&"interior_plaster", Vector3(x0 - 0.05, 0, z0), Vector3(x0, fh, z1))
	b.box_mm(&"interior_plaster", Vector3(x1, 0, z0), Vector3(x1 + 0.05, fh, z1))
	# Glass front with the door gap on the right (door_t - 0.55 .. door_t + 0.55 along the face).
	var door_t: float = t1 - 1.2
	var dx0: float = -hx + door_t - 0.55
	var dx1: float = -hx + door_t + 0.55
	b.color = Color.WHITE
	for seg: Vector2 in [Vector2(x0, dx0), Vector2(dx1, x1)]:
		if seg.y - seg.x < 0.1:
			continue
		b.quad(&"glass_clear", Vector3(seg.x, 0.5, z0 - 0.2), Vector3(seg.y, 0.5, z0 - 0.2),
				Vector3(seg.y, fh - 1.0, z0 - 0.2), Vector3(seg.x, fh - 1.0, z0 - 0.2), Vector3.FORWARD)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(seg.y - seg.x, fh - 0.5, 0.25)
		cs.shape = shape
		cs.position = Vector3((seg.x + seg.y) / 2.0, (fh - 0.5) / 2.0, z0 - 0.1)
		nodes.append(cs)
	b.color = Color(0.4, 0.4, 0.4)  # above the door
	b.box_mm(&"item_metal", Vector3(dx0, 2.4, z0 - 0.25), Vector3(dx1, fh - 0.9, z0 - 0.05))
	# Light: an emissive ceiling panel + one small light without shadows.
	b.color = Color(1, 0.97, 0.9)
	b.box(&"lamp_glow", Vector3((x0 + x1) / 2.0, fh - 0.04, (z0 + z1) / 2.0), Vector3(1.6, 0.03, 0.6))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3((x0 + x1) / 2.0, fh - 0.5, (z0 + z1) / 2.0)
	lamp.omni_range = 7.0
	lamp.light_energy = 0.9
	lamp.light_color = Color(1.0, 0.95, 0.85)
	lamp.shadow_enabled = false
	nodes.append(lamp)
	# The counter across the back third, the shopkeeper spot behind it.
	var cz: float = z1 - 2.2
	var cx: float = (x0 + x1) / 2.0
	b.color = Color(0.4, 0.28, 0.18) if kind in ["cafe", "bakery", "restaurant", "chips"] else Color(0.85, 0.85, 0.85)
	b.box(&"planks", Vector3(cx + 0.6, FLOOR + 0.5, cz), Vector3(x1 - x0 - 2.4, 1.0, 0.6))
	var counter_shape := CollisionShape3D.new()
	var csh := BoxShape3D.new()
	csh.size = Vector3(x1 - x0 - 2.4, 1.0, 0.6)
	counter_shape.shape = csh
	counter_shape.position = Vector3(cx + 0.6, FLOOR + 0.5, cz)
	nodes.append(counter_shape)
	nodes.append(_furn("cash_register.tscn", Vector3(cx + 1.5, FLOOR + 1.0, cz), 0.0))
	var spot := Marker3D.new()
	spot.name = "ShopkeeperSpot"  # (session B's ShopStaff puts a seller here)
	spot.position = Vector3(cx + 0.6, FLOOR + 0.05, cz + 1.0)
	spot.rotation.y = 0.0  # (looks -Z: at the door)
	spot.set_meta(&"shop_kind", kind)
	spot.set_meta(&"shop_name", shop_name)
	spot.set_meta(&"shop_type", SELLER_TYPE.get(kind, "-"))
	nodes.append(spot)
	# Shelves on the back wall + the kind's own furniture in the front part.
	for k: int in 2:
		nodes.append(_furn("wall_shelf.tscn", Vector3(x0 + 1.2 + k * (x1 - x0 - 2.4), 1.4, z1 - 0.1), PI))
	var front_z: float = z0 + 2.2
	match kind:
		"cafe", "restaurant":
			for k: int in 2:
				var tx: float = x0 + 1.3 + k * 2.4
				nodes.append(_furn("dining_table.tscn", Vector3(tx, 0.04, front_z), 0.0))
				nodes.append(_furn("dining_chair.tscn", Vector3(tx, 0.04, front_z - 0.8), 0.0))
				nodes.append(_furn("dining_chair.tscn", Vector3(tx, 0.04, front_z + 0.8), PI))
				for side: float in [-1.0, 1.0]:  # session B's diners: -Z of the marker looks at the table
					var seat := Marker3D.new()
					seat.name = "DinerSeat"
					seat.position = Vector3(tx, FLOOR + 0.05, front_z + side * 0.8)
					seat.rotation.y = PI if side < 0.0 else 0.0
					nodes.append(seat)
		"barber":
			for k: int in 2:
				nodes.append(_furn("barber_chair.tscn", Vector3(x0 + 1.2 + k * 1.8, 0.04, front_z + 1.2), PI))
		"supermarket", "pharmacy", "phone", "bakery":
			for k: int in 2:
				nodes.append(_furn("metal_rack.tscn" if kind == "supermarket" else "low_cabinet.tscn",
						Vector3(x0 + 1.3 + k * 2.2, 0.04, front_z + 0.6), PI / 2.0))
		"florist":
			for k: int in 4:
				nodes.append(_furn("potted_plant.tscn", Vector3(x0 + 0.8 + k * 1.2, 0.04, front_z), 0.0))
		"boutique", "chips":
			nodes.append(_furn("wardrobe.tscn" if kind == "boutique" else "steel_shelves.tscn",
					Vector3(x0 + 0.6, 0.04, front_z + 1.0), PI / 2.0))
	return nodes


static func _furn(file: String, pos: Vector3, yaw: float) -> Node3D:
	var n: Node3D = (load(FURN + file) as PackedScene).instantiate()
	n.position = pos + Vector3(0, FLOOR - 0.04 if pos.y < 0.1 else 0.0, 0)  # (floor-standing pieces on the shop floor)
	n.rotation.y = yaw
	return n
