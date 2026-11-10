class_name MeshBuilder
extends RefCounted
## Collects procedural geometry per material key and builds one ArrayMesh
## (one surface per material = few draw calls).
## Material keys are file names in res://prefabs/materials/ (e.g. &"brick_old").
## UVs are in metres (projected from position) unless given explicitly.
## Godot treats clockwise triangles (seen from the front) as front faces;
## poly() fixes the winding automatically from the `outward` hint.

const MAT_DIR: String = "res://prefabs/materials/"

## Applied to every point added (lets callers build in a local frame).
var xform: Transform3D = Transform3D.IDENTITY
## Vertex colour for the next primitives (used by glass, awnings, foliage wind).
var color: Color = Color.WHITE
## When true, box() also records a collision box.
var collide: bool = false
## Recorded collision boxes: [{ "xform": Transform3D, "size": Vector3 }]
var collision_boxes: Array[Dictionary] = []

var _tools: Dictionary = {}  # StringName -> SurfaceTool


static func get_material(key: StringName) -> Material:
	return load(MAT_DIR + String(key) + ".tres") as Material


func has_geometry() -> bool:
	return not _tools.is_empty()


func _st(key: StringName) -> SurfaceTool:
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = st
	return _tools[key]


## Builds the final mesh. Each material key becomes one surface.
func build() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for key: StringName in _tools:
		var st: SurfaceTool = _tools[key]
		var arrays: Array = st.commit_to_arrays()
		if arrays[Mesh.ARRAY_VERTEX] == null or (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
			continue  # key was touched but only got degenerate polygons
		st.generate_tangents()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, get_material(key))
	return mesh


# --- Polygons ---------------------------------------------------------------

## Adds a planar convex polygon (points in order, either winding).
## outward: direction the visible side faces (local space).
## uvs: optional explicit UVs (same count as points); otherwise metres projected
## on the dominant axis, or along uv_u / uv_v if given.
func poly(key: StringName, pts: PackedVector3Array, outward: Vector3,
		uvs: PackedVector2Array = PackedVector2Array(),
		uv_u: Vector3 = Vector3.ZERO, uv_v: Vector3 = Vector3.ZERO) -> void:
	var count: int = pts.size()
	if count < 3:
		return
	var p := PackedVector3Array()
	p.resize(count)
	for i: int in count:
		p[i] = xform * pts[i]
	var hint: Vector3 = (xform.basis * outward).normalized()
	var n: Vector3 = _newell(p)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	# Right-hand normal along the hint = counter-clockwise from outside,
	# but Godot wants clockwise front faces -> reverse the triangle order.
	var reverse: bool = n.dot(hint) > 0.0
	var face_normal: Vector3 = n if reverse else -n

	var uv := PackedVector2Array()
	uv.resize(count)
	if uvs.size() == count:
		uv = uvs
	elif uv_u != Vector3.ZERO:
		var u_axis: Vector3 = (xform.basis * uv_u).normalized()
		var v_axis: Vector3 = (xform.basis * uv_v).normalized()
		for i: int in count:
			uv[i] = Vector2(p[i].dot(u_axis), p[i].dot(v_axis))
	else:
		for i: int in count:
			uv[i] = _project_uv(p[i], face_normal)

	var st: SurfaceTool = _st(key)
	for i: int in range(1, count - 1):
		var idx := PackedInt32Array([0, i, i + 1] if not reverse else [0, i + 1, i])
		for j: int in idx:
			st.set_normal(face_normal)
			st.set_uv(uv[j])
			st.set_color(color)
			st.add_vertex(p[j])


## Quad with one custom normal for all vertices and no winding fix
## (for double-sided foliage cards where the normal shapes the lighting).
func card(key: StringName, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3,
		uvs: PackedVector2Array) -> void:
	var p: Array[Vector3] = [xform * a, xform * b, xform * c, xform * d]
	var n: Vector3 = (xform.basis * normal).normalized()
	var st: SurfaceTool = _st(key)
	for j: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n)
		st.set_uv(uvs[j])
		st.set_color(color)
		st.add_vertex(p[j])


