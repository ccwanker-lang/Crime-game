class_name PlayerPlacement
extends Node
## Point 6 (owner only): placement mode + picking things up.
## - A placeable item (ItemData.place_scene) selected in the hotbar with no weapon out
##   shows a ghost where you look: green = can place, red = can't (reason in the prompt).
##   It snaps to a 0.25 m grid on the floor; R / mouse wheel rotates; LMB places
##   (Player.request_place -> the host checks it again).
## - Hold E on a placed station or piece of furniture picks it up (Player.request_pick_up).
##   A short tap on a station still does its normal action.

const HOLD_TIME: float = 0.6
const ROTATE_STEP: float = PI / 12.0  # 15 degrees (wheel); R turns 90

var player: Player
var item: ItemData = null
var yaw: float = 0.0
var valid: bool = false
var reason: String = ""
var target: Vector3 = Vector3.INF

var _ghost: Node3D = null
var _ghost_id: StringName = &""
var _mat_ok: StandardMaterial3D
var _mat_bad: StandardMaterial3D
var _yaw_set: bool = false
# Hold E
var _hold_node: Node = null
var _hold_time: float = 0.0
var _hold_done: bool = false


func _ready() -> void:
	_mat_ok = _ghost_material(Color(0.3, 1.0, 0.45, 0.42))
	_mat_bad = _ghost_material(Color(1.0, 0.3, 0.25, 0.42))


static func _ghost_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## The placeable item in the selected hotbar slot (no weapon out), else null.
func selected_placeable() -> ItemData:
	var c: PlayerCombat = player.combat
	if c.equipped or player.dead or c.selected_slot < 0 or c.selected_slot >= player.inventory.size():
		return null
	var it: ItemData = ItemDB.get_item(StringName(str((player.inventory[c.selected_slot] as Dictionary).get("id", ""))))
	return it if it and it.place_scene else null


func is_active() -> bool:
	return item != null


func _process(delta: float) -> void:
	_update_ghost()
	_update_hold(delta)


func _update_ghost() -> void:
	var want: ItemData = selected_placeable() if player.shop == null and player.locker == null else null
	if want != item:
		item = want
		if not _yaw_set:
			yaw = snappedf(player.rotation.y + PI, PI / 2.0)  # facing the player
	if item == null:
		_free_ghost()
		target = Vector3.INF
		return
	if _ghost == null or _ghost_id != item.id:
		_make_ghost()
	var ignore: Array[RID] = [player.get_rid()]
	var hit: Dictionary = Placement.aim_point(player.get_world_3d(), player.head.global_position,
			-player.head.global_basis.z, ignore, Placement.support_mask(item))
	if hit.is_empty():
		_ghost.visible = false
		target = Vector3.INF
		valid = false
		reason = "Look at a floor."
		return
	target = hit["pos"]
	_ghost.visible = true
	_ghost.global_transform = Transform3D(Basis(Vector3.UP, yaw), target)
	reason = Placement.check(player.get_world_3d(), player.get_tree(), item, target, yaw, ignore)
	valid = reason == ""
	_set_ghost_material(_mat_ok if valid else _mat_bad)


func _make_ghost() -> void:
	_free_ghost()
	_ghost_id = item.id
	var inst: Node3D = item.place_scene.instantiate() as Node3D
	if inst is Station:
		(inst as Station).ghost = true
	_ghost = inst
	_ghost.name = "PlacementGhost"
	_ghost.top_level = true
	player.add_child(_ghost)
	for n: Node in [_ghost] + _ghost.find_children("*", "CollisionObject3D", true, false):
		var body := n as CollisionObject3D
		if body:
			body.collision_layer = 0
			body.collision_mask = 0


func _free_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
	_ghost = null
	_ghost_id = &""


func _set_ghost_material(m: Material) -> void:
	for n: Node in _ghost.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.material_override != m:
			g.material_override = m
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Player input while placing: returns true when used.
func handle_input(event: InputEvent) -> bool:
	if item == null:
		return false
	if event.is_action_pressed("fire"):
		if valid:
			player.request_place(String(item.id), target, yaw)
		elif reason != "":
			player.ui.toast(reason)
		return true
	if event.is_action_pressed("weapon_next") or event.is_action_pressed("weapon_prev"):
		yaw = wrapf(yaw + (ROTATE_STEP if event.is_action_pressed("weapon_next") else -ROTATE_STEP), -PI, PI)
		_yaw_set = true
		return true
	if event.is_action_pressed("reload"):  # R
		yaw = wrapf(snappedf(yaw, PI / 2.0) + PI / 2.0, -PI, PI)
		_yaw_set = true
		return true
	return false


func prompt_text() -> String:
	if item == null:
		return ""
	if valid:
		return "[LMB] Place %s   [R / wheel] Rotate" % item.display_name
	return "%s: %s   [R / wheel] Rotate" % [item.display_name, reason]


# --- Hold E to pick up -------------------------------------------------------------

static func placed_uid_of(n: Node) -> String:
	if n == null:
		return ""
	var uid: Variant = n.get("placed_uid")
	return str(uid) if uid != null else ""


## E pressed on `n`: placed things wait for the hold (a short tap = normal action).
## Returns true when the press is handled here.
func begin_interact(n: Node) -> bool:
	if placed_uid_of(n) == "":
		return false
	_hold_node = n
	_hold_time = 0.0
	_hold_done = false
	return true


func _update_hold(delta: float) -> void:
	if _hold_node == null:
		return
	if not is_instance_valid(_hold_node) or player.dead:
		_hold_node = null
		return
	if Input.is_action_pressed("interact"):
		_hold_time += delta
		if _hold_time >= HOLD_TIME and not _hold_done:
			_hold_done = true
			var blocker: String = _hold_node.call("pick_up_blocker") if _hold_node.has_method("pick_up_blocker") else ""
			if blocker != "":
				player.ui.toast(blocker)
			else:
				player.request_pick_up(placed_uid_of(_hold_node))
		return
	# Released: a short tap is the normal E action.
	if not _hold_done:
		_hold_node.call("interact")
	_hold_node = null


## 0..1 while E is held on a placed thing (prompt shows it).
func hold_progress() -> float:
	return clampf(_hold_time / HOLD_TIME, 0.0, 1.0) if _hold_node and not _hold_done else 0.0
