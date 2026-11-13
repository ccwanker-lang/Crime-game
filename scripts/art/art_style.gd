class_name ArtStyle
extends RefCounted
## Point 27 art direction: stylized low-poly (DESIGN.md "Art direction").
## - `stylized`: the procedural generators (trees, grass, hedges, building trim) build their
##   stylized geometry (on since the rollout; the old geometry is kept behind it for now).
## - Every material in prefabs/materials/ is already stylized (gen_materials.py).
## - `restyle(root)` dresses imported models: colour textures are swapped for their painted
##   version (assets/painted/, gen_painted_textures.py), normal/roughness maps dropped, and
##   every StandardMaterial3D gets the shared light model (lambert wrap, matte).
##   ModelPart, WeaponModel and the characters call it.

const PAINTED_FROM: String = "res://assets/polyhaven/"
const PAINTED_TO: String = "res://assets/painted/"

static var stylized: bool = true
static var _cache: Dictionary = {}


## Palette colours (sRGB) as a typed array, for MeshBuilder.blob etc.
static func colors(names: Array) -> Array[Color]:
	var out: Array[Color] = []
	for n: Variant in names:
		out.append(Palette.color(StringName(n)))
	return out


static func restyle(root: Node) -> int:
	var changed: int = 0
	var nodes: Array = root.find_children("*", "GeometryInstance3D", true, false)
	if root is GeometryInstance3D:
		nodes.append(root)
	for n: Node in nodes:
		var g := n as GeometryInstance3D
		if g.material_override:
			var o: Material = stylize_material(g.material_override)
			if o != g.material_override:
				g.material_override = o
				changed += 1
		var m := g as MeshInstance3D
		if m == null or m.mesh == null:
			continue
		for s: int in m.mesh.get_surface_count():
			var src: Material = m.get_surface_override_material(s)
			if src == null:
				src = m.mesh.surface_get_material(s)
			var dst: Material = stylize_material(src)
			if dst != src:
				m.set_surface_override_material(s, dst)
				changed += 1
	return changed


## The stylized version of `mat` (the same object when nothing changes).
static func stylize_material(mat: Material) -> Material:
	if mat == null:
		return null
	if _cache.has(mat):
		return _cache[mat]
	var out: Material = mat
	if mat is BaseMaterial3D and not mat.resource_path.begins_with("res://prefabs/materials/"):
		out = paint_material(mat as BaseMaterial3D)
	_cache[mat] = out
	return out


## A copy with the painted colour texture (if there is one) and the shared light model.
static func paint_material(mat: BaseMaterial3D) -> BaseMaterial3D:
	if mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return mat
	var c := mat.duplicate() as BaseMaterial3D
	var tex: Texture2D = mat.albedo_texture
	if tex and tex.resource_path.begins_with(PAINTED_FROM):
		var p: String = PAINTED_TO + tex.resource_path.trim_prefix(PAINTED_FROM).get_basename() + "_painted.png"
		if ResourceLoader.exists(p):
			c.albedo_texture = load(p)
	c.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	c.roughness = maxf(c.roughness, 0.6)
	c.metallic *= 0.3
	c.metallic_specular = 0.3
	c.clearcoat_enabled = false
	c.normal_enabled = false
	c.normal_texture = null
	c.roughness_texture = null
	c.metallic_texture = null
	c.ao_enabled = false
	if c is ORMMaterial3D:
		(c as ORMMaterial3D).orm_texture = null
	return c
