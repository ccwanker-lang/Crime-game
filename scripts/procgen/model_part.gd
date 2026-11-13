@tool
class_name ModelPart
extends Node3D
## Shows selected mesh parts of an imported model (glTF), e.g. one shrub out of
## a file with four variants. Empty `parts` = all meshes.
## With `recenter`, the selected parts are moved so the centre of their
## bounding box (XZ) sits on this node's origin.

@export var model: PackedScene:
	set(v): model = v; _queue_rebuild()
@export var parts: PackedStringArray = PackedStringArray():
	set(v): parts = v; _queue_rebuild()
@export var recenter: bool = true:
	set(v): recenter = v; _queue_rebuild()
## 0 = always visible; otherwise hide beyond this distance (small props).
@export var visibility_end: float = 0.0:
	set(v): visibility_end = v; _queue_rebuild()
@export var cast_shadows: bool = true:
	set(v): cast_shadows = v; _queue_rebuild()

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
	if model == null:
		return
	var inst: Node = model.instantiate()
	var found: Array[MeshInstance3D] = []
	_collect(inst, found)
	var selected: Array[MeshInstance3D] = []
	var xforms: Array[Transform3D] = []
	var bounds := AABB()
	for mi: MeshInstance3D in found:
		if not parts.is_empty() and not parts.has(mi.name):
			continue
		var t: Transform3D = _relative_transform(mi, inst)
		var bb: AABB = t * mi.mesh.get_aabb()
		bounds = bb if selected.is_empty() else bounds.merge(bb)
		selected.append(mi)
		xforms.append(t)
	var c: Vector3 = bounds.get_center()
	var offset := Vector3(c.x, 0, c.z) if recenter else Vector3.ZERO
	for i: int in selected.size():
		var mi: MeshInstance3D = selected[i]
		var copy := MeshInstance3D.new()
		copy.mesh = mi.mesh
		copy.transform = Transform3D(xforms[i].basis, xforms[i].origin - offset)
		for s: int in mi.get_surface_override_material_count():
			var m: Material = mi.get_surface_override_material(s)
			if m:
				copy.set_surface_override_material(s, m)
		if visibility_end > 0.0:
			copy.visibility_range_end = visibility_end
			copy.visibility_range_end_margin = 5.0
			copy.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if not cast_shadows:
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if ArtStyle.stylized:
			ArtStyle.restyle(copy)  # point 27: painted textures, flat light
		add_child(copy)
		_generated.append(copy)
	inst.free()


static func _collect(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c: Node in n.get_children():
		_collect(c, out)


static func _relative_transform(n: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
