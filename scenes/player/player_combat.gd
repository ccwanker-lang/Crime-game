class_name PlayerCombat
extends Node
## Weapon handling of one player (child "Combat" of Player, exists on every peer).
##
## Weapons are inventory items (WeaponData in LOADOUT): bought at the gun shop,
## lost in the loot bag on death, and only drawn while carried. The number
## keys pick a hotbar slot (= inventory slot): a weapon there is taken in hand,
## anything else puts the weapon away. New players and every respawn get a
## loaded service pistol + starter rounds. Spare rounds are ammo items in the
## inventory (WeaponData.ammo_id); only the loaded magazine lives here.
## Player.net_weapon = 0 holstered, else the index + 1 of the weapon in hand
## (synced by the owner).
##
## OWNER: reads input (via Player), predicts ammo and plays its own effects at
## once (viewmodel, sound, casing, impact) so shooting feels instant, then asks
## the host with _request_fire(index, origin, dir).
## HOST: validates every shot (alive, weapon out, fire rate, ammo, origin near
## the shooter's eyes), does the real raycast(s) (shotgun: one per pellet),
## applies damage to players and NPCs, and sends the effects to the other peers.
## Magazines on the host and GameState inventories are the truth; the owner is
## corrected with _sync_ammo / Player.send_wallet when they differ.
## Lag compensation: none (LAN co-op; the host hits what it sees).

const LOADOUT: Array[StringName] = [&"pistol", &"smg", &"ak47", &"shotgun", &"sniper"]
const HIT_MASK: int = 1 | 2 | 4 | 8  # world, doors/props, npcs, players
const FAR_SOUND_DISTANCE: float = 30.0

signal weapon_changed

var player: Player
var weapons: Array[WeaponData] = []
## Owner: index of the selected weapon (also while holstered).
var current: int = 0
## Owner: hotbar slot picked last with the number keys (-1 = none).
var selected_slot: int = 0
var weapon: WeaponData:
	get:
		return weapons[current]

# Owner (predicted) magazine per weapon and spare rounds per ammo id (from the inventory).
var _mags: Array[int] = []
var ammo: Dictionary = {}
var mag: int:
	get:
		return _mags[current]
	set(v):
		_mags[current] = v
var reserve: int:
	get:
		return int(ammo.get(String(weapon.ammo_id), 0))
	set(v):
		ammo[String(weapon.ammo_id)] = v
var equipped: bool = true
## Owner: right mouse button held (aim down sights / scope).
var aiming: bool = false
## Owner: fire button held (automatic weapons).
var trigger_held: bool = false

var viewmodel: Viewmodel      # local player only
## Third-person guns in the body's right fist, one per weapon (every peer).
var hand_guns: Array[WeaponModel] = []
var hand_gun: WeaponModel:
	get:
		var i: int = player.net_weapon - 1
		return hand_guns[i] if i >= 0 and i < hand_guns.size() else null

var _next_fire: float = 0.0
var _reload_end: float = 0.0  # owner: when the current reload completes (0 = none)
# Host truth per weapon (spare rounds: GameState inventory).
var _h_mags: Array[int] = []
var _h_last_fire: float = -10.0
var _h_reload_end: float = 0.0
var _h_reload_index: int = -1
## Host: magazine of the weapon in hand (tests).
var _h_mag: int:
	get:
		return _h_mags[maxi(0, player.net_weapon - 1)]
# Third-person pose (every peer).
var _kick: float = 0.0
var _reload_pose: float = 0.0


func _ready() -> void:
	player = get_parent() as Player
	for id: StringName in LOADOUT:
		var w := ItemDB.get_item(id) as WeaponData
		weapons.append(w)
		# The sidearm starts loaded; bought weapons come empty (press R).
		_mags.append(w.magazine_size if weapons.size() == 1 else 0)
	_h_mags = _mags.duplicate()
	player.wallet_changed.connect(_on_wallet_changed)


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- Owner -------------------------------------------------------------------------

func can_act() -> bool:
	return not player.dead and equipped and (viewmodel == null or viewmodel.is_drawn())


func is_reloading() -> bool:
	return _reload_end > 0.0


## Owner: does the player carry weapon `index`?
func owns(index: int) -> bool:
	return index >= 0 and index < weapons.size() and slot_of(index) >= 0


