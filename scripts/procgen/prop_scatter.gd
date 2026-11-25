@tool
class_name PropScatter
extends Node3D
## Point 103 (street detail): many copies of one prop prefab (bins, bike racks, planters, bollards, manholes...)
## drawn as MultiMeshes - one draw call per mesh of the prop, however many copies - plus one StaticBody3D with the
## prop's collision shapes per copy. The prefab is built once (its own procedural _ready), its meshes and shapes are
## harvested and cached per prefab path, then it is freed.
## `spots` = x, y, z, yaw (degrees) per copy, local to this node. Drawn up to `range_end` m, no shadows by default.

@export_file("*.tscn") var prefab_path: String = "":
	set(v): prefab_path = v; _queue_rebuild()
@export var spots: PackedFloat32Array = PackedFloat32Array():
	set(v): spots = v; _queue_rebuild()
@export var range_end: float = 90.0:
	set(v): range_end = v; _queue_rebuild()
@export var shadows: bool = false:
	set(v): shadows = v; _queue_rebuild()
@export var collide: bool = true:
	set(v): collide = v; _queue_rebuild()

## prefab path -> [parts [[Mesh, Transform3D, Material, {tint: Color}]], shapes [[Shape3D, Transform3D]]]
const TINTS: Array[StringName] = [&"wall_tint", &"roof_tint", &"trim_tint", &"door_tint", &"foliage_tint"]
static var _cache: Dictionary = {}

var _generated: Array[Node] = []
var _pending: bool = false


func _ready() -> void:
	add_to_group(&"prop_scatter")
	_queue_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


func count() -> int:
	return spots.size() / 4


func _rebuild() -> void:
	_pending = false
	for n: Node in _generated:
		n.queue_free()
	_generated.clear()
	if prefab_path == "" or count() == 0:
		return
	var data: Array = await _harvest()
	if data.is_empty() or not is_inside_tree():
		return
	var xforms: Array[Transform3D] = []
	for i: int in count():
		var p := Vector3(spots[i * 4], spots[i * 4 + 1], spots[i * 4 + 2])
		xforms.append(Transform3D(Basis(Vector3.UP, deg_to_rad(spots[i * 4 + 3])), p))
	for part: Array in data[0]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part[0]
		mm.instance_count = xforms.size()
		for i: int in xforms.size():
			mm.set_instance_transform(i, xforms[i] * (part[1] as Transform3D))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if part[2]:
			mmi.material_override = part[2]
		for k: StringName in (part[3] as Dictionary):
			mmi.set_instance_shader_parameter(k, part[3][k])
		mmi.visibility_range_end = range_end
		mmi.visibility_range_end_margin = 5.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if not shadows:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_generated.append(mmi)
	if collide and not (data[1] as Array).is_empty():
		var body := StaticBody3D.new()
		body.name = "Collision"
		for t: Transform3D in xforms:
			for sh: Array in data[1]:
				var cs := CollisionShape3D.new()
				cs.shape = sh[0]
				cs.transform = t * (sh[1] as Transform3D)
				body.add_child(cs)
		add_child(body)
		_generated.append(body)


func _harvest() -> Array:
	if _cache.has(prefab_path):
		return _cache[prefab_path]
	var scene: PackedScene = load(prefab_path) as PackedScene
	if scene == null:
		push_warning("PropScatter: no prefab at %s" % prefab_path)
		return []
	var inst: Node3D = scene.instantiate() as Node3D
	inst.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(inst)
	# Procedural props build their meshes in _ready or one deferred call later.
	for i: int in 2:
		await get_tree().process_frame
	if not is_instance_valid(inst):
		return []
	ArtStyle.restyle(inst)  # (imported models get their stylized materials, as in the world)
	var root_inv: Transform3D = inst.global_transform.affine_inverse()
	var parts: Array = []
	for n: Node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		# Bake the surface (override) materials into a copy of the mesh: a MultiMesh only has one override.
		var mesh: Mesh = mi.mesh
		if mi.material_override == null and mesh is ArrayMesh:
			var copy: ArrayMesh = (mesh as ArrayMesh).duplicate() as ArrayMesh
			for i: int in copy.get_surface_count():
				copy.surface_set_material(i, mi.get_active_material(i))
			mesh = copy
		var tints: Dictionary = {}
		for k: StringName in TINTS:
			var v: Variant = mi.get_instance_shader_parameter(k)
			if v != null:
				tints[k] = v
		parts.append([mesh, root_inv * mi.global_transform, mi.material_override, tints])
	var shapes: Array = []
	for n: Node in inst.find_children("*", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		if cs.shape and not cs.disabled:
			shapes.append([cs.shape, root_inv * cs.global_transform])
	inst.queue_free()
	var data: Array = [parts, shapes]
	_cache[prefab_path] = data
	return data
