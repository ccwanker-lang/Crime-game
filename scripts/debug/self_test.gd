extends Node
## Headless map checks. Start with:
##   --headless --path . -- --selftest --port=7791
## 1. Lamps: every light in group "street_lights" belongs to a pole prefab that
##    stands on the ground (no floating lamps).
## 2. Doors: opens every NetDoor, then a real player body (player.tscn in auto_walk mode, same
##    movement code as a real player) walks from the street to 2.5 m inside.
##    Also checks that the navigation mesh has a path through the door.
## 3. Debug labels (group "debug_only") are hidden in game.
## 4. Pedestrians: spawns them, runs 90 game-seconds at 3x speed and checks that
##    nobody walks on the road outside a zebra, nobody gets stuck for good, and
##    they wander, idle, sit on benches and visit public buildings.
## 5. Player: jump height, walk/sprint speed, crouch (lower capsule, stays down
##    under a low ceiling, stands up again when it is gone).
## 6. Combat: a shot uses ammo and leaves an impact, reload refills from the
##    reserve, damage lowers health, death drops a loot bag with the cash,
##    respawn at the hospital with full health/ammo, the bag can be picked up.
## 7. Inventory + shops: stacks/slot limits, shopkeepers stand on the floor and can
##    be targeted from the counter, buying pays and fills the inventory, the host
##    refuses too far / not in stock / no cash / full pockets, items drop in the bag.
## 8. Weed growing: pot (soil -> seed -> water -> grow, faster under the lamp ->
##    harvest Fresh Weed), drying rack (hang -> dry -> take Dried Weed), state in GameState.
## Prints "[SelfTest] PASS/FAIL ..." lines and quits.

const WALKER: PackedScene = preload("res://scenes/player/player.tscn")
const LAMP_PREFABS: Array[String] = ["street_lamp.tscn", "floodlight_pole.tscn"]

const CHECKS: Array[String] = ["items", "lamps", "debug_labels", "doors", "player", "held", "stairs", "furniture", "balconies", "combat", "shops", "gun_shop", "black_market", "placement", "storage", "real_estate", "laundering", "growing", "pedestrians", "npc_combat", "police", "regen", "selling", "phone", "traffic", "save"]

var _fails: int = 0
var _corner: Dictionary = {}  # the test weed corner (World.debug_weed_corner), placed once


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState.infinite_cash = false  # test the real money rules
	var world: Node3D = get_parent()
	await _wait_for_navmesh(world)
	# --only=stairs,traffic runs just those checks (names = the _check_* suffix).
	var only: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	for check: String in CHECKS:
		if only.is_empty() or check in only:
			await call("_check_" + check, world)
	print("[SelfTest] Done: %s" % ("ALL PASSED" if _fails == 0 else "%d FAILED" % _fails))
	Net.leave_game()
	get_tree().quit(1 if _fails > 0 else 0)


func _report(ok: bool, text: String) -> void:
	print("[SelfTest] %s %s" % ["PASS" if ok else "FAIL", text])
	if not ok:
		_fails += 1


func _wait_for_navmesh(world: Node3D) -> void:
	var region: NavigationRegion3D = world.get_node("NavRegion")
	var map: RID = region.get_navigation_map()
	for i: int in 600:
		if NavigationServer3D.map_get_iteration_id(map) > 0 and region.navigation_mesh.get_polygon_count() > 0:
			break
		await get_tree().physics_frame
	for i: int in 10:
		await get_tree().physics_frame


# --- Items -----------------------------------------------------------------------

## Every item has a 3D model (held / dropped) and a rendered icon (scripts/debug/render_icons.gd).
func _check_items(_world: Node3D) -> void:
	var missing: PackedStringArray = []
	var ids: Array = ItemDB.get_all_ids()
	for id: StringName in ids:
		var data: ItemData = ItemDB.get_item(id)
		if data.get_model() == null:
			missing.append("%s (model)" % id)
		if data.get_icon() == null:
			missing.append("%s (icon)" % id)
	_report(missing.is_empty(), "%d items have a model and an icon%s" % [ids.size(),
			"" if missing.is_empty() else ", missing: " + ", ".join(missing)])


## Point 5: an item in the selected hotbar slot is held in the hand (body + first-person
## copy); drawing a weapon puts it away.
func _check_held(world: Node3D) -> void:
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Holder"
	world.get_node("Players").add_child(p)
	p.global_position = Vector3(-8, 0.3, -4.6)
	for i: int in 30:
		await get_tree().physics_frame
	p._set_wallet(100, [{"id": "pistol", "count": 1}, {"id": "watering_can", "count": 1}])
	p.combat.select_slot(1)
	for i: int in 3:
		await get_tree().process_frame
	var body: Node3D = p.get_node_or_null("HeldItem") as Node3D
	var near: bool = body != null and body.global_position.distance_to(p.global_position + Vector3.UP * 0.9) < 0.9
	_report(p.net_held == &"watering_can" and near and p._held_view != null,
			"selected item is held in the hand (held '%s', body model %s)" % [p.net_held, body != null])
	p.combat.select_slot(0)
	for i: int in 3:
		await get_tree().process_frame
	_report(p.net_held == &"" and p.get_node_or_null("HeldItem") == null and p.net_weapon == 1,
			"drawing the pistol puts the item away")
	p.queue_free()
	await get_tree().physics_frame


# --- Lamps -----------------------------------------------------------------------

func _check_lamps(world: Node3D) -> void:
	var space := world.get_world_3d().direct_space_state
	var count: int = 0
	for light: Node in get_tree().get_nodes_in_group("street_lights"):
		count += 1
		var root: Node3D = light.get_parent() as Node3D
		var prefab: String = root.scene_file_path.get_file() if root else ""
		if not prefab in LAMP_PREFABS:
			_report(false, "lamp %s is not in a pole prefab (%s)" % [light.get_path(), prefab])
			continue
		# Pole foot must touch the ground: ray down from 0.5 m above the origin.
		var from: Vector3 = root.global_position + Vector3.UP * 0.5
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.0, 1)
		q.exclude = [(root as CollisionObject3D).get_rid()] if root is CollisionObject3D else []
		var hit: Dictionary = space.intersect_ray(q)
		var gap: float = (from.y - 0.5 - (hit["position"] as Vector3).y) if not hit.is_empty() else INF
		if absf(gap) > 0.05:
			_report(false, "lamp %s at %s floats %.2f m above the ground" % [root.name, root.global_position, gap])
	_report(true, "checked %d lamps" % count)


# --- Debug labels ------------------------------------------------------------------

func _check_debug_labels(_world: Node3D) -> void:
	var shown: int = 0
	var nodes: Array[Node] = get_tree().get_nodes_in_group("debug_only")
	for n: Node in nodes:
		if (n as Node3D).is_visible_in_tree():
			shown += 1
			_report(false, "debug label visible in game: %s" % n.get_path())
	_report(shown == 0 and not nodes.is_empty(), "%d debug labels hidden in game" % nodes.size())


# --- Doors -----------------------------------------------------------------------

func _check_doors(world: Node3D) -> void:
	var doors: Array[Node] = world.find_children("*", "NetDoor", true, false)
	_report(not doors.is_empty(), "found %d doors" % doors.size())
	var map: RID = (world.get_node("NavRegion") as NavigationRegion3D).get_navigation_map()
	for d: Node in doors:
		var door := d as NetDoor
		if door.name.begins_with("BalconyDoor"):
			continue  # upstairs, see _check_balconies
		var building: String = door.get_parent().name
		door._set_open(true)
		await get_tree().create_timer(0.7).timeout

		var out: Vector3 = door.global_basis.z.normalized()
		var center: Vector3 = door.global_position + door.global_basis.x.normalized() * door.width / 2.0
		center.y = door.global_position.y
		var start: Vector3 = center + out * 1.6
		var inside: Vector3 = center - out * 2.5

		var walker: CharacterBody3D = WALKER.instantiate()
		walker.set("auto_walk", true)
		walker.set("auto_target", inside)
		world.add_child(walker)
		walker.global_position = start + Vector3.UP * 0.1
		var ok: bool = false
		for i: int in 360:  # 6 s
			await get_tree().physics_frame
			var p: Vector3 = walker.global_position
			if Vector2(p.x - inside.x, p.z - inside.z).length() < 0.4:
				ok = true
				break
		var end: Vector3 = walker.global_position
		walker.queue_free()
		_report(ok, "walk through %s/%s (ended %.1f m from target)" % [building, door.name,
				Vector2(end.x - inside.x, end.z - inside.z).length()])

		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, start, inside, true)
		var reached: bool = not path.is_empty() and path[path.size() - 1].distance_to(inside) < 0.6
		var detour: float = 0.0
		for i: int in range(1, path.size()):
			detour += path[i].distance_to(path[i - 1])
		# A path that goes in through the door is about 4 m long, not a detour.
		# Only buildings NPCs walk into need it (private houses are for players).
		if door.is_in_group(&"public_door") or building == "StarterRoom":
			_report(reached and detour < 6.0, "navmesh through %s/%s (path %.1f m)" % [building, door.name, detour])

		door._set_open(false)
		await get_tree().create_timer(0.6).timeout
		# Closed door must block.
		walker = WALKER.instantiate()
		walker.set("auto_walk", true)
		walker.set("auto_target", inside)
		world.add_child(walker)
		walker.global_position = start + Vector3.UP * 0.1
		for i: int in 180:
			await get_tree().physics_frame
		var p2: Vector3 = walker.global_position
		walker.queue_free()
		_report((p2 - center).dot(out) > 0.0, "closed %s/%s blocks the walker" % [building, door.name])


# --- Player ---------------------------------------------------------------------

func _check_player(world: Node3D) -> void:
	var start: Vector3 = (world.get_node("Markers/SpawnPoints").get_child(0) as Node3D).global_position
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.auto_target = start
	world.add_child(p)
	p.global_position = start + Vector3.UP * 0.1
	for i: int in 30:
		await get_tree().physics_frame
	var ground: float = p.global_position.y

	# Jump: peak height.
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	var peak: float = ground
	for i: int in 90:
		await get_tree().physics_frame
		peak = maxf(peak, p.global_position.y)
	_report(peak - ground > 0.9 and peak - ground < 1.5, "player jumps %.2f m high" % (peak - ground))

	# Walk and sprint speed along the sidewalk.
	for sprint: bool in [false, true]:
		if sprint:
			Input.action_press("sprint")
		var from: Vector3 = p.global_position
		p.auto_target = from + Vector3(-30, 0, 0)
		for i: int in 60:  # 1 s
			await get_tree().physics_frame
		var a: Vector3 = p.global_position
		for i: int in 60:
			await get_tree().physics_frame
		var speed: float = Vector2(p.global_position.x - a.x, p.global_position.z - a.z).length()
		var want: float = Player.SPRINT_SPEED if sprint else Player.WALK_SPEED
		_report(absf(speed - want) < 0.6, "player %s speed %.1f m/s (expected %.1f)" % ["sprint" if sprint else "walk", speed, want])
		Input.action_release("sprint")
		p.auto_target = p.global_position

	# Crouch under a low ceiling: must stay down until the ceiling is gone.
	for i: int in 20:
		await get_tree().physics_frame
	Input.action_press("crouch")
	for i: int in 30:
		await get_tree().physics_frame
	var shape := p.get_node("Collision").shape as CapsuleShape3D
	var head_y: float = (p.get_node("Head") as Node3D).position.y
	_report(p.net_crouch and shape.height < 1.3 and head_y < 1.2, "player crouches (capsule %.2f m, eyes %.2f m)" % [shape.height, head_y])
	var ceiling := StaticBody3D.new()
	var box := CollisionShape3D.new()
	box.shape = BoxShape3D.new()
	(box.shape as BoxShape3D).size = Vector3(3, 0.2, 3)
	ceiling.add_child(box)
	world.add_child(ceiling)
	ceiling.global_position = p.global_position + Vector3.UP * 1.45
	await get_tree().physics_frame
	Input.action_release("crouch")
	for i: int in 30:
		await get_tree().physics_frame
	_report(p.net_crouch, "player stays crouched under a 1.35 m ceiling")
	ceiling.queue_free()
	for i: int in 30:
		await get_tree().physics_frame
	_report(not p.net_crouch and shape.height > 1.7, "player stands up when there is room")
	p.queue_free()
	await get_tree().physics_frame


# --- Houses: stairs + furniture ----------------------------------------------------

