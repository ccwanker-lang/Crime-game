class_name VehicleSound
extends Node3D
## Engine, tyre and brake sound of one vehicle (Roadmap 66, session B). LOCAL on every peer: `Ambience` adds one
## to every traffic Car (group "cars") and PlayerCar (group "player_cars"), so the car scripts stay untouched.
## Everything comes from the vehicle's own movement (works the same on the host and on clients, which only get
## smoothed positions): speed -> a simulated gearbox -> rpm -> pitch of two engine loops (engine_on = under load,
## engine_off = coasting / idle), crossfaded by acceleration. Point 94 (A, user feedback "geen piepende banden in
## bochten"): tyres screech ONLY on a real slide - a player car's `net_skid` (handbrake, or turning past its grip) -
## or a panicking traffic car's emergency stop; never just from taking a bend. Brakes squeal now and then when a car
## stops. Only runs within HEAR_RANGE of the camera.

const ENGINE_ON := preload("res://assets/audio/vehicles/engine_on.ogg")
const ENGINE_OFF := preload("res://assets/audio/vehicles/engine_off.ogg")
const SCREECH := preload("res://assets/audio/vehicles/tyre_screech.ogg")
const BRAKE := preload("res://assets/audio/vehicles/brake_squeal.ogg")

## The rpm the engine loops were made at (tools/generators/gen_engine_sounds.py).
const BASE_RPM: float = 1500.0
const IDLE_RPM: float = 800.0
## Top speed (m/s) of each gear.
const GEAR_TOPS: Array[float] = [5.0, 10.0, 16.0, 23.0, 31.0, 60.0]
const HEAR_RANGE: float = 70.0
## Sideways (centripetal) acceleration and braking deceleration (m/s²) where the tyres start to screech.
const SLIDE_ACCEL: float = 7.0
const SLIDE_BRAKE: float = 8.0
const BRAKE_SQUEAL_CHANCE: float = 0.3

static var _looped: bool = false

var vehicle: Node3D
## Player cars are a little louder than traffic; trucks run lower.
var loudness_db: float = -8.0
var pitch_factor: float = 1.0
## Read by tests / the HUD: the current simulated values.
var speed: float = 0.0
var rpm: float = IDLE_RPM
var gear: int = 0
var engine_load: float = 0.0
var slide: float = 0.0
var running: bool = false

var _on: AudioStreamPlayer3D
var _off: AudioStreamPlayer3D
var _tyres: AudioStreamPlayer3D
var _brake: AudioStreamPlayer3D
var _last_pos: Vector3
var _last_yaw: float = 0.0
var _accel: float = 0.0
var _yaw_rate: float = 0.0
var _was_fast: bool = false
var _active: bool = false
var _first: bool = true


func _ready() -> void:
	name = "VehicleSound"
	if not _looped:
		_looped = true
		for s: AudioStreamOggVorbis in [ENGINE_ON, ENGINE_OFF, SCREECH]:
			s.loop = true
	_on = _player(ENGINE_ON)
	_off = _player(ENGINE_OFF)
	_tyres = _player(SCREECH)
	_brake = _player(BRAKE)
	if vehicle is PlayerCar:
		loudness_db = -3.0
	elif vehicle.get("garbage") == true:
		loudness_db = -4.0
		pitch_factor = 0.7


func _player(stream: AudioStream) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.unit_size = 7.0
	p.max_distance = HEAR_RANGE
	p.volume_db = -80.0
	add_child(p)
	return p


## Simulated gearbox: speed (m/s) -> [gear, rpm].
static func rpm_for(v: float) -> Array:
	v = absf(v)
	if v < 0.4:
		return [0, IDLE_RPM]
	var lo: float = 0.0
	for g: int in GEAR_TOPS.size():
		if v <= GEAR_TOPS[g] or g == GEAR_TOPS.size() - 1:
			var r: float = clampf((v - lo) / (GEAR_TOPS[g] - lo), 0.0, 1.0)
			return [g + 1, lerpf(1100.0, 4300.0, r) if g == 0 else lerpf(2300.0, 5200.0, r)]
		lo = GEAR_TOPS[g]
	return [GEAR_TOPS.size(), 5200.0]


