class_name Player
extends CharacterBody3D
## The player character. One per connected peer, spawned by the host through
## World/PlayerSpawner (also replicated to late joiners).
##
## NETWORK: the owning peer moves its own body (responsive, no input lag) and
## sends its state (position, look, movement input, crouch, weapon out...)
## through the MultiplayerSynchronizer. The HOST validates it: a client that
## moves faster than possible is put back with _teleport(). Health, death,
## damage, ammo and money are decided by the host (HostSync replicates health
## and dead; shooting lives in the Combat child, see PlayerCombat).
##
## Death: the host drops a LootBag with the player's cash + carried items and
## respawns the player at the hospital after RESPAWN_TIME.
##
## Controls: WASD/arrows move, Shift sprint, Space jump, Ctrl/C crouch, mouse look,
## LMB shoot, R reload, 1 pistol / 2 holster / Q switch, V first/third person,
## E interact, Esc frees the mouse (click to capture again), F4 debug: hurt yourself.

enum Move { IDLE, FORWARD, BACK, LEFT, RIGHT }

## Quaternius characters for players (CharacterArmature set: idle/walk/run in four
## directions, gun aim/shoot, death). "scale" brings them to ~1.75 m.
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

const MAX_HEALTH: int = 100
const RESPAWN_TIME: float = 5.0
const DEBUG_HURT: int = 25

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
## Weapon in hand: 0 = none (holstered), 1 = pistol.
var net_weapon: int = 1

# --- Synced from the host (HostSync) --------------------------------------------
var health: int = MAX_HEALTH:
	set(v):
		var old: int = health
		health = v
		_on_health_changed(old)
var dead: bool = false:
	set(v):
		if v != dead:
			dead = v
			_on_dead_changed()

## Test mode (self-test): walk straight to auto_target without mouse/camera.
var auto_walk: bool = false
var auto_target: Vector3 = Vector3.ZERO

@onready var collision: CollisionShape3D = $Collision
@onready var head: Node3D = $Head
@onready var spring: SpringArm3D = $Head/Spring
@onready var camera: Camera3D = $Head/Spring/Camera3D
@onready var nametag: Label3D = $Nametag
@onready var ui: PlayerHUD = $UI
@onready var prompt_label: Label = %PromptLabel
@onready var combat: PlayerCombat = $Combat

var third_person: bool = false
var cash: int = 0  # owner: last value sent by the host
## Owner: carried item stacks [{ "id", "count" }], last list sent by the host.
var inventory: Array = []
## Owner: the shop window that is open (null = none).
var shop: Shopkeeper = null

signal wallet_changed
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _crouch_amount: float = 0.0  # 0 standing .. 1 crouched (smoothed, also for remote players)
var _focused: Node = null
var _anim: AnimationPlayer
var _anim_names: Dictionary = {}
var _pose: PoseModifier
var _skeleton: Skeleton3D
var _bone_lower_r: int = -1
var _bone_wrist_r: int = -1
var _meshes: Array[MeshInstance3D] = []
var _model: Node3D
var _recoil_pending: float = 0.0  # camera pitch still to recover from recoil
var _view_before_death: bool = false
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
		var vm := Viewmodel.new()
		vm.name = "Viewmodel"
		camera.add_child(vm)
		var v: Dictionary = MODELS[model_index % MODELS.size()]
		vm.setup(MODEL_DIR % v["model"], float(v["scale"]), combat.weapon)
		combat.viewmodel = vm
		if auto_walk:
			ui.visible = false
		else:
			camera.current = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_set_third_person(false)
		ui.set_health(health, MAX_HEALTH)
		if multiplayer.is_server():
			send_wallet()
		else:
			_request_wallet.rpc_id(1)
	else:
		ui.queue_free()
		ui = null
		global_position = net_pos
		rotation.y = net_yaw
	_apply_crouch_shape()
	if dead:
		_on_dead_changed()  # late joiner sees a dead player lying down


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
	var aim_anim: Animation = null
	for a: String in _anim.get_animation_list():
		var short: String = a.get_slice("|", a.get_slice_count("|") - 1)
		if short in ["Idle", "Walk", "Run", "Run_Back", "Run_Left", "Run_Right"]:
			_anim_names[short] = a
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		elif short == "Death":
			_anim_names[short] = a
			_anim.get_animation(a).loop_mode = Animation.LOOP_NONE
		elif short == "Idle_Gun_Pointing":
			aim_anim = _anim.get_animation(a)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_pose = PoseModifier.new()
	_skeleton.add_child(_pose)
	if aim_anim:
		_pose.set_aim_pose(aim_anim, 0.3)
	_anim.play(_anim_names.get("Idle", ""))

	# Pistol in the right fist, placed after every skeleton update.
	combat.hand_gun = combat.weapon.model_scene.instantiate() as WeaponModel
	combat.hand_gun.name = "HandGun"
	add_child(combat.hand_gun)
	WeaponFX.make_flash(combat.hand_gun.muzzle, false)
	_bone_lower_r = _skeleton.find_bone("LowerArm.R")
	_bone_wrist_r = _skeleton.find_bone("Wrist.R")
	_skeleton.skeleton_updated.connect(_place_hand_gun)


