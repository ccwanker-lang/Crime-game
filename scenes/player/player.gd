class_name Player
extends CharacterBody3D
## The player character. One per connected peer, spawned by the host through
## World/PlayerSpawner (also replicated to late joiners).
##
## NETWORK: the owning peer moves its own body (responsive, no input lag) and
## sends its state (position, look, movement input, crouch...) through the
## MultiplayerSynchronizer. The HOST validates it: a client that moves faster
## than possible is put back with _teleport(). Damage, items and money (later
## steps) are always decided by the host.
##
## Controls: WASD/arrows move, Shift sprint, Space jump, Ctrl/C crouch, mouse look,
## V first/third person, E interact, Esc frees the mouse (click to capture again).

enum Move { IDLE, FORWARD, BACK, LEFT, RIGHT }

## Quaternius characters for players (CharacterArmature set: idle/walk/run in four
## directions, plus gun animations for step 4). "scale" brings them to ~1.75 m.
const MODELS: Array[Dictionary] = [
	{"model": "hoodie", "scale": 0.94},
	{"model": "worker", "scale": 0.95},
	{"model": "punk", "scale": 0.93},
	{"model": "man_longsleeve", "scale": 0.95},
]
const MODEL_DIR: String = "res://assets/characters/quaternius/%s.glb"

const WALK_SPEED: float = 4.2
const SPRINT_SPEED: float = 6.8
const CROUCH_SPEED: float = 1.9
const JUMP_VELOCITY: float = 4.8
const ACCEL: float = 11.0
const AIR_ACCEL: float = 2.5
const MOUSE_SENSITIVITY: float = 0.0022
const STEP_HEIGHT: float = 0.35
const INTERACT_DISTANCE: float = 3.0

const STAND_HEIGHT: float = 1.8
const CROUCH_HEIGHT: float = 1.15
const EYE_STAND: float = 1.62
const EYE_CROUCH: float = 1.02
const THIRD_PERSON_DISTANCE: float = 3.0
## Ground speed of the run animation at speed_scale 1 (to avoid foot sliding).
const RUN_ANIM_SPEED: float = 4.6
const WALK_ANIM_SPEED: float = 1.25

## Host check: highest horizontal speed accepted from a client (m/s).
const MAX_CLIENT_SPEED: float = SPRINT_SPEED * 1.6

# --- Set at spawn (spawn data, same on every peer) ---------------------------------
var peer_id: int = 1
var player_name: String = ""
var model_index: int = 0

# --- Synced from the owner (MultiplayerSynchronizer) ----------------------------
var net_pos: Vector3 = Vector3.ZERO
var net_yaw: float = 0.0
var net_pitch: float = 0.0
## Movement input in local space (x = right, y = back), length 0..1.
var net_move: Vector2 = Vector2.ZERO
var net_sprint: bool = false
var net_crouch: bool = false
var net_air: bool = false

## Test mode (self-test): walk straight to auto_target without mouse/camera.
var auto_walk: bool = false
var auto_target: Vector3 = Vector3.ZERO

@onready var collision: CollisionShape3D = $Collision
@onready var head: Node3D = $Head
@onready var spring: SpringArm3D = $Head/Spring
@onready var camera: Camera3D = $Head/Spring/Camera3D
@onready var nametag: Label3D = $Nametag
@onready var ui: CanvasLayer = $UI
@onready var prompt_label: Label = %PromptLabel

var third_person: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _crouch_amount: float = 0.0  # 0 standing .. 1 crouched (smoothed, also for remote players)
var _focused: Node = null
var _anim: AnimationPlayer
var _anim_names: Dictionary = {}
var _pose: PoseModifier
var _meshes: Array[MeshInstance3D] = []
var _model: Node3D
# Host-side validation of client movement.
var _check_pos: Vector3 = Vector3.INF
var _check_time: float = 0.0


func _enter_tree() -> void:
	# The owner simulates this body; must be set before the synchronizer starts.
	set_multiplayer_authority(peer_id)
	# HostSync stays with the host: it decides when this player is spawned on a
	# joining client (only once that client's world is loaded, see Net).
	$HostSync.set_multiplayer_authority(1)


func _ready() -> void:
	add_to_group(&"players")
	Net.limit_sync_to_world($Sync)
	Net.limit_sync_to_world($HostSync)
	_build_model()
	nametag.text = player_name
	if is_local():
		net_pos = global_position
		net_yaw = rotation.y
		nametag.visible = false
		spring.add_excluded_object(get_rid())
		if auto_walk:
			ui.visible = false
		else:
			camera.current = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_set_third_person(false)
	else:
		ui.queue_free()
		ui = null
		global_position = net_pos
		rotation.y = net_yaw
	_apply_crouch_shape()


