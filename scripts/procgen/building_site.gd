@tool
class_name BuildingSite
extends StaticBody3D
## Point 102: a building site in place of a tower - a half-built concrete skeleton (slabs on a column grid, bare
## columns with rebar on top), a switchback stair of `ProcStairs` flights so you can climb every floor, scaffolding
## along the front with plank decks, a tower crane whose jib slowly turns (local visual), a site fence with mesh
## panels and a gate gap on the front, containers (site office + store), pallets of bricks, rebar, pipes, a sand
## heap and a concrete mixer. All static geometry is ONE mesh + simple boxes (no lights, no shadows from the small
## props). Markers for session B's builders: BuilderSpot1-6 (meta task), SiteGate, SiteDealSpot (top floor).
## Origin = centre of the plot at ground level; the front (street + gate) faces -Z.

@export var width: float = 24.0:
	set(v): width = v; _queue_rebuild()
@export var depth: float = 20.0:
	set(v): depth = v; _queue_rebuild()
## Finished floors above the ground slab (the level above them is bare columns).
@export var floors_built: int = 3:
	set(v): floors_built = v; _queue_rebuild()
@export var crane: bool = true:
	set(v): crane = v; _queue_rebuild()
@export var site_seed: int = 1:
	set(v): site_seed = v; _queue_rebuild()
## Ground under the site (the city blocks are paved at pavement height 0.15).
@export var base_y: float = 0.15:
	set(v): base_y = v; _queue_rebuild()

const FH: float = 3.4           # floor height
const SLAB: float = 0.25
const COL: float = 0.4          # column size
const BAY: float = 6.0          # column spacing (about)
const FENCE_IN: float = 0.6     # fence inset from the plot edge
const SKEL_IN: float = 4.0      # skeleton inset from the plot edge
const GATE_W: float = 6.0
const STAIR_W: float = 1.3
const STAIR_RUN: float = 5.2
const SCAF_OUT: float = 1.3     # scaffold depth in front of the skeleton
const PROP_RANGE: float = 110.0
const CRANE_RANGE: float = 600.0
const JIB_SPEED: float = 0.05   # rad/s
const YELLOW := Color(0.93, 0.72, 0.12)
const ORANGE := Color(0.9, 0.42, 0.1)
const STEEL := Color(0.45, 0.47, 0.5)
const MESH := Color(0.55, 0.58, 0.6)

var _generated: Array[Node] = []
var _pending: bool = false
var _jib: Node3D = null


func _ready() -> void:
	add_to_group(&"building_sites")
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


func _process(delta: float) -> void:
	if _jib and _jib.is_visible_in_tree():
		_jib.rotation.y = wrapf(_jib.rotation.y + JIB_SPEED * delta, -PI, PI)


## The skeleton's footprint (local XZ), inside the fence.
func skeleton_rect() -> Rect2:
	var hx: float = width / 2.0 - SKEL_IN
	var hz: float = depth / 2.0 - SKEL_IN
	return Rect2(-hx, -hz + SCAF_OUT * 0.5, hx * 2.0, hz * 2.0 - SCAF_OUT * 0.5)


## Height of slab k's walking surface (k 0 = ground slab).
func slab_top(k: int) -> float:
	return base_y + SLAB + FH * k


func top_floor() -> int:
	return floors_built


## Where flight k starts (foot, local) and its yaw: switchback in two lanes at the skeleton's east end.
func flight(k: int) -> Array:
	var r: Rect2 = skeleton_rect()
	var lane_x: float = r.end.x - 0.9 - STAIR_W * (0.5 + float(k % 2))
	var z_south: float = r.end.y - 1.2
	var z_north: float = z_south - STAIR_RUN
	if k % 2 == 0:
		return [Vector3(lane_x, slab_top(k), z_south), 0.0]
	return [Vector3(lane_x, slab_top(k), z_north), PI]


