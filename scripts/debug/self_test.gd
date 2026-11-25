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

const CHECKS: Array[String] = ["items", "ground", "grass", "lamps", "debug_labels", "doors", "player", "kerb", "admin", "held", "stairs", "furniture", "balconies", "combat", "shops", "gun_shop", "black_market", "placement", "build_mode", "sleep", "storage", "bookshelf", "trash", "real_estate", "laundering", "growing", "pedestrians", "npc_combat", "police", "wanted", "police_life", "rivals", "harbour", "police_vs_crows", "park", "vehicles", "garage", "territory", "intro", "prison", "pass", "city", "city_shops", "building_sites", "street_detail", "weather", "apartments", "roads", "slums", "army", "airfield", "bunker", "bunker_inside", "bunker_rooms", "fuel", "regen", "selling", "phone", "traffic", "lights", "save", "ranks", "staff", "meth", "cocaine", "services", "raids", "roadside", "bulk", "quality", "range", "engine_sound", "run_over", "car_roof", "dogs", "animals", "staff_assign", "zones", "missions", "streaming", "grass_roads", "day_rhythm", "settings", "soundscape", "menus", "steam", "gamepad", "quality_levels", "shop_sellers"]

var _fails: int = 0
var _corner: Dictionary = {}  # the test weed corner (World.debug_weed_corner), placed once


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState.infinite_cash = false  # test the real money rules
	Wanted.enabled = false  # point 28: only the "wanted" check uses stars (the others test the plain AI)
	var world: Node3D = get_parent()
	await _wait_for_navmesh(world)
	# --only=stairs,traffic runs just those checks (names = the _check_* suffix).
	var only: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	# A SCRIPT ERROR inside a check aborts that check function; it must count as a FAIL, not pass unnoticed.
	var errors := ScriptErrorCounter.new()
	OS.add_logger(errors)
	for check: String in CHECKS:
		if only.is_empty() or check in only:
			var before: int = errors.count()
			await call("_check_" + check, world)
			var n: int = errors.count() - before
			if n > 0:
				_report(false, "check '%s': %d SCRIPT ERROR(s), last: %s" % [check, n, errors.last()])
	OS.remove_logger(errors)
	print("[SelfTest] Done: %s" % ("ALL PASSED" if _fails == 0 else "%d FAILED" % _fails))
	Net.leave_game()
	get_tree().quit(1 if _fails > 0 else 0)


## Staff + dealers (scripts/debug/staff_test.gd).
func _check_staff(world: Node3D) -> void:
	await StaffTest.run(self, world)


## Milestone 3 Crow raids on labs + guards (scripts/debug/raid_test.gd).
func _check_raids(world: Node3D) -> void:
	await RaidTest.run(self, world)


## Session B (product quality): how many of `id` a player carries, every quality (Quality.variants).
func _count_q(who: String, id: String) -> int:
	var n: int = 0
	for v: String in Quality.variants(id):
		n += GameState.count_item(who, v)
	return n


## Milestone 3 product quality (scripts/debug/quality_test.gd).
func _check_quality_levels(world: Node3D) -> void:
	await QualityLevelsTest.run(self, world)


## NOTES part 19 missions (scripts/debug/missions_test.gd).
func _check_missions(world: Node3D) -> void:
	await MissionsTest.run(self, world)


## NOTES part 18 zones: army base, slums, city, bunker (scripts/debug/zones_test.gd).
func _check_zones(world: Node3D) -> void:
	await ZonesTest.run(self, world)


## Roadmap 88 (session B): the village crowd by the clock (scripts/debug/day_rhythm_test.gd).
func _check_day_rhythm(world: Node3D) -> void:
	await DayRhythmTest.run(self, world)


## Session B user list item 1: the settings menu (scripts/debug/settings_test.gd).
func _check_settings(world: Node3D) -> void:
	await SettingsTest.run(self, world)


## Session B user list item 2: ambience, music, footsteps (scripts/debug/soundscape_test.gd).
func _check_soundscape(world: Node3D) -> void:
	await SoundscapeTest.run(self, world)


## Session B user list item 3: save slots, title page, loading screen, pause menu (scripts/debug/menus_test.gd).
func _check_menus(world: Node3D) -> void:
	await MenusTest.run(self, world)


## Session B user list item 4: Steam co-op without starting Steam (scripts/debug/steam_test.gd).
func _check_steam(world: Node3D) -> void:
	await SteamTest.run(self, world)


## City life point 1: sellers behind every shop till (scripts/debug/shop_sellers_test.gd).
func _check_shop_sellers(world: Node3D) -> void:
	await ShopSellersTest.run(self, world)


## Performance rules (2026-11-24): quality levels scale the world (scripts/debug/quality_test.gd).
func _check_quality(world: Node3D) -> void:
	await QualityTest.run(self, world)


## Session B user list item 5: controller support (scripts/debug/gamepad_test.gd).
func _check_gamepad(world: Node3D) -> void:
	await GamepadTest.run(self, world)


## NOTES part 12 staff assignment + staff locker wages (scripts/debug/staff_assign_test.gd).
func _check_staff_assign(world: Node3D) -> void:
	await StaffAssignTest.run(self, world)


## Roadmap 68 birds, pigeons, cats, ducks (scripts/debug/animals_test.gd).
func _check_animals(world: Node3D) -> void:
	await AnimalsTest.run(self, world)


## Roadmap 67 dogs as real NPCs (scripts/debug/dogs_test.gd).
func _check_dogs(world: Node3D) -> void:
	await DogsTest.run(self, world)


## Roadmap 65 standing on cars (scripts/debug/car_roof_test.gd).
func _check_car_roof(world: Node3D) -> void:
	await CarRoofTest.run(self, world)


## Roadmap 64 running people over from any side (scripts/debug/run_over_test.gd).
func _check_run_over(world: Node3D) -> void:
	await RunOverTest.run(self, world)


## Roadmap 66 engine / tyre / brake sound (scripts/debug/engine_sound_test.gd).
func _check_engine_sound(world: Node3D) -> void:
	await EngineSoundTest.run(self, world)


## Milestone 3 shooting range (scripts/debug/range_test.gd).
func _check_range(world: Node3D) -> void:
	await RangeTest.run(self, world)


## Milestone 3 bulk deals (scripts/debug/bulk_test.gd).
func _check_bulk(world: Node3D) -> void:
	await BulkTest.run(self, world)


## Milestone 3 roadside team (scripts/debug/roadside_test.gd).
func _check_roadside(world: Node3D) -> void:
	await RoadsideTest.run(self, world)


## Milestone 3 courier, lawyer, bribes (scripts/debug/services_test.gd).
func _check_services(world: Node3D) -> void:
	await ServicesTest.run(self, world)


## Milestone 3 cocaine (scripts/debug/coke_test.gd).
func _check_cocaine(world: Node3D) -> void:
	await CokeTest.run(self, world)


## Milestone 3 meth (scripts/debug/meth_test.gd).
func _check_meth(world: Node3D) -> void:
	await MethTest.run(self, world)


## Ranks + XP (scripts/debug/rank_test.gd).
func _check_ranks(world: Node3D) -> void:
	await RankTest.run(self, world)


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
	# Point 41: the mouse wheel walks through every hotbar slot (pistol -> can -> empty ... -> pistol).
	p.combat.cycle(1)
	var after_one: bool = p.combat.selected_slot == 1 and not p.combat.equipped and p.net_held == &"watering_can"
	p.combat.cycle(1)
	var after_two: bool = p.combat.selected_slot == 2 and p.net_held == &""
	p.combat.cycle(-1)
	p.combat.cycle(-1)
	_report(after_one and after_two and p.combat.equipped and p.combat.hotbar_slot() == 0,
			"the mouse wheel scrolls through the hotbar slots (%s, %s, back to the pistol: %s)" % [after_one, after_two,
			p.combat.equipped])
	p.combat.select_slot(7)
	p.combat.cycle(1)
	_report(p.combat.hotbar_slot() == 0 and p.combat.equipped, "and wraps around from slot 8 to slot 1")
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
		if door is BunkerLift or door is BunkerDoor:
			continue  # lifts + the bunker's blast door: own checks (bunker_inside, apartments)
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

## A property's building, or the property node itself when it has none (the bunker: BunkerProperty sits in
## Mountain/Bunker, no Building parent).
func _prop_anchor(prop: Property) -> Node3D:
	var b: Building = prop.building()
	return b if b != null else prop


func _check_real_estate(world: Node3D) -> void:
	# Point 35: every property has a map spot inside its own building (owned icon / for-sale pin).
	var bad: PackedStringArray = []
	for n: Node in get_tree().get_nodes_in_group(&"properties"):
		var prop := n as Property
		var spot: Vector2 = PhoneMap.property_spot(prop)
		if not prop.contains(Vector3(spot.x, _prop_anchor(prop).global_position.y + 0.5, spot.y)):
			bad.append(prop.display_name)
	_report(bad.is_empty(), "map: every property's icon sits on its own building%s" % (" (wrong: %s)" % ", ".join(bad) if not bad.is_empty() else ""))
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
		var bi: Node3D = _prop_anchor(homes[i] as Property)
		to_police = minf(to_police, bi.global_position.distance_to(station.global_position))
		for j: int in range(i + 1, homes.size()):
			closest = minf(closest, bi.global_position.distance_to(_prop_anchor(homes[j] as Property).global_position))
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


# --- Bookshelf storage (point 38) --------------------------------------------------------

func _check_bookshelf(world: Node3D) -> void:
	var item: ItemData = ItemDB.get_item(&"bookshelf")
	_report(item != null and item.place_scene != null and item.place_scene.resource_path.ends_with("bookshelf_storage.tscn"),
			"the bookshelf item places a storage bookshelf")
	var spot: Node3D = world.get_marker("LockerSpot")
	var sr: Property = world.find_child("StarterRoom", true, false).get_node("Property") as Property
	var at: Vector3 = spot.global_position - sr.building().global_basis.x * 2.0
	var shelf := world.call("host_place", "bookshelf", at, spot.global_rotation.y) as BookshelfStorage
	await get_tree().physics_frame
	_report(shelf != null and shelf.storage_name() == "Bookshelf" and shelf.get_node_or_null("Shelf") != null,
			"a placed bookshelf is a storage station with the bookshelf model")
	if shelf == null:
		return
	GameState.player_data.erase("Reader")
	var d: Dictionary = GameState.get_or_create_player_data("Reader")
	d["inventory"] = [{"id": "baggie", "count": 20}]
	shelf.host_move("Reader", true, 0, 0)
	_report((shelf.state["items"] as Array).size() == 1 and GameState.count_item("Reader", "baggie") == 0,
			"put a stack in the bookshelf: %s" % [shelf.state["items"]])
	_report(shelf.pick_up_blocker() != "", "a full bookshelf can't be picked up ('%s')" % shelf.pick_up_blocker())
	shelf.host_move("Reader", false, 0, 0)
	_report(GameState.count_item("Reader", "baggie") == 20, "and take it out again")
	world.call("host_remove_placed", shelf.placed_uid)
	GameState.player_data.erase("Reader")
	await get_tree().physics_frame


# --- Trash bin + garbage truck (point 39) --------------------------------------------------

func _check_trash(world: Node3D) -> void:
	var sr: Property = world.find_child("StarterRoom", true, false).get_node("Property") as Property
	var b: Building = sr.building()
	var item: ItemData = ItemDB.get_item(&"trash_bin")
	_report(item != null and item.is_legal and item.place_scene != null, "the trash bin is a legal placeable item")
	var spot: Vector3 = Scenarios.outdoor_bin_spot(world, sr)
	var w3d: World3D = world.get_world_3d()
	_report(Placement.check(w3d, get_tree(), item, spot, b.global_rotation.y) == "",
			"a bin may stand on the pavement in front of the Starter Room (%s)" % spot.snapped(Vector3.ONE * 0.1))
	var road: Array = (world.get_node("Traffic") as Traffic).nearest(spot)
	var lane: Vector3 = (world.get_node("Traffic") as Traffic).routes[int(road[0])].sample(float(road[1]))[0]
	var on_road := Vector3(lane.x, spot.y, lane.z)
	_report(Placement.check(w3d, get_tree(), item, on_road, 0.0) != "",
			"not on the road ('%s')" % Placement.check(w3d, get_tree(), item, on_road, 0.0))
	_report(Placement.check(w3d, get_tree(), ItemDB.get_item(&"sofa"), spot, 0.0) != "", "a sofa may not stand outside")
	var far_front: Vector3 = b.to_global(Vector3(0, 0.1, 12.0))
	_report(Placement.check(w3d, get_tree(), item, far_front, 0.0) != "", "not far from your own front door")
	# Trash comes from deliveries and harvests; E throws it in the bin.
	var bin := world.call("host_place", "trash_bin", spot, b.global_rotation.y) as TrashBin
	await get_tree().physics_frame
	_report(bin != null and bin.is_in_group(&"trash_bins"), "a placed trash bin is a station")
	if bin == null:
		return
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Binman"
	var front: Vector3 = spot + b.global_basis.z * 1.0
	p.auto_target = front
	world.get_node("Players").add_child(p)
	p.global_position = front + Vector3.UP * 0.1
	for i: int in 5:
		await get_tree().physics_frame
	GameState.player_data.erase("Binman")
	var d: Dictionary = GameState.get_or_create_player_data("Binman")
	d["inventory"] = [{"id": "empty_box", "count": 3}, {"id": "plant_waste", "count": 2}, {"id": "baggie", "count": 5}]
	var msg: String = bin.do_action(p)
	_report(bin.trash() == 5 and GameState.count_item("Binman", "empty_box") == 0
			and GameState.count_item("Binman", "plant_waste") == 0 and GameState.count_item("Binman", "baggie") == 5,
			"E throws only the trash in the bin ('%s', bin %d)" % [msg, bin.trash()])
	var box := DeliveryBox.new()
	box.station_id = "test/trash_delivery"
	add_child(box)
	box.state["items"] = [{"id": "soil", "count": 1}]
	box.do_action(p)
	_report(GameState.count_item("Binman", "empty_box") == 1, "taking a delivery leaves an empty box")
	box.queue_free()
	(GameState.world["stations"] as Dictionary).erase("test/trash_delivery")
	# An inside bin is never collected; the outside one gets a truck that stops and empties it.
	var inside := world.call("host_place", "trash_bin", b.to_global(Vector3(-1.0, 0.1, -2.0)), 0.0) as TrashBin
	await get_tree().physics_frame
	if inside:
		inside.state["trash"] = 4
	var garbage: Garbage = Garbage.current(get_tree())
	var sent: int = garbage.dispatch() if garbage else 0
	var truck: Car = null
	for c: Node in get_tree().get_nodes_in_group(&"garbage_trucks"):
		truck = c as Car
	_report(sent == 1 and truck != null and truck.garbage_stops.size() == 1,
			"the garbage truck is sent for the outside bin only (%d truck(s), %d stop(s))" % [sent,
			truck.garbage_stops.size() if truck else -1])
	var t: int = 0
	var stopped_near: float = INF
	while t < 60 * 40 and bin.trash() > 0 and is_instance_valid(truck):
		await get_tree().physics_frame
		t += 1
		if truck.speed < 0.1:
			stopped_near = minf(stopped_near, truck.global_position.distance_to(bin.global_position))
	_report(bin.trash() == 0 and stopped_near < Placement.LANE_MAX + 1.0,
			"the truck stops next to the bin and empties it (%.1f s, stopped %.1f m from it)" % [t / 60.0, stopped_near])
	_report(inside == null or inside.trash() == 4, "the bin inside the house is left alone")
	t = 0
	while t < 60 * 30 and is_instance_valid(truck):
		await get_tree().physics_frame
		t += 1
	_report(not is_instance_valid(truck), "and goes off duty afterwards (%.1f s)" % [t / 60.0])
	world.call("host_remove_placed", bin.placed_uid)
	if inside:
		world.call("host_remove_placed", inside.placed_uid)
	p.queue_free()
	GameState.player_data.erase("Binman")
	await get_tree().physics_frame


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
	# Point 40: the deposit message says what comes back and when; the ledger lists it.
	_report(msg.contains("€3000 deposited") and msg.contains("€2700 clean") and msg.contains("ready around"),
			"the deposit message tells what comes back clean and when ('%s')" % msg)
	var ledger: Array = bakery.ledger()
	_report(ledger.size() == 1 and int(ledger[0]["dirty"]) == 3000 and int(ledger[0]["clean"]) == 2700
			and absf(float(ledger[0]["hours"]) - 48.0) < 0.01,
			"the safe's ledger shows the pending money (%s)" % [ledger])
	_report(LaunderSafe.eta_text(10.0, 48.0) == "around 10:00 in 2 days" and LaunderSafe.eta_text(22.0, 4.0) == "around 02:00 tomorrow",
			"ready times read well ('%s', '%s')" % [LaunderSafe.eta_text(10.0, 48.0), LaunderSafe.eta_text(22.0, 4.0)])
	p.last_phone = []
	bakery.tick(12.0)
	_report(int(d["clean"]) == 630 and bakery.queued_total() == 2300,
			"half a day launders €700 (in €100 chunks) -> €630 clean (clean %d, safe %d)" % [d["clean"], bakery.queued_total()])
	bakery.tick(48.0)
	_report(int(d["clean"]) == 2700 and bakery.queued_total() == 0 and bakery.state["queue"].is_empty(),
			"everything comes back clean minus 10%% (clean %d)" % d["clean"])
	_report(p.last_phone.size() == 3 and str(p.last_phone[0]) == "Bakery" and str(p.last_phone[1]).contains("€2700"),
			"a text from the business when the money is clean (%s)" % [p.last_phone])
	_report((bakery.state.get("paid", {}) as Dictionary).is_empty(), "the payout tally starts over after that")
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
	# (An earlier check - sleep - may have left a grown plant in the shared corner pot.)
	pot.state.merge(pot.default_state(), true)
	pot.changed()
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
	# Point 42: hands-on work plays an animation (kneel at the low pot, can tips, drops fall).
	var drops: int = 0
	for n: Node in world.get_children():
		if n is CPUParticles3D:
			drops += 1
	_report(p.is_working() and p._work_kind == "water" and drops > 0,
			"watering: drops at the pot (kind '%s', %d particle burst(s))" % [p._work_kind, drops])
	for i: int in 12:
		await get_tree().physics_frame
	# Point 58: no kneeling / body animation for using things any more.
	_report(p._pose.crouch < 0.05 and p._work_low == 0.0, "the body does not kneel (crouch %.2f)" % p._pose.crouch)
	var before: int = world.get_children().filter(func(n: Node) -> bool: return n is CPUParticles3D).size()
	world.call("host_poof", p.global_position + Vector3.UP)
	var after: int = world.get_children().filter(func(n: Node) -> bool: return n is CPUParticles3D).size()
	_report(after == before + 1, "placing / picking up makes a poof at the object (%d -> %d)" % [before, after])
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
	# (Session B, product quality: grown under the lamp = Good Fresh Weed; count every quality.)
	_report(int(pot.state["stage"]) == GrowPot.Stage.EMPTY and _count_q("Grower", "fresh_weed") == GrowPot.YIELD,
			"harvest gives %d Fresh Weed and empties the pot" % _count_q("Grower", "fresh_weed"))

	p.teleport(rack.global_position + rack.global_basis.z * 0.9 + Vector3.UP * 0.1)
	await get_tree().physics_frame
	_report(rack.prompt_for(p).begins_with("Hang"), "rack prompt: '%s'" % rack.prompt_for(p))
	rack._server_action(1)
	_report(int(rack.state["wet"]) == GrowPot.YIELD and _count_q("Grower", "fresh_weed") == 0, "fresh weed hangs on the rack")
	rack.tick(DryingRack.DRY_HOURS + 0.1)
	_report(int(rack.state["dry"]) == GrowPot.YIELD and int(rack.state["wet"]) == 0, "it dries after %d hours" % int(DryingRack.DRY_HOURS))
	rack._server_action(1)
	_report(_count_q("Grower", "weed_bud") == GrowPot.YIELD and int(rack.state["dry"]) == 0,
			"take %d Dried Weed off the rack" % _count_q("Grower", "weed_bud"))
	var visible_buds: int = 0
	for c: Node in rack.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).visible and (c as MeshInstance3D).mesh in [rack._bud_mesh_wet, rack._bud_mesh_dry]:
			visible_buds += 1
	_report(visible_buds == 0, "rack shows no buds when empty")
	GameState.player_data.erase("Grower")
	p.queue_free()
	await get_tree().physics_frame


# --- Pedestrians -----------------------------------------------------------------