## Is the engine on? (wrecks, cars without a driver and empty tanks are silent apart from the tyres)
func engine_on() -> bool:
	if vehicle.get("wrecked") == true:
		return false
	if vehicle is PlayerCar:
		var pc := vehicle as PlayerCar
		return pc.seats.size() > 0 and pc.seats[0] != 0 and pc.fuel > 0.0
	return not (vehicle.get("abandoned") == true and speed < 0.5)


func _physics_process(delta: float) -> void:
	if vehicle == null or not is_instance_valid(vehicle) or delta <= 0.0:
		return
	var pos: Vector3 = vehicle.global_position
	var yaw: float = vehicle.global_rotation.y
	if _first:
		_first = false
		_last_pos = pos
		_last_yaw = yaw
		return
	var flat: Vector3 = pos - _last_pos
	flat.y = 0.0
	var v: float = flat.length() / delta
	if v > 80.0:
		v = speed  # a teleport, not driving
	_accel = lerpf(_accel, (v - speed) / delta, clampf(delta * 6.0, 0.0, 1.0))
	speed = lerpf(speed, v, clampf(delta * 10.0, 0.0, 1.0))
	_yaw_rate = lerpf(_yaw_rate, angle_difference(_last_yaw, yaw) / delta, clampf(delta * 8.0, 0.0, 1.0))
	_last_pos = pos
	_last_yaw = yaw
	var gr: Array = rpm_for(speed)
	gear = int(gr[0])
	rpm = lerpf(rpm, float(gr[1]), clampf(delta * 7.0, 0.0, 1.0))
	engine_load = clampf(_accel / 2.5, 0.0, 1.0) if speed > 0.4 else 0.0
	var skid: Variant = vehicle.get("net_skid")
	if skid != null:  # a player car (or a test stand-in): its own slip value
		slide = lerpf(slide, float(skid), clampf(delta * 10.0, 0.0, 1.0))
	elif float(vehicle.get("panic") if vehicle.get("panic") != null else 0.0) > 0.0 and speed > 4.0:
		slide = clampf((-_accel - SLIDE_BRAKE) / 6.0, 0.0, 1.0)  # an emergency stop in a panic
	else:
		slide = 0.0
	running = engine_on()
	_active = _near()
	if not _active:
		_stop_all()
		return
	_play_engine()
	_play_tyres(delta)
	# Brakes: a car that was moving and stops with a firm deceleration squeals now and then.
	if speed > 2.5:
		_was_fast = true
	elif _was_fast and speed < 1.0:
		_was_fast = false
		if _accel < -1.5 and randf() < BRAKE_SQUEAL_CHANCE and not _brake.playing:
			_brake.volume_db = loudness_db - 6.0
			_brake.pitch_scale = randf_range(0.92, 1.08)
			_brake.play()


func _near() -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam != null and cam.global_position.distance_to(global_position) < HEAR_RANGE


func _play_engine() -> void:
	if not running:
		_on.stop()
		_off.stop()
		return
	var pitch: float = clampf(rpm / BASE_RPM * pitch_factor, 0.3, 4.0)
	_on.pitch_scale = pitch
	_off.pitch_scale = pitch
	# Louder with revs, the "on" loop with load (idle = the soft loop only).
	var revs: float = clampf((rpm - IDLE_RPM) / 4400.0, 0.0, 1.0)
	_on.volume_db = loudness_db + linear_to_db(maxf(0.001, lerpf(0.04, 1.0, engine_load) * lerpf(0.5, 1.0, revs)))
	_off.volume_db = loudness_db + linear_to_db(maxf(0.001, lerpf(0.75, 0.3, engine_load) * lerpf(0.6, 0.9, revs)))
	if not _on.playing:
		_on.play(randf() * 1.9)
	if not _off.playing:
		_off.play(randf() * 1.9)


func _play_tyres(_delta: float) -> void:
	if slide <= 0.02:
		if _tyres.playing:
			_tyres.stop()
		return
	_tyres.volume_db = loudness_db + linear_to_db(slide)
	_tyres.pitch_scale = 0.9 + 0.2 * slide
	if not _tyres.playing:
		_tyres.play(randf() * 1.4)


func _stop_all() -> void:
	for p: AudioStreamPlayer3D in [_on, _off, _tyres]:
		if p.playing:
			p.stop()


## Tests: are the engine loops audible right now?
func is_playing() -> bool:
	return _active and _on.playing and _off.playing
