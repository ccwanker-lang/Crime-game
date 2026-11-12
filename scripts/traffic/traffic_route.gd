class_name TrafficRoute
extends RefCounted
## A closed driving line for AI cars: corner points joined by straight lines,
## each corner rounded with its own radius. Sampled by distance along the line.

const STEP: float = 0.5  # arc sampling (m)

var length: float = 0.0
## Stretches of this route inside a junction: [start, end, junction index].
var junctions: Array[Array] = []
var _points := PackedVector3Array()
var _dist := PackedFloat32Array()  # distance along the line at each point


## corners: Vector2 (x, z) in driving order; radii: one per corner.
func _init(corners: Array[Vector2], radii: Array[float]) -> void:
	var n: int = corners.size()
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
	length = _dist[_dist.size() - 1]


func _add(p: Vector2) -> void:
	var v := Vector3(p.x, 0.0, p.y)
	if _points.size() > 0:
		var seg: float = _points[_points.size() - 1].distance_to(v)
		if seg < 0.001:
			return
		_dist.append(_dist[_dist.size() - 1] + seg)
	else:
		_dist.append(0.0)
	_points.append(v)


## [position: Vector3, direction: Vector3] at distance d (wraps around).
func sample(d: float) -> Array:
	d = fposmod(d, length)
	var lo: int = 0
	var hi: int = _dist.size() - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) / 2
		if _dist[mid] <= d:
			lo = mid
		else:
			hi = mid
	var a: Vector3 = _points[lo]
	var b: Vector3 = _points[hi]
	var seg: float = _dist[hi] - _dist[lo]
	var f: float = (d - _dist[lo]) / seg if seg > 0.0 else 0.0
	return [a.lerp(b, f), (b - a).normalized()]


## Largest heading change (radians) between d and the next `ahead` metres.
func turn_ahead(d: float, ahead: float) -> float:
	var dir0: Vector3 = sample(d)[1]
	var best: float = 0.0
	for k: float in [ahead / 3.0, ahead * 2.0 / 3.0, ahead]:
		best = maxf(best, dir0.angle_to(sample(d + k)[1]))
	return best


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