## True on the peer that controls this player.
func is_local() -> bool:
	if auto_walk:
		return true
	return multiplayer.has_multiplayer_peer() and is_multiplayer_authority()


# --- Model -----------------------------------------------------------------------

func _build_model() -> void:
	var v: Dictionary = MODELS[model_index % MODELS.size()]
	_model = (load(MODEL_DIR % v["model"]) as PackedScene).instantiate()
	_model.name = "Model"
	_model.scale = Vector3.ONE * float(v["scale"])
	_model.rotation.y = PI  # the models face +Z, Godot's forward is -Z
	add_child(_model)
	for mi: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		for s: int in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(s) as StandardMaterial3D
			if mat:
				m.set_surface_override_material(s, Pedestrian._matte(mat, -1))
		_meshes.append(m)
	_anim = _model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for a: String in _anim.get_animation_list():
		var short: String = a.get_slice("|", a.get_slice_count("|") - 1)
		if short in ["Idle", "Walk", "Run", "Run_Back", "Run_Left", "Run_Right"]:
			_anim_names[short] = a
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var skeleton: Skeleton3D = _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_pose = PoseModifier.new()
	skeleton.add_child(_pose)
	_anim.play(_anim_names.get("Idle", ""))


## First person: the own body is invisible but still casts a shadow.
func _set_third_person(on: bool) -> void:
	third_person = on
	spring.spring_length = THIRD_PERSON_DISTANCE if on else 0.0
	spring.position = Vector3(0.45, 0.15, 0) if on else Vector3.ZERO
	for m: MeshInstance3D in _meshes:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


# --- Input (owner only) ----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_local() or auto_walk:
		return
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and captured:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * MOUSE_SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x - motion.relative.y * MOUSE_SENSITIVITY, -1.45, 1.45)
	elif event is InputEventMouseButton and event.pressed and not captured:
		# Clicks on HUD buttons never get here (the GUI handles them first).
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("toggle_view") and captured:
		_set_third_person(not third_person)
	elif event.is_action_pressed("interact") and captured and _focused != null:
		_focused.call("interact")


# --- Movement --------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if is_local():
		_local_move(delta)
		net_pos = global_position
		net_yaw = rotation.y
		net_pitch = head.rotation.x
		if not auto_walk:
			_update_focus()
	else:
		_follow_net(delta)
		if multiplayer.is_server():
			_host_validate(delta)
	_update_crouch(delta)
	_update_anim()


func _local_move(delta: float) -> void:
	# Test mode reads the (simulated) actions without a captured mouse.
	var active: bool = auto_walk or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var input := Vector2.ZERO
	if active and not auto_walk:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir: Vector3 = (transform.basis * Vector3(input.x, 0, input.y))
	if auto_walk:
		dir = Vector3(auto_target.x - global_position.x, 0, auto_target.z - global_position.z)
		dir = dir.normalized() if dir.length() > 0.1 else Vector3.ZERO
		input = Vector2(0, -dir.length())

	var want_crouch: bool = active and Input.is_action_pressed("crouch")
	if net_crouch and not want_crouch and not _can_stand():
		want_crouch = true  # something above the head: stay down
	if want_crouch != net_crouch:
		net_crouch = want_crouch
		_apply_crouch_shape()
	net_sprint = active and Input.is_action_pressed("sprint") and not net_crouch and input.y < -0.1

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif active and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	var speed: float = CROUCH_SPEED if net_crouch else (SPRINT_SPEED if net_sprint else WALK_SPEED)
	var target: Vector3 = dir * speed
	var accel: float = ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = move_toward(velocity.x, target.x, accel * speed * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * speed * delta)
	_try_step_up(delta)
	move_and_slide()
	net_move = input
	net_air = not is_on_floor()


## Lets the player walk up curbs and doorsteps: if moving forward is blocked but
## the same move one step higher is free, lift the body; floor snap does the rest.
func _try_step_up(delta: float) -> void:
	if not is_on_floor():
		return
	var motion := Vector3(velocity.x, 0, velocity.z) * delta
	if motion.length() < 0.001 or not test_move(global_transform, motion):
		return
	var raised := global_transform.translated(Vector3.UP * STEP_HEIGHT)
	if test_move(global_transform, Vector3.UP * STEP_HEIGHT) or test_move(raised, motion):
		return
	var hit := KinematicCollision3D.new()
	if test_move(raised.translated(motion.normalized() * 0.1), Vector3.DOWN * STEP_HEIGHT, hit):
		var lift: float = STEP_HEIGHT - hit.get_travel().length()
		if lift > 0.01:
			global_position.y += lift + 0.01


func _can_stand() -> bool:
	return not test_move(global_transform, Vector3.UP * (STAND_HEIGHT - CROUCH_HEIGHT))


