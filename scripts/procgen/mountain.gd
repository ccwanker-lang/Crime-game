class_name Mountain
extends StaticBody3D
## Point 49b: the mountain between Hollow Farm and the prison, with the hairpin pass road over it.
## Built at load from data/mountain/ (tools/generators/gen_mountain.py): a heightmap terrain (grass, rock on steep
## slopes, snow up high) with HeightMapShape3D collision, the road ribbon (asphalt, markings, shoulders) with
## trimesh collision, guardrails, pines and rocks. Layer 1 (world), outside NavRegion: no navmesh on the mountain.
## The same data gives traffic route 5 (`route_points`) and the intro bus path (`bus_points`).

const DATA_PATH: String = "res://data/mountain/mountain.json"
const HEIGHT_PATH: String = "res://data/mountain/height.bin"
const RENDER_STEP: int = 2  # terrain mesh every 2 m (collision every 1 m)
const SNOW_LINE: float = 27.0
const ROAD_HALF: float = 3.5
const SHOULDER: float = 1.2
const RAIL_H: float = 0.75

static var _data: Dictionary = {}
static var _heights: PackedFloat32Array


## The generator's data (cached; empty when the files are missing).
static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA_PATH):
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_heights = FileAccess.get_file_as_bytes(HEIGHT_PATH).to_float32_array()
	return _data