func quad(key: StringName, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3,
		uvs: PackedVector2Array = PackedVector2Array()) -> void:
	poly(key, PackedVector3Array([a, b, c, d]), outward, uvs)


static func _newell(p: PackedVector3Array) -> Vector3:
	var n := Vector3.ZERO
	var count: int = p.size()
	for i: int in count:
		var a: Vector3 = p[i]
		var b: Vector3 = p[(i + 1) % count]
		n.x += (a.y - b.y) * (a.z + b.z)
		n.y += (a.z - b.z) * (a.x + b.x)
		n.z += (a.x - b.x) * (a.y + b.y)
	return n


static func _project_uv(q: Vector3, n: Vector3) -> Vector2:
	var ax: float = absf(n.x)
	var ay: float = absf(n.y)
	var az: float = absf(n.z)
	if ay >= ax and ay >= az:
		return Vector2(q.x, q.z)
	if ax >= az:
		return Vector2(q.z, -q.y)
	return Vector2(q.x, -q.y)


# --- Boxes ------------------------------------------------------------------

const SKIP_NONE: int = 0
const SKIP_BOTTOM: int = 1
const SKIP_TOP: int = 2

## Axis-aligned box (in the current xform) with optional chamfered edges.
func box(key: StringName, center: Vector3, size: Vector3, bevel: float = 0.0, skip: int = SKIP_NONE) -> void:
	if size.x <= 0.001 or size.y <= 0.001 or size.z <= 0.001:
		return
	if collide:
		collision_boxes.append({"xform": xform * Transform3D(Basis.IDENTITY, center), "size": size})
	var h: Vector3 = size * 0.5
	var b: float = minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.8)
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	# Faces
	for axis: int in 3:
		for s: float in [-1.0, 1.0]:
			if axis == 1 and s < 0.0 and (skip & SKIP_BOTTOM):
				continue
			if axis == 1 and s > 0.0 and (skip & SKIP_TOP):
				continue
			var pts := PackedVector3Array()
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var sv := Vector3.ZERO
				sv[axis] = s
				sv[(axis + 1) % 3] = corner.x
				sv[(axis + 2) % 3] = corner.y
				pts.append(_bevel_point(center, h, b, sv, axis))
			poly(key, pts, axes[axis] * s)
	if b <= 0.0:
		return
	# Chamfered edges
	for a1: int in 3:
		var a2: int = (a1 + 1) % 3
		var a3: int = (a1 + 2) % 3
		for s1: float in [-1.0, 1.0]:
			for s2: float in [-1.0, 1.0]:
				var pts := PackedVector3Array()
				for s3: float in [-1.0, 1.0]:
					var sv := Vector3.ZERO
					sv[a1] = s1
					sv[a2] = s2
					sv[a3] = s3
					pts.append(_bevel_point(center, h, b, sv, a1))
				for s3: float in [1.0, -1.0]:
					var sv := Vector3.ZERO
					sv[a1] = s1
					sv[a2] = s2
					sv[a3] = s3
					pts.append(_bevel_point(center, h, b, sv, a2))
				poly(key, pts, (axes[a1] * s1 + axes[a2] * s2).normalized())
	# Corner triangles
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var sv := Vector3(sx, sy, sz)
				poly(key, PackedVector3Array([
					_bevel_point(center, h, b, sv, 0),
					_bevel_point(center, h, b, sv, 1),
					_bevel_point(center, h, b, sv, 2)]), sv.normalized())


static func _bevel_point(c: Vector3, h: Vector3, b: float, s: Vector3, axis: int) -> Vector3:
	var p := Vector3.ZERO
	for i: int in 3:
		p[i] = c[i] + s[i] * (h[i] if i == axis else h[i] - b)
	return p


## Records a collision box without adding geometry (e.g. for glass panes).
func add_collision_box(center: Vector3, size: Vector3) -> void:
	collision_boxes.append({"xform": xform * Transform3D(Basis.IDENTITY, center), "size": size})


