class_name StaticBatcher
extends RefCounted
## Point 90 part 2: repeated static props drawn as MultiMeshes. Every MeshInstance3D inside an instance of one of
## BATCH_PREFABS (624 chain-link fence posts, containers, benches, ...) is grouped by (mesh, material override,
## shadow mode, draw distance, CHUNK square); a group of MIN_GROUP or more becomes one MultiMeshInstance3D and the
## originals are hidden (their collision stays - only the drawing moves). Local and visual only, on every peer
## with a window (WorldLod calls `batch` once after loading). Per-surface override materials (the art style's
## painted materials) are part of the group key and baked into one mesh copy per group. Street lamps are not in
## the list: their glass gets a glow material at night, per lamp.

const CHUNK: float = 64.0
const MIN_GROUP: int = 3
const BATCH_PREFABS: Array[String] = ["chainlink_fence", "chainlink_gate_frame", "road_straight", "road_curve",
		"road_t_junction", "road_crossing", "bench", "barrel", "bollard", "crate_long", "crate_flat", "covered_car", "sign_post", "trash_can",
		"trash_can_rusty", "trashbag", "planter_box", "utility_box", "post_box", "bike_rack", "road_barrier",
		"picket_fence", "garden_fence", "aircon", "manhole"]
## A mesh tinted per instance (shader instance uniforms: containers, sign posts, tree leaves) keeps its own draw -
## a MultiMesh would lose the colour.
const TINT_PARAMS: Array[StringName] = [&"wall_tint", &"trim_tint", &"door_tint", &"foliage_tint", &"tint"]
## Never batch inside these (things that move, get picked up or belong to players).
const SKIP_UNDER: Array[String] = ["PlacedSpawner", "LootSpawner", "Players", "Vehicles", "NPCs", "Traffic"]


## Batches everything under `root`; returns [groups made, meshes hidden].
static func batch(root: Node, holder_parent: Node = null) -> Array[int]:
	var groups: Dictionary = {}  # key -> Array[MeshInstance3D]
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if str(n.name) in SKIP_UNDER:
			continue
		var path: String = n.scene_file_path
		if path != "" and _batchable(path):
			for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
				_add(groups, mi as MeshInstance3D)
			continue
		for c: Node in n.get_children():
			stack.append(c)
	var holder := Node3D.new()
	holder.name = "StaticBatches"
	(holder_parent if holder_parent else root).add_child(holder)
	var made: int = 0
	var hidden: int = 0
	for key: String in groups:
		var list: Array = groups[key]
		if list.size() < MIN_GROUP:
			continue
		var first: MeshInstance3D = list[0]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _baked_mesh(first)
		mm.instance_count = list.size()
		for i: int in list.size():
			mm.set_instance_transform(i, (list[i] as MeshInstance3D).global_transform)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Batch%d" % made
		mmi.multimesh = mm
		mmi.material_override = first.material_override
		mmi.cast_shadow = first.cast_shadow
		mmi.visibility_range_end = first.visibility_range_end
		mmi.visibility_range_end_margin = first.visibility_range_end_margin
		mmi.visibility_range_fade_mode = first.visibility_range_fade_mode
		holder.add_child(mmi)
		for m: MeshInstance3D in list:
			m.visible = false
			m.set_meta(&"batched", true)
		made += 1
		hidden += list.size()
	return [made, hidden]


## The mesh to draw: the mesh itself, or a copy with the instance's per-surface override materials set on it.
static func _baked_mesh(mi: MeshInstance3D) -> Mesh:
	var any: bool = false
	for s: int in mi.get_surface_override_material_count():
		any = any or mi.get_surface_override_material(s) != null
	if not any:
		return mi.mesh
	var copy: Mesh = mi.mesh.duplicate()
	for s: int in mi.get_surface_override_material_count():
		var m: Material = mi.get_surface_override_material(s)
		if m:
			copy.surface_set_material(s, m)
	return copy


static func _batchable(path: String) -> bool:
	var file: String = path.get_file().get_basename()
	return file in BATCH_PREFABS


static func _add(groups: Dictionary, mi: MeshInstance3D) -> void:
	if mi == null or mi.mesh == null or not mi.visible or mi.has_meta(&"batched"):
		return
	for prm: StringName in TINT_PARAMS:
		var v: Variant = mi.get_instance_shader_parameter(prm)
		if v is Color and not (v as Color).is_equal_approx(Color.WHITE):  # (unset uniforms read back as white)
			return
	var overrides: String = ""
	for s: int in mi.get_surface_override_material_count():
		var m: Material = mi.get_surface_override_material(s)
		overrides += "%d," % (m.get_rid().get_id() if m else 0)
	var p: Vector3 = mi.global_position
	var key: String = "%d|%s|%d|%d|%d|%d|%d" % [mi.mesh.get_rid().get_id(), overrides,
			mi.material_override.get_rid().get_id() if mi.material_override else 0, mi.cast_shadow,
			roundi(mi.visibility_range_end), floori(p.x / CHUNK), floori(p.z / CHUNK)]
	var list: Array = groups.get(key, [])
	list.append(mi)
	groups[key] = list
