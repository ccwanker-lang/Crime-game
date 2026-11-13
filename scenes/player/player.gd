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
const DEBUG_CASH: int = 1000
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
## Item (id) held in the hand when no weapon is drawn: seeds, soil, watering can... "" = empty hands.
var net_held: StringName = &""

## Point 22: health comes back by itself after `regen_delay` seconds without damage.
@export var regen_delay: float = 8.0
@export var regen_per_second: float = 4.0
var _last_damage: float = -1000.0  # host
## Host (point 25): when this player last fired (seconds, Time ticks) - resisting arrest.
var host_last_shot: float = -1000.0
## Arrest: fine = FINE_SHARE of all money, between FINE_MIN and FINE_MAX.
const FINE_SHARE: float = 0.1
const FINE_MIN: int = 200
const FINE_MAX: int = 5000
var _regen_acc: float = 0.0  # host

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
## Point 28: wanted stars (0-5) and whether the police see the player right now (Wanted).
var wanted_stars: int = 0:
	set(v):
		wanted_stars = v
		_on_wanted_changed()
var wanted_seen: bool = false:
	set(v):
		wanted_seen = v
		_on_wanted_changed()

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
var clean: int = 0  # owner: laundered money (point 9), last value sent by the host
## Owner: carried item stacks [{ "id", "count" }], last list sent by the host.
var inventory: Array = []
## Owner: the shop window that is open (null = none).
var shop: Shopkeeper = null
## Owner: the storage locker window that is open (null = none).
var locker: StorageLocker = null
## Point 40: the ledger window of a front business's safe is open.
var safe: LaunderSafe = null
## Owner (point 34): the customer whose deal window is open (null = none).
var deal_npc: Pedestrian = null
## Admin mode (host only, debug builds): F10 noclip, F11 god mode (no damage, endless ammo), F12 clear wanted.
## Owner (point 37): in bed, waiting for the night to pass (input only gets you out).
var sleeping: bool = false
var admin_noclip: bool = false
var admin_god: bool = false
const NOCLIP_SPEED: float = 9.0
## Owner: placement mode + hold E to pick up (point 6).
var placement: PlayerPlacement = null
var _base_fov: float = 75.0
## Owner: last message from the host (show_message), also for tests.
var last_message: String = ""
## Last phone message received [contact, text, deal] (tests).
var last_phone: Array = []

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
var _ragdoll: Ragdoll
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
		_base_fov = camera.fov
		var vm := Viewmodel.new()
		vm.name = "Viewmodel"
		camera.add_child(vm)
		var v: Dictionary = MODELS[model_index % MODELS.size()]
		vm.setup(MODEL_DIR % v["model"], float(v["scale"]), combat.weapon)
		combat.viewmodel = vm
		placement = PlayerPlacement.new()
		placement.name = "Placement"
		placement.player = self
		add_child(placement)
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
		elif short == "Interact":  # point 42: hands-on work at a station
			_anim_names[short] = a
			_anim.get_animation(a).loop_mode = Animation.LOOP_NONE
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_pose = PoseModifier.new()
	_skeleton.add_child(_pose)
	_ragdoll = Ragdoll.new()  # after the pose modifier: overrides it while dead
	_skeleton.add_child(_ragdoll)
	if aim_anim:
		_pose.set_aim_pose(aim_anim, 0.3)
	_anim.play(_anim_names.get("Idle", ""))

	# Every weapon of the loadout in the right fist (only the one in hand is
	# visible), placed after every skeleton update.
	for w: WeaponData in combat.weapons:
		var g := w.model_scene.instantiate() as WeaponModel
		g.name = "HandGun_%s" % w.id
		g.visible = false
		add_child(g)
		WeaponFX.make_flash(g.muzzle, false)
		combat.hand_guns.append(g)
	_bone_lower_r = _skeleton.find_bone("LowerArm.R")
	_bone_wrist_r = _skeleton.find_bone("Wrist.R")
	_skeleton.skeleton_updated.connect(_place_hand_gun)
	_skeleton.skeleton_updated.connect(_place_held_item)


# --- Held item (point 5) -------------------------------------------------------------

var _held_id: StringName = &""
var _held_body: Node3D  # in the right fist of the body (others, third person, shadow)
var _held_view: Node3D  # first person: in view, bottom right
var _held_bob: float = 0.0


## Every peer: (re)builds the held item models when net_held changes.
func _update_held_models() -> void:
	var want: StringName = net_held if net_weapon == 0 and not dead else &""
	if want == _held_id:
		return
	_held_id = want
	for n: Node3D in [_held_body, _held_view]:
		if n:
			n.queue_free()
	_held_body = null
	_held_view = null
	var data: ItemData = ItemDB.get_item(want) if want != &"" else null
	var scene: PackedScene = data.get_model() if data else null
	if scene == null:
		return
	_held_body = scene.instantiate() as Node3D
	_held_body.name = "HeldItem"
	_held_body.top_level = true
	add_child(_held_body)
	if is_local():
		_held_view = scene.instantiate() as Node3D
		_held_view.name = "HeldItemView"
		camera.add_child(_held_view)
		_set_held_shadows.call_deferred()
	_set_third_person_held()


