class_name DayNight
extends Node3D
## Day/night cycle (root of prefabs/environment/sun_and_sky.tscn).
##
## The HOST owns the clock and sends it to the clients every few seconds
## (_sync_time); clients run the same clock in between so the sun moves
## smoothly. Late joiners get it through the world snapshot (group net_state).
##
## One DirectionalLight3D is the sun by day and the moon by night (only one
## shadow-casting light at any time). The sky shader (sky_day_night.gdshader)
## gets the sun/moon directions and a day factor; the global shader parameter
## `night_lights` (0..1) makes windows and lamp glass glow. Street lamps
## (group street_lights) switch on in the evening and off in the morning.

signal lights_changed(on: bool)

## Real minutes for one in-game day (24 h).
@export var day_length_minutes: float = 24.0
## Hour the game starts at (a new game).
@export var start_hour: float = 10.0
## Sunrise / sunset hours (sun on the horizon).
@export var sunrise: float = 6.5
@export var sunset: float = 21.0
## Street lamps switch on / off at these hours.
@export var lights_on_hour: float = 20.25
@export var lights_off_hour: float = 7.0
## Highest sun / moon elevation in degrees.
@export var sun_max_elevation: float = 58.0
@export var moon_max_elevation: float = 40.0

const SYNC_INTERVAL: float = 2.0
## Debug fast-forward speed (F7 held): in-game hours per real second.
const FAST_HOURS_PER_SECOND: float = 2.0

## In-game time in hours, 0..24.
var hours: float = 10.0
## Host: true while someone holds the fast-forward key.
var fast_forward: bool = false

@onready var sun: DirectionalLight3D = $Sun
@onready var world_env: WorldEnvironment = $WorldEnvironment

var _env: Environment
var _sky_mat: ShaderMaterial
var _sync_timer: float = 0.0
var _sky_timer: float = 0.0
var _lights_on: bool = false
var _lights_known: bool = false
var _glow_cache: Dictionary = {}  # source material -> glowing copy
var _base_fog: float = 0.0012
var _cloud_drift: Vector2 = Vector2.ZERO
var _vol_on: bool = false

## Point 103: 0..1 rain cover (set by Weather): a dimmer sun, greyer sky + clouds, thicker haze.
static var overcast: float = 0.0
## Point 103 quality hook (B's QualityProfile: High / Ultra): real volumetric mist at dawn / dusk and in the rain.
## Off = the same mist as plain depth fog (cheaper).
static var volumetric: bool = true
## Ground mist at dawn (strongest) and dusk: extra fog density at full twilight.
const MIST_DENSITY: float = 0.006
const VOL_MIST: float = 0.035
const CLOUD_SPEED: Vector2 = Vector2(0.004, 0.0015)  # cloud-plane units per real second

const DAY_SUN_COLOR := Color(1.0, 0.95, 0.87)
const LOW_SUN_COLOR := Color(1.0, 0.56, 0.3)
const MOON_COLOR := Color(0.55, 0.66, 0.95)
const DAY_FOG := Color(0.72, 0.77, 0.83)
const DUSK_FOG := Color(0.75, 0.55, 0.45)
const NIGHT_FOG := Color(0.04, 0.055, 0.09)
## Point 27 art direction: a warmer sun and a light, clear haze (no grey fog).
const STYLIZED_SUN := Color(1.0, 0.92, 0.8)
const STYLIZED_FOG := Color(0.8, 0.87, 0.94)


func _ready() -> void:
	add_to_group("day_night")
	add_to_group("net_state")
	_env = world_env.environment
	_base_fog = _env.fog_density
	_sky_mat = _env.sky.sky_material as ShaderMaterial
	if _sky_mat:
		_sky_mat.set_shader_parameter("stylized", ArtStyle.stylized)
	hours = start_hour
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--time="):
			hours = fposmod(arg.trim_prefix("--time=").to_float(), 24.0)
	_apply(true)
	# Lamp models (ModelPart) build their meshes in their own _ready, after this
	# one: switch the lamps again once everything is in the tree.
	_refresh_lights.call_deferred()


func _refresh_lights() -> void:
	_lights_known = false
	_apply(false)


