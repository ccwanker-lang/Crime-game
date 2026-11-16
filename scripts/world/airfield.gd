class_name Airfield
extends Node3D
## Point 85: the airfield at Fort Halden. One `ProcJet` per `JetHangar*` sibling; every jet runs the same sortie
## over and over: parked in its hangar -> taxi out -> line up -> take off east (climbing clear of the mountains) ->
## away -> approach from the west -> land -> taxi back -> turn and back into the hangar.
## Decoration, local on every peer: the timeline is a pure function of a shared clock (the system time), so all peers
## see the jets at (nearly) the same spot without any network traffic. `clock_offset` shifts it (tests/scenarios).

## Point 91: seconds between two movements (a take-off or a landing) on the whole field; 180-300 = one every
## 3-5 minutes. Every jet's cycle = event_every * 2 * jets; the jets are spread evenly over it and each one lands
## event_every s after its take-off, so the movements come evenly spaced.
@export var event_every: float = 240.0
## The jet sound: full volume within `sound_unit` m, gone beyond `sound_range` m (only audible near the base,
## e.g. once you come over the pass towards it).
@export var sound_unit: float = 30.0
@export var sound_range: float = 650.0
## With rock (or any world geometry) between the camera and the jet the roar drops by this much and gets muffled.
@export var blocked_db: float = -24.0
## Seconds every jet's cycle takes (set from event_every in _ready).
var cycle: float = 1440.0
@export var runway_x0: float = -20.0
@export var runway_x1: float = 230.0
@export var runway_z: float = -425.0
@export var taxi_z: float = -404.0
## The taxiway's links to the runway (west one = line up, east one = exit after landing).
@export var link_x0: float = -8.0
@export var link_x1: float = 215.0

const DT: float = 0.2
const TAXI_SPEED: float = 7.0
const ROTATE_SPEED: float = 62.0
const TAKEOFF_ACCEL: float = 13.0
const TOUCHDOWN_SPEED: float = 66.0
const BRAKE: float = 11.0
const FLY_OUT: float = 2600.0  # metres flown past lift-off before the jet is hidden
const APPROACH: float = 2600.0  # metres before touchdown where it appears again
const CLEARANCE: float = 30.0  # over the mountains
const MAX_DESCENT: float = 0.25  # tan of the steepest glide (~14 deg)
const MAX_CLIMB: float = 0.55  # tan of the steepest climb (~29 deg)

static var clock_offset: float = 0.0
static var current: Airfield

var jets: Array[ProcJet] = []
## Per jet: {"t": PackedFloat32Array, "pos": PackedVector3Array, "rot": PackedVector3Array (pitch, yaw, roll),
## "flags": PackedByteArray (1 gear, 2 burner, 4 visible), "events": {name: time}, "length": float}.
var tracks: Array[Dictionary] = []
var _sounds: Array[AudioStreamPlayer3D] = []
var _bodies: Array[AnimatableBody3D] = []


func _ready() -> void:
	current = self
	var hangars: Array[Node] = get_parent().find_children("JetHangar*", "JetHangar", false, false)
	hangars.sort_custom(func(a: Node, b: Node) -> bool: return (a as Node3D).global_position.x < (b as Node3D).global_position.x)
	cycle = maxf(event_every * 2.0 * maxf(hangars.size(), 1), 330.0)
	for h: Node in hangars:
		var jet := ProcJet.new()
		jet.name = "Jet_%s" % h.name
		add_child(jet)
		jets.append(jet)
		# Solid on the ground (fuselage + wings, layer 2 like cars): no walking through a parked jet.
		var body := AnimatableBody3D.new()
		body.name = "Solid"
		body.collision_layer = 2
		body.collision_mask = 0
		body.sync_to_physics = false  # (follows the jet node directly; the jet teleports when the clock jumps)
		for box: Array in [[Vector3(1.5, 1.5, 15.0), Vector3(0, ProcJet.BODY_Y, 0)], [Vector3(9.6, 0.3, 4.5), Vector3(0, ProcJet.BODY_Y, 1.8)],
				[Vector3(0.3, 2.6, 3.0), Vector3(0, ProcJet.BODY_Y + 1.6, 6.0)]]:
			var cs := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = box[0]
			cs.shape = shape
			cs.position = box[1]
			body.add_child(cs)
		jet.add_child(body)
		_bodies.append(body)
		tracks.append(_build_track(h as JetHangar))
		var snd := AudioStreamPlayer3D.new()
		var stream: AudioStream = load("res://assets/audio/vehicles/jet_loop.ogg") if ResourceLoader.exists("res://assets/audio/vehicles/jet_loop.ogg") else null
		if stream and not DisplayServer.get_name() == "headless":
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = true
			snd.stream = stream
			snd.unit_size = sound_unit
			snd.max_distance = sound_range
			snd.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			snd.position = Vector3(0, 2, 8)
			jet.add_child(snd)
			snd.play()
		_sounds.append(snd)
	_blocked.resize(jets.size())
	_occ_t.resize(jets.size())
	_process(0.0)


