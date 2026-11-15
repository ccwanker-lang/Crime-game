class_name ShootingRange
extends Node3D
## The shooting range "Hollow Creek Gun Club" (milestone 3, session B; DESIGN "Progression" rank 2). A LOCAL
## visual + collision built in code on every peer (RangeClub adds it to the World at the same path everywhere):
## a covered firing line with LANES lanes, pop-up targets at DISTANCES, an earth berm behind them, and the club hut
## with Walt behind the counter (RangeDesk: E opens the RangeWindow). Local frame: the firing line runs along X at
## z = 0, the shooters face -Z. Game logic (drills, loans, skill) lives in the RangeClub autoload (host).

const LANES: int = 3
const LANE_W: float = 3.4
const DISTANCES: Array[float] = [10.0, 20.0, 32.0]
const BERM_Z: float = -38.0
## The zone where gunfire is legal (local box) - also the area RangeClub.covers() checks.
const ZONE_MIN := Vector3(-8.0, -5.0, -42.0)
const ZONE_MAX := Vector3(8.0, 12.0, 9.0)
const SIGN: String = "HOLLOW CREEK GUN CLUB"

static var current: ShootingRange = null

## targets[lane][i] (i = index in DISTANCES).
var targets: Array = []
var boards: Array[Label3D] = []
var desk: RangeDesk


func _ready() -> void:
	name = "ShootingRange"
	current = self
	_build()


func _exit_tree() -> void:
	if current == self:
		current = null


## Local x of a lane's centre.
static func lane_x(lane: int) -> float:
	return (lane - (LANES - 1) * 0.5) * LANE_W


## World position where a shooter stands on `lane`.
func firing_spot(lane: int) -> Vector3:
	return to_global(Vector3(lane_x(lane), 0.1, 0.6))


func covers(pos: Vector3) -> bool:
	var l: Vector3 = to_local(pos)
	return l.x >= ZONE_MIN.x and l.x <= ZONE_MAX.x and l.y >= ZONE_MIN.y and l.y <= ZONE_MAX.y \
			and l.z >= ZONE_MIN.z and l.z <= ZONE_MAX.z


func target(lane: int, i: int) -> RangeTarget:
	if lane < 0 or lane >= targets.size():
		return null
	var row: Array = targets[lane]
	return row[i] as RangeTarget if i >= 0 and i < row.size() else null


func set_board(lane: int, text: String) -> void:
	if lane >= 0 and lane < boards.size():
		boards[lane].text = text


# --- Building -----------------------------------------------------------------------