## Owner: hotbar slot holding weapon `index`, -1 if not carried.
func slot_of(index: int) -> int:
	for i: int in player.inventory.size():
		if StringName(str((player.inventory[i] as Dictionary).get("id", ""))) == weapons[index].id:
			return i
	return -1


## Owner: LOADOUT index of the weapon in hotbar `slot`, -1 if it holds something else.
func weapon_in_slot(slot: int) -> int:
	if slot < 0 or slot >= player.inventory.size():
		return -1
	return LOADOUT.find(StringName(str((player.inventory[slot] as Dictionary).get("id", ""))))


## Owner: the highlighted hotbar slot (the weapon in hand, else the last picked slot).
func hotbar_slot() -> int:
	if equipped:
		var s: int = slot_of(current)
		if s >= 0:
			return s
	return selected_slot


## Owner: number key `slot` (0-based) pressed. A weapon there -> take it in
## hand (pressing it again puts it away); anything else -> hands free.
func select_slot(slot: int) -> void:
	selected_slot = slot
	var index: int = weapon_in_slot(slot)
	if index < 0:
		set_equipped(false)
	elif index == current and equipped:
		set_equipped(false)
	else:
		select(index)


## Owner: new inventory from the host -> spare rounds; put away a weapon we lost.
func _on_wallet_changed() -> void:
	ammo.clear()
	for it: Dictionary in player.inventory:
		var id: String = str(it.get("id", ""))
		ammo[id] = int(ammo.get(id, 0)) + int(it.get("count", 1))
	if equipped and not owns(current):
		set_equipped(false)
		aiming = false
	weapon_changed.emit()


## True while the sniper scope overlay should be shown.
func is_scoped() -> bool:
	return aiming and equipped and weapon.aim_fov < 20.0 and not is_reloading() and not player.dead


func try_fire() -> void:
	if not can_act() or is_reloading():
		return
	var now: float = _now()
	if now < _next_fire:
		return
	if mag <= 0:
		WeaponFX.play_2d(player, weapon.dry_fire_sound, -4.0)
		_next_fire = now + 0.3
		trigger_held = false
		if reserve > 0:
			try_reload()
		return
	mag -= 1
	_next_fire = now + weapon.fire_interval
	var origin: Vector3 = player.head.global_position
	var dir: Vector3 = _spread(_aim_dir(origin))
	# Own effects right away.
	if viewmodel and not player.third_person and not is_scoped():
		viewmodel.fire(mag == 0)
		WeaponFX.eject_casing(player.get_parent(), viewmodel.ejection_transform(), player.velocity)
	else:
		_hand_fx(mag == 0)
	WeaponFX.play_2d(player, weapon.shot_sounds.pick_random(), -2.0 + weapon.sound_volume_db, 0.04, weapon.sound_pitch)
	for pellet_dir: Vector3 in _pellet_dirs(weapon, dir):
		var hit: Dictionary = _raycast(origin, pellet_dir, weapon)
		if not hit.is_empty():
			WeaponFX.impact(player.get_parent(), hit["position"], hit["normal"], WeaponFX.surface_of(hit["collider"]))
	player.add_recoil(weapon.recoil_pitch * (0.6 if aiming else 1.0), randf_range(-weapon.recoil_yaw, weapon.recoil_yaw))
	_kick = 1.0
	if multiplayer.is_server():
		_host_fire(current, origin, dir)
	else:
		_request_fire.rpc_id(1, current, origin, dir)


func try_reload() -> void:
	if not can_act() or is_reloading() or mag >= weapon.magazine_size or reserve <= 0:
		return
	_reload_end = _now() + weapon.reload_time
	if viewmodel:
		viewmodel.reload(weapon.reload_time)
	WeaponFX.play_2d(player, weapon.reload_sound, -3.0, 0.0, clampf(weapon.sound_pitch * 1.1, 0.8, 1.1))
	_reload_pose = 1.0
	if multiplayer.is_server():
		_host_reload(current)
	else:
		_request_reload.rpc_id(1, current)


## Weapon in hand (true) or holstered (false).
func set_equipped(on: bool) -> void:
	if on and not owns(current):
		# Q with the last weapon gone: take the first one on the hotbar instead.
		for i: int in player.inventory.size():
			if weapon_in_slot(i) >= 0:
				select(weapon_in_slot(i))
				return
		if player.ui:
			player.ui.toast("You have no weapon. Buy one at the gun shop.")
		return
	if on == equipped:
		return
	_cancel_reload()
	equipped = on
	player.net_weapon = current + 1 if on else 0
	if viewmodel:
		viewmodel.set_drawn(on)
	weapon_changed.emit()