func _process(delta: float) -> void:
	var rate: float = 24.0 / maxf(0.1, day_length_minutes * 60.0)
	if fast_forward:
		rate = FAST_HOURS_PER_SECOND
	hours = fposmod(hours + delta * rate, 24.0)
	_sky_timer -= delta
	_cloud_drift += CLOUD_SPEED * delta
	var sky_due: bool = _sky_timer <= 0.0
	if sky_due:
		_sky_timer = 0.1 if fast_forward else 0.5
	_apply(sky_due)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_sync_timer -= delta
		if _sync_timer <= 0.0:
			_sync_timer = 0.25 if fast_forward else SYNC_INTERVAL
			for peer: int in Net.peers_in_world:
				_sync_time.rpc_id(peer, hours, fast_forward)


## In-game hours that pass per real second (stations grow/dry in game hours).
func hours_per_second() -> float:
	return FAST_HOURS_PER_SECOND if fast_forward else 24.0 / maxf(0.1, day_length_minutes * 60.0)


## "HH:MM" of the current in-game time.
func clock_text() -> String:
	var total: int = int(hours * 60.0) % (24 * 60)
	return "%02d:%02d" % [total / 60, total % 60]


func is_night() -> bool:
	return _lights_on


## Debug: set the time (host; clients follow with the next sync).
func set_hours(h: float) -> void:
	hours = fposmod(h, 24.0)
	_sync_timer = 0.0
	_apply(true)


## Debug key: fast-forward while held. Clients ask the host.
func request_fast_forward(on: bool) -> void:
	if multiplayer.is_server():
		fast_forward = on
		_sync_timer = 0.0
	else:
		_request_fast_forward.rpc_id(1, on)


@rpc("any_peer", "call_remote", "reliable")
func _request_fast_forward(on: bool) -> void:
	if multiplayer.is_server():
		fast_forward = on
		_sync_timer = 0.0


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _sync_time(h: float, fast: bool) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	fast_forward = fast
	# Small differences are smoothed out; big jumps (debug) snap.
	var diff: float = wrapf(h - hours, -12.0, 12.0)
	hours = fposmod(hours + (diff if absf(diff) > 0.2 else diff * 0.5), 24.0)


func get_net_state() -> Dictionary:
	return {"h": hours, "f": fast_forward}


func apply_net_state(state: Dictionary) -> void:
	hours = float(state.get("h", hours))
	fast_forward = bool(state.get("f", false))
	_apply(true)


# --- Visuals ---------------------------------------------------------------------

## Direction towards a body that rises in the east (+X) at `rise` and sets in
## the west (-X) at `set_h`, culminating in the south (+Z).
func _arc(rise: float, set_h: float, max_elev_deg: float) -> Vector3:
	var length: float = fposmod(set_h - rise, 24.0)
	var t: float = fposmod(hours - rise, 24.0) / length  # 0..1 while up, > 1 below the horizon
	var a: float = t * PI
	if t > 1.0:
		# Below the horizon: continue the circle underneath.
		var below: float = (t - 1.0) / ((24.0 - length) / length)
		a = PI + below * PI
	var tilt: float = deg_to_rad(max_elev_deg)
	return Vector3(cos(a), sin(a) * sin(tilt), sin(a) * cos(tilt)).normalized()