func _exit_tree() -> void:
	if current == self:
		current = null


## Per jet: is there rock between the camera and it? (A ray every OCCLUSION_EVERY s.)
var _blocked: Array[bool] = []
var _occ_t: Array[float] = []
const OCCLUSION_EVERY: float = 0.3


func _occlusion_check(i: int, from: Vector3, to: Vector3) -> void:
	while _blocked.size() <= i:
		_blocked.append(false)
		_occ_t.append(0.0)
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _occ_t[i] < OCCLUSION_EVERY:
		return
	_occ_t[i] = now
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [_bodies[i].get_rid()]
	_blocked[i] = not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


static func clock() -> float:
	return Time.get_unix_time_from_system() + clock_offset


## Seconds into jet `i`'s cycle right now.
func phase(i: int) -> float:
	return fposmod(clock() + float(i) * cycle / maxf(jets.size(), 1), cycle)


## Shift the shared clock so jet `i` is `t` seconds into its cycle now (tests / scenarios).
func set_phase(i: int, t: float) -> void:
	clock_offset += t - phase(i)


## Seconds into the cycle at which jet `i` hits `event` ("taxi_out", "line_up", "roll", "lift_off", "gone",
## "appear", "touchdown", "exit", "parked").
func event_time(i: int, event: String) -> float:
	return float((tracks[i]["events"] as Dictionary).get(event, -1.0))


func _process(_delta: float) -> void:
	for i: int in jets.size():
		var s: Dictionary = sample(i, phase(i))
		var jet: ProcJet = jets[i]
		jet.visible = s["visible"]
		var r: Vector3 = s["rot"]
		jet.global_transform = Transform3D(Basis.from_euler(Vector3(r.x, r.y, r.z), EULER_ORDER_YXZ), s["pos"])
		if jet.gear_down != bool(s["gear"]):
			jet.gear_down = s["gear"]
		if jet.burner != bool(s["burner"]):
			jet.burner = s["burner"]
		var solid: bool = s["visible"] and (s["pos"] as Vector3).y < 0.5
		_bodies[i].collision_layer = 2 if solid else 0
		var snd: AudioStreamPlayer3D = _sounds[i]
		if snd.stream:
			# Out of earshot (or hidden): pause the stream instead of mixing it silently.
			var cam: Camera3D = get_viewport().get_camera_3d()
			var far_off: bool = not s["visible"] or cam == null 					or cam.global_position.distance_to(s["pos"]) > sound_range + 50.0
			if snd.stream_paused != far_off:
				snd.stream_paused = far_off
			if not far_off:
				_occlusion_check(i, cam.global_position, (s["pos"] as Vector3) + Vector3.UP * 3.0)
			var speed: float = s["speed"]
			snd.volume_db = -30.0 if not s["visible"] else lerpf(-12.0, 6.0, clampf(speed / 90.0, 0.0, 1.0)) + (4.0 if s["burner"] else 0.0) 					+ (blocked_db if _blocked[i] else 0.0)
			snd.attenuation_filter_cutoff_hz = 900.0 if _blocked[i] else 5000.0
			snd.pitch_scale = lerpf(0.7, 1.25, clampf(speed / 120.0, 0.0, 1.0))