## Owner: take weapon `index` (0-based) in hand.
func select(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	if not owns(index):
		if player.ui:
			player.ui.toast("No %s. Buy one at the gun shop." % weapons[index].display_name)
		return
	selected_slot = slot_of(index)
	if index == current:
		set_equipped(true)
		return
	_cancel_reload()
	current = index
	equipped = true
	aiming = false
	player.net_weapon = current + 1
	_next_fire = _now() + 0.35  # draw time
	if viewmodel:
		viewmodel.switch_to(weapon)
	weapon_changed.emit()


## Owner: next / previous weapon (mouse wheel).
func cycle(step: int) -> void:
	var n: int = player.inventory.size()
	if n == 0:
		return
	var s: int = hotbar_slot()
	for k: int in n:
		s = posmod(s + step, n)
		if weapon_in_slot(s) >= 0:
			select(weapon_in_slot(s))
			return


func _cancel_reload() -> void:
	if _reload_end > 0.0:
		_reload_end = 0.0
		if viewmodel:
			viewmodel.cancel_reload()


## Pellet directions around `dir` (one for normal guns).
static func _pellet_dirs(w: WeaponData, dir: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = [dir]
	for i: int in w.pellets - 1:
		out.append(_cone(dir, w.pellet_spread))
	return out


## Random direction inside a cone of `angle` radians around `dir`.
static func _cone(dir: Vector3, angle: float) -> Vector3:
	var right: Vector3 = dir.cross(Vector3.UP).normalized()
	if right.length() < 0.01:
		right = Vector3.RIGHT
	var up: Vector3 = right.cross(dir).normalized()
	var a: float = randf() * TAU
	var r: float = sqrt(randf()) * angle
	return (dir + right * cos(a) * r + up * sin(a) * r).normalized()


## Owner: where the crosshair points, as a direction from the eyes. In third
## person the camera sits behind/right of the head, so aim at what the camera's
## centre ray hits (else bullets would land beside the crosshair).
func _aim_dir(origin: Vector3) -> Vector3:
	var forward: Vector3 = -player.head.global_basis.z
	var cam: Camera3D = player.camera
	if not player.third_person or cam == null:
		return forward
	var from: Vector3 = cam.global_position
	var cam_dir: Vector3 = -cam.global_basis.z
	var to: Vector3 = from + cam_dir * weapon.max_range
	var q := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK, [player.get_rid()])
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	var target: Vector3 = hit["position"] if not hit.is_empty() else to
	# Ignore things between the camera and the player (the head would shoot backwards).
	if (target - origin).dot(cam_dir) < 0.5:
		return cam_dir
	return (target - origin).normalized()


## Random direction inside the current spread cone.
func _spread(dir: Vector3) -> Vector3:
	var s: float = weapon.spread_still
	if aiming and weapon.aim_spread >= 0.0:
		s = weapon.aim_spread
	var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	s = lerpf(s, weapon.spread_moving, clampf(speed / Player.SPRINT_SPEED, 0.0, 1.0))
	if not player.is_on_floor():
		s = weapon.spread_air
	if player.net_crouch:
		s *= 0.6
	return _cone(dir, s)


func _raycast(origin: Vector3, dir: Vector3, w: WeaponData) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * w.max_range, HIT_MASK, [player.get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(q)


func _process(delta: float) -> void:
	# Owner: reload done -> predicted refill (the host confirms with _sync_ammo).
	if _reload_end > 0.0 and _now() >= _reload_end:
		_reload_end = 0.0
		var take: int = mini(weapon.magazine_size - mag, reserve)
		mag += take
		reserve -= take
	if trigger_held and weapon.automatic and player.is_local():
		try_fire()
	_kick = move_toward(_kick, 0.0, 6.0 * delta)
	var reload_len: float = weapons[maxi(0, player.net_weapon - 1)].reload_time
	_reload_pose = move_toward(_reload_pose, 0.0, delta / maxf(0.1, reload_len))


# --- Third-person look (every peer) --------------------------------------------------

func _hand_fx(last_round: bool) -> void:
	var gun: WeaponModel = hand_gun
	if gun == null:
		return
	gun.cycle(last_round)
	WeaponFX.flash(gun.muzzle)
	WeaponFX.eject_casing(player.get_parent(), gun.ejection.global_transform, player.velocity)


## Pose values for the body (Player._update_anim): aim weight and recoil kick.
func body_aim() -> float:
	if player.dead or player.net_weapon == 0:
		return 0.0
	return 1.0 - 0.55 * sin(clampf(_reload_pose, 0.0, 1.0) * PI)


func body_kick() -> float:
	return _kick


# --- Host --------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _request_fire(index: int, origin: Vector3, dir: Vector3) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.peer_id:
		_host_fire(index, origin, dir)


func _host_fire(index: int, origin: Vector3, dir: Vector3) -> void:
	var now: float = _now()
	var reason: String = ""
	if index < 0 or index >= weapons.size():
		return
	var w: WeaponData = weapons[index]
	if player.dead:
		reason = "dead"
	elif player.net_weapon == 0:
		reason = "no weapon out"
	elif not _h_owns(index):
		reason = "weapon not carried"
	elif now - _h_last_fire < w.fire_interval * 0.75:
		reason = "too fast"
	elif now < _h_reload_end:
		reason = "reloading"
	elif _h_mags[index] <= 0:
		reason = "no ammo"
	elif origin.distance_to(player.head.global_position) > 2.0:
		reason = "origin too far from the player"
	if reason != "":
		push_warning("[Combat] %s: shot rejected (%s)" % [player.player_name, reason])
		_send_ammo(index)
		return
	_h_mags[index] -= 1
	_h_last_fire = now
	dir = dir.normalized()
	var ends := PackedVector3Array()
	var normals := PackedVector3Array()
	var surfaces := PackedStringArray()
	# Damage per victim (shotgun pellets add up), headshot if any pellet hit the head.
	var damage: Dictionary = {}
	var heads: Dictionary = {}
	for pellet_dir: Vector3 in _pellet_dirs(w, dir):
		var hit: Dictionary = _raycast(origin, pellet_dir, w)
		if hit.is_empty():
			continue
		var end: Vector3 = hit["position"]
		ends.append(end)
		normals.append(hit["normal"])
		surfaces.append(WeaponFX.surface_of(hit["collider"]))
		var victim: Node = hit["collider"]
		if not victim.has_method("host_damage"):
			continue
		var headshot: bool = victim.call("is_head_hit", end) if victim.has_method("is_head_hit") else false
		damage[victim] = int(damage.get(victim, 0)) + roundi(w.damage * (w.headshot_multiplier if headshot else 1.0))
		heads[victim] = heads.get(victim, false) or headshot
	for victim: Node in damage:
		if victim is Player and (victim as Player).dead:
			continue
		var killed: bool = victim.call("host_damage", int(damage[victim]), player, origin)
		print("[Combat] %s hit %s for %d%s%s" % [player.player_name, victim.get("player_name") if victim is Player else victim.name,
				damage[victim], " (headshot)" if heads[victim] else "", " - killed" if killed else ""])
		if player.peer_id == 1:
			_hit_confirm(heads[victim], killed)
		else:
			_hit_confirm.rpc_id(player.peer_id, heads[victim], killed)
	# Pedestrians nearby react to the bang (host AI).
	get_tree().call_group(&"npc", "hear_gunshot", origin)
	# Everyone else sees and hears the shot.
	for peer: int in [1] + Net.peers_in_world:
		if peer == player.peer_id:
			continue
		if peer == 1:
			_fire_fx(index, origin, ends, normals, surfaces, _h_mags[index] == 0)
		else:
			_fire_fx.rpc_id(peer, index, origin, ends, normals, surfaces, _h_mags[index] == 0)


@rpc("any_peer", "call_remote", "reliable")
func _request_reload(index: int) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.peer_id:
		_host_reload(index)


func _host_reload(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	var w: WeaponData = weapons[index]
	if player.dead or _h_mags[index] >= w.magazine_size or _h_reserve(index) <= 0 or _now() < _h_reload_end \
			or not _h_owns(index):
		_send_ammo(index)
		return
	# A little less than the real time: the owner's clock started earlier.
	_h_reload_end = _now() + w.reload_time * 0.85
	_h_reload_index = index
	for peer: int in [1] + Net.peers_in_world:
		if peer != player.peer_id:
			if peer == 1:
				_reload_fx(index)
			else:
				_reload_fx.rpc_id(peer, index)
	await get_tree().create_timer(w.reload_time * 0.85).timeout
	if not is_inside_tree() or player.dead or _h_reload_index != index:
		return
	_h_reload_index = -1
	if player.net_weapon - 1 != index:
		_h_reload_end = 0.0
		_send_ammo(index)  # switched weapons: reload cancelled
		return
	var take: int = mini(w.magazine_size - _h_mags[index], _h_reserve(index))
	if take > 0 and GameState.remove_item(player.player_name, String(w.ammo_id), take):
		_h_mags[index] += take
		player.send_wallet()
	_send_ammo(index)


## Host: does the player carry weapon `index`?
func _h_owns(index: int) -> bool:
	return GameState.count_item(player.player_name, String(weapons[index].id)) > 0


## Host: spare rounds for weapon `index` in the player's inventory.
func _h_reserve(index: int) -> int:
	return GameState.count_item(player.player_name, String(weapons[index].ammo_id))


## Host, on death (before the inventory goes into the loot bag): the rounds
## loaded in the carried weapons go back into the inventory as ammo items.
func host_unload() -> void:
	for i: int in weapons.size():
		if _h_mags[i] > 0 and _h_owns(i):
			GameState.give(player.player_name, 0, [{"id": String(weapons[i].ammo_id), "count": _h_mags[i]}])
		_h_mags[i] = 0
	_h_reload_end = 0.0
	_h_reload_index = -1


## Host, on respawn: a loaded service pistol plus its starter rounds.
func host_refill() -> void:
	_h_mags[0] = weapons[0].magazine_size
	GameState.give_starter_kit(player.player_name)
	player.send_wallet()
	for i: int in weapons.size():
		_send_ammo(i)
	_h_reload_end = 0.0
	_h_reload_index = -1


func _send_ammo(index: int) -> void:
	if player.peer_id == multiplayer.get_unique_id():
		_sync_ammo(index, _h_mags[index], _h_reserve(index))
	else:
		_sync_ammo.rpc_id(player.peer_id, index, _h_mags[index], _h_reserve(index))


# --- Host -> peers -----------------------------------------------------------------

## Host -> owner: the real ammo count of one weapon.
@rpc("any_peer", "call_remote", "reliable")
func _sync_ammo(index: int, new_mag: int, new_reserve: int) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	if index == current and is_reloading() and new_mag < weapons[index].magazine_size:
		# Our reload has not finished yet: the refill message will come after it.
		return
	_mags[index] = new_mag
	ammo[String(weapons[index].ammo_id)] = new_reserve
	if index == current:
		_reload_end = 0.0


## Host -> shooter: your bullet hit someone.
@rpc("any_peer", "call_remote", "reliable")
func _hit_confirm(headshot: bool, killed: bool) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	player.on_hit_confirmed(headshot, killed)


## Host -> other peers: this player fired (flash, sound, casing, impacts).
@rpc("any_peer", "call_remote", "reliable")
func _fire_fx(index: int, origin: Vector3, ends: PackedVector3Array, normals: PackedVector3Array,
		surfaces: PackedStringArray, last_round: bool) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1] or index < 0 or index >= weapons.size():
		return
	var w: WeaponData = weapons[index]
	_kick = 1.0
	_hand_fx(last_round)
	var listener: Camera3D = player.get_viewport().get_camera_3d()
	var dist: float = listener.global_position.distance_to(origin) if listener else 0.0
	var sounds: Array[AudioStream] = w.shot_far_sounds if dist > FAR_SOUND_DISTANCE else w.shot_sounds
	WeaponFX.play_3d(player.get_parent(), sounds.pick_random(), origin, 4.0 + w.sound_volume_db, 400.0, 0.05, w.sound_pitch)
	for i: int in ends.size():
		WeaponFX.impact(player.get_parent(), ends[i], normals[i], surfaces[i])


## Host -> other peers: this player reloads.
@rpc("any_peer", "call_remote", "reliable")
func _reload_fx(index: int) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1] or index < 0 or index >= weapons.size():
		return
	_reload_pose = 1.0
	WeaponFX.play_3d(player.get_parent(), weapons[index].reload_sound, player.head.global_position, -4.0, 25.0, 0.0,
			clampf(weapons[index].sound_pitch * 1.1, 0.8, 1.1))
