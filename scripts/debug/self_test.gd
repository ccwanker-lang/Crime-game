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
## Prints "[SelfTest] PASS/FAIL ..." lines and quits.

const WALKER: PackedScene = preload("res://scenes/player/player.tscn")
const LAMP_PREFABS: Array[String] = ["street_lamp.tscn", "floodlight_pole.tscn"]

var _fails: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: Node3D = get_parent()
	await _wait_for_navmesh(world)
	_check_lamps(world)
	_check_debug_labels()
	await _check_doors(world)
	await _check_player(world)
	await _check_combat(world)
	await _check_shops(world)
	await _check_pedestrians(world)
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
	_report(c.mag == c.weapon.magazine_size and c.reserve == c.weapon.starting_reserve - 1,
			"reload refills (mag %d, reserve %d)" % [c.mag, c.reserve])

	# Damage and death.
	p.host_damage(30, null)
	_report(p.health == Player.MAX_HEALTH - 30, "damage lowers health to %d" % p.health)
	var cash: int = int(GameState.get_or_create_player_data(p.player_name)["cash"])
	var death_pos: Vector3 = p.global_position
	p.host_damage(200, null)
	await get_tree().physics_frame
	var bags: Array[Node] = world.get_node("Loot").get_children()
	_report(p.dead and p.collision_layer == 0, "player dies at 0 health (not solid while dead)")
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
			and GameState.count_item("Shopper", "soil") == 5 and p.inventory.size() == 1,
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
	_report(bag != null and bag.items.size() == 1 and int(bag.items[0]["count"]) == 5 and p.inventory.is_empty(),
			"death puts carried items in the loot bag")
	await get_tree().create_timer(Player.RESPAWN_TIME + 0.5).timeout
	if bag:
		bag.queue_free()
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
	_report(totals["walk"] >= 8 and totals["sit"] + totals["visit"] > 0, "activities: %s" % totals)
	# Getting stuck now and then is fine (it backs off); staying stuck is not.
	_report(worst_stuck <= 2 and totals["stuck"] <= 5,
			"nobody stays stuck (%d stuck moves, worst NPC %d)" % [totals["stuck"], worst_stuck])