func _check_stairs(world: Node3D) -> void:
	var houses: Array[Building] = []
	for n: Node in world.find_children("*", "Building", true, false):
		var bld := n as Building
		if bld.enterable and bld.upper_floors and bld.floors > 1:
			houses.append(bld)
	var all: int = world.find_children("*", "Building", true, false).size()
	_report(houses.size() >= 20, "%d of %d buildings have walkable upper floors" % [houses.size(), all])
	if houses.is_empty():
		return
	var furnished: int = 0
	for h: Building in houses:
		for c: Node in h.get_children():
			if c.scene_file_path.begins_with(Building.FURNITURE_DIR):
				furnished += 1
				break
	_report(furnished == houses.size(), "every walkable house has furniture (%d/%d)" % [furnished, houses.size()])
	# A walker climbs every flight of every walkable house and comes back down:
	# up the flight, round the railing to the next flight, ..., then all the way down.
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Climber"
	world.get_node("Players").add_child(p)
	Engine.time_scale = 3.0
	var failed: PackedStringArray = []
	var flights: int = 0
	for h: Building in houses:
		var ok: bool = await _climb(p, h)
		flights += (h.floors - 1) * 2
		if not ok:
			failed.append(str(h.name))
	Engine.time_scale = 1.0
	_report(failed.is_empty(), "player walks every stair up and down (%d flights in %d houses)%s" % [flights, houses.size(),
			"" if failed.is_empty() else ", stuck in: " + ", ".join(failed)])
	p.queue_free()
	await get_tree().physics_frame
	# NPCs: the navmesh goes up the stairs too (path from the ground floor to the top floor).
	var map: RID = world.get_world_3d().navigation_map
	var nav_ok: int = 0
	for h: Building in houses:
		var x: float = -h.width / 2.0 + Building.WALL_T + Building.STAIR_W / 2.0
		var z0: float = -h.depth + Building.WALL_T
		var front: float = z0 + Building.LANDING + h._stair_run()
		var from: Vector3 = h.to_global(Vector3(x, Building.SLAB_TOP, front + 0.8))
		var to: Vector3 = h.to_global(Vector3(x, (h.floors - 1) * h.floor_height + Building.SLAB_TOP, z0 + 0.5))
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, to, true)
		if path.size() > 1 and path[path.size() - 1].distance_to(to) < 0.6:
			nav_ok += 1
		else:
			print("[SelfTest]   no NPC path up the stairs of %s (%s)" % [h.name, path[path.size() - 1] if path.size() > 0 else "none"])
			for f: int in range(1, h.floors):
				var lvl: Vector3 = h.to_global(Vector3(x, f * h.floor_height + Building.SLAB_TOP, z0 + 0.5))
				var pp: PackedVector3Array = NavigationServer3D.map_get_path(map, from, lvl, true)
				var near: Vector3 = NavigationServer3D.map_get_closest_point(map, lvl)
				print("[SelfTest]     floor %d: path end local %s, closest navmesh %s" % [f,
						h.to_local(pp[pp.size() - 1]) if pp.size() > 0 else "none", h.to_local(near)])
	_report(nav_ok == houses.size(), "NPC navmesh reaches the top floor of every house (%d/%d)" % [nav_ok, houses.size()])


## Balconies: the door opens (E), a walker steps out onto the balcony, can't get off it
## (front or sides) and walks back in; the closed door blocks.
func _check_balconies(world: Node3D) -> void:
	var doors: Array[NetDoor] = []
	for d: Node in world.find_children("BalconyDoor*", "NetDoor", true, false):
		doors.append(d as NetDoor)
	_report(doors.size() >= 3, "found %d balcony doors" % doors.size())
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Balcony"
	world.get_node("Players").add_child(p)
	var bad: PackedStringArray = []
	for door: NetDoor in doors:
		var h: String = door.get_parent().name
		door._set_open(true)
		await get_tree().create_timer(0.7).timeout
		var out: Vector3 = door.global_basis.z.normalized()
		var side: Vector3 = door.global_basis.x.normalized()
		var centre: Vector3 = door.global_position + side * door.width / 2.0
		var floor_y: float = door.global_position.y
		var inside: Vector3 = centre - out * 1.3
		var on_balcony: Vector3 = centre + out * 0.75
		p.teleport(inside + Vector3.UP * 0.1)
		for i: int in 5:
			await get_tree().physics_frame
		if not await _walk_to(p, on_balcony, 5.0):
			bad.append("%s: can't step out (at %s)" % [h, p.global_position.snapped(Vector3.ONE * 0.01)])
			door._set_open(false)
			continue
		var off: bool = false
		for target: Vector3 in [centre + out * 4.0, on_balcony + side * 4.0, on_balcony - side * 4.0]:
			await _walk_to(p, target, 2.5)
			var rel: Vector3 = p.global_position - centre
			if p.global_position.y < floor_y - 0.5 or rel.dot(out) > 1.05:
				off = true
				bad.append("%s: walker got off the balcony at %s" % [h, p.global_position.snapped(Vector3.ONE * 0.01)])
				break
		if off:
			door._set_open(false)
			continue
		if not await _walk_to(p, inside, 5.0):
			bad.append("%s: can't walk back in" % h)
		door._set_open(false)
		await get_tree().create_timer(0.7).timeout
		await _walk_to(p, on_balcony, 2.5)
		if (p.global_position - centre).dot(out) > -0.1:
			bad.append("%s: closed balcony door doesn't block" % h)
	p.queue_free()
	await get_tree().physics_frame
	_report(bad.is_empty(), "balconies: step out, can't fall off, back in, closed door blocks (%d)%s" % [doors.size(),
			"" if bad.is_empty() else ": " + "; ".join(bad)])


## Walks the auto-walker to the global point `t` (xz); false if it doesn't get there in time.
func _walk_to(p: Player, t: Vector3, timeout: float) -> bool:
	p.auto_target = t
	var waited: float = 0.0
	while waited < timeout:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		if Vector2(p.global_position.x - t.x, p.global_position.z - t.z).length() < 0.3:
			return true
	return false


## Every walkable floor of every enterable building has some furniture (no empty rooms).
func _check_furniture(world: Node3D) -> void:
	var empty: PackedStringArray = []
	var total: int = 0
	for n: Node in world.find_children("*", "Building", true, false):
		var h := n as Building
		if not h.enterable:
			continue
		var levels: int = h.floors if h.upper_floors else 1
		var counts: Array[int] = []
		counts.resize(levels)
		counts.fill(0)
		for c: Node in h.get_children():
			if c is Node3D and (c.scene_file_path.begins_with(Building.FURNITURE_DIR) or c.scene_file_path.begins_with(Building.PROPS_DIR)
					or c.scene_file_path.begins_with("res://prefabs/stations/")):
				var f: int = clampi(floori(((c as Node3D).position.y + 0.2) / h.floor_height), 0, levels - 1)
				counts[f] += 1
		# Owned properties: their furniture became placed objects (point 17).
		for c: Node in world.get_node("Placed").get_children():
			var lp: Vector3 = h.to_local((c as Node3D).global_position)
			if absf(lp.x) < h.width * 0.5 and lp.z < 0.0 and lp.z > -h.depth and lp.y > -0.3 and lp.y < h.get_height():
				counts[clampi(floori((lp.y + 0.2) / h.floor_height), 0, levels - 1)] += 1
		for f: int in levels:
			total += 1
			if counts[f] < (6 if h.furnish == "home" else 3):
				empty.append("%s floor %d (%d pieces)" % [h.name, f, counts[f]])
	_report(empty.is_empty(), "every walkable floor has furniture (%d floors)%s" % [total,
			"" if empty.is_empty() else ", nearly empty: " + ", ".join(empty)])


## Walks `target` (local to the house) with the auto-walker; false if it doesn't get there.
func _walk(p: Player, h: Building, target: Vector3, timeout: float = 6.0) -> bool:
	var t: Vector3 = h.to_global(target)
	p.auto_target = t
	var waited: float = 0.0
	while waited < timeout:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		var d := Vector2(p.global_position.x - t.x, p.global_position.z - t.z)
		if d.length() < 0.3:
			return true
	return false


func _climb(p: Player, h: Building) -> bool:
	var x: float = -h.width / 2.0 + Building.WALL_T + Building.STAIR_W / 2.0
	var sx: float = -h.width / 2.0 + Building.WALL_T + Building.STAIR_W
	var z0: float = -h.depth + Building.WALL_T
	var front: float = z0 + Building.LANDING + h._stair_run()
	var side: float = sx + 0.45  # beside the stairwell (outside the railing)
	p.auto_target = h.to_global(Vector3(x, 0.3, front + 0.8))
	p.teleport(p.auto_target)
	for i: int in 5:
		await get_tree().physics_frame
	var levels: int = h.floors - 1
	# Up.
	for f: int in levels:
		if f > 0:
			# From the back landing round the railing to the front of the next flight.
			if not (await _walk(p, h, Vector3(side, 0, z0 + 0.5)) and await _walk(p, h, Vector3(side, 0, front + 0.8))
					and await _walk(p, h, Vector3(x, 0, front + 0.8))):
				print("[SelfTest]   %s: can't get round to flight %d (at %s)" % [h.name, f + 1, h.to_local(p.global_position)])
				return false
		if not await _walk(p, h, Vector3(x, 0, z0 + 0.4)):
			print("[SelfTest]   %s: stuck going up flight %d at %s" % [h.name, f + 1, h.to_local(p.global_position)])
			return false
		var up: float = h.to_local(p.global_position).y
		if absf(up - ((f + 1) * h.floor_height + Building.SLAB_TOP)) > 0.25:
			print("[SelfTest]   %s: flight %d ends at height %.2f" % [h.name, f + 1, up])
			return false
	# Down.
	for f: int in range(levels - 1, -1, -1):
		if not await _walk(p, h, Vector3(x, 0, front + 0.8)):
			print("[SelfTest]   %s: stuck going down flight %d at %s" % [h.name, f + 1, h.to_local(p.global_position)])
			return false
		var down: float = h.to_local(p.global_position).y
		if absf(down - (f * h.floor_height + Building.SLAB_TOP)) > 0.25:
			print("[SelfTest]   %s: went down flight %d to height %.2f" % [h.name, f + 1, down])
			return false
		if f > 0:
			if not (await _walk(p, h, Vector3(side, 0, front + 0.8)) and await _walk(p, h, Vector3(side, 0, z0 + 0.5))
					and await _walk(p, h, Vector3(x, 0, z0 + 0.4))):
				print("[SelfTest]   %s: can't get back to flight %d (at %s)" % [h.name, f, h.to_local(p.global_position)])
				return false
	return true


# --- Combat ---------------------------------------------------------------------

func _check_combat(world: Node3D) -> void:
	var start: Vector3 = (world.get_node("Markers/SpawnPoints").get_child(0) as Node3D).global_position
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.auto_target = start
	p.name = "1"
	p.player_name = "Tester"
	world.get_node("Players").add_child(p)
	p.global_position = start + Vector3.UP * 0.1
	for i: int in 40:
		await get_tree().physics_frame
	var c: PlayerCombat = p.combat

	# Shoot at the ground in front of the feet.
	p.head.rotation.x = -1.3
	var decals_before: int = world.find_children("*", "Decal", true, false).size()
	c.try_fire()
	await get_tree().physics_frame
	var decals: int = world.find_children("*", "Decal", true, false).size()
	_report(c.mag == c.weapon.magazine_size - 1 and c._h_mag == c.mag, "shot uses one round (mag %d, host %d)" % [c.mag, c._h_mag])
	_report(decals > decals_before, "shot leaves a bullet hole decal")

	# Reload: back to a full magazine, the reserve pays for it.
	await get_tree().create_timer(0.3).timeout
	c.try_reload()
	_report(c.is_reloading(), "reload starts")
	await get_tree().create_timer(c.weapon.reload_time + 0.3).timeout
	_report(c.mag == c.weapon.magazine_size and c.reserve == c.weapon.starting_reserve - 1
			and GameState.count_item(p.player_name, String(c.weapon.ammo_id)) == c.reserve,
			"reload refills from the ammo items (mag %d, reserve %d)" % [c.mag, c.reserve])

	# Damage and death.
	p.host_damage(30, null)
	_report(p.health == Player.MAX_HEALTH - 30, "damage lowers health to %d" % p.health)
	var cash: int = int(GameState.get_or_create_player_data(p.player_name)["cash"])
	var death_pos: Vector3 = p.global_position
	p.host_damage(200, null)
	await get_tree().physics_frame
	var bags: Array[Node] = world.get_node("Loot").get_children()
	_report(p.dead and p.collision_layer == 0, "player dies at 0 health (not solid while dead)")
	await get_tree().create_timer(2.0).timeout
	_report(p._ragdoll.running and p._ragdoll.head_height() < p.global_position.y + 0.6,
			"dead player falls as a ragdoll (head %.2f m above the feet)" % (p._ragdoll.head_height() - p.global_position.y))
	_report(bags.size() == 1 and (bags[0] as LootBag).cash == cash and cash > 0,
			"death drops a loot bag with the cash (€%d)" % cash)
	_report(int(GameState.get_or_create_player_data(p.player_name)["cash"]) == 0, "dead player's cash is in the bag, not on him")

	# Respawn at the hospital.
	await get_tree().create_timer(Player.RESPAWN_TIME + 0.5).timeout
	_report(not p.dead and p.health == Player.MAX_HEALTH and c.mag == c.weapon.magazine_size
			and c.reserve == c.weapon.starting_reserve, "respawn with full health and ammo")
	var near_spawn: bool = false
	for sp: Node in world.get_node("Markers/SpawnPoints").get_children():
		if (sp as Node3D).global_position.distance_to(p.global_position) < 1.0:
			near_spawn = true
	_report(near_spawn, "respawned at a hospital spawn point %s" % p.global_position.snapped(Vector3.ONE * 0.1))
	_report(not p._ragdoll.running, "ragdoll gone after the respawn")

	# Pick the bag up again.
	p.teleport(death_pos + Vector3(1.0, 0.1, 0))
	await get_tree().physics_frame
	if not bags.is_empty() and is_instance_valid(bags[0]):
		(bags[0] as LootBag).interact()
	await get_tree().physics_frame
	_report(int(GameState.get_or_create_player_data(p.player_name)["cash"]) == cash and world.get_node("Loot").get_child_count() == 0,
			"loot bag pickup gives the cash back and removes the bag")
	p.queue_free()
	await get_tree().physics_frame