## First person: the body's copy only casts a shadow (like the body itself).
func _set_held_shadows() -> void:
	_set_third_person_held()


func _set_third_person_held() -> void:
	var first_person: bool = is_local() and not third_person
	if _held_body:
		for m: Node in _held_body.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if first_person \
					else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if _held_view:
		_held_view.visible = first_person


## Body: the item hangs from the right fist (hand above it), facing where the player looks.
func _place_held_item() -> void:
	if _held_body == null or _bone_wrist_r < 0 or not is_inside_tree():
		return
	var t: Transform3D = _skeleton.global_transform
	var lower: Vector3 = t * _skeleton.get_bone_global_pose(_bone_lower_r).origin
	var wrist: Vector3 = t * _skeleton.get_bone_global_pose(_bone_wrist_r).origin
	var up: Vector3 = (lower - wrist).normalized()
	var back: Vector3 = global_basis.z - up * global_basis.z.dot(up)
	if back.length() < 0.01:
		back = global_basis.y
	back = back.normalized()
	var basis := Basis(up.cross(back).normalized(), up, back)
	_held_body.global_transform = Transform3D(basis, wrist - up * 0.09)


## First person: the item low in the right of the view, bobbing with the steps.
## Big things (soil bag, watering can) sit further away so they don't fill the screen.
func _update_held_view(delta: float) -> void:
	if _held_view == null:
		return
	var speed: float = Vector2(velocity.x, velocity.z).length()
	_held_bob += delta * (2.0 + speed * 1.6)
	var bob: float = sin(_held_bob * 2.0) * 0.008 * minf(1.0, speed / 3.0)
	var box: AABB = _held_aabb()
	var dist: float = 0.42 + box.get_longest_axis_size() * 0.75
	_held_view.rotation = Vector3(0.12, -0.75, 0.04)
	var work: float = work_amount()
	if work > 0.0 and _work_kind == "water":
		_held_view.rotation += Vector3(-0.9, 0.5, 0.0) * work  # tip the can forward: pour
	var anchor := Vector3(0.42 * dist - 0.12 * work, -0.36 * dist + bob - 0.08 * work, -dist - 0.1 * work)
	_held_view.position = anchor - _held_view.basis * box.get_center()


var _held_box_cache: Dictionary = {}


func _held_aabb() -> AABB:
	if _held_box_cache.has(_held_id):
		return _held_box_cache[_held_id]
	var box := AABB()
	var first: bool = true
	for m: Node in _held_view.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh:
			box = mi.get_aabb() if first else box.merge(mi.get_aabb())
			first = false
	if not first:
		_held_box_cache[_held_id] = box
	return box


func _place_hand_gun() -> void:
	var gun: WeaponModel = combat.hand_gun
	for g: WeaponModel in combat.hand_guns:
		g.visible = g == gun and not dead
	# The skeleton can still update while the player leaves the tree (disconnect).
	if gun == null or not gun.visible or _bone_wrist_r < 0 or not is_inside_tree():
		return
	var t: Transform3D = _skeleton.global_transform
	var lower: Vector3 = t * _skeleton.get_bone_global_pose(_bone_lower_r).origin
	var wrist: Vector3 = t * _skeleton.get_bone_global_pose(_bone_wrist_r).origin
	gun.global_transform = ViewmodelIK.gun_in_fist(lower, wrist, global_basis.y)


## First person: the own body (and the gun in its hand) is invisible but still
## casts a shadow; the viewmodel shows the arms instead.
func _set_third_person(on: bool) -> void:
	third_person = on
	_set_third_person_held()
	spring.spring_length = THIRD_PERSON_DISTANCE if on else 0.0
	spring.position = Vector3(0.45, 0.15, 0) if on else Vector3.ZERO
	var mode: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for m: MeshInstance3D in _meshes:
		m.cast_shadow = mode
	for g: WeaponModel in combat.hand_guns:
		for m: Node in g.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).cast_shadow = mode
	if combat.viewmodel:
		combat.viewmodel.hidden_by_view = on