func _apply(update_sky: bool) -> void:
	var sun_dir: Vector3 = _arc(sunrise, sunset, sun_max_elevation)
	var moon_dir: Vector3 = _arc(sunset + 0.5, sunrise + 24.0 - 0.5, moon_max_elevation)
	var e: float = sun_dir.y
	var day: float = smoothstep(-0.12, 0.12, e)
	var twilight: float = clampf(1.0 - absf(e - 0.02) / 0.22, 0.0, 1.0)

	# One light: the sun while it is (almost) up, otherwise the moon.
	var light_dir: Vector3
	if e > -0.04:
		light_dir = sun_dir
		sun.light_color = LOW_SUN_COLOR.lerp(STYLIZED_SUN if ArtStyle.stylized else DAY_SUN_COLOR, smoothstep(0.0, 0.35, e))
		sun.light_energy = 1.25 * smoothstep(-0.04, 0.12, e) * lerpf(1.0, 0.35, overcast)
	else:
		light_dir = moon_dir
		sun.light_color = MOON_COLOR
		sun.light_energy = 0.16 * smoothstep(-0.02, 0.15, moon_dir.y)
	sun.visible = sun.light_energy > 0.005
	if light_dir.y > -0.2:
		var up: Vector3 = Vector3.UP if absf(light_dir.y) < 0.99 else Vector3.FORWARD
		# Clamp the light a little above the horizon so shadows don't stretch forever.
		var shine: Vector3 = Vector3(light_dir.x, maxf(light_dir.y, 0.08), light_dir.z).normalized()
		sun.global_basis = Basis.looking_at(-shine, up)

	# Environment.
	var sty: bool = ArtStyle.stylized
	_env.ambient_light_energy = lerpf(0.45 if sty else 0.4, 1.05 if sty else 0.9, day)
	_env.tonemap_exposure = lerpf(1.45, 1.0 if sty else 0.95, day)
	var fog: Color = NIGHT_FOG.lerp(DUSK_FOG, twilight * 0.8).lerp(STYLIZED_FOG if sty else DAY_FOG, day * (1.0 - twilight * 0.6))
	_env.fog_light_color = fog
	_env.fog_light_energy = lerpf(0.5, 1.0, day)
	_env.fog_sun_scatter = 0.05 + 0.25 * twilight
	# Point 103: rain cover greys the haze; mist hangs low at dawn (and a little at dusk).
	var grey := Color(0.55, 0.58, 0.62) * lerpf(0.15, 1.0, day)
	_env.fog_light_color = fog.lerp(grey, overcast * 0.7)
	_env.ambient_light_energy *= lerpf(1.0, 0.8, overcast)
	var mist: float = twilight * (1.0 if hours < 12.0 else 0.5)
	# Ground mist on every quality level: depth fog that thickens below a few metres (cheap height fog).
	_env.fog_height = 4.0
	_env.fog_height_density = 0.05 * mist + 0.015 * overcast
	# (Low / Medium quality = depth-fog mist; QualityProfile.active -1 = tests = High.)
	if volumetric and (QualityProfile.active < 0 or QualityProfile.active >= 2):
		_env.fog_density = _base_fog * (1.0 + 1.5 * overcast) + MIST_DENSITY * 0.5 * mist
		var want: bool = mist > 0.05 or overcast > 0.2
		if want != _vol_on:  # (switched only twice a day: a full re-setup of the froxel buffer)
			_vol_on = want
			_env.volumetric_fog_enabled = want
		if want:
			_env.volumetric_fog_density = VOL_MIST * mist + 0.012 * overcast
			_env.volumetric_fog_albedo = _env.fog_light_color
			_env.volumetric_fog_length = 90.0
			_env.volumetric_fog_detail_spread = 2.0
			_env.volumetric_fog_sky_affect = 0.2
	else:
		if _vol_on:
			_vol_on = false
			_env.volumetric_fog_enabled = false
		_env.fog_density = _base_fog * (1.0 + 2.5 * overcast) + MIST_DENSITY * mist

	if update_sky and _sky_mat:
		_sky_mat.set_shader_parameter("sun_dir", sun_dir)
		_sky_mat.set_shader_parameter("moon_dir", moon_dir)
		_sky_mat.set_shader_parameter("day", day)
		_sky_mat.set_shader_parameter("twilight", twilight)
		_sky_mat.set_shader_parameter("overcast", overcast)
		_sky_mat.set_shader_parameter("cloud_offset", _cloud_drift)

	# Lamps and windows.
	var on: bool = _hour_between(hours, lights_on_hour, lights_off_hour)
	# Windows fade in over the evening, out in the morning.
	var glow: float = smoothstep(0.25, -0.08, e)
	RenderingServer.global_shader_parameter_set(&"night_lights", glow)
	if on != _lights_on or not _lights_known:
		_lights_on = on
		_lights_known = true
		_set_street_lights(on)
		lights_changed.emit(on)


static func _hour_between(h: float, from: float, to: float) -> bool:
	if from < to:
		return h >= from and h < to
	return h >= from or h < to


func _set_street_lights(on: bool) -> void:
	for n: Node in get_tree().get_nodes_in_group("street_lights"):
		var light := n as Light3D
		light.visible = on
		# The lamp's glass / bulb glows (materials named *_glass / *_bulb in the model).
		var lamp: Node = light.get_parent()
		for mi: Node in lamp.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			for s: int in m.mesh.get_surface_count():
				var src := m.mesh.surface_get_material(s) as BaseMaterial3D
				if src == null or not (src.resource_name.ends_with("_glass") or src.resource_name.ends_with("_bulb")):
					continue
				m.set_surface_override_material(s, _glow_material(src) if on else null)


func _glow_material(src: BaseMaterial3D) -> BaseMaterial3D:
	if not _glow_cache.has(src):
		var mat := src.duplicate() as BaseMaterial3D
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.8, 0.55)
		mat.emission_energy_multiplier = 6.0 if src.resource_name.ends_with("_bulb") else 2.5
		_glow_cache[src] = mat
	return _glow_cache[src]
