class_name RaidTest
extends RefCounted
## Self-test check "raids" (SelfTest._check_raids): Crow raids on labs + guards (Raids autoload, Staff role guard).


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	var p: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Boss"
	GameState.player_data.erase("Boss")
	world.get_node("Players").add_child(p)
	var sr: Property = world.find_child("StarterRoom", true, false).get_node("Property") as Property
	var b: Node3D = sr.building()
	p.global_position = Vector3(60.0, 0.3, -40.0)  # far away: nobody defends
	p.auto_target = p.global_position
	for i: int in 5:
		await tree.physics_frame
	GameState.get_or_create_player_data("Boss")["cash"] = 20000
	GameState.world.erase("staff")
	GameState.world.erase("raids")
	Staff.tick(0.01)
	if Staff._stations_in("starter_room", PackagingTable).is_empty():
		world.call("debug_weed_corner")
		await tree.physics_frame
	var cooker := world.call("host_place", "cook_station", b.to_global(Vector3(1.5, 0.15, -8.2)), b.global_rotation.y) as CookStation
	await tree.physics_frame
	report.call(Raids.lab_properties().has(sr), "the Starter Room with stations counts as a lab")

	# Warning, then the raid WARN_HOURS later (nobody there, no guards): lost.
	var lockers: Array = Staff._stations_in("starter_room", StorageLocker)
	for l: StorageLocker in lockers:
		l.state["items"] = []
	(lockers[0] as StorageLocker).state["items"] = [{"id": "meth_bag", "count": 10}, {"id": "weed_bag", "count": 6}, {"id": "soil", "count": 4}]
	Raids.announce("starter_room")
	var warned: bool = p.last_phone.size() > 0 and str(p.last_phone[0]) == Raids.CROWS
	Raids.tick(1.0, true)
	var waiting: bool = not (Raids._data()["pending"] as Dictionary).is_empty()
	Raids.tick(Raids.WARN_HOURS, true)
	await tree.physics_frame
	var left_meth: int = Staff._locker_count(lockers, "meth_bag")
	var taken: bool = not is_instance_valid(cooker) or cooker.is_queued_for_deletion()
	report.call(warned and waiting and left_meth == 5 and Staff._locker_count(lockers, "weed_bag") == 3
			and Staff._locker_count(lockers, "soil") == 4 and taken,
			"warning text, raid 2 h later: half the product stolen (meth %d, soil kept) + the cooking station taken" % left_meth)
	report.call(int(Raids._data()["losses"]) == 1 and str(p.last_phone[1]).contains("got into"), "lost raid texted: '%s'" % str(p.last_phone[1]))

	# Guards: each takes one raider down; enough guards = won.
	Progression.debug_set_rank(0)  # 2 raiders
	Staff.debug_hire("Boss", "guard", "starter_room")
	Staff.debug_hire("Boss", "guard", "starter_room")
	var guards: int = Raids._guards_in("starter_room").size()
	var xp0: int = Progression.host_xp()
	var res: String = Raids.start("starter_room")
	report.call(guards == 2 and res == "won" and Progression.host_xp() - xp0 == Raids.XP_WIN, "2 guards stop 2 raiders: %s, +%d XP" % [
			res, Progression.host_xp() - xp0])

	# Live raid: a crew player close by -> real Crows at the door; kill them = won.
	GameState.world.erase("staff")
	Progression.debug_set_rank(2)  # 3 raiders
	p.teleport(b.to_global(Vector3(0.0, 0.2, 8.0)))
	await tree.physics_frame
	await tree.physics_frame
	res = Raids.start("starter_room")
	var n: int = Raids.live_left()
	var near: bool = true
	for r: Rival in Raids.live.get("raiders", []):
		near = near and r.global_position.distance_to(b.global_position) < 15.0 and r.memory.has(p)
	report.call(res == "live" and n == 3 and near, "live raid: %d Crows at the door who know you (%s)" % [n, res])
	var wins0: int = int(Raids._data()["wins"])
	for r: Rival in Raids.live.get("raiders", []):
		r.host_damage(1000, p)
	for i: int in 10:
		await tree.process_frame
	report.call(Raids.live.is_empty() and int(Raids._data()["wins"]) == wins0 + 1, "killed them all: raid won")
	# Live raid that runs out of time: lost.
	res = Raids.start("starter_room")
	var raiders: Array = Raids.live.get("raiders", [])
	Raids.live["until"] = 0.0
	for i: int in 5:
		await tree.process_frame
	report.call(Raids.live.is_empty() and int(Raids._data()["losses"]) == 2, "Crows still standing when time runs out: raid lost")
	for r: Rival in raiders:
		if is_instance_valid(r):
			r.queue_free()
	GameState.world.erase("staff")
	GameState.world.erase("raids")
	Staff._broadcast()
	GameState.world.erase("progress")
	GameState.player_data.erase("Boss")
	p.queue_free()
	await tree.physics_frame
