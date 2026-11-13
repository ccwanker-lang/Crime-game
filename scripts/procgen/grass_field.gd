@tool
class_name GrassField
extends MultiMeshInstance3D
## Scatters 3D grass clumps over a rectangle (centred on the node) using one
## MultiMesh. Fades out with distance (visibility range) for performance.
## Keep fields modest in size (e.g. up to 25 x 25 m) so culling works well.

@export var size: Vector2 = Vector2(10, 10):
	set(v): size = v; _queue_rebuild()
## Grass clumps per square metre.
@export_range(1.0, 40.0) var density: float = 14.0:
	set(v): density = v; _queue_rebuild()
@export var blade_height: Vector2 = Vector2(0.22, 0.42):
	set(v): blade_height = v; _queue_rebuild()
@export var field_seed: int = 1:
	set(v): field_seed = v; _queue_rebuild()
## Areas without grass (local X/Z rectangles), e.g. under a building or path.
@export var holes: Array[Rect2] = []:
	set(v): holes = v; _queue_rebuild()

static var _clump_mesh: ArrayMesh
var _pending: bool = false


func _ready() -> void:
	visibility_range_end = 45.0
	visibility_range_end_margin = 10.0
	visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_pending = false
	var rng := RandomNumberGenerator.new()
	rng.seed = field_seed
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _get_tuft_mesh() if ArtStyle.stylized else _get_clump_mesh()
	var count: int = int(size.x * size.y * density * (0.3 if ArtStyle.stylized else 1.0))
	var xforms: Array[Transform3D] = []
	for i: int in count:
		var pos := Vector3(rng.randf_range(-size.x / 2.0, size.x / 2.0), -0.03, rng.randf_range(-size.y / 2.0, size.y / 2.0))
		var h: float = rng.randf_range(blade_height.x, blade_height.y)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(h * 2.5, h, h * 2.5))
		if ArtStyle.stylized:
			h *= 0.42  # low, broad tufts
			basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(h * 2.6, h, h * 2.6))
		if _in_hole(Vector2(pos.x, pos.z)):
			continue
		xforms.append(Transform3D(basis, pos))
	mm.instance_count = xforms.size()
	for i: int in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	multimesh = mm
	material_override = load("res://prefabs/materials/grass_blades.tres")


func _in_hole(p: Vector2) -> bool:
	for r: Rect2 in holes:
		if r.has_point(p):
			return true
	return false


## One clump = 4 curved, tapering blades, 1 m tall (scaled per instance).
static func _get_clump_mesh() -> ArrayMesh:
	if _clump_mesh:
		return _clump_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for blade: int in 4:
		var angle: float = blade * TAU / 4.0 + rng.randf_range(-0.4, 0.4)
		var dir := Vector3(cos(angle), 0, sin(angle))
		var side := Vector3(-dir.z, 0, dir.x)
		var offset: Vector3 = dir * rng.randf_range(0.0, 0.06)
		var lean: float = rng.randf_range(0.1, 0.3)
		var w: float = 0.016
		var segs: int = 3
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for s: int in segs + 1:
			var t: float = float(s) / segs
			var center: Vector3 = offset + Vector3(0, t, 0) + dir * lean * t * t
			var half: float = w * (1.0 - t * 0.9)
			var l: Vector3 = center - side * half
			var r: Vector3 = center + side * half
			if s > 0:
				var t0: float = float(s - 1) / segs
				for v: Array in [[prev_l, t0], [r, t], [prev_r, t0], [prev_l, t0], [l, t], [r, t]]:
					st.set_normal(Vector3.UP)
					st.set_uv(Vector2(0.5, v[1]))
					st.add_vertex(v[0])
			prev_l = l
			prev_r = r
	_clump_mesh = st.commit()
	return _clump_mesh


static var _tuft_mesh: ArrayMesh


## Point 27 art direction: a low, broad tuft (5 wide pointed leaves, flat palette greens
## from dark at the root to light at the tip), 1 m tall before scaling.
static func _get_tuft_mesh() -> ArrayMesh:
	if _tuft_mesh:
		return _tuft_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var root: Color = Palette.color(&"grass_dark")
	var tip: Color = Palette.color(&"grass_light")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for blade: int in 5:
		var angle: float = blade * TAU / 5.0 + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(angle), 0, sin(angle))
		var side := Vector3(-dir.z, 0, dir.x)
		var w: float = 0.17
		var lean: float = rng.randf_range(0.45, 0.65)
		var a: Vector3 = -side * w
		var b: Vector3 = side * w
		var m: Vector3 = dir * lean * 0.5 + Vector3(0, 0.6, 0)
		var ml: Vector3 = m - side * w * 0.85
		var mr: Vector3 = m + side * w * 0.85
		var t: Vector3 = dir * lean + Vector3(0, 1.0, 0)
		var n: Vector3 = (Vector3.UP + dir * 0.3).normalized()
		for v: Array in [[a, 0.0], [ml, 0.55], [b, 0.0], [b, 0.0], [ml, 0.55], [mr, 0.55], [ml, 0.55], [t, 1.0], [mr, 0.55]]:
			st.set_normal(n)
			st.set_color(root.lerp(tip, v[1]))
			st.set_uv(Vector2(0.5, v[1]))
			st.add_vertex(v[0])
	_tuft_mesh = st.commit()
	return _tuft_mesh
