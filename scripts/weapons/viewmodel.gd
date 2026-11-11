class_name Viewmodel
extends Node3D
## First-person arms + weapon, child of the local player's camera.
## The arms are a copy of the player's own character (same sleeves as the
## third-person body). The weapon sits at a fixed spot in front of the camera
## (moved by the procedural animations); ViewmodelIK brings both hands to it.
## Everything that moves here is procedural: bob, mouse sway, recoil kick,
## reload (magazine out/in, slide), draw and holster.
## All meshes use viewmodel.gdshader, so they never poke into walls.

const SHADER: Shader = preload("res://prefabs/materials/shaders/viewmodel.gdshader")
## Weapon grip relative to the camera (x right, y up, -z forward) and its yaw.
const GUN_POS: Vector3 = Vector3(0.13, -0.155, -0.32)
const GUN_YAW: float = 0.14
const GUN_ROLL: float = -0.06
## First-person hands wear dark leather gloves (the bare low-poly hands look
## like pale blobs this close to the camera).
const GLOVE_COLOR: Color = Color(0.07, 0.065, 0.06)
## Middle between the shoulders relative to the camera (just outside the view).
const SHOULDERS: Vector3 = Vector3(0.09, -0.3, 0.04)
const AIM_ANIM: String = "Idle_Gun_Pointing"

var weapon_data: WeaponData
var gun: WeaponModel
## True in third person (the body shows the gun instead) or looking through a scope.
var hidden_by_view: bool = false
var hidden_by_scope: bool = false
## 0..1 aim down sights (set by the player every frame, smoothed here).
var aim_target: float = 0.0

var _aim: float = 0.0
var _pending: WeaponData = null  # weapon to take out once the current one is away
var _want_drawn: bool = true
var _arms_scale: float = 1.0
var _skeleton: Skeleton3D

var _rig: Node3D           # moved by bob / sway / recoil / reload
var _arms: Node3D
var _ik: ViewmodelIK
var _time: float = 0.0
var _sway := Vector2.ZERO  # smoothed mouse motion
var _kick: float = 0.0     # 0..1 recoil, decays
var _reload_t: float = -1.0
var _reload_len: float = 1.6
var _draw: float = 1.0     # 0 = holstered (out of view), 1 = in hand
var _draw_target: float = 1.0
var _sprint: float = 0.0
var _move: float = 0.0
var _air: float = 0.0

static var _material_cache: Dictionary = {}


## model_path: the player's character .glb; model_scale as on the body.
func setup(model_path: String, model_scale: float, data: WeaponData) -> void:
	weapon_data = data
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)

	_arms = (load(model_path) as PackedScene).instantiate()
	_arms.name = "Arms"
	_arms.scale = Vector3.ONE * model_scale
	_arms.rotation.y = PI  # the models face +Z
	add_child(_arms)  # not in the rig: the shoulders stay put, the hands follow the gun
	for mi: Node in _arms.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s: int in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(s) as StandardMaterial3D
			if mat:
				m.set_surface_override_material(s, Pedestrian._matte(mat, -1))
		convert_meshes(m)
		for s: int in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(s) as StandardMaterial3D
			if src and src.resource_name.begins_with("Skin"):
				m.set_surface_override_material(s, _glove_material())
	var anim := _arms.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for a: String in anim.get_animation_list():
		if a.ends_with(AIM_ANIM):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
			anim.play(a)
	anim.advance(0.0)
	var sk := _arms.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D

	_make_gun(data)

	_ik = ViewmodelIK.new()
	_ik.weapon = gun
	_ik.frame = self
	sk.add_child(_ik)

	_arms_scale = model_scale
	_skeleton = sk
	_place_arms()


## Scales the arms for the current weapon and puts the shoulders on SHOULDERS
## (+ the weapon's shoulder shift). Needs to be in the tree.
func _place_arms() -> void:
	var k: float = weapon_data.vm_arm_scale
	_arms.scale = Vector3.ONE * _arms_scale * k
	_arms.position = Vector3.ZERO
	var sk: Skeleton3D = _skeleton
	var mid: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("UpperArm.R")).origin
			+ sk.global_transform * sk.get_bone_global_pose(sk.find_bone("UpperArm.L")).origin) / 2.0
	_arms.position = SHOULDERS + weapon_data.vm_shoulder_shift - to_local(mid)
	_ik.hand_scale = 0.8 / k


func _make_gun(data: WeaponData) -> void:
	weapon_data = data
	gun = data.model_scene.instantiate() as WeaponModel
	_rig.add_child(gun)
	gun.position = _base_pos()
	gun.rotation = Vector3(0, _yaw(), GUN_ROLL)
	gun.make_viewmodel()
	WeaponFX.make_flash(gun.muzzle, true)
	if _ik:
		_ik.weapon = gun


func _yaw() -> float:
	return weapon_data.vm_yaw if weapon_data and weapon_data.vm_yaw >= 0.0 else GUN_YAW


func _base_pos() -> Vector3:
	return GUN_POS + (weapon_data.vm_offset if weapon_data else Vector3.ZERO)


