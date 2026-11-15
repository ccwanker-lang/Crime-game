class_name BorderRange
extends StaticBody3D
## Map blueprint zone 9: the snowy mountains round the whole map (the natural border; no invisible walls in the
## fields). Built at load from data/border/ (tools/generators/gen_border.py): a 2 m heightmap that lies under the
## ground inside the playable land and the sea (not drawn there) and rises outside it - a short grass foot you can
## walk on, then too steep to climb, up to snowy peaks - plus pines on the lower slopes. Layer 1 (world).

const DATA_PATH: String = "res://data/border/border.json"
const HEIGHT_PATH: String = "res://data/border/height.bin"
const RENDER_STEP: int = 2  # mesh every 2 cells (4 m)

static var _data: Dictionary = {}
static var _heights: PackedFloat32Array


static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA_PATH):
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_heights = FileAccess.get_file_as_bytes(HEIGHT_PATH).to_float32_array()
	return _data


## Border terrain height at (x, z) (under 0 inside the playable land).
static func height_at(x: float, z: float) -> float:
	var g: Dictionary = data().get("grid", {})
	if g.is_empty():
		return -10.0
	var fx: float = (x - float(g["x0"])) / float(g["cell"])
	var fz: float = (z - float(g["z0"])) / float(g["cell"])
	var nx: int = int(g["nx"])
	var nz: int = int(g["nz"])
	if fx < 0.0 or fz < 0.0 or fx > nx - 1 or fz > nz - 1:
		return -10.0
	var ix: int = mini(int(fx), nx - 2)
	var iz: int = mini(int(fz), nz - 2)
	var a: float = lerpf(_heights[iz * nx + ix], _heights[iz * nx + ix + 1], fx - ix)
	var b: float = lerpf(_heights[(iz + 1) * nx + ix], _heights[(iz + 1) * nx + ix + 1], fx - ix)
	return lerpf(a, b, fz - iz)


## The playable land + sea rectangles (x0, z0, x1, z1) the border runs round.
static func land_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r: Array in data().get("land", []):
		out.append(Rect2(r[0], r[1], float(r[2]) - float(r[0]), float(r[3]) - float(r[1])))
	return out


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	if data().is_empty():
		push_warning("BorderRange: no data in %s (run tools/generators/gen_border.py)" % DATA_PATH)
		return
	_build_terrain()
	_build_pines()


func _build_terrain() -> void:
	var g: Dictionary = data()["grid"]
	var nx: int = int(g["nx"])
	var nz: int = int(g["nz"])
	var x0: float = float(g["x0"])
	var z0: float = float(g["z0"])
	var cell: float = float(g["cell"])
	# Collision: the heightmap with 1 m spacing, scaled up to the 2 m cells (heights pre-divided so the uniform
	# scale gives the right height).
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var scaled := PackedFloat32Array()
	scaled.resize(_heights.size())
	for i: int in _heights.size():
		scaled[i] = _heights[i] / cell
	var shape := HeightMapShape3D.new()
	shape.map_width = nx
	shape.map_depth = nz
	shape.map_data = scaled
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3.ONE * cell
	cs.position = Vector3(x0 + (nx - 1) * cell / 2.0, 0.0, z0 + (nz - 1) * cell / 2.0)
	body.add_child(cs)
	# Mesh: flat-shaded, coloured by height + slope (grass foot, rock faces, snow on top).
	var snow_line: float = float(data().get("snow_line", 48.0))
	var grass: Color = Palette.color(&"grass_dark")
	var grass_hi := Color(0.42, 0.55, 0.32)
	var rock := Color(0.5, 0.49, 0.47)
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
			if maxf(maxf(p00.y, p10.y), maxf(p01.y, p11.y)) < 0.0:
				continue  # under the ground / the sea: the ground slabs and the water show there
			for tri: Array in [[p00, p10, p11], [p00, p11, p01]]:
				var a: Vector3 = tri[0]
				var b: Vector3 = tri[1]
				var c: Vector3 = tri[2]
				var n: Vector3 = (c - a).cross(b - a).normalized()
				if n.y < 0.0:
					n = -n
				var h: float = (a.y + b.y + c.y) / 3.0
				var wobble: float = sin(a.x * 0.13 + a.z * 0.07) * 4.0 + sin(a.x * 0.05 - a.z * 0.11) * 3.0
				var colr: Color = grass.lerp(grass_hi, clampf(h / 30.0, 0.0, 1.0))
				if n.y < 0.75:
					colr = colr.lerp(rock, clampf((0.75 - n.y) / 0.2, 0.0, 1.0))
				if h + wobble > snow_line:
					colr = colr.lerp(snow, clampf((h + wobble - snow_line) / 6.0, 0.0, 1.0) * (0.7 if n.y < 0.5 else 1.0))
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


func _build_pines() -> void:
	var pines: Array = data().get("pines", [])
	for snowy: int in [0, 1]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Mountain._pine_mesh(snowy == 1)
		var list: Array = pines.filter(func(p: Array) -> bool: return int(p[4]) == snowy)
		mm.instance_count = list.size()
		for i: int in list.size():
			var p: Array = list[i]
			var s: float = float(p[3]) * 1.6
			mm.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(0, float(i) * 2.39, 0)).scaled(Vector3.ONE * s),
					Vector3(p[0], p[1], p[2])))
		var mi := MultiMeshInstance3D.new()
		mi.name = "Pines%d" % snowy
		mi.multimesh = mm
		add_child(mi)