# --- Input (owner only) ----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_local() or auto_walk:
		return
	if sleeping:
		# In bed: moving, jumping, E or Esc gets you up.
		for a: String in ["move_forward", "move_back", "move_left", "move_right", "jump", "interact", "release_mouse"]:
			if event.is_action_pressed(a):
				request_sleep(false)
				get_viewport().set_input_as_handled()
				break
		return
	if ui and ui.phone.is_open():
		# Phone out: mouse free for it, you can still walk; Tab or Esc puts it away.
		if event.is_action_pressed("phone") or event.is_action_pressed("release_mouse"):
			close_phone()
			get_viewport().set_input_as_handled()
		return
	if shop != null:
		# Shop window open: the mouse is free for its buttons; E or Esc leaves.
		if event.is_action_pressed("release_mouse") or event.is_action_pressed("interact"):
			close_shop()
			get_viewport().set_input_as_handled()
		return
	if locker != null:
		if event.is_action_pressed("release_mouse") or event.is_action_pressed("interact"):
			close_locker()
			get_viewport().set_input_as_handled()
		return
	if safe != null:
		if event.is_action_pressed("release_mouse") or event.is_action_pressed("interact") or not is_instance_valid(safe):
			close_safe()
			get_viewport().set_input_as_handled()
		return
	if deal_npc != null:
		if event.is_action_pressed("release_mouse") or event.is_action_pressed("interact") 				or not is_instance_valid(deal_npc) or deal_npc.wants <= 0:
			close_deal()
			get_viewport().set_input_as_handled()
		return
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and captured:
		if dead:
			return
		var motion := event as InputEventMouseMotion
		# Slower turning while zoomed in (same feel on screen).
		var sens: float = MOUSE_SENSITIVITY * camera.fov / _base_fov
		rotate_y(-motion.relative.x * sens)
		head.rotation.x = clampf(head.rotation.x - motion.relative.y * sens, -1.45, 1.45)
		if combat.viewmodel:
			combat.viewmodel.add_mouse(motion.relative)
	elif event is InputEventMouseButton and event.pressed and not captured:
		# Clicks on HUD buttons never get here (the GUI handles them first).
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		combat.trigger_held = false
		combat.aiming = false
	elif event.is_action_released("fire"):
		combat.trigger_held = false
	elif event.is_action_released("aim"):
		combat.aiming = false
	elif not captured:
		return
	elif placement and placement.handle_input(event):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("fire"):
		combat.trigger_held = true
		combat.try_fire()
	elif event.is_action_pressed("aim"):
		combat.aiming = not dead
	elif event.is_action_pressed("reload"):
		combat.try_reload()
	elif event.is_action_pressed("weapon_holster"):
		combat.set_equipped(false)
	elif event.is_action_pressed("weapon_toggle"):
		combat.set_equipped(not combat.equipped)
	elif event.is_action_pressed("weapon_next"):
		combat.cycle(1)
	elif event.is_action_pressed("weapon_prev"):
		combat.cycle(-1)
	elif _weapon_key(event) >= 0:
		combat.select_slot(_weapon_key(event))
	elif event.is_action_pressed("toggle_view") and not dead:
		_set_third_person(not third_person)
	elif event.is_action_pressed("phone") and not dead and ui:
		open_phone()
	elif event.is_action_pressed("build_mode") and not dead and placement:
		placement.toggle_build_mode()
	elif event.is_action_pressed("drop") and not dead:
		# G: drop the selected hotbar stack (Shift+G: just one).
		var slot: int = combat.hotbar_slot()
		if slot >= 0 and slot < inventory.size():
			request_drop(slot, 1 if Input.is_key_pressed(KEY_SHIFT) else 0)
	elif event.is_action_pressed("interact") and _focused != null and not dead:
		if placement == null or not placement.begin_interact(_focused):
			_focused.call("interact")
	elif event is InputEventKey and event.pressed and not event.echo 			and (event as InputEventKey).physical_keycode in [KEY_F10, KEY_F11, KEY_F12]:
		_admin_key((event as InputEventKey).physical_keycode)
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
	elif event is InputEventKey and event.pressed and not event.echo 			and (event as InputEventKey).physical_keycode == KEY_F6:
		if multiplayer.is_server():
			_debug_cash()
		else:
			_debug_cash.rpc_id(1)


## Admin mode: only the host's own player, only in debug builds (never in a release export).
static func admin_allowed(p: Player) -> bool:
	return OS.is_debug_build() and p.is_local() and (not p.multiplayer.has_multiplayer_peer() or p.multiplayer.is_server())


func _admin_key(key: Key) -> void:
	if not admin_allowed(self):
		return
	match key:
		KEY_F10:
			admin_noclip = not admin_noclip
			collision.disabled = admin_noclip
			velocity = Vector3.ZERO
			_admin_toast("Noclip %s" % ("ON: WASD + mouse, Space up, Ctrl down, Shift faster" if admin_noclip else "off"))
		KEY_F11:
			admin_god = not admin_god
			if admin_god:
				health = MAX_HEALTH
			_admin_toast("God mode %s" % ("ON: no damage, endless ammo" if admin_god else "off"))
		KEY_F12:
			Wanted.clear(self, "admin")
			for n: Node in get_tree().get_nodes_in_group(&"police"):
				if n.has_method("on_arrested"):
					n.call("on_arrested", self)  # (also forgets that you shot at them)
			_admin_toast("Admin: wanted stars cleared, the police back off")
	print("[Admin] %s: noclip %s, god %s%s" % [player_name, admin_noclip, admin_god, ", wanted cleared" if key == KEY_F12 else ""])
	var parts: PackedStringArray = []
	if admin_noclip:
		parts.append("NOCLIP")
	if admin_god:
		parts.append("GOD MODE")
	if ui:
		ui.set_admin(("ADMIN: " + " + ".join(parts)) if not parts.is_empty() else "")


func _admin_toast(text: String) -> void:
	if ui:
		ui.toast(text)


## Owner (noclip): fly where you look, through walls.
func _admin_fly(delta: float) -> void:
	var active: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back") if active else Vector2.ZERO
	var look: Basis = head.global_basis
	var dir: Vector3 = look * Vector3(input.x, 0, input.y)
	if active and Input.is_action_pressed("jump"):
		dir += Vector3.UP
	if active and Input.is_action_pressed("crouch"):
		dir += Vector3.DOWN
	var speed: float = NOCLIP_SPEED * (3.0 if active and Input.is_action_pressed("sprint") else 1.0)
	velocity = Vector3.ZERO
	global_position += dir.limit_length(1.0) * speed * delta


