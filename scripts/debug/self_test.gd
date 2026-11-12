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

var _fails: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState.infinite_cash = false  # test the real money rules
	var world: Node3D = get_parent()
	await _wait_for_navmesh(world)
	_check_lamps(world)
	_check_debug_labels()
	await _check_doors(world)
	await _check_player(world)
	await _check_stairs(world)
	await _check_combat(world)
	await _check_shops(world)
	await _check_gun_shop(world)
	await _check_growing(world)
	await _check_pedestrians(world)
	await _check_npc_combat(world)
	await _check_selling(world)
	await _check_phone(world)
	await _check_traffic(world)
	await _check_save(world)
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

func _check_debug_labels() -> void:
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
	# Walk up the first flight of a house.
	var h: Building = houses[0]
	var x: float = -h.width / 2.0 + Building.WALL_T + Building.STAIR_W / 2.0
	var z0: float = -h.depth + Building.WALL_T
	var front: float = z0 + Building.LANDING + h._stair_run()
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Climber"
	world.get_node("Players").add_child(p)
	p.global_position = h.to_global(Vector3(x, 0.2, front + 0.6))
	p.auto_target = h.to_global(Vector3(x, 0, z0 + 0.4))
	for i: int in 300:
		await get_tree().physics_frame
	var up: float = p.global_position.y - h.global_position.y
	_report(up > h.floor_height, "player walks up the stairs of %s to the first floor (%.2f m up)" % [h.name, up])
	p.queue_free()
	await get_tree().physics_frame


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


# --- Weed growing --------------------------------------------------------------------

func _check_growing(world: Node3D) -> void:
	var room: Node = world.find_child("StarterRoom", true, false)
	var pot: GrowPot = room.find_child("Pot1", true, false) as GrowPot
	var lamp: GrowLamp = room.find_child("GrowLamp", true, false) as GrowLamp
	var rack: DryingRack = room.find_child("DryingRack", true, false) as DryingRack
	_report(pot != null and lamp != null and rack != null, "starter room has pots, a grow lamp and a drying rack")
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


# --- Packaging + selling (step 7) --------------------------------------------------------

func _check_selling(world: Node3D) -> void:
	var room: Node = world.find_child("StarterRoom", true, false)
	var table: PackagingTable = room.find_child("PackagingTable", true, false) as PackagingTable
	_report(table != null, "starter room has a packaging table")
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