## Point 87: NPC streaming - asleep beyond the despawn radius (no AI / physics / drawing, position kept), MID / FULL
## nearer, hysteresis between spawn and despawn radius, mission NPCs always awake, deals first under the cap, and
## nobody wakes up in view right in front of a player.
func _check_streaming(world: Node3D) -> void:
	# Point 90 part 2: WorldLod's shadow budget + far-process LOD (headless runs no WorldLod, so drive one by hand).
	var lod := WorldLod.new()
	var holder := Node3D.new()
	world.add_child(holder)
	for i: int in 24:
		var l := OmniLight3D.new()
		l.shadow_enabled = true
		holder.add_child(l)
		l.global_position = Vector3(5000.0 + i * 5.0, 50, 5000)
		lod.shadow_lights.append(l)
	var near_node := Node3D.new()
	var far_node := Node3D.new()
	holder.add_child(near_node)
	holder.add_child(far_node)
	near_node.global_position = Vector3(5010, 50, 5000)
	far_node.global_position = Vector3(5000, 50, 5600)
	near_node.set_process(true)
	far_node.set_process(true)
	lod.far_nodes.append(near_node)
	lod.far_nodes.append(far_node)
	lod.update_budget(Vector3(5000, 50, 5000))
	var on: Array[int] = []
	for i: int in 24:
		if (lod.shadow_lights[i] as Light3D).shadow_enabled:
			on.append(i)
	_report(lod.shadows_on == 16 and on.size() == 16 and on.max() == 15,
			"shadow budget: only the 16 nearest of 24 shadowed lights in range cast shadows (%d on, farthest on = #%d)" % [lod.shadows_on, on.max() if on.size() else -1])
	_report(near_node.is_processing() and not far_node.is_processing() and lod.far_off == 1,
			"far-process LOD: a ticking prop 600 m away stops its per-frame code, one 10 m away keeps it")
	lod.update_budget(Vector3(5000, 50, 5600))
	_report(far_node.is_processing() and not near_node.is_processing() and lod.shadows_on == 0,
			"walking over: the far prop ticks again, the old one stops; lights 600 m away cast no shadow (%d on)" % lod.shadows_on)
	# Point 98: quality hooks - fewer shadowed lights, shorter draw distances (rescaled after the fact), less grass.
	WorldLod.max_shadows = 4
	lod.update_budget(Vector3(5000, 50, 5000))
	var low_on: int = lod.shadows_on
	WorldLod.max_shadows = WorldLod.MAX_SHADOWS
	holder.add_child(lod)  # (headless: _ready only joins the group)
	var prop := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.8, 0.8, 0.8)
	prop.mesh = pm
	holder.add_child(prop)
	lod._one(prop, "")
	var before: float = prop.visibility_range_end
	WorldLod.set_range_scale(get_tree(), 0.6)
	var low_range: float = prop.visibility_range_end
	WorldLod.set_range_scale(get_tree(), 1.0)
	var dense: int = GrassCover.tuft_points(world.get_world_3d().direct_space_state, Vector2i(11, -6)).size()
	GrassCover.density_scale = 0.35
	var thin: int = GrassCover.tuft_points(world.get_world_3d().direct_space_state, Vector2i(11, -6)).size()
	GrassCover.density_scale = 1.0
	_report(low_on == 4 and is_equal_approx(before, WorldLod.PROP_RANGE) and is_equal_approx(low_range, WorldLod.PROP_RANGE * 0.6)
			and is_equal_approx(prop.visibility_range_end, WorldLod.PROP_RANGE) and dense > 20 and thin < dense * 0.6,
			"quality hooks: max_shadows 4 -> %d shadowed lights, range scale 0.6 -> a prop at %.0f m (was %.0f), grass %d -> %d tufts per chunk" % [low_on, low_range, before, dense, thin])
	lod.queue_free()
	# StaticBatcher: 5 fence posts + 3 benches + 1 street lamp in one square -> one batch per fence/bench mesh, the
	# originals hidden, the lamp (night glow per surface) left alone, collisions untouched.
	var fence: PackedScene = load("res://prefabs/props/chainlink_fence.tscn")
	var bench: PackedScene = load("res://prefabs/props/bench.tscn")
	var lamp: PackedScene = load("res://prefabs/props/street_lamp.tscn")
	var props := Node3D.new()
	holder.add_child(props)
	for i: int in 5:
		var f: Node3D = fence.instantiate()
		props.add_child(f)
		f.global_position = Vector3(5000.0 + i * 2.0, 50, 5010)
	for i: int in 3:
		var b: Node3D = bench.instantiate()
		props.add_child(b)
		b.global_position = Vector3(5000.0 + i * 3.0, 50, 5014)
	var lp: Node3D = lamp.instantiate()
	props.add_child(lp)
	lp.global_position = Vector3(5004, 50, 5016)
	await get_tree().process_frame
	var res: Array[int] = StaticBatcher.batch(props, holder)
	var shown: int = 0
	for mi: Node in props.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).visible and not mi.has_meta(&"batched") and not lp.is_ancestor_of(mi):
			shown += 1
	var batches: Node = holder.get_node_or_null("StaticBatches")
	var inst: int = 0
	if batches:
		for c: Node in batches.get_children():
			inst += (c as MultiMeshInstance3D).multimesh.instance_count
	var lamp_vis: bool = true
	for mi: Node in lp.find_children("*", "MeshInstance3D", true, false):
		lamp_vis = lamp_vis and (mi as MeshInstance3D).visible
	_report(res[0] >= 1 and res[1] == inst and shown == 0 and lamp_vis and props.find_children("*", "CollisionShape3D", true, false).size() >= 9,
			"StaticBatcher: %d batches draw %d fence/bench meshes (%d instances), none left visible twice, the street lamp untouched" % [res[0], res[1], inst])
	holder.queue_free()
	var st: NpcStreamer = world.get_node_or_null("NpcStreamer") as NpcStreamer
	_report(st != null and st.config != null, "the NPC streamer + its config (data/npc/streaming.tres)")
	if st == null:
		return
	var cfg: NpcStreamConfig = st.config
	var p: Player = WALKER.instantiate()
	p.name = "1"
	p.player_name = "Streamer"
	world.get_node("Players").add_child(p)
	var base := Vector3(-8, 0.3, -4.6)
	p.global_position = base
	p.rotation.y = 0.0  # looks -Z
	await get_tree().physics_frame
	var mk := func(off: Vector3, nm: String = "") -> Pedestrian:
		var n: Pedestrian = world.call("_add_pedestrian", base + off, 0)
		if nm != "":
			n.name = nm
		return n
	var near: Pedestrian = mk.call(Vector3(0, 0, 20))  # behind the player
	var mid: Pedestrian = mk.call(Vector3(0, 0, cfg.full_radius + 40.0))
	var far: Pedestrian = mk.call(Vector3(cfg.despawn_radius + 80.0, 0, 0))
	var mission: Pedestrian = mk.call(Vector3(-cfg.despawn_radius - 80.0, 0, 0), "MissionNPC_streamtest")
	for n: Pedestrian in [near, mid, far, mission]:
		n.set_physics_process(false)  # (stand still: the test moves the player, not them)
	await get_tree().physics_frame
	st.update_now()
	var far_pos: Vector3 = far.global_position
	_report(near.lod == Pedestrian.Lod.FULL and mid.lod == Pedestrian.Lod.MID and far.lod == Pedestrian.Lod.ASLEEP
			and mission.lod != Pedestrian.Lod.ASLEEP,
			"levels by distance: 20 m FULL (%d), %.0f m MID (%d), %.0f m asleep (%d), a mission NPC that far stays awake (%d)" % [
			near.lod, cfg.full_radius + 40.0, mid.lod, cfg.despawn_radius + 80.0, far.lod, mission.lod])
	_report(far.process_mode == Node.PROCESS_MODE_DISABLED and not far.visible and far.collision_layer == 0,
			"asleep = no scripts, not drawn, no collision")
	# Hysteresis: between the radii nothing changes.
	p.global_position = far.global_position + Vector3(-(cfg.spawn_radius + cfg.despawn_radius) / 2.0, 0, 0)
	st.update_now()
	var still_asleep: bool = far.lod == Pedestrian.Lod.ASLEEP
	p.global_position = far.global_position + Vector3(-cfg.spawn_radius + 30.0, 0, 0)
	p.rotation.y = PI / 2.0  # looks -X: away from it
	st.update_now()
	_report(still_asleep and far.lod != Pedestrian.Lod.ASLEEP and far.global_position.is_equal_approx(far_pos) and far.visible
			and far.process_mode != Node.PROCESS_MODE_DISABLED,
			"hysteresis: asleep until within %.0f m, then it wakes where it was (%s)" % [cfg.spawn_radius, far.global_position.snapped(Vector3.ONE * 0.1)])
	# No popping up in view: an asleep NPC 30 m right in front stays asleep while the player looks at it.
	far.set_lod(Pedestrian.Lod.ASLEEP)
	p.global_position = far.global_position + Vector3(0, 0, 30)
	p.rotation.y = 0.0  # looks -Z, straight at it
	st.update_now()
	var stayed: bool = far.lod == Pedestrian.Lod.ASLEEP
	p.rotation.y = PI  # turns round
	st.update_now()
	_report(stayed and far.lod != Pedestrian.Lod.ASLEEP, "nobody wakes up in view %.0f m in front of a player (only once he looks away)" % 30.0)
	# The cap: deals first, then the nearest.
	p.global_position = base
	p.rotation.y = 0.0
	mid.wants = 1
	NpcStreamer.cap_override = 1
	st.update_now()
	var capped: bool = mid.lod != Pedestrian.Lod.ASLEEP and near.lod == Pedestrian.Lod.ASLEEP and mission.lod != Pedestrian.Lod.ASLEEP
	NpcStreamer.cap_override = -1
	mid.wants = 0
	_report(capped, "max_active_npcs: over the cap the customer (deal) stays awake before a nearer NPC; mission NPCs always")
	for n: Node in get_tree().get_nodes_in_group(&"npc"):
		(n as Pedestrian).set_lod(Pedestrian.Lod.FULL)
	for n: Pedestrian in [near, mid, far, mission]:
		n.queue_free()
	p.queue_free()
	GameState.player_data.erase("Streamer")
	await get_tree().physics_frame


func _check_pedestrians(world: Node3D) -> void:
	# (With --only this runs right after the bake: random points need the map's regions ready.)
	for i: int in 120:
		if NavigationServer3D.map_get_random_point(world.get_world_3d().navigation_map, 1, true) != Vector3.ZERO:
			break
		await get_tree().physics_frame
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
			if (n as Pedestrian).crossing_road or (n as Pedestrian)._direct:
				continue  # point 29: crossing the road on purpose
			for r: Node in roads:
				# Fully on the road (body overlapping a zebra edge is fine).
				var t := r as RoadTile
				if p.y < 0.12 and t.is_blocked(p) and t.is_blocked(p + Vector3(0.4, 0, 0)) 						and t.is_blocked(p - Vector3(0.4, 0, 0)) and t.is_blocked(p + Vector3(0, 0, 0.4)) 						and t.is_blocked(p - Vector3(0, 0, 0.4)):
					on_road += 1
					if on_road <= 5:
						print("[SelfTest]   %s on the road at %s" % [n.name, p])
					break
	# A visit picks a public door anywhere on the (big) map, so in 90 s nobody may have finished one yet: wait up to
	# 90 game-seconds more for the first sit / visit (it is the behaviour that is checked, not the dice).
	for extra: int in 150:
		var done_any: int = 0
		for n: Node in npcs:
			if is_instance_valid(n):
				done_any += int(n.get("stats")["sit"]) + int(n.get("stats")["visit"])
		if done_any > 0:
			break
		await get_tree().create_timer(0.2).timeout
	Engine.time_scale = 1.0
	_report(on_road == 0, "pedestrians only walk on the road while crossing it (%d of %d samples on road)" % [on_road, samples])
	var totals: Dictionary = {"walk": 0, "idle": 0, "sit": 0, "visit": 0, "stuck": 0, "cross": 0}
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
	# Point 29: crossing the road anywhere (not at a zebra), straight over the asphalt.
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var kerb: Vector3 = Vector3.INF
	for r: Node in roads:
		var t := r as RoadTile
		if t.type != RoadTile.Type.STRAIGHT or t.crossing:
			continue
		for off: Vector3 in [Vector3(5.0, 0, 0), Vector3(-5.0, 0, 0), Vector3(0, 0, 5.0), Vector3(0, 0, -5.0)]:
			var p: Vector3 = t.to_global(off)
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP, p + Vector3.DOWN, 1))
			if not hit.is_empty() and hit["collider"] == t and (hit["position"] as Vector3).y > 0.1:
				kerb = hit["position"]
				break
		if kerb != Vector3.INF:
			break
	var walker := npcs[0] as Pedestrian
	walker.ambient = false
	walker._finish_move(false)
	walker.global_position = kerb + Vector3.UP * 0.05
	for i: int in 5:
		await get_tree().physics_frame
	var plan: Array = walker.plan_road_crossing()
	var crossed: bool = await walker.cross_road() if not plan.is_empty() else false
	var across: float = walker.global_position.distance_to(kerb)
	_report(kerb != Vector3.INF and crossed and across > 5.0,
			"a pedestrian crosses the road outside a zebra (from %s, %.1f m across)" % [kerb.snapped(Vector3.ONE * 0.1), across])


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
	# Point 32: it keeps running until it is far away and out of sight of the shot.
	var shot_at: Vector3 = b_start + Vector3(3, 0, 0)
	for i: int in 100:
		if not b.is_fleeing():
			break
		await get_tree().create_timer(0.5).timeout
	_report(not b.is_fleeing() and b.flee_safe(), "it runs until it is safe: %.0f m away, out of sight %s" % [
			b.global_position.distance_to(shot_at), b.global_position.distance_to(shot_at) >= Pedestrian.FLEE_SAFE_DISTANCE])
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


# --- Black Crows (point 11) --------------------------------------------------------------

func _check_rivals(world: Node3D) -> void:
	var house: Node3D = world.find_child("CrowsHouse", true, false) as Node3D
	_report(house != null and house.find_children("RivalSpawn*", "Marker3D", true, false).size() == 3,
			"the Black Crows' house with its door spots")
	if house == null:
		return
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	var hours0: float = dn.hours
	dn.set_hours(23.0)
	await get_tree().create_timer(0.3).timeout
	# A player on the pavement in front of the Starter Room, a Crow 12 m down the street.
	var sr: Property = world.find_child("StarterRoom", true, false).get_node("Property") as Property
	var b: Node3D = sr.building()
	var spot: Vector3 = b.to_global(Vector3(0.0, 0.2, 2.2))
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Target"
	p.auto_target = spot
	world.get_node("Players").add_child(p)
	p.global_position = spot
	await get_tree().physics_frame
	p.net_weapon = 0
	var r: Rival = world.add_rival(spot + b.global_basis.x * 12.0, 0)
	r.role = Rival.Role.STREET  # point 31: the night group in town
	var sharp: NpcCombatProfile = r.profile.duplicate()
	sharp.accuracy = 1.0
	sharp.reaction_time = 0.2
	sharp.spread_per_metre = 0.0
	sharp.moving_spread = 0.0
	sharp.damage = 15
	_report(r.is_in_group(&"rivals") and not r.is_in_group(&"police") and r.profile.damage <= 10,
			"a Crow: its own group, its own (weak) combat profile (%d damage)" % r.profile.damage)
	r.profile = sharp
	await get_tree().create_timer(2.5).timeout
	_report(r.target == p, "at night a Crow goes after a player it sees")
	for i: int in 20:
		if p.health < Player.MAX_HEALTH:
			break
		await get_tree().create_timer(0.5).timeout
	_report(p.health < Player.MAX_HEALTH, "it shoots, even with the weapon away - no arrests (health %d)" % p.health)
	# Safe inside your own property: it gives up and doesn't come in.
	var inside: Vector3 = world.get_marker("LockerSpot").global_position + b.global_basis.x * 1.5 + Vector3.UP * 0.1
	p.teleport(inside)
	p.auto_target = inside
	p.health = Player.MAX_HEALTH
	await get_tree().create_timer(1.0).timeout
	_report(sr.is_crew_owned() and r.target == null and r.spot_victim() == null,
			"a player inside their own property is safe: the Crow gives up")
	var h: int = p.health
	await get_tree().create_timer(3.0).timeout
	_report(p.health >= h and not sr.contains(r.global_position), "the Crow stays outside")
	# Killed: a loot bag.
	var bags0: int = world.get_node("LootBags").get_child_count() if world.has_node("LootBags") else -1
	var loot_root: Node = world.get("loot_root")
	bags0 = loot_root.get_child_count()
	r.host_damage(1000, p, p.global_position)
	await get_tree().create_timer(0.5).timeout
	var bag: LootBag = null
	for n: Node in loot_root.get_children():
		if n is LootBag and (n as LootBag).owner_name == "Black Crows":
			bag = n as LootBag
	_report(r.dead and bag != null and bag.cash > 0, "a dead Crow drops a loot bag (€%d, %s)" % [
			bag.cash if bag else 0, bag.items if bag else []])
	if bag:
		bag.queue_free()
	# Daybreak (point 31): the street group walks back to the yard and stays there.
	var r2: Rival = world.add_rival(Vector3.INF, 0)
	r2.role = Rival.Role.STREET
	r2.global_position = r2.home + house.global_basis.z * 5.0
	await get_tree().create_timer(1.0).timeout
	dn.set_hours(12.0)
	for i: int in 40:
		if r2.role == Rival.Role.YARD:
			break
		await get_tree().create_timer(0.5).timeout
	_report(is_instance_valid(r2) and r2.role == Rival.Role.YARD and Rival.on_turf(get_tree(), r2.global_position),
			"at daybreak a street Crow walks back into the yard and stays there")
	# Point 31: the yard. By day, a player outside the fence is left alone by a new Crow.
	p.health = 1000
	var gate_out := Vector3(49.0, 0.2, 4.4)
	var gate_in := Vector3(49.0, 0.2, 10.5)
	p.teleport(gate_out)
	p.auto_target = gate_out
	var y1: Rival = world.add_rival(Vector3(49.0, 0.1, 13.5), 0)
	var y2: Rival = world.add_rival(Vector3(52.0, 0.1, 20.0), 0)
	for c: Rival in [y1, y2]:
		c.profile = sharp
	await get_tree().create_timer(1.5).timeout
	_report(Rival.turf(get_tree()).size.x > 10.0 and Rival.yard_point(y1) != Vector3.INF
			and Rival.on_turf(get_tree(), Rival.yard_point(y1)), "the turf rect + a walkable yard spot (%s)" % Rival.turf(get_tree()))
	_report(y1.can_see(p) and y1.spot_victim() == null and y1.target == null,
			"a yard Crow leaves a player outside the yard alone (sees them: %s)" % y1.can_see(p))
	# On the turf: attacked, remembered, and the Crows close by hear about it.
	p.teleport(gate_in)
	p.auto_target = gate_in
	for i: int in 10:
		if y1.target == p:
			break
		await get_tree().create_timer(0.3).timeout
	_report(y1.target == p and y1.memory.has(p), "a player on the turf is attacked and remembered")
	_report(y2.memory.has(p), "the Crow next to it remembers the player too (shared)")
	# Back outside: the ones that saw you still come for you, a new Crow doesn't.
	p.teleport(gate_out)
	p.auto_target = gate_out
	var y3: Rival = world.add_rival(Vector3(50.5, 0.1, 13.5), 0)
	await get_tree().create_timer(1.0).timeout
	_report(y1.memory.has(p) and (y1.target == p or y1.spot_victim() == p), "outside again: a Crow that saw you keeps coming")
	_report(y3.can_see(p) and y3.spot_victim() == null and not y3.memory.has(p),
			"a new Crow that never saw you leaves you alone outside")
	var ak: Rival = world.add_rival(Vector3(56.0, 0.1, 24.0), 1)
	await get_tree().physics_frame
	_report(ak.gun == &"ak47" and ak._pistol != null and ak._pistol.id == &"ak47" and ak.profile.damage > 10,
			"some Crows carry an AK-47 (%d damage)" % ak.profile.damage)
	for c: Rival in [r2, y1, y2, y3, ak]:
		if is_instance_valid(c):
			c.queue_free()
	dn.set_hours(hours0)
	p.queue_free()
	GameState.player_data.erase("Target")
	await get_tree().physics_frame


# --- Police vs Crows + the Crows' night pool (point 31a/b) --------------------------------

func _check_police_vs_crows(world: Node3D) -> void:
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	var hours0: float = dn.hours
	dn.set_hours(23.0)
	var station: Node3D = world.find_child("PoliceStation", true, false) as Node3D
	var spot: Vector3 = station.global_position + station.global_basis.z * 4.5 + station.global_basis.x * 6.0
	var cop: PoliceOfficer = world.add_officer(spot, spot)
	var crow: Rival = world.add_rival(spot + station.global_basis.x * 12.0, 0)
	crow.role = Rival.Role.STREET
	var sharp: NpcCombatProfile = crow.profile.duplicate()
	sharp.accuracy = 1.0
	sharp.reaction_time = 0.3
	sharp.spread_per_metre = 0.0
	sharp.moving_spread = 0.0
	sharp.damage = 25
	crow.profile = sharp
	cop.profile = sharp
	var both: bool = false
	for i: int in 30:
		await get_tree().create_timer(0.3).timeout
		if crow.foe == cop and cop.foe == crow:
			both = true
			break
	_report(both, "at night a street Crow opens fire on an officer it sees, the officer fights back (crow foe %s, cop foe %s)" % [
			crow.foe.name if crow.foe else "-", cop.foe.name if cop.foe else "-"])
	for i: int in 60:
		if cop.dead or crow.dead:
			break
		await get_tree().create_timer(0.3).timeout
	_report(cop.dead or crow.dead, "police vs Crows: the gunfight ends with one down (cop %d hp, crow %d hp)" % [cop.health, crow.health])
	# Point 59: a clash never lasts longer than clash_max; then a truce (no new fights, no car response).
	PoliceOfficer.truce_until = 0.0
	PoliceOfficer.clash_start = -1.0
	var max0: float = PoliceOfficer.clash_max
	PoliceOfficer.clash_max = 2.0
	var cop2: PoliceOfficer = world.add_officer(spot, spot)
	var crow3: Rival = world.add_rival(spot + station.global_basis.x * 12.0, 0)
	crow3.role = Rival.Role.STREET
	var tough: NpcCombatProfile = crow3.profile.duplicate()
	tough.accuracy = 0.0
	tough.damage = 0
	crow3.profile = tough
	cop2.profile = tough
	var fought: bool = false
	for i: int in 30:
		await get_tree().create_timer(0.3).timeout
		if crow3.foe == cop2 or cop2.foe == crow3:
			fought = true
			break
	var ended: bool = false
	for i: int in 30:
		await get_tree().create_timer(0.3).timeout
		if crow3.foe == null and cop2.foe == null and PoliceOfficer.in_truce():
			ended = true
			break
	await get_tree().create_timer(1.0).timeout
	_report(fought and ended and crow3.foe == null and cop2.foe == null and not cop2.dead and not crow3.dead,
			"police vs Crows: a clash ends by itself after clash_max, both break off (fought %s, truce %s)" % [fought, PoliceOfficer.in_truce()])
	crow3.set_foe(cop2, cop2.global_position)
	_report(crow3.foe == null and crow3.spot_cop() == null, "during the truce nobody starts a new fight")
	PoliceOfficer.clash_max = max0
	PoliceOfficer.truce_until = 0.0
	cop2.queue_free()
	crow3.queue_free()
	# A Crow firing near a patrol car: its crew gets out and takes it on.
	var traffic: Traffic = world.get_node("Traffic") as Traffic
	var car: Car = traffic.spawn_police_car(3, traffic.routes[3].length * 0.3, 2)
	await get_tree().create_timer(0.5).timeout
	var crow2: Rival = world.add_rival(car.global_position + car.global_basis.x * 6.0, 0)
	await get_tree().physics_frame
	crow2._shoot_at(car)  # (a shot: reported to the police)
	await get_tree().create_timer(0.5).timeout
	var out_ok: bool = car.abandoned and not car.crew_out.is_empty() and is_instance_valid(car.crew_out[0]) \
			and (car.crew_out[0] as PoliceOfficer).foe == crow2
	_report(out_ok and car.chase == null, "a Crow shooting near a patrol car: the crew gets out after it (no player chased)")
	# No stars from NPC fights.
	var stars: int = 0
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		stars += (n as Player).wanted_stars
	_report(stars == 0, "NPC gunfights give no player stars")
	for o: PoliceOfficer in car.crew_out:
		if is_instance_valid(o):
			o.queue_free()
	car.queue_free()
	for c: Node in [cop, crow, crow2]:
		if is_instance_valid(c):
			c.queue_free()
	await get_tree().create_timer(0.3).timeout
	# Point 31b: the night pool.
	for n: Node in get_tree().get_nodes_in_group(&"rivals"):
		n.queue_free()
	await get_tree().physics_frame
	var count0: int = world.rival_count
	var pool0: int = world.rival_night_pool
	var resp0: Vector2 = world.rival_respawn
	world.rival_count = 2
	world.rival_night_pool = 3
	world.rival_respawn = Vector2(0.1, 0.2)
	world.refill_rival_pool()
	await get_tree().physics_frame
	var alive: Array = world._alive_rivals()
	var first_ok: bool = alive.size() == 2 and world.rival_pool_left == 1
	(alive[0] as Rival).host_damage(1000, null)
	await get_tree().create_timer(0.6).timeout
	var after1: int = world._alive_rivals().size()
	var pool1: int = world.rival_pool_left
	(world._alive_rivals()[0] as Rival).host_damage(1000, null)
	await get_tree().create_timer(0.6).timeout
	var after2: int = world._alive_rivals().size()
	_report(first_ok and after1 == 2 and pool1 == 0 and after2 == 1,
			"night pool 3: 2 in the yard, 1 replacement, then nobody (alive %d -> %d, pool %d)" % [after1, after2, pool1])
	world.refill_rival_pool()
	await get_tree().physics_frame
	_report(world._alive_rivals().size() == 2 and world.rival_pool_left == 1, "next dusk: the yard is manned again, the pool is full")
	world.rival_count = count0
	world.rival_night_pool = pool0
	world.rival_respawn = resp0
	for n: Node in get_tree().get_nodes_in_group(&"rivals"):
		n.queue_free()
	var loot_root: Node = world.get("loot_root")
	for n: Node in loot_root.get_children():
		if n is LootBag and (n as LootBag).owner_name == "Black Crows":
			n.queue_free()
	dn.set_hours(hours0)
	await get_tree().physics_frame


