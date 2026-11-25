@tool
class_name ArmyProp
extends StaticBody3D
## Point 100: the army base's furniture and field kit as ONE mesh + one collision box per piece (shared per kind +
## length, so 30 bunks cost one mesh): bunk beds, a weapon rack with rifles, sandbag walls, a map table, a radio
## cabinet, an ammo crate stack. Origin = floor centre of the piece; its front faces +Z; length runs along X.

enum Kind { BUNK_BED, WEAPON_RACK, SANDBAGS, MAP_TABLE, RADIO, AMMO_STACK, LOCKER }

@export var kind: Kind = Kind.BUNK_BED:
	set(v): kind = v; _queue_rebuild()
## Sandbags / weapon rack / lockers: length along X (m). Sandbags: `rows` high.
@export var length: float = 3.0:
	set(v): length = v; _queue_rebuild()
@export var rows: int = 3:
	set(v): rows = v; _queue_rebuild()

const OLIVE := Color(0.36, 0.4, 0.27)
const SAND := Color(0.72, 0.64, 0.46)
const STEEL := Color(0.28, 0.3, 0.32)
static var _cache: Dictionary = {}  # key -> [ArrayMesh, AABB]

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
	var entry: Array = model(kind, length, rows)
	var mi := MeshInstance3D.new()
	mi.mesh = entry[0]
	add_child(mi)
	_generated.append(mi)
	var box: AABB = entry[1]
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	cs.shape = shape
	cs.position = box.get_center()
	add_child(cs)
	_generated.append(cs)


## [mesh, collision AABB] for a kind (cached).
static func model(k: Kind, len: float, rws: int) -> Array:
	var key: String = "%d|%.2f|%d" % [k, len, rws]
	if _cache.has(key):
		return _cache[key]
	var b := MeshBuilder.new()
	var box := AABB()
	match k:
		Kind.BUNK_BED:
			box = _bunk(b)
		Kind.WEAPON_RACK:
			box = _rack(b, len)
		Kind.SANDBAGS:
			box = _sandbags(b, len, rws)
		Kind.MAP_TABLE:
			box = _map_table(b)
		Kind.RADIO:
			box = _radio(b)
		Kind.AMMO_STACK:
			box = _ammo(b)
		Kind.LOCKER:
			box = _lockers(b, len)
	var out: Array = [b.build(), box]
	_cache[key] = out
	return out


static func _bunk(b: MeshBuilder) -> AABB:
	var w: float = 0.95
	var l: float = 2.0
	b.color = STEEL
	for x: float in [-w / 2.0 + 0.03, w / 2.0 - 0.03]:
		for z: float in [-l / 2.0 + 0.03, l / 2.0 - 0.03]:
			b.box(&"item_metal", Vector3(x, 0.9, z), Vector3(0.05, 1.8, 0.05))
	for y: float in [0.38, 1.38]:
		b.color = STEEL
		b.box(&"item_metal", Vector3(0, y, 0), Vector3(w, 0.05, l))
		b.color = OLIVE
		b.box(&"item_matte", Vector3(0, y + 0.1, 0), Vector3(w - 0.08, 0.14, l - 0.06), 0.03)
		b.color = Color(0.85, 0.85, 0.8)
		b.box(&"item_matte", Vector3(0, y + 0.22, -l / 2.0 + 0.25), Vector3(0.6, 0.1, 0.3), 0.03)
		b.color = Color(0.3, 0.34, 0.24)  # folded blanket at the foot
		b.box(&"item_matte", Vector3(0, y + 0.2, l / 2.0 - 0.3), Vector3(w - 0.12, 0.08, 0.45), 0.02)
	b.color = STEEL  # ladder at the foot
	for y: float in [0.6, 0.9, 1.2]:
		b.box(&"item_metal", Vector3(0, y, l / 2.0 - 0.02), Vector3(w - 0.1, 0.03, 0.03))
	return AABB(Vector3(-w / 2.0, 0, -l / 2.0), Vector3(w, 1.8, l))


static func _rack(b: MeshBuilder, len: float) -> AABB:
	b.color = OLIVE.darkened(0.2)
	b.box(&"item_matte", Vector3(0, 0.05, -0.15), Vector3(len, 0.1, 0.4))
	b.box(&"item_matte", Vector3(0, 1.75, -0.3), Vector3(len, 0.08, 0.12))
	for x: float in [-len / 2.0 + 0.05, len / 2.0 - 0.05]:
		b.box(&"item_matte", Vector3(x, 0.9, -0.2), Vector3(0.08, 1.8, 0.3))
	var n: int = int(len / 0.32)
	for i: int in n:
		var x: float = -len / 2.0 + 0.2 + i * (len - 0.4) / maxf(n - 1, 1)
		b.color = Color(0.12, 0.12, 0.13)
		b.box(&"item_metal", Vector3(x, 0.95, -0.12), Vector3(0.05, 1.4, 0.05))  # barrel + receiver
		b.box(&"item_metal", Vector3(x, 0.62, -0.08), Vector3(0.06, 0.18, 0.12))  # magazine
		b.color = Color(0.36, 0.25, 0.15) if i % 3 == 0 else Color(0.18, 0.18, 0.17)
		b.box(&"item_matte", Vector3(x, 0.3, -0.12), Vector3(0.07, 0.4, 0.14))  # stock
	return AABB(Vector3(-len / 2.0, 0, -0.4), Vector3(len, 1.8, 0.45))