# --- Inventory + shops --------------------------------------------------------------

func _check_shops(world: Node3D) -> void:
	# Inventory rules (GameState, host side).
	GameState.player_data.erase("InvTest")
	(GameState.get_or_create_player_data("InvTest")["inventory"] as Array).clear()  # no starter rounds
	var left: Array = GameState.give("InvTest", 0, [{"id": "weed_seed", "count": 25}, {"id": "watering_can", "count": 2}])
	var inv: Array = GameState.get_or_create_player_data("InvTest")["inventory"]
	_report(inv.size() == 4 and left.is_empty() and GameState.count_item("InvTest", "weed_seed") == 25,
			"stacks split at max_stack (25 seeds + 2 cans = 4 slots, got %d)" % inv.size())
	left = GameState.give("InvTest", 0, [{"id": "soil", "count": 1000}])
	_report(inv.size() == GameState.INVENTORY_SLOTS and not left.is_empty(), "inventory stops at %d slots" % GameState.INVENTORY_SLOTS)
	_report(GameState.remove_item("InvTest", "weed_seed", 22) and GameState.count_item("InvTest", "weed_seed") == 3
			and not GameState.remove_item("InvTest", "weed_seed", 4), "remove_item takes items, refuses more than carried")
	GameState.player_data.erase("InvTest")

	var keepers: Dictionary = {}
	for n: Node in world.find_children("*", "Node3D", true, false):
		if n is Shopkeeper:
			keepers[(n as Shopkeeper).shop_name] = n
	_report(keepers.has("Store") and keepers.has("Contact"), "shopkeepers in the store and contact hideout (%s)" % ", ".join(keepers.keys()))
	if not (keepers.has("Store") and keepers.has("Contact")):
		return
	var space := world.get_world_3d().direct_space_state
	for k: Shopkeeper in keepers.values():
		var q := PhysicsRayQueryParameters3D.create(k.global_position + Vector3.UP * 0.3, k.global_position + Vector3.DOWN * 0.5, 1)
		var hit: Dictionary = space.intersect_ray(q)
		var gap: float = k.global_position.y - (hit["position"] as Vector3).y if not hit.is_empty() else INF
		_report(absf(gap) < 0.05, "%s stands on the floor (gap %.2f)" % [k.npc_name, gap])
		# A player 1.4 m in front of the NPC (across the counter) can target it.
		var front: Vector3 = k.global_position - k.global_basis.z * 1.4
		var eye: Vector3 = front + Vector3.UP * Player.EYE_STAND
		var ray := PhysicsRayQueryParameters3D.create(eye, k.global_position + Vector3.UP * 1.4, 1 | 2)
		var h: Dictionary = space.intersect_ray(ray)
		var target: Node = h.get("collider") as Node
		_report(target != null and target.get_parent() == k, "%s can be targeted from the front (hit %s)" % [k.npc_name,
				target.name if target else "nothing"])

	# Buying with a real player body.
	var clerk: Shopkeeper = keepers["Store"]
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Shopper"
	var front_pos: Vector3 = clerk.global_position - clerk.global_basis.z * 1.6
	p.auto_target = front_pos
	world.get_node("Players").add_child(p)
	p.global_position = front_pos + Vector3.UP * 0.1
	for i: int in 20:
		await get_tree().physics_frame
	GameState.player_data.erase("Shopper")
	var cash0: int = int(GameState.get_or_create_player_data("Shopper")["cash"])
	var results: Array = []
	clerk.buy_result.connect(func(ok: bool, msg: String) -> void: results.append([ok, msg]))
	clerk.request_buy(&"soil", 5)
	await get_tree().physics_frame
	var paid: int = cash0 - int(GameState.get_or_create_player_data("Shopper")["cash"])
	_report(results.size() == 1 and results[0][0] and paid == clerk.price_of(&"soil") * 5
			and GameState.count_item("Shopper", "soil") == 5 and p.inventory.size() == 3,
			"buy 5 soil: paid €%d, owner inventory %s" % [paid, p.inventory])
	clerk.request_buy(&"weed_seed", 1)
	_report(results.size() == 2 and not results[1][0], "clerk refuses items he doesn't stock (%s)" % results[1][1])
	GameState.get_or_create_player_data("Shopper")["cash"] = 3
	clerk.request_buy(&"baggie", 5)
	_report(results.size() == 3 and not results[2][0] and GameState.count_item("Shopper", "baggie") == 0,
			"no sale without enough cash (%s)" % results[2][1])
	GameState.get_or_create_player_data("Shopper")["cash"] = 100000
	GameState.give("Shopper", 0, [{"id": "soil", "count": 1000}])
	clerk.request_buy(&"watering_can", 1)
	_report(results.size() == 4 and not results[3][0], "no sale with full pockets (%s)" % results[3][1])
	GameState.player_data.erase("Shopper")
	p.teleport(front_pos + Vector3(0, 0.1, 8.0))
	await get_tree().physics_frame
	clerk.request_buy(&"soil", 1)
	_report(results.size() == 5 and not results[4][0], "no sale from too far away (%s)" % results[4][1])

	# Seeds from the contact, then die: the items go into the loot bag.
	var contact: Shopkeeper = keepers["Contact"]
	var c_front: Vector3 = contact.global_position - contact.global_basis.z * 1.2
	p.teleport(c_front + Vector3.UP * 0.1)
	await get_tree().physics_frame
	contact.request_buy(&"weed_seed", 5)
	_report(GameState.count_item("Shopper", "weed_seed") == 5, "contact sells weed seeds")
	p.host_damage(500, null)
	await get_tree().physics_frame
	var bag: LootBag = null
	for b: Node in world.get_node("Loot").get_children():
		bag = b as LootBag
	var seeds_in_bag: int = 0
	if bag:
		for it: Dictionary in bag.items:
			if it["id"] == "weed_seed":
				seeds_in_bag += int(it["count"])
	_report(bag != null and seeds_in_bag == 5 and p.inventory.is_empty(), "death puts carried items in the loot bag")
	await get_tree().create_timer(Player.RESPAWN_TIME + 0.5).timeout
	if bag:
		bag.queue_free()
	p.queue_free()
	await get_tree().physics_frame


# --- Gun shop -------------------------------------------------------------------------

func _check_gun_shop(world: Node3D) -> void:
	var dealer: Shopkeeper = null
	for n: Node in world.find_children("*", "Node3D", true, false):
		if n is Shopkeeper and (n as Shopkeeper).shop_name == "Gun Shop":
			dealer = n as Shopkeeper
	_report(dealer != null, "gun shop dealer exists")
	if dealer == null:
		return
	var front_pos: Vector3 = dealer.global_position - dealer.global_basis.z * 1.6
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Gunner"
	p.auto_target = front_pos
	GameState.player_data.erase("Gunner")
	world.get_node("Players").add_child(p)
	p.global_position = front_pos + Vector3.UP * 0.1
	for i: int in 20:
		await get_tree().physics_frame
	var c: PlayerCombat = p.combat
	var ak: int = PlayerCombat.LOADOUT.find(&"ak47")
	c.select(ak)
	_report(c.current == 0, "can't draw an AK-47 you don't carry")
	GameState.get_or_create_player_data("Gunner")["cash"] = 10000
	var results: Array = []
	dealer.buy_result.connect(func(ok: bool, msg: String) -> void: results.append([ok, msg]))
	dealer.request_buy(&"ak47", 1)
	dealer.request_buy(&"ak47", 1)
	dealer.request_buy(&"ammo_762", 1)
	await get_tree().physics_frame
	_report(results.size() == 3 and results[0][0] and not results[1][0] and results[2][0]
			and GameState.count_item("Gunner", "ak47") == 1 and GameState.count_item("Gunner", "ammo_762") == 30,
			"buy an AK-47 (only one) and a box of 30 rounds: %s" % [results])
	var ak_slot: int = c.slot_of(ak)
	c.select_slot(ak_slot)
	await get_tree().create_timer(0.5).timeout
	_report(c.current == ak and p.net_weapon == ak + 1 and c.mag == 0 and c.reserve == 30,
			"bought AK-47 drawn, empty magazine, 30 spare (mag %d, reserve %d)" % [c.mag, c.reserve])
	c.try_reload()
	await get_tree().create_timer(c.weapon.reload_time + 0.3).timeout
	_report(c.mag == 30 and c.reserve == 0 and GameState.count_item("Gunner", "ammo_762") == 0 and c._h_mag == 30,
			"reload loads the ammo items into the AK (mag %d, reserve %d)" % [c.mag, c.reserve])
	p.head.rotation.x = -1.3
	c.try_fire()
	await get_tree().physics_frame
	_report(c.mag == 29 and c._h_mag == 29, "AK fires (mag %d)" % c.mag)
	p.host_damage(500, null)
	await get_tree().physics_frame
	var bag: LootBag = null
	for b: Node in world.get_node("Loot").get_children():
		bag = b as LootBag
	var got: Dictionary = {}
	if bag:
		for it: Dictionary in bag.items:
			got[it["id"]] = int(got.get(it["id"], 0)) + int(it["count"])
	_report(got.get("ak47", 0) == 1 and got.get("ammo_762", 0) == 29 and got.get("pistol", 0) == 1
			and not c.equipped and p.net_weapon == 0,
			"death: the guns + loaded rounds go into the bag, hands empty (%s)" % got)
	await get_tree().create_timer(Player.RESPAWN_TIME + 0.5).timeout
	_report(c.owns(0) and c._mags[0] == c.weapons[0].magazine_size and int(c.ammo.get("ammo_9mm", 0)) == c.weapons[0].starting_reserve,
			"respawn: loaded pistol + %d starter rounds" % int(c.ammo.get("ammo_9mm", 0)))
	c.select_slot(c.slot_of(0))
	_report(c.equipped and c.current == 0 and c.hotbar_slot() == c.slot_of(0), "hotbar key draws the pistol")
	c.select_slot(c.slot_of(0))
	_report(not c.equipped, "same hotbar key again puts it away")
	if bag:
		bag.queue_free()
	p.queue_free()
	GameState.player_data.erase("Gunner")
	await get_tree().physics_frame


# --- Black market (point 7) ----------------------------------------------------------

func _check_black_market(world: Node3D) -> void:
	var garage := world.find_child("Garage", true, false) as Building
	var gate: NightGate = garage.find_child("MarketGate", true, false) as NightGate if garage else null
	var rook: Shopkeeper = garage.find_child("BlackMarket", true, false) as Shopkeeper if garage else null
	_report(gate != null and rook != null and rook.night_only, "garage with a locked gate and Rook (night only)")
	if gate == null or rook == null:
		return
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Night"
	var outside: Vector3 = gate.to_global(Vector3(1.0, 0.1, 1.0))
	p.auto_target = outside
	world.get_node("Players").add_child(p)
	p.global_position = outside
	for i: int in 10:
		await get_tree().physics_frame
	GameState.player_data.erase("Night")
	GameState.get_or_create_player_data("Night")["cash"] = 1000
	dn.set_hours(12.0)
	dn._refresh_lights()
	await get_tree().physics_frame
	gate._gate_toggle(1)
	await get_tree().create_timer(0.1).timeout
	_report(not gate.is_open and p.last_message.contains("locked"), "by day the gate stays locked ('%s')" % p.last_message)
	dn.set_hours(23.0)
	dn._refresh_lights()
	await get_tree().physics_frame
	gate._gate_toggle(1)
	await get_tree().create_timer(0.6).timeout
	_report(gate.is_open, "at night the gate opens")
	# Through the gate to Rook, buy seeds.
	var through: Vector3 = gate.to_global(Vector3(1.0, 0.1, -1.0))
	var walked: bool = await _walk_to(p, through, 8.0)
	_report(walked, "walk through the open gate (at %s)" % p.global_position.snapped(Vector3.ONE * 0.1))
	var front: Vector3 = rook.global_position - rook.global_basis.z * 2.3
	p.global_position = front  # the rest only needs to stand there
	var answers: Array = []
	var cb := func(ok: bool, msg: String) -> void: answers.append([ok, msg])
	rook.buy_result.connect(cb)
	rook.request_buy(&"weed_seed", 5)
	await get_tree().process_frame
	_report(answers.size() == 1 and answers[0][0] and GameState.count_item("Night", "weed_seed") == 5,
			"Rook sells seeds at night (%s)" % [answers[0] if answers.size() > 0 else "no answer"])
	# Dawn: the gate closes, Rook stops selling; from inside the gate still opens.
	dn.set_hours(9.0)
	dn._refresh_lights()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_report(not gate.is_open, "at dawn the gate closes")
	rook.request_buy(&"weed_seed", 1)
	await get_tree().process_frame
	_report(answers.size() == 2 and not answers[1][0], "by day Rook doesn't sell (%s)" % [answers[1] if answers.size() > 1 else "no answer"])
	gate._gate_toggle(1)
	await get_tree().create_timer(0.1).timeout
	_report(gate.is_open, "from the market side the gate always opens (nobody gets locked in)")
	gate._set_open(false)
	rook.buy_result.disconnect(cb)
	dn.set_hours(10.0)
	GameState.player_data.erase("Night")
	p.queue_free()
	await get_tree().physics_frame


