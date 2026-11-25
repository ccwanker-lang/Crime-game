@tool
class_name ProcGoods
extends Node3D
## City life point 1 (session B): small low-poly models of the shop goods (food, drinks, flowers, clothes) for the
## icons, loot bags and dropped items. Built from primitives, shared materials per colour. Origin = bottom centre.

@export var kind: String = "coffee":
	set(v):
		kind = v
		if is_inside_tree():
			_build()

static var _mats: Dictionary = {}


func _ready() -> void:
	_build()


static func mat(c: Color) -> StandardMaterial3D:
	var key: String = c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.8
		_mats[key] = m
	return _mats[key]


func _part(mesh: Mesh, c: Color, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(c)
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi


static func cyl(r_top: float, r_bot: float, h: float, seg: int = 10) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m


static func box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = s
	return m


static func ball(r: float, h: float = -1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0 if h < 0.0 else h
	m.radial_segments = 10
	m.rings = 5
	return m


func _build() -> void:
	for c: Node in get_children():
		c.free()
	var white := Color(0.95, 0.94, 0.9)
	match kind:
		"coffee", "tea":
			_part(cyl(0.045, 0.035, 0.09), white, Vector3(0, 0.045, 0))
			_part(cyl(0.04, 0.04, 0.005), Color(0.25, 0.14, 0.07) if kind == "coffee" else Color(0.6, 0.35, 0.12), Vector3(0, 0.088, 0))
			_part(cyl(0.08, 0.08, 0.008), white, Vector3(0, 0.004, 0))
		"soda":
			_part(cyl(0.033, 0.033, 0.12), Color(0.8, 0.1, 0.1), Vector3(0, 0.06, 0))
			_part(cyl(0.028, 0.033, 0.01), Color(0.75, 0.75, 0.78), Vector3(0, 0.125, 0))
		"beer":
			_part(cyl(0.04, 0.035, 0.15), Color(0.95, 0.65, 0.15, 1), Vector3(0, 0.075, 0))
			_part(cyl(0.041, 0.041, 0.03), white, Vector3(0, 0.16, 0))
		"wine", "cocktail":
			_part(cyl(0.035, 0.03, 0.005), Color(0.85, 0.9, 0.95), Vector3(0, 0.003, 0))
			_part(cyl(0.006, 0.006, 0.09), Color(0.85, 0.9, 0.95), Vector3(0, 0.05, 0))
			_part(cyl(0.045, 0.01, 0.07) if kind == "wine" else cyl(0.06, 0.005, 0.06),
					Color(0.5, 0.05, 0.12) if kind == "wine" else Color(0.95, 0.45, 0.6), Vector3(0, 0.125, 0))
			if kind == "cocktail":
				_part(cyl(0.0, 0.05, 0.025), Color(0.2, 0.7, 0.9), Vector3(0.02, 0.19, 0), Vector3(0, 0, 0.4))
		"croissant":
			for i: int in 3:
				_part(ball(0.035, 0.05), Color(0.85, 0.6, 0.25), Vector3((i - 1) * 0.045, 0.025, absf(i - 1) * 0.015))
		"sandwich":
			_part(box(Vector3(0.14, 0.025, 0.1)), Color(0.9, 0.75, 0.5), Vector3(0, 0.0125, 0))
			_part(box(Vector3(0.145, 0.012, 0.105)), Color(0.35, 0.7, 0.25), Vector3(0, 0.031, 0))
			_part(box(Vector3(0.14, 0.012, 0.1)), Color(0.95, 0.8, 0.3), Vector3(0, 0.043, 0))
			_part(box(Vector3(0.14, 0.025, 0.1)), Color(0.9, 0.75, 0.5), Vector3(0, 0.06, 0))
		"apple_pie", "cake":
			_part(cyl(0.1, 0.1, 0.01), white, Vector3(0, 0.005, 0))
			_part(box(Vector3(0.09, 0.06, 0.07)), Color(0.85, 0.6, 0.3) if kind == "apple_pie" else Color(0.35, 0.2, 0.12), Vector3(0, 0.04, 0))
			_part(box(Vector3(0.092, 0.012, 0.072)), white if kind == "cake" else Color(0.7, 0.45, 0.2), Vector3(0, 0.076, 0))
		"fries":
			_part(box(Vector3(0.08, 0.1, 0.05)), Color(0.85, 0.12, 0.1), Vector3(0, 0.05, 0))
			for i: int in 7:
				_part(box(Vector3(0.012, 0.09, 0.012)), Color(0.98, 0.82, 0.35), Vector3((i % 4 - 1.5) * 0.016, 0.12, (i / 4 - 0.5) * 0.018), Vector3(0, 0, (i - 3) * 0.08))
		"burger":
			_part(cyl(0.06, 0.065, 0.025), Color(0.85, 0.55, 0.25), Vector3(0, 0.0125, 0))
			_part(cyl(0.065, 0.065, 0.02), Color(0.35, 0.18, 0.1), Vector3(0, 0.035, 0))
			_part(cyl(0.068, 0.068, 0.006), Color(0.98, 0.8, 0.2), Vector3(0, 0.048, 0))
			_part(cyl(0.068, 0.068, 0.006), Color(0.35, 0.7, 0.25), Vector3(0, 0.054, 0))
			_part(ball(0.065, 0.06), Color(0.85, 0.55, 0.25), Vector3(0, 0.06, 0))
		"soup", "pasta", "steak":
			_part(cyl(0.12, 0.09, 0.02 if kind != "soup" else 0.05), white, Vector3(0, 0.01 if kind != "soup" else 0.025, 0))
			match kind:
				"soup":
					_part(cyl(0.1, 0.1, 0.005), Color(0.85, 0.4, 0.15), Vector3(0, 0.045, 0))
				"pasta":
					_part(ball(0.07, 0.05), Color(0.95, 0.85, 0.5), Vector3(0, 0.03, 0))
					_part(ball(0.035, 0.025), Color(0.8, 0.15, 0.1), Vector3(0, 0.055, 0))
				"steak":
					_part(box(Vector3(0.12, 0.025, 0.08)), Color(0.45, 0.22, 0.12), Vector3(-0.02, 0.032, 0), Vector3(0, 0.3, 0))
					for i: int in 4:
						_part(box(Vector3(0.01, 0.01, 0.06)), Color(0.98, 0.82, 0.35), Vector3(0.07, 0.025 + i * 0.008, (i - 1.5) * 0.012))
		"rose_bouquet", "tulips", "sunflowers":
			var head: Color = {"rose_bouquet": Color(0.8, 0.05, 0.12), "tulips": Color(0.95, 0.45, 0.6),
					"sunflowers": Color(0.98, 0.78, 0.1)}[kind]
			_part(cyl(0.06, 0.025, 0.2), Color(0.92, 0.88, 0.75), Vector3(0, 0.1, 0))  # (paper cone)
			for i: int in 7:
				var a: float = TAU * i / 7.0
				var r: float = 0.0 if i == 0 else 0.045
				var p := Vector3(cos(a) * r, 0.25 + (0.02 if i == 0 else 0.0), sin(a) * r)
				_part(cyl(0.004, 0.004, 0.18), Color(0.2, 0.5, 0.2), p - Vector3(0, 0.08, 0))
				if kind == "sunflowers":
					_part(cyl(0.035, 0.035, 0.01), head, p, Vector3(0.6, a, 0))
					_part(cyl(0.015, 0.015, 0.012), Color(0.35, 0.2, 0.08), p, Vector3(0.6, a, 0))
				else:
					_part(ball(0.025, 0.04), head, p)
		"cap":
			_part(ball(0.09, 0.1), Color(0.15, 0.25, 0.55), Vector3(0, 0.0, 0))
			_part(box(Vector3(0.12, 0.008, 0.09)), Color(0.15, 0.25, 0.55), Vector3(0, 0.004, -0.11))
		"sunglasses":
			for sx: float in [-1.0, 1.0]:
				_part(cyl(0.028, 0.028, 0.006), Color(0.05, 0.05, 0.07), Vector3(sx * 0.035, 0.03, 0), Vector3(PI / 2, 0, 0))
				_part(box(Vector3(0.004, 0.004, 0.13)), Color(0.1, 0.1, 0.1), Vector3(sx * 0.066, 0.034, 0.065))
			_part(box(Vector3(0.02, 0.004, 0.004)), Color(0.1, 0.1, 0.1), Vector3(0, 0.036, 0))
		"leather_jacket", "hoodie":
			var c: Color = Color(0.08, 0.07, 0.07) if kind == "leather_jacket" else Color(0.55, 0.56, 0.58)
			_part(box(Vector3(0.28, 0.05, 0.3)), c, Vector3(0, 0.025, 0))
			_part(box(Vector3(0.09, 0.045, 0.26)), c, Vector3(-0.17, 0.022, 0.02), Vector3(0, 0.25, 0))
			_part(box(Vector3(0.09, 0.045, 0.26)), c, Vector3(0.17, 0.022, 0.02), Vector3(0, -0.25, 0))
			if kind == "leather_jacket":
				_part(box(Vector3(0.006, 0.052, 0.28)), Color(0.7, 0.7, 0.72), Vector3(0, 0.026, 0))
			else:
				_part(ball(0.07, 0.04), c.darkened(0.15), Vector3(0, 0.05, -0.15))
		"sneakers":
			for sx: float in [-1.0, 1.0]:
				_part(box(Vector3(0.08, 0.025, 0.24)), Color(0.85, 0.85, 0.85), Vector3(sx * 0.055, 0.0125, 0))
				_part(box(Vector3(0.075, 0.06, 0.16)), Color(0.97, 0.97, 0.97), Vector3(sx * 0.055, 0.05, 0.03))
				_part(box(Vector3(0.077, 0.01, 0.05)), Color(0.85, 0.15, 0.15), Vector3(sx * 0.055, 0.06, -0.06))
		_:
			_part(box(Vector3(0.1, 0.1, 0.1)), Color(0.7, 0.7, 0.7), Vector3(0, 0.05, 0))