## 0-based hotbar slot for the number keys 1-8, -1 otherwise.
func _weapon_key(event: InputEvent) -> int:
	for i: int in GameState.INVENTORY_SLOTS:
		if event.is_action_pressed("weapon_%d" % (i + 1)):
			return i
	return -1


# --- Movement --------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_host_regen(delta)
	if is_local():
		if admin_noclip:
			_admin_fly(delta)
		elif sleeping:
			velocity = Vector3.ZERO
		else:
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
	_work_t = maxf(0.0, _work_t - delta)
	_update_crouch(delta)
	_update_anim()


func _process(delta: float) -> void:
	_update_held_models()
	if not is_local():
		return
	_update_held_view(delta)
	# Recoil: most of the kick comes back down by itself.
	var step: float = _recoil_pending * minf(1.0, 7.0 * delta)
	head.rotation.x -= step
	_recoil_pending -= step
	var vm: Viewmodel = combat.viewmodel
	if vm:
		var speed: float = Vector2(velocity.x, velocity.z).length() / SPRINT_SPEED
		vm.update(delta, clampf(speed, 0.0, 1.0), net_sprint, is_on_floor())
	# Aim down sights / scope: zoom the camera (not while sprinting or reloading).
	var aim_on: bool = combat.aiming and combat.equipped and not net_sprint and not combat.is_reloading() and not dead
	var fov_goal: float = combat.weapon.aim_fov if aim_on else _base_fov
	camera.fov = lerpf(camera.fov, fov_goal, minf(1.0, 14.0 * delta))
	if vm:
		vm.aim_target = 1.0 if aim_on else 0.0
		vm.hidden_by_scope = combat.is_scoped() and camera.fov < 30.0
	if ui:
		ui.set_ammo(combat.weapon.display_name, combat.mag, combat.reserve, combat.equipped, combat.is_reloading())
		ui.set_hotbar_selected(combat.hotbar_slot())
		ui.set_scope(combat.is_scoped() and camera.fov < 30.0 and not third_person)


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
	head.position.y = lerpf(EYE_STAND, EYE_CROUCH, maxf(_crouch_amount, _work_low * work_amount() * 0.8))


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
		return  # the ragdoll moves the body
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
	if _work_t > 0.0 and _anim_names.has("Interact") and move.length() < 0.1:
		key = "Interact"  # point 42 (started once in _play_work)
		speed_scale = 1.0
	var a: String = _anim_names.get(key, _anim_names.get("Idle", ""))
	if _anim.current_animation != a and not (key == "Interact" and _anim.assigned_animation == a):
		_anim.play(a, 0.2)
	_anim.speed_scale = speed_scale
	# Holding a gun: the body keeps facing forward (the arm must point where you look).
	if net_weapon != 0:
		model_yaw *= 0.3
	_model.rotation.y = lerp_angle(_model.rotation.y, PI + model_yaw, 0.2)
	_pose.crouch = maxf(maxf(_crouch_amount, 0.3 if net_air else 0.0), _work_low * work_amount() * 0.85)
	_pose.pitch = head.rotation.x
	_pose.aim = move_toward(_pose.aim, combat.body_aim(), 0.15)
	_pose.kick = combat.body_kick()


# --- Point 42: work animations (planting, watering, harvesting, packaging...) -------------

const WORK_TIME: float = 1.2
## Particles per work kind: [colour, count, size, spread]; none for the rest.
const WORK_FX: Dictionary = {
	"water": [Color(0.45, 0.65, 0.95, 0.85), 40, 0.018, 0.08],
	"soil": [Color(0.3, 0.2, 0.12), 24, 0.03, 0.15],
	"plant": [Color(0.3, 0.2, 0.12), 10, 0.02, 0.06],
	"harvest": [Color(0.25, 0.45, 0.15), 18, 0.035, 0.2],
}
var _work_t: float = 0.0
var _work_kind: String = ""
var _work_low: float = 0.0  # 1 = the station is low (a pot on the floor): kneel down


## 0 -> 1 -> 0 over the work animation (how far the body bends / the view dips).
func work_amount() -> float:
	if _work_t <= 0.0:
		return 0.0
	return sin(PI * (1.0 - _work_t / WORK_TIME))


func is_working() -> bool:
	return _work_t > 0.0


## Host: `kind` of work done at a station at `at` -> every peer plays it.
func host_work(kind: String, at: Vector3) -> void:
	if not multiplayer.has_multiplayer_peer():
		_play_work(kind, at)
		return
	if not multiplayer.is_server():
		return
	_play_work(kind, at)
	for peer: int in Net.peers_in_world:
		if peer != multiplayer.get_unique_id():
			_play_work.rpc_id(peer, kind, at)


@rpc("any_peer", "call_remote", "reliable")
func _play_work(kind: String, at: Vector3) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	_work_t = WORK_TIME
	_work_kind = kind
	_work_low = 1.0 if at.y < global_position.y + 0.45 else 0.0
	if _anim and _anim_names.has("Interact") and not dead:
		_anim.play(_anim_names["Interact"], 0.15)
	_work_particles(kind, at)