# --- Placement (point 6), furniture (17), storage lockers (18) ------------------------

func _check_placement(world: Node3D) -> void:
	var placed_root: Node3D = world.get_node("Placed")
	var room := world.find_child("StarterRoom", true, false) as Building
	var prop := room.get_node("Property") as Property
	# New game: the Starter Room's furniture was adopted (placed objects, no static copies left).
	var adopted: int = 0
	for c: Node in placed_root.get_children():
		if c is PlacedFurniture and prop.contains((c as Node3D).global_position + Vector3.UP * 0.1):
			adopted += 1
	_report(adopted >= 6 and prop.static_furniture().is_empty(),
			"starter room furniture can be moved (%d placed pieces, %d static left)" % [adopted, prop.static_furniture().size()])
	var no_station: bool = true
	for c: Node in placed_root.get_children():
		if c is Station and not c is StorageLocker and _corner.is_empty():
			no_station = false
	_report(no_station, "a new game starts without production stations (only the free locker)")

	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Placer"
	var spot: Vector3 = world.get_marker("Pot1Spot").global_position
	var stand: Vector3 = spot + Vector3(0, 0.1, 1.6)
	p.auto_target = stand
	world.get_node("Players").add_child(p)
	p.global_position = stand
	for i: int in 20:
		await get_tree().physics_frame
	GameState.player_data.erase("Placer")
	(GameState.get_or_create_player_data("Placer")["inventory"] as Array).clear()
	GameState.give("Placer", 0, [{"id": "grow_pot", "count": 2}, {"id": "storage_locker", "count": 1}, {"id": "sofa", "count": 1}])
	var pot_item: ItemData = ItemDB.get_item(&"grow_pot")
	var before: int = placed_root.get_child_count()
	var why: String = p._host_place("grow_pot", spot, 0.0)
	var pot: GrowPot = null
	for c: Node in placed_root.get_children():
		if c is GrowPot and (c as Node3D).global_position.distance_to(spot) < 0.01:
			pot = c as GrowPot
	_report(why == "" and pot != null and placed_root.get_child_count() == before + 1
			and GameState.count_item("Placer", "grow_pot") == 1 and GameState.world["stations"].has(pot.station_id),
			"a bought grow pot is placed in the starter room ('%s')" % why)
	_report(p._host_place("grow_pot", spot, 0.0) != "", "a second pot on the same spot is refused (%s)" %
			Placement.check(world.get_world_3d(), get_tree(), pot_item, spot, 0.0))
	var street: Vector3 = room.global_position + room.global_basis.z * 3.0
	_report(p._host_place("grow_pot", street + Vector3.UP * 0.05, 0.0) != "", "placing outside an own property is refused")
	var wall: Vector3 = room.to_global(Vector3(room.width * 0.5 - 0.35, 0.15, -5.0))
	_report(Placement.check(world.get_world_3d(), get_tree(), ItemDB.get_item(&"sofa"), wall, PI / 2.0) != "",
			"a sofa sticking through the wall is refused")
	_report(p._host_place("grow_pot", spot + Vector3(30, 0, 0), 0.0) != "", "placing far away is refused")
	var arm: Node3D = null
	for c: Node in world.get_node("Placed").get_children():
		if c is PlacedFurniture and (c as PlacedFurniture).item_id == "armchair":
			arm = c as Node3D
	if arm:
		var top: Dictionary = Placement.aim_point(world.get_world_3d(), arm.global_position + Vector3.UP * 1.5, Vector3.DOWN, [p.get_rid()])
		_report(not top.is_empty() and Placement.check(world.get_world_3d(), get_tree(), ItemDB.get_item(&"sofa"), top["pos"], 0.0) != "",
				"a sofa can't stand on top of an armchair")
	# Pick up: a pot with a plant can't, an empty one can (and goes back into the inventory).
	pot.state.merge({"stage": GrowPot.Stage.GROWING, "growth": 0.2, "water": 1.0}, true)
	_report(p._host_pick_up(pot.placed_uid) != "" and is_instance_valid(pot), "a pot with a plant can't be picked up")
	pot.state.merge({"stage": GrowPot.Stage.SOIL, "growth": 0.0}, true)
	var uid: String = pot.placed_uid
	var msg: String = p._host_pick_up(uid)
	await get_tree().process_frame
	_report(msg == "" and world.call("get_placed", uid) == null and GameState.count_item("Placer", "grow_pot") == 2
			and GameState.count_item("Placer", "soil") == 1 and not GameState.world["placed"].has(uid)
			and not GameState.world["stations"].has("placed/" + uid),
			"picking a pot up gives it back (+ its soil) and removes its record ('%s')" % msg)
	# Adopted furniture: pick up, place it again somewhere else (turned).
	var chair: PlacedFurniture = null
	for c: Node in placed_root.get_children():
		if c is PlacedFurniture and prop.contains((c as Node3D).global_position + Vector3.UP * 0.1) \
				and (c as Node3D).global_position.distance_to(p.global_position) < 4.0:
			chair = c as PlacedFurniture
	if chair:
		var id: String = chair.item_id
		_report(p._host_pick_up(chair.placed_uid) == "" and GameState.count_item("Placer", id) >= 1,
				"furniture (%s) can be picked up" % id)
		await get_tree().process_frame
		var free_spot: Vector3 = _free_floor(world, ItemDB.get_item(StringName(id)), prop, p)
		_report(free_spot != Vector3.INF and p._host_place(id, free_spot, PI / 2.0) == "",
				"and placed again, turned (%s)" % free_spot.snapped(Vector3.ONE * 0.01))
	else:
		_report(false, "furniture near the placer to pick up")
	# Resell (phone): half the price.
	var cash: int = int(GameState.player_data["Placer"]["cash"])
	p._host_resell(&"sofa")
	_report(int(GameState.player_data["Placer"]["cash"]) == cash + Player.resell_price(ItemDB.get_item(&"sofa"))
			and GameState.count_item("Placer", "sofa") == 0, "furniture resells for half the price")
	# Storage locker: place, put a stack in, take it out, can't pick it up while full.
	var lspot: Vector3 = _free_floor(world, ItemDB.get_item(&"storage_locker"), prop, p)
	var lwhy: String = p._host_place("storage_locker", lspot, PI / 2.0) if lspot != Vector3.INF else "no free spot"
	_report(lwhy == "", "a storage locker is placed ('%s' at %s, player at %s)" % [lwhy, lspot, p.global_position.snapped(Vector3.ONE * 0.1)])
	var locker: StorageLocker = null
	for c: Node in placed_root.get_children():
		if c is StorageLocker:
			locker = c as StorageLocker
	if locker:
		GameState.give("Placer", 0, [{"id": "weed_bag", "count": 7}])
		var inv: Array = GameState.player_data["Placer"]["inventory"]
		var idx: int = -1
		for i: int in inv.size():
			if str(inv[i]["id"]) == "weed_bag":
				idx = i
		locker.host_move("Placer", true, idx)
		_report(GameState.count_item("Placer", "weed_bag") == 0 and locker.used_slots() == 1
				and int(locker.state["items"][0]["count"]) == 7, "a stack goes into the locker")
		_report(GameState.world["stations"][locker.station_id] == locker.state, "the locker contents live in the world state (saved)")
		_report(p._host_pick_up(locker.placed_uid) != "", "a full locker can't be picked up")
		locker.host_move("Placer", false, 0)
		_report(GameState.count_item("Placer", "weed_bag") == 7 and locker.used_slots() == 0, "and comes back out")
		_report(p._host_pick_up(locker.placed_uid) == "", "an empty locker can be picked up")
	# Save round trip: placed records keep item, position and yaw.
	var placed: Dictionary = GameState.world["placed"]
	var json: String = JSON.stringify(JSON.from_native(GameState.world))
	var back: Dictionary = JSON.to_native(JSON.parse_string(json))
	var ok: bool = (back["placed"] as Dictionary).size() == placed.size()
	for k: String in placed:
		ok = ok and back["placed"][k]["pos"] is Vector3 and str(back["placed"][k]["item"]) == str(placed[k]["item"])
	_report(ok and placed.size() > 0, "placed things survive a save (%d records)" % placed.size())
	GameState.player_data.erase("Placer")
	p.queue_free()
	await get_tree().physics_frame


## A floor spot inside `prop` near the player where `item` fits, or INF.
func _free_floor(world: Node3D, item: ItemData, prop: Property, p: Player) -> Vector3:
	var b: Building = prop.building()
	for z: float in [-1.5, -2.0, -2.5, -3.0, -3.5, -4.0, -5.0, -6.0, -7.0]:
		for x: float in [0.0, -0.5, 0.5, -1.0, 1.0, -1.5, 1.5]:
			var hit: Dictionary = Placement.aim_point(world.get_world_3d(), b.to_global(Vector3(x, 1.5, z)), Vector3.DOWN,
					[p.get_rid()], Placement.support_mask(item))
			if hit.is_empty():
				continue
			if Placement.check(world.get_world_3d(), get_tree(), item, hit["pos"], PI / 2.0, [p.get_rid()]) == "":
				return hit["pos"]
	return Vector3.INF


# --- Real estate (point 8) -----------------------------------------------------------