func _place_hand_gun() -> void:
	var gun: WeaponModel = combat.hand_gun
	gun.visible = net_weapon != 0 and not dead
	# The skeleton can still update while the player leaves the tree (disconnect).
	if not gun.visible or _bone_wrist_r < 0 or not is_inside_tree():
		return
	var t: Transform3D = _skeleton.global_transform
	var lower: Vector3 = t * _skeleton.get_bone_global_pose(_bone_lower_r).origin
	var wrist: Vector3 = t * _skeleton.get_bone_global_pose(_bone_wrist_r).origin
	gun.global_transform = ViewmodelIK.gun_in_fist(lower, wrist, global_basis.y)


## First person: the own body (and the gun in its hand) is invisible but still
## casts a shadow; the viewmodel shows the arms instead.
func _set_third_person(on: bool) -> void:
	third_person = on
	spring.spring_length = THIRD_PERSON_DISTANCE if on else 0.0
	spring.position = Vector3(0.45, 0.15, 0) if on else Vector3.ZERO
	var mode: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for m: MeshInstance3D in _meshes:
		m.cast_shadow = mode
	for m: Node in combat.hand_gun.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = mode
	if combat.viewmodel:
		combat.viewmodel.hidden_by_view = on


# --- Input (owner only) ----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_local() or auto_walk:
		return
	if shop != null:
		# Shop window open: the mouse is free for its buttons; E or Esc leaves.
		if event.is_action_pressed("release_mouse") or event.is_action_pressed("interact"):
			close_shop()
			get_viewport().set_input_as_handled()
		return
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and captured:
		if dead:
			return
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * MOUSE_SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x - motion.relative.y * MOUSE_SENSITIVITY, -1.45, 1.45)
		if combat.viewmodel:
			combat.viewmodel.add_mouse(motion.relative)
	elif event is InputEventMouseButton and event.pressed and not captured:
		# Clicks on HUD buttons never get here (the GUI handles them first).
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not captured:
		return
	elif event.is_action_pressed("fire"):
		combat.try_fire()
	elif event.is_action_pressed("reload"):
		combat.try_reload()
	elif event.is_action_pressed("weapon_1"):
		combat.set_equipped(true)
	elif event.is_action_pressed("weapon_holster"):
		combat.set_equipped(false)
	elif event.is_action_pressed("weapon_toggle"):
		combat.set_equipped(not combat.equipped)
	elif event.is_action_pressed("toggle_view") and not dead:
		_set_third_person(not third_person)
	elif event.is_action_pressed("interact") and _focused != null and not dead:
		_focused.call("interact")
	elif event is InputEventKey and not event.echo and (event as InputEventKey).physical_keycode == KEY_F7:
		# Debug: fast-forward the day/night clock while held.
		var dn := get_tree().get_first_node_in_group("day_night") as DayNight
		if dn:
			dn.request_fast_forward(event.pressed)
	elif event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_F4:
		if multiplayer.is_server():
			_debug_hurt()
		else:
			_debug_hurt.rpc_id(1)


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


func _process(delta: float) -> void:
	if not is_local():
		return
	# Recoil: most of the kick comes back down by itself.
	var step: float = _recoil_pending * minf(1.0, 7.0 * delta)
	head.rotation.x -= step
	_recoil_pending -= step
	var vm: Viewmodel = combat.viewmodel
	if vm:
		var speed: float = Vector2(velocity.x, velocity.z).length() / SPRINT_SPEED
		vm.update(delta, clampf(speed, 0.0, 1.0), net_sprint, is_on_floor())
	if ui:
		ui.set_ammo(combat.weapon.display_name, combat.mag, combat.reserve, combat.equipped, combat.is_reloading())