# --- Park + agora (point 46) -------------------------------------------------------------

func _check_park(world: Node3D) -> void:
	var ag: Agora = world.find_child("Agora", true, false) as Agora
	var path: Array[Vector3] = world.park_path()
	var smoke: Node3D = world.find_child("ParkSmokeSpot", true, false) as Node3D
	_report(ag != null and path.size() == 4 and smoke != null, "park: the agora, the dog walkers' loop (4) and the smoke spot")
	if ag == null or path.size() < 4 or smoke == null:
		return
	var map: RID = (world.get_node("NavRegion") as NavigationRegion3D).get_navigation_map()
	var mid: Vector3 = Vector3.ZERO
	for i: int in 40:  # (right after the bake the map can still answer zero)
		mid = NavigationServer3D.map_get_closest_point(map, ag.global_position + Vector3.UP * 0.1)
		if mid != Vector3.ZERO:
			break
		await get_tree().create_timer(0.25).timeout
	var through: PackedVector3Array = NavigationServer3D.map_get_path(map, ag.gate(true) + Vector3(0, 0, 3), mid, true)
	_report(Vector2(mid.x - ag.global_position.x, mid.z - ag.global_position.z).length() < 0.3 and through.size() > 1
			and through[through.size() - 1].distance_to(mid) < 0.5, "navmesh on the pitch, reachable through the gate (mid %s, path %d pts, end %s)" % [
			mid.snapped(Vector3.ONE * 0.1), through.size(), through[through.size() - 1].snapped(Vector3.ONE * 0.1) if through.size() > 0 else Vector3.INF])
	# The ball: a goal, a bounce, a player walking into it kicks it.
	ag.ball_pos = Vector3(Agora.LENGTH / 2.0 - 1.0, Agora.TURF_TOP + Agora.BALL_R, 0.2)
	ag.ball_vel = Vector3(6, 0, 0)
	var g0: int = ag.goals
	await get_tree().create_timer(0.6).timeout
	_report(ag.goals == g0 + 1 and ag.score[0] >= 1, "the ball rolling into the +X goal: a goal for red (%s)" % ag._score_text())
	await get_tree().create_timer(2.2).timeout
	_report(ag.ball_pos.distance_to(Vector3(0, Agora.TURF_TOP + Agora.BALL_R, 0)) < 0.05, "after a goal the ball is back on the centre spot")
	ag.ball_pos = Vector3(0, Agora.TURF_TOP + Agora.BALL_R, Agora.WIDTH / 2.0 - 1.0)
	ag.ball_vel = Vector3(0, 0, 5)
	await get_tree().create_timer(0.5).timeout
	_report(ag.ball_vel.z < 0.0 and ag.ball_pos.z < Agora.WIDTH / 2.0, "the ball bounces off the boards (vel z %.1f)" % ag.ball_vel.z)
	ag.ball_vel = Vector3.ZERO
	ag.ball_pos = Vector3(0, Agora.TURF_TOP + Agora.BALL_R, 0)
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Kicker"
	var start: Vector3 = ag.to_global(Vector3(-0.45, 0.3, 0))
	p.auto_target = start
	world.get_node("Players").add_child(p)
	p.global_position = start
	var k0: int = ag.kicks
	for i: int in 20:
		await get_tree().physics_frame
	_report(ag.kicks > k0 and ag.ball_vel.length() > 1.0, "a player next to the ball kicks it (%d kick(s), %.1f m/s)" % [ag.kicks - k0, ag.ball_vel.length()])
	p.queue_free()
	GameState.player_data.erase("Kicker")
	# A match: four NPCs in two teams play (kicks), then walk off.
	ag.ball_vel = Vector3.ZERO
	ag.ball_pos = Vector3(0, Agora.TURF_TOP + Agora.BALL_R, 0)
	ag.start_match(4, 1.0)
	var team_ok: bool = ag.players.size() == 4 and ag.players[0].team != ag.players[1].team
	k0 = ag.kicks
	var on: int = 0
	for i: int in 60:
		await get_tree().create_timer(0.5).timeout
		on = 0
		for q: ParkGoer in ag._alive():
			if ag.on_pitch(q.global_position):
				on += 1
		if on == 4 and ag.kicks >= k0 + 3:
			break
	_report(team_ok and on == 4 and ag.kicks >= k0 + 3, "a 2-against-2 match: all on the pitch, %d kicks" % (ag.kicks - k0))
	var mates: Array[ParkGoer] = ag._alive()
	ag.end_match()
	await get_tree().create_timer(0.5).timeout
	var leaving: bool = mates.all(func(q: ParkGoer) -> bool: return not is_instance_valid(q) or q.leaving)
	_report(leaving and ag.players.is_empty(), "match over: the players walk off")
	for q: ParkGoer in mates:
		if is_instance_valid(q):
			q.queue_free()
	# A dog walker with its dog walks the loop; the smokers gather at their spot.
	# (From the last loop point: the first leg is 14 m, no random pause at the start.)
	var walker: ParkGoer = world.add_park_goer(path[path.size() - 1], ParkGoer.Role.DOG)
	var smokers: Array[ParkGoer] = []
	for i: int in 3:
		var y: ParkGoer = world.add_park_goer(smoke.global_position + Vector3(2.0 + i, 0.1, 0.5), ParkGoer.Role.SMOKER)
		y.slot = TAU * i / 3.0
		smokers.append(y)
	var from: Vector3 = walker.global_position
	await get_tree().create_timer(9.0).timeout
	var dog: Dog = Dog.of(walker)  # (Roadmap 67, session B: the dog is a real NPC in World/Dogs now)
	_report(dog != null and dog.global_position.distance_to(walker.global_position) < 2.0
			and walker.global_position.distance_to(from) > 3.0, "a dog walker walks the park loop with its dog next to it (%.1f m)" % walker.global_position.distance_to(from))
	var gathered: int = 0
	for y: ParkGoer in smokers:
		if Vector2(y.global_position.x - smoke.global_position.x, y.global_position.z - smoke.global_position.z).length() < 1.5:
			gathered += 1
	_report(gathered == 3 and smokers[0].get_node_or_null("Smoke") != null, "three youths stand smoking at their spot (%d/3)" % gathered)
	_report(not walker.can_be_customer() and smokers[0].can_be_customer(), "only the smokers can become customers (they stay put)")
	walker.queue_free()
	for y: ParkGoer in smokers:
		y.queue_free()
	await get_tree().physics_frame


# --- Admin mode (host debug keys F10-F12) ----------------------------------------------

func _check_admin(world: Node3D) -> void:
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Admin"
	var start: Vector3 = (world.get_node("Markers/SpawnPoints").get_child(0) as Node3D).global_position
	p.auto_target = start
	world.get_node("Players").add_child(p)
	p.global_position = start + Vector3.UP * 0.1
	for i: int in 10:
		await get_tree().physics_frame
	_report(Player.admin_allowed(p), "admin keys work for the host in a debug build")
	p._admin_key(KEY_F11)
	var killed: bool = p.host_damage(500, null)
	_report(p.admin_god and not killed and p.health == Player.MAX_HEALTH, "F11 god mode: no damage (health %d)" % p.health)
	p._admin_key(KEY_F11)
	p._admin_key(KEY_F10)
	_report(p.admin_noclip and p.collision.disabled, "F10 noclip: no collision")
	var y0: float = p.global_position.y
	for i: int in 30:
		await get_tree().physics_frame
	_report(absf(p.global_position.y - y0) < 0.05, "noclip: no gravity (moved %.2f m down)" % (y0 - p.global_position.y))
	p._admin_key(KEY_F10)
	_report(not p.admin_noclip and not p.collision.disabled, "F10 again: walking + collision back")
	var was: bool = Wanted.enabled
	Wanted.enabled = true
	Wanted.current.debug_set(p, 3)
	p._admin_key(KEY_F12)
	_report(p.wanted_stars == 0, "F12 clears the wanted stars")
	Wanted.enabled = was
	p.queue_free()
	GameState.player_data.erase("Admin")
	await get_tree().physics_frame


# --- Build mode (point 36) ------------------------------------------------------------

func _check_build_mode(world: Node3D) -> void:
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Builder"
	var inside: Vector3 = world.get_marker("LockerSpot").global_position
	var sr: Property = world.find_child("StarterRoom", true, false).get_node("Property") as Property
	var spot: Vector3 = inside + sr.building().global_basis.x * 1.5 + Vector3.UP * 0.1
	p.auto_target = spot
	world.get_node("Players").add_child(p)
	p.global_position = spot
	for i: int in 10:
		await get_tree().physics_frame
	p._set_wallet(100, [{"id": "grow_pot", "count": 1}])
	p.combat.select_slot(0)
	await get_tree().create_timer(0.2).timeout
	var pl: PlayerPlacement = p.placement
	_report(pl != null and not pl.build_mode and not pl.is_active() and pl.hint_text().contains("[B]"),
			"outside build mode: no ghost, a hint to press B ('%s')" % (pl.hint_text() if pl else ""))
	var locker: Node = null
	for n: Node in get_tree().get_nodes_in_group(&"interactable"):
		if PlayerPlacement.placed_uid_of(n) != "" and (n as Node3D).global_position.distance_to(spot) < 30.0:
			locker = n
			break
	_report(locker == null or not pl.begin_interact(locker), "outside build mode E only uses a placed thing (no pick-up)")
	pl.set_build_mode(true)
	await get_tree().create_timer(0.2).timeout
	_report(pl.build_mode and pl.is_active(), "B: build mode on, the ghost shows")
	_report(locker == null or pl.begin_interact(locker), "in build mode hold E can pick up a placed thing")
	pl._hold_node = null
	pl.set_build_mode(false)
	await get_tree().create_timer(0.2).timeout
	_report(not pl.is_active(), "B again: build mode off, ghost gone")
	p.queue_free()
	GameState.player_data.erase("Builder")
	await get_tree().physics_frame


# --- Sleep (point 37) -----------------------------------------------------------------

func _check_sleep(world: Node3D) -> void:
	var bed: PlacedFurniture = null
	for n: Node in get_tree().get_nodes_in_group(&"placed"):
		if n is PlacedFurniture and (n as PlacedFurniture).item_id == "bed":
			bed = n as PlacedFurniture
	_report(bed != null, "an own bed to sleep in (the Starter Room's, adopted)")
	if bed == null:
		return
	var sleep: Sleep = Sleep.current(get_tree())
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	var hours0: float = dn.hours
	var ps: Array[Player] = []
	for i: int in 2:
		var p: Player = WALKER.instantiate()
		p.auto_walk = true
		p.name = str(i + 1)
		p.player_name = "Sleeper%d" % i
		var at: Vector3 = bed.global_position + Vector3(0.6 * i - 0.3, 0.1, 0.0)
		p.auto_target = at
		world.get_node("Players").add_child(p)
		p.global_position = at
		ps.append(p)
	for i: int in 5:
		await get_tree().physics_frame
	dn.set_hours(12.0)
	ps[0]._host_request_sleep(true)
	_report(not sleep.sleepers.has(ps[0]) and ps[0].last_message.contains("not tired"),
			"no sleeping at noon ('%s')" % ps[0].last_message)
	dn.set_hours(23.0)
	# A pot that grows overnight.
	var pot: GrowPot = (await _weed_corner(world))["Pot1"] as GrowPot
	if pot:
		pot.state.merge({"stage": GrowPot.Stage.GROWING, "growth": 0.1, "water": 1.0, "seed": 5}, true)
	var growth0: float = float(pot.state["growth"]) if pot else 0.0
	ps[0].health = 50
	ps[0]._host_request_sleep(true)
	_report(sleep.sleepers.has(ps[0]) and ps[0].sleeping and absf(dn.hours - 23.0) < 0.1,
			"one player in bed: asleep, waiting for the other (it's still %s)" % dn.clock_text())
	ps[1]._host_request_sleep(true)
	await get_tree().physics_frame
	_report(absf(dn.hours - Sleep.WAKE_HOUR) < 0.1 and not ps[0].sleeping and not ps[1].sleeping and sleep.sleepers.is_empty()
			and ps[0].health == Player.MAX_HEALTH, "both in bed: it's %s, everyone awake and rested" % dn.clock_text())
	if pot:
		_report(float(pot.state["growth"]) > growth0, "the plant grew during the night (%.2f -> %.2f)" % [growth0, float(pot.state["growth"])])
	# Getting up again.
	dn.set_hours(22.0)
	ps[0]._host_request_sleep(true)
	ps[0]._host_request_sleep(false)
	_report(not sleep.sleepers.has(ps[0]) and not ps[0].sleeping, "getting out of bed works")
	dn.set_hours(hours0)
	for p: Player in ps:
		GameState.player_data.erase(p.player_name)
		p.queue_free()
	await get_tree().physics_frame


# --- Kerb (point 33) ------------------------------------------------------------------

## The player walks from the road up onto the pavement: straight, at an angle and very
## flat, also over a tile seam; every try must end on the pavement.
func _check_kerb(world: Node3D) -> void:
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Kerb"
	world.get_node("Players").add_child(p)
	var fails: PackedStringArray = []
	var tries: int = 0
	var paths: Array = []
	for x0: float in [-58.0, -53.0, -41.0, 38.0]:  # straight tiles, over the seams, no lamp poles in the way
		for side: float in [-1.0, 1.0]:
			for slope: float in [0.0, 1.0, 2.5]:  # metres along the road per metre towards the kerb
				paths.append([Vector3(x0, 0.1, side * 1.5), Vector3(x0 + slope * 3.5, 0.2, side * 5.2)])
	# The rounded kerb corners at the junctions (x -6 T, x 30 cross).
	for g: Vector3 in [Vector3(-11.0, 0.2, -5.5), Vector3(-1.0, 0.2, -5.5), Vector3(-10.0, 0.2, 5.2), Vector3(-2.0, 0.2, 5.2)]:
		paths.append([Vector3(-6.0, 0.1, -0.5), g])
	for g: Vector3 in [Vector3(24.5, 0.2, -5.5), Vector3(35.5, 0.2, -5.5), Vector3(24.5, 0.2, 5.5), Vector3(35.5, 0.2, 5.5)]:
		paths.append([Vector3(30.0, 0.1, 0.0), g])
	for path: Array in paths:
		for mode: int in 3:  # walk, sprint, crouch
			var sprint: bool = mode == 1
			tries += 1
			var start: Vector3 = path[0]
			var goal: Vector3 = path[1]
			p.teleport(start)
			p.velocity = Vector3.ZERO
			p.auto_target = start
			for i: int in 6:
				await get_tree().physics_frame
			if sprint:
				Input.action_press("sprint")
			if mode == 2:
				Input.action_press("crouch")
			p.auto_target = goal
			var t: int = 0
			while t < 480 and Vector2(p.global_position.x - goal.x, p.global_position.z - goal.z).length() > 0.4:
				await get_tree().physics_frame
				t += 1
			Input.action_release("sprint")
			Input.action_release("crouch")
			if p.global_position.y < 0.12:
				fails.append("%s -> %s%s stuck at %s" % [start, goal, ["", " sprint", " crouch"][mode],
						p.global_position.snapped(Vector3.ONE * 0.01)])
	_report(fails.is_empty(), "kerb: the player steps up onto the pavement from the road (%d/%d)%s" % [
			tries - fails.size(), tries, (": " + "; ".join(fails.slice(0, 6))) if not fails.is_empty() else ""])
	p.queue_free()
	GameState.player_data.erase("Kerb")
	await get_tree().physics_frame


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
	Wanted.clear(q, "test")
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


# --- wanted level (point 28) -------------------------------------------------------------

func _check_wanted(world: Node3D) -> void:
	var wanted: Wanted = Wanted.current
	_report(wanted != null and wanted.config != null and wanted.config.heat_for_star.size() == 5,
			"wanted system with its config (data/police/wanted.tres)")
	if wanted == null:
		return
	Wanted.enabled = true
	var cfg: WantedConfig = wanted.config
	var station: Node3D = world.find_child("PoliceStation", true, false) as Node3D
	var spot: Vector3 = station.global_position + station.global_basis.z * 4.5 + station.global_basis.x * 6.0
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Wanted1"
	p.auto_target = spot
	world.get_node("Players").add_child(p)
	p.global_position = spot
	for i: int in 10:
		await get_tree().physics_frame
	# 0 stars: innocent = left alone; a drawn weapon in sight of an officer = 1 star at once.
	p.combat.set_equipped(false)  # (the starter pistol comes drawn)
	p.net_weapon = 0
	var cop: PoliceOfficer = world.add_officer(spot - station.global_basis.x * 12.0, spot)
	await get_tree().create_timer(1.0).timeout
	_report(p.wanted_stars == 0 and cop.target == null, "no stars for an innocent player next to an officer")
	p.net_weapon = 1
	await get_tree().create_timer(0.6).timeout
	_report(p.wanted_stars == 0 and cop.target == null, "point 28a: only holding a weapon in sight of an officer gives no stars")
	cop.report_crime(p, p.global_position, false)  # (as if it heard a shot)
	await get_tree().physics_frame
	_report(p.wanted_stars == 1 and cop.target == p, "a shot the officer hears: 1 star, it comes")
	p.net_weapon = 0
	if p.is_local():
		_report(p.ui._wanted_row.visible and p.ui._wanted_stars[0].color == PlayerHUD.ACCENT
				and p.ui._wanted_stars[1].color != PlayerHUD.ACCENT, "HUD shows 1 star")
	_report(not cop._should_shoot(p), "1 star, weapon away: the officer arrests, doesn't shoot")
	p.host_arrest(cop)
	_report(p.wanted_stars == 0 and cop.target == null, "an arrest clears the stars")
	cop.queue_free()
	p.teleport(spot)
	p.auto_target = spot
	await get_tree().physics_frame
	# Heat: kills add up to stars; an officer kill is 2 stars at once.
	var got: Array = []
	for n: int in [1, 5, 6]:
		for i: int in n:
			Wanted.report(p, &"kill", spot)
		got.append(p.wanted_stars)
	_report(got == [1, 2, 3], "kills add stars: 1 kill / 6 / 12 = %s stars" % [got])
	Wanted.clear(p, "test")
	Wanted.report(p, &"kill_officer", spot)
	_report(p.wanted_stars == cfg.officer_kill_stars, "killing an officer: %d stars at once" % p.wanted_stars)
	# How the police treat you, by stars.
	var far: Vector3 = spot + Vector3(0, 0, -60)
	var judge: PoliceOfficer = world.add_officer(far, far)
	await get_tree().physics_frame
	var unarmed2: bool = judge._should_shoot(p)
	p.net_weapon = 1
	var armed2: bool = judge._should_shoot(p)
	p.net_weapon = 0
	wanted.debug_set(p, 3)
	var unarmed3: bool = judge._should_shoot(p)
	_report(not unarmed2 and armed2 and unarmed3, "2 stars: shot only when armed; 3 stars: shot on sight")
	judge.queue_free()
	# Point 28b: out of sight ONE search timer runs (stars x 1 s here); then all stars go at
	# once. Inside your own place it runs faster.
	_report(cfg.search_time.size() == 6 and is_equal_approx(cfg.search_time[3], 30.0),
			"search time per star in the resource (3 stars = %.0f s)" % cfg.search_time[3])
	var fast: WantedConfig = cfg.duplicate()
	fast.search_time = PackedFloat32Array([0.0, 1.0, 2.0, 3.0, 4.0, 5.0])
	wanted.config = fast
	var fam: Property = world.find_child("FamilyHouse", true, false).get_node("Property") as Property
	var hide_out: Vector3 = fam.building().to_global(Vector3(0.0, 0.2, -2.0))
	p.teleport(hide_out)
	p.auto_target = hide_out
	await get_tree().physics_frame
	wanted.debug_set(p, 3)
	await get_tree().create_timer(1.1).timeout
	var outside: int = p.wanted_stars
	var seen_out: bool = p.wanted_seen
	await get_tree().create_timer(1.4).timeout
	var outside2: int = p.wanted_stars
	var left: float = wanted.search_left(p)
	await get_tree().create_timer(1.0).timeout
	var outside3: int = p.wanted_stars
	var sr: Property = world.find_child("StarterRoom", true, false).get_node("Property") as Property
	var at_home: Vector3 = sr.building().to_global(Vector3(0.0, 0.2, -3.0))
	p.teleport(at_home)
	p.auto_target = at_home
	await get_tree().physics_frame
	wanted.debug_set(p, 3)
	await get_tree().create_timer(1.3).timeout
	var home: int = p.wanted_stars
	_report(not fam.is_crew_owned() and not seen_out and outside == 3 and outside2 == 3 and left < 1.0 and outside3 == 0,
			"search phase: 3 stars stay for 3 s out of sight, then all go at once (3 -> %d -> %d -> %d, %.2f s left at 2.5 s)" % [outside, outside2, outside3, left])
	_report(sr.is_crew_owned() and home == 0, "inside your own place the search runs 3x faster (3 -> %d in 1.3 s)" % home)
	await get_tree().create_timer(3.0).timeout
	_report(p.wanted_stars == 0, "every star gone after a while out of sight (%d)" % p.wanted_stars)
	wanted.config = cfg
	# Response: cars sent along the road, heavy teams and a road block at 4 stars.
	p.teleport(spot)
	p.auto_target = spot
	await get_tree().physics_frame
	wanted.dispatch = true
	wanted.debug_set(p, 4)
	var sent: Array = []
	var block: Car = null
	for i: int in 20:
		await get_tree().create_timer(0.25).timeout
		sent.clear()
		for c: Node in get_tree().get_nodes_in_group(&"police"):
			if c is Car and (c as Car).chase == p:
				if (c as Car).roadblock:
					block = c
				else:
					sent.append(c)
		if not sent.is_empty() and block != null and block.crew_out.size() > 0:
			break
	var first: Car = sent[0] if not sent.is_empty() else null
	_report(first != null and first.siren and first.heavy and first.crew_size == cfg.crew_per_star[4],
			"4 stars: a police car is sent with its siren on (heavy crew of %d)" % (first.crew_size if first else 0))
	var heavy_ok: bool = block != null and block.crew_out.size() == cfg.crew_per_star[4]
	if block:
		for o: PoliceOfficer in block.crew_out:
			heavy_ok = heavy_ok and o.heavy and o._pistol.id == &"smg" and o.health == PoliceOfficer.HEAVY_HEALTH
	_report(block != null and block.abandoned and block.siren and heavy_ok,
			"4 stars: a road block across the road %s m away, heavy team with SMGs" % (
			str(roundi(block.global_position.distance_to(p.global_position))) if block else "-"))
	if block:
		var along: float = absf(block.global_basis.z.dot(fast_route_dir(world, block)))
		_report(along < 0.3, "the road block car stands across the road (|dot| %.2f)" % along)
	Wanted.clear(p, "test")
	await get_tree().create_timer(0.6).timeout
	_report(block == null or not is_instance_valid(block) or block.is_queued_for_deletion(), "no stars: the road block is lifted")
	_report(first == null or not is_instance_valid(first) or (first.chase == null or first.abandoned),
			"no stars: the sent car stops chasing")
	# Death clears the stars too.
	wanted.debug_set(p, 2)
	p.host_damage(1000, null)
	await get_tree().physics_frame
	_report(p.wanted_stars == 0, "dying clears the stars")
	# Clean up: sent cars and their crews.
	wanted.dispatch = false
	Wanted.enabled = false
	for c: Node in get_tree().get_nodes_in_group(&"police"):
		if c is Car and ((c as Car).dispatched or (c as Car).chase != null or (c as Car).roadblock):
			for o: PoliceOfficer in (c as Car).crew_out:
				if is_instance_valid(o):
					o.queue_free()
			(c as Car).queue_free()
	p.queue_free()
	GameState.player_data.erase("Wanted1")
	await get_tree().create_timer(0.5).timeout


