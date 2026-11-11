@tool
class_name WeedPlant
extends MeshInstance3D
## Procedural weed plant that grows with `growth` (0 = seedling .. 1 = ready
## to harvest). Stem + pairs of fan-leaf cards per node (rotated 90 degrees per
## node), buds (colas) appear from growth 0.5. Cards use the weed atlas
## (tools/generators/gen_weed_atlas.py). Meshes are cached per seed and growth
## step, so many plants stay cheap. Origin = where the stem leaves the soil.

const STEPS: int = 40  # growth is rounded to this many mesh variants
const MAX_HEIGHT: float = 0.85
const CELL_FAN := Vector2(0.0, 0.0)
const CELL_SMALL := Vector2(0.5, 0.0)
const CELL_BUD := Vector2(0.0, 0.5)

@export_range(0.0, 1.0) var growth: float = 0.5:
	set(v):
		growth = clampf(v, 0.0, 1.0)
		_refresh()
@export var plant_seed: int = 1:
	set(v):
		plant_seed = v
		_refresh()
## 0 = healthy green .. 1 = thirsty (yellowish, used when the pot is dry).
@export_range(0.0, 1.0) var thirst: float = 0.0:
	set(v):
		thirst = v
		_apply_tint()

static var _cache: Dictionary = {}
var _step: int = -1


func _ready() -> void:
	_refresh()
	_apply_tint()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var step: int = roundi(growth * STEPS)
	if step == _step and mesh != null:
		return
	_step = step
	var key: String = "%d:%d" % [plant_seed, step]
	if not _cache.has(key):
		_cache[key] = _build(float(step) / STEPS, plant_seed)
	mesh = _cache[key]


func _apply_tint() -> void:
	var c: Color = Color.WHITE.lerp(Color(1.05, 0.85, 0.45), thirst)
	set_instance_shader_parameter(&"foliage_tint", c)


static func _build(g: float, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var b := MeshBuilder.new()
	var height: float = 0.05 + (MAX_HEIGHT - 0.05) * smoothstep(0.0, 1.0, g)
	var nodes: int = clampi(1 + int(g * 8.0), 1, 8)
	var lean := Vector3(rng.randf_range(-0.03, 0.03), 0, rng.randf_range(-0.03, 0.03)) * height
	var base_angle: float = rng.randf() * TAU
	var bud_amount: float = clampf((g - 0.5) / 0.5, 0.0, 1.0)

	# Main stem (thin, slightly leaning).
	b.color = Color(0, 0, 0)
	var stem_r: float = 0.003 + 0.007 * g
	b.cylinder(&"weed_stem", Vector3.ZERO, Vector3(0, height * 0.97, 0) + lean, stem_r, stem_r * 0.4, 5, false)

	for i: int in nodes:
		var t: float = float(i + 1) / float(nodes + 0.5)  # 0 bottom .. ~1 top
		var at: Vector3 = Vector3(0, height * t, 0) + lean * t
		var from_top: int = nodes - 1 - i
		# Big fan leaves low on the plant, small fresh ones at the top.
		var size: float = (0.06 + 0.26 * g) * (1.0 - 0.4 * t)
		if from_top == 0:
			size *= 0.5
		elif from_top == 1:
			size *= 0.75
		var cell: Vector2 = CELL_SMALL if (from_top <= 1 or g < 0.12) else CELL_FAN
		var tilt: float = lerpf(0.9, -0.2, clampf(g * 1.6 - from_top * 0.12, 0.0, 1.0))
		var ang: float = base_angle + i * PI * 0.5 + rng.randf_range(-0.25, 0.25)
		for side: int in 2:
			var a: float = ang + side * PI + rng.randf_range(-0.2, 0.2)
			_leaf(b, at, a, tilt + rng.randf_range(-0.1, 0.1), size * rng.randf_range(0.85, 1.1), cell)
		# Side branches (Christmas-tree shape): longer low down, each with its own
		# leaves and, when flowering, a bud at the tip.
		if g > 0.25 and from_top >= 1:
			for side: int in 2:
				var a: float = ang + PI * 0.5 + side * PI + rng.randf_range(-0.3, 0.3)
				var length: float = (0.05 + 0.3 * g) * (1.0 - t) + 0.03
				var dir := Vector3(cos(a) * 0.75, 0.66, sin(a) * 0.75).normalized()
				var tip: Vector3 = at + dir * length
				b.color = Color(0.3, 0, 0)
				b.cylinder(&"weed_stem", at, tip, stem_r * 0.55, stem_r * 0.25, 4, false)
				var leaf_size: float = size * 0.8
				_leaf(b, at + dir * length * 0.5, a + 0.9, tilt, leaf_size, CELL_FAN if g > 0.4 else CELL_SMALL)
				_leaf(b, at + dir * length * 0.5, a - 0.9, tilt, leaf_size, CELL_FAN if g > 0.4 else CELL_SMALL)
				_leaf(b, tip, a, tilt + 0.3, leaf_size * 0.6, CELL_SMALL)
				if bud_amount > 0.0:
					_bud(b, tip - Vector3(0, 0.01, 0), (0.03 + 0.07 * bud_amount) * (0.6 + 0.4 * t), rng.randf() * PI)
	# Main cola on top.
	if bud_amount > 0.0:
		_bud(b, Vector3(0, height * 0.82, 0) + lean, 0.06 + 0.17 * bud_amount, rng.randf() * PI)
	return b.build()


## One leaf card: petiole at `at`, pointing outward at angle `a` (radians around
## Y), tilted up by `tilt` radians.
static func _leaf(b: MeshBuilder, at: Vector3, a: float, tilt: float, size: float, cell: Vector2) -> void:
	var out := Vector3(cos(a), 0, sin(a))
	var dir: Vector3 = (out * cos(tilt) + Vector3.UP * sin(tilt)).normalized()
	var side := Vector3(-sin(a), 0, cos(a))
	var normal: Vector3 = side.cross(dir).normalized()
	if normal.y < 0.0:
		normal = -normal
	var h: Vector3 = side * size * 0.5
	var tip: Vector3 = dir * size
	b.color = Color(1, 1, 1)
	var u0: float = cell.x
	var v0: float = cell.y
	b.card(&"weed_leaves", at - h, at + h, at + h + tip, at - h + tip, normal,
			PackedVector2Array([Vector2(u0, v0 + 0.5), Vector2(u0 + 0.5, v0 + 0.5), Vector2(u0 + 0.5, v0), Vector2(u0, v0)]))


## Bud: three crossed vertical cards with the cola texture, base at `at`.
static func _bud(b: MeshBuilder, at: Vector3, height: float, rot: float) -> void:
	var w: float = height * 0.95  # the cola fills ~45% of its cell width
	b.color = Color(0.6, 0.6, 0.6)
	for k: int in 3:
		var a: float = rot + k * PI / 3.0
		var side := Vector3(cos(a), 0, sin(a)) * w * 0.5
		var up := Vector3(0, height, 0)
		var normal := Vector3(-sin(a), 0, cos(a))
		var u0: float = CELL_BUD.x
		var v0: float = CELL_BUD.y
		b.card(&"weed_leaves", at - side, at + side, at + side + up, at - side + up, normal,
				PackedVector2Array([Vector2(u0, v0 + 0.5), Vector2(u0 + 0.5, v0 + 0.5), Vector2(u0 + 0.5, v0), Vector2(u0, v0)]))