func _local_move(delta: float) -> void:
	# Test mode reads the (simulated) actions without a captured mouse.
	var active: bool = (auto_walk or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED) and not dead
	var input := Vector2.ZERO
	if active and not auto_walk:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir: Vector3 = (transform.basis * Vector3(input.x, 0, input.y))
	if auto_walk and not dead:
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


## Remote players: smooth towards the last synced state. Big jumps (respawn,
## correction) snap: gliding there would shove whoever stands in between.
func _follow_net(delta: float) -> void:
	if global_position.distance_to(net_pos) > 2.0:
		global_position = net_pos
	else:
		global_position = global_position.lerp(net_pos, minf(1.0, 15.0 * delta))
	rotation.y = lerp_angle(rotation.y, net_yaw, minf(1.0, 15.0 * delta))
	head.rotation.x = lerpf(head.rotation.x, net_pitch, minf(1.0, 15.0 * delta))


## Owner: camera kick of a shot (pitch up, yaw sideways); 75% recovers by itself.
func add_recoil(pitch: float, yaw: float) -> void:
	head.rotation.x = clampf(head.rotation.x + pitch, -1.45, 1.45)
	_recoil_pending += pitch * 0.75
	rotate_y(yaw)


# --- Animation (same on every peer, from the synced state) ----------------------

func _update_anim() -> void:
	if _anim == null:
		return
	if dead:
		return  # the death animation plays once and holds its last frame
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
	# Holding a gun: the body keeps facing forward (the arm must point where you look).
	if net_weapon != 0:
		model_yaw *= 0.3
	_model.rotation.y = lerp_angle(_model.rotation.y, PI + model_yaw, 0.2)
	_pose.crouch = maxf(_crouch_amount, 0.3 if net_air else 0.0)
	_pose.pitch = head.rotation.x
	_pose.aim = move_toward(_pose.aim, combat.body_aim(), 0.15)
	_pose.kick = combat.body_kick()


# --- Interaction (owner only) ----------------------------------------------------

func _update_focus() -> void:
	var space := get_world_3d().direct_space_state
	# Always from the eyes, also in third person.
	var from: Vector3 = head.global_position
	var to: Vector3 = from - head.global_basis.z * INTERACT_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2, [get_rid()])
	var hit: Dictionary = space.intersect_ray(query)
	var found: Node = null
	if not hit.is_empty() and not dead and shop == null:
		var n: Node = hit["collider"]
		while n != null and not n.is_in_group("interactable"):
			n = n.get_parent()
		found = n
	_focused = found
	if prompt_label:
		prompt_label.text = "[E] %s" % _focused.call("get_interaction_prompt") if _focused else ""


## Owner: opens the buy window of a shopkeeper (frees the mouse).
func open_shop(keeper: Shopkeeper) -> void:
	if ui == null or dead:
		return
	shop = keeper
	ui.open_shop(keeper, cash)
	if not ui.close_requested.is_connected(close_shop):
		ui.close_requested.connect(close_shop)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_shop() -> void:
	shop = null
	if ui:
		ui.close_shop()
	if not auto_walk:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Health and death ------------------------------------------------------------

## Host: apply damage from `attacker` (may be null). Returns true if this killed.
func host_damage(amount: int, attacker: Player) -> bool:
	if not multiplayer.is_server() or dead or amount <= 0:
		return false
	health = maxi(0, health - amount)
	if health > 0:
		return false
	_host_die(attacker)
	return true


func _host_die(attacker: Player) -> void:
	dead = true
	var killer: String = attacker.player_name if attacker and attacker != self else ""
	print("[Player] %s died%s" % [player_name, (" (killed by %s)" % killer) if killer != "" else ""])
	# Drop everything carried in a bag on the ground.
	var loot: Dictionary = GameState.take_all(player_name)
	var world := get_tree().current_scene
	var dropped: String = "You had nothing on you."
	if (int(loot["cash"]) > 0 or not (loot["items"] as Array).is_empty()) and world.has_method("spawn_loot_bag"):
		world.call("spawn_loot_bag", global_position, player_name, int(loot["cash"]), loot["items"])
		dropped = "Your bag with €%d dropped where you died." % int(loot["cash"])
	send_wallet()
	if peer_id == multiplayer.get_unique_id():
		_show_death(killer, dropped)
	else:
		_show_death.rpc_id(peer_id, killer, dropped)
	await get_tree().create_timer(RESPAWN_TIME).timeout
	if not is_inside_tree():
		return
	var spawn: Vector3 = world.call("get_free_spawn_point") if world.has_method("get_free_spawn_point") else global_position
	teleport(spawn)
	health = MAX_HEALTH
	dead = false
	combat.host_refill()
	print("[Player] %s respawned at the hospital %s" % [player_name, spawn.snapped(Vector3.ONE * 0.1)])