func _rebuild() -> void:
	_pending = false
	for n: Node in _generated:
		n.queue_free()
	_generated.clear()
	_jib = null
	var rng := RandomNumberGenerator.new()
	rng.seed = site_seed * 7919 + 17
	var b := MeshBuilder.new()        # big pieces (skeleton, scaffold, fence): drawn far
	var s := MeshBuilder.new()        # small props: PROP_RANGE
	var boxes: Array = []             # [centre, size]
	_ground(b)
	_skeleton(b, boxes)
	_scaffold(b, boxes)
	_fence(b, boxes)
	_props(s, boxes, rng)
	_add_mesh(b.build(), 0.0, true)
	_add_mesh(s.build(), PROP_RANGE, false)
	for bx: Array in boxes:
		_add_box(bx[0], bx[1])
	_stairs()
	if crane:
		_crane(rng)
	_containers(rng)
	_markers()


func _add_mesh(m: ArrayMesh, range_end: float, shadows: bool) -> void:
	if m.get_surface_count() == 0:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.visibility_range_end = range_end
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_generated.append(mi)


func _add_box(centre: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = centre
	add_child(cs)
	_generated.append(cs)


func _ground(b: MeshBuilder) -> void:
	var hx: float = width / 2.0 - FENCE_IN
	var hz: float = depth / 2.0 - FENCE_IN
	b.color = Color.WHITE
	b.box_mm(&"soil_dry", Vector3(-hx, base_y - 0.05, -hz), Vector3(hx, base_y + 0.02, hz))


func _skeleton(b: MeshBuilder, boxes: Array) -> void:
	var r: Rect2 = skeleton_rect()
	var nx: int = maxi(1, roundi(r.size.x / BAY))
	var nz: int = maxi(1, roundi(r.size.y / BAY))
	var top: int = top_floor()
	b.color = Color.WHITE
	for k: int in top + 1:
		var y: float = slab_top(k)
		# The slab, minus the stair hole of the flight that comes up through it (lane of flight k-1).
		var hole := Rect2()
		if k > 0:
			var f: Array = flight(k - 1)
			var foot: Vector3 = f[0]
			# Open from the flight's top edge (where you step off) to 0.3 m past its foot (headroom).
			var hz0: float = foot.z - STAIR_RUN if f[1] == 0.0 else foot.z - 0.3
			hole = Rect2(foot.x - STAIR_W / 2.0 - 0.05, hz0, STAIR_W + 0.1, STAIR_RUN + 0.3)
		for piece: Rect2 in _cut(r, hole):
			var mn := Vector3(piece.position.x, y - SLAB, piece.position.y)
			var mx := Vector3(piece.end.x, y, piece.end.y)
			b.box_mm(&"concrete", mn, mx)
			boxes.append([(mn + mx) * 0.5, mx - mn])
		if k == 0:
			continue
		# Columns from the slab below up to this one.
		for i: int in nx + 1:
			for j: int in nz + 1:
				var p := Vector3(r.position.x + r.size.x * i / nx, 0, r.position.y + r.size.y * j / nz)
				p.x = clampf(p.x, r.position.x + COL / 2.0, r.end.x - COL / 2.0)
				p.z = clampf(p.z, r.position.y + COL / 2.0, r.end.y - COL / 2.0)
				var y0: float = slab_top(k - 1)
				b.box(&"concrete", Vector3(p.x, (y0 + y - SLAB) / 2.0, p.z), Vector3(COL, y - SLAB - y0, COL))
				boxes.append([Vector3(p.x, (y0 + y - SLAB) / 2.0, p.z), Vector3(COL, y - SLAB - y0, COL)])
		# Edge upstands (a low kerb on the open slab edges) on the upper floors, so it reads as a skeleton.
		b.box_mm(&"concrete", Vector3(r.position.x, y, r.position.y), Vector3(r.end.x, y + 0.15, r.position.y + 0.15))
	# Bare columns + rebar on the top slab (the next floor, unfinished).
	var yt: float = slab_top(top)
	for i: int in nx + 1:
		for j: int in nz + 1:
			var p := Vector3(r.position.x + r.size.x * i / nx, 0, r.position.y + r.size.y * j / nz)
			p.x = clampf(p.x, r.position.x + COL / 2.0, r.end.x - COL / 2.0)
			p.z = clampf(p.z, r.position.y + COL / 2.0, r.end.y - COL / 2.0)
			var h: float = 1.2 if (i + j) % 2 == 0 else 0.4
			b.box(&"concrete", Vector3(p.x, yt + h / 2.0, p.z), Vector3(COL, h, COL))
			boxes.append([Vector3(p.x, yt + h / 2.0, p.z), Vector3(COL, h, COL)])
			b.color = Color(0.45, 0.25, 0.15)
			for c: Vector2 in [Vector2(-0.12, -0.12), Vector2(0.12, -0.12), Vector2(-0.12, 0.12), Vector2(0.12, 0.12)]:
				b.box(&"item_metal", Vector3(p.x + c.x, yt + h + 0.45, p.z + c.y), Vector3(0.03, 0.9, 0.03))
			b.color = Color.WHITE


## Rect r minus the hole (as up to 4 rects).
func _cut(r: Rect2, hole: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if hole.size == Vector2.ZERO or not r.intersects(hole):
		out.append(r)
		return out
	var h: Rect2 = r.intersection(hole)
	if h.position.y > r.position.y:
		out.append(Rect2(r.position.x, r.position.y, r.size.x, h.position.y - r.position.y))
	if h.end.y < r.end.y:
		out.append(Rect2(r.position.x, h.end.y, r.size.x, r.end.y - h.end.y))
	if h.position.x > r.position.x:
		out.append(Rect2(r.position.x, h.position.y, h.position.x - r.position.x, h.size.y))
	if h.end.x < r.end.x:
		out.append(Rect2(h.end.x, h.position.y, r.end.x - h.end.x, h.size.y))
	return out


func _stairs() -> void:
	for k: int in top_floor():
		var f: Array = flight(k)
		var st := ProcStairs.new()
		st.width = STAIR_W
		st.height = FH
		st.run = STAIR_RUN
		st.rails = 1 if k % 2 == 0 else 2
		st.material_key = &"concrete"
		st.position = f[0]
		st.rotation.y = f[1]
		st.name = "Flight%d" % (k + 1)
		add_child(st)
		_generated.append(st)


func _scaffold(b: MeshBuilder, boxes: Array) -> void:
	var r: Rect2 = skeleton_rect()
	var z_in: float = r.position.y - 0.25
	var z_out: float = z_in - SCAF_OUT
	var x0: float = r.position.x
	var x1: float = r.end.x - 2.0 * STAIR_W - 1.2  # (not in front of the stair lanes)
	var top: float = slab_top(top_floor()) + 1.0
	var n: int = maxi(1, ceili((x1 - x0) / 2.5))
	b.color = STEEL
	for i: int in n + 1:
		var x: float = lerpf(x0, x1, float(i) / n)
		for z: float in [z_in, z_out]:
			b.cylinder(&"item_metal", Vector3(x, base_y, z), Vector3(x, top, z), 0.03, 0.03, 5, false)
		if i < n:
			var xn: float = lerpf(x0, x1, float(i + 1) / n)
			var up: bool = i % 2 == 0
			b.cylinder(&"item_metal", Vector3(x, base_y if up else top - 1.0, z_out),
					Vector3(xn, top - 1.0 if up else base_y, z_out), 0.025, 0.025, 4, false)
	for k: int in top_floor() + 1:
		var y: float = slab_top(k)
		for z: float in [z_in, z_out]:
			b.color = STEEL
			b.cylinder(&"item_metal", Vector3(x0, y + 1.0, z), Vector3(x1, y + 1.0, z), 0.025, 0.025, 4, false)
		if k == 0:
			continue
		b.color = Color.WHITE
		var mn := Vector3(x0, y - 0.06, z_out)
		var mx := Vector3(x1, y, z_in)
		b.box_mm(&"planks", mn, mx)
		boxes.append([(mn + mx) * 0.5, mx - mn])
		# Toe board.
		b.color = Color(0.85, 0.6, 0.15)
		b.box_mm(&"planks", Vector3(x0, y, z_out - 0.03), Vector3(x1, y + 0.15, z_out))


func _fence(b: MeshBuilder, boxes: Array) -> void:
	var hx: float = width / 2.0 - FENCE_IN
	var hz: float = depth / 2.0 - FENCE_IN
	var h: float = 2.0
	var y: float = base_y
	var gx: float = -hx + 3.0 + GATE_W / 2.0  # gate centre on the front (west part)
	# [from, to] runs along the edges, front split round the gate.
	var runs: Array = [
		[Vector3(-hx, y, -hz), Vector3(gx - GATE_W / 2.0, y, -hz)],
		[Vector3(gx + GATE_W / 2.0, y, -hz), Vector3(hx, y, -hz)],
		[Vector3(hx, y, -hz), Vector3(hx, y, hz)],
		[Vector3(hx, y, hz), Vector3(-hx, y, hz)],
		[Vector3(-hx, y, hz), Vector3(-hx, y, -hz)]]
	for run: Array in runs:
		var a: Vector3 = run[0]
		var c: Vector3 = run[1]
		var len: float = a.distance_to(c)
		if len < 0.5:
			continue
		var dir: Vector3 = (c - a) / len
		var n: int = maxi(1, ceili(len / 3.5))
		for i: int in n + 1:
			var p: Vector3 = a + dir * (len * i / n)
			b.color = Color(0.55, 0.56, 0.58)
			b.box(&"concrete", p + Vector3(0, 0.1, 0), Vector3(0.6, 0.2, 0.6) if absf(dir.x) < 0.5 else Vector3(0.6, 0.2, 0.6))
			b.color = STEEL
			b.cylinder(&"item_metal", p + Vector3(0, 0.2, 0), p + Vector3(0, h, 0), 0.025, 0.025, 5, false)
			if i < n:
				var q: Vector3 = a + dir * (len * (i + 1) / n)
				for yy: float in [0.25, h - 0.03]:
					b.cylinder(&"item_metal", p + Vector3(0, yy, 0), q + Vector3(0, yy, 0), 0.02, 0.02, 4, false)
		# The mesh: one thin translucent-looking card each side (no alpha: a dark grey grid reads well enough).
		var side: Vector3 = dir.cross(Vector3.UP)
		b.color = MESH
		var p0: Vector3 = a + Vector3(0, 0.25, 0)
		var p1: Vector3 = c + Vector3(0, 0.25, 0)
		var p2: Vector3 = c + Vector3(0, h, 0)
		var p3: Vector3 = a + Vector3(0, h, 0)
		b.quad(&"string", p0, p1, p2, p3, side)
		b.quad(&"string", p1, p0, p3, p2, -side)
		# A green-and-white printed banner on the street side of the front runs.
		if absf(a.z + hz) < 0.01 and absf(c.z + hz) < 0.01 and len > 4.0:
			b.color = Color(0.15, 0.4, 0.3)
			var m: Vector3 = (a + c) / 2.0
			b.box(&"item_matte", m + Vector3(0, 1.15, -0.03), Vector3(minf(len - 1.0, 6.0), 1.0, 0.02))
		var centre: Vector3 = (a + c) / 2.0 + Vector3(0, h / 2.0, 0)
		var size: Vector3 = Vector3(absf(c.x - a.x) + 0.1, h, absf(c.z - a.z) + 0.1)
		boxes.append([centre, size])


func _props(s: MeshBuilder, boxes: Array, rng: RandomNumberGenerator) -> void:
	var hx: float = width / 2.0 - FENCE_IN
	var hz: float = depth / 2.0 - FENCE_IN
	var y: float = base_y
	var r: Rect2 = skeleton_rect()
	# Yard = the strip between fence and skeleton on the west side and the back.
	# Pallets of bricks.
	for i: int in 3:
		var p := Vector3(-hx + 1.0 + i * 1.3, y, hz - 1.2)
		s.color = Color(0.55, 0.42, 0.28)
		s.box(&"planks", p + Vector3(0, 0.07, 0), Vector3(1.1, 0.14, 1.1))
		s.color = Color.WHITE
		var hgt: float = rng.randf_range(0.5, 1.0)
		s.box(&"brick_old", p + Vector3(0, 0.14 + hgt / 2.0, 0), Vector3(1.0, hgt, 1.0))
		boxes.append([p + Vector3(0, (0.14 + hgt) / 2.0, 0), Vector3(1.1, 0.14 + hgt, 1.1)])
	# Rebar bundle on timber bearers.
	var rb := Vector3(-hx + 1.2, y, -hz + 9.0 if depth > 22.0 else 0.0)
	s.color = Color(0.5, 0.4, 0.3)
	for dz: float in [-1.8, 0.0, 1.8]:
		s.box(&"planks", rb + Vector3(0.0, 0.06, dz), Vector3(1.2, 0.12, 0.15))
	s.color = Color(0.45, 0.25, 0.15)
	for i: int in 9:
		var o := Vector3(-0.4 + (i % 5) * 0.2, 0.17 + (i / 5) * 0.06, 0.0)
		s.cylinder(&"item_metal", rb + o + Vector3(0, 0, -2.6), rb + o + Vector3(0, 0, 2.6), 0.025, 0.025, 4, false)
	# Concrete pipes.
	var pp := Vector3(-hx + 2.6, y, rb.z)
	s.color = Color(0.7, 0.7, 0.68)
	for i: int in 2:
		var c: Vector3 = pp + Vector3(0, 0.45, -1.0 + i * 1.6)
		s.cylinder(&"concrete", c + Vector3(-0.0, 0, -0.6), c + Vector3(0, 0, 0.6), 0.45, 0.45, 10, true)
	boxes.append([pp + Vector3(0, 0.45, -0.2), Vector3(0.9, 0.9, 2.8)])
	# Sand heap.
	var sand := Vector3(r.position.x + 2.0, y, hz - 2.2)
	s.color = Color(0.84, 0.74, 0.52)
	s.cylinder(&"soil_dry", sand, sand + Vector3(0, 1.0, 0), 1.6, 0.25, 9, true)
	# The concrete mixer (drum on a frame with two wheels), next to the sand.
	var mx := Vector3(sand.x + 2.4, y, sand.z)
	s.color = ORANGE
	s.box(&"item_matte", mx + Vector3(0, 0.55, 0), Vector3(0.9, 0.1, 0.5))
	s.cylinder(&"item_matte", mx + Vector3(-0.1, 0.65, 0), mx + Vector3(0.35, 1.25, 0), 0.45, 0.42, 10, true)
	s.cylinder(&"item_matte", mx + Vector3(0.35, 1.25, 0), mx + Vector3(0.6, 1.55, 0), 0.42, 0.22, 10, true)
	s.color = Color(0.15, 0.15, 0.16)
	for dz: float in [-0.32, 0.32]:
		s.cylinder(&"car_tire", mx + Vector3(-0.35, 0.22, dz), mx + Vector3(-0.35, 0.22, dz * 1.3), 0.22, 0.22, 10, true)
	s.color = STEEL
	s.box(&"item_metal", mx + Vector3(0.4, 0.27, 0), Vector3(0.05, 0.55, 0.05))
	s.box(&"item_metal", mx + Vector3(0.75, 0.6, 0), Vector3(0.7, 0.04, 0.04))
	boxes.append([mx + Vector3(0.1, 0.75, 0), Vector3(1.2, 1.5, 0.9)])
	# Wheelbarrow + a portable toilet by the gate.
	var wb := Vector3(mx.x + 1.6, y, mx.z - 0.8)
	s.color = Color(0.2, 0.45, 0.25)
	s.box(&"item_matte", wb + Vector3(0, 0.55, 0), Vector3(0.6, 0.3, 0.9))
	s.color = Color(0.15, 0.15, 0.16)
	s.cylinder(&"car_tire", wb + Vector3(-0.06, 0.18, 0.55), wb + Vector3(0.06, 0.18, 0.55), 0.18, 0.18, 8, true)
	var wc := Vector3(-hx + 1.0, y, -hz + 1.0)
	s.color = Color(0.2, 0.38, 0.72)
	s.box(&"item_matte", wc + Vector3(0, 1.15, 0), Vector3(1.1, 2.3, 1.1))
	s.color = Color(0.9, 0.9, 0.9)
	s.box(&"item_matte", wc + Vector3(0, 2.35, 0), Vector3(1.2, 0.1, 1.2))
	boxes.append([wc + Vector3(0, 1.15, 0), Vector3(1.1, 2.3, 1.1)])
	# Site board by the gate (on the fence, street side).
	var gx: float = -hx + 3.0 + GATE_W / 2.0
	var sb := Vector3(gx + GATE_W / 2.0 + 2.2, y, -hz - 0.08)
	s.color = Color(0.95, 0.95, 0.92)
	s.box(&"item_matte", sb + Vector3(0, 1.45, 0), Vector3(2.4, 1.3, 0.04))
	s.color = YELLOW
	s.box(&"item_matte", sb + Vector3(0, 2.0, -0.01), Vector3(2.4, 0.2, 0.04))
	var lbl := Label3D.new()
	lbl.text = ["NEW OFFICES - COMING SOON", "HARBOURVIEW LOFTS", "PHASE 2 - 48 APARTMENTS", "CITY GATE TOWER"][site_seed % 4]
	lbl.font_size = 40
	lbl.pixel_size = 0.004
	lbl.modulate = Color(0.12, 0.2, 0.3)
	lbl.outline_size = 0
	lbl.position = sb + Vector3(0, 1.45, -0.04)
	lbl.rotation.y = PI
	lbl.visibility_range_end = 40.0
	lbl.name = "SiteBoard"
	add_child(lbl)
	_generated.append(lbl)


func _containers(rng: RandomNumberGenerator) -> void:
	var hx: float = width / 2.0 - FENCE_IN
	var hz: float = depth / 2.0 - FENCE_IN
	var scene: PackedScene = load("res://prefabs/props/container_6m.tscn") as PackedScene
	# Site office (white) along the back fence (the yard strip behind the skeleton), on wide plots a green store
	# container next to it.
	var spots: Array = [[Vector3(hx - 4.0, base_y, hz - 1.4), 0.0, Color(0.92, 0.92, 0.88)],
			[Vector3(hx - 10.5, base_y, hz - 1.4), 0.0, Color(0.2, 0.42, 0.25)]]
	if width < 26.0:
		spots.resize(1)
	for i: int in spots.size():
		var c: Node3D = scene.instantiate()
		c.set("color", spots[i][2])
		c.position = spots[i][0]
		c.rotation.y = spots[i][1]
		c.name = "SiteContainer%d" % (i + 1)
		add_child(c)
		_generated.append(c)


func _crane(rng: RandomNumberGenerator) -> void:
	var r: Rect2 = skeleton_rect()
	var base := Vector3(r.position.x - 2.0, base_y, r.end.y + 1.0)  # south-west corner, outside the skeleton
	var mast_h: float = slab_top(top_floor()) + 14.0
	var w: float = 1.6
	var b := MeshBuilder.new()
	b.color = Color(0.6, 0.6, 0.58)
	b.box(&"concrete", base + Vector3(0, 0.3, 0), Vector3(4.0, 0.6, 4.0))
	b.color = YELLOW
	var hw: float = w / 2.0
	var corners: Array[Vector2] = [Vector2(-hw, -hw), Vector2(hw, -hw), Vector2(hw, hw), Vector2(-hw, hw)]
	for c: Vector2 in corners:
		b.box(&"item_matte", base + Vector3(c.x, 0.6 + mast_h / 2.0, c.y), Vector3(0.12, mast_h, 0.12))
	var seg: float = 2.0
	var n: int = ceili(mast_h / seg)
	for i: int in n:
		var y0: float = 0.6 + i * seg
		for f: int in 4:
			var a: Vector2 = corners[f]
			var c2: Vector2 = corners[(f + 1) % 4]
			b.cylinder(&"item_matte", base + Vector3(a.x, y0, a.y), base + Vector3(c2.x, y0, c2.y), 0.035, 0.035, 4, false)
			var lo: Vector2 = a if i % 2 == 0 else c2
			var hi: Vector2 = c2 if i % 2 == 0 else a
			b.cylinder(&"item_matte", base + Vector3(lo.x, y0, lo.y), base + Vector3(hi.x, y0 + seg, hi.y), 0.03, 0.03, 4, false)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	mi.visibility_range_end = CRANE_RANGE
	mi.name = "CraneMast"
	add_child(mi)
	_generated.append(mi)
	_add_box(base + Vector3(0, 0.6 + mast_h / 2.0, 0), Vector3(w, mast_h, w))
	# The slewing part: cab, jib, counter-jib, counterweights, trolley + hook. Turns slowly (local, visual only).
	var jib := Node3D.new()
	jib.name = "CraneJib"
	jib.position = base + Vector3(0, 0.6 + mast_h, 0)
	jib.rotation.y = rng.randf_range(-PI, PI)
	add_child(jib)
	_generated.append(jib)
	var j := MeshBuilder.new()
	var jl: float = clampf(maxf(width, depth) + 6.0, 24.0, 40.0)
	var cl: float = jl * 0.32
	j.color = YELLOW
	j.box(&"item_matte", Vector3(0, 0.3, 0), Vector3(w + 0.4, 0.6, w + 0.4))  # slewing ring
	# Jib: two bottom chords + one top chord, zig-zag lacing (along +X), counter-jib along -X.
	for side: float in [-1.0, 1.0]:
		j.box(&"item_matte", Vector3(jl / 2.0, 0.7, side * 0.55), Vector3(jl, 0.1, 0.1))
		j.box(&"item_matte", Vector3(-cl / 2.0, 0.7, side * 0.7), Vector3(cl, 0.16, 0.12))
	j.box(&"item_matte", Vector3(jl / 2.0, 1.9, 0), Vector3(jl, 0.1, 0.1))
	var steps: int = ceili(jl / 1.6)
	for i: int in steps:
		var x0: float = jl * i / steps
		var x1: float = jl * (i + 1) / steps
		for side: float in [-1.0, 1.0]:
			j.cylinder(&"item_matte", Vector3(x0, 0.7, side * 0.55), Vector3((x0 + x1) / 2.0, 1.9, 0), 0.03, 0.03, 4, false)
			j.cylinder(&"item_matte", Vector3((x0 + x1) / 2.0, 1.9, 0), Vector3(x1, 0.7, side * 0.55), 0.03, 0.03, 4, false)
	# Tower head (A-frame) + pendant ties.
	j.box(&"item_matte", Vector3(0, 3.2, 0), Vector3(0.5, 5.2, 0.5))
	j.color = STEEL
	j.cylinder(&"item_metal", Vector3(0, 5.6, 0), Vector3(jl * 0.65, 1.95, 0), 0.025, 0.025, 4, false)
	j.cylinder(&"item_metal", Vector3(0, 5.6, 0), Vector3(-cl * 0.9, 0.8, 0), 0.025, 0.025, 4, false)
	# Counterweights + walkway.
	j.color = Color(0.62, 0.62, 0.6)
	j.box(&"concrete", Vector3(-cl + 1.2, 0.0, 0), Vector3(2.0, 1.6, 1.6))
	j.color = Color(0.3, 0.3, 0.32)
	j.box(&"item_metal", Vector3(-cl / 2.0 + 0.6, 0.66, 0), Vector3(cl - 1.6, 0.04, 1.2))
	# Cab on the side of the ring.
	j.color = Color(0.92, 0.92, 0.9)
	j.box(&"item_matte", Vector3(0.6, -0.4, 1.4), Vector3(1.5, 1.8, 1.2))
	j.color = Color(0.35, 0.55, 0.7)
	j.box(&"glass_clear", Vector3(1.36, -0.25, 1.4), Vector3(0.04, 1.0, 1.0))
	# Trolley + cable + hook block hanging over the site.
	var tx: float = jl * rng.randf_range(0.35, 0.7)
	var drop: float = rng.randf_range(6.0, mast_h - 4.0)
	j.color = Color(0.25, 0.25, 0.27)
	j.box(&"item_metal", Vector3(tx, 0.55, 0), Vector3(0.9, 0.25, 1.2))
	j.cylinder(&"item_metal", Vector3(tx, 0.4, 0), Vector3(tx, 0.4 - drop, 0), 0.02, 0.02, 4, false)
	j.color = ORANGE
	j.box(&"item_matte", Vector3(tx, 0.1 - drop, 0), Vector3(0.45, 0.6, 0.3))
	j.color = STEEL
	j.cylinder(&"item_metal", Vector3(tx, -0.2 - drop, 0), Vector3(tx, -0.55 - drop, 0), 0.05, 0.02, 6, true)
	var jm := MeshInstance3D.new()
	jm.mesh = j.build()
	jm.visibility_range_end = CRANE_RANGE
	jib.add_child(jm)
	if not Engine.is_editor_hint():
		_jib = jib


func _markers() -> void:
	var r: Rect2 = skeleton_rect()
	var hx: float = width / 2.0 - FENCE_IN
	var hz: float = depth / 2.0 - FENCE_IN
	var gx: float = -hx + 3.0 + GATE_W / 2.0
	var y: float = base_y + 0.05
	var spots: Array = [
		["BuilderSpot1", Vector3(r.position.x + 4.8, y, hz - 2.2), "mixer"],
		["BuilderSpot2", Vector3(-hx + 2.3, y, hz - 2.4), "bricks"],
		["BuilderSpot3", Vector3(r.position.x + 2.5, slab_top(1) + 0.05, r.position.y - 0.9), "scaffold"],
		["BuilderSpot4", Vector3(r.get_center().x, slab_top(top_floor()) + 0.05, r.get_center().y), "upper"],
		["BuilderSpot5", Vector3(r.get_center().x - 2.0, slab_top(1) + 0.05, r.get_center().y + 1.0), "floor"],
		["BuilderSpot6", Vector3(hx - 4.0, y, hz - 2.9), "office"],
		["SiteGate", Vector3(gx, y, -hz + 0.5), ""],
		["SiteDealSpot", Vector3(r.position.x + 1.5, slab_top(top_floor()) + 0.05, r.end.y - 1.5), ""]]
	for sp: Array in spots:
		var m := Marker3D.new()
		m.name = sp[0]
		m.position = sp[1]
		if sp[2] != "":
			m.set_meta(&"task", sp[2])
		add_child(m)
		_generated.append(m)
