@tool
class_name FlowerBed
extends Node3D
## Bed of soil with a bluestone edge and randomly scattered plants (from
## Poly Haven models). Centred on the node.

const PLANTS: Array[Array] = [
	["res://assets/polyhaven/flower_gazania/flower_gazania.gltf", ["flower_gazania_a_LOD0", "flower_gazania_b_LOD0", "flower_gazania_d_LOD0", "flower_gazania_e_LOD0"], 0.45],
	["res://assets/polyhaven/periwinkle_plant/periwinkle_plant.gltf", ["periwinkle_plant_01_LOD0", "periwinkle_plant_02_LOD0", "periwinkle_plant_03_LOD0", "periwinkle_plant_04_LOD0"], 1.4],
	["res://assets/polyhaven/fern_02/fern_02.gltf", ["fern_02_a", "fern_02_b", "fern_02_d"], 0.8],
]

@export var size: Vector2 = Vector2(3, 1.2):
	set(v): size = v; _queue_rebuild()
@export_range(0.5, 12.0) var plants_per_m2: float = 3.0:
	set(v): plants_per_m2 = v; _queue_rebuild()
@export var bed_seed: int = 1:
	set(v): bed_seed = v; _queue_rebuild()
@export var edge: bool = true:
	set(v): edge = v; _queue_rebuild()

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
	var rng := RandomNumberGenerator.new()
	rng.seed = bed_seed
	var b := MeshBuilder.new()
	var hx: float = size.x / 2.0
	var hz: float = size.y / 2.0
	b.box_mm(&"soil", Vector3(-hx, -0.1, -hz), Vector3(hx, 0.04, hz))
	if edge:
		b.box_mm(&"bluestone", Vector3(-hx - 0.08, -0.1, -hz - 0.08), Vector3(hx + 0.08, 0.1, -hz), 0.01)
		b.box_mm(&"bluestone", Vector3(-hx - 0.08, -0.1, hz), Vector3(hx + 0.08, 0.1, hz + 0.08), 0.01)
		b.box_mm(&"bluestone", Vector3(-hx - 0.08, -0.1, -hz), Vector3(-hx, 0.1, hz), 0.01)
		b.box_mm(&"bluestone", Vector3(hx, -0.1, -hz), Vector3(hx + 0.08, 0.1, hz), 0.01)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	_generated.append(mi)

	var count: int = maxi(1, int(size.x * size.y * plants_per_m2))
	for i: int in count:
		var entry: Array = PLANTS[rng.randi() % PLANTS.size()]
		var names: Array = entry[1]
		var part := ModelPart.new()
		part.model = load(entry[0])
		part.parts = PackedStringArray([names[rng.randi() % names.size()]])
		part.visibility_end = 40.0
		part.cast_shadows = false
		var s: float = entry[2] * rng.randf_range(0.8, 1.2)
		part.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)),
				Vector3(rng.randf_range(-hx + 0.2, hx - 0.2), 0.03, rng.randf_range(-hz + 0.2, hz - 0.2)))
		add_child(part)
		_generated.append(part)