## Jet `i` at `t` seconds into its cycle: {pos, rot, gear, burner, visible, speed}.
func sample(i: int, t: float) -> Dictionary:
	var tr: Dictionary = tracks[i]
	var ts: PackedFloat32Array = tr["t"]
	var pos: PackedVector3Array = tr["pos"]
	var rot: PackedVector3Array = tr["rot"]
	var flags: PackedByteArray = tr["flags"]
	var n: int = ts.size()
	if t <= ts[0]:
		return _at(tr, 0, 0, 0.0)
	if t >= ts[n - 1]:
		return _at(tr, n - 1, n - 1, 0.0)
	var lo: int = 0
	var hi: int = n - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) / 2
		if ts[mid] <= t:
			lo = mid
		else:
			hi = mid
	var f: float = (t - ts[lo]) / maxf(ts[hi] - ts[lo], 0.0001)
	return _at(tr, lo, hi, f)


func _at(tr: Dictionary, a: int, b: int, f: float) -> Dictionary:
	var pos: PackedVector3Array = tr["pos"]
	var rot: PackedVector3Array = tr["rot"]
	var flags: PackedByteArray = tr["flags"]
	var ra: Vector3 = rot[a]
	var rb: Vector3 = rot[b]
	var fl: int = flags[a]
	var ts: PackedFloat32Array = tr["t"]
	var speed: float = pos[a].distance_to(pos[b]) / maxf(ts[b] - ts[a], 0.0001) if b != a else 0.0
	return {"pos": pos[a].lerp(pos[b], f), "rot": Vector3(lerp_angle(ra.x, rb.x, f), lerp_angle(ra.y, rb.y, f),
			lerp_angle(ra.z, rb.z, f)), "gear": fl & 1 != 0, "burner": fl & 2 != 0, "visible": fl & 4 != 0, "speed": speed}


## Ground or mountain height under (x, z).
static func terrain_at(x: float, z: float) -> float:
	return maxf(maxf(Mountain.height_at(x, z), BorderRange.height_at(x, z)), 0.0)


# --- Building one jet's timeline -----------------------------------------------------------------------------

var _b: Dictionary  # the track being built


func _push(p: Vector3, pitch: float, yaw: float, roll: float, flags: int, dt: float = DT) -> void:
	var ts: PackedFloat32Array = _b["t"]
	var t: float = 0.0 if ts.is_empty() else ts[ts.size() - 1] + dt
	ts.append(t)
	_b["t"] = ts
	var pos: PackedVector3Array = _b["pos"]
	pos.append(p)
	_b["pos"] = pos
	var rot: PackedVector3Array = _b["rot"]
	rot.append(Vector3(pitch, yaw, roll))
	_b["rot"] = rot
	var fl: PackedByteArray = _b["flags"]
	fl.append(flags)
	_b["flags"] = fl


func _now() -> float:
	var ts: PackedFloat32Array = _b["t"]
	return ts[ts.size() - 1] if not ts.is_empty() else 0.0


func _last() -> Vector3:
	var pos: PackedVector3Array = _b["pos"]
	return pos[pos.size() - 1]


func _last_yaw() -> float:
	var rot: PackedVector3Array = _b["rot"]
	return rot[rot.size() - 1].y


func _mark(event: String) -> void:
	(_b["events"] as Dictionary)[event] = _now()


static func _yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


## Polyline with rounded corners (quadratic curve over up to `radius` m each side of every inner point).
static func _rounded(pts: Array[Vector3], radius: float) -> Array[Vector3]:
	var out: Array[Vector3] = [pts[0]]
	for i: int in range(1, pts.size() - 1):
		var a: Vector3 = pts[i - 1]
		var c: Vector3 = pts[i]
		var e: Vector3 = pts[i + 1]
		var r: float = minf(radius, minf(a.distance_to(c), c.distance_to(e)) * 0.45)
		var p0: Vector3 = c + (a - c).normalized() * r
		var p2: Vector3 = c + (e - c).normalized() * r
		for k: int in 9:
			var u: float = float(k) / 8.0
			out.append(p0.lerp(c, u).lerp(c.lerp(p2, u), u))
	out.append(pts[pts.size() - 1])
	return out


