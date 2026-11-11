class_name PlayerCombat
extends Node
## Weapon handling of one player (child "Combat" of Player, exists on every peer).
##
## OWNER: reads input (via Player), predicts ammo and plays its own effects at
## once (viewmodel, sound, casing, impact) so shooting feels instant, then asks
## the host with _request_fire(origin, dir).
## HOST: validates every shot (alive, weapon out, fire rate, ammo, origin near
## the shooter's eyes), does the real raycast, applies damage, and sends the
## effects to the other peers. Ammo on the host is the truth; the owner is
## corrected with _sync_ammo when they differ.
## Lag compensation: none (LAN co-op; the host hits what it sees).

const HIT_MASK: int = 1 | 2 | 4 | 8  # world, doors, npcs, players
const FAR_SOUND_DISTANCE: float = 30.0

var player: Player
var weapon: WeaponData

# Owner (predicted) ammo; on the host for its own player these equal the truth.
var mag: int = 0
var reserve: int = 0
var equipped: bool = true

var viewmodel: Viewmodel      # local player only
var hand_gun: WeaponModel     # third-person gun in the body's right fist (every peer)

var _next_fire: float = 0.0
var _reload_end: float = 0.0  # owner: when the current reload completes (0 = none)
# Host truth.
var _h_mag: int = 0
var _h_reserve: int = 0
var _h_last_fire: float = -10.0
var _h_reload_end: float = 0.0
# Third-person pose (every peer).
var _kick: float = 0.0
var _reload_pose: float = 0.0


func _ready() -> void:
	player = get_parent() as Player
	weapon = ItemDB.get_item(&"pistol") as WeaponData
	mag = weapon.magazine_size
	reserve = weapon.starting_reserve
	_h_mag = mag
	_h_reserve = reserve


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- Owner -------------------------------------------------------------------------

func can_act() -> bool:
	return not player.dead and equipped and (viewmodel == null or viewmodel.is_drawn())


func is_reloading() -> bool:
	return _reload_end > 0.0


func try_fire() -> void:
	if not can_act() or is_reloading():
		return
	var now: float = _now()
	if now < _next_fire:
		return
	if mag <= 0:
		WeaponFX.play_2d(player, weapon.dry_fire_sound, -4.0)
		_next_fire = now + 0.3
		if reserve > 0:
			try_reload()
		return
	mag -= 1
	_next_fire = now + weapon.fire_interval
	var origin: Vector3 = player.head.global_position
	var dir: Vector3 = _spread(-player.head.global_basis.z)
	var hit: Dictionary = _raycast(origin, dir)
	# Own effects right away.
	if viewmodel and not player.third_person:
		viewmodel.fire(mag == 0)
		WeaponFX.eject_casing(player.get_parent(), viewmodel.ejection_transform(), player.velocity)
	else:
		_hand_fx(mag == 0)
	WeaponFX.play_2d(player, weapon.shot_sounds.pick_random(), -2.0)
	if not hit.is_empty():
		WeaponFX.impact(player.get_parent(), hit["position"], hit["normal"], WeaponFX.surface_of(hit["collider"]))
	player.add_recoil(weapon.recoil_pitch, randf_range(-weapon.recoil_yaw, weapon.recoil_yaw))
	_kick = 1.0
	if multiplayer.is_server():
		_host_fire(origin, dir)
	else:
		_request_fire.rpc_id(1, origin, dir)


func try_reload() -> void:
	if not can_act() or is_reloading() or mag >= weapon.magazine_size or reserve <= 0:
		return
	_reload_end = _now() + weapon.reload_time
	if viewmodel:
		viewmodel.reload(weapon.reload_time)
	WeaponFX.play_2d(player, weapon.reload_sound, -3.0, 0.0)
	_reload_pose = 1.0
	if multiplayer.is_server():
		_host_reload()
	else:
		_request_reload.rpc_id(1)


## 1 = pistol in hand, 0 = holstered.
func set_equipped(on: bool) -> void:
	if on == equipped or is_reloading():
		return
	equipped = on
	player.net_weapon = 1 if on else 0
	if viewmodel:
		viewmodel.set_drawn(on)


## Random direction inside the current spread cone.
func _spread(dir: Vector3) -> Vector3:
	var s: float = weapon.spread_still
	var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	s = lerpf(s, weapon.spread_moving, clampf(speed / Player.SPRINT_SPEED, 0.0, 1.0))
	if not player.is_on_floor():
		s = weapon.spread_air
	if player.net_crouch:
		s *= 0.6
	var right: Vector3 = dir.cross(Vector3.UP).normalized()
	if right.length() < 0.01:
		right = Vector3.RIGHT
	var up: Vector3 = right.cross(dir).normalized()
	var a: float = randf() * TAU
	var r: float = sqrt(randf()) * s
	return (dir + right * cos(a) * r + up * sin(a) * r).normalized()