static func _pts(key: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p: Array in data().get(key, []):
		out.append(Vector3(p[0], p[1], p[2]))
	return out


## Traffic route 5 (closed loop over the pass, 1 m apart).
static func route_points() -> PackedVector3Array:
	return _pts("route")


## The intro bus: from the prison gate down the pass to the bus stop on Main Road.
static func bus_points() -> PackedVector3Array:
	return _pts("bus")


## The road centre line (ribbon part).
static func road_points() -> PackedVector3Array:
	return _pts("road")


## True when (x, z) is on the pass road's asphalt (tests).
static func on_road(p: Vector3, margin: float = 0.3) -> bool:
	for q: Vector3 in road_points():
		if Vector2(q.x - p.x, q.z - p.z).length() < ROAD_HALF + margin:
			return true
	return false


## Terrain height at (x, z) (0 outside the grid).
static func height_at(x: float, z: float) -> float:
	var g: Dictionary = data().get("grid", {})
	if g.is_empty():
		return 0.0
	var fx: float = (x - float(g["x0"])) / float(g["cell"])
	var fz: float = (z - float(g["z0"])) / float(g["cell"])
	var nx: int = int(g["nx"])
	var nz: int = int(g["nz"])
	if fx < 0.0 or fz < 0.0 or fx > nx - 1 or fz > nz - 1:
		return 0.0
	var ix: int = mini(int(fx), nx - 2)
	var iz: int = mini(int(fz), nz - 2)
	var tx: float = fx - ix
	var tz: float = fz - iz
	var a: float = lerpf(_heights[iz * nx + ix], _heights[iz * nx + ix + 1], tx)
	var b: float = lerpf(_heights[(iz + 1) * nx + ix], _heights[(iz + 1) * nx + ix + 1], tx)
	return lerpf(a, b, tz)


## Jolt can't hold heightmap + trimesh + ~1200 small shapes in one compound: each kind gets its own body.
var _bodies: Dictionary = {}


func _body(key: String) -> StaticBody3D:
	if not _bodies.has(key):
		var b := StaticBody3D.new()
		b.name = key + "Body"
		b.collision_layer = 1
		b.collision_mask = 0
		add_child(b)
		_bodies[key] = b
	return _bodies[key]


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	if data().is_empty():
		push_warning("Mountain: no data in %s (run tools/generators/gen_mountain.py)" % DATA_PATH)
		return
	_build_terrain()
	_build_road()
	_build_rails()
	_build_props()


# --- Terrain ---------------------------------------------------------------------------

func _build_terrain() -> void:
	var g: Dictionary = data()["grid"]
	var nx: int = int(g["nx"])
	var nz: int = int(g["nz"])
	var x0: float = float(g["x0"])
	var z0: float = float(g["z0"])
	var cell: float = float(g["cell"])
	# Collision: the full 1 m heightmap (a HeightMapShape3D is centred on its node).
	var shape := HeightMapShape3D.new()
	shape.map_width = nx
	shape.map_depth = nz
	shape.map_data = _heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(x0 + (nx - 1) * cell / 2.0, 0.0, z0 + (nz - 1) * cell / 2.0)
	_body("Terrain").add_child(cs)
	# Mesh: flat-shaded triangles every RENDER_STEP m, coloured by height and slope.
	var grass: Color = Palette.color(&"grass_dark")
	var grass_hi := Color(0.45, 0.6, 0.32)
	var rock := Color(0.48, 0.47, 0.45)
	var snow := Color(0.94, 0.96, 0.98)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var step: int = RENDER_STEP
	for iz: int in range(0, nz - step, step):
		for ix: int in range(0, nx - step, step):
			var p00 := Vector3(x0 + ix * cell, _heights[iz * nx + ix], z0 + iz * cell)
			var p10 := Vector3(x0 + (ix + step) * cell, _heights[iz * nx + ix + step], z0 + iz * cell)
			var p01 := Vector3(x0 + ix * cell, _heights[(iz + step) * nx + ix], z0 + (iz + step) * cell)
			var p11 := Vector3(x0 + (ix + step) * cell, _heights[(iz + step) * nx + ix + step], z0 + (iz + step) * cell)
			if maxf(maxf(p00.y, p10.y), maxf(p01.y, p11.y)) < 0.02:
				continue  # flat land at ground height: the village ground already shows there
			for tri: Array in [[p00, p10, p11], [p00, p11, p01]]:
				var a: Vector3 = tri[0]
				var b: Vector3 = tri[1]
				var c: Vector3 = tri[2]
				var n: Vector3 = (c - a).cross(b - a).normalized()
				if n.y < 0.0:
					n = -n
				var h: float = (a.y + b.y + c.y) / 3.0
				var wobble: float = sin(a.x * 0.37 + a.z * 0.21) * 1.6 + sin(a.x * 0.11 - a.z * 0.29) * 1.2
				var colr: Color = grass.lerp(grass_hi, clampf(h / 20.0, 0.0, 1.0))
				if n.y < 0.72:
					colr = colr.lerp(rock, clampf((0.72 - n.y) / 0.15, 0.0, 1.0))
				if h + wobble > SNOW_LINE:
					colr = colr.lerp(snow, clampf((h + wobble - SNOW_LINE) / 3.0, 0.0, 1.0) * (0.55 if n.y < 0.6 else 1.0))
				for v: Vector3 in [a, b, c]:
					verts.append(v)
					norms.append(n)
					cols.append(colr)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	add_child(mi)


# --- Road ------------------------------------------------------------------------------

## Left/right edge points of the centre line `pts` at `half` m (right = of the driving direction).
static func _side(pts: PackedVector3Array, i: int, off: float) -> Vector3:
	var a: Vector3 = pts[maxi(0, i - 1)]
	var b: Vector3 = pts[mini(pts.size() - 1, i + 1)]
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var right := Vector3(-d.z, 0.0, d.x)
	return pts[i] + right * off


func _build_road() -> void:
	var all: PackedVector3Array = road_points()
	var pts := PackedVector3Array()
	for i: int in range(0, all.size(), 2):  # 1 m
		pts.append(all[i])
	var b := MeshBuilder.new()
	var faces := PackedVector3Array()
	var up := Vector3.UP
	for i: int in pts.size() - 1:
		var l0: Vector3 = _side(pts, i, -ROAD_HALF)
		var r0: Vector3 = _side(pts, i, ROAD_HALF)
		var l1: Vector3 = _side(pts, i + 1, -ROAD_HALF)
		var r1: Vector3 = _side(pts, i + 1, ROAD_HALF)
		b.quad(&"asphalt", l0, r0, r1, l1, up)
		faces.append_array([l0, r1, r0, l0, l1, r1])
		# Shoulders (gravel-grey, sloping down) and a skirt down into the ground.
		for s: float in [-1.0, 1.0]:
			var e0: Vector3 = r0 if s > 0.0 else l0
			var e1: Vector3 = r1 if s > 0.0 else l1
			var o0: Vector3 = _side(pts, i, s * (ROAD_HALF + SHOULDER)) + Vector3.DOWN * 0.12
			var o1: Vector3 = _side(pts, i + 1, s * (ROAD_HALF + SHOULDER)) + Vector3.DOWN * 0.12
			b.quad(&"curb", e0, o0, o1, e1, up)
			faces.append_array([e0, o1, o0, e0, e1, o1] if s > 0.0 else [e0, o0, o1, e0, o1, e1])
			var out: Vector3 = (o0 - e0).normalized()
			b.quad(&"curb", o0, o1, o1 + Vector3.DOWN * 1.6, o0 + Vector3.DOWN * 1.6, out)
		# Markings: a dashed centre line, solid edge lines (1 cm above the asphalt).
		var lift := Vector3.UP * 0.012
		if i % 6 < 3:
			b.quad(&"road_marking", _side(pts, i, -0.06) + lift, _side(pts, i, 0.06) + lift,
					_side(pts, i + 1, 0.06) + lift, _side(pts, i + 1, -0.06) + lift, up)
		for e: float in [-ROAD_HALF + 0.25, ROAD_HALF - 0.25]:
			b.quad(&"road_marking", _side(pts, i, e - 0.06) + lift, _side(pts, i, e + 0.06) + lift,
					_side(pts, i + 1, e + 0.06) + lift, _side(pts, i + 1, e - 0.06) + lift, up)
	var mi := MeshInstance3D.new()
	mi.name = "Road"
	mi.mesh = b.build()
	add_child(mi)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.name = "RoadCollision"
	cs.shape = shape
	_body("Road").add_child(cs)


# --- Guardrails ------------------------------------------------------------------------

func _build_rails() -> void:
	var b := MeshBuilder.new()
	for line: Array in data().get("rails", []):
		var pts := PackedVector3Array()
		for p: Array in line:
			pts.append(Vector3(p[0], p[1], p[2]))
		for i: int in pts.size():
			b.color = Color(0.55, 0.57, 0.6)
			b.box(&"item_matte", pts[i] + Vector3(0, RAIL_H / 2.0 - 0.1, 0), Vector3(0.12, RAIL_H + 0.2, 0.12))
			if i + 1 >= pts.size() or pts[i].distance_to(pts[i + 1]) > 6.0:
				continue
			# The beam between this post and the next (a thin box along the segment) + a collision box.
			var a: Vector3 = pts[i] + Vector3(0, RAIL_H - 0.17, 0)
			var c: Vector3 = pts[i + 1] + Vector3(0, RAIL_H - 0.17, 0)
			var mid: Vector3 = (a + c) / 2.0
			var along: Vector3 = c - a
			var seg_len: float = along.length()
			var basis := Basis.looking_at(along.normalized(), Vector3.UP)
			b.xform = Transform3D(basis, mid)
			b.color = Color(0.78, 0.8, 0.82)
			b.box(&"item_glossy", Vector3.ZERO, Vector3(0.06, 0.3, seg_len + 0.02))
			b.xform = Transform3D.IDENTITY
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(0.2, 1.2, seg_len)
			cs.shape = box
			cs.transform = Transform3D(basis, mid + Vector3(0, -0.1, 0))
			_body("Rails").add_child(cs)
	var mi := MeshInstance3D.new()
	mi.name = "Guardrails"
	mi.mesh = b.build()
	add_child(mi)


# --- Pines + rocks ---------------------------------------------------------------------

static func _pine_mesh(snowy: bool) -> ArrayMesh:
	var b := MeshBuilder.new()
	b.color = Color(0.36, 0.25, 0.16)
	b.cylinder(&"item_matte", Vector3.ZERO, Vector3(0, 1.6, 0), 0.22, 0.15, 6)
	var green := Color(0.16, 0.34, 0.22)
	var tiers: Array = [[1.0, 2.0, 3.4], [2.4, 1.6, 2.8], [3.7, 1.15, 2.3]]  # base y, radius, height
	for k: int in tiers.size():
		var t: Array = tiers[k]
		b.color = green.lightened(0.06 * k)
		if snowy and k == tiers.size() - 1:
			b.color = Color(0.93, 0.95, 0.97)
		b.cylinder(&"item_matte", Vector3(0, t[0], 0), Vector3(0, float(t[0]) + float(t[2]), 0), t[1], 0.02, 7)
	return b.build()


static func _rock_mesh() -> ArrayMesh:
	var b := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4949
	var greys: Array[Color] = [Color(0.5, 0.49, 0.47), Color(0.44, 0.43, 0.42), Color(0.56, 0.55, 0.52)]
	b.blob(&"item_matte", Vector3(0, 0.35, 0), 0.8, Vector3(1.2, 0.75, 1.0), rng, greys, 0.22, 1, -0.2)
	return b.build()


func _build_props() -> void:
	var pines: Array = data().get("pines", [])
	for snowy: int in [0, 1]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _pine_mesh(snowy == 1)
		var list: Array = pines.filter(func(p: Array) -> bool: return int(p[4]) == snowy)
		mm.instance_count = list.size()
		for i: int in list.size():
			var p: Array = list[i]
			var s: float = p[3]
			var basis := Basis(Vector3.UP, float(i) * 2.4).scaled(Vector3(s, s * 1.15, s))
			mm.set_instance_transform(i, Transform3D(basis, Vector3(p[0], p[1], p[2])))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Pines%d" % snowy
		mmi.multimesh = mm
		add_child(mmi)
	for p: Array in pines:
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.25 * float(p[3])
		cyl.height = 3.0
		cs.shape = cyl
		cs.position = Vector3(p[0], float(p[1]) + 1.5, p[2])
		_body("Pines").add_child(cs)
	var rocks: Array = data().get("rocks", [])
	var rm := MultiMesh.new()
	rm.transform_format = MultiMesh.TRANSFORM_3D
	rm.mesh = _rock_mesh()
	rm.instance_count = rocks.size()
	for i: int in rocks.size():
		var p: Array = rocks[i]
		var s: float = p[3]
		rm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, deg_to_rad(p[4])).scaled(Vector3.ONE * s),
				Vector3(p[0], p[1], p[2])))
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.7 * s
		cs.shape = sph
		cs.position = Vector3(p[0], float(p[1]) + 0.3 * s, p[2])
		_body("Rocks").add_child(cs)
	var rmi := MultiMeshInstance3D.new()
	rmi.name = "Rocks"
	rmi.multimesh = rm
	add_child(rmi)
