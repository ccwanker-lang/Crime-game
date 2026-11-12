@tool
class_name ProcItem
extends Node3D
## Procedural low-poly model of a small inventory item (held in the hand, dropped,
## rendered as its icon). Origin = where the hand grips it; front = -Z.
## Prefabs in res://prefabs/items/ (written by tools/generators/gen_prefabs.py).

@export_enum("soil_bag", "watering_can", "seed_packet", "baggie", "weed_bag", "weed_bud", "fresh_weed", "ammo_box")
var kind: String = "soil_bag":
	set(v): kind = v; _queue_rebuild()
## Main colour (ammo box print, seed packet label...).
@export var tint: Color = Color(0.7, 0.2, 0.15):
	set(v): tint = v; _queue_rebuild()
## Text-free label band colour (ammo boxes: calibre colour code).
@export var accent: Color = Color(0.9, 0.85, 0.7):
	set(v): accent = v; _queue_rebuild()

var _mesh: MeshInstance3D
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
	if _mesh:
		_mesh.queue_free()
	var b := MeshBuilder.new()
	match kind:
		"soil_bag": _soil_bag(b)
		"watering_can": _watering_can(b)
		"seed_packet": _seed_packet(b)
		"baggie": _baggie(b, false)
		"weed_bag": _baggie(b, true)
		"weed_bud": _bud(b, Vector3.ZERO, 1.0)
		"fresh_weed": _fresh_weed(b)
		"ammo_box": _ammo_box(b)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = b.build()
	_mesh.visibility_range_end = 40.0
	add_child(_mesh)


## Plastic sack of potting soil (~5 l), gripped at the top seam.
func _soil_bag(b: MeshBuilder) -> void:
	var w: float = 0.3
	var h: float = 0.4
	var d: float = 0.11
	b.color = Color(0.13, 0.22, 0.1)
	b.box(&"item_glossy", Vector3(0, -h / 2.0 - 0.02, 0), Vector3(w, h, d), 0.04)
	# Crimped top seam the hand holds.
	b.color = Color(0.1, 0.17, 0.08)
	b.box(&"item_glossy", Vector3(0, -0.01, 0), Vector3(w * 0.96, 0.04, 0.02), 0.005)
	# Printed label: a lighter band with a brown soil "photo".
	b.color = Color(0.85, 0.8, 0.55)
	b.box(&"item_matte", Vector3(0, -0.2, d / 2.0 + 0.001), Vector3(w * 0.8, 0.12, 0.004))
	b.box(&"item_matte", Vector3(0, -0.2, -d / 2.0 - 0.001), Vector3(w * 0.8, 0.12, 0.004))
	b.color = Color(0.3, 0.2, 0.12)
	b.box(&"item_matte", Vector3(0, -0.32, d / 2.0 + 0.002), Vector3(w * 0.6, 0.07, 0.004))


## Green plastic watering can, gripped by the top handle.
func _watering_can(b: MeshBuilder) -> void:
	var body := Color(0.12, 0.42, 0.22)
	b.color = body
	b.cylinder(&"item_glossy", Vector3(0, -0.3, 0.02), Vector3(0, -0.08, 0.02), 0.1, 0.09, 12)
	# Handle arch over the top.
	var pts: Array[Vector3] = []
	for i: int in 7:
		var a: float = PI * float(i) / 6.0
		pts.append(Vector3(0, -0.08 + sin(a) * 0.08, 0.02 + cos(a) * 0.09))
	for i: int in pts.size() - 1:
		b.cylinder(&"item_glossy", pts[i], pts[i + 1], 0.012, 0.012, 6)
	# Spout to the front, rose at the tip.
	b.cylinder(&"item_glossy", Vector3(0, -0.26, -0.06), Vector3(0, -0.06, -0.3), 0.025, 0.014, 8)
	b.color = Color(0.75, 0.75, 0.7)
	b.cylinder(&"item_metal", Vector3(0, -0.065, -0.295), Vector3(0, -0.045, -0.325), 0.022, 0.035, 10)


## Paper seed packet with a coloured label and a little plant picture.
func _seed_packet(b: MeshBuilder) -> void:
	b.color = Color(0.9, 0.88, 0.8)
	b.box(&"item_matte", Vector3(0, 0, 0), Vector3(0.09, 0.13, 0.012), 0.003)
	b.color = tint
	b.box(&"item_matte", Vector3(0, 0.035, 0.0065), Vector3(0.084, 0.05, 0.002))
	b.box(&"item_matte", Vector3(0, 0.035, -0.0065), Vector3(0.084, 0.05, 0.002))
	b.color = Color(0.2, 0.45, 0.15)
	for i: int in 3:
		var a: float = -0.5 + i * 0.5
		var tip := Vector3(sin(a) * 0.025, -0.01 + cos(a) * 0.035, 0.0072)
		b.poly(&"item_matte", PackedVector3Array([Vector3(0, -0.035, 0.0072), tip + Vector3(0.006, -0.012, 0),
				tip, tip + Vector3(-0.006, -0.012, 0)]), Vector3.BACK)