func _raycast(origin: Vector3, dir: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * weapon.max_range, HIT_MASK, [player.get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(q)


func _process(delta: float) -> void:
	# Owner: reload done -> predicted refill (the host confirms with _sync_ammo).
	if _reload_end > 0.0 and _now() >= _reload_end:
		_reload_end = 0.0
		var take: int = mini(weapon.magazine_size - mag, reserve)
		mag += take
		reserve -= take
	_kick = move_toward(_kick, 0.0, 6.0 * delta)
	_reload_pose = move_toward(_reload_pose, 0.0, delta / maxf(0.1, weapon.reload_time))


# --- Third-person look (every peer) --------------------------------------------------

func _hand_fx(last_round: bool) -> void:
	if hand_gun == null:
		return
	hand_gun.cycle(last_round)
	WeaponFX.flash(hand_gun.muzzle)
	WeaponFX.eject_casing(player.get_parent(), hand_gun.ejection.global_transform, player.velocity)


## Pose values for the body (Player._update_anim): aim weight and recoil kick.
func body_aim() -> float:
	if player.dead or player.net_weapon == 0:
		return 0.0
	return 1.0 - 0.55 * sin(clampf(_reload_pose, 0.0, 1.0) * PI)


func body_kick() -> float:
	return _kick


# --- Host --------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _request_fire(origin: Vector3, dir: Vector3) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.peer_id:
		_host_fire(origin, dir)


func _host_fire(origin: Vector3, dir: Vector3) -> void:
	var now: float = _now()
	var reason: String = ""
	if player.dead:
		reason = "dead"
	elif player.net_weapon == 0:
		reason = "no weapon out"
	elif now - _h_last_fire < weapon.fire_interval * 0.75:
		reason = "too fast"
	elif now < _h_reload_end:
		reason = "reloading"
	elif _h_mag <= 0:
		reason = "no ammo"
	elif origin.distance_to(player.head.global_position) > 2.0:
		reason = "origin too far from the player"
	if reason != "":
		push_warning("[Combat] %s: shot rejected (%s)" % [player.player_name, reason])
		_send_ammo()
		return
	_h_mag -= 1
	_h_last_fire = now
	dir = dir.normalized()
	var hit: Dictionary = _raycast(origin, dir)
	var end: Vector3 = origin + dir * weapon.max_range
	var normal := Vector3.ZERO
	var surface: String = ""
	if not hit.is_empty():
		end = hit["position"]
		normal = hit["normal"]
		surface = WeaponFX.surface_of(hit["collider"])
		var victim := hit["collider"] as Player
		if victim and not victim.dead:
			var headshot: bool = end.y - victim.global_position.y > victim.head.position.y - 0.2
			var dmg: int = roundi(weapon.damage * (weapon.headshot_multiplier if headshot else 1.0))
			var killed: bool = victim.host_damage(dmg, player)
			print("[Combat] %s hit %s for %d%s%s" % [player.player_name, victim.player_name, dmg,
					" (headshot)" if headshot else "", " - killed" if killed else ""])
			if player.peer_id == 1:
				_hit_confirm(headshot, killed)
			else:
				_hit_confirm.rpc_id(player.peer_id, headshot, killed)
	# Everyone else sees and hears the shot.
	for peer: int in [1] + Net.peers_in_world:
		if peer == player.peer_id:
			continue
		if peer == 1:
			_fire_fx(origin, end, normal, surface, _h_mag == 0)
		else:
			_fire_fx.rpc_id(peer, origin, end, normal, surface, _h_mag == 0)


@rpc("any_peer", "call_remote", "reliable")
func _request_reload() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.peer_id:
		_host_reload()


func _host_reload() -> void:
	if player.dead or _h_mag >= weapon.magazine_size or _h_reserve <= 0 or _now() < _h_reload_end:
		_send_ammo()
		return
	# A little less than the real time: the owner's clock started earlier.
	_h_reload_end = _now() + weapon.reload_time * 0.85
	for peer: int in [1] + Net.peers_in_world:
		if peer != player.peer_id:
			if peer == 1:
				_reload_fx()
			else:
				_reload_fx.rpc_id(peer)
	await get_tree().create_timer(weapon.reload_time * 0.85).timeout
	if not is_inside_tree() or player.dead:
		return
	var take: int = mini(weapon.magazine_size - _h_mag, _h_reserve)
	_h_mag += take
	_h_reserve -= take
	_send_ammo()


## Host: full magazine and starting reserve (respawn).
func host_refill() -> void:
	_h_mag = weapon.magazine_size
	_h_reserve = weapon.starting_reserve
	_h_reload_end = 0.0
	_send_ammo()


func _send_ammo() -> void:
	if player.peer_id == multiplayer.get_unique_id():
		_sync_ammo(_h_mag, _h_reserve)
	else:
		_sync_ammo.rpc_id(player.peer_id, _h_mag, _h_reserve)


# --- Host -> peers -----------------------------------------------------------------

## Host -> owner: the real ammo count.
@rpc("any_peer", "call_remote", "reliable")
func _sync_ammo(new_mag: int, new_reserve: int) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	if is_reloading() and new_mag < weapon.magazine_size:
		# Our reload has not finished yet: the refill message will come after it.
		return
	mag = new_mag
	reserve = new_reserve
	_reload_end = 0.0


## Host -> shooter: your bullet hit a player.
@rpc("any_peer", "call_remote", "reliable")
func _hit_confirm(headshot: bool, killed: bool) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	player.on_hit_confirmed(headshot, killed)


## Host -> other peers: this player fired (flash, sound, casing, impact).
@rpc("any_peer", "call_remote", "reliable")
func _fire_fx(origin: Vector3, end: Vector3, normal: Vector3, surface: String, last_round: bool) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	_kick = 1.0
	_hand_fx(last_round)
	var listener: Camera3D = player.get_viewport().get_camera_3d()
	var dist: float = listener.global_position.distance_to(origin) if listener else 0.0
	var sounds: Array[AudioStream] = weapon.shot_far_sounds if dist > FAR_SOUND_DISTANCE else weapon.shot_sounds
	WeaponFX.play_3d(player.get_parent(), sounds.pick_random(), origin, 4.0, 400.0, 0.05)
	if surface != "":
		WeaponFX.impact(player.get_parent(), end, normal, surface)


## Host -> other peers: this player reloads.
@rpc("any_peer", "call_remote", "reliable")
func _reload_fx() -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	_reload_pose = 1.0
	WeaponFX.play_3d(player.get_parent(), weapon.reload_sound, player.head.global_position, -4.0, 25.0, 0.0)
