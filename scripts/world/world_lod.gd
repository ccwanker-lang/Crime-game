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
## Part 2: a shadow budget (only the MAX_SHADOWS nearest shadowed lights cast shadows, the rest light without) and
## far-process LOD (FAR_PROCESS_CLASSES stop their per-frame code beyond FAR_PROCESS_RANGE from the camera).

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

## Part 2.
const MAX_SHADOWS: int = 16
const SHADOW_RANGE: float = 90.0
const FAR_PROCESS_RANGE: float = 220.0
const FAR_PROCESS_CLASSES: Array[String] = ["Watchtower", "TrafficLight", "FireBarrel"]
const BUDGET_EVERY: float = 0.5

static var enabled: bool = true
var done: int = 0
var shadow_lights: Array[Light3D] = []  # lights that had shadows on (the budget hands them out)
var far_nodes: Array[Node] = []
var shadows_on: int = 0
var batched: Array[int] = [0, 0]
var far_off: int = 0
var _budget_t: float = 0.0


func _ready() -> void:
	if DisplayServer.get_name() == "headless" or not enabled:
		return
	for i: int in 2:
		await get_tree().process_frame
		if not is_inside_tree():  # (the world was left during loading: B NOTES part 29)
			return
	apply(get_parent())
	# StaticBatcher measured no gain (A/B/A at the docks + city: same FPS, a few MORE draws - a MultiMesh per 64 m
	# square is never culled per prop), so it stays off; `--batch` switches it on for experiments.
	if "--batch" in OS.get_cmdline_user_args():
		batched = StaticBatcher.batch(get_parent())
	print("[WorldLod] %d draw-distance limits, %d occluders, %d batches (%d props drawn as MultiMesh)" % [done, occluders, batched[0], batched[1]])
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is GeometryInstance3D or n is Light3D:
		_later.call_deferred(n)
	elif _class_of(n) in FAR_PROCESS_CLASSES:
		far_nodes.append(n)


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
		if k in FAR_PROCESS_CLASSES:
			far_nodes.append(n)
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
		if light.shadow_enabled and not light in shadow_lights:
			shadow_lights.append(light)
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


func _process(delta: float) -> void:
	_budget_t -= delta
	if _budget_t > 0.0:
		return
	_budget_t = BUDGET_EVERY
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	update_budget(cam.global_position)


## Shadows to the MAX_SHADOWS nearest lights within SHADOW_RANGE; per-frame code off for far FAR_PROCESS_CLASSES.
func update_budget(at: Vector3) -> void:
	var near: Array = []
	var i: int = shadow_lights.size() - 1
	while i >= 0:
		var l: Light3D = shadow_lights[i]
		if not is_instance_valid(l):
			shadow_lights.remove_at(i)
		else:
			near.append([l.global_position.distance_squared_to(at), l])
		i -= 1
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	shadows_on = 0
	for k: int in near.size():
		var on: bool = k < MAX_SHADOWS and near[k][0] < SHADOW_RANGE * SHADOW_RANGE
		(near[k][1] as Light3D).shadow_enabled = on
		if on:
			shadows_on += 1
	far_off = 0
	i = far_nodes.size() - 1
	while i >= 0:
		var n3 := far_nodes[i] as Node3D
		if not is_instance_valid(n3):
			far_nodes.remove_at(i)
		else:
			var on: bool = n3.global_position.distance_to(at) < FAR_PROCESS_RANGE
			if n3.is_processing() != on:
				n3.set_process(on)
			if not on:
				far_off += 1
		i -= 1


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