## Puts the current weapon away and takes `data` out.
func switch_to(data: WeaponData) -> void:
	if data == weapon_data and _pending == null:
		set_drawn(true)
		return
	cancel_reload()
	_pending = data
	_want_drawn = true
	_draw_target = 0.0


## Converts every surface of `m` to the viewmodel shader (keeps the PBR inputs).
static func convert_meshes(m: MeshInstance3D) -> void:
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	for s: int in m.mesh.get_surface_count():
		var src: Material = m.get_surface_override_material(s)
		if src == null:
			src = m.mesh.surface_get_material(s)
		m.set_surface_override_material(s, convert_material(src as BaseMaterial3D))


static func _glove_material() -> ShaderMaterial:
	if not _material_cache.has(-1):
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("albedo", GLOVE_COLOR)
		mat.set_shader_parameter("roughness", 0.82)
		_material_cache[-1] = mat
	return _material_cache[-1]


static func convert_material(src: BaseMaterial3D) -> ShaderMaterial:
	var key: int = src.get_instance_id() if src else 0
	if _material_cache.has(key):
		return _material_cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	if src:
		mat.set_shader_parameter("albedo", src.albedo_color)
		if src.albedo_texture:
			mat.set_shader_parameter("albedo_tex", src.albedo_texture)
		mat.set_shader_parameter("roughness", src.roughness)
		mat.set_shader_parameter("metallic", src.metallic)
		if src.normal_enabled and src.normal_texture:
			mat.set_shader_parameter("use_normal", true)
			mat.set_shader_parameter("normal_tex", src.normal_texture)
			mat.set_shader_parameter("normal_strength", src.normal_scale)
		if src is ORMMaterial3D and (src as ORMMaterial3D).orm_texture:
			mat.set_shader_parameter("use_orm", true)
			mat.set_shader_parameter("orm_tex", (src as ORMMaterial3D).orm_texture)
			mat.set_shader_parameter("use_ao", true)
		elif src.roughness_texture:
			mat.set_shader_parameter("use_orm", true)
			mat.set_shader_parameter("orm_tex", src.roughness_texture)
			mat.set_shader_parameter("use_ao", src.ao_enabled)
		mat.set_shader_parameter("uv_scale", Vector2(src.uv1_scale.x, src.uv1_scale.y))
	_material_cache[key] = mat
	return mat


# --- Actions ---------------------------------------------------------------------

func fire(last_round: bool) -> void:
	_kick = 1.0
	gun.cycle(last_round)
	WeaponFX.flash(gun.muzzle)


func reload(duration: float) -> void:
	_reload_len = duration
	_reload_t = 0.0


func is_reloading() -> bool:
	return _reload_t >= 0.0


func cancel_reload() -> void:
	_reload_t = -1.0
	gun.set_magazine(0.0)
	gun.set_slide(0.0)


## Draw (true) or holster (false) the weapon.
func set_drawn(on: bool) -> void:
	_want_drawn = on
	if _pending == null:
		_draw_target = 1.0 if on else 0.0
	if not on:
		cancel_reload()


func is_drawn() -> bool:
	return _draw > 0.99 and _draw_target > 0.5 and _pending == null


func add_mouse(relative: Vector2) -> void:
	_sway += relative * 0.0012


## Ejection port transform (for casings).
func ejection_transform() -> Transform3D:
	return gun.ejection.global_transform


# --- Per frame -------------------------------------------------------------------