## A short puff at the station: water drops, soil, leaves.
func _work_particles(kind: String, at: Vector3) -> void:
	if not WORK_FX.has(kind) or not is_inside_tree():
		return
	var fx: Array = WORK_FX[kind]
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = int(fx[1])
	p.lifetime = 0.9
	p.explosiveness = 0.15 if kind == "water" else 0.6
	p.direction = Vector3.DOWN if kind == "water" else Vector3.UP
	p.spread = 12.0 if kind == "water" else 60.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0, -6.0, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = float(fx[3])
	var mesh := SphereMesh.new()
	mesh.radius = float(fx[2])
	mesh.height = float(fx[2]) * 2.0
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = fx[0]
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if (fx[0] as Color).a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	p.mesh = mesh
	get_tree().current_scene.add_child(p)
	p.global_position = at + Vector3.UP * (0.7 if kind == "water" else 0.35)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


# --- Interaction (owner only) ----------------------------------------------------

func _update_focus() -> void:
	var space := get_world_3d().direct_space_state
	# Always from the eyes, also in third person.
	var from: Vector3 = head.global_position
	var to: Vector3 = from - head.global_basis.z * INTERACT_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 4, [get_rid()])  # world, props, npcs (customers)
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
		if placement and placement.hold_progress() > 0.0:
			var n: int = int(placement.hold_progress() * 10.0)
			prompt_label.text = "Picking up  [%s%s]" % ["#".repeat(n), "-".repeat(10 - n)]
		elif placement and placement.is_active():
			prompt_label.text = placement.prompt_text()
		elif placement and placement.build_mode and _focused and PlayerPlacement.placed_uid_of(_focused) != "":
			prompt_label.text = "[E] %s   [Hold E] Pick up" % _focused.call("get_interaction_prompt")
		elif placement and _focused == null and placement.hint_text() != "":
			prompt_label.text = placement.hint_text()


## Owner: opens the buy window of a shopkeeper (frees the mouse).
func open_shop(keeper: Shopkeeper) -> void:
	if ui == null or dead:
		return
	shop = keeper
	ui.open_shop(keeper, cash, clean)
	if not ui.close_requested.is_connected(close_shop):
		ui.close_requested.connect(close_shop)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Owner (point 34): the talk with a customer whose deal was accepted ("Confirm deal").
func open_deal(npc: Pedestrian) -> void:
	if ui == null or dead or shop != null or locker != null:
		return
	deal_npc = npc
	ui.open_deal(npc, Station.carried(self, npc.product))
	if not ui.close_requested.is_connected(close_deal):
		ui.close_requested.connect(close_deal)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_deal() -> void:
	deal_npc = null
	if ui:
		ui.close_deal()
	if not auto_walk:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Owner (point 37): get into bed / out of it (the host checks time, bed, wanted).
func request_sleep(on: bool) -> void:
	if multiplayer.is_server():
		_host_request_sleep(on)
	else:
		_request_sleep.rpc_id(1, on)


@rpc("any_peer", "call_remote", "reliable")
func _request_sleep(on: bool) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == peer_id:
		_host_request_sleep(on)


func _host_request_sleep(on: bool) -> void:
	var s: Sleep = Sleep.current(get_tree())
	if s:
		s.host_set(self, on)


## Host -> owner: asleep (dark screen + text) or awake.
func host_sleep_state(on: bool, text: String) -> void:
	if not multiplayer.is_server():
		return
	if peer_id == multiplayer.get_unique_id():
		_sleep_state(on, text)
	else:
		_sleep_state.rpc_id(peer_id, on, text)


@rpc("any_peer", "call_remote", "reliable")
func _sleep_state(on: bool, text: String) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	sleeping = on
	if ui:
		ui.set_sleep(on, text)
		if not on and text != "":
			ui.toast(text)


## Owner: phone out (frees the mouse) / away.
func open_phone() -> void:
	ui.phone.player = self
	ui.phone.open()
	combat.trigger_held = false
	combat.aiming = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_phone() -> void:
	if ui:
		ui.phone.close()
	if not auto_walk:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Dropping items (point 20) -------------------------------------------------------

## Owner: drop `count` items (<= 0: the whole stack) of inventory slot `index` on the ground.
func request_drop(index: int, count: int = 0) -> void:
	if multiplayer.is_server():
		_host_drop(index, count)
	else:
		_request_drop.rpc_id(1, index, count)


@rpc("any_peer", "call_remote", "reliable")
func _request_drop(index: int, count: int) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == peer_id:
		_host_drop(index, count)