func _build() -> void:
	var b := MeshBuilder.new()
	var half_w: float = LANES * LANE_W * 0.5
	# Ground: a concrete slab under the firing line + hut, gravel down the lanes.
	b.box(&"concrete", Vector3(0, 0.05, 3.2), Vector3(half_w * 2.0 + 6.0, 0.1, 7.0))
	b.box(&"soil_dry", Vector3(0, 0.03, (BERM_Z - 0.3) * 0.5), Vector3(half_w * 2.0 + 1.0, 0.06, -BERM_Z + 0.4))
	# The berm behind the targets (+ low earth walls along the sides).
	b.collide = true
	b.box(&"soil", Vector3(0, 2.0, BERM_Z - 1.5), Vector3(half_w * 2.0 + 4.0, 4.0, 3.0), 0.3)
	b.box(&"soil", Vector3(-half_w - 1.2, 0.9, BERM_Z * 0.5 - 1.0), Vector3(1.4, 1.8, -BERM_Z - 4.0), 0.2)
	b.box(&"soil", Vector3(half_w + 1.2, 0.9, BERM_Z * 0.5 - 1.0), Vector3(1.4, 1.8, -BERM_Z - 4.0), 0.2)
	# The covered firing line: posts, a roof, the bench and booth walls between the lanes.
	for x: float in [-half_w, half_w]:
		for z: float in [-0.6, 2.6]:
			b.box(&"planks", Vector3(x, 1.4, z), Vector3(0.16, 2.8, 0.16))
	b.collide = false
	b.box(&"roof_dark", Vector3(0, 2.9, 1.0), Vector3(half_w * 2.0 + 0.8, 0.12, 4.4), 0.02)
	b.collide = true
	b.box(&"planks", Vector3(0, 0.95, -0.5), Vector3(half_w * 2.0, 0.08, 0.5))  # shooting bench
	for lane: int in range(1, LANES):
		b.box(&"planks", Vector3(lane_x(lane) - LANE_W * 0.5, 1.2, 0.4), Vector3(0.06, 2.0, 1.8))
	b.collide = false
	b.color = Color(0.95, 0.85, 0.2)
	b.box(&"item_matte", Vector3(0, 0.065, -0.95), Vector3(half_w * 2.0, 0.01, 0.12))  # the yellow line
	b.color = Color.WHITE
	# Distance markers (posts with a white plate).
	for d: float in DISTANCES:
		for x: float in [-half_w - 0.3, half_w + 0.3]:
			b.box(&"planks", Vector3(x, 0.4, -d), Vector3(0.1, 0.8, 0.1))
			b.box(&"trim_paint", Vector3(x, 0.75, -d + 0.06), Vector3(0.36, 0.22, 0.02))
	# The club hut behind the firing line (left side), open counter towards the lanes.
	var hut := Vector3(-half_w - 3.2, 0.0, 3.6)
	b.collide = true
	b.box(&"planks", hut + Vector3(0, 1.3, 2.0), Vector3(4.4, 2.6, 0.16))
	b.box(&"planks", hut + Vector3(-2.1, 1.3, 0), Vector3(0.16, 2.6, 4.2))
	b.box(&"planks", hut + Vector3(2.1, 1.3, 1.3), Vector3(0.16, 2.6, 1.6))
	b.box(&"planks", hut + Vector3(0, 0.55, -2.0), Vector3(4.4, 1.1, 0.16))
	b.box(&"planks", hut + Vector3(0.0, 1.05, -1.75), Vector3(3.2, 0.08, 0.5))  # the counter top
	b.collide = false
	b.box(&"corrugated", hut + Vector3(0, 2.7, 0), Vector3(4.8, 0.1, 4.6))
	b.box(&"planks", hut + Vector3(-1.6, 1.1, 1.5), Vector3(0.8, 0.06, 0.5))  # gun rack shelf
	for i: int in 4:
		b.box(&"gun_metal", hut + Vector3(-1.9 + i * 0.2, 1.5, 1.82), Vector3(0.06, 0.8, 0.05))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for box: Dictionary in b.collision_boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box["size"]
		cs.shape = shape
		cs.transform = box["xform"]
		body.add_child(cs)
	# Sign over the hut.
	var sign := Label3D.new()
	sign.text = SIGN
	sign.font_size = 72
	sign.pixel_size = 0.006
	sign.outline_size = 14
	sign.modulate = Color(0.96, 0.77, 0.27)
	sign.position = hut + Vector3(0, 3.2, -2.1)
	sign.rotation.y = PI
	add_child(sign)
	# Targets + a scoreboard per lane under the roof.
	targets.clear()
	boards.clear()
	for lane: int in LANES:
		var row: Array = []
		for i: int in DISTANCES.size():
			var t := RangeTarget.new()
			t.lane = lane
			t.index = i
			# Spread the three targets a little across the lane so they never hide each other.
			t.position = Vector3(lane_x(lane) + (i - 1) * 0.9, 0.0, -DISTANCES[i])
			add_child(t)
			row.append(t)
		targets.append(row)
		var board := Label3D.new()
		board.font_size = 40
		board.pixel_size = 0.004
		board.outline_size = 10
		board.position = Vector3(lane_x(lane), 2.45, -1.1)  # (a Label3D reads from +Z: the shooters' side)
		board.text = "Lane %d - free practice" % (lane + 1)
		add_child(board)
		boards.append(board)
	# Walt behind the counter.
	desk = RangeDesk.new()
	desk.position = hut + Vector3(0, 0, -1.2)
	desk.rotation.y = PI
	add_child(desk)