static func _sandbags(b: MeshBuilder, len: float, rws: int) -> AABB:
	var bag := Vector3(0.6, 0.18, 0.36)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(len * 100.0) + rws
	for r: int in rws:
		var off: float = 0.0 if r % 2 == 0 else bag.x * 0.5
		var n: int = int((len - off) / bag.x)
		for i: int in n:
			var x: float = -len / 2.0 + off + (i + 0.5) * bag.x
			b.color = SAND.darkened(rng.randf_range(0.0, 0.15))
			b.box(&"item_matte", Vector3(x, (r + 0.5) * bag.y, rng.randf_range(-0.03, 0.03)), bag - Vector3(0.03, 0, 0), 0.07)
	return AABB(Vector3(-len / 2.0, 0, -bag.z / 2.0), Vector3(len, rws * bag.y, bag.z))


static func _map_table(b: MeshBuilder) -> AABB:
	b.color = OLIVE.darkened(0.3)
	b.box(&"item_matte", Vector3(0, 0.45, 0), Vector3(2.4, 0.9, 1.4))
	b.color = Color(0.82, 0.78, 0.62)  # the map
	b.box(&"item_matte", Vector3(0, 0.905, 0), Vector3(2.2, 0.01, 1.2))
	b.color = Color(0.35, 0.55, 0.35)
	for p: Vector3 in [Vector3(-0.5, 0.912, -0.2), Vector3(0.3, 0.912, 0.25), Vector3(0.6, 0.912, -0.3)]:
		b.box(&"item_matte", p, Vector3(0.5, 0.005, 0.35))
	b.color = Color(0.8, 0.15, 0.1)  # pins
	for p: Vector3 in [Vector3(-0.4, 0.95, -0.1), Vector3(0.2, 0.95, 0.3), Vector3(0.7, 0.95, -0.25)]:
		b.box(&"item_matte", p, Vector3(0.04, 0.08, 0.04))
	return AABB(Vector3(-1.2, 0, -0.7), Vector3(2.4, 0.95, 1.4))


static func _radio(b: MeshBuilder) -> AABB:
	b.color = STEEL
	b.box(&"item_metal", Vector3(0, 0.9, 0), Vector3(1.0, 1.8, 0.5))
	for i: int in 4:
		b.color = Color(0.2, 0.24, 0.18)
		b.box(&"item_matte", Vector3(0, 0.3 + i * 0.4, 0.26), Vector3(0.85, 0.3, 0.02))
		b.color = Color(0.9, 0.6, 0.15) if i % 2 == 0 else Color(0.3, 0.9, 0.4)
		b.box(&"item_glossy", Vector3(-0.3, 0.35 + i * 0.4, 0.275), Vector3(0.12, 0.05, 0.01))
	b.color = Color(0.15, 0.15, 0.15)
	b.cylinder(&"item_metal", Vector3(0.35, 1.8, 0), Vector3(0.35, 2.6, 0), 0.01, 0.01, 4)
	return AABB(Vector3(-0.5, 0, -0.25), Vector3(1.0, 1.8, 0.5))


static func _ammo(b: MeshBuilder) -> AABB:
	var rng := RandomNumberGenerator.new()
	rng.seed = 100
	for r: int in 3:
		for i: int in 3 - r:
			b.color = OLIVE.darkened(rng.randf_range(0.0, 0.2))
			var x: float = -0.35 + i * 0.36 + r * 0.18
			b.box(&"item_matte", Vector3(x, 0.14 + r * 0.28, 0), Vector3(0.34, 0.27, 0.5), 0.02)
			b.color = Color(0.9, 0.8, 0.2)
			b.box(&"item_matte", Vector3(x, 0.14 + r * 0.28, 0.251), Vector3(0.2, 0.05, 0.005))
	return AABB(Vector3(-0.55, 0, -0.25), Vector3(1.1, 0.84, 0.5))


static func _lockers(b: MeshBuilder, len: float) -> AABB:
	var n: int = maxi(1, int(len / 0.5))
	var w: float = len / n
	for i: int in n:
		var x: float = -len / 2.0 + (i + 0.5) * w
		b.color = OLIVE.lightened(0.05) if i % 2 == 0 else OLIVE
		b.box(&"item_metal", Vector3(x, 0.95, 0), Vector3(w - 0.02, 1.9, 0.5))
		b.color = Color(0.15, 0.15, 0.15)
		for y: float in [1.6, 1.68, 1.76]:
			b.box(&"item_metal", Vector3(x, y, 0.251), Vector3(w * 0.5, 0.02, 0.005))
		b.box(&"item_metal", Vector3(x + w * 0.3, 1.0, 0.26), Vector3(0.03, 0.15, 0.02))
	return AABB(Vector3(-len / 2.0, 0, -0.25), Vector3(len, 1.9, 0.5))
