class_name TrafficRoute
extends RefCounted
## A closed driving line for AI cars: corner points joined by straight lines,
## each corner rounded with its own radius (fillet arcs), stored as a smooth
## baked Curve3D (`curve`, also shown as a debug Path3D). Sampled by distance.

const STEP: float = 0.25  # arc sampling (m)

var length: float = 0.0
## Stretches of this route inside a junction: [start, end, junction index].
var junctions: Array[Array] = []
var curve := Curve3D.new()
var _points := PackedVector3Array()
var _dist := PackedFloat32Array()  # distance along the line at each point


## corners: Vector2 (x, z) in driving order; radii: one per corner. (Empty = fill it with from_points.)
func _init(corners: Array[Vector2], radii: Array[float]) -> void:
	var n: int = corners.size()
	if n == 0:
		return
	for i: int in n:
		var prev: Vector2 = corners[(i - 1 + n) % n]
		var c: Vector2 = corners[i]
		var next: Vector2 = corners[(i + 1) % n]
		var d_in: Vector2 = (c - prev).normalized()
		var d_out: Vector2 = (next - c).normalized()
		var r: float = radii[i]
		var turn: float = d_in.angle_to(d_out)  # signed
		if absf(turn) < 0.01 or r <= 0.0:
			_add(c)
			continue
		# Fillet: tangent points at distance t from the corner along both legs.
		var t: float = r * tan(absf(turn) / 2.0)
		var p0: Vector2 = c - d_in * t
		var normal: Vector2 = Vector2(-d_in.y, d_in.x) * signf(turn)  # towards the turn centre
		var centre: Vector2 = p0 + normal * r
		var a0: float = (p0 - centre).angle()
		var steps: int = maxi(2, ceili(absf(turn) * r / STEP))
		for s: int in steps + 1:
			_add(centre + Vector2.from_angle(a0 + turn * float(s) / steps) * r)
	# Close the loop.
	_add(Vector2(_points[0].x, _points[0].z))
	curve.bake_interval = 0.1
	for p: Vector3 in _points:
		curve.add_point(p)
	length = curve.get_baked_length()


## Point 49b: a closed route from dense 3D points (the mountain pass: with heights).
static func from_points(pts: PackedVector3Array) -> TrafficRoute:
	var r := TrafficRoute.new([], [])
	for p: Vector3 in pts:
		r._add3(p)
	r._add3(pts[0])
	r.curve.bake_interval = 0.1
	for p: Vector3 in r._points:
		r.curve.add_point(p)
	r.length = r.curve.get_baked_length()
	return r


func _add(p: Vector2) -> void:
	_add3(Vector3(p.x, 0.0, p.y))


func _add3(v: Vector3) -> void:
	if _points.size() > 0:
		var seg: float = _points[_points.size() - 1].distance_to(v)
		if seg < 0.001:
			return
		_dist.append(_dist[_dist.size() - 1] + seg)
	else:
		_dist.append(0.0)
	_points.append(v)


## [position: Vector3, direction: Vector3] at distance d (wraps around).
## Position from the smooth (cubic) Curve3D; direction = tangent over 1.2 m.
func sample(d: float) -> Array:
	var pos: Vector3 = _at(d)
	var dir: Vector3 = _at(d + 0.6) - _at(d - 0.6)
	return [pos, dir.normalized() if dir.length() > 0.0001 else Vector3.FORWARD]


func _at(d: float) -> Vector3:
	return curve.sample_baked(fposmod(d, length), true)


## Signed curvature at d (1/m; + = bending to the left, seen from above).
func curvature(d: float) -> float:
	var a: Vector3 = sample(d - 1.0)[1]
	var b: Vector3 = sample(d + 1.0)[1]
	var ang: float = Vector2(a.x, a.z).angle_to(Vector2(b.x, b.z))
	return -ang / 2.0


## Finds where this route runs through the junction squares (centre, half size).
## A stretch that runs over the loop start gets a negative start.
func mark_junctions(centres: Array[Vector2], half: float) -> void:
	junctions.clear()
	for j: int in centres.size():
		var found: Array[Array] = []
		var inside: bool = false
		var d: float = 0.0
		while d <= length:
			var p: Vector3 = sample(d)[0]
			var now: bool = absf(p.x - centres[j].x) < half and absf(p.z - centres[j].y) < half
			if now and not inside:
				found.append([d, length, j])
			elif inside and not now:
				found[found.size() - 1][1] = d
			inside = now
			d += 0.25
		if found.size() > 1 and found[0][0] == 0.0 and found[found.size() - 1][1] == length:
			found[0][0] = found[found.size() - 1][0] - length
			found.pop_back()
		junctions.append_array(found)