# --- police life (point 30) -------------------------------------------------------------

func _check_police_life(world: Node3D) -> void:
	PoliceOfficer.talk_time = Vector2(1.5, 2.0)
	var station: Node3D = world.find_child("PoliceStation", true, false) as Node3D
	var spot: Vector3 = station.global_position + station.global_basis.z * 4.5 + station.global_basis.x * 6.0
	var ped: Pedestrian = world.call("_add_pedestrian", spot, 0)
	var cop: PoliceOfficer = world.add_officer(spot + station.global_basis.x * 8.0, spot)
	await get_tree().create_timer(1.8).timeout
	print("[SelfTest] police_life before question: cop target %s, busy %s, ped free %s, fleeing %s, %.1f m" % [
			cop.target, cop.is_busy(), ped.free_for_talk(), ped.is_fleeing(), cop.global_position.distance_to(ped.global_position)])
	cop.question(ped)
	var talked: bool = false
	var gap: float = INF
	for i: int in 80:
		await get_tree().create_timer(0.2).timeout
		if cop.anim_state == Pedestrian.Anim.TALK or ped.anim_state == Pedestrian.Anim.TALK:
			talked = true
			gap = cop.global_position.distance_to(ped.global_position)
			break
	_report(talked and gap < 2.5 and ped.is_talking(), "a foot officer walks up to a passer-by and they talk (%.1f m apart)" % gap)
	for i: int in 40:
		if not cop._chatting:
			break
		await get_tree().create_timer(0.25).timeout
	_report(not cop._chatting and not ped.is_talking() and cop.chats == 1, "after the chat both carry on")
	cop.queue_free()
	# A patrol car stops by someone on the pavement ahead, one officer has a word, back in, on.
	var traffic: Traffic = world.get_node("Traffic")
	var car: Car = traffic.spawn_police_car(3, 30.0)
	await get_tree().create_timer(0.3).timeout
	car.speed = 0.0
	ped._finish_move(false)
	ped.global_position = car.global_position - car.global_basis.z * 12.0 + car.global_basis.x * 3.2 + Vector3.UP * 0.2
	await get_tree().physics_frame
	car.question_in = 0.01
	var stopped: bool = false
	for i: int in 20:
		await get_tree().create_timer(0.2).timeout
		if car.abandoned:
			stopped = true
			break
	_report(stopped and car.siren and car.crew_out.size() == 1,
			"a patrol car stops (light bar on), one officer gets out to question a passer-by (%d out)" % car.crew_out.size())
	var back: bool = false
	var questioned: bool = false
	for i: int in 160:
		await get_tree().create_timer(0.25).timeout
		for c: PoliceOfficer in car.crew_out:
			if is_instance_valid(c) and c.chats > 0:
				questioned = true
		if not car.abandoned:
			back = true
			break
	_report(questioned and back and not car.siren and car.crew_size == 2,
			"the officer talked, got back in and the car drives on (crew %d)" % car.crew_size)
	car.queue_free()
	ped.queue_free()
	PoliceOfficer.talk_time = Vector2(6.0, 10.0)
	await get_tree().physics_frame


## The driving direction of the route under a road block car.
func fast_route_dir(world: Node3D, car: Car) -> Vector3:
	var route: TrafficRoute = (world.get_node("Traffic") as Traffic).routes[car.route_id]
	var a: Vector3 = route.sample(car.progress - 1.0)[0]
	var b: Vector3 = route.sample(car.progress + 1.0)[0]
	return (b - a).normalized()


# --- traffic ---------------------------------------------------------------------------

## Point 63: traffic lights (never both axes green, a car stops at red and goes at green) + overtaking a car
## that stands still.
func _check_lights(world: Node3D) -> void:
	var traffic: Traffic = world.get_node("Traffic")
	for c: Node in get_tree().get_nodes_in_group(&"cars"):
		c.queue_free()
	await get_tree().physics_frame
	var both: int = 0
	var seen: Dictionary = {}
	var t: float = 0.0
	while t < Traffic.CYCLE:
		traffic.light_clock = t
		var x: StringName = traffic.light_state(1, &"x")
		var z: StringName = traffic.light_state(1, &"z")
		seen[String(x) + "x"] = true
		seen[String(z) + "z"] = true
		if x != &"red" and z != &"red":
			both += 1
		t += 0.25
	_report(both == 0 and seen.size() == 6, "traffic lights: x and z never both go, every colour shows (%d clashes, %s)" % [both, seen.keys()])
	var village_poles: int = world.find_children("Light*", "TrafficLight", true, false).filter(
			func(t: Node) -> bool: return Traffic.VILLAGE_LIGHTS.has((t as TrafficLight).junction)).size()
	_report(village_poles == 10, "10 traffic light poles at the village's 3 junctions (%d; the city has its own)" % village_poles)
	traffic.spawn_cars(5)
	await get_tree().physics_frame
	var car: Car = null
	var other: Array[Car] = []
	for c: Node in get_tree().get_nodes_in_group(&"cars"):
		if (c as Car).route_id == 3 and car == null:
			car = c
		else:
			other.append(c as Car)
	var route: TrafficRoute = traffic.routes[3]
	var at_x := func(x: float) -> float:
		var d: float = 0.0
		while d < route.length and not ((route.sample(d)[0] as Vector3).x >= x and absf((route.sample(d)[0] as Vector3).z - 1.75) < 0.3):
			d += 0.5
		return d
	for o: Car in other:
		o.progress = fposmod(o.progress + 1.0, traffic.routes[o.route_id].length)
		if o.global_position.distance_to(Vector3(-30, 0, 0)) < 60.0:
			o.progress = fposmod(o.progress + traffic.routes[o.route_id].length * 0.5, traffic.routes[o.route_id].length)
	# Red for the main road (x) at junction 0 (-6, 0): the car stops before it.
	traffic.light_clock = Traffic.X_GREEN + Traffic.AMBER + 0.5
	car.progress = at_x.call(-45.0)
	car.speed = Car.CRUISE
	await get_tree().create_timer(7.0).timeout
	var front: float = car.global_position.x + ProcCar.collision_size(car.kind).z / 2.0
	_report(car.speed < 0.2 and car.blocked_by == "light" and front < -11.5,
			"a car stops at a red light before the junction (speed %.1f, %s, front at x %.1f)" % [car.speed, car.blocked_by, front])
	traffic.light_clock = 0.0
	await get_tree().create_timer(4.0).timeout
	_report(car.global_position.x > -6.0, "green: it drives on through the junction (x %.1f)" % car.global_position.x)
	# Overtaking: a car standing still in the lane (abandoned), the car behind passes it on the left.
	var stopped: Car = other[0]
	var r_old: int = stopped.route_id
	stopped.route_id = 3
	stopped.progress = at_x.call(-40.0)
	stopped.abandoned = true
	stopped.speed = 0.0
	traffic.light_clock = 0.0
	car.progress = at_x.call(-62.0)
	car.speed = Car.CRUISE
	var went_left: bool = false
	for i: int in 90:
		await get_tree().create_timer(0.3).timeout
		if car.lane_offset < -3.0:
			went_left = true
		if car.global_position.x > stopped.global_position.x + 8.0 and car.lane_offset == 0.0:
			break
	if car._ahead_car:
		print("[SelfTest]   blocked by %s (route %d) at %s" % [car._ahead_car.name, car._ahead_car.route_id, car._ahead_car.global_position.snapped(Vector3.ONE * 0.1)])
	_report(went_left and car.overtakes >= 1 and car.global_position.x > stopped.global_position.x + 5.0 and car.lane_offset == 0.0,
			"a car overtakes a car standing still and goes back into its lane (left %s, x %.1f vs %.1f, offset %.1f, speed %.1f, %s)" % [
			went_left, car.global_position.x, stopped.global_position.x, car.lane_offset, car.speed, car.blocked_by])
	stopped.queue_free()
	for c: Node in get_tree().get_nodes_in_group(&"cars"):
		c.queue_free()
	await get_tree().physics_frame


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
			if not on_road and p.z < -70.0 and Mountain.on_road(p):
				on_road = true  # point 49b: the pass road
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
	# Point 47a: route 2 starts on Industrial Road now: find the spot on Main Road at x -36 (east lane) by position.
	var p0: float = 0.0
	while p0 < traffic.routes[2].length and (traffic.routes[2].sample(p0)[0] as Vector3).x < -36.0:
		p0 += 1.0
	car.progress = p0
	car.speed = Car.CRUISE
	# Other cars on that route go half a lap away, so none of them queues in front of the test car.
	var gap_cars: float = 0.0
	for c: Node in cars:
		if c != car and (c as Car).route_id == 2:
			(c as Car).progress = p0 + traffic.routes[2].length * 0.5 + gap_cars
			gap_cars += 15.0
	var person: Pedestrian = world.call("_add_pedestrian", traffic.routes[2].sample(p0 + 14.0)[0], 0)
	person.set_physics_process(false)
	await get_tree().create_timer(5.0).timeout
	var gap: float = car.global_position.distance_to(person.global_position)
	_report(car.speed < 0.1 and car.blocked_by == "person" and gap > 2.5,
			"car stops for a person in the road (speed %.1f, %s, %.1f m away)" % [car.speed, car.blocked_by, gap])
	person.queue_free()
	await get_tree().create_timer(3.0).timeout
	_report(car.speed > 2.0, "car drives on once the road is clear (speed %.1f, %s)" % [car.speed, car.blocked_by])
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
	# Point 32: in panic it never stops, not even for a person in the lane (horn, crawls past).
	car.route_id = 2
	car.progress = 30.0
	car.speed = Car.CRUISE
	car.panic = Car.PANIC_TIME
	var in_lane: Pedestrian = world.call("_add_pedestrian", traffic.routes[2].sample(30.0 + 16.0)[0], 0)
	in_lane.set_physics_process(false)
	var slowest: float = INF
	for i: int in 300:
		await get_tree().physics_frame
		slowest = minf(slowest, car.speed)
	_report(slowest >= Car.PANIC_MIN_SPEED - 0.3 and car.progress > 30.0 + 16.0,
			"a panicking car doesn't stop for a person in the lane (slowest %.1f m/s, at %.0f m, person at 46 m)" % [slowest, car.progress])
	in_lane.queue_free()
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
		# Point 63: it waits (no driving through it), then overtakes on the left when the other lane is clear.
		_report(d > 3.0 and (other.speed < 0.2 or other.lane_offset < -1.0),
				"car behind a stopped car waits or overtakes it (%.1f m away, speed %.1f, offset %.1f)" % [d, other.speed, other.lane_offset])
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
		# An ordinary passer-by (an officer or Crow as "customer" made the run-off flaky).
		if not (n as Pedestrian).dead and not (n is PoliceOfficer or n is Shopkeeper or n is ParkGoer):
			npc = n as Pedestrian
	if npc == null:  # (--only=selling: no pedestrians spawned yet)
		npc = world.call("_add_pedestrian", front + Vector3(3, 0, 3), 0)
		await get_tree().physics_frame
	world.call("make_customer", npc)
	_report(npc.wants > 0 and npc.is_in_group(&"interactable") and npc.is_in_group(&"customer"),
			"pedestrian becomes a customer (wants %d for €%d)" % [npc.wants, npc.offer])
	# Point 34: no accepted deal, no sale.
	npc.become_customer(2, 150, 60.0)
	p.teleport(npc.global_position + Vector3(1.2, 0.1, 0))
	npc._server_sell(1)
	_report(npc.wants == 2 and not npc.deal_ok and p.last_message.contains("Text me first"),
			"no sale before the deal is accepted by phone ('%s')" % p.last_message)
	var deal := func(bags: int, price: int, outcome: String) -> void:
		npc.become_customer(bags, price, 60.0)
		npc.accept_deal()
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
			and str(p.last_phone[1]).contains("need") and str(p.last_phone[1]).contains("Meet me"),
			"customer texts a proposal: %s" % [p.last_phone])
	p._host_phone_reply(str(npc.name), "accept")
	await get_tree().create_timer(1.0).timeout
	var pos0: Vector3 = npc.global_position
	await get_tree().create_timer(2.0).timeout
	_report(npc.deal_ok and npc.global_position.distance_to(pos0) < 0.3 and str(p.last_phone[1]).contains("wait"),
			"'Accept': the customer waits (moved %.2f m) - '%s'" % [npc.global_position.distance_to(pos0), p.last_phone[1]])
	# Point 34: counter-offers.
	npc.become_customer(2, 100, 60.0)
	Pedestrian.force_counter = "no"
	p._host_phone_reply(str(npc.name), "counter", 150)
	_report(not npc.deal_ok and npc.wants == 2 and npc.offer == 100 and str(p.last_phone[2]).ends_with("#fixed"),
			"counter refused: the deal stays open at the old price, no second counter - '%s'" % p.last_phone[1])
	p._host_phone_reply(str(npc.name), "counter", 140)
	_report(not npc.deal_ok and npc.offer == 100 and str(p.last_phone[1]).contains("already"), "a second counter is turned down")
	p._host_phone_reply(str(npc.name), "accept")
	_report(npc.deal_ok and npc.offer == 100, "then accepting at its price works")
	npc.become_customer(2, 100, 60.0)
	Pedestrian.force_counter = "yes"
	p._host_phone_reply(str(npc.name), "counter", 125)
	_report(npc.deal_ok and npc.offer == 125, "counter accepted: deal at €%d" % npc.offer)
	npc.become_customer(2, 100, 60.0)
	Pedestrian.force_counter = "leave"
	p._host_phone_reply(str(npc.name), "counter", 150)
	_report(npc.wants == 0, "too greedy: the customer walks off - '%s'" % p.last_phone[1])
	var tries: int = 400
	var took: Array[int] = [0, 0, 0]
	for i: int in tries:
		for k: int in 3:
			if randf() < clampf(1.05 - Pedestrian.COUNTER_STEPS[k] * Pedestrian.COUNTER_PICKY, 0.05, 0.95):
				took[k] += 1
	_report(took[0] > took[1] and took[1] > took[2] and took[0] > tries * 0.7 and took[2] < tries * 0.25,
			"the further you go, the less often they accept (+10/25/50%%: %d/%d/%d of %d)" % [took[0], took[1], took[2], tries])
	npc.become_customer(2, 100, 60.0)
	p._host_phone_reply(str(npc.name), "decline")
	_report(npc.wants == 0 and not npc.is_in_group(&"customer"), "'Decline': no longer a customer")
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


# --- Cars (point 45) ----------------------------------------------------------------------

func _check_vehicles(world: Node3D) -> void:
	var dealer := world.find_child("Carlo", true, false) as CarDealer
	var spots: int = 0
	for i: int in range(1, 9):
		if world.find_child("CarDelivery%d" % i, true, false):
			spots += 1
	var shows: int = world.find_children("*", "DisplayCar", true, false).size()
	_report(dealer != null and spots == 4 and shows == 2 and Vehicles.current != null,
			"Carlo's Cars: the dealer, 4 delivery spots, %d cars on show" % shows)
	if dealer == null or Vehicles.current == null:
		return
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Driver"
	var front: Vector3 = (world.find_child("CarDealer", true, false) as Node3D).to_global(Vector3(0.0, 0.2, -3.6))
	p.auto_target = front
	world.get_node("Players").add_child(p)
	p.global_position = front
	for i: int in 10:
		await get_tree().physics_frame
	GameState.player_data.erase("Driver")
	GameState.get_or_create_player_data("Driver")["cash"] = 3000
	var answers: Array = []
	var cb := func(ok: bool, msg: String) -> void: answers.append([ok, msg])
	dealer.buy_result.connect(cb)
	dealer.request_buy_car("hatch")
	await get_tree().process_frame
	_report(answers.size() == 1 and not answers[0][0] and Vehicles.current.cars().is_empty(),
			"not enough money: no car (%s)" % [answers[0] if answers.size() else "-"])
	GameState.get_or_create_player_data("Driver")["cash"] = 10000
	dealer.request_buy_car("hatch")
	for i: int in 3:
		await get_tree().physics_frame
	var cars: Array[PlayerCar] = Vehicles.current.cars()
	var car: PlayerCar = cars[0] if cars.size() == 1 else null
	var spot: Node3D = world.find_child("CarDelivery1", true, false) as Node3D
	_report(answers.size() == 2 and answers[1][0] and car != null and int(GameState.player_data["Driver"]["cash"]) == 5500
			and car.global_position.distance_to(spot.global_position) < 0.5,
			"buying the Pony Hatch for €4,500: it waits on the lot (%s)" % [answers[1] if answers.size() > 1 else "-"])
	dealer.buy_result.disconnect(cb)
	if car == null:
		p.queue_free()
		return
	# Get in: the walker stands next to it, the host gives it the driver's seat.
	p.auto_walk = true
	p.global_position = car.exit_spot(0)
	p.auto_target = p.global_position
	await get_tree().physics_frame
	var seat: int = car.host_enter(p)
	for i: int in 3:
		await get_tree().physics_frame
	_report(seat == 0 and p.vehicle == car and p.seat == 0 and p.collision.disabled,
			"getting in: the driver's seat, the body rides along (seat %d)" % seat)
	# Drive: full throttle for 1.5 s (nose to the road, west).
	var start: Vector3 = car.global_position
	car.test_drive = true
	car.test_input = Vector3(0, 1, 0)
	await get_tree().create_timer(1.5).timeout
	var moved: float = Vector2(car.global_position.x - start.x, car.global_position.z - start.z).length()
	_report(moved > 3.0 and car.global_position.x < start.x - 2.5 and car.speed > 5.0
			and p.global_position.distance_to(car.global_position) < 2.0,
			"full throttle: %.1f m in 1.5 s, %.1f m/s, the driver comes along" % [moved, car.speed])
	var yaw0: float = car.rotation.y
	car.test_input = Vector3(1, 0.5, 0)
	await get_tree().create_timer(0.8).timeout
	_report(angle_difference(yaw0, car.rotation.y) > 0.2, "steering left turns the car left (%.2f rad)" % angle_difference(yaw0, car.rotation.y))
	car.test_input = Vector3(0, 0, 1)
	for i: int in 120:
		await get_tree().physics_frame
		if absf(car.speed) < 0.1:
			break
	_report(absf(car.speed) < 0.1, "the handbrake stops it (%.2f m/s)" % car.speed)
	# A wall stops it: nose to the sales office, 3 m away.
	var office: Node3D = world.find_child("CarDealer", true, false) as Node3D
	car.global_position = office.global_position + Vector3(-4.5, 0, 3.4)
	car.rotation.y = -PI / 2.0  # nose east (+X)
	car.speed = 0.0
	car.test_input = Vector3(0, 1, 0)
	await get_tree().create_timer(1.5).timeout
	var nose_x: float = car.global_position.x + ProcCar.collision_size(ProcCar.Kind.HATCHBACK).z / 2.0
	_report(nose_x < office.global_position.x + 0.3 and absf(car.speed) < 3.0,
			"driving into a wall: it stops there (nose x %.2f, wall x %.2f, %.1f m/s)" % [nose_x, office.global_position.x, car.speed])
	# Running someone over (host): a pedestrian in front of a fast car.
	car.test_input = Vector3.ZERO
	car.global_position = Vector3(40.0, car.global_position.y, 56.5)
	car.rotation.y = PI / 2.0  # nose west, towards the road
	await get_tree().physics_frame
	var npc: Pedestrian = world.call("_add_pedestrian", Vector3(35.6, 0.15, 56.5), 1)
	for i: int in 5:
		await get_tree().physics_frame
	npc.velocity = Vector3.ZERO
	car.speed = 12.0
	car.test_input = Vector3(0, 1, 0)
	var hits0: int = car.hits
	for i: int in 60:
		await get_tree().physics_frame
		if npc.dead:
			break
	_report(car.hits > hits0 and npc.dead, "a pedestrian hit at speed goes down (hits %d, dead %s)" % [car.hits - hits0, npc.dead])
	car.test_input = Vector3(0, 0, 1)
	for i: int in 90:
		await get_tree().physics_frame
	# Get out: beside the car, solid again.
	car.host_exit(p)
	for i: int in 4:
		await get_tree().physics_frame
	_report(p.vehicle == null and not p.collision.disabled and car.distance_to_body(p.global_position) > 0.3
			and car.seats[0] == 0, "getting out: next to the car (%.1f m from the body)" % car.distance_to_body(p.global_position))
	# Saved where it was parked; a restore brings it back there.
	var parked: Vector3 = car.global_position
	world.capture_for_save()
	var rec: Dictionary = GameState.world.get("vehicles", {}).get(car.uid, {})
	_report(not rec.is_empty() and (rec["pos"] as Vector3).distance_to(parked) < 0.1 and str(rec["model"]) == "hatch",
			"the save knows where it is parked")
	var uid: String = car.uid
	car.free()
	Vehicles.current.restore()
	await get_tree().physics_frame
	var back: PlayerCar = Vehicles.current.get_node_or_null("Car" + uid) as PlayerCar
	_report(back != null and back.global_position.distance_to(parked) < 0.2, "after loading it is back on that spot")
	if back:
		Vehicles.current.host_remove(back)
	if is_instance_valid(npc):
		npc.queue_free()
	GameState.player_data.erase("Driver")
	p.queue_free()
	await get_tree().physics_frame


# --- Cover garage (point 52) ----------------------------------------------------------------