## Capsule height follows crouch (the feet stay on the ground).
func _apply_crouch_shape() -> void:
	var capsule := collision.shape as CapsuleShape3D
	var h: float = CROUCH_HEIGHT if net_crouch else STAND_HEIGHT
	capsule.height = h
	collision.position.y = h / 2.0


func _update_crouch(delta: float) -> void:
	_crouch_amount = move_toward(_crouch_amount, 1.0 if net_crouch else 0.0, 5.0 * delta)
	head.position.y = lerpf(EYE_STAND, EYE_CROUCH, _crouch_amount)


## Remote players: smooth towards the last synced state.
func _follow_net(delta: float) -> void:
	if global_position.distance_to(net_pos) > 5.0:
		global_position = net_pos
	else:
		global_position = global_position.lerp(net_pos, minf(1.0, 15.0 * delta))
	rotation.y = lerp_angle(rotation.y, net_yaw, minf(1.0, 15.0 * delta))
	head.rotation.x = lerpf(head.rotation.x, net_pitch, minf(1.0, 15.0 * delta))


# --- Animation (same on every peer, from the synced state) ----------------------

func _update_anim() -> void:
	if _anim == null:
		return
	var move: Vector2 = net_move
	var key: String = "Idle"
	var speed_scale: float = 1.0
	var model_yaw: float = 0.0
	if move.length() > 0.1 and not net_air:
		var ground: float = CROUCH_SPEED if net_crouch else (SPRINT_SPEED if net_sprint else WALK_SPEED)
		ground *= minf(1.0, move.length())
		if net_crouch:
			# Crouch-walk: the walk animation, body turned towards the movement.
			key = "Walk"
			var m: Vector2 = move if move.y <= 0.05 else -move
			model_yaw = clampf(atan2(-m.x, -m.y), -PI / 2.0, PI / 2.0)
			speed_scale = ground / WALK_ANIM_SPEED * (1.0 if move.y <= 0.05 else -1.0)
		else:
			if absf(move.x) > absf(move.y) * 1.2:
				key = "Run_Right" if move.x > 0.0 else "Run_Left"
			elif move.y > 0.0:
				key = "Run_Back"
			else:
				key = "Run"
				model_yaw = clampf(-move.x * 0.6, -0.5, 0.5)
			speed_scale = ground / RUN_ANIM_SPEED
	elif net_air:
		key = "Run"
		speed_scale = 0.25
	var a: String = _anim_names.get(key, _anim_names.get("Idle", ""))
	if _anim.current_animation != a:
		_anim.play(a, 0.2)
	_anim.speed_scale = speed_scale
	_model.rotation.y = lerp_angle(_model.rotation.y, PI + model_yaw, 0.2)
	_pose.crouch = maxf(_crouch_amount, 0.3 if net_air else 0.0)
	_pose.pitch = head.rotation.x


# --- Interaction (owner only) ----------------------------------------------------

func _update_focus() -> void:
	var space := get_world_3d().direct_space_state
	# Always from the eyes, also in third person.
	var from: Vector3 = head.global_position
	var to: Vector3 = from - head.global_basis.z * INTERACT_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2, [get_rid()])
	var hit: Dictionary = space.intersect_ray(query)
	var found: Node = null
	if not hit.is_empty():
		var n: Node = hit["collider"]
		while n != null and not n.is_in_group("interactable"):
			n = n.get_parent()
		found = n
	_focused = found
	if prompt_label:
		prompt_label.text = "[E] %s" % _focused.call("get_interaction_prompt") if _focused else ""


# --- Host validation -------------------------------------------------------------

## Host only: a client that moves faster than possible is put back.
func _host_validate(delta: float) -> void:
	if _check_pos == Vector3.INF:
		_check_pos = net_pos
	_check_time += delta
	if _check_time < 0.5:
		return
	var flat := Vector2(net_pos.x - _check_pos.x, net_pos.z - _check_pos.z)
	if flat.length() / _check_time > MAX_CLIENT_SPEED:
		push_warning("[Player] %s moved too fast (%.1f m/s), corrected" % [player_name, flat.length() / _check_time])
		_teleport.rpc_id(peer_id, _check_pos)
		net_pos = _check_pos
	else:
		_check_pos = net_pos
	_check_time = 0.0


## Host -> owner: put the player at a position (speed check now, respawn later).
@rpc("any_peer", "call_local", "reliable")
func _teleport(pos: Vector3) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return  # only the host may move players
	global_position = pos
	velocity = Vector3.ZERO
	net_pos = pos


## Host: move a player anywhere (e.g. respawn at the hospital in step 4).
func teleport(pos: Vector3) -> void:
	if multiplayer.is_server():
		_check_pos = pos
		if peer_id == multiplayer.get_unique_id():
			_teleport(pos)
		else:
			_teleport.rpc_id(peer_id, pos)
			net_pos = pos