## Host: takes the items out of the inventory and puts them on the ground in front of the player.
func _host_drop(index: int, count: int) -> void:
	var inv: Array = GameState.get_or_create_player_data(player_name)["inventory"]
	if dead or index < 0 or index >= inv.size():
		return
	var stack: Dictionary = inv[index]
	var id: String = str(stack.get("id", ""))
	var have: int = int(stack.get("count", 1))
	var amount: int = have if count <= 0 else mini(count, have)
	stack["count"] = have - amount
	if int(stack["count"]) <= 0:
		inv.remove_at(index)
	var world: Node = get_tree().current_scene
	var pos: Vector3 = global_position - global_basis.z * 0.9 + Vector3.UP * 0.3
	if world.has_method("spawn_loot_bag"):
		world.call("spawn_loot_bag", pos, player_name, 0, [{"id": id, "count": amount}], true)
	send_wallet()
	var data: ItemData = ItemDB.get_item(StringName(id))
	print("[Player] %s dropped %dx %s" % [player_name, amount, id])
	show_message("Dropped %dx %s." % [amount, data.display_name if data else id])


## Owner: the storage window of a locker (frees the mouse).
func open_locker(l: StorageLocker) -> void:
	if ui == null or dead or shop != null:
		return
	locker = l
	ui.open_locker(l, self)
	if not ui.close_requested.is_connected(close_locker):
		ui.close_requested.connect(close_locker)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Owner (point 40): the ledger window of a front business's safe (frees the mouse).
func open_safe(s: LaunderSafe) -> void:
	if ui == null or dead or shop != null or locker != null:
		return
	safe = s
	ui.open_safe(s, self)
	if not ui.close_requested.is_connected(close_safe):
		ui.close_requested.connect(close_safe)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_safe() -> void:
	safe = null
	if ui:
		ui.close_safe()
	if not auto_walk:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func close_locker() -> void:
	locker = null
	if ui:
		ui.close_locker()
	if not auto_walk:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func close_shop() -> void:
	shop = null
	if ui:
		ui.close_shop()
	if not auto_walk:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Health and death ------------------------------------------------------------

## Host: did a bullet that hit this player at `pos` hit the head?
func is_head_hit(pos: Vector3) -> bool:
	return pos.y - global_position.y > head.position.y - 0.2


## Host: apply damage from `attacker` (may be null). Returns true if this killed.
## `from`: where the shot came from (ragdoll impulse), INF = unknown.
## Host: slow regeneration back to MAX_HEALTH once nothing hurt us for regen_delay s.
func _host_regen(delta: float) -> void:
	if dead or health >= MAX_HEALTH:
		_regen_acc = 0.0
		return
	if Time.get_ticks_msec() / 1000.0 - _last_damage < regen_delay:
		return
	_regen_acc += regen_per_second * delta
	if _regen_acc >= 1.0:
		var add: int = int(_regen_acc)
		_regen_acc -= add
		health = mini(MAX_HEALTH, health + add)


## `attacker`: the Player who shot, or an NPC (police officer, rival), or null.
func host_damage(amount: int, attacker: Node, from: Vector3 = Vector3.INF) -> bool:
	if not multiplayer.is_server() or dead or amount <= 0 or admin_god:
		return false
	_last_damage = Time.get_ticks_msec() / 1000.0
	_regen_acc = 0.0
	health = maxi(0, health - amount)
	if health > 0:
		return false
	if attacker is PoliceOfficer:
		print("[Player] %s was shot dead by the police" % player_name)
	_host_die(attacker as Player, from)
	return true


func _host_die(attacker: Player, from: Vector3 = Vector3.INF) -> void:
	dead = true
	Wanted.clear(self, "dead")
	# Every peer lets the body fall as a ragdoll; the shot pushes it away from the shooter.
	var away := Vector3(global_position.x - from.x, 0, global_position.z - from.z) if from != Vector3.INF else -global_basis.z
	var impulse: Vector3 = away.normalized() * 90.0 + Vector3.UP * 15.0
	var at: Vector3 = global_position + Vector3.UP * 1.25
	_ragdoll_push(impulse, at)
	for peer: int in Net.peers_in_world:
		if peer != multiplayer.get_unique_id():
			_ragdoll_push.rpc_id(peer, impulse, at)
	var killer: String = attacker.player_name if attacker and attacker != self else ""
	print("[Player] %s died%s" % [player_name, (" (killed by %s)" % killer) if killer != "" else ""])
	# Drop everything carried in a bag on the ground (loaded rounds included).
	combat.host_unload()
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


## Host (point 25): the police cuffed this player. Illegal items are confiscated
## (loaded rounds first go back into the pockets), a fine is paid (clean money
## first, as much as there is) and the player is released at the police station.
func host_arrest(by: Node) -> void:
	if not multiplayer.is_server() or dead:
		return
	combat.host_unload()
	var data: Dictionary = GameState.get_or_create_player_data(player_name)
	var inv: Array = data["inventory"]
	var taken: PackedStringArray = []
	for i: int in range(inv.size() - 1, -1, -1):
		var it: Dictionary = inv[i]
		var item: ItemData = ItemDB.get_item(StringName(str(it.get("id", ""))))
		if item and not item.is_legal:
			taken.append("%dx %s" % [int(it.get("count", 1)), item.display_name])
			inv.remove_at(i)
	var total: int = GameState.total_money(player_name)
	var fine: int = mini(total, clampi(roundi(total * FINE_SHARE), FINE_MIN, FINE_MAX))
	if fine > 0:
		GameState.add_cash(player_name, -fine, true)
	health = MAX_HEALTH
	var world: Node = get_tree().current_scene
	var spot: Node3D = world.call("get_marker", "ReleaseSpot") if world.has_method("get_marker") else null
	if spot:
		teleport(spot.global_position)
	send_wallet()
	combat.host_send_all_ammo()
	get_tree().call_group(&"police", "on_arrested", self)
	Wanted.clear(self, "arrested")
	var what: String = ", ".join(taken) if not taken.is_empty() else "nothing"
	print("[Police] %s arrested by %s: confiscated %s, fine €%d" % [player_name, by.name if by else "?", what, fine])
	show_message("ARRESTED. Confiscated: %s. Fine: €%d. You're free to go." % [what, fine])
	phone_message("Police", "You were arrested and released on a €%d fine. Confiscated: %s." % [fine, what], "")