## Taxi along `pts` at `speed` (nose along the way; `reverse` = backing, nose the other way).
func _taxi(pts: Array[Vector3], speed: float, flags: int, reverse: bool = false) -> void:
	var path: Array[Vector3] = _rounded(pts, 9.0)
	var step: float = speed * DT
	var carry: float = 0.0
	for i: int in range(1, path.size()):
		var a: Vector3 = path[i - 1]
		var c: Vector3 = path[i]
		var seg: float = a.distance_to(c)
		if seg < 0.001:
			continue
		var dir: Vector3 = (c - a) / seg
		var yaw: float = _yaw_of(-dir if reverse else dir)
		var d: float = step - carry
		while d <= seg:
			_push(a + dir * d, 0.0, yaw, 0.0, flags)
			d += step
		carry = seg - (d - step)


## Stand still for `seconds`, optionally turning to `to_yaw`.
func _hold(seconds: float, flags: int, to_yaw: float = INF) -> void:
	var p: Vector3 = _last()
	var y0: float = _last_yaw()
	var y1: float = y0 if to_yaw == INF else to_yaw
	var steps: int = maxi(int(seconds / DT), 1)
	for k: int in steps:
		_push(p, 0.0, lerp_angle(y0, y1, float(k + 1) / steps), 0.0, flags)


## Height profile over x for a straight flight along the runway line: `base(d)` from the anchor, kept CLEARANCE m over
## the mountains, never steeper than `slope` (computed from the far end back to the anchor).
func _profile(x_anchor: float, dir: float, length: float, base: Callable, slope: float) -> PackedFloat32Array:
	var n: int = int(length / 10.0) + 1
	var h := PackedFloat32Array()
	h.resize(n)
	for k: int in n:
		var d: float = k * 10.0
		var x: float = x_anchor + dir * d
		var ground: float = terrain_at(x, runway_z)
		var need: float = ground + CLEARANCE if ground > 2.0 else 0.0
		h[k] = maxf(float(base.call(d)), need)
	for k: int in range(n - 2, 0, -1):
		h[k] = maxf(h[k], h[k + 1] - slope * 10.0)
	h[0] = 0.0
	return h


static func _h_at(h: PackedFloat32Array, d: float) -> float:
	var f: float = clampf(d / 10.0, 0.0, h.size() - 1.001)
	var k: int = int(f)
	return lerpf(h[k], h[k + 1], f - k)