func _check_real_estate(world: Node3D) -> void:
	var agent: EstateAgent = world.find_child("Agent", true, false) as EstateAgent
	_report(agent != null and agent.listings().size() >= 3, "Mrs. Vos sells %d properties" % (agent.listings().size() if agent else 0))
	if agent == null:
		return
	var house: Property = null
	for p: Property in agent.listings():
		if p.property_id == &"small_house":
			house = p
	_report(house != null and not house.is_crew_owned() and house.static_furniture().size() > 0,
			"the Small House is for sale and furnished (%d pieces)" % (house.static_furniture().size() if house else 0))
	if house == null:
		return
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Buyer"
	var front: Vector3 = agent.global_position - agent.global_basis.z * 2.5
	p.auto_target = front
	world.get_node("Players").add_child(p)
	p.global_position = front
	for i: int in 10:
		await get_tree().physics_frame
	GameState.player_data.erase("Buyer")
	GameState.get_or_create_player_data("Buyer")["cash"] = 5000
	var answers: Array = []
	var cb := func(ok: bool, msg: String) -> void: answers.append([ok, msg])
	agent.buy_result.connect(cb)
	# Inside an unowned house nothing can be placed.
	var inside: Vector3 = house.building().to_global(Vector3(0.5, 0.15, -6.0))
	_report(Placement.check(world.get_world_3d(), get_tree(), ItemDB.get_item(&"grow_pot"), inside, 0.0) != "",
			"placing in a house you don't own is refused")
	agent.request_buy_property(&"small_house")
	await get_tree().process_frame
	_report(answers.size() == 1 and not answers[0][0] and not house.is_crew_owned(), "not enough cash: no sale (%s)" % [answers[0] if answers.size() else "-"])
	GameState.get_or_create_player_data("Buyer")["cash"] = 9000
	var placed_before: int = world.get_node("Placed").get_child_count()
	agent.request_buy_property(&"small_house")
	await get_tree().process_frame
	await get_tree().process_frame
	_report(answers.size() == 2 and answers[1][0] and house.is_crew_owned()
			and int(GameState.player_data["Buyer"]["cash"]) == 1000, "buying the Small House for €8,000 (%s)" % [answers[1] if answers.size() > 1 else "-"])
	_report(house.static_furniture().is_empty() and world.get_node("Placed").get_child_count() > placed_before,
			"its furniture can now be moved (%d placed)" % (world.get_node("Placed").get_child_count() - placed_before))
	_report(GameState.world["properties"]["small_house"]["owner"] == "host", "ownership is in the world state (saved)")
	_report(house._label.text.contains("Owner"), "the sign shows the owner ('%s')" % house._label.text.replace("
", " / "))
	agent.request_buy_property(&"small_house")
	await get_tree().process_frame
	_report(answers.size() == 3 and not answers[2][0], "it can't be bought twice")
	agent.buy_result.disconnect(cb)
	GameState.player_data.erase("Buyer")
	p.queue_free()
	await get_tree().physics_frame
	# Point 26: spread over the map - far apart, none next to the police station.
	var station: Node3D = world.find_child("PoliceStation", true, false) as Node3D
	var closest: float = 1000.0
	var to_police: float = 1000.0
	var homes: Array = agent.listings().filter(func(q: Property) -> bool: return q.property_id != &"south_warehouse")
	for i: int in homes.size():
		var bi: Node3D = (homes[i] as Property).building()
		to_police = minf(to_police, bi.global_position.distance_to(station.global_position))
		for j: int in range(i + 1, homes.size()):
			closest = minf(closest, bi.global_position.distance_to((homes[j] as Property).building().global_position))
	_report(homes.size() >= 5 and closest > 25.0 and to_police > 40.0,
			"%d properties spread out: at least %.0f m apart, %.0f m or more from the police station" % [homes.size(), closest, to_police])
	# An old save (all on South Street) carries what stood inside along to the new spot.
	var keep: Dictionary = GameState.world
	GameState.world = {"hours": 12.0, "placed": {"t1": {"item": "sofa", "pos": Vector3(-37.5, 0.15, 50.0), "yaw": 0.5},
			"t2": {"item": "sofa", "pos": Vector3(-37.5, 0.15, 58.0), "yaw": 0.0}}, "loot_bags": []}
	GameState.get_or_create_player_data("Mover")["pos"] = Vector3(-36.0, 0.2, 51.0)
	var n_moved: int = world.migrate_layout()
	var rec: Dictionary = GameState.world["placed"]["t1"]
	var outside: Dictionary = GameState.world["placed"]["t2"]
	_report(n_moved == 2 and house.contains(rec["pos"]) and house.contains(GameState.player_data["Mover"]["pos"])
			and outside["pos"] == Vector3(-37.5, 0.15, 58.0) and absf(absf(float(rec["yaw"]) - 0.5) - PI) < 0.01,
			"an old save: the sofa and the player inside the Small House move along to %s" % (rec["pos"] as Vector3).snapped(Vector3.ONE * 0.1))
	_report(world.migrate_layout() == 0, "the move runs only once per save")
	GameState.world = keep
	GameState.player_data.erase("Mover")


# --- Storage + dropping (point 20) ------------------------------------------------------

func _check_storage(world: Node3D) -> void:
	var spot: Node3D = world.get_marker("LockerSpot")
	var locker: StorageLocker = null
	for n: Node in get_tree().get_nodes_in_group(&"stations"):
		if n is StorageLocker and (n as Node3D).global_position.distance_to(spot.global_position) < 0.3:
			locker = n as StorageLocker
	_report(locker != null and GameState.world.get("free_locker", false), "a free storage locker stands in the Starter Room")
	if locker == null:
		return
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Packrat"
	var front: Vector3 = locker.global_position + locker.global_basis.z * 1.0
	p.auto_target = front
	world.get_node("Players").add_child(p)
	p.global_position = front
	for i: int in 10:
		await get_tree().physics_frame
	GameState.player_data.erase("Packrat")
	var d: Dictionary = GameState.get_or_create_player_data("Packrat")
	locker.state["items"] = []
	# Full pockets: 8 different stacks.
	d["inventory"] = [{"id": "soil", "count": 5}, {"id": "baggie", "count": 20}, {"id": "weed_seed", "count": 3},
			{"id": "watering_can", "count": 1}, {"id": "weed_bud", "count": 4}, {"id": "ammo_9mm", "count": 30},
			{"id": "pistol", "count": 1}, {"id": "fresh_weed", "count": 2}]
	_report(GameState.space_for("Packrat", "sofa") == 0, "pockets are full (8 slots)")
	locker.host_move("Packrat", true, 0, 1)
	_report(int(d["inventory"][0]["count"]) == 4 and locker.state["items"] == [{"id": "soil", "count": 1}],
			"click: one Soil into the locker")
	locker.host_move("Packrat", true, 0, 0)
	_report(d["inventory"].size() == 7 and locker.state["items"] == [{"id": "soil", "count": 5}],
			"shift+click: the rest of the stack joins it (pockets now have a free slot)")
	locker._server_move(1, true, 0, 0)  # the RPC path (peer 1 = this walker), baggies
	_report(d["inventory"].size() == 6 and locker.used_slots() == 2, "moving through the host request works too")
	# Back out: pockets refill, and a full pocket refuses.
	locker.host_move("Packrat", false, 0, 2)
	_report(GameState.count_item("Packrat", "soil") == 2 and int(locker.state["items"][0]["count"]) == 3,
			"two Soil back into the pockets")
	d["inventory"].append({"id": "sofa", "count": 1})
	d["inventory"].append({"id": "stool", "count": 1})
	var msg: String = locker.host_move("Packrat", false, 1, 0)
	_report(msg == "Your pockets are full." and locker.used_slots() == 2, "full pockets: the baggies stay in the locker ('%s')" % msg)
	_report(GameState.world["stations"][locker.station_id]["items"].size() == 2, "the locker contents are in the world state (saved)")
	# Drop the stool (G / right click) and pick it up again.
	var bags0: int = world.get_node("Loot").get_child_count()
	var idx: int = -1
	for i: int in d["inventory"].size():
		if d["inventory"][i]["id"] == "stool":
			idx = i
	p._host_drop(idx, 0)
	await get_tree().process_frame
	var bag: LootBag = null
	for b: Node in world.get_node("Loot").get_children():
		if (b as LootBag).dropped and (b as LootBag).owner_name == "Packrat":
			bag = b as LootBag
	_report(bag != null and world.get_node("Loot").get_child_count() == bags0 + 1 and GameState.count_item("Packrat", "stool") == 0
			and bag.get_node_or_null("ItemModel") != null or (bag != null and bag.find_child("ItemModel", true, false) != null),
			"dropping puts the item on the ground (its own model)")
	_report(bag != null and bag.get_interaction_prompt() == "Pick up 1x Stool", "prompt: '%s'" % (bag.get_interaction_prompt() if bag else "-"))
	world.capture_for_save()
	var saved: bool = false
	for rec: Dictionary in GameState.world["loot_bags"]:
		saved = saved or bool(rec.get("dropped", false))
	GameState.world["loot_bags"] = []
	_report(saved, "dropped items are saved")
	GameState.remove_item("Packrat", "sofa", 1)  # room in the pockets again
	if bag:
		bag.global_position = p.global_position + Vector3(0.5, 0, 0)
		bag._server_take(1)
		await get_tree().process_frame
	_report(GameState.count_item("Packrat", "stool") == 1 and (bag == null or not is_instance_valid(bag) or bag.is_queued_for_deletion()),
			"picking it up puts it back in the pockets")
	locker.state["items"] = []
	locker.changed()
	GameState.player_data.erase("Packrat")
	p.queue_free()
	await get_tree().physics_frame


# --- Money laundering (point 9) ------------------------------------------------------

func _check_laundering(world: Node3D) -> void:
	var safes: Array[LaunderSafe] = []
	for n: Node in get_tree().get_nodes_in_group(&"stations"):
		if n is LaunderSafe:
			safes.append(n as LaunderSafe)
	var names: Array[String] = []
	for s: LaunderSafe in safes:
		names.append(s.business_name())
	_report(safes.size() == 3 and "Bakery" in names and "Barber Shop" in names and "Laundromat" in names,
			"three front businesses with a safe (%s)" % ", ".join(names))
	var agent: EstateAgent = world.find_child("Agent", true, false) as EstateAgent
	var bakery: LaunderSafe = null
	for s: LaunderSafe in safes:
		if s.business_name() == "Bakery":
			bakery = s
	if bakery == null or agent == null:
		return
	_report(bakery.property() in agent.listings(), "Mrs. Vos sells the Bakery")
	# Spending: legal purchases use clean money first, illegal ones dirty cash first.
	GameState.player_data.erase("Washer")
	var d: Dictionary = GameState.get_or_create_player_data("Washer")
	d["cash"] = 100
	d["clean"] = 100
	GameState.add_cash("Washer", -60, true)
	var legal_ok: bool = int(d["cash"]) == 100 and int(d["clean"]) == 40
	GameState.add_cash("Washer", -120, false)
	_report(legal_ok and int(d["cash"]) == 0 and int(d["clean"]) == 20 and not GameState.add_cash("Washer", -50),
			"legal buys use clean money first, illegal ones dirty cash (cash %d, clean %d)" % [d["cash"], d["clean"]])
	var taken: Dictionary = GameState.take_all("Washer")
	_report(int(d["clean"]) == 20, "clean money is not lost on death (bag €%d, clean €%d)" % [taken["cash"], d["clean"]])
	GameState.player_data.erase("Washer")

	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Washer"
	var front: Vector3 = bakery.global_position + bakery.global_basis.z * 1.2
	p.auto_target = front
	world.get_node("Players").add_child(p)
	p.global_position = front
	for i: int in 10:
		await get_tree().physics_frame
	d = GameState.get_or_create_player_data("Washer")
	d["cash"] = 5000
	d["clean"] = 0
	var msg: String = bakery.do_action(p)
	_report(int(d["cash"]) == 5000 and msg.contains("doesn't own"), "an unowned business doesn't launder ('%s')" % msg)
	bakery.property().host_set_owned("Washer")
	msg = bakery.do_action(p)
	_report(int(d["cash"]) == 2000 and bakery.queued_total() == 3000,
			"depositing fills the safe up to 2 days of turnover (cash %d, safe %d)" % [d["cash"], bakery.queued_total()])
	bakery.tick(12.0)
	_report(int(d["clean"]) == 630 and bakery.queued_total() == 2300,
			"half a day launders €700 (in €100 chunks) -> €630 clean (clean %d, safe %d)" % [d["clean"], bakery.queued_total()])
	bakery.tick(48.0)
	_report(int(d["clean"]) == 2700 and bakery.queued_total() == 0 and bakery.state["queue"].is_empty(),
			"everything comes back clean minus 10%% (clean %d)" % d["clean"])
	_report(GameState.world["stations"].has(bakery.station_id), "the safe state is in the world state (saved)")
	GameState.player_data.erase("Washer")
	p.queue_free()
	await get_tree().physics_frame


# --- Weed growing --------------------------------------------------------------------

## The classic weed corner, placed in the Starter Room (once) for the station tests.
func _weed_corner(world: Node3D) -> Dictionary:
	if _corner.is_empty() or not is_instance_valid(_corner["Pot1"]):
		_corner = world.call("debug_weed_corner")
		await get_tree().physics_frame
	return _corner


func _check_growing(world: Node3D) -> void:
	var corner: Dictionary = await _weed_corner(world)
	var pot: GrowPot = corner["Pot1"] as GrowPot
	var lamp: GrowLamp = corner["GrowLamp"] as GrowLamp
	var rack: DryingRack = corner["DryingRack"] as DryingRack
	_report(pot != null and lamp != null and rack != null, "placed pots, a grow lamp and a drying rack in the starter room")
	if pot == null or lamp == null or rack == null:
		return
	var stations: Dictionary = GameState.world.get("stations", {})
	_report(stations.get(pot.station_id) == pot.state, "pot state lives in GameState.world (%s)" % pot.station_id)

	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Grower"
	var front: Vector3 = pot.global_position + Vector3(0, 0.1, 0.9)
	p.auto_target = front
	world.get_node("Players").add_child(p)
	p.global_position = front
	for i: int in 10:
		await get_tree().physics_frame
	GameState.player_data.erase("Grower")
	p.send_wallet()

	pot._server_action(1)
	_report(int(pot.state["stage"]) == GrowPot.Stage.EMPTY and p.last_message.contains("Soil"),
			"empty pot without soil: '%s'" % p.last_message)
	GameState.give("Grower", 0, [{"id": "soil", "count": 1}, {"id": "weed_seed", "count": 1}, {"id": "watering_can", "count": 1}])
	p.send_wallet()
	_report(pot.prompt_for(p).begins_with("Fill with soil"), "prompt: '%s'" % pot.prompt_for(p))
	pot._server_action(1)
	pot._server_action(1)
	_report(int(pot.state["stage"]) == GrowPot.Stage.GROWING and GameState.count_item("Grower", "soil") == 0
			and GameState.count_item("Grower", "weed_seed") == 0, "soil + seed planted (stage %d)" % int(pot.state["stage"]))
	pot.tick(1.0)
	_report(float(pot.state["growth"]) == 0.0, "a dry plant does not grow")
	pot._server_action(1)
	_report(float(pot.state["water"]) == 1.0 and GameState.count_item("Grower", "watering_can") == 1,
			"watering fills the soil and keeps the can")
	lamp.state["on"] = true
	var g0: float = float(pot.state["growth"])
	pot.tick(1.0)
	var lit: float = float(pot.state["growth"]) - g0
	lamp.state["on"] = false
	g0 = float(pot.state["growth"])
	pot.tick(1.0)
	var unlit: float = float(pot.state["growth"]) - g0
	lamp.state["on"] = true
	_report(absf(lit - GrowLamp.BOOST / GrowPot.GROW_HOURS) < 0.001 and absf(unlit - 1.0 / GrowPot.GROW_HOURS) < 0.001,
			"grow light speeds it up (%.3f vs %.3f per hour)" % [lit, unlit])
	for i: int in 20:
		if int(pot.state["stage"]) == GrowPot.Stage.READY:
			break
		pot._server_action(1)  # water when needed
		pot.tick(1.0)
	_report(int(pot.state["stage"]) == GrowPot.Stage.READY, "plant becomes ready to harvest")
	pot._server_action(1)
	_report(int(pot.state["stage"]) == GrowPot.Stage.EMPTY and GameState.count_item("Grower", "fresh_weed") == GrowPot.YIELD,
			"harvest gives %d Fresh Weed and empties the pot" % GameState.count_item("Grower", "fresh_weed"))

	p.teleport(rack.global_position + rack.global_basis.z * 0.9 + Vector3.UP * 0.1)
	await get_tree().physics_frame
	_report(rack.prompt_for(p).begins_with("Hang"), "rack prompt: '%s'" % rack.prompt_for(p))
	rack._server_action(1)
	_report(int(rack.state["wet"]) == GrowPot.YIELD and GameState.count_item("Grower", "fresh_weed") == 0, "fresh weed hangs on the rack")
	rack.tick(DryingRack.DRY_HOURS + 0.1)
	_report(int(rack.state["dry"]) == GrowPot.YIELD and int(rack.state["wet"]) == 0, "it dries after %d hours" % int(DryingRack.DRY_HOURS))
	rack._server_action(1)
	_report(GameState.count_item("Grower", "weed_bud") == GrowPot.YIELD and int(rack.state["dry"]) == 0,
			"take %d Dried Weed off the rack" % GameState.count_item("Grower", "weed_bud"))
	var visible_buds: int = 0
	for c: Node in rack.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).visible and (c as MeshInstance3D).mesh in [rack._bud_mesh_wet, rack._bud_mesh_dry]:
			visible_buds += 1
	_report(visible_buds == 0, "rack shows no buds when empty")
	GameState.player_data.erase("Grower")
	p.queue_free()
	await get_tree().physics_frame


# --- Pedestrians -----------------------------------------------------------------

func _check_pedestrians(world: Node3D) -> void:
	world.call("spawn_pedestrians", 10)
	await get_tree().physics_frame
	var npcs: Array[Node] = get_tree().get_nodes_in_group(&"npc")
	_report(npcs.size() == 10, "spawned %d pedestrians" % npcs.size())
	var roads: Array[Node] = world.find_children("*", "RoadTile", true, false)
	var start: Dictionary = {}
	var travelled: Dictionary = {}
	for n: Node in npcs:
		start[n] = (n as Node3D).global_position
		travelled[n] = 0.0
	var on_road: int = 0
	var samples: int = 0
	var indoor_hits: int = 0
	Engine.time_scale = 3.0
	var last: Dictionary = start.duplicate()
	for step: int in 450:  # 90 game-seconds, sampled every 0.2 s
		await get_tree().create_timer(0.2).timeout
		for n: Node in npcs:
			var p: Vector3 = (n as Node3D).global_position
			travelled[n] += p.distance_to(last[n])
			last[n] = p
			samples += 1
			for r: Node in roads:
				# Fully on the road (body overlapping a zebra edge is fine).
				var t := r as RoadTile
				if p.y < 0.12 and t.is_blocked(p) and t.is_blocked(p + Vector3(0.4, 0, 0)) 						and t.is_blocked(p - Vector3(0.4, 0, 0)) and t.is_blocked(p + Vector3(0, 0, 0.4)) 						and t.is_blocked(p - Vector3(0, 0, 0.4)):
					on_road += 1
					if on_road <= 5:
						print("[SelfTest]   %s on the road at %s" % [n.name, p])
					break
	Engine.time_scale = 1.0
	_report(on_road == 0, "pedestrians stayed off the road outside zebras (%d of %d samples on road)" % [on_road, samples])
	var totals: Dictionary = {"walk": 0, "idle": 0, "sit": 0, "visit": 0, "stuck": 0}
	var lazy: int = 0
	var worst_stuck: int = 0
	for n: Node in npcs:
		var st: Dictionary = n.get("stats")
		for k: String in totals:
			totals[k] += st[k]
		worst_stuck = maxi(worst_stuck, st["stuck"])
		if travelled[n] < 10.0:
			lazy += 1
			print("[SelfTest]   %s only moved %.1f m (%s)" % [n.name, travelled[n], st])
	_report(lazy <= 1, "pedestrians keep moving (%d of %d moved < 10 m)" % [lazy, npcs.size()])
	_report(totals["walk"] >= 5 and totals["sit"] + totals["visit"] > 0, "activities: %s" % totals)
	# Getting stuck now and then is fine (it backs off); staying stuck is not.
	_report(worst_stuck <= 2 and totals["stuck"] <= 5,
			"nobody stays stuck (%d stuck moves, worst NPC %d)" % [totals["stuck"], worst_stuck])


# --- NPC combat -----------------------------------------------------------------------

func _check_npc_combat(world: Node3D) -> void:
	var npcs: Array[Node] = get_tree().get_nodes_in_group(&"npc")
	var count0: int = npcs.size()
	if count0 < 2:
		_report(false, "need pedestrians for the NPC combat check")
		return
	Pedestrian.corpse_time = 3.0
	Pedestrian.respawn_time = 4.0
	var a: Pedestrian = npcs[0] as Pedestrian
	var b: Pedestrian = npcs[1] as Pedestrian
	var b_start: Vector3 = b.global_position
	world.get_tree().call_group(&"npc", "hear_gunshot", b.global_position + Vector3(3, 0, 0))
	_report(b.is_fleeing() and b.anim_state == Pedestrian.Anim.RUN, "pedestrian runs from a gunshot nearby")
	await get_tree().create_timer(1.5).timeout
	_report(b.global_position.distance_to(b_start) > 2.0, "fleeing pedestrian moves away (%.1f m)" % b.global_position.distance_to(b_start))
	_report(not a.host_damage(30, null) and a.health == 70, "NPC takes damage (health %d)" % a.health)
	_report(a.is_head_hit(a.global_position + Vector3.UP * 1.6) and not a.is_head_hit(a.global_position + Vector3.UP * 1.0),
			"NPC head hit zone")
	var killed: bool = a.host_damage(200, null)
	_report(killed and a.dead and a.anim_state == Pedestrian.Anim.DEAD and a.collision_layer == 0,
			"NPC dies at 0 health (death anim, not solid)")
	var head0: float = a.get_node("Model").find_children("*", "Skeleton3D", true, false)[0].global_position.y
	await get_tree().create_timer(2.0).timeout
	var rd: Ragdoll = a._ragdoll
	_report(rd.running and rd.head_height() < a.global_position.y + 0.6,
			"dead NPC falls as a ragdoll (head %.2f m above its feet)" % (rd.head_height() - a.global_position.y))
	await get_tree().create_timer(2.5).timeout
	var now: int = get_tree().get_nodes_in_group(&"npc").size()
	_report(not is_instance_valid(a) and now == count0, "dead NPC removed and a new one respawned (%d -> %d)" % [count0, now])
	Pedestrian.corpse_time = 20.0
	Pedestrian.respawn_time = 60.0


# --- Health regeneration (point 22) ------------------------------------------------------

func _check_regen(world: Node3D) -> void:
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Healer"
	var spot: Vector3 = (world.get_node("Markers/SpawnPoints").get_child(0) as Node3D).global_position
	p.auto_target = spot
	world.get_node("Players").add_child(p)
	p.global_position = spot
	await get_tree().physics_frame
	_report(p.regen_delay >= 6.0 and p.regen_delay <= 10.0, "regeneration starts %.0f s after the last damage" % p.regen_delay)
	p.regen_delay = 1.0
	p.regen_per_second = 30.0
	p.host_damage(60, null)
	await get_tree().create_timer(0.6).timeout
	_report(p.health == 40, "no healing right after a hit (health %d)" % p.health)
	await get_tree().create_timer(2.0).timeout
	var mid: int = p.health
	p.host_damage(10, null)
	var after_hit: int = p.health
	await get_tree().create_timer(0.5).timeout
	_report(mid > 40 and p.health == after_hit, "health comes back, a new hit pauses it (%d -> hit %d -> %d)" % [mid, after_hit, p.health])
	await get_tree().create_timer(4.0).timeout
	_report(p.health == Player.MAX_HEALTH, "healed back to %d (not higher)" % p.health)
	GameState.player_data.erase("Healer")
	p.queue_free()
	await get_tree().physics_frame


# --- Police (point 10) -------------------------------------------------------------------

func _check_police(world: Node3D) -> void:
	var station: Node3D = world.find_child("PoliceStation", true, false) as Node3D
	_report(station != null and station.find_child("OfficerSpawn1", true, false) != null, "police station with officer spawns")
	if station == null:
		return
	# A test player on the pavement in front of the station, an officer 12 m away.
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Crook"
	var spot: Vector3 = station.global_position + station.global_basis.z * 4.5 + station.global_basis.x * 6.0
	p.auto_target = spot
	world.get_node("Players").add_child(p)
	p.global_position = spot
	for i: int in 10:
		await get_tree().physics_frame
	var cop: PoliceOfficer = world.add_officer(spot - station.global_basis.x * 12.0, spot)
	await get_tree().create_timer(2.0).timeout
	_report(cop.target == null and cop.anim_state != Pedestrian.Anim.AIM, "an officer on patrol leaves an innocent player alone")
	_report(cop.can_see(p), "the officer can see the player (12 m, open street)")
	# Far away gunshot: ignored. Nearby: the officer takes the shooter on.
	get_tree().call_group(&"police", "report_crime", p, spot + Vector3(200, 0, 0), false)
	_report(cop.target == null, "a gunshot 200 m away is not heard")
	# Point 21: tunable, weak by default: slow to react, spread grows with range and movement.
	var prof: NpcCombatProfile = cop.profile
	_report(prof.reaction_time >= 0.8 and prof.damage <= 10 and prof.burst_pause > 1.0
			and prof.spread(25.0, 0.0) > prof.spread(5.0, 0.0) and prof.spread(10.0, 5.0) > prof.spread(10.0, 0.0),
			"police profile: reaction %.1f s, damage %d, bursts of %d, spread %.3f -> %.3f rad (5 -> 25 m), %.3f running" % [
			prof.reaction_time, prof.damage, prof.burst_size, prof.spread(5.0, 0.0), prof.spread(25.0, 0.0), prof.spread(10.0, 5.0)])
	p.health = 100000  # (count hits, don't die)
	var hits: int = 0
	for i: int in 40:
		var h: int = p.health
		cop._shoot_at(p)
		hits += 1 if p.health < h else 0
	_report(hits < 28, "at 12 m the police miss a lot (%d of 40 shots hit)" % hits)
	p.health = Player.MAX_HEALTH
	var health0: int = p.health
	p.host_last_shot = Time.get_ticks_msec() / 1000.0
	cop._hostile[p] = true  # (fired at the police: no arrest, always shot)
	get_tree().call_group(&"police", "report_crime", p, p.global_position, false)
	_report(cop.target == p, "a gunshot nearby: the officer goes after the shooter")
	await get_tree().create_timer(0.5).timeout
	_report(p.health == health0, "no shot before the reaction time")
	# From here a sharp test profile, so the rest of the check doesn't take minutes.
	var sharp: NpcCombatProfile = prof.duplicate()
	sharp.accuracy = 1.0
	sharp.reaction_time = 0.2
	sharp.burst_pause = 0.3
	sharp.spread_per_metre = 0.0
	sharp.moving_spread = 0.0
	sharp.damage = 15
	cop.profile = sharp
	await get_tree().create_timer(3.0).timeout
	_report(cop.anim_state == Pedestrian.Anim.AIM and p.health < health0,
			"the officer aims and shoots the culprit (health %d -> %d)" % [health0, p.health])
	_report(not get_tree().get_nodes_in_group(&"npc").any(func(n: Node) -> bool: return n is PoliceOfficer and (n as Pedestrian).is_fleeing()),
			"officers don't flee from gunfire")
	# Until the culprit is dead.
	for i: int in 40:
		if p.dead:
			break
		await get_tree().create_timer(0.5).timeout
	_report(p.dead, "the officer keeps shooting until the culprit is dead")
	await get_tree().create_timer(0.6).timeout
	_report(cop.target == null, "dead culprit: the officer stops")
	cop.profile = PoliceOfficer.DEFAULT_PROFILE
	# Shooting an officer makes you its target (a fresh test player).
	p.queue_free()
	await get_tree().physics_frame
	GameState.player_data.erase("Crook")
	var q: Player = WALKER.instantiate()
	q.auto_walk = true
	q.name = "1"
	q.player_name = "Crook2"
	q.auto_target = spot
	world.get_node("Players").add_child(q)
	q.global_position = spot
	await get_tree().physics_frame
	cop.host_damage(10, q, q.global_position)
	_report(cop.target == q and cop.health == 90, "shooting an officer makes you its target")
	# Out of sight long enough: it gives up.
	q.global_position = spot + Vector3(0, 0, -60)  # behind the buildings
	q.auto_target = q.global_position
	cop._search_until = cop._now() + 1.0
	await get_tree().create_timer(2.0).timeout
	_report(cop.target == null, "culprit gone for a while: the officer gives up")
	# Point 25: a culprit who doesn't resist (weapon away, no shots) is cuffed, not shot.
	var r: Player = WALKER.instantiate()
	r.auto_walk = true
	r.name = "2"
	r.player_name = "Cuffed"
	var rspot: Vector3 = spot + station.global_basis.x * 3.0
	r.auto_target = rspot
	world.get_node("Players").add_child(r)
	r.global_position = rspot
	await get_tree().physics_frame
	r.net_weapon = 0
	GameState.get_or_create_player_data("Cuffed")["cash"] = 1000
	GameState.give("Cuffed", 0, [{"id": "weed_bag", "count": 3}, {"id": "soil", "count": 2}])
	var cop2: PoliceOfficer = world.add_officer(rspot - station.global_basis.x * 8.0, rspot)
	await get_tree().create_timer(0.5).timeout
	var health_r: int = r.health
	cop2._alert(r, rspot)
	var release: Node3D = world.get_marker("ReleaseSpot")
	var released: bool = false
	for i: int in 160:
		if r.global_position.distance_to(release.global_position) < 1.5:
			released = true
			r.auto_target = release.global_position  # (the test walker would walk back)
			break
		await get_tree().physics_frame
		await get_tree().create_timer(0.1).timeout
	var rdata: Dictionary = GameState.get_or_create_player_data("Cuffed")
	var ids: Array = (rdata["inventory"] as Array).map(func(it: Dictionary) -> String: return str(it.get("id", "")))
	_report(r.health == health_r and released,
			"a culprit who doesn't resist is cuffed (not shot) and released at the police station")
	_report(not ids.has("weed_bag") and ids.has("soil") and int(rdata["cash"]) == 800,
			"arrest: illegal items confiscated, legal ones kept, minimum fine paid (cash %d, items %s)" % [int(rdata["cash"]), ids])
	await get_tree().create_timer(0.5).timeout
	_report(cop2.target == null, "after the arrest the officer stops")
	# Weapon drawn and not put away after the warning: resisting -> shot.
	r.teleport(rspot)
	r.auto_target = rspot
	r.net_weapon = 1
	cop2.profile = sharp
	await get_tree().create_timer(0.5).timeout
	cop2._alert(r, rspot)
	for i: int in 20:
		if r.health < health_r:
			break
		await get_tree().create_timer(0.5).timeout
	_report(r.health < health_r and cop2.resisting(r), "weapon still drawn after the warning: resisting, the officer shoots")
	cop2.queue_free()
	r.queue_free()
	GameState.player_data.erase("Cuffed")
	# Patrol car: a crime nearby stops it and the officer gets out.
	var traffic: Traffic = world.get_node("Traffic")
	var car: Car = traffic.spawn_police_car(3, 10.0)
	await get_tree().create_timer(0.5).timeout
	_report(car.police and car.is_in_group(&"police") and car._bar_lights.size() == 2, "police car with a light bar")
	q.global_position = car.global_position + car.global_basis.x * 6.0
	q.auto_target = q.global_position
	await get_tree().physics_frame
	var cops0: int = get_tree().get_nodes_in_group(&"police").size()
	car.hear_gunshot(q.global_position)
	_report(not car.abandoned and car.panic == 0.0, "a police car doesn't panic at gunfire")
	get_tree().call_group(&"police", "report_crime", q, q.global_position, false)
	await get_tree().create_timer(0.5).timeout
	var out: PoliceOfficer = car._driver as PoliceOfficer
	_report(car.abandoned and car.siren and out != null and out.target == q and out.from_car == car,
			"a crime near the patrol car: it stops (siren) and its officers get out")
	_report(car.crew_out.size() == 2 and get_tree().get_nodes_in_group(&"police").size() >= cops0 + 2,
			"the patrol car's crew of %d is on the street" % car.crew_out.size())
	# Point 25: the crew never chases further than LEASH from its car.
	var mate: PoliceOfficer = car.crew_out[1]
	mate.last_known = car.global_position + Vector3(PoliceOfficer.LEASH + 10.0, 0, 0)
	await get_tree().create_timer(1.8).timeout  # (the brain starts up to 1.5 s after spawning)
	_report(mate.target == null, "an officer doesn't go further than %d m from the car" % int(PoliceOfficer.LEASH))
	# Called off: they walk back, get in, the car drives on.
	var crew: Array = car.crew_out.duplicate()
	for c: PoliceOfficer in crew:
		c._drop_target()
	for i: int in 30:
		if not car.abandoned:
			break
		await get_tree().create_timer(0.5).timeout
	_report(not car.abandoned and not car.siren and crew.all(func(c: Variant) -> bool: return not is_instance_valid(c)),
			"after the call the officers get back in and the car drives on")
	car.queue_free()
	if is_instance_valid(cop):
		cop.queue_free()
	q.queue_free()
	GameState.player_data.erase("Crook2")
	await get_tree().physics_frame


# --- traffic ---------------------------------------------------------------------------

func _check_traffic(world: Node3D) -> void:
	var traffic: Traffic = world.get_node("Traffic")
	traffic.spawn_cars(8)
	await get_tree().physics_frame
	var cars: Array[Node] = get_tree().get_nodes_in_group(&"cars")
	_report(cars.size() == 8, "spawned %d cars" % cars.size())
	var roads: Array[Node] = world.find_children("*", "RoadTile", true, false)
	var travelled: Dictionary = {}
	var last: Dictionary = {}
	for c: Node in cars:
		travelled[c] = 0.0
		last[c] = (c as Node3D).global_position
	var off_road: int = 0
	var overlaps: int = 0
	Engine.time_scale = 3.0
	for step: int in 300:  # 60 game-seconds
		await get_tree().create_timer(0.2).timeout
		for i: int in cars.size():
			var p: Vector3 = (cars[i] as Node3D).global_position
			travelled[cars[i]] += p.distance_to(last[cars[i]])
			last[cars[i]] = p
			var on_road: bool = false
			for r: Node in roads:
				if (r as RoadTile).is_on_asphalt(p):
					on_road = true
					break
			if not on_road:
				off_road += 1
				if off_road <= 3:
					print("[SelfTest]   %s off the road at %s" % [cars[i].name, p])
			for j: int in range(i + 1, cars.size()):
				if p.distance_to((cars[j] as Node3D).global_position) < 2.0:
					overlaps += 1
					if overlaps <= 4:
						print("[SelfTest]   %s (route %d, ignoring cars %.1f s) and %s (route %d) overlap at %s" % [cars[i].name,
								cars[i].route_id, cars[i]._ignore_cars, cars[j].name, cars[j].route_id, p.snapped(Vector3.ONE * 0.1)])
	Engine.time_scale = 1.0
	var slow: int = 0
	for c: Node in cars:
		if travelled[c] < 100.0:
			slow += 1
			print("[SelfTest]   %s only drove %.0f m" % [c.name, travelled[c]])
	_report(off_road == 0, "cars stay on the asphalt (%d off-road samples)" % off_road)
	_report(slow == 0, "cars keep driving (%d of %d drove < 100 m in 60 s)" % [slow, cars.size()])
	_report(overlaps == 0, "cars don't drive through each other (%d overlaps)" % overlaps)
	# Braking: a person standing in the lane 14 m ahead of a car on the main road.
	var car: Car = null
	for c: Node in cars:
		if (c as Car).route_id == 2:
			car = c
	car.progress = 30.0
	car.speed = Car.CRUISE
	# Other cars on that route go half a lap away, so none of them queues in front of the test car.
	var gap_cars: float = 0.0
	for c: Node in cars:
		if c != car and (c as Car).route_id == 2:
			(c as Car).progress = 30.0 + traffic.routes[2].length * 0.5 + gap_cars
			gap_cars += 15.0
	var person: Pedestrian = world.call("_add_pedestrian", traffic.routes[2].sample(30.0 + 14.0)[0], 0)
	person.set_physics_process(false)
	await get_tree().create_timer(5.0).timeout
	var gap: float = car.global_position.distance_to(person.global_position)
	_report(car.speed < 0.1 and car.blocked_by == "person" and gap > 2.5,
			"car stops for a person in the road (speed %.1f, %s, %.1f m away)" % [car.speed, car.blocked_by, gap])
	person.queue_free()
	await get_tree().create_timer(3.0).timeout
	_report(car.speed > 2.0, "car drives on once the road is clear (speed %.1f)" % car.speed)
	# Smooth bends: a car on the inner loop (tight right turns) through a whole lap,
	# watched every physics frame: no heading jumps, slow in the bend, fast on the straight.
	var bender: Car = null
	for c: Node in cars:
		if (c as Car).route_id == 1:
			bender = c
	var max_step: float = 0.0
	var bend_speed: float = 0.0
	var straight_speed: float = 0.0
	var yaw0: float = bender.rotation.y
	for f: int in 60 * 25:
		await get_tree().physics_frame
		max_step = maxf(max_step, absf(angle_difference(yaw0, bender.rotation.y)))
		yaw0 = bender.rotation.y
		var k: float = absf(traffic.routes[1].curvature(bender.progress))
		if k > 0.3:
			bend_speed = maxf(bend_speed, bender.speed)
		elif k < 0.001:
			straight_speed = maxf(straight_speed, bender.speed)
	_report(rad_to_deg(max_step) < 2.5, "cars turn smoothly (max %.2f deg per frame)" % rad_to_deg(max_step))
	_report(bend_speed > 0.5 and bend_speed < 3.5 and straight_speed > 6.0,
			"slow in tight bends (%.1f m/s), fast on straights (%.1f m/s)" % [bend_speed, straight_speed])
	await _check_car_gunfire(world, traffic)


## Point 3: cars react to gunfire (panic: faster + honk; bail: driver runs and comes back;
## a shot car stops, a wreck is towed away and replaced).
func _check_car_gunfire(world: Node3D, traffic: Traffic) -> void:
	var on_main: Array[Car] = []
	for c: Node in traffic.get_children():
		if c is Car and (c as Car).route_id == 2:
			on_main.append(c as Car)
	var car: Car = on_main[0]
	var top: float = 0.0
	# Clear stretch of the main road for the test car, others half a lap away. A pedestrian or a
	# junction can hold it up: up to 3 tries on other stretches.
	for attempt: int in 3:
		car.progress = 20.0 + attempt * 45.0
		car.speed = Car.CRUISE
		car.panic = 0.0
		for i: int in range(1, on_main.size()):
			on_main[i].progress = car.progress + traffic.routes[2].length * 0.5 + i * 15.0
		await get_tree().create_timer(0.5).timeout
		Car.force_reaction = "panic"
		car.hear_gunshot(car.global_position + Vector3(0, 0, 20))
		top = 0.0
		for i: int in 120:
			await get_tree().physics_frame
			top = maxf(top, car.speed)
		if top > Car.CRUISE + 1.0:
			break
	_report(car.panic > 0.0 and top > Car.CRUISE + 1.0 and not car.abandoned,
			"gunshot nearby: the car panics and speeds up (%.1f m/s)" % top)
	await get_tree().create_timer(Car.PANIC_TIME).timeout
	# Point 24: a shot ahead -> the car turns round and drives away; nobody gets out.
	var peds0: int = get_tree().get_nodes_in_group(&"npc").size()
	# (Back on the straight test stretch: after the panic it can be anywhere, e.g. in a bend.)
	car.route_id = 2
	car.progress = 20.0
	car.speed = Car.CRUISE
	await get_tree().create_timer(0.5).timeout
	var shot_from: Vector3 = car.global_position - car.global_basis.z * 15.0
	var d0: float = car.global_position.distance_to(shot_from)
	Car.force_reaction = "uturn"
	car.hear_gunshot(shot_from)
	Car.force_reaction = ""
	_report(not car._uturn.is_empty(), "gunshot ahead: the car turns round")
	# (Up to 2 s more: on the other lane it may have to follow a car through a junction.)
	for i: int in 8:
		await get_tree().create_timer(0.5 if i > 0 else Car.UTURN_TIME + 2.5).timeout
		if car.global_position.distance_to(shot_from) > d0 + 5.0:
			break
	var heading_away: bool = (car.global_position - shot_from).dot(-car.global_basis.z) > 0.0
	var d1: float = car.global_position.distance_to(shot_from)
	_report(car._uturn.is_empty() and heading_away and d1 > d0 + 5.0 and not car.abandoned,
			"it drives away from the shooting on the other lane (%.0f -> %.0f m, %.1f m/s)" % [d0, d1, car.speed])
	_report(get_tree().get_nodes_in_group(&"npc").size() == peds0 and car._driver == null, "the driver stays in the car")
	# A hit (not wrecked) car doesn't stop either.
	car.panic = 0.0
	car.host_damage(20, null, car.global_position + car.global_basis.x * 6.0)
	await get_tree().create_timer(0.5).timeout
	_report(not car.abandoned and car.panic > 0.0, "a car that is hit speeds off (doesn't stop)")
	await get_tree().create_timer(Car.PANIC_TIME).timeout
	var prog0: float = car.progress
	for i: int in 10:  # (it may wait at a junction / behind another car for a while)
		await get_tree().create_timer(1.0).timeout
		if absf(car.progress - prog0) > 2.0:
			break
	_report(car.panic == 0.0 and not car.abandoned and car._uturn.is_empty() and car.progress != prog0,
			"after the panic it drives its route again (route %d)" % car.route_id)
	# Back onto the main road for the next checks.
	car.route_id = 2
	car.progress = 20.0
	car.speed = Car.CRUISE
	await get_tree().create_timer(1.0).timeout
	# Horns: one at a time in town.
	Car._last_honk_ms = -100000
	car.honk(true)
	var t0: int = Car._last_honk_ms
	(on_main[1] if on_main.size() > 1 else car).honk(true)
	_report(Car._last_honk_ms == t0, "only one horn at a time")
	var other: Car = on_main[1] if on_main.size() > 1 else null
	Engine.time_scale = 3.0
	# A car stuck behind a stopped car waits (no driving through it).
	if other:
		other.progress = car.progress - 14.0
		other.speed = Car.CRUISE
		car.abandon(car.global_position + Vector3(0, 0, 30))
		await get_tree().create_timer(6.0).timeout
		var d: float = other.global_position.distance_to(car.global_position)
		_report(other.speed < 0.2 and d > 3.0, "car behind a stopped car waits (%.1f m behind)" % d)
	# Shot to a wreck: it stops for good, is towed away and a new car turns up.
	var before: int = 0
	for c: Node in traffic.get_children():
		before += 1 if c is Car else 0
	var wreck: Car = on_main[on_main.size() - 1]
	wreck.host_damage(Car.MAX_HEALTH + 10, null, wreck.global_position + Vector3(5, 1, 0))
	_report(wreck.wrecked and wreck.abandoned, "a car shot to pieces stops (wrecked)")
	var replaced: bool = false
	for i: int in 70:
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(wreck):
			await get_tree().create_timer(6.0).timeout
			var after: int = 0
			for c: Node in traffic.get_children():
				after += 1 if c is Car and not c.is_queued_for_deletion() else 0
			replaced = after == before
			break
	Engine.time_scale = 1.0
	_report(replaced, "the wreck is towed away and a new car turns up")


# --- Packaging + selling (step 7) --------------------------------------------------------

func _check_selling(world: Node3D) -> void:
	var table: PackagingTable = (await _weed_corner(world))["PackagingTable"] as PackagingTable
	_report(table != null, "placed a packaging table in the starter room")
	if table == null:
		return
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Dealer"
	var front: Vector3 = table.global_position + table.global_basis.z * 0.8 + Vector3.UP * 0.1
	p.auto_target = front
	world.get_node("Players").add_child(p)
	p.global_position = front
	for i: int in 10:
		await get_tree().physics_frame
	GameState.player_data.erase("Dealer")
	GameState.give("Dealer", 0, [{"id": "weed_bud", "count": 3}, {"id": "baggie", "count": 2}])
	p.send_wallet()
	_report(table.prompt_for(p).begins_with("Package 2"), "packaging prompt: '%s'" % table.prompt_for(p))
	table._server_action(1)
	_report(GameState.count_item("Dealer", "weed_bag") == 2 and GameState.count_item("Dealer", "weed_bud") == 1
			and GameState.count_item("Dealer", "baggie") == 0, "1 Dried Weed + 1 Baggie -> 1 Bag of Weed ('%s')" % p.last_message)
	table._server_action(1)
	_report(p.last_message.contains("need"), "no baggies left: '%s'" % p.last_message)

	GameState.give("Dealer", 0, [{"id": "weed_bag", "count": 6}])
	var npcs: Array[Node] = get_tree().get_nodes_in_group(&"npc")
	var npc: Pedestrian = null
	for n: Node in npcs:
		if not (n as Pedestrian).dead:
			npc = n as Pedestrian
	world.call("make_customer", npc)
	_report(npc.wants > 0 and npc.is_in_group(&"interactable") and npc.is_in_group(&"customer"),
			"pedestrian becomes a customer (wants %d for €%d)" % [npc.wants, npc.offer])
	var deal := func(bags: int, price: int, outcome: String) -> void:
		npc.become_customer(bags, price, 60.0)
		p.teleport(npc.global_position + Vector3(1.2, 0.1, 0))
		Pedestrian.force_outcome = outcome
		npc._server_sell(1)
	var cash0: int = int(GameState.get_or_create_player_data("Dealer")["cash"])
	deal.call(2, 150, "fair")
	_report(int(GameState.get_or_create_player_data("Dealer")["cash"]) == cash0 + 150 and GameState.count_item("Dealer", "weed_bag") == 6
			and npc.wants == 0 and not npc.is_in_group(&"interactable"), "fair deal: +€150 for 2 bags ('%s')" % p.last_message)
	deal.call(9, 500, "")
	_report(GameState.count_item("Dealer", "weed_bag") == 6 and p.last_message.contains("I need"),
			"not enough bags: no deal ('%s')" % p.last_message)
	cash0 = int(GameState.get_or_create_player_data("Dealer")["cash"])
	deal.call(2, 200, "short")
	var paid: int = int(GameState.get_or_create_player_data("Dealer")["cash"]) - cash0
	_report(paid >= 70 and paid <= 140 and GameState.count_item("Dealer", "weed_bag") == 4,
			"rip-off: customer pays short (€%d of €200)" % paid)
	cash0 = int(GameState.get_or_create_player_data("Dealer")["cash"])
	var bags_before: int = world.get_node("Loot").get_child_count()
	deal.call(3, 200, "run")
	_report(int(GameState.get_or_create_player_data("Dealer")["cash"]) == cash0 and GameState.count_item("Dealer", "weed_bag") == 1 and npc.is_fleeing(),
			"rip-off: customer runs off with 3 bags ('%s')" % p.last_message)
	npc.host_damage(500, null)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var stolen_back: bool = false
	for bag: Node in world.get_node("Loot").get_children():
		for it: Dictionary in (bag as LootBag).items:
			if str(it["id"]) == "weed_bag" and int(it["count"]) == 3:
				stolen_back = true
	_report(world.get_node("Loot").get_child_count() == bags_before + 1 and stolen_back,
			"killing the runner drops the stolen bags")
	GameState.player_data.erase("Dealer")
	p.queue_free()
	await get_tree().physics_frame


# --- Phone (step 8) -------------------------------------------------------------------------

func _check_phone(world: Node3D) -> void:
	var room: Node = world.find_child("StarterRoom", true, false)
	var box: DeliveryBox = room.find_child("DeliveryBox", true, false) as DeliveryBox
	_report(box != null, "starter room has a delivery box")
	if box == null:
		return
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Caller"
	var front: Vector3 = box.global_position + box.global_basis.z * 0.9 + Vector3.UP * 0.1
	p.auto_target = front
	world.get_node("Players").add_child(p)
	p.global_position = front
	for i: int in 10:
		await get_tree().physics_frame
	GameState.player_data.erase("Caller")
	p.send_wallet()
	# Customers text where they are; "On my way" makes them wait, "Not now" sends them off.
	var npc: Pedestrian = null
	for n: Node in get_tree().get_nodes_in_group(&"npc"):
		if not (n as Pedestrian).dead and (n as Pedestrian).wants == 0:
			npc = n as Pedestrian
	world.call("make_customer", npc)
	_report(p.last_phone.size() == 3 and p.last_phone[0] == npc.customer_name and p.last_phone[2] == str(npc.name)
			and str(p.last_phone[1]).contains("Need"), "customer texts the players: %s" % [p.last_phone])
	p._host_phone_reply(str(npc.name), true)
	await get_tree().create_timer(1.0).timeout
	var pos0: Vector3 = npc.global_position
	await get_tree().create_timer(2.0).timeout
	_report(npc._meet_accepted and npc.global_position.distance_to(pos0) < 0.3 and str(p.last_phone[1]).contains("wait"),
			"'On my way': the customer waits (moved %.2f m) - '%s'" % [npc.global_position.distance_to(pos0), p.last_phone[1]])
	p._host_phone_reply(str(npc.name), false)
	_report(npc.wants == 0 and not npc.is_in_group(&"customer"), "'Not now': no longer a customer")
	# Webshop: legal items only, paid now, delivered to the box after an in-game hour.
	var cash0: int = int(GameState.get_or_create_player_data("Caller")["cash"])
	p._host_webshop_buy(&"weed_seed", 1)
	_report(p.last_message.contains("can't") and int(GameState.get_or_create_player_data("Caller")["cash"]) == cash0,
			"webshop refuses illegal items: '%s'" % p.last_message)
	p._host_webshop_buy(&"soil", 2)
	_report(int(GameState.get_or_create_player_data("Caller")["cash"]) == cash0 - 20 and (box.state["pending"] as Array).size() == 1,
			"webshop order paid (€20) and on its way: '%s'" % p.last_message)
	box.tick(DeliveryBox.DELIVERY_HOURS + 0.05)
	_report((box.state["items"] as Array).size() == 1 and p.last_phone[0] == "QuickShip", "order delivered to the box + text")
	var soil0: int = GameState.count_item("Caller", "soil")
	box._server_action(1)
	_report(GameState.count_item("Caller", "soil") == soil0 + 2 and (box.state["items"] as Array).is_empty(),
			"take the delivery: +2 soil ('%s')" % p.last_message)
	# Phone UI: messages, unread count, every app opens.
	var phone := Phone.new()
	add_child(phone)
	phone.add_message("Kevin", "Need 2 bags", "Pedestrian")
	phone.add_message("Kevin", "Hello?", "")
	_report(phone.total_unread() == 2, "phone counts unread messages (%d)" % phone.total_unread())
	phone.open()
	for screen: String in ["list", "map", "shop", "home"]:
		phone._show(screen)
		await get_tree().process_frame
	phone._contact = "Kevin"
	phone._show("thread")
	await get_tree().process_frame
	_report(phone.total_unread() == 0, "reading the thread clears unread")
	phone.queue_free()
	GameState.player_data.erase("Caller")
	p.queue_free()
	await get_tree().physics_frame


# --- Save / load (step 9) -------------------------------------------------------------------

func _check_save(world: Node3D) -> void:
	SaveManager.enabled = true
	SaveManager.save_path = "user://selftest_save.json"
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Saver"
	var spot := Vector3(-20.0, 0.2, -4.6)
	p.auto_target = spot
	world.get_node("Players").add_child(p)
	p.global_position = spot
	for i: int in 10:
		await get_tree().physics_frame
	GameState.player_data.erase("Saver")
	var rec: Dictionary = GameState.get_or_create_player_data("Saver")
	rec["cash"] = 777
	GameState.give("Saver", 0, [{"id": "weed_bag", "count": 3}])
	p.health = 64
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	dn.set_hours(15.5)
	world.call("spawn_loot_bag", Vector3(-22, 0.5, -4.6), "Ghost", 42, [{"id": "soil", "count": 2}])
	await get_tree().physics_frame
	var stations_before: int = (GameState.world["stations"] as Dictionary).size()
	_report(SaveManager.save_game() and SaveManager.save_game() and SaveManager.has_save()
			and FileAccess.file_exists(SaveManager.save_path + ".bak"), "game saves (with a .bak of the previous save)")
	var pos_saved: Vector3 = p.global_position
	GameState.reset()
	_report(SaveManager.load_game(), "save loads")
	var r: Dictionary = GameState.player_data.get("Saver", {})
	var bag_count: int = 0
	var int_counts: bool = true
	for it: Dictionary in r.get("inventory", []):
		int_counts = int_counts and typeof(it["count"]) == TYPE_INT
		if str(it["id"]) == "weed_bag":
			bag_count = int(it["count"])
	_report(typeof(r.get("cash")) == TYPE_INT and int(r["cash"]) == 777 and bag_count == 3 and int_counts,
			"player cash + items survive (ints stay ints): €%s, %d bags" % [r.get("cash"), bag_count])
	_report(r.get("pos") is Vector3 and (r["pos"] as Vector3).distance_to(pos_saved) < 0.2 and int(r.get("health", 0)) == 64
			and r.get("mags") is Array, "player position, health and magazines saved (%s, %s hp)" % [r.get("pos"), r.get("health")])
	_report(absf(float(GameState.world.get("hours", 0.0)) - 15.5) < 0.05, "time of day saved (%.2f)" % float(GameState.world.get("hours", 0.0)))
	_report((GameState.world.get("stations", {}) as Dictionary).size() == stations_before and stations_before > 0,
			"station states saved (%d)" % stations_before)
	var bags: Array = GameState.world.get("loot_bags", [])
	_report(bags.size() >= 1 and str(bags[bags.size() - 1]["owner"]) == "Ghost" and bags[bags.size() - 1]["pos"] is Vector3,
			"loot bags saved (%d)" % bags.size())
	# Clean up: never leave test saves behind; tests don't save by default.
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.save_path + suffix))
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.enabled = false
	p.queue_free()
	await get_tree().physics_frame