func _check_garage(world: Node3D) -> void:
	var garage: Node3D = world.find_child("CoverGarage", true, false) as Node3D
	var prop: Property = garage.get_node_or_null("Property") as Property if garage else null
	var bay: RepairBay = garage.find_child("RepairBay", true, false) as RepairBay if garage else null
	var shelf: HiddenShelfDoor = garage.find_child("SecretShelf", true, false) as HiddenShelfDoor if garage else null
	_report(prop != null and bay != null and shelf != null and prop.for_sale and bay.property() == prop,
			"the cover garage: for sale, a car lift, a secret shelf door")
	if prop == null or bay == null or shelf == null:
		return
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Mech"
	var at_bay: Vector3 = bay.global_position + bay.global_basis.x * 0.6 + bay.global_basis.z * 2.8
	p.auto_target = at_bay
	world.get_node("Players").add_child(p)
	p.global_position = at_bay
	for i: int in 5:
		await get_tree().physics_frame
	GameState.player_data.erase("Mech")
	GameState.get_or_create_player_data("Mech")
	bay.work = ""
	var msg: String = bay.do_action(p)
	_report(msg.begins_with("Buy the garage") and not prop.is_crew_owned(), "not owned: the lift does nothing (%s)" % msg)
	prop.host_set_owned("Mech")
	bay.new_job(1)  # new brake pads: 1 part, 4 steps, €260
	msg = bay.do_action(p)
	_report(int(bay.state["done"]) == 0 and "Spare Parts" in msg, "a job that needs parts waits for them (%s)" % msg)
	GameState.give("Mech", 0, [{"id": "car_parts", "count": 2}])
	var clean0: int = int(GameState.player_data["Mech"]["clean"])
	for i: int in 4:
		bay.work = ""
		msg = bay.do_action(p)
		if i == 0:
			_report(bay.work == "repair" and int(bay.state["done"]) == 1 and GameState.count_item("Mech", "car_parts") == 1,
					"working uses the part and plays the repair animation (%s)" % msg)
	var clean1: int = int(GameState.player_data["Mech"]["clean"])
	_report(clean1 == clean0 + 260 and int(bay.state["job"]) == -1 and float(bay.state["wait"]) >= bay.wait_hours.x,
			"4 steps later: done, €%d CLEAN money, next customer in %.1f h (%s)" % [clean1 - clean0, float(bay.state["wait"]), msg])
	bay.state["wait"] = 0.05
	bay.tick(0.1)
	_report(int(bay.state["job"]) >= 0 and str(bay.state["who"]) != "", "the next customer brings a car (%s)" % bay.prompt_for(p))
	# The hidden room: the shelf blocks the gap until it slides aside.
	var room: Node3D = garage.find_child("HiddenRoomSpot", true, false) as Node3D
	var before: Vector3 = garage.to_global(Vector3(0.0, 0.2, -8.0))
	p.global_position = before
	p.auto_target = room.global_position
	await get_tree().create_timer(2.5).timeout
	var blocked: bool = garage.to_local(p.global_position).z > -10.0
	_report(blocked and not shelf.is_open, "the closed shelf blocks the way to the hidden room (z %.1f)" % garage.to_local(p.global_position).z)
	shelf.interact()
	await get_tree().create_timer(1.0).timeout
	p.auto_target = room.global_position
	await get_tree().create_timer(3.0).timeout
	_report(shelf.is_open and p.global_position.distance_to(room.global_position) < 0.8,
			"pulled aside: you walk into the hidden room (%.1f m from its middle, at %s local)" % [
			p.global_position.distance_to(room.global_position), garage.to_local(p.global_position).snapped(Vector3.ONE * 0.1)])
	var why: String = Placement.check(world.get_world_3d(), get_tree(), ItemDB.get_item(&"grow_pot"),
			room.global_position + Vector3(1.5, 0, 0), 0.0)
	_report(why == "", "stations can be placed in the hidden room ('%s')" % why)
	shelf.interact()
	await get_tree().create_timer(1.0).timeout
	GameState.player_data.erase("Mech")
	p.queue_free()
	await get_tree().physics_frame


# --- Territory (point 51) -------------------------------------------------------------------

func _check_territory(world: Node3D) -> void:
	var terr: Territory = Territory.current
	_report(terr != null and terr.state == GameState.world.get("territory") and terr.state.size() == Territory.districts().size(),
			"World/Territory: %d districts in GameState.world[territory]" % (terr.state.size() if terr else 0))
	if terr == null:
		return
	var all: Dictionary = Territory.districts()
	var ok: bool = true
	for id: String in all.keys():
		ok = ok and Territory.district_at(all[id]["anchor"]) == id and not terr.is_held(id)
	_report(ok, "every anchor lies in its own district, all Crow turf at the start")
	var id: String = "old_town" if all.has("old_town") else str(all.keys()[0])
	var at: Vector3 = (all[id]["anchor"] as Vector3) + Vector3.UP * 0.15  # (anchors lie on the pavement)
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Turfer"
	p.auto_target = at
	world.get_node("Players").add_child(p)
	p.global_position = at + Vector3.UP * 0.2
	for i: int in 5:
		await get_tree().physics_frame
	GameState.player_data.erase("Turfer")
	GameState.give("Turfer", 0, [{"id": "weed_bag", "count": 10}])
	var npc: Pedestrian = world.call("_add_pedestrian", at + Vector3(1.5, 0.1, 0.0), 1)
	for i: int in 5:
		await get_tree().physics_frame
	var sell := func(bags: int, price: int, outcome: String) -> void:
		npc.become_customer(bags, price, 60.0)
		npc.accept_deal()
		p.teleport(npc.global_position + Vector3(1.2, 0.1, 0))
		Pedestrian.force_outcome = outcome
		npc._server_sell(1)
	terr.debug_set(id, 20.0, false)
	terr.state[id]["warned"] = false
	Territory.crow_send_chance = 1.0
	var crows0: int = get_tree().get_nodes_in_group(&"rivals").size()
	sell.call(2, 120, "fair")
	_report(is_equal_approx(terr.influence(id), 28.0) and bool(terr.state[id]["warned"])
			and get_tree().get_nodes_in_group(&"rivals").size() == crows0,
			"first sale on Crow turf: +8%% (%.0f%%) and only a warning, no Crow yet" % terr.influence(id))
	sell.call(1, 60, "fair")
	await get_tree().physics_frame
	var sent: Rival = null
	for n: Node in get_tree().get_nodes_in_group(&"rivals"):
		if (n as Rival).sent_target == p:
			sent = n as Rival
	_report(sent != null and sent.global_position.distance_to(p.global_position) > 20.0,
			"next sale there: a Crow is sent after the seller from %.0f m" % (sent.global_position.distance_to(p.global_position) if sent else -1.0))
	if sent:
		var d0: float = sent.global_position.distance_to(p.global_position)
		Rival.obey_daylight = true
		var d1: float = d0
		for i: int in 30:
			await get_tree().create_timer(0.5).timeout
			d1 = sent.global_position.distance_to(p.global_position)
			if d1 < d0 - 8.0 or sent.target == p:
				break
		_report(d1 < d0 - 8.0 or sent.target == p, "the sent Crow comes for the seller (by day too): %.0f m -> %.0f m%s" % [
				d0, d1, " and aims at them" if sent.target == p else ""])
		var kid: String = Territory.district_at(sent.global_position)
		sent.host_damage(500, p, p.global_position)
		var inf0: float = terr.influence(kid)
		get_tree().call_group(&"kill_hooks", "on_kill", p, sent)  # (what PlayerCombat calls after a kill)
		_report(absf(terr.influence(kid) - inf0 - Territory.KILL_CROW_GAIN) < 0.3, "killing a Crow (in %s): +%.0f%%" % [kid, Territory.KILL_CROW_GAIN])
	Territory.crow_send_chance = 0.0
	terr.debug_set(id, 97.0, false)
	sell.call(1, 60, "fair")
	_report(terr.is_held(id) and is_equal_approx(terr.influence(id), 100.0), "a sale past 100%%: the crew takes %s" % id)
	_report(Territory.crew_holds(at) and not Territory.crew_holds(all[_other_district(all, id)]["anchor"]),
			"crew_holds: true in %s, false elsewhere" % id)
	# Customers in crew turf pay more: compare many offers.
	var sum_held: int = 0
	for i: int in 20:
		npc.wants = 0
		world.call("make_customer", npc)
		sum_held += int(float(npc.offer) / maxf(1.0, npc.wants))
	terr.debug_set(id, 40.0, false)
	var sum_crow: int = 0
	for i: int in 20:
		npc.wants = 0
		world.call("make_customer", npc)
		sum_crow += int(float(npc.offer) / maxf(1.0, npc.wants))
	_report(sum_held > sum_crow, "customers on your turf pay more (avg €%d vs €%d per bag)" % [sum_held / 20, sum_crow / 20])
	# Losing it: held, then a death to a Crow under LOSE_AT.
	terr.debug_set(id, 55.0, true)
	var crow_killer: Rival = world.call("add_rival", at + Vector3(0, 0, 30)) as Rival
	get_tree().call_group(&"kill_hooks", "on_kill", crow_killer, p)
	_report(not terr.is_held(id) and is_equal_approx(terr.influence(id), 47.0), "killed by a Crow at 55%%: down to %.0f%%, lost to the Crows" % terr.influence(id))
	# Decay on Crow turf while time passes (sleep).
	terr.on_hours_skipped(10.0)
	_report(is_equal_approx(terr.influence(id), 47.0 - Territory.DECAY_PER_HOUR * 10.0), "Crow turf drifts back: %.0f%% after 10 h" % terr.influence(id))
	_report(terr.status_text(id).contains("Crow turf"), "status: '%s'" % terr.status_text(id))
	terr.debug_set(id, 0.0, false)
	terr.state[id]["warned"] = false
	Territory.crow_send_chance = Territory.CROW_SEND_DEFAULT
	Pedestrian.force_outcome = ""
	if crow_killer and is_instance_valid(crow_killer):
		crow_killer.queue_free()
	npc.queue_free()
	GameState.player_data.erase("Turfer")
	p.queue_free()
	await get_tree().physics_frame


func _other_district(all: Dictionary, not_id: String) -> String:
	for k: String in all.keys():
		if k != not_id:
			return k
	return not_id


## Point 103: street detail = PropScatter MultiMeshes (one draw per mesh, however many copies) with real collision.
func _check_street_detail(world: Node3D) -> void:
	var scatters: Array[Node] = get_tree().get_nodes_in_group(&"prop_scatter")
	for i: int in 30:
		var ready_all: bool = true
		for n: Node in scatters:
			if n.find_children("*", "MultiMeshInstance3D", false, false).is_empty():
				ready_all = false
		if ready_all:
			break
		await get_tree().process_frame
	var copies: int = 0
	var meshes: int = 0
	var bad: PackedStringArray = []
	for n: Node in scatters:
		var ps := n as PropScatter
		copies += ps.count()
		for m: Node in ps.find_children("*", "MultiMeshInstance3D", false, false):
			meshes += 1
			if (m as MultiMeshInstance3D).multimesh.instance_count != ps.count():
				bad.append(ps.name)
	_report(scatters.size() >= 6 and copies >= 200 and meshes >= 6 and meshes < 40 and bad.is_empty(),
			"street detail: %d PropScatters, %d props drawn with %d MultiMeshes%s" % [scatters.size(), copies, meshes,
			"" if bad.is_empty() else " (wrong counts: %s)" % ", ".join(bad)])
	var bol := world.find_child("StreetBollard", true, false) as PropScatter
	var hit: bool = false
	if bol and bol.count() > 0:
		var at: Vector3 = bol.to_global(Vector3(bol.spots[0], bol.spots[1], bol.spots[2]))
		await get_tree().physics_frame
		var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 3.0, 0), at + Vector3(0, 0.5, 0))
		hit = not world.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	_report(hit, "a scattered bollard has collision (ray from above hits it)")


## Point 103: weather - the host's rain reaches the shader (wetness), the sky (overcast) and late joiners (net state).
func _check_weather(world: Node3D) -> void:
	var w := world.get_node_or_null("Weather") as Weather
	_report(w != null and Weather.current == w and not w.raining and is_zero_approx(w.wetness),
			"weather: World/Weather exists, dry at the start of a test")
	if w == null:
		return
	w.debug_set(true)
	await get_tree().process_frame
	var wet: float = w.wetness  # (global_shader_parameter_get is editor-only; _publish sets the parameter from it)
	var state: Dictionary = w.get_net_state()
	w.debug_set(false, 0.0)
	w.apply_net_state(state)
	var restored: bool = w.raining and is_equal_approx(w.wetness, 1.0)
	w.debug_set(false, 0.6)
	await get_tree().create_timer(0.5).timeout
	var drying: bool = w.wetness < 0.6 and w.wetness > 0.5 and DayNight.overcast < 1.0
	w.debug_set(false, 0.0)
	await get_tree().process_frame
	_report(is_equal_approx(wet, 1.0) and restored and drying and is_zero_approx(DayNight.overcast),
			"rain: wetness %.2f (shader parameter), net state restores it, the streets dry slowly after (%s), clear sky after" % [wet, drying])


## Point 102: building sites - each has its skeleton, crane, fence and builder markers; a walker comes in through the
## gate and climbs every flight of the switchback stair to the top slab (the deal spot).
func _check_building_sites(world: Node3D) -> void:
	var sites: Array[Node] = get_tree().get_nodes_in_group(&"building_sites")
	var ok_parts: int = 0
	for n: Node in sites:
		var st := n as BuildingSite
		if st.find_child("CraneJib", false, false) != null and st.find_child("SiteDealSpot", false, false) != null 				and st.find_child("BuilderSpot6", false, false) != null and st.find_child("Flight1", false, false) != null:
			ok_parts += 1
	_report(sites.size() >= 3 and ok_parts == sites.size(),
			"%d building sites, %d with crane + stair + builder / deal markers" % [sites.size(), ok_parts])
	if sites.is_empty():
		return
	var site := sites[0] as BuildingSite
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Climber"
	world.get_node("Players").add_child(p)
	var gate: Vector3 = (site.find_child("SiteGate", false, false) as Node3D).global_position
	p.global_position = site.to_global(site.to_local(gate) + Vector3(0, 0.3, -3.0))
	p.auto_target = p.global_position
	await get_tree().create_timer(0.5).timeout
	var path: Array[Vector3] = [gate + site.global_basis * Vector3(0, 0, 1.5)]
	# Round the stair lanes on their west side (the walker goes straight; the flights are solid).
	var r: Rect2 = site.skeleton_rect()
	var west_x: float = r.end.x - 0.9 - BuildingSite.STAIR_W * 2.0 - 0.9
	var foot0: Vector3 = site.flight(0)[0]
	var gl: Vector3 = site.to_local(gate)
	path.append(site.to_global(Vector3(west_x, foot0.y, gl.z + 2.0)))
	path.append(site.to_global(Vector3(west_x, foot0.y, foot0.z + 0.8)))
	for k: int in site.top_floor():
		var f: Array = site.flight(k)
		var foot: Vector3 = f[0]
		var dir: float = -1.0 if f[1] == 0.0 else 1.0
		path.append(site.to_global(foot + Vector3(0, 0, -dir * 0.8)))
		path.append(site.to_global(foot + Vector3(0, BuildingSite.FH, dir * (BuildingSite.STAIR_RUN + 0.7))))
	var reached: int = 0
	for t: Vector3 in path:
		if not await _walk_to(p, t, 12.0):
			print("[SelfTest]   site walker stuck at local %s, target local %s" % [site.to_local(p.global_position), site.to_local(t)])
			break
		reached += 1
	var top_y: float = site.to_global(Vector3(0, site.slab_top(site.top_floor()), 0)).y
	_report(reached == path.size() and p.global_position.y > top_y - 0.4,
			"climbed %s from the gate to the top slab (%d of %d legs, y %.1f, top %.1f)" % [site.name, reached,
			path.size(), p.global_position.y, top_y])
	p.queue_free()
	await get_tree().physics_frame


## Point 101: shops on the city's ground floors - signs on every street face, a walk-in shop per block with a counter
## spot for session B's shopkeeper, café terraces with TerraceSeat markers, paved blocks without grass.
func _check_city_shops(world: Node3D) -> void:
	var city: Node = world.find_child("City", false, false)
	var signs: int = 0
	var open: Array[Tower] = []
	for n: Node in city.find_children("*", "Tower", true, false):
		var t := n as Tower
		for c: Node in t.get_children():
			if c is Label3D and (c as Label3D).visibility_range_end == ShopFront.SIGN_RANGE:
				signs += 1
		if t.has_open_shop():
			open.append(t)
	var spots: int = city.find_children("ShopkeeperSpot*", "Marker3D", true, false).size()
	var seats: int = city.find_children("TerraceSeat*", "Marker3D", true, false).size()
	_report(signs >= 100 and open.size() >= 5 and spots == open.size() and seats >= 8,
			"city shops: %d shop signs, %d walk-in shops (%d counter spots), %d terrace seats" % [signs, open.size(), spots, seats])
	if open.is_empty():
		return
	var t: Tower = open[0]
	var hx: float = t.width / 2.0 - 0.15
	var u: Array = ShopFront.open_unit(hx * 2.0)
	var door_x: float = -hx + float(u[1]) - 1.2
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Shopper"
	world.get_node("Players").add_child(p)
	p.global_position = t.to_global(Vector3(door_x, 0.45, -t.depth / 2.0 - 2.5))
	p.auto_target = p.global_position
	await get_tree().create_timer(0.5).timeout
	var r: Rect2 = ShopFront.room_rect(t.width, t.depth)
	var inside: Vector3 = t.to_global(Vector3(door_x, 0, r.position.y + 2.5))
	var counter: Vector3 = t.to_global(Vector3(r.get_center().x, 0, r.end.y - 3.4))
	var in_ok: bool = await _walk_to(p, inside, 8.0)
	var to_counter: bool = await _walk_to(p, counter, 8.0)
	var blocked_glass: bool = not await _walk_to(p, t.to_global(Vector3(r.position.x + 0.8, 0, -t.depth / 2.0 - 2.0)), 3.0)
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var bare: int = GrassCover.tuft_points(space, Vector2i(floori(t.global_position.x / GrassCover.CHUNK),
			floori((t.global_position.z - t.depth / 2.0 - 1.0) / GrassCover.CHUNK)),
			GrassCover.field_rects(get_tree(), world)).size()
	_report(in_ok and to_counter and blocked_glass and bare == 0,
			"a walk-in shop (%s): in through the door, up to the counter, the shop window stops you; no grass at its front (%d tufts)" % [t.name, bare])
	p.queue_free()
	await get_tree().physics_frame


## Point 99: the prison's sliding gate opens for a walker and shuts behind them, Block B's stair reaches the upper
## gallery, razor wire on every wall, the guard markers for session B.
func _check_prison(world: Node3D) -> void:
	var prison: Node3D = world.find_child("Prison", true, false) as Node3D
	var gate: SlidingGate = prison.find_child("MainGate", true, false) as SlidingGate if prison else null
	var wires: int = prison.find_children("Wire*", "RazorWire", true, false).size() if prison else 0
	var marks: int = 0
	for nm: String in ["PrisonGuardPost1", "PrisonGuardPost2", "PrisonGuardPost3", "PrisonGuardPost4",
			"PrisonPatrol1", "PrisonPatrol2", "PrisonPatrol3", "PrisonPatrol4"]:
		if prison and prison.find_child(nm, true, false):
			marks += 1
	_report(gate != null and wires == 5 and marks == 8 and prison.find_child("BStairs", true, false) is ProcStairs,
			"prison: sliding gate, razor wire on all %d wall runs, Block B stair, %d/8 guard markers" % [wires, marks])
	if gate == null:
		return
	for i: int in 30:
		await get_tree().physics_frame
	var shut: bool = gate.openness < 0.01
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Visitor"
	world.get_node("Players").add_child(p)
	p.global_position = prison.to_global(Vector3(0, 0.3, 25.0))  # (between the bus and the gate)
	p.auto_target = p.global_position
	await get_tree().create_timer(4.0).timeout
	var opened: float = gate.openness
	var through: bool = await _walk_to(p, prison.to_global(Vector3(0, 0, 12)), 10.0)
	_report(shut and opened > 0.99 and through,
			"the gate is shut with nobody near, rolls open for a player by the bus (%.2f) and lets them walk in" % opened)
	p.global_position = prison.to_global(Vector3(-33.3, 0.3, -17.0))
	p.auto_target = p.global_position
	await get_tree().create_timer(4.0).timeout
	var closed: bool = gate.openness < 0.01
	var up: bool = await _walk_to(p, prison.to_global(Vector3(-33.3, 0, -25.2)), 10.0)
	var along: bool = await _walk_to(p, prison.to_global(Vector3(-26.0, 0, -25.3)), 8.0)
	var y: float = prison.to_local(p.global_position).y
	_report(closed and up and along and y > 3.6,
			"the gate shuts behind them; the Block B stair leads to the upper gallery (%.1f m up)" % y)
	p.queue_free()
	await get_tree().physics_frame


# --- Prison intro (point 49) ----------------------------------------------------------------

