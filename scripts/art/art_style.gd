class_name ArtStyle
extends RefCounted
## Point 27 art direction: stylized low-poly (DESIGN.md "Art direction").
## - `stylized`: the procedural generators (trees, grass, shrubs, hedges, buildings) build
##   their stylized geometry. Off until the user approves the art test; the rollout turns
##   it on for good.
## - `restyle(root)`: swaps every material under `root` for its stylized version from
##   prefabs/materials/stylized/ (same file name); other StandardMaterial3Ds (imported
##   characters, per-car paint copies) get the same light model (lambert wrap, matte).

const STYLIZED_DIR: String = "res://prefabs/materials/stylized/"
const MAT_DIR: String = "res://prefabs/materials/"

static var stylized: bool = false
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


## The stylized version of `mat` (same object when there is none).
static func stylize_material(mat: Material) -> Material:
	if mat == null:
		return null
	if _cache.has(mat):
		return _cache[mat]
	var out: Material = mat
	var path: String = mat.resource_path
	if path.begins_with(MAT_DIR) and not path.begins_with(STYLIZED_DIR):
		var alt: String = STYLIZED_DIR + path.get_file()
		if ResourceLoader.exists(alt):
			out = load(alt)
	elif mat is BaseMaterial3D:
		out = soften(mat as BaseMaterial3D)
	_cache[mat] = out
	return out


## A copy with the shared light model: lambert wrap, matte, no clearcoat.
static func soften(mat: BaseMaterial3D) -> BaseMaterial3D:
	if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return mat
	var c := mat.duplicate() as BaseMaterial3D
	c.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	c.roughness = maxf(c.roughness, 0.6)
	c.metallic *= 0.3
	c.metallic_specular = 0.3
	c.clearcoat_enabled = false
	c.normal_enabled = false
	return c