## Every peer: health changed (HostSync). Owner: HUD + damage flash.
func _on_health_changed(old: int) -> void:
	if ui and is_local():
		ui.set_health(health, MAX_HEALTH)
		if health < old:
			ui.flash_damage(old - health)
			head.rotation.x = clampf(head.rotation.x + 0.03, -1.45, 1.45)  # small flinch


## Every peer: wanted level changed (HostSync). Owner: HUD stars.
func _on_wanted_changed() -> void:
	if ui and is_inside_tree() and is_local():
		ui.set_wanted(wanted_stars, wanted_seen)


## Every peer: dead flag changed (HostSync).
func _on_dead_changed() -> void:
	if not is_inside_tree() or _anim == null:
		return
	# Dead bodies are not solid for others and can't be shot again.
	collision_layer = 0 if dead else 8
	if dead:
		_go_limp()
	else:
		_ragdoll.stop()
		_pose.active = true
		_anim.play(_anim_names.get("Idle", ""), 0.0)
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


## Every peer: the animation stops and the ragdoll takes over.
func _go_limp() -> void:
	if _ragdoll == null or _ragdoll.running:
		return
	_pose.aim = 0.0
	_pose.crouch = 0.0
	_pose.pitch = 0.0
	_pose.active = false
	_anim.pause()
	_ragdoll.start(velocity)


## Host -> peers: the death shot's push on the ragdoll.
@rpc("any_peer", "call_remote", "reliable")
func _ragdoll_push(impulse: Vector3, at: Vector3) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	_go_limp()
	_ragdoll.push(impulse, at)


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


## Debug (F6): the host gives this player €1000 (to test the shops before selling exists).
@rpc("any_peer", "call_remote", "reliable")
func _debug_cash() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != 0 and sender != peer_id:
		return
	GameState.add_cash(player_name, DEBUG_CASH)
	send_wallet()
	show_message("Debug: +€%d" % DEBUG_CASH)


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
	var clean_amount: int = int(data["clean"])
	var items: Array = (data["inventory"] as Array).duplicate(true)
	if peer_id == multiplayer.get_unique_id():
		_set_wallet(amount, items, clean_amount)
	else:
		_set_wallet.rpc_id(peer_id, amount, items, clean_amount)


## Owner -> host: send me my cash (when my player node is ready).
@rpc("any_peer", "call_remote", "reliable")
func _request_wallet() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == peer_id:
		send_wallet()
		combat.host_send_all_ammo()  # e.g. magazines loaded from the save


@rpc("any_peer", "call_remote", "reliable")
func _set_wallet(amount: int, items: Array, clean_amount: int = 0) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	cash = amount
	clean = clean_amount
	inventory = items
	if ui:
		ui.set_cash(amount, clean_amount)
		ui.set_inventory(items)
	wallet_changed.emit()


## Host: a phone message for the owner (`deal` = customer node name or "").
func phone_message(contact: String, text: String, deal: String) -> void:
	if not multiplayer.is_server():
		return
	if peer_id == multiplayer.get_unique_id():
		_phone_message(contact, text, deal)
	else:
		_phone_message.rpc_id(peer_id, contact, text, deal)


@rpc("any_peer", "call_remote", "reliable")
func _phone_message(contact: String, text: String, deal: String) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	last_phone = [contact, text, deal]
	if ui:
		ui.phone.player = self
		ui.phone.add_message(contact, text, deal)
		if not ui.phone.is_open():
			ui.toast("New message from %s  [Tab]" % contact)


## Owner: answer a customer's proposal (point 34: "accept", "decline", "counter" + price).
func phone_reply(deal: String, action: String, price: int = 0) -> void:
	if multiplayer.is_server():
		_host_phone_reply(deal, action, price)
	else:
		_request_phone_reply.rpc_id(1, deal, action, price)


@rpc("any_peer", "call_remote", "reliable")
func _request_phone_reply(deal: String, action: String, price: int) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == peer_id:
		_host_phone_reply(deal, action, price)


func _host_phone_reply(deal: String, action: String, price: int = 0) -> void:
	if not action in ["accept", "decline", "counter"]:
		return
	var npc := get_tree().current_scene.get_node_or_null("NPCs/" + deal) as Pedestrian
	if npc and not npc.dead and npc.wants > 0:
		npc.answer_text(self, action, clampi(price, 0, 100000))


## Owner: order a legal item on the phone (delivered to the Starter Room box).
func webshop_buy(id: StringName, count: int) -> void:
	if multiplayer.is_server():
		_host_webshop_buy(id, count)
	else:
		_request_webshop_buy.rpc_id(1, id, count)