func _check_intro(world: Node3D) -> void:
	var intro: Intro = Intro.current
	var prison: Node3D = world.find_child("Prison", true, false) as Node3D
	var doors: Array = prison.find_children("CellDoor*", "Node3D", true, false) if prison else []
	var bus: ProcBus = prison.find_child("Bus", true, false) as ProcBus if prison else null
	var stop: Node3D = world.find_child("BusStop", true, false) as Node3D
	_report(intro != null and not intro.is_running() and prison != null and doors.size() == 4 and bus != null and stop != null,
			"the prison (4 cell doors, the bus) and the village bus stop exist; --selftest skips the intro")
	if intro == null or prison == null or doors.size() < 4 or bus == null or stop == null:
		return
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Inmate"
	world.get_node("Players").add_child(p)
	p.global_position = stop.global_position + Vector3.UP * 0.3
	p.auto_target = p.global_position
	for i: int in 5:
		await get_tree().physics_frame
	GameState.player_data.erase("Inmate")
	GameState.get_or_create_player_data("Inmate")  # new player: €500 + the starter pistol
	intro.debug_start(p)
	await get_tree().physics_frame
	var cell: Node3D = prison.find_child("Cell1", true, false) as Node3D
	var door := prison.find_child("CellDoor1", true, false) as CellDoor
	var data: Dictionary = GameState.player_data["Inmate"]
	_report(p.global_position.distance_to(cell.global_position) < 0.6 and int(data["cash"]) == 0
			and (data["inventory"] as Array).is_empty() and int(data["intro_step"]) == Intro.Step.WALK and door.locked,
			"a new player wakes in cell 1 with empty pockets, the cell door locked (step %d)" % int(data.get("intro_step", -1)))
	intro._host_talk(1, "mentor")
	_report(int(data["intro_step"]) == Intro.Step.WALK, "Marco can't be reached from the cell")
	p.auto_target = door.get_center() + door.global_basis.z * 0.3
	for i: int in 16:
		await get_tree().create_timer(0.25).timeout
		if int(data["intro_step"]) != Intro.Step.WALK:
			break
	_report(not door.locked and door.is_open and int(data["intro_step"]) == Intro.Step.TALK,
			"walking to the door: the guard unlocks it and it slides open (%.1f m from it)" % p.global_position.distance_to(door.get_center()))
	intro._host_talk(1, "desk")
	_report(int(data["intro_step"]) == Intro.Step.TALK, "the desk sends you to Marco first")
	intro._host_talk(1, "mentor")
	_report(int(data["intro_step"]) == Intro.Step.DESK, "talking to Marco: his number, next step the desk")
	intro._host_board(1)
	_report(int(data["intro_step"]) == Intro.Step.DESK, "the bus won't take you without your things")
	intro._host_talk(1, "desk")
	_report(int(data["intro_step"]) == Intro.Step.BUS and int(data["cash"]) == GameState.STARTING_CASH
			and GameState.count_item("Inmate", "pistol") == 0, "the desk gives the wallet back (€%d), no pistol" % int(data["cash"]))
	p.auto_target = stop.global_position  # (the walker would head back to its old target after the ride)
	# Point 49b: the bus really drives over the pass with the rider on board (8x faster in the test).
	Intro.ride_speed_scale = 8.0
	var home: Vector3 = bus.global_position
	intro._host_board(1)
	await get_tree().create_timer(1.5).timeout
	_report(intro.bus_progress > 0.0 and p.bus_ride == bus and p.global_position.distance_to(bus.global_position) < 4.0,
			"on the bus: it drives off with the rider on board (%.0f m along, rider %.1f m from the bus)" % [
			intro.bus_progress, p.global_position.distance_to(bus.global_position)])
	var top: float = 0.0
	for i: int in 160:
		top = maxf(top, bus.global_position.y)
		if intro.bus_progress < 0.0:
			break
		await get_tree().create_timer(0.25).timeout
	_report(top > 25.0 and bus.global_position.distance_to(home) < 1.0,
			"the bus crossed the pass (highest %.1f m) and went back to the prison afterwards" % top)
	Intro.ride_speed_scale = 1.0
	_report(not data.has("intro_step") and p.global_position.distance_to(stop.global_position) < 3.0
			and GameState.count_item("Inmate", "pistol") == 1 and GameState.count_item("Inmate", "ammo_9mm") > 0
			and not intro.is_running(), "on the bus: dropped at the village bus stop (%.1f m) with Marco's package, intro done" % p.global_position.distance_to(stop.global_position))
	# Skip (F2): straight to the bus stop with everything.
	intro.debug_start(p)
	await get_tree().physics_frame
	intro._host_skip(1)
	await get_tree().create_timer(3.0).timeout
	_report(not data.has("intro_step") and p.global_position.distance_to(stop.global_position) < 3.0
			and int(data["cash"]) == GameState.STARTING_CASH and GameState.count_item("Inmate", "pistol") == 1,
			"F2 skips the intro: bus stop, wallet and package")
	# Point 50: a new player joining after the intro: the short version (desk + bus), straight out.
	Intro.late_join_in_tests = true
	GameState.player_data.erase("Inmate")
	intro.host_on_spawn(p, true)
	Intro.late_join_in_tests = false
	await get_tree().physics_frame
	data = GameState.player_data["Inmate"]
	var cell_n: int = int(data.get("intro_cell", 0))
	var door2 := prison.find_child("CellDoor%d" % maxi(1, cell_n), true, false) as CellDoor
	_report(int(data.get("intro_step", -1)) == Intro.Step.DESK and not door2.locked and int(data["cash"]) == 0
			and p.global_position.distance_to(prison.find_child("Cell%d" % maxi(1, cell_n), true, false).global_position) < 0.6,
			"late joiner: wakes in cell %d, door open, straight to the desk (step %d)" % [cell_n, int(data.get("intro_step", -1))])
	intro.host_on_spawn(p, false)
	_report(int(data.get("intro_step", -1)) == Intro.Step.DESK, "a returning player is not reset")
	intro._host_talk(1, "desk")
	p.auto_target = stop.global_position
	Intro.ride_speed_scale = 10.0
	intro._host_board(1)
	for i: int in 160:
		await get_tree().create_timer(0.25).timeout
		if intro.bus_progress < 0.0:
			break
	Intro.ride_speed_scale = 1.0
	await get_tree().create_timer(0.5).timeout
	_report(not data.has("intro_step") and p.global_position.distance_to(stop.global_position) < 3.0
			and int(data["cash"]) == GameState.STARTING_CASH and GameState.count_item("Inmate", "pistol") == 1,
			"late joiner: the bus leaves at once with just them, bus stop + wallet + package")
	door.apply_net_state({"open": false, "locked": true})
	door2.apply_net_state({"open": false, "locked": true})
	GameState.player_data.erase("Inmate")
	p.queue_free()
	await get_tree().physics_frame


# --- Fuel + gas station (point 48, rest) ---------------------------------------------------

## Point 96: every new station (city, docks, prison) stands on firm ground at forecourt height, both drive lanes under
## the canopy are free for a car (rays at bumper and roof height), the road side is open (a car can drive straight
## in from the road: ground at road height, nothing in the way), and a parked car is found + filled by pump 1.
func _check_new_gas_stations(world: Node3D, veh: Vehicles) -> void:
	await get_tree().physics_frame
	var space := world.get_world_3d().direct_space_state
	for tag: String in ["City", "Docks", "Prison"]:
		var st: Node3D = world.find_child("GasStation" + tag, true, false) as Node3D
		if st == null:
			_report(false, "gas station %s exists" % tag)
			continue
		var fc: PavedArea = st.get_node("Forecourt") as PavedArea
		var half: float = minf(fc.size.x / 2.0 - 0.5, 7.0)  # the pump island run (the kiosk closes the back lane at the far end, like QuickFuel)
		var bx: Vector3 = st.global_basis.x
		var bz: Vector3 = st.global_basis.z
		var c: Vector3 = st.global_position
		var probs: PackedStringArray = []
		for lane: float in [-2.2, 2.2]:
			for h: float in [0.5, 1.6]:
				var from: Vector3 = c + bz * lane - bx * half + Vector3.UP * (0.15 + h)
				var to: Vector3 = c + bz * lane + bx * half + Vector3.UP * (0.15 + h)
				var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1 | 2))
				if hit:
					probs.append("lane %+.1f h %.1f blocked by %s" % [lane, h, (hit.collider as Node).name])
			# Ground under the lane: the forecourt top (0.15 above the station origin).
			for t: float in [-0.9, 0.0, 0.9]:
				var top: Vector3 = c + bz * lane + bx * half * t + Vector3.UP * 3.5
				var g: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 8.0, 1))
				if g.is_empty() or absf(g.position.y - (c.y + 0.15)) > 0.06:
					probs.append("ground under lane %+.1f at %.1f: %s" % [lane, t, "none" if g.is_empty() else "y %.2f" % g.position.y])
		# The road side: from the front lane 7 m out towards the road, at bumper height nothing; the ground stays low.
		for t: float in [-0.6, 0.0, 0.6]:
			var from: Vector3 = c + bz * 2.2 + bx * half * t + Vector3.UP * 0.65
			var to: Vector3 = from + bz * 7.0
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1 | 2))
			if hit:
				probs.append("road side blocked by %s" % (hit.collider as Node).name)
			var g: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(to + Vector3.UP * 3.0, to + Vector3.DOWN * 3.0, 1))
			if g.is_empty() or absf(g.position.y - c.y) > 0.35:
				probs.append("no road surface in front (%s)" % ("none" if g.is_empty() else "y %.2f" % g.position.y))
		_report(probs.is_empty(), "gas station %s: forecourt on firm ground, both lanes free, open to the road (%s)" % [tag, "; ".join(probs)])
		var pump: FuelPump = st.get_node("Pump1") as FuelPump
		var car: PlayerCar = veh.host_spawn("sedan", 1, pump.global_position - bz * 2.2 + Vector3.UP * 0.1, PI / 2.0 + st.global_rotation.y, "", 0.5)
		await get_tree().physics_frame
		_report(pump.car_here() == car and pump.get_interaction_prompt().contains("L"), "gas station %s: pump 1 sees the parked car ('%s')" % [tag, pump.get_interaction_prompt()])
		veh.host_remove(car)
		await get_tree().physics_frame

func _check_fuel(world: Node3D) -> void:
	var pumps: Array[Node] = get_tree().get_nodes_in_group(&"fuel_pumps")
	var veh: Vehicles = Vehicles.current
	_report(pumps.size() == 8 and veh != null and world.find_child("GasStation", true, false) != null,
			"QuickFuel + the 3 new stations: %d pumps (want 8) and the GasStation marker" % pumps.size())
	if pumps.size() < 2 or veh == null:
		return
	await _check_new_gas_stations(world, veh)
	var pump := world.find_child("FuelPump1", true, false) as FuelPump
	var car: PlayerCar = veh.host_spawn("sedan", 1, pump.global_position + Vector3(0, 0, -2.2), PI / 2.0, "", 0.5)
	await get_tree().physics_frame
	for i: int in 12:
		car.host_use_fuel(25.0)  # one call per frame of driving; jumps > 30 m count as teleports
	_report(absf(car.fuel - 0.4) < 0.006, "300 m driven: 50%% -> %d%% (a full tank = %.0f km)" % [roundi(car.fuel * 100.0), PlayerCar.FUEL_RANGE / 1000.0])
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Tanker"
	world.get_node("Players").add_child(p)
	p.global_position = pump.global_position + Vector3(1.5, 0.2, 1.2)
	p.auto_target = p.global_position
	for i: int in 3:
		await get_tree().physics_frame
	GameState.player_data.erase("Tanker")
	var data: Dictionary = GameState.get_or_create_player_data("Tanker")
	data["cash"] = 30
	data["clean"] = 0
	_report(pump.car_here() == car and pump.get_interaction_prompt().contains("27 L"), "pump prompt: '%s'" % pump.get_interaction_prompt())
	pump._host_fill(1)
	_report(car.fuel < 1.0 and int(data["cash"]) == 30, "not enough money: no fuel ('%s')" % p.last_message)
	data["cash"] = 20
	data["clean"] = 100
	pump._host_fill(1)
	_report(is_equal_approx(car.fuel, 1.0) and int(data["clean"]) == 46 and int(data["cash"]) == 20,
			"filled up: 27 L for €54, clean money first ('%s')" % p.last_message)
	var rec: Dictionary = (GameState.world.get("vehicles", {}) as Dictionary).get(car.uid, {})
	_report(is_equal_approx(float(rec.get("fuel", -1.0)), 1.0), "the fuel is in the save record")
	# Empty tank: full throttle does nothing.
	car.fuel = 0.0
	p.global_position = car.exit_spot(0)
	p.auto_target = p.global_position
	await get_tree().physics_frame
	car.host_enter(p)
	car.test_drive = true
	car.test_input = Vector3(0, 1, 0)
	var start: Vector3 = car.global_position
	await get_tree().create_timer(1.0).timeout
	var moved: float = car.global_position.distance_to(start)
	_report(moved < 0.3 and absf(car.speed) < 0.1, "empty tank: full throttle moves it %.2f m" % moved)
	car.fuel = 1.0
	var top: float = 0.0
	for i: int in 90:
		await get_tree().physics_frame
		top = maxf(top, absf(car.speed))
	_report(top > 2.0 and car.global_position.distance_to(start) > 2.0, "with fuel it drives again (%.1f m/s, %.1f m)" % [top, car.global_position.distance_to(start)])
	car.test_input = Vector3.ZERO
	car.test_drive = false
	car.host_exit(p)
	veh.host_remove(car)
	GameState.player_data.erase("Tanker")
	p.queue_free()
	await get_tree().physics_frame


# --- Crows at the harbour (point 47c) ------------------------------------------------------

func _check_harbour(world: Node3D) -> void:
	var t: Rect2 = Rival.turf(get_tree(), &"harbour")
	var yard: Rect2 = Rival.turf(get_tree(), &"yard")
	_report(t.size.x > 10.0 and t.get_center().x < -150.0 and yard.size.x > 10.0 and not t.intersects(yard),
			"two Crow turfs: the yard %s and the harbour pier %s" % [yard, t])
	var r: Rival = world.add_rival(Vector3.INF, 0, &"harbour")
	await get_tree().physics_frame
	var marker: Node3D = world.get_marker("HarbourCrows")
	_report(r.post == &"harbour" and marker != null and r.home.distance_to(marker.global_position) < 0.5,
			"a harbour Crow comes from Markers/HarbourCrows (post %s)" % r.post)
	var spot: Vector3 = Rival.yard_point(r)
	_report(spot != Vector3.INF and t.has_point(Vector2(spot.x, spot.z)), "its stroll spots are on the pier (%s)" % spot)
	var leash: Vector3 = r._leash_center()
	_report(t.has_point(Vector2(leash.x, leash.z)), "its leash is the pier, not the yard")
	_report(Rival.on_turf(get_tree(), Vector3(-176, 0.2, 98)) and Rival.on_turf(get_tree(), Vector3(50, 0, 27))
			and not Rival.on_turf(get_tree(), Vector3(-140, 0.2, 84)), "on_turf: pier + yard yes, Quay Road no")
	var yard_crows: int = world.call("_alive_rivals").size()
	var harbour_crows: int = world.call("_alive_rivals", &"harbour").size()
	_report(harbour_crows == 1 and yard_crows == 0, "counted apart: %d harbour, %d yard" % [harbour_crows, yard_crows])
	r.queue_free()
	await get_tree().physics_frame


# --- Ground + safety net (points 56/57) -----------------------------------------------------

## The playable area of gen_world (PLAY) and where the sea starts.
const PLAY_RECT := Rect2(-193, -133, 268, 239)
const QUAY_Z: float = 104.8
const SEA_X: float = -72.5


## Point 61: grass on the open green land, none on roads, soil fields or in buildings.
## Map zone 2: the army base east of the prison - closed (fence + gate), towers, barracks, hangars, vehicles, the
## pass road ends at its gate.
func _check_army(world: Node3D) -> void:
	var base: Node3D = world.find_child("ArmyBase", false, false) as Node3D
	_report(base != null, "the army base (Fort Halden)")
	if base == null:
		return
	var towers: int = base.find_children("Watchtower*", "Watchtower", false, false).size()
	var trucks: int = base.find_children("ArmyTruck*", "ArmyTruck", false, false).size()
	var hangars: int = base.find_children("Hangar*", "", false, false).size()
	_report(towers == 6 and trucks >= 5 and hangars == 2, "%d watchtowers, %d army vehicles, %d hangars" % [towers, trucks, hangars])
	var road: PackedVector3Array = Mountain.road_points()
	_report(road[road.size() - 1].distance_to(Vector3(-106, road[road.size() - 1].y, -355.65)) < 1.0,
			"the pass road ends at the base gate (%s)" % road[road.size() - 1].snapped(Vector3.ONE))
	await get_tree().physics_frame
	# Closed: rays from outside to the middle hit the fence or the gate on every side.
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var open: Array[String] = []
	for pair: Array in [[Vector3(-115, 1.2, -355.65), Vector3(-70, 1.2, -380)], [Vector3(-115, 1.2, -400), Vector3(-70, 1.2, -380)],
			[Vector3(-70, 1.2, -340), Vector3(-70, 1.2, -380)], [Vector3(-70, 1.2, -448), Vector3(-70, 1.2, -380)],
			[Vector3(100, 1.2, -448), Vector3(100, 1.2, -415)], [Vector3(100, 1.2, -345), Vector3(180, 1.2, -380)],
			[Vector3(245, 1.2, -400), Vector3(150, 1.2, -400)]]:
		var from: Vector3 = pair[0]
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, pair[1], 1 | 2))
		if hit.is_empty():
			open.append(str(from))
	_report(open.is_empty(), "the base is closed off on every side (open from: %s)" % ", ".join(open))
	# A walker at the gate can't get in.
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Recruit"
	world.get_node("Players").add_child(p)
	p.global_position = Vector3(-112, 0.3, -355.65)
	p.auto_target = Vector3(-80, 0, -355.65)
	await get_tree().create_timer(5.0).timeout
	_report(p.global_position.x < -103.0, "walking at the gate: stopped outside (x %.1f)" % p.global_position.x)
	# Point 100: walk-in buildings, sandbags, the gate opens for a pass holder, the hangar and a dormitory can be entered.
	var bunks: int = 0
	for b: Node in base.find_children("Barracks*", "", false, false):
		bunks += b.find_children("Bunk*", "ArmyProp", true, false).size()
	var racks: int = base.find_child("Armoury", false, false).find_children("Rack*", "ArmyProp", true, false).size() \
			if base.find_child("Armoury", false, false) else 0
	var cp: Node = base.find_child("CommandPost", false, false)
	var bags: int = base.find_children("Sandbags*", "", false, false).size()
	var gate := base.find_child("BaseGate", false, false) as SlidingGate
	_report(bunks >= 24 and racks == 3 and cp != null and cp.find_child("MapTable", true, false) != null and bags >= 5 and gate != null
			and gate.needs_army_pass and not gate.is_open,
			"Fort Halden: %d bunks in 3 barracks, armoury with %d racks, command post with a map table, %d sandbag walls, the gate shut for a stranger" % [bunks, racks, bags])
	Zones.allow_army(p, 120.0)
	var route: Array[Vector3] = [Vector3(-98, 0, -356.5), Vector3(-98, 0, -380), Vector3(-88, 0, -380), Vector3(-88, 0, -398)]
	var walked: int = 0
	for t: Vector3 in route:
		if not await _walk_to(p, t, 14.0):
			break
		walked += 1
	_report(walked == route.size(), "with a pass the gate opens: walked in and into the open hangar (%d/%d legs)" % [walked, route.size()])
	var route2: Array[Vector3] = [Vector3(-88, 0, -388), Vector3(-80.5, 0, -388), Vector3(-80.5, 0, -408), Vector3(-90, 0, -408),
			Vector3(-90, 0, -414.2)]
	walked = 0
	for t: Vector3 in route2:
		if not await _walk_to(p, t, 12.0):
			break
		walked += 1
	_report(walked == route2.size(), "...and through the door into a dormitory between the bunks (%d/%d legs)" % [walked, route2.size()])
	Zones.allow_army(p, 0.0)
	p.queue_free()
	GameState.player_data.erase("Recruit")
	await get_tree().physics_frame


## Point 85: the airfield at Fort Halden - solid ground + runway, three hangars with a jet each, every jet's sortie
## (taxi, take-off, climb clear of the mountains, landing on the runway, back into its hangar), no two jets too close,
## a jet really rolls when its take-off starts, a parked jet is solid.
func _check_airfield(world: Node3D) -> void:
	var af: Airfield = Airfield.current
	_report(af != null and af.jets.size() == 3, "the airfield with %d jets (one per hangar)" % (af.jets.size() if af else 0))
	if af == null or af.jets.is_empty():
		return
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var bad: Array[String] = []
	for at: Vector3 in [Vector3(-10, 0, -425), Vector3(120, 0, -425), Vector3(225, 0, -425), Vector3(100, 0, -404),
			Vector3(215, 0, -415), Vector3(100, 0, -391), Vector3(180, 0, -370), Vector3(-25, 0, -360), Vector3(230, 0, -440)]:
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 5.0, at + Vector3.DOWN * 5.0, 1))
		if hit.is_empty() or absf((hit["position"] as Vector3).y) > 0.15:
			bad.append("%s %s" % [at, "nothing" if hit.is_empty() else "%.2f" % (hit["position"] as Vector3).y])
	_report(bad.is_empty(), "solid flat ground on the runway, taxiway, apron and the airfield grass (%s)" % ", ".join(bad))
	var lines: Array[String] = []
	var ok: bool = true
	for i: int in af.jets.size():
		var tr: Dictionary = af.tracks[i]
		var pos: PackedVector3Array = tr["pos"]
		var flags: PackedByteArray = tr["flags"]
		var low: float = 1e9
		var top: float = 0.0
		var ground_off: int = 0
		for k: int in pos.size():
			var p: Vector3 = pos[k]
			if flags[k] & 4 == 0:
				continue
			top = maxf(top, p.y)
			var ter: float = Airfield.terrain_at(p.x, p.z)
			if ter > 2.0:
				low = minf(low, p.y - ter)
			if p.y < 0.01 and not (Rect2(af.runway_x0, af.runway_z - 11.0, af.runway_x1 - af.runway_x0, 22.0).has_point(Vector2(p.x, p.z))
					or absf(p.z - af.taxi_z) < 6.5 or Rect2(38.0, -398.0, 124.0, 30.0).has_point(Vector2(p.x, p.z))
					or (absf(p.x - af.link_x0) < 6.5 or absf(p.x - af.link_x1) < 6.5) and p.z < af.taxi_z and p.z > af.runway_z):
				ground_off += 1
		var ev: Array[String] = ["taxi_out", "line_up", "roll", "lift_off", "gone", "appear", "touchdown", "exit", "parked"]
		var order: bool = true
		for e: int in range(1, ev.size()):
			order = order and af.event_time(i, ev[e]) > af.event_time(i, ev[e - 1])
		var lift: Vector3 = af.sample(i, af.event_time(i, "lift_off"))["pos"]
		var td: Vector3 = af.sample(i, af.event_time(i, "touchdown"))["pos"]
		var ex: Vector3 = af.sample(i, af.event_time(i, "exit"))["pos"]
		var parked: Vector3 = af.sample(i, af.event_time(i, "parked") + 1.0)["pos"]
		var hangar: JetHangar = world.find_child("ArmyBase", false, false).get_node("JetHangar%d" % (i + 1)) as JetHangar
		var home: bool = hangar != null and parked.distance_to(hangar.jet_spot()) < 0.5
		var good: bool = order and top > 100.0 and low > 18.0 and ground_off == 0 and lift.x < af.runway_x1 - 40.0 \
				and td.x > af.runway_x0 and ex.x < af.runway_x1 - 5.0 and home and float(tr["length"]) <= af.cycle + 0.5
		ok = ok and good
		lines.append("jet %d: lift-off x %.0f, top %.0f m, %.0f m over the mountains, touchdown x %.0f, off the runway x %.0f, %s, %d ground steps off the concrete" % [
				i + 1, lift.x, top, low, td.x, ex.x, "back in its hangar" if home else "NOT home", ground_off])
	_report(ok, "every jet's sortie: %s" % "; ".join(lines))
	# Spacing: at every second of the cycle no two visible jets within 15 m.
	var closest: float = 1e9
	for t: int in int(af.cycle):
		var ps: Array[Vector3] = []
		for i: int in af.jets.size():
			var s: Dictionary = af.sample(i, fposmod(float(t) + float(i) * af.cycle / af.jets.size(), af.cycle))
			if s["visible"] and (s["pos"] as Vector3).y < 200.0:
				ps.append(s["pos"])
		for a: int in ps.size():
			for b: int in range(a + 1, ps.size()):
				closest = minf(closest, ps[a].distance_to(ps[b]))
	_report(closest > 15.0, "the jets never come closer than %.0f m to each other" % closest)
	# Point 91: a movement (take-off or landing) every 3-5 minutes on the whole field, and the roar only near the base.
	var moves: Array[float] = []
	for i: int in af.jets.size():
		var off: float = float(i) * af.cycle / af.jets.size()
		for ev: String in ["lift_off", "touchdown"]:
			moves.append(fposmod(af.event_time(i, ev) - off, af.cycle))
	moves.sort()
	var gaps: Array[float] = []
	for k: int in moves.size():
		gaps.append(fposmod(moves[(k + 1) % moves.size()] - moves[k], af.cycle))
	var snd: AudioStreamPlayer3D = null
	for c: Node in af.jets[0].get_children():
		if c is AudioStreamPlayer3D:
			snd = c
	_report(gaps.min() >= 150.0 and gaps.max() <= 330.0 and af.sound_range <= 700.0,
			"a take-off or landing every %.0f-%.0f s (cycle %.0f s); jet sound heard up to %.0f m%s" % [gaps.min(), gaps.max(),
			af.cycle, af.sound_range, "" if snd == null else " (max_distance %.0f)" % snd.max_distance])
	# Live: jet 1 a second before its take-off roll -> 4 s later it is rolling fast down the runway, burner on.
	af.set_phase(0, af.event_time(0, "roll") - 1.0)
	for k: int in 3:
		await get_tree().process_frame
	var x0: float = af.jets[0].global_position.x
	await get_tree().create_timer(4.0).timeout
	var j: ProcJet = af.jets[0]
	_report(j.global_position.x > x0 + 25.0 and j.burner and j.visible, "a jet takes off: %.0f m down the runway in 4 s, afterburner %s" % [
			j.global_position.x - x0, "on" if j.burner else "off"])
	# A parked jet is solid (layer 2).
	af.set_phase(1, af.event_time(1, "parked") + 5.0)
	for k: int in 3:
		await get_tree().process_frame
		await get_tree().physics_frame
	var jp: Vector3 = af.jets[1].global_position
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(jp + Vector3(-8, 2.0, 0), jp + Vector3(0, 2.0, 0), 2))
	_report(not hit.is_empty(), "a parked jet in its hangar is solid")
	Airfield.clock_offset = 0.0