## Box from min/max corners.
func box_mm(key: StringName, mn: Vector3, mx: Vector3, bevel: float = 0.0, skip: int = SKIP_NONE) -> void:
	box(key, (mn + mx) * 0.5, mx - mn, bevel, skip)


# --- Cylinders ----------------------------------------------------------------

## Tapered cylinder from base to top with smooth sides (poles, pipes, trunks).
func cylinder(key: StringName, base: Vector3, top: Vector3, r0: float, r1: float,
		sides: int = 8, caps: bool = true, uv_len: float = 1.0) -> void:
	var axis: Vector3 = (top - base)
	var length: float = axis.length()
	if length < 1e-4:
		return
	axis /= length
	var ref: Vector3 = Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT
	var t1: Vector3 = axis.cross(ref).normalized()
	var t2: Vector3 = axis.cross(t1).normalized()
	var st: SurfaceTool = _st(key)
	var circ: float = TAU * maxf(r0, r1)
	for i: int in sides:
		var a0: float = TAU * float(i) / sides
		var a1: float = TAU * float(i + 1) / sides
		var d0: Vector3 = t1 * cos(a0) + t2 * sin(a0)
		var d1: Vector3 = t1 * cos(a1) + t2 * sin(a1)
		var v: Array[Vector3] = [base + d0 * r0, base + d1 * r0, top + d1 * r1, top + d0 * r1]
		var nrm: Array[Vector3] = [d0, d1, d1, d0]
		var u0: float = float(i) / sides * circ
		var u1: float = float(i + 1) / sides * circ
		var uvs: Array[Vector2] = [Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, -length * uv_len), Vector2(u0, -length * uv_len)]
		# Two triangles; order chosen so the outside is the front face.
		for j: int in [0, 2, 1, 0, 3, 2]:
			st.set_normal((xform.basis * nrm[j]).normalized())
			st.set_uv(uvs[j])
			st.set_color(color)
			st.add_vertex(xform * v[j])
	if caps:
		var top_pts := PackedVector3Array()
		var bottom_pts := PackedVector3Array()
		for i: int in sides:
			var a: float = TAU * float(i) / sides
			var d: Vector3 = t1 * cos(a) + t2 * sin(a)
			top_pts.append(top + d * r1)
			bottom_pts.append(base + d * r0)
		if r1 > 0.001:
			poly(key, top_pts, axis)
		if r0 > 0.001:
			poly(key, bottom_pts, -axis)


# --- Extruded 2D shapes (roads, pavements) -------------------------------------

## Extrudes a 2D outline (in XZ) into a slab with a top face at y_top.
## side_edges: per edge index i (from point i to i+1) whether to draw its side.
## Empty = all sides.
func slab(top_key: StringName, side_key: StringName, outline: PackedVector2Array,
		y_top: float, y_bottom: float, side_edges: Array = []) -> void:
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	for i: int in range(0, tris.size(), 3):
		var a: Vector2 = outline[tris[i]]
		var b: Vector2 = outline[tris[i + 1]]
		var c: Vector2 = outline[tris[i + 2]]
		poly(top_key, PackedVector3Array([
			Vector3(a.x, y_top, a.y), Vector3(b.x, y_top, b.y), Vector3(c.x, y_top, c.y)]), Vector3.UP)
	if y_top - y_bottom < 0.001:
		return
	var count: int = outline.size()
	for i: int in count:
		if not side_edges.is_empty() and not side_edges[i]:
			continue
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % count]
		var d: Vector2 = (b - a)
		if d.length() < 1e-4:
			continue
		var n2 := Vector2(d.y, -d.x).normalized()
		if Geometry2D.is_point_in_polygon((a + b) * 0.5 + n2 * 0.01, outline):
			n2 = -n2
		quad(side_key, Vector3(a.x, y_top, a.y), Vector3(b.x, y_top, b.y),
				Vector3(b.x, y_bottom, b.y), Vector3(a.x, y_bottom, a.y), Vector3(n2.x, 0, n2.y))