## Every peer: health changed (HostSync). Owner: HUD + damage flash.
func _on_health_changed(old: int) -> void:
	if ui and is_local():
		ui.set_health(health, MAX_HEALTH)
		if health < old:
			ui.flash_damage(old - health)
			head.rotation.x = clampf(head.rotation.x + 0.03, -1.45, 1.45)  # small flinch


## Every peer: dead flag changed (HostSync).
func _on_dead_changed() -> void:
	if not is_inside_tree() or _anim == null:
		return
	# Dead bodies are not solid for others and can't be shot again.
	collision_layer = 0 if dead else 8
	if dead:
		_pose.aim = 0.0
		_pose.crouch = 0.0
		_pose.pitch = 0.0
		_anim.speed_scale = 1.0
		_anim.play(_anim_names.get("Death", ""), 0.15)
	else:
		_anim.play(_anim_names.get("Idle", ""), 0.1)
	if is_local():
		if dead and shop != null:
			close_shop()
		if dead:
			_view_before_death = third_person
			_set_third_person(true)  # watch your own body fall
			if combat.viewmodel:
				combat.viewmodel.cancel_reload()
			combat._reload_end = 0.0
		else:
			_set_third_person(_view_before_death)
			if ui:
				ui.hide_death()


## Host -> owner: you died.
@rpc("any_peer", "call_remote", "reliable")
func _show_death(killer: String, dropped: String) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1] or ui == null:
		return
	var text: String = ("Killed by %s. " % killer if killer != "" else "") + dropped
	ui.show_death(text, RESPAWN_TIME)


## Shooter only: the host confirmed a hit.
func on_hit_confirmed(headshot: bool, killed: bool) -> void:
	if ui:
		ui.show_hitmarker(headshot, killed)
	WeaponFX.play_2d(self, WeaponFX.random_stream("impact_flesh"), -14.0 if not killed else -8.0, 0.1)


## Debug (F4): the host hurts this player (to test death without a second player).
@rpc("any_peer", "call_remote", "reliable")
func _debug_hurt() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != 0 and sender != peer_id:
		return
	host_damage(DEBUG_HURT, null)


# --- Money (host -> owner) -------------------------------------------------------

## Host: tell the owner its current cash and carried items.
func send_wallet() -> void:
	if not multiplayer.is_server():
		return
	var data: Dictionary = GameState.get_or_create_player_data(player_name)
	var amount: int = int(data["cash"])
	var items: Array = (data["inventory"] as Array).duplicate(true)
	if peer_id == multiplayer.get_unique_id():
		_set_wallet(amount, items)
	else:
		_set_wallet.rpc_id(peer_id, amount, items)


## Owner -> host: send me my cash (when my player node is ready).
@rpc("any_peer", "call_remote", "reliable")
func _request_wallet() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == peer_id:
		send_wallet()


@rpc("any_peer", "call_remote", "reliable")
func _set_wallet(amount: int, items: Array) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	cash = amount
	inventory = items
	if ui:
		ui.set_cash(amount)
		ui.set_inventory(items)
	wallet_changed.emit()


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


## Host -> owner: put the player at a position (speed check, respawn).
@rpc("any_peer", "call_local", "reliable")
func _teleport(pos: Vector3) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return  # only the host may move players
	global_position = pos
	velocity = Vector3.ZERO
	net_pos = pos


## Host: move a player anywhere (e.g. respawn at the hospital).
func teleport(pos: Vector3) -> void:
	if multiplayer.is_server():
		_check_pos = pos
		if peer_id == multiplayer.get_unique_id():
			_teleport(pos)
		else:
			_teleport.rpc_id(peer_id, pos)
			net_pos = pos
			global_position = pos