## move: horizontal speed 0..1 of sprint, sprinting, on_floor.
func update(delta: float, move: float, sprinting: bool, on_floor: bool) -> void:
	if _rig == null:
		return
	_time += delta
	_move = lerpf(_move, move, minf(1.0, 8.0 * delta))
	_sprint = move_toward(_sprint, 1.0 if sprinting and _reload_t < 0.0 else 0.0, 4.0 * delta)
	_air = move_toward(_air, 0.0 if on_floor else 1.0, 6.0 * delta)
	_draw = move_toward(_draw, _draw_target, 5.0 * delta)
	if _pending != null and _draw <= 0.01:
		gun.queue_free()
		_make_gun(_pending)
		_place_arms()
		_pending = null
		_draw_target = 1.0 if _want_drawn else 0.0
	_aim = move_toward(_aim, aim_target if _reload_t < 0.0 else 0.0, 6.0 * delta)
	_kick = move_toward(_kick, 0.0, 7.0 * delta)
	_sway = _sway.lerp(Vector2.ZERO, minf(1.0, 10.0 * delta))
	visible = _draw > 0.01 and not hidden_by_view and not hidden_by_scope

	# Base pose + bob + sway.
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO
	var bob_speed: float = 7.0 + 4.0 * _sprint
	pos.x += sin(_time * bob_speed * 0.5) * 0.008 * _move
	pos.y += -absf(cos(_time * bob_speed * 0.5)) * 0.01 * _move + _air * 0.02
	rot.y += clampf(-_sway.x, -0.08, 0.08)
	rot.x += clampf(-_sway.y, -0.06, 0.06)
	# Recoil: back, up and a little twist.
	var k: float = _kick * _kick
	pos.z += 0.045 * k
	pos.y += 0.01 * k
	rot.x += 0.16 * k
	rot.z += 0.03 * k
	# Sprint: gun down and turned in.
	pos += Vector3(-0.03, -0.04, 0.02) * _sprint
	rot += Vector3(-0.45, 0.5, 0.2) * _sprint
	# Aim down sights: the sight line (about muzzle height above the grip) to the
	# middle of the screen, less bob and sway.
	var base: Vector3 = _base_pos()
	var sight := gun.get_node_or_null("Sight") as Node3D
	var sight_y: float = sight.position.y if sight else gun.muzzle.position.y + 0.012
	# Long guns sit further out than a real cheek weld, so the receiver does not fill the view.
	var ads_z: float = -0.34 if weapon_data.vm_arm_scale > 1.0 else base.z - 0.04
	var ads := Vector3(0.0, -sight_y - 0.008, ads_z)
	var a: float = smoothstep(0.0, 1.0, _aim)
	gun.position = base.lerp(ads, a)
	gun.rotation = Vector3(0, _yaw() * (1.0 - a), GUN_ROLL * (1.0 - a))
	pos *= 1.0 - 0.7 * a
	rot *= 1.0 - 0.7 * a
	# Draw / holster: from below the screen.
	var d: float = 1.0 - ease(_draw, 0.4)
	pos.y -= 0.32 * d
	rot.x -= 0.9 * d

	var left: Vector3 = Vector3.INF  # support grip
	var left_weight: float = 1.0 - _sprint * 0.7
	if _reload_t >= 0.0:
		var r: Array = _reload_pose(delta)
		pos += r[0]
		rot += r[1]
		left = r[2]
		left_weight = r[3]

	_rig.position = pos
	# Rotate around the grip (not the camera) so the gun tilts in place.
	var pivot: Vector3 = gun.position
	var basis_rot := Basis.from_euler(rot)
	_rig.transform = Transform3D(basis_rot, pos + pivot - basis_rot * pivot)
	_ik.left_target = left
	_ik.left_weight = left_weight


## Reload keyframes (t in seconds, matching pistol_reload.ogg):
## 0.05 mag out, 0.2-0.45 left hand fetches a new one, 0.65 mag in,
## 0.85-1.2 left hand racks the slide, 1.2-1.6 back to aim.
func _reload_pose(delta: float) -> Array:
	_reload_t += delta * 1.6 / _reload_len
	var t: float = _reload_t
	if t >= 1.6:
		cancel_reload()
		return [Vector3.ZERO, Vector3.ZERO, Vector3.INF, 1.0]
	# Whole rig: tilt the gun (roll left, nose up) while working on it.
	var tilt: float = _blend(t, 0.0, 0.2, 1.3, 1.6) * (0.35 if weapon_data.vm_arm_scale > 1.0 else 1.0)
	var pos := Vector3(-0.03, 0.03, 0.02) * tilt
	var rot := Vector3(0.25, 0.1, 0.55) * tilt

	# Magazine: drops out at 0.05-0.25, gone, back in hand 0.35, inserted at 0.65.
	var dir: Vector3 = -gun.magazine_dir.global_basis.y.normalized()
	var mag_base: Vector3 = gun.magazine_dir.global_position
	if t < 0.35:
		var out: float = smoothstep(0.05, 0.3, t) * 0.3
		gun.set_magazine(out, t < 0.28)
	else:
		var out: float = lerpf(0.12, 0.0, smoothstep(0.45, 0.65, t))
		gun.set_magazine(out, true)
	# Slide: pulled back 1.08-1.15, released at 1.18.
	gun.set_slide(smoothstep(1.02, 1.12, t) * (1.0 - smoothstep(1.16, 1.2, t)))

	# Wrist targets of the left hand.
	var support: Vector3 = gun.global_transform * gun.support.position
	var away: Vector3 = mag_base + dir * 0.3 + gun.global_basis.x * -0.12
	var mag_bottom: Vector3 = mag_base + dir * (gun.magazine_out + 0.14)
	var slide_rear: Vector3 = gun.ejection.global_position + gun.global_basis * Vector3(-0.05, 0.0, 0.06)
	var left: Vector3
	if t < 0.15:
		left = support.lerp(away, smoothstep(0.0, 0.15, t))
	elif t < 0.35:
		left = away.lerp(mag_bottom, smoothstep(0.2, 0.35, t))
	elif t < 0.7:
		left = mag_bottom
	elif t < 0.95:
		left = mag_bottom.lerp(slide_rear, smoothstep(0.75, 0.95, t))
	elif t < 1.2:
		left = slide_rear + gun.global_basis.z * 0.028 * smoothstep(1.02, 1.12, t)
	else:
		left = slide_rear.lerp(support, smoothstep(1.2, 1.45, t))
	if t >= 1.45:
		left = Vector3.INF  # back on the grip
	return [pos, rot, left, 1.0]


## 0 before a, ramps to 1 at b, stays until c, back to 0 at d.
static func _blend(t: float, a: float, b: float, c: float, d: float) -> float:
	return smoothstep(a, b, t) * (1.0 - smoothstep(c, d, t))
