class_name FumeHood
extends Station
## Product quality (milestone 3, session B): a steel extraction hood on legs with a duct to the ceiling.
## A cooking station or refinery (ProcessStation.quality_step) within RANGE makes one quality step better
## (Quality). No actions: E only explains it.

const RANGE: float = 2.5
const WIDTH: float = 1.1
const DEPTH: float = 0.6
const HEIGHT: float = 2.1


func default_state() -> Dictionary:
	return {}


func _ready() -> void:
	if not ghost:
		add_to_group(&"fume_hoods")
	super()


func _build() -> void:
	var b := MeshBuilder.new()
	b.collide = true
	var hw: float = WIDTH * 0.5
	var hd: float = DEPTH * 0.5
	for x: float in [-hw + 0.03, hw - 0.03]:
		for z: float in [-hd + 0.03, hd - 0.03]:
			b.box(&"metal_dark", Vector3(x, 0.8, z), Vector3(0.04, 1.6, 0.04))
	b.collide = false
	# Back panel + the hood (a wide box narrowing into the duct).
	b.box(&"zinc", Vector3(0, 1.25, -hd + 0.02), Vector3(WIDTH, 0.9, 0.03))
	b.box(&"zinc", Vector3(0, 1.66, 0), Vector3(WIDTH + 0.06, 0.12, DEPTH + 0.06), 0.006)
	b.box(&"zinc", Vector3(0, 1.8, -0.05), Vector3(WIDTH * 0.7, 0.16, DEPTH * 0.7), 0.006)
	b.cylinder(&"item_metal", Vector3(0, 1.88, -0.05), Vector3(0, HEIGHT + 0.4, -0.05), 0.11, 0.11, 12, true)
	# Grille under the hood.
	for i: int in 6:
		var x: float = -hw + 0.12 + i * (WIDTH - 0.24) / 5.0
		b.box(&"metal_dark", Vector3(x, 1.59, 0), Vector3(0.012, 0.02, DEPTH - 0.08))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	for box: Dictionary in b.collision_boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box["size"]
		cs.shape = shape
		cs.transform = box["xform"]
		add_child(cs)
	# One solid box over the whole footprint for the interact ray / placement.
	var body := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(WIDTH, 1.75, DEPTH)
	body.shape = bs
	body.position.y = 0.875
	add_child(body)


func prompt_for(_player: Player) -> String:
	return "Fume hood: a cooking station or refinery within %.1f m makes better quality" % RANGE


func do_action(_player: Player) -> String:
	var n: int = 0
	for s: Node in get_tree().get_nodes_in_group(&"stations"):
		var ps := s as ProcessStation
		if ps and ps.quality_step and ps.global_position.distance_to(global_position) <= RANGE:
			n += 1
	if n == 0:
		return "No cooking station or refinery close enough (place one within %.1f m)." % RANGE
	return "Venting %d machine%s: +1 quality on every run." % [n, "" if n == 1 else "s"]