## Small zip bag; `full` = with a bud inside (a sold unit of weed).
func _baggie(b: MeshBuilder, full: bool) -> void:
	var w: float = 0.07
	var h: float = 0.09
	if full:
		b.color = Color(0.36, 0.42, 0.2)
		_bud(b, Vector3(0, -0.012, 0), 0.65)
	b.color = Color(0.95, 0.97, 1.0, 0.28)
	b.box(&"item_clear", Vector3(0, 0, 0), Vector3(w, h, 0.016 if full else 0.004), 0.002)
	# Red zip strip.
	b.color = Color(0.75, 0.08, 0.06)
	b.box(&"item_glossy", Vector3(0, h / 2.0 - 0.008, 0), Vector3(w, 0.005, 0.006 if not full else 0.017))


## Dried bud: a cluster of lumpy blobs with orange hairs.
func _bud(b: MeshBuilder, at: Vector3, s: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 9:
		var p := Vector3(rng.randf_range(-0.012, 0.012), rng.randf_range(-0.02, 0.022), rng.randf_range(-0.012, 0.012)) * s
		b.color = Color(0.34, 0.42, 0.18).lerp(Color(0.48, 0.5, 0.26), rng.randf())
		b.sphere(&"item_matte", at + p, 0.014 * s, 4, 6, Vector3(1, 1.3, 1))
	b.color = Color(0.85, 0.45, 0.15)
	for i: int in 8:
		var p := Vector3(rng.randf_range(-0.016, 0.016), rng.randf_range(-0.02, 0.025), rng.randf_range(-0.016, 0.016)) * s
		b.cylinder(&"item_matte", at + p, at + p * 1.35 + Vector3(0, 0.004, 0), 0.0015, 0.0008, 3, false)


## A freshly cut branch: stem, sticky buds and fan leaves.
func _fresh_weed(b: MeshBuilder) -> void:
	b.color = Color(0.36, 0.46, 0.22)
	b.cylinder(&"item_matte", Vector3(0, -0.05, 0), Vector3(0, 0.3, 0), 0.008, 0.004, 6)
	for i: int in 4:
		var y: float = 0.05 + i * 0.07
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var tip := Vector3(side * 0.06, y + 0.05, 0.01 * side)
		b.color = Color(0.36, 0.46, 0.22)
		b.cylinder(&"item_matte", Vector3(0, y, 0), tip, 0.004, 0.003, 5, false)
		_leaf(b, tip, Vector3(side, 0.5, 0).normalized(), 0.07)
		_bud(b, Vector3(side * 0.012, y + 0.02, 0), 0.8)
	_bud(b, Vector3(0, 0.31, 0), 1.2)


## Seven-fingered fan leaf at `at`, pointing along `dir`.
func _leaf(b: MeshBuilder, at: Vector3, dir: Vector3, length: float) -> void:
	b.color = Color(0.2, 0.42, 0.13)
	var side: Vector3 = dir.cross(Vector3.BACK).normalized()
	for f: int in 7:
		var a: float = (f - 3) * 0.42
		var d: Vector3 = (dir * cos(a) + side * sin(a)).normalized()
		var l: float = length * (1.0 - absf(f - 3) * 0.17)
		var w: Vector3 = d.cross(Vector3.BACK).normalized() * l * 0.12
		b.poly(&"item_matte", PackedVector3Array([at, at + d * l * 0.45 + w, at + d * l, at + d * l * 0.45 - w]),
				Vector3.BACK)


## Cardboard box of cartridges, calibre colour band on the sides.
func _ammo_box(b: MeshBuilder) -> void:
	b.color = tint
	b.box(&"item_matte", Vector3.ZERO, Vector3(0.1, 0.055, 0.14), 0.004)
	b.color = accent
	b.box(&"item_matte", Vector3(0, 0, 0), Vector3(0.102, 0.022, 0.1))
	b.color = Color(0.85, 0.7, 0.35)
	for i: int in 3:  # brass rims showing through the open lid
		b.cylinder(&"item_metal", Vector3(-0.03 + i * 0.03, 0.0275, -0.05), Vector3(-0.03 + i * 0.03, 0.031, -0.05), 0.006, 0.006, 8)
