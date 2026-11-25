class_name Weather
extends Node
## Point 103: rain and wet streets. The HOST rolls the weather (dry spells of DRY_MIN..DRY_MAX real minutes, showers
## of RAIN_MIN..RAIN_MAX) and tells every peer (`_set_rain` RPC + net_state for late joiners). Every peer then:
## - eases `rain` (0..1) towards the target, and `wetness` (global shader parameter) up while it rains and slowly down
##   after it (the stylized shader darkens and shines up materials with `wet_receiver`, puddles on flat ground);
## - darkens the sky / sun a little and thickens the haze (`DayNight.overcast`);
## - draws rain streaks round the camera (GPUParticles3D, count by `drops_scale` = quality), hidden while the camera
##   is under a roof (one ray up every 0.25 s), so it never rains indoors.
## Node World/Weather; `Weather.current`. Tests: `debug_set(rain, wetness)`; `--weather=rain|dry`.

const DRY_MIN: float = 10.0 * 60.0
const DRY_MAX: float = 25.0 * 60.0
const RAIN_MIN: float = 3.0 * 60.0
const RAIN_MAX: float = 6.0 * 60.0
const RAIN_IN: float = 20.0       # s for the rain to set in / stop
const WET_IN: float = 40.0        # s to get soaked
const DRY_OUT: float = 240.0      # s to dry after the rain
const DROPS: int = 5000           # streaks at drops_scale 1.0
const BOX: Vector3 = Vector3(36.0, 18.0, 36.0)

static var current: Weather = null
## Quality hook (B's QualityProfile): share of DROPS (0 = no rain particles, the streets still get wet).
static var drops_scale: float = 1.0

## Synced target: 1 = raining.
var raining: bool = false
var rain: float = 0.0
var wetness: float = 0.0
var _timer: float = 0.0
var _particles: GPUParticles3D = null
var _roof_t: float = 0.0
var _indoors: bool = false
var _locked: bool = false  # (tests / --weather: no automatic changes)
var _made_for: int = -2  # QualityProfile level the particles were made for


func _ready() -> void:
	current = self
	add_to_group(&"net_state")
	add_to_group(&"weather")
	var rng := RandomNumberGenerator.new()
	_timer = rng.randf_range(DRY_MIN * 0.5, DRY_MAX)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--weather="):
			_locked = true
			raining = arg.trim_prefix("--weather=") == "rain"
			rain = 1.0 if raining else 0.0
			wetness = rain
	if "--selftest" in OS.get_cmdline_user_args() or "--netcheck" in OS.get_cmdline_user_args() \
			or "--perf" in OS.get_cmdline_user_args() or "--screenshot" in OS.get_cmdline_user_args():
		_locked = true  # (deterministic tests and measurements: dry unless a test asks)
	_publish()


func _exit_tree() -> void:
	if current == self:
		current = null
	RenderingServer.global_shader_parameter_set(&"wetness", 0.0)
	DayNight.overcast = 0.0


func _process(delta: float) -> void:
	if multiplayer.is_server() and not _locked:
		_timer -= delta
		if _timer <= 0.0:
			host_set(not raining)
	var target: float = 1.0 if raining else 0.0
	rain = move_toward(rain, target, delta / RAIN_IN)
	if rain > 0.3:
		wetness = minf(1.0, wetness + delta / WET_IN * rain)
	else:
		wetness = maxf(0.0, wetness - delta / DRY_OUT)
	_publish()
	_update_particles(delta)


func _publish() -> void:
	RenderingServer.global_shader_parameter_set(&"wetness", wetness)
	DayNight.overcast = rain


## Host: start / stop the rain now (and roll the next change).
func host_set(on: bool) -> void:
	raining = on
	_timer = randf_range(RAIN_MIN, RAIN_MAX) if on else randf_range(DRY_MIN, DRY_MAX)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		for peer: int in Net.peers_in_world:
			_set_rain.rpc_id(peer, on)


@rpc("authority", "call_remote", "reliable")
func _set_rain(on: bool) -> void:
	raining = on


func get_net_state() -> Dictionary:
	return {"raining": raining, "rain": rain, "wetness": wetness}


func apply_net_state(s: Dictionary) -> void:
	raining = bool(s.get("raining", false))
	rain = float(s.get("rain", 0.0))
	wetness = float(s.get("wetness", 0.0))
	_publish()


## Tests / scenarios: set the weather at once (and keep it).
func debug_set(on: bool, wet: float = -1.0) -> void:
	_locked = true
	raining = on
	rain = 1.0 if on else 0.0
	wetness = wet if wet >= 0.0 else rain
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		for peer: int in Net.peers_in_world:
			_set_rain.rpc_id(peer, on)
	_publish()


func is_indoors() -> bool:
	return _indoors


func _update_particles(delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if rain <= 0.01 or cam == null or drops_scale <= 0.0:
		if _particles:
			_particles.emitting = false
			_particles.visible = false
		return
	if _particles and _made_for != QualityProfile.active:
		_particles.queue_free()
		_particles = null
	if _particles == null:
		_made_for = QualityProfile.active
		_particles = _make_particles()
		add_child(_particles)
	_roof_t -= delta
	if _roof_t <= 0.0:
		_roof_t = 0.25
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + Vector3.UP * 40.0, 1)
		_indoors = not cam.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	_particles.visible = not _indoors
	_particles.emitting = true
	_particles.amount_ratio = rain
	_particles.global_position = cam.global_position + Vector3(0, BOX.y * 0.35, 0) - cam.global_basis.z * 6.0


func _make_particles() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Rain"
	# Quality: Low 35 %, Medium 60 %, High 100 %, Ultra 130 % of DROPS (QualityProfile.active -1 = High).
	var q: float = [0.35, 0.6, 1.0, 1.3][QualityProfile.active] if QualityProfile.active >= 0 else 1.0
	p.amount = maxi(64, roundi(DROPS * drops_scale * q))
	p.lifetime = 1.1
	p.preprocess = 1.0
	p.local_coords = false
	p.visibility_aabb = AABB(-BOX, BOX * 2.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(BOX.x * 0.5, 1.0, BOX.z * 0.5)
	pm.direction = Vector3(0.12, -1.0, 0.05)
	pm.spread = 2.0
	pm.initial_velocity_min = 17.0
	pm.initial_velocity_max = 21.0
	pm.gravity = Vector3(0, -4.0, 0)
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.018, 0.55)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.82, 0.9, 0.35)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y  # (streaks stay upright, face the camera round Y)
	mat.disable_receive_shadows = true
	quad.material = mat
	p.draw_pass_1 = quad
	return p
