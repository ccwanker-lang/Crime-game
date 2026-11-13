class_name Stylizer
extends RefCounted
## Point 27 (art style comparison): re-dresses any existing node tree in one art style by
## swapping its materials, so the proposals compare the very same houses, cars, people
## and weapons.
## - "A" flat: one colour per surface (the original texture's average), soft wrapped light,
##   no highlights (stylized low-poly, Synty / Schedule I direction).
## - "B" pbr: the PBR materials stay (only the geometry is simpler, see the style scene).
## - "C" toon: flat colours + faint texture detail, banded light, dark outlines on people,
##   cars and weapons.
## Transparent, emissive and special shader materials (glass, lamps, window interiors,
## foliage, grass, sky) are left as they are.

const FLAT := preload("res://prefabs/materials/shaders/stylized_flat.gdshader")
const TOON := preload("res://prefabs/materials/shaders/stylized_toon.gdshader")
const OUTLINE := preload("res://prefabs/materials/shaders/outline.gdshader")

static var _avg_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}


## Restyles every mesh under `root`. `outline` > 0 adds an outline of that width (metres).
static func apply(root: Node, style: String, outline: float = 0.0) -> int:
	if style == "B" and outline <= 0.0:
		return 0
	var changed: int = 0
	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for n: Node in meshes:
		var m := n as MeshInstance3D
		if m.mesh == null:
			continue
		var override: Material = m.material_override
		m.material_override = null
		for s: int in m.mesh.get_surface_count():
			var src: Material = override if override else m.get_active_material(s)
			var dst: Material = src if style == "B" else restyle_material(src, style)
			if dst == null:
				if override:
					m.set_surface_override_material(s, override)
				continue
			if outline > 0.0 and dst != null:
				dst = _with_outline(dst, outline)
			m.set_surface_override_material(s, dst)
			changed += 1
	return changed


## The stylized copy of `mat` (cached), or null when it must stay as it is.
static func restyle_material(mat: Material, style: String) -> Material:
	if mat == null:
		return null
	if _mat_cache.has([mat, style]):
		return _mat_cache[[mat, style]]
	var out: ShaderMaterial = null
	if mat is BaseMaterial3D:
		var b := mat as BaseMaterial3D
		if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or b.emission_enabled \
				or b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			return null
		var atlas: bool = b.albedo_texture != null and b.uv1_scale.x <= 1.01
		var c: Color = b.albedo_color * (Color.WHITE if atlas else _average(b.albedo_texture))
		out = _make(style, c, b.vertex_color_use_as_albedo, 0, b.albedo_texture, Vector2(b.uv1_scale.x, b.uv1_scale.y),
				b.metallic, atlas)
	elif mat is ShaderMaterial:
		var sm := mat as ShaderMaterial
		var path: String = sm.shader.resource_path if sm.shader else ""
		if path.ends_with("surface.gdshader"):
			var tex: Texture2D = sm.get_shader_parameter("albedo_tex")
			var tint: Variant = sm.get_shader_parameter("base_tint")
			var c: Color = _average(tex) * (tint as Color if tint != null else Color.WHITE)
			var uv: Variant = sm.get_shader_parameter("uv_scale")
			out = _make(style, c, false, int(sm.get_shader_parameter("tint_channel") if sm.get_shader_parameter("tint_channel") != null else 0),
					tex, uv as Vector2 if uv != null else Vector2.ONE, 0.0)
		elif path.ends_with("painted.gdshader"):
			var bc: Variant = sm.get_shader_parameter("base_color")
			var ch: Variant = sm.get_shader_parameter("tint_channel")
			out = _make(style, bc as Color if bc != null else Color(0.9, 0.9, 0.88), false, int(ch) if ch != null else 0,
					null, Vector2.ONE, 0.0)
		elif path.ends_with("ground.gdshader"):
			var tex2: Texture2D = sm.get_shader_parameter("albedo_tex")
			if tex2 == null:
				return null
			out = _make(style, _average(tex2), false, 0, tex2, Vector2.ONE, 0.0)
		else:
			return null  # windows, foliage, grass, sky, flashes...
	if out:
		_mat_cache[[mat, style]] = out
	return out


static func _make(style: String, color: Color, vertex_color: bool, channel: int, tex: Texture2D, uv: Vector2,
		metal: float, atlas: bool = false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON if style == "C" else FLAT
	# Stylized palettes are a little brighter and more saturated than photo textures.
	var c := Color.from_hsv(color.h, clampf(color.s * 1.35, 0.0, 1.0), clampf(color.v * 1.02 + 0.02, 0.0, 1.0))
	if atlas:
		c = Color.WHITE
	if metal > 0.5:
		c = c.lerp(Color(0.55, 0.56, 0.58), 0.35)  # metal reads as a light grey, not black
	m.set_shader_parameter("base_color", c)
	m.set_shader_parameter("use_vertex_color", vertex_color)
	m.set_shader_parameter("tint_channel", channel)
	m.set_shader_parameter("roughness_v", 0.75 if style == "C" else 1.0)
	m.set_shader_parameter("metallic_v", 0.0)
	if atlas:
		m.set_shader_parameter("detail_tex", tex)
		m.set_shader_parameter("atlas", true)
	elif style == "C" and tex != null:
		m.set_shader_parameter("detail_tex", tex)
		m.set_shader_parameter("detail", 0.3)
		m.set_shader_parameter("detail_lum", _luminance(_average(tex)))
		m.set_shader_parameter("uv_scale", uv)
	return m


static func _with_outline(mat: Material, width: float) -> Material:
	var key: Array = [mat, "outline", width]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var copy: Material = mat.duplicate()
	var o := ShaderMaterial.new()
	o.shader = OUTLINE
	o.set_shader_parameter("width_px", width)
	copy.next_pass = o
	_mat_cache[key] = copy
	return copy


## Average colour of a texture (white for none), from a tiny downscaled copy.
static func _average(tex: Texture2D) -> Color:
	if tex == null:
		return Color.WHITE
	if _avg_cache.has(tex):
		return _avg_cache[tex]
	var img: Image = tex.get_image()
	if img == null:
		return Color.WHITE
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(4, 4, Image.INTERPOLATE_BILINEAR)
	var sum := Color(0, 0, 0, 0)
	for y: int in 4:
		for x: int in 4:
			sum += img.get_pixel(x, y)
	var avg: Color = sum / 16.0
	avg.a = 1.0
	_avg_cache[tex] = avg
	return avg


static func _luminance(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114
