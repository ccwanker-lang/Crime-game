class_name WorldLod
extends Node
## Point 90 (part 1): draw distances + light budget for the whole map, on every peer with a window
## (node World/WorldLod). Walks the world once after loading and again for nodes added later:
##  - small props (< SMALL m) vanish beyond PROP_RANGE (and cast no shadow below TINY m)
##  - medium pieces (< MEDIUM m) beyond MEDIUM_RANGE; parts of buildings/towers beyond BUILDING_PART_RANGE
##  - trees / shrubs beyond TREE_RANGE, street lamps beyond LAMP_RANGE
##  - big things (buildings, terrain, roads) stay: the silhouettes you see from afar
##  - point/spot lights fade out between LIGHT_FADE_BEGIN and + LIGHT_FADE_LENGTH (they cost nothing beyond)
## Nodes that already have a visibility range (NPCs, grass, critters) are left alone.

const SMALL: float = 1.6
const TINY: float = 0.5
const MEDIUM: float = 5.0
const PROP_RANGE: float = 80.0
const MEDIUM_RANGE: float = 160.0
const BUILDING_PART_RANGE: float = 220.0
const TREE_RANGE: float = 250.0
const LAMP_RANGE: float = 100.0
const LIGHT_FADE_BEGIN: float = 70.0
const LIGHT_FADE_LENGTH: float = 25.0
## Classes whose small parts are part of a facade (window frames, trim): kept further.
const FACADE_CLASSES: Array[String] = ["Building", "Tower", "ParkingGarage", "JetHangar", "Shack", "Watchtower"]
const TREE_CLASSES: Array[String] = ["ProcTree", "ProcShrub", "Hedge"]
## Never touched (big generated ground / far backdrop / the moving or first-person things).
const SKIP_CLASSES: Array[String] = ["BorderRange", "Mountain", "ProcBackdrop", "GrassCover", "GrassField",
		"Player", "Viewmodel", "Pedestrian", "Car", "PlayerCar", "ProcJet", "Airfield"]

static var enabled: bool = true
var done: int = 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless" or not enabled:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	apply(get_parent())
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is GeometryInstance3D or n is Light3D:
		_later.call_deferred(n)


func _later(n: Node) -> void:
	if is_instance_valid(n) and n.is_inside_tree():
		_one(n, _context(n))


## Walks `root` once (iterative, no recursion limit).
func apply(root: Node) -> void:
	var stack: Array = [[root, ""]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var n: Node = it[0]
		var ctx: String = it[1]
		var k: String = _class_of(n)
		if k in SKIP_CLASSES:
			continue
		if k in FACADE_CLASSES or k in TREE_CLASSES:
			ctx = k
			if k == "Building" or k == "Tower":
				_add_occluder(n as Node3D)
		elif n.scene_file_path.contains("street_lamp"):
			ctx = "lamp"
		_one(n, ctx)
		for c: Node in n.get_children():
			stack.append([c, ctx])


func _context(n: Node) -> String:
	var p: Node = n
	var ctx: String = ""
	while p:
		var k: String = _class_of(p)
		if k in SKIP_CLASSES:
			return "skip"
		if ctx == "" and (k in FACADE_CLASSES or k in TREE_CLASSES):
			ctx = k
		elif ctx == "" and p.scene_file_path.contains("street_lamp"):
			ctx = "lamp"
		p = p.get_parent()
	return ctx


func _one(n: Node, ctx: String) -> void:
	if ctx == "skip":
		return
	var light := n as Light3D
	if light and not light is DirectionalLight3D:
		if not light.distance_fade_enabled:
			light.distance_fade_enabled = true
			light.distance_fade_begin = LIGHT_FADE_BEGIN
			light.distance_fade_length = LIGHT_FADE_LENGTH
			light.distance_fade_shadow = 30.0
		return
	var g := n as GeometryInstance3D
	if g == null or g.visibility_range_end > 0.0 or g is MultiMeshInstance3D and ctx == "":
		return
	var vi := g as VisualInstance3D
	var box: AABB = vi.get_aabb()
	var s: Vector3 = box.size * g.global_basis.get_scale().abs()
	var size: float = maxf(s.x, maxf(s.y, s.z))
	var end: float = 0.0
	if ctx in TREE_CLASSES:
		end = TREE_RANGE
	elif ctx == "lamp":
		end = LAMP_RANGE
	elif ctx in FACADE_CLASSES:
		end = BUILDING_PART_RANGE if size < MEDIUM else 0.0
	elif size < SMALL:
		end = PROP_RANGE
	elif size < MEDIUM:
		end = MEDIUM_RANGE
	if end > 0.0:
		g.visibility_range_end = end
		g.visibility_range_end_margin = 6.0
		done += 1
	if size < TINY and ctx != "lamp":
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Occlusion culling: a box a bit inside the shell of every closed (non-enterable) building or tower, so what
## stands behind it is not drawn. Enterable ones get none (you would stand inside the box).
func _add_occluder(b: Node3D) -> void:
	if b == null or bool(b.get(&"enterable")) or b.get_node_or_null("Occluder"):
		return
	var box := AABB()
	var first: bool = true
	var inv: Transform3D = b.global_transform.affine_inverse()
	for m: Node in b.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var a: AABB = (inv * mi.global_transform) * mi.get_aabb()
		box = a if first else box.merge(a)
		first = false
	if first or box.size.x < 4.0 or box.size.z < 4.0 or box.size.y < 3.0:
		return
	var inset: Vector3 = Vector3(minf(1.2, box.size.x * 0.12), 0.0, minf(1.2, box.size.z * 0.12))
	var occ := BoxOccluder3D.new()
	occ.size = Vector3(box.size.x - 2.0 * inset.x, box.size.y * 0.8, box.size.z - 2.0 * inset.z)
	var oi := OccluderInstance3D.new()
	oi.name = "Occluder"
	oi.occluder = occ
	oi.position = Vector3(box.get_center().x, box.position.y + box.size.y * 0.4, box.get_center().z)
	b.add_child(oi)
	occluders += 1


var occluders: int = 0


func _class_of(n: Node) -> String:
	var sc: Script = n.get_script() as Script
	if sc:
		var g: StringName = sc.get_global_name()
		if g != &"":
			return str(g)
	return n.get_class()