func _build_track(hangar: JetHangar) -> Dictionary:
	_b = {"t": PackedFloat32Array(), "pos": PackedVector3Array(), "rot": PackedVector3Array(), "flags": PackedByteArray(),
			"events": {}}
	const GEAR: int = 1
	const BURN: int = 2
	const VIS: int = 4
	var spot: Vector3 = hangar.jet_spot()
	var front: Vector3 = hangar.global_transform * Vector3(0, 0, -6.0)  # just outside the door
	var out_yaw: float = _yaw_of(front - spot)
	_push(spot, 0.0, out_yaw, 0.0, GEAR | VIS)
	_hold(2.0, GEAR | VIS)
	# Taxi out: through the door, onto the taxiway, west to the link, onto the runway, line up facing east.
	_mark("taxi_out")
	_taxi([spot, front, Vector3(front.x, 0, taxi_z), Vector3(link_x0, 0, taxi_z), Vector3(link_x0, 0, runway_z),
			Vector3(link_x0 + 14.0, 0, runway_z)], TAXI_SPEED, GEAR | VIS)
	_mark("line_up")
	_hold(5.0, GEAR | VIS | BURN, _yaw_of(Vector3.RIGHT))
	# Take-off roll east.
	_mark("roll")
	var x: float = _last().x
	var v: float = 0.0
	var east: float = _yaw_of(Vector3.RIGHT)
	while v < ROTATE_SPEED:
		v += TAKEOFF_ACCEL * DT
		x += v * DT
		_push(Vector3(x, 0, runway_z), 0.0, east, 0.0, GEAR | VIS | BURN)
	_mark("lift_off")
	var x_lift: float = x
	var climb: PackedFloat32Array = _profile(x_lift, 1.0, FLY_OUT, func(d: float) -> float:
		return 0.22 * d * d / (d + 120.0), MAX_CLIMB)
	var d: float = 0.0
	var gear: bool = true
	while d < FLY_OUT:
		v = minf(v + 7.0 * DT, 150.0)
		var dd: float = v * DT
		var h0: float = _h_at(climb, d)
		d += dd
		var h1: float = _h_at(climb, d)
		if d > 260.0:
			gear = false
		_push(Vector3(x_lift + d, h1, runway_z), atan2(h1 - h0, dd), east, 0.0, (GEAR if gear else 0) | VIS | BURN)
	_mark("gone")
	var out_end: Vector3 = _last()
	_push(out_end, 0.0, east, 0.0, 0, 0.05)
	# Away (hidden) until the landing comes event_every s after the take-off (approach time estimated).
	var flown: float = _now() - float((_b["events"] as Dictionary).get("lift_off", _now()))
	_push(out_end, 0.0, east, 0.0, 0, maxf(20.0, event_every - flown - APPROACH / ((TOUCHDOWN_SPEED + 95.0) / 2.0)))
	# Approach from the west along the runway line, touchdown 15 m past the threshold.
	var x_td: float = runway_x0 + 15.0
	var glide: PackedFloat32Array = _profile(x_td, -1.0, APPROACH, func(dist: float) -> float:
		return 0.07 * dist + 0.00002 * dist * dist, MAX_DESCENT)
	d = APPROACH
	v = 95.0
	_push(Vector3(x_td - d, _h_at(glide, d), runway_z), 0.0, east, 0.0, VIS, 0.5)
	_mark("appear")
	while d > 0.0:
		v = lerpf(TOUCHDOWN_SPEED, 95.0, clampf(d / APPROACH, 0.0, 1.0))
		var dd: float = minf(v * DT, d)
		var h0: float = _h_at(glide, d)
		d -= dd
		var h1: float = _h_at(glide, d)
		var flare: float = clampf(1.0 - d / 60.0, 0.0, 1.0)
		_push(Vector3(x_td - d, h1, runway_z), atan2(h1 - h0, dd) * (1.0 - flare) + flare * 0.12, east, 0.0,
				(GEAR if d < 900.0 else 0) | VIS)
	_mark("touchdown")
	x = x_td
	v = TOUCHDOWN_SPEED
	while v > TAXI_SPEED:
		v = maxf(v - BRAKE * DT, TAXI_SPEED)
		x += v * DT
		_push(Vector3(x, 0, runway_z), 0.0, east, 0.0, GEAR | VIS)
	# Off at the east link, west along the taxiway, stop in front of the hangar facing it, turn round, back in.
	_mark("exit")
	var wait_at: Vector3 = hangar.global_transform * Vector3(0, 0, -16.0)
	_taxi([_last(), Vector3(link_x1, 0, runway_z), Vector3(link_x1, 0, taxi_z), Vector3(wait_at.x, 0, taxi_z), wait_at],
			TAXI_SPEED, GEAR | VIS)
	_hold(7.0, GEAR | VIS, out_yaw)
	_taxi([wait_at, spot], 2.0, GEAR | VIS, true)
	_mark("parked")
	# Parked until the cycle starts over.
	var rest: float = cycle - _now()
	if rest > 0.0:
		_push(spot, 0.0, out_yaw, 0.0, GEAR | VIS, rest)
	else:
		push_warning("Airfield: a sortie takes %.0f s, longer than the cycle (%.0f s)" % [_now(), cycle])
	_b["length"] = _now()
	return _b