@rpc("any_peer", "call_remote", "reliable")
func _request_webshop_buy(id: StringName, count: int) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == peer_id:
		_host_webshop_buy(id, count)


func _host_webshop_buy(id: StringName, count: int) -> void:
	var item: ItemData = ItemDB.get_item(id)
	var box := get_tree().get_first_node_in_group(&"delivery_box") as DeliveryBox
	if item == null or not item.is_legal or item.base_price <= 0 or count < 1 or count > 20 or box == null:
		show_message("QuickShip can't deliver that.")
		return
	var cost: int = item.base_price * count
	if not GameState.add_cash(player_name, -cost, true):
		show_message("Not enough money (€%d)." % cost)
		return
	box.order(str(id), count * item.pack_size)
	send_wallet()
	show_message("Ordered %d %s for €%d. Delivery to your Starter Room in about an hour." % [count, item.display_name, cost])


# --- Placing + picking up (point 6) -----------------------------------------------

## Owner: place the item `id` (one from the inventory) at `pos` turned by `yaw`.
func request_place(id: String, pos: Vector3, yaw: float) -> void:
	if multiplayer.is_server():
		var msg: String = _host_place(id, pos, yaw)
		if msg != "":
			show_message(msg)
	else:
		_request_place.rpc_id(1, id, pos, yaw)


@rpc("any_peer", "call_remote", "reliable")
func _request_place(id: String, pos: Vector3, yaw: float) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == peer_id:
		var msg: String = _host_place(id, pos, yaw)
		if msg != "":
			show_message(msg)


## Host: checks + places. Returns "" when placed, otherwise why not.
func _host_place(id: String, pos: Vector3, yaw: float) -> String:
	var item: ItemData = ItemDB.get_item(StringName(id))
	if item == null or item.place_scene == null or dead:
		return "You can't place that."
	if GameState.count_item(player_name, id) < 1:
		return "You don't have a %s." % item.display_name
	if global_position.distance_to(pos) > Placement.MAX_REACH + 1.5:
		return "That's too far away."
	var reason: String = Placement.check(get_world_3d(), get_tree(), item, pos, yaw, [get_rid()])
	if reason != "":
		return reason
	GameState.remove_item(player_name, id, 1)
	get_tree().current_scene.call("host_place", id, pos, yaw)
	send_wallet()
	return ""


## Owner: pick up the placed station / furniture `uid` (back into the inventory).
func request_pick_up(uid: String) -> void:
	if multiplayer.is_server():
		var msg: String = _host_pick_up(uid)
		if msg != "":
			show_message(msg)
	else:
		_request_pick_up.rpc_id(1, uid)


@rpc("any_peer", "call_remote", "reliable")
func _request_pick_up(uid: String) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == peer_id:
		var msg: String = _host_pick_up(uid)
		if msg != "":
			show_message(msg)


## Host: checks + picks up. Returns "" when done, otherwise why not.
func _host_pick_up(uid: String) -> String:
	var world: Node = get_tree().current_scene
	var n: Node3D = world.call("get_placed", uid)
	if n == null or dead:
		return ""
	if global_position.distance_to(n.global_position) > INTERACT_DISTANCE + 2.0:
		return "That's too far away."
	var prop: Property = Placement.property_at(get_tree(), n.global_position)
	if prop != null and not prop.is_crew_owned():
		return "This isn't your property."
	var refund: Array = []
	if n is Station:
		var blocker: String = (n as Station).pick_up_blocker()
		if blocker != "":
			return blocker
		refund = (n as Station).refund_items()
	var id: String = str(n.get_meta(&"placed_item", ""))
	if GameState.space_for(player_name, id) < 1:
		return "Your pockets are full."
	GameState.give(player_name, 0, [{"id": id, "count": 1}] + refund)
	world.call("host_remove_placed", uid)
	send_wallet()
	return ""


## Half the price back for furniture / stations (phone Resell app).
static func resell_price(item: ItemData) -> int:
	return int(floor(item.base_price * 0.5))


## Owner: sell one carried furniture piece / station.
func resell(id: StringName) -> void:
	if multiplayer.is_server():
		_host_resell(id)
	else:
		_request_resell.rpc_id(1, id)


@rpc("any_peer", "call_remote", "reliable")
func _request_resell(id: StringName) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == peer_id:
		_host_resell(id)


func _host_resell(id: StringName) -> void:
	var item: ItemData = ItemDB.get_item(id)
	if item == null or item.place_scene == null or not GameState.remove_item(player_name, String(id), 1):
		show_message("You can't sell that.")
		return
	var price: int = resell_price(item)
	GameState.add_cash(player_name, price)
	send_wallet()
	show_message("Sold a %s for €%d." % [item.display_name, price])


## Host: short message on the owner's screen (station results, errors).
func show_message(text: String) -> void:
	if not multiplayer.is_server():
		return
	if peer_id == multiplayer.get_unique_id():
		_show_message(text)
	else:
		_show_message.rpc_id(peer_id, text)


@rpc("any_peer", "call_remote", "reliable")
func _show_message(text: String) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	last_message = text
	if ui:
		ui.toast(text)


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