## Map zone 8: the hidden bunker - a side road east off the pass summit, solid all the way, a car drives up it, the
## blast door at the end is shut.
func _check_bunker(world: Node3D) -> void:
	var side: PackedVector3Array = Mountain._pts("side_road")
	var spot: Transform3D = Mountain.bunker_spot()
	var mountain: Node = world.find_child("Mountain", false, false)
	var bunker: Node3D = mountain.get_node_or_null("Bunker") as Node3D if mountain else null
	_report(side.size() > 40 and bunker != null and spot.origin.distance_to(Vector3(-98, spot.origin.y, -254)) < 1.0,
			"the bunker side road (%d pts) + the bunker at %s" % [side.size(), spot.origin.snapped(Vector3.ONE)])
	if side.is_empty() or bunker == null:
		return
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var bad: int = 0
	for i: int in range(0, side.size(), 6):
		var q: Vector3 = side[i]
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(q + Vector3.UP * 3.0, q + Vector3.DOWN * 3.0, 1))
		if hit.is_empty() or absf((hit["position"] as Vector3).y - q.y) > 0.1:
			bad += 1
	_report(bad == 0, "the side road is solid (%d bad samples)" % bad)
	var door: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(spot.origin + Vector3(-4, 1.5, 0), spot.origin + Vector3(3, 1.5, 0), 1))
	_report(not door.is_empty() and absf((door["position"] as Vector3).x - spot.origin.x) < 1.5, "the blast door is shut")
	var veh: Vehicles = Vehicles.current
	if veh == null:
		return
	var start: Vector3 = side[8]
	var pc: PlayerCar = veh.host_spawn("sedan", 1, start + Vector3.UP * 0.4, -PI / 2.0, "", 1.0)
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Digger"
	world.get_node("Players").add_child(p)
	p.global_position = pc.exit_spot(0)
	p.auto_target = p.global_position
	await get_tree().physics_frame
	pc.host_enter(p)
	for i: int in 3:
		await get_tree().physics_frame
	pc.test_drive = true
	pc.test_input = Vector3(0, 1, 0)
	await get_tree().create_timer(4.0).timeout
	var at: Vector3 = pc.global_position
	pc.test_input = Vector3(0, 0, 1)
	await get_tree().create_timer(1.0).timeout
	pc.test_drive = false
	_report(at.x > start.x + 20.0 and at.x < spot.origin.x and at.y > start.y + 1.5,
			"a player car drives up the side road to the bunker (x %.1f -> %.1f, %.1f -> %.1f m high)" % [start.x, at.x, start.y, at.y])
	pc.host_exit(p)
	p.queue_free()
	GameState.player_data.erase("Digger")
	veh.host_remove(pc)
	await get_tree().physics_frame


## Map zone 8 inside (user 2026-11-15): the blast door opens, the hall is walkable, the stairs go down, the vehicle
## lift carries a car to the garage 14 m below, every lower room has a floor, the property covers the complex.
func _check_bunker_inside(world: Node3D) -> void:
	var mountain: Node = world.find_child("Mountain", false, false)
	var bunker := mountain.get_node_or_null("Bunker") as BunkerComplex if mountain else null
	_report(bunker != null, "the bunker complex")
	if bunker == null:
		return
	var t: Transform3D = bunker.global_transform
	var door: BunkerDoor = bunker.get_node("Door") as BunkerDoor
	var lift: BunkerLift = bunker.get_node("Lift") as BunkerLift
	var missing: Array[String] = []
	for m: String in ["LabSpot1", "LabSpot6", "StorageSpot4", "BedSpot4", "GarageSpot3", "ControlSpot", "Property"]:
		if bunker.get_node_or_null(m) == null:
			missing.append(m)
	var prop := bunker.get_node_or_null("Property") as BunkerProperty
	_report(missing.is_empty() and prop != null and prop.contains((bunker.get_node("LabSpot1") as Node3D).global_position + Vector3.UP)
			and prop.contains(t * Vector3(0, 1, 8)) and not prop.contains(t * Vector3(0, 1, -5)),
			"markers + the property 'bunker' covers the complex (missing: %s)" % ", ".join(missing))
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	# Floors: a ray down in every room hits its floor.
	var bad: Array[String] = []
	for spot: Array in [["hall", Vector3(-6, 0, 13)], ["garage", Vector3(-10, -14, 8)], ["corridor", Vector3(-2, -14, 30)],
			["lab", Vector3(12, -14, 30)], ["storage", Vector3(-10, -14, 24)], ["quarters", Vector3(-10, -14, 39)]]:
		var p: Vector3 = t * (spot[1] as Vector3)
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p + Vector3.DOWN * 1.0, 1))
		if hit.is_empty() or absf((hit["position"] as Vector3).y - p.y) > 0.1:
			bad.append(spot[0])
	_report(bad.is_empty(), "every room has a floor (bad: %s)" % ", ".join(bad))
	# The door opens.
	if door.is_open:
		door.interact()
		await get_tree().create_timer(3.0).timeout
	var ray := PhysicsRayQueryParameters3D.create(t * Vector3(0, 1.5, -3), t * Vector3(0, 1.5, 1), 1 | 2)
	var shut: bool = not space.intersect_ray(ray).is_empty()
	door.interact()
	await get_tree().create_timer(3.0).timeout
	var open: bool = space.intersect_ray(ray).is_empty()
	_report(shut and open and door.is_open, "the blast door opens (shut %s, open %s)" % [shut, open])
	# A walker goes in, and walks down the first flight of stairs.
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Delver"
	world.get_node("Players").add_child(p)
	p.global_position = t * Vector3(0, 0.3, -4)
	p.auto_target = t * Vector3(-6, 0, 13)
	await get_tree().create_timer(6.0).timeout
	var inside: Vector3 = t.affine_inverse() * p.global_position
	_report(inside.z > 10.0 and absf(inside.y) < 0.5, "walking in through the door into the hall (local %s)" % inside.snapped(Vector3.ONE * 0.1))
	p.global_position = t * Vector3(5, 0.3, 3)
	p.auto_target = t * Vector3(5, -3.5, 11.5)
	await get_tree().create_timer(6.0).timeout
	var down: Vector3 = t.affine_inverse() * p.global_position
	_report(down.z > 9.5 and absf(down.y + 3.5) < 0.4, "walking down the first flight of stairs (local %s)" % down.snapped(Vector3.ONE * 0.1))
	p.global_position = t * Vector3(3, -3.2, 11)
	p.auto_target = t * Vector3(3, -7, 2.5)
	await get_tree().create_timer(6.0).timeout
	var down2: Vector3 = t.affine_inverse() * p.global_position
	_report(down2.z < 4.5 and absf(down2.y + 7.0) < 0.4, "and the second flight (local %s)" % down2.snapped(Vector3.ONE * 0.1))
	p.queue_free()
	GameState.player_data.erase("Delver")
	# The vehicle lift takes a car down to the garage and back up.
	var veh: Vehicles = Vehicles.current
	if veh == null:
		return
	var pc: PlayerCar = veh.host_spawn("sedan", 1, t * Vector3(BunkerComplex.LIFT.get_center().x, 0.5, 6.5), 0.0, "", 1.0)
	await get_tree().create_timer(1.0).timeout
	lift.interact()
	await get_tree().create_timer(lift.travel_time + 2.0).timeout
	var low: Vector3 = t.affine_inverse() * pc.global_position
	var gate_down: bool = not space.intersect_ray(PhysicsRayQueryParameters3D.create(t * Vector3(-3, 0.8, 0.5), t * Vector3(-3, 0.8, 3), 1)).is_empty()
	lift.interact()
	await get_tree().create_timer(lift.travel_time + 2.0).timeout
	var high: Vector3 = t.affine_inverse() * pc.global_position
	_report(absf(low.y + 14.0) < 1.0 and absf(high.y) < 1.0 and gate_down and lift.is_up(),
			"the vehicle lift: car down to %.1f m, back up to %.1f m, boom closed while away %s" % [low.y, high.y, gate_down])
	veh.host_remove(pc)
	await get_tree().physics_frame


## Points 83/84: no invisible walls in the bunker - horizontal rays at knee and chest height across every room only
## hit that room's own walls / furniture with a mesh, and a test walker reaches the far side of every room.
func _check_bunker_rooms(world: Node3D) -> void:
	var mountain: Node = world.find_child("Mountain", false, false)
	var bunker := mountain.get_node_or_null("Bunker") as BunkerComplex if mountain else null
	if bunker == null:
		_report(false, "the bunker complex")
		return
	var t: Transform3D = bunker.global_transform
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var bad: Array[String] = []
	var rooms: Array = BunkerComplex.ROOMS.duplicate()
	rooms.append(["hall", Rect2i(BunkerComplex.HALL.position.x, 1, BunkerComplex.HALL.size.x, 1), BunkerComplex.HALL_H])
	for r: Array in rooms:
		var name: String = r[0]
		if name == "stairs":
			continue
		var rect: Rect2i = r[1]
		var fy: float = 0.0 if name == "hall" else -BunkerComplex.DEPTH
		for hy: float in [0.5, 1.4]:
			# Along x at every metre of z, and along z at every metre of x, 0.3 m in from the walls.
			for z: int in range(rect.position.y, rect.end.y):
				var a := Vector3(rect.position.x + 0.3, fy + hy, z + 0.5)
				var b := Vector3(rect.end.x - 0.3, fy + hy, z + 0.5)
				var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(t * a, t * b, 1 | 2))
				if not hit.is_empty() and not _bunker_hit_ok(hit):
					bad.append("%s x-ray z %d h %.1f hits %s at %s" % [name, z, hy, (hit["collider"] as Node).name,
							(t.affine_inverse() * (hit["position"] as Vector3)).snapped(Vector3.ONE * 0.1)])
			if name == "hall":
				continue
			for x: int in range(rect.position.x, rect.end.x):
				var a2 := Vector3(x + 0.5, fy + hy, rect.position.y + 0.3)
				var b2 := Vector3(x + 0.5, fy + hy, rect.end.y - 0.3)
				var hit2: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(t * a2, t * b2, 1 | 2))
				if not hit2.is_empty() and not _bunker_hit_ok(hit2):
					bad.append("%s z-ray x %d h %.1f hits %s at %s" % [name, x, hy, (hit2["collider"] as Node).name,
							(t.affine_inverse() * (hit2["position"] as Vector3)).snapped(Vector3.ONE * 0.1)])
	_report(bad.is_empty(), "no invisible walls in the bunker rooms (%d: %s)" % [bad.size(), "; ".join(bad.slice(0, 6))])
	# A walker crosses every lower room: garage -> corridor -> lab (far corner), storage, quarters, generator room.
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Inspector"
	world.get_node("Players").add_child(p)
	var y: float = -BunkerComplex.DEPTH
	var legs: Array = [["garage", Vector3(-10, y, 1), Vector3(-10, y, 14)], ["garage -> corridor", Vector3(-10, y, 14), Vector3(-2, y, 17)],
			["corridor", Vector3(-2, y, 17), Vector3(-2, y, 29)],
			["lab", Vector3(-2, y, 29), Vector3(22, y, 38)], ["lab back", Vector3(22, y, 38), Vector3(22, y, 21.5)],
			["storage", Vector3(-2, y, 23), Vector3(-14, y, 19.5)], ["quarters", Vector3(-2, y, 39), Vector3(-7, y, 39)], ["quarters back", Vector3(-7, y, 39), Vector3(-7, y, 44.5)]]
	for extra: Array in BunkerComplex.EXTRA_LEGS:
		legs.append(extra)
	var stuck: Array[String] = []
	for leg: Array in legs:
		p.global_position = t * ((leg[1] as Vector3) + Vector3(0, 0.3, 0))
		p.auto_target = t * (leg[2] as Vector3)
		await get_tree().create_timer(maxf(4.0, (leg[1] as Vector3).distance_to(leg[2]) / 3.0 + 2.0)).timeout
		var at: Vector3 = t.affine_inverse() * p.global_position
		if Vector2(at.x, at.z).distance_to(Vector2((leg[2] as Vector3).x, (leg[2] as Vector3).z)) > 1.2:
			stuck.append("%s (stopped at %s)" % [leg[0], at.snapped(Vector3.ONE * 0.1)])
	_report(stuck.is_empty(), "a test walker gets through every bunker room (%d legs; stuck: %s)" % [legs.size(), ", ".join(stuck)])
	# Point 92: every room reachable on foot in ONE walk (no teleports) from the foot of the stairs AND from the
	# garage, with the lift both up and down.
	var lift: BunkerLift = bunker.get_node("Lift") as BunkerLift
	var stair_foot := Vector3(3, y, 3)
	var garage := Vector3(-10, y, 8)
	var hub: Array = [Vector3(1, y, 3), Vector3(1, y, 12.6), Vector3(-2, y, 15), Vector3(-2, y, 18)]
	var from_garage: Array = [Vector3(-10, y, 13.5), Vector3(-2, y, 15), Vector3(-2, y, 18)]
	var rooms_to: Dictionary = {
		"garage": [Vector3(-2, y, 15), Vector3(-10, y, 13.5), Vector3(-10, y, 4)],
		"lab": [Vector3(-2, y, 29), Vector3(12, y, 30)],
		"storage": [Vector3(-2, y, 23), Vector3(-10, y, 23.5)],
		"quarters": [Vector3(-2, y, 39), Vector3(-10, y, 39)],
		"generator room": [Vector3(-2, y, 46), Vector3(-1, y, 52)],
		"stairs": [Vector3(-2, y, 15), Vector3(1, y, 12.6), Vector3(1, y, 3), Vector3(3, y, 3)],
	}
	var unreached: Array[String] = []
	for lift_down: bool in [false, true]:
		if lift.is_open != lift_down:
			lift.interact()
			await get_tree().create_timer(lift.travel_time + 1.0).timeout
		for start_name: String in ["stairs", "garage"]:
			for room: String in rooms_to:
				if room == start_name:
					continue
				var route: Array = (hub if start_name == "stairs" else from_garage).duplicate()
				if room == "garage" or room == "stairs":
					route = (hub if start_name == "stairs" else []).duplicate()
					route = route.slice(0, 3) if start_name == "stairs" else [Vector3(-10, y, 13.5)]
				route.append_array(rooms_to[room])
				p.global_position = t * ((stair_foot if start_name == "stairs" else garage) + Vector3(0, 0.3, 0))
				p.velocity = Vector3.ZERO
				var ok: bool = true
				var prev: Vector3 = stair_foot if start_name == "stairs" else garage
				for wp: Vector3 in route:
					p.auto_target = t * wp
					var limit: float = prev.distance_to(wp) / 2.5 + 2.5
					var waited: float = 0.0
					while waited < limit:
						await get_tree().create_timer(0.25).timeout
						waited += 0.25
						var at2: Vector3 = t.affine_inverse() * p.global_position
						if Vector2(at2.x, at2.z).distance_to(Vector2(wp.x, wp.z)) < 0.8:
							break
					var at3: Vector3 = t.affine_inverse() * p.global_position
					if Vector2(at3.x, at3.z).distance_to(Vector2(wp.x, wp.z)) > 1.2 or absf(at3.y - y) > 0.6:
						unreached.append("%s -> %s (lift %s, stuck at %s on the way to %s)" % [start_name, room,
								"down" if lift_down else "up", at3.snapped(Vector3.ONE * 0.1), wp])
						ok = false
						break
					prev = wp
				if not ok:
					continue
	if lift.is_open:
		lift.interact()
	_report(unreached.is_empty(), "every bunker room is reachable on foot from the stairs and from the garage, lift up and down (unreached: %s)" % "; ".join(unreached))
	p.queue_free()
	GameState.player_data.erase("Inspector")
	await get_tree().physics_frame


func _bunker_hit_ok(hit: Dictionary) -> bool:
	# Furniture (prefabs/interiors) is visible; only the complex's own bare collision counts as an invisible wall.
	var n: Node = hit["collider"]
	if n is BunkerLiftButton or n.name == &"Machines":
		return true
	while n != null:
		if n.name == &"Furniture":
			return true
		n = n.get_parent()
	return false


## Map zone 3: the slums north of the centre - shacks, caravans, fire barrels, the cheap shack for sale, the loop
## road with its own traffic route.
func _check_slums(world: Node3D) -> void:
	var shacks: int = world.find_children("Shack*", "Shack", true, false).size()
	var caravans: int = world.find_children("Caravan*", "Caravan", true, false).size()
	var fires: int = world.find_children("FireBarrel*", "FireBarrel", true, false).size()
	_report(shacks >= 10 and caravans >= 20 and fires >= 5, "the slums: %d shacks, %d caravans, %d fire barrels" % [shacks, caravans, fires])
	var prop: Property = null
	for n: Node in get_tree().get_nodes_in_group(&"properties"):
		if (n as Property).property_id == &"slum_shack":
			prop = n
	if prop == null:
		for n: Node in world.find_children("Property", "Node3D", true, false):
			if n is Property and (n as Property).property_id == &"slum_shack":
				prop = n
	_report(prop != null and prop.for_sale and prop.price <= 5000, "a cheap property for sale in the slums (%s)" % (
			"Rosehill Shack €%d" % prop.price if prop else "missing"))
	var traffic: Traffic = world.get_node("Traffic") as Traffic
	var r: int = traffic.routes.size() - 1
	for i: int in traffic.routes.size():  # (point 71 appended routes after the slum loop: find it by place)
		var q: Vector3 = traffic.routes[i].sample(0.0)[0]
		if q.z < -55.0 and q.x > -82.0 and q.x < -2.0:
			r = i
	var pt: Vector3 = traffic.routes[r].sample(0.0)[0]
	_report(pt.z < -55.0 and pt.x > -82.0 and pt.x < -2.0, "a traffic route round the slums (route %d starts at %s)" % [r, pt.snapped(Vector3.ONE)])
	var car: Car = Traffic.CAR.instantiate()
	car.route_id = r
	car.progress = 1.0
	car.kind = 1
	traffic.add_child(car, true)
	await get_tree().create_timer(6.0).timeout
	_report(car.progress > 25.0, "a car drives the slum loop (%.0f m)" % car.progress)
	car.queue_free()


## Map zone 7: the city south of the centre - routes from data/city, a traffic car down the highway into the city,
## solid ground, the multi-storey car park can be driven up.
## Point 76: enterable apartment blocks - a walker gets into the lobby, climbs the first flights, the lift rides to
## the roof and back, the roof is walkable.
func _check_apartments(world: Node3D) -> void:
	var blocks: Array[Tower] = []
	for n: Node in world.find_children("ApartmentBlock*", "Tower", true, false):
		if (n as Tower).enterable:
			blocks.append(n as Tower)
	var plain: int = 0
	for n: Node in world.find_children("*", "Tower", true, false):
		if (n as Tower).style == "apartment" and not (n as Tower).enterable:
			plain += 1
	_report(blocks.size() >= 2 and plain >= 4, "apartment blocks: %d enterable, %d more" % [blocks.size(), plain])
	if blocks.is_empty():
		return
	var tw: Tower = blocks[0]
	var t: Transform3D = tw.global_transform
	var hz: float = tw.depth / 2.0 - 0.15
	var zc0: float = hz - 0.3 - Tower.SHAFT
	var top: float = tw.height()
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var roof: Vector3 = t * Vector3(-5.0, top, -hz + 3.0)
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(roof + Vector3.UP * 2.0, roof + Vector3.DOWN, 1))
	_report(not hit.is_empty() and absf((hit["position"] as Vector3).y - roof.y) < 0.1, "the roof is walkable (%.1f m up)" % top)
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Tenant"
	world.get_node("Players").add_child(p)
	p.global_position = t * Vector3(0, 0.3, -hz - 3.0)
	p.auto_target = t * Vector3(-1.0, 0, zc0 - 1.0)
	await get_tree().create_timer(6.0).timeout
	var lobby: Vector3 = t.affine_inverse() * p.global_position
	_report(lobby.z > -hz + 1.0 and absf(lobby.x) < Tower.CORE_X, "walking in through the front door into the lobby (local %s)" % lobby.snapped(Vector3.ONE * 0.1))
	p.global_position = t * Vector3(-3.0, 0.3, zc0 + 0.6)
	p.auto_target = t * Vector3(-2.0, tw.floor_height / 2.0, hz - 1.0)
	await get_tree().create_timer(5.0).timeout
	var mid: Vector3 = t.affine_inverse() * p.global_position
	p.auto_target = t * Vector3(-1.0, tw.floor_height, zc0 + 0.6)
	await get_tree().create_timer(5.0).timeout
	var up1: Vector3 = t.affine_inverse() * p.global_position
	_report(absf(mid.y - tw.floor_height / 2.0) < 0.4 and absf(up1.y - tw.floor_height) < 0.4,
			"climbing the stairs to the 1st floor (landing %.1f m, floor %.1f m)" % [mid.y, up1.y])
	# The lift: stand on it, ride to the roof, walk out of the stair-house, ride back down.
	var lift := tw.get_node("Lift") as ApartmentLift
	p.global_position = t * Vector3(2.2, 0.3, zc0 + 3.0)
	p.auto_target = t * Vector3(2.2, 0, zc0 + 3.0)
	await get_tree().create_timer(1.0).timeout
	lift.interact()
	await get_tree().create_timer(lift.travel_time + 1.5).timeout
	var ride: Vector3 = t.affine_inverse() * p.global_position
	p.auto_target = t * Vector3(0, top, zc0 - 1.2)  # off the lift into the stair-house, then out of its door
	await get_tree().create_timer(3.0).timeout
	p.auto_target = t * Vector3(0, top, -hz + 3.0)
	await get_tree().create_timer(6.0).timeout
	var out: Vector3 = t.affine_inverse() * p.global_position
	_report(absf(ride.y - top) < 0.6 and lift.at_roof() and out.z < zc0 - 3.0 and absf(out.y - top) < 0.5,
			"the lift rides to the roof (%.1f m) and you walk out onto it (local %s)" % [ride.y, out.snapped(Vector3.ONE * 0.1)])
	lift.interact()
	await get_tree().create_timer(lift.travel_time + 1.0).timeout
	_report(lift.at_lobby(), "the lift goes back down to the lobby")
	p.queue_free()
	GameState.player_data.erase("Tenant")
	await get_tree().physics_frame


