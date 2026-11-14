class_name PhoneMap
extends Control
## Phone map app: top-down town map (north = -Z up), centred on you. Roads come from the
## RoadTile asphalt, buildings from Building footprints; markers for players
## (you = arrow), customers (€) and the shops. Redrawn every frame while open.
## Point 35: crew-owned properties get a green house icon + their name; with `show_for_sale`
## (the estate agent's window) properties for sale get an orange pin, and `focus` centres
## the map on one property and highlights it.

const BOUNDS := Rect2(-199, -139, 280, 251)  # world x, z (point 47: + the west side, 57: one area)
## Point 47: the sea south of the harbour quay (world x, z).
const SEA := Rect2(-260, 104.5, 186, 80)
const LANDMARKS: Dictionary = {
	"Store": "Store", "Hospital": "Hospital",
	"GunShop": "Guns", "ContactHideout": "Dries", "Garage": "Garage", "PoliceStation": "Police",
	"Factory": "Metalworks", "HarborSign": "Harbour",
}

var _roads: Array[PackedVector2Array] = []
var _buildings: Array[PackedVector2Array] = []
var _labels: Array[Array] = []  # [world xz, text]
## Point 35: the estate window's map: for-sale pins, centred on `focus` (null = follow you).
var show_for_sale: bool = false
var focus: Property = null


func _ready() -> void:
	custom_minimum_size = Vector2(0, 380)
	clip_contents = true
	var world: Node = get_tree().current_scene
	if world == null:
		return
	for n: Node in world.find_children("*", "RoadTile", true, false):
		var t := n as RoadTile
		for poly: PackedVector2Array in t.asphalt_areas:
			var out := PackedVector2Array()
			for p: Vector2 in poly:
				var w: Vector3 = t.global_transform * Vector3(p.x, 0, p.y)
				out.append(Vector2(w.x, w.z))
			_roads.append(out)
	for n: Node in world.find_children("*", "Building", true, false):
		var b := n as Building
		var hw: float = b.width * 0.5
		var out := PackedVector2Array()
		for c: Vector2 in [Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw, -b.depth), Vector2(-hw, -b.depth)]:
			var w: Vector3 = b.global_transform * Vector3(c.x, 0, c.y)
			out.append(Vector2(w.x, w.z))
		_buildings.append(out)
	for key: String in LANDMARKS:
		var node := world.find_child(key, true, false) as Node3D
		if node:
			var p: Vector3 = node.global_position
			_labels.append([Vector2(p.x, p.z), LANDMARKS[key]])


func _process(_delta: float) -> void:
	queue_redraw()


const PIXELS_PER_M: float = 2.6

var _centre := Vector2.ZERO  # world xz in the middle of the map


func _to_map(p: Vector2) -> Vector2:
	return size * 0.5 + (p - _centre) * PIXELS_PER_M


## Point 35: a property's spot on the map (the middle of its building, xz).
static func property_spot(p: Property) -> Vector2:
	var b: Building = p.building()
	var w: Vector3 = b.global_transform * Vector3(0, 0, -b.depth * 0.5) if b else p.global_position
	return Vector2(w.x, w.z)


## Follows the local player (or the focused property), without scrolling past the edge of the town.
func _update_centre() -> void:
	if focus != null and is_instance_valid(focus):
		_centre = property_spot(focus)
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if focus != null and is_instance_valid(focus):
			break
		var pl := n as Player
		if pl and pl.is_local():
			_centre = Vector2(pl.global_position.x, pl.global_position.z)
	var half: Vector2 = size * 0.5 / PIXELS_PER_M
	for axis: int in 2:
		var lo: float = BOUNDS.position[axis] + half[axis]
		var hi: float = BOUNDS.end[axis] - half[axis]
		_centre[axis] = clampf(_centre[axis], lo, hi) if lo <= hi else (BOUNDS.position[axis] + BOUNDS.end[axis]) * 0.5


func _poly(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(_to_map(p))
	return out


func _draw() -> void:
	_update_centre()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.22, 0.15))
	var sea_a: Vector2 = _to_map(SEA.position)
	draw_rect(Rect2(sea_a, _to_map(SEA.end) - sea_a), Color(0.16, 0.3, 0.4))
	for r: PackedVector2Array in _roads:
		if r.size() >= 3:
			draw_colored_polygon(_poly(r), Color(0.33, 0.33, 0.36))
	for b: PackedVector2Array in _buildings:
		var poly: PackedVector2Array = _poly(b)
		draw_colored_polygon(poly, Color(0.55, 0.5, 0.45))
		poly.append(poly[0])
		draw_polyline(poly, Color(0.3, 0.27, 0.25), 1.0)
	var font: Font = get_theme_default_font()
	for l: Array in _labels:
		var p: Vector2 = _to_map(l[0])
		draw_string_outline(font, p + Vector2(-20, 4), l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.8))
		draw_string(font, p + Vector2(-20, 4), l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.9, 0.6))
	# Point 35: own properties (green house) and, in the estate window, the ones for sale (orange pin).
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
	for n: Node in get_tree().get_nodes_in_group(&"properties"):
		var prop := n as Property
		var owned: bool = prop.is_crew_owned()
		if not owned and not (show_for_sale and prop.for_sale):
			continue
		var p: Vector2 = _to_map(property_spot(prop))
		var col: Color = Color(0.35, 0.9, 0.45) if owned else Color(1.0, 0.62, 0.2)
		var big: bool = prop == focus
		var r: float = 7.0 + (3.0 * pulse if big else 0.0)
		if big:
			draw_circle(p, r + 6.0, Color(1, 0.3, 0.25, 0.35 + 0.3 * pulse))
		# House: a square with a roof.
		draw_colored_polygon(PackedVector2Array([p + Vector2(-r, -r * 0.1), p + Vector2(0, -r * 1.1), p + Vector2(r, -r * 0.1)]), col)
		draw_rect(Rect2(p + Vector2(-r * 0.7, -r * 0.1), Vector2(r * 1.4, r * 0.9)), col)
		var text: String = prop.display_name + ("" if owned else "  €" + Property.money(prop.price))
		draw_string_outline(font, p + Vector2(r + 3, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12 if big else 11, 3, Color(0, 0, 0, 0.85))
		draw_string(font, p + Vector2(r + 3, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12 if big else 11, col.lightened(0.3))
	for c: Node in get_tree().get_nodes_in_group(&"customer"):
		var p3: Vector3 = (c as Node3D).global_position
		var p: Vector2 = _to_map(Vector2(p3.x, p3.z))
		draw_circle(p, 7.0, Color(0.2, 0.7, 0.25))
		draw_string(font, p + Vector2(-4, 4), "€", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var pl := n as Player
		if pl == null or pl.dead:
			continue
		var p: Vector2 = _to_map(Vector2(pl.global_position.x, pl.global_position.z))
		if pl.is_local():
			# Arrow in the facing direction (-Z of the body).
			var fwd3: Vector3 = -pl.global_basis.z
			var f: Vector2 = Vector2(fwd3.x, fwd3.z).normalized()
			var side: Vector2 = Vector2(-f.y, f.x)
			draw_colored_polygon(PackedVector2Array([p + f * 9.0, p - f * 6.0 + side * 6.0, p - f * 3.0, p - f * 6.0 - side * 6.0]),
					Color(0.35, 0.75, 1.0))
		else:
			draw_circle(p, 5.0, Color(1, 1, 1))
			draw_string(font, p + Vector2(7, 4), pl.player_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