## Points 77-79: every road tile joins another one (no dead ends: only the pass road leaves the tile grid, north of
## Country Lane), every tile draws a centre line, no tree stands on the asphalt.
func _check_roads(world: Node3D) -> void:
	var dirs: Dictionary = {"W": Vector3(-1, 0, 0), "E": Vector3(1, 0, 0), "N": Vector3(0, 0, -1), "S": Vector3(0, 0, 1)}
	var base: Dictionary = {RoadTile.Type.STRAIGHT: ["W", "E"], RoadTile.Type.CURVE: ["W", "S"],
			RoadTile.Type.T: ["W", "E", "N"], RoadTile.Type.CROSS: ["W", "E", "N", "S"]}
	var tiles: Dictionary = {}  # Vector2i (grid of 12 m) -> Array of world arm dirs (Vector2i)
	var all: Array[RoadTile] = []
	var no_line: int = 0
	for n: Node in world.find_children("*", "RoadTile", true, false):
		var rt := n as RoadTile
		all.append(rt)
		if not rt.center_line:
			no_line += 1
		var arms: Array[Vector2i] = []
		for d: String in base[rt.type]:
			var w: Vector3 = rt.global_basis * (dirs[d] as Vector3)
			arms.append(Vector2i(roundi(w.x), roundi(w.z)))
		tiles[Vector2i(roundi(rt.global_position.x / 6.0), roundi(rt.global_position.z / 6.0))] = arms
	var open: Array[String] = []
	for key: Vector2i in tiles:
		for a: Vector2i in tiles[key]:
			var nb: Vector2i = key + a * 2
			if not tiles.has(nb) or not (tiles[nb] as Array).has(-a):
				var at := Vector2(key.x * 6, key.y * 6)
				if at == Vector2(-150, -72) and a == Vector2i(0, -1):
					continue  # Country Lane -> the mountain pass ribbon (the road to the army base may end)
				open.append("%s %s" % [at, a])
	_report(open.is_empty(), "no dead ends: every road tile joins another (%d tiles; open: %s)" % [tiles.size(), ", ".join(open)])
	_report(no_line == 0, "a centre line on every road tile (%d without)" % no_line)
	var on_road: Array[String] = []
	for n: Node in world.find_children("*", "Node3D", true, false):
		var n3 := n as Node3D
		if not n3.scene_file_path.contains("nature/tree_"):
			continue
		for rt: RoadTile in all:
			if absf(rt.global_position.x - n3.global_position.x) < 6.5 and absf(rt.global_position.z - n3.global_position.z) < 6.5 					and rt.is_on_asphalt(n3.global_position):
				on_road.append("%s %s" % [n3.name, Vector2(n3.global_position.x, n3.global_position.z).snapped(Vector2.ONE)])
				break
	_report(on_road.is_empty(), "no trees on the asphalt (%s)" % ", ".join(on_road))


func _check_city(world: Node3D) -> void:
	var traffic: Traffic = world.get_node("Traffic") as Traffic
	var first: int = Traffic.city_first_route
	_report(first == 6 and traffic.routes.size() >= 9 and Traffic.JUNCTIONS.has(Vector2(6, 204)) and Traffic.LIGHTS.size() >= 7,
			"city traffic data: routes %d.. (%d routes), %d junctions, %d with lights" % [first, traffic.routes.size(),
			Traffic.JUNCTIONS.size(), Traffic.LIGHTS.size()])
	if first < 0 or traffic.routes.size() <= first:
		return
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var holes: int = 0
	for at: Vector2 in [Vector2(102, 60), Vector2(6, 230), Vector2(-54, 300), Vector2(120, 340), Vector2(-66, 200), Vector2(40, 126)]:
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, 3, at.y), Vector3(at.x, -2, at.y), 1))
		if hit.is_empty() or absf((hit["position"] as Vector3).y) > 0.3:
			holes += 1
	_report(holes == 0, "the city and the highway stand on solid ground (%d holes)" % holes)
	var route: TrafficRoute = traffic.routes[first]
	var start: float = 0.0
	while start < route.length and not ((route.sample(start)[0] as Vector3).z > 30.0):
		start += 1.0
	var car: Car = Traffic.CAR.instantiate()
	car.route_id = first
	car.progress = start
	car.kind = 2
	traffic.add_child(car, true)
	await get_tree().create_timer(10.0).timeout
	_report(car.progress > start + 60.0 and car.global_position.z > 100.0,
			"a traffic car drives down the highway into the city (%.0f m, now at %s)" % [car.progress - start, car.global_position.snapped(Vector3.ONE)])
	car.queue_free()
	var veh: Vehicles = Vehicles.current
	var garage: Node3D = world.find_child("ParkingGarage*", true, false) as Node3D
	_report(garage != null, "a multi-storey car park")
	if veh == null or garage == null:
		return
	var lane_x: float = garage.global_position.x + float(garage.get("width")) / 2.0 - 3.0
	var bottom_z: float = garage.global_position.z + float(garage.get("depth")) / 2.0 + 3.0
	var pc: PlayerCar = veh.host_spawn("sedan", 1, Vector3(lane_x, 0.3, bottom_z), 0.0, "", 1.0)
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Parker"
	world.get_node("Players").add_child(p)
	p.global_position = pc.exit_spot(0)
	p.auto_target = p.global_position
	await get_tree().physics_frame
	pc.host_enter(p)
	for i: int in 3:
		await get_tree().physics_frame
	pc.test_drive = true
	pc.test_input = Vector3(0, 0.6, 0)
	var top: float = 0.0
	for i: int in 40:
		await get_tree().create_timer(0.1).timeout
		top = maxf(top, pc.global_position.y)
	pc.test_input = Vector3(0, 0, 1)
	await get_tree().create_timer(1.0).timeout
	_report(top > 2.5, "a car drives up the car park ramp (highest %.1f m)" % top)
	pc.test_drive = false
	pc.host_exit(p)
	p.queue_free()
	GameState.player_data.erase("Parker")
	veh.host_remove(pc)


## Point 49b: the mountain pass - terrain under the road, a traffic car climbs it, a player car drives up a
## straight, the mountain hides the prison from the village and the farm.
func _check_pass(world: Node3D) -> void:
	var mt: Node3D = world.find_child("Mountain", false, false) as Node3D
	var road: PackedVector3Array = Mountain.road_points()
	_report(mt != null and road.size() > 500, "the Mountain node and its road (%d points)" % road.size())
	if mt == null or road.size() < 500:
		return
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var top: float = 0.0
	var bad: int = 0
	for i: int in range(0, road.size(), 20):
		var q: Vector3 = road[i]
		top = maxf(top, q.y)
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(q + Vector3.UP * 6.0, q + Vector3.DOWN * 3.0, 1))
		if hit.is_empty() or absf((hit["position"] as Vector3).y - q.y) > 0.4:
			bad += 1
	_report(bad == 0 and top > 28.0, "the road surface is solid all the way (top %.1f m, %d bad spots)" % [top, bad])
	var snow: float = Mountain.height_at(-200.0, -250.0)
	_report(snow > Mountain.SNOW_LINE, "the ridge rises above the snow line (%.1f m at (-200, -250))" % snow)
	var prison: Node3D = world.find_child("Prison", true, false) as Node3D
	var blocked: int = 0
	var froms: Array[Vector3] = [Vector3(-60, 2, -20), Vector3(-20, 2, -60), Vector3(-150, 2, -85), Vector3(-100, 2, 0)]
	for f: Vector3 in froms:
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(f, prison.global_position + Vector3.UP * 4.0, 1))
		if not hit.is_empty() and (hit["position"] as Vector3).z > -330.0:
			blocked += 1
	_report(prison != null and blocked == froms.size(), "the mountain hides the prison from the village and the farm (%d/%d views blocked)" % [blocked, froms.size()])
	# A traffic car on route 5 climbs the pass.
	var traffic: Traffic = world.get_node("Traffic") as Traffic
	_report(traffic.routes.size() > 5, "traffic route 5 runs over the pass")
	if traffic.routes.size() <= 5:
		return
	var route: TrafficRoute = traffic.routes[5]
	var start: float = 0.0
	while start < route.length and not ((route.sample(start)[0] as Vector3).z < -95.0):
		start += 1.0
	var car: Car = Traffic.CAR.instantiate()
	car.route_id = 5
	car.progress = start
	car.kind = 1
	traffic.add_child(car, true)
	await get_tree().physics_frame
	var y0: float = car.global_position.y
	var off: int = 0
	var hi: float = y0
	for i: int in 60:
		await get_tree().create_timer(0.25).timeout
		hi = maxf(hi, car.global_position.y)
		if not Mountain.on_road(car.global_position, 1.0):
			off += 1
	_report(car.progress > start + 60.0 and hi > y0 + 3.0 and off == 0,
			"a traffic car climbs the pass (%.0f m along, %.1f -> %.1f m high, %d samples off the road)" % [car.progress - start, y0, hi, off])
	car.queue_free()
	# A player car drives up the first climbing leg (west, z -159..-162).
	var veh: Vehicles = Vehicles.current
	if veh == null:
		return
	var best: Vector3 = road[0]
	for q: Vector3 in road:
		if Vector2(q.x + 155.0, q.z + 158.7).length() < Vector2(best.x + 155.0, best.z + 158.7).length():
			best = q
	var pc: PlayerCar = veh.host_spawn("sedan", 1, best + Vector3.UP * 0.4, 1.484, "", 1.0)
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Climber"
	world.get_node("Players").add_child(p)
	p.global_position = pc.exit_spot(0)
	p.auto_target = p.global_position
	await get_tree().physics_frame
	pc.host_enter(p)
	for i: int in 3:
		await get_tree().physics_frame
	var py0: float = pc.global_position.y
	pc.test_drive = true
	pc.test_input = Vector3(0, 1, 0)
	await get_tree().create_timer(3.0).timeout
	var climbed: float = pc.global_position.y - py0
	var dz: float = best.x - pc.global_position.x
	_report(dz > 15.0 and climbed > 0.8 and Mountain.on_road(pc.global_position, 0.5) and pc.global_position.y > Mountain.height_at(pc.global_position.x, pc.global_position.z) - 0.5,
			"a player car drives up the pass road (%.1f m west, %.1f m higher, on the road)" % [dz, climbed])
	pc.test_input = Vector3(0, 0, 1)
	await get_tree().create_timer(1.0).timeout
	pc.test_drive = false
	pc.host_exit(p)
	p.queue_free()
	veh.host_remove(pc)


func _check_grass(world: Node3D) -> void:
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var skip: Array[Rect2] = GrassCover.field_rects(get_tree(), world)
	var open: int = GrassCover.tuft_points(space, Vector2i(11, -6), skip).size()  # the open strip east of the village (zone 3 took the old field)
	var full: int = int(GrassCover.CHUNK * GrassCover.CHUNK * GrassCover.DENSITY * 0.8)
	_report(open >= full, "open green land is covered with grass (%d tufts in a 10 m chunk, want >= %d)" % [open, full])
	var on_road: int = 0
	for key: Vector2i in [Vector2i(0, -1), Vector2i(0, 0), Vector2i(-2, -1), Vector2i(-2, 0)]:
		for p: Vector3 in GrassCover.tuft_points(space, key, skip):
			if absf(p.z) < 5.8:
				on_road += 1
	_report(on_road == 0, "no grass on Main Road or its pavements (%d tufts there)" % on_road)
	var field: int = GrassCover.tuft_points(space, Vector2i(-13, -5), skip).size()  # inside the soil field (-120, -40)
	_report(field == 0, "no grass on the soil fields (%d)" % field)
	var store: Building = world.find_child("Store", true, false) as Building
	var inside: int = 0
	if store:
		var c: Vector3 = store.global_position
		var mid := Vector2(c.x, c.z) + Vector2(store.global_basis.z.x, store.global_basis.z.z) * -4.0
		for p: Vector3 in GrassCover.tuft_points(space, Vector2i(floori(mid.x / 10.0), floori(mid.y / 10.0)), skip):
			if Vector2(p.x, p.z).distance_to(mid) < 2.0:
				inside += 1
	_report(store != null and inside == 0, "no grass inside a building (%d)" % inside)
	var dup: int = 0
	for r: Rect2 in skip.slice(0, 3):
		var k := Vector2i(floori(r.get_center().x / 10.0), floori(r.get_center().y / 10.0))
		for p: Vector3 in GrassCover.tuft_points(space, k, skip):
			if r.has_point(Vector2(p.x, p.z)):
				dup += 1
	_report(skip.size() > 0 and dup == 0, "the hand-placed grass fields keep their own grass (%d bare rects, %d doubles)" % [skip.size(), dup])


## Point 95: map-wide - no cover-grass tuft on anything paved. Every flat mesh at ground height (roads, pavements,
## kerbs, yards, plazas: AABB < 0.5 m high, top between -0.05 and 0.35 m) is a no-grass zone; every 10 m chunk that
## touches one is filled exactly like GrassCover does and no tuft may land inside such a zone.
func _check_grass_roads(world: Node3D) -> void:
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var skip: Array[Rect2] = GrassCover.field_rects(get_tree(), world)
	var zones: Array = []  # [Rect2, path]
	for m: Node in world.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var anc: Node = mi
		var bad: bool = false
		while anc != null and anc != world:
			if anc is GroundArea or anc is GrassField or anc is GrassCover or anc is Pedestrian or anc is Car or anc is PlayerCar:
				bad = true
				break
			anc = anc.get_parent()
		if bad:
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		if box.size.y > 0.5 or box.end.y > 0.35 or box.end.y < -0.05 or box.size.x < 0.4 or box.size.z < 0.4 				or box.size.x * box.size.z < 0.5:
			continue
		zones.append([Rect2(box.position.x + 0.15, box.position.z + 0.15, box.size.x - 0.3, box.size.z - 0.3), str(mi.get_path())])
	var keys: Dictionary = {}
	for z: Array in zones:
		var r: Rect2 = z[0]
		for kx: int in range(floori(r.position.x / GrassCover.CHUNK), floori(r.end.x / GrassCover.CHUNK) + 1):
			for kz: int in range(floori(r.position.y / GrassCover.CHUNK), floori(r.end.y / GrassCover.CHUNK) + 1):
				keys[Vector2i(kx, kz)] = true
	var hits: Dictionary = {}  # path -> count
	var total: int = 0
	for key: Vector2i in keys:
		var area := Rect2(key.x * GrassCover.CHUNK, key.y * GrassCover.CHUNK, GrassCover.CHUNK, GrassCover.CHUNK)
		var near: Array = []
		for z: Array in zones:
			if (z[0] as Rect2).intersects(area):
				near.append(z)
		for p: Vector3 in GrassCover.tuft_points(space, key, skip):
			for z: Array in near:
				if (z[0] as Rect2).has_point(Vector2(p.x, p.z)):
					total += 1
					var path: String = z[1]
					hits[path] = int(hits.get(path, 0)) + 1
					break
	var worst: Array = hits.keys()
	worst.sort_custom(func(a: String, b: String) -> bool: return int(hits[a]) > int(hits[b]))
	var lines: PackedStringArray = []
	for k: String in worst.slice(0, 8):
		lines.append("%s (%d)" % [k.trim_prefix("/root/World/"), hits[k]])
	# Hand-placed GrassFields (verges, gardens) draw their own grass over their whole rect: none may lie on a road
	# tile or a paved area.
	var paved_rects: Array = []
	for n: Node in world.find_children("*", "RoadTile", true, false):
		var t: Vector3 = (n as Node3D).global_position
		paved_rects.append([Rect2(t.x - RoadTile.HALF, t.z - RoadTile.HALF, RoadTile.TILE, RoadTile.TILE), str(n.name)])
	for n: Node in world.find_children("*", "PavedArea", true, false):
		var pa := n as PavedArea
		if pa.surface == "soil":
			continue
		var bx: AABB = pa.global_transform * AABB(Vector3(-pa.size.x / 2.0, 0, -pa.size.y / 2.0), Vector3(pa.size.x, 0.1, pa.size.y))
		paved_rects.append([Rect2(bx.position.x, bx.position.z, bx.size.x, bx.size.z), str(n.name)])
	var over: PackedStringArray = []
	for n: Node in world.find_children("*", "GrassField", true, false):
		var g := n as GrassField
		if not g.is_visible_in_tree():
			continue
		var c: Vector3 = g.global_position
		var gr := Rect2(c.x - g.size.x / 2.0, c.z - g.size.y / 2.0, g.size.x, g.size.y).grow(-0.3)
		for pr: Array in paved_rects:
			if gr.intersects(pr[0]) and _grass_shows_in(g, gr.intersection(pr[0] as Rect2)):
				over.append("%s @(%.0f, %.0f) on %s" % [g.get_path().get_concatenated_names().trim_prefix("root/World/"), c.x, c.z, pr[1]])
				break
	_report(over.is_empty(), "no hand-placed grass field lies on a road or paved area (%d: %s)" % [over.size(), ", ".join(over.slice(0, 10))])
	_report(total == 0, "no grass on any road / pavement / paved yard on the whole map (%d paved surfaces, %d chunks; %d tufts on: %s)" % [
			zones.size(), keys.size(), total, ", ".join(lines)])


## Does GrassField `g` draw grass anywhere in world rect `r` (5x5 sample points, minus its holes)?
func _grass_shows_in(g: GrassField, r: Rect2) -> bool:
	var c: Vector3 = g.global_position
	for i: int in 5:
		for j: int in 5:
			var p := Vector2(r.position.x + r.size.x * (i + 0.5) / 5.0, r.position.y + r.size.y * (j + 0.5) / 5.0)
			var local := p - Vector2(c.x, c.z)
			var in_hole: bool = false
			for h: Rect2 in g.holes:
				if h.has_point(local):
					in_hole = true
					break
			if not in_hole:
				return true
	return false


func _check_ground(world: Node3D) -> void:
	# Every 2 m over the whole village: a ray from 30 m up must hit world ground (layer 1) between y -1 and 30.
	var space := world.get_world_3d().direct_space_state
	var holes: Array[Vector2] = []
	var x: float = PLAY_RECT.position.x + 1.0
	while x < PLAY_RECT.end.x:
		var z: float = PLAY_RECT.position.y + 1.0
		while z < PLAY_RECT.end.y:
			if not (x < SEA_X and z > QUAY_Z):
				var q := PhysicsRayQueryParameters3D.create(Vector3(x, 30, z), Vector3(x, -1.0, z), 1)
				if space.intersect_ray(q).is_empty():
					holes.append(Vector2(x, z))
			z += 2.0
		x += 4.0 if holes.size() > 50 else 2.0
	_report(holes.is_empty(), "no holes in the ground over the whole village (%d holes%s)" % [holes.size(),
			(", first at %s" % holes[0]) if not holes.is_empty() else ""])
	# No invisible walls inside the village: a sweep across the open north (old edge z -61) and west (old edge x -72.5).
	var blocked: Array[String] = []
	for line: Array in [[Vector3(-40, 1, -40), Vector3(-40, 1, -125)], [Vector3(-60, 1, -100), Vector3(-185, 1, -100)],
			[Vector3(10, 1, 70), Vector3(10, 1, 100)], [Vector3(-60, 1, 80), Vector3(60, 1, 80)]]:
		var q := PhysicsRayQueryParameters3D.create(line[0], line[1], 1)
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty() and hit["collider"] is StaticBody3D and (hit["collider"] as Node).name == "Bounds":
			blocked.append("%s at %s" % [(hit["collider"] as Node).name, (hit["position"] as Vector3).snapped(Vector3.ONE)])
	_report(blocked.is_empty(), "no invisible walls across the open land (%s)" % ", ".join(blocked))
	# Safety net: a player and a car that fall below the world come back where they stood.
	var p: Player = WALKER.instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Faller"
	world.get_node("Players").add_child(p)
	p.global_position = Vector3(-40, 0.3, -90)
	p.auto_target = p.global_position
	await get_tree().create_timer(1.2).timeout
	var stood: Vector3 = p.safe_pos
	p.global_position = Vector3(-40, -30, -90)
	for i: int in 5:
		await get_tree().physics_frame
	_report(stood != Vector3.INF and p.global_position.y > -1.0 and p.global_position.distance_to(stood) < 2.0 and not p.dead,
			"fell out of the world: back on the last safe spot, alive (%s)" % p.global_position.snapped(Vector3.ONE * 0.1))
	p.queue_free()
	var veh: Vehicles = Vehicles.current
	if veh:
		var car: PlayerCar = veh.host_spawn("sedan", 0, Vector3(-40, 0.2, -80), 0.0)
		await get_tree().create_timer(1.2).timeout
		car.global_position = Vector3(-40, -30, -80)
		for i: int in 5:
			await get_tree().physics_frame
		_report(car.global_position.y > -1.0 and car.global_position.distance_to(Vector3(-40, 0, -80)) < 3.0,
				"a car that falls through comes back too (%s)" % car.global_position.snapped(Vector3.ONE * 0.1))
		veh.host_remove(car)
	GameState.player_data.erase("Faller")
	await get_tree().physics_frame
	# Blueprint zone 9: snowy border mountains all round; you walk freely up to their foot, then it's too steep.
	var peaks: Array[float] = []
	for at: Vector2 in [Vector2(230, 0), Vector2(-300, -60), Vector2(0, 470), Vector2(-150, -540), Vector2(40, -300)]:
		peaks.append(BorderRange.height_at(at.x, at.y))
	_report(peaks.min() > 35.0, "border mountains round the map (heights %s)" % str(peaks.map(func(h: float) -> int: return roundi(h))))
	var w: Player = WALKER.instantiate()
	w.auto_walk = true
	w.name = "1"
	w.player_name = "Climber"
	world.get_node("Players").add_child(w)
	w.global_position = Vector3(130, 0.3, 40)
	w.auto_target = Vector3(200, 0, 40)
	await get_tree().create_timer(9.0).timeout
	_report(w.global_position.x > 141.0 and w.global_position.x < 160.0 and w.global_position.y < 8.0,
			"walking east: past the old edge onto the mountain foot, then stopped by the slope (%s)" % w.global_position.snapped(Vector3.ONE * 0.1))
	w.queue_free()
	GameState.player_data.erase("Climber")
	await get_tree().physics_frame
