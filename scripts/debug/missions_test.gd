class_name MissionsTest
extends RefCounted
## Self-test check "missions" (SelfTest._check_missions), NOTES part 19: the two test missions from data/missions/
## played through on the host (talk, go to, deliver, kill, survive), a late joiner (progress yes, reward no),
## giving up, the phone app + map pin hooks and the talk box on mission NPCs.


static func _player(world: Node3D, node_name: String, who: String, at: Vector3) -> Player:
	var p: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.auto_walk = true
	p.name = node_name
	p.player_name = who
	world.get_node("Players").add_child(p)
	p.teleport(at)
	return p


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	GameState.world.erase("missions")
	var m1: MissionData = Missions.get_mission(&"first_contact")
	var m2: MissionData = Missions.get_mission(&"pier_pressure")
	report.call(m1 != null and m2 != null and m1.objectives.size() == 3 and m2.objectives.size() == 3,
			"missions are data: %d .tres in data/missions/ (%s)" % [Missions.all.size(), ", ".join(Missions.all.keys())])
	if m1 == null or m2 == null:
		return
	var park: Vector3 = world.find_child("ParkSmokeSpot", true, false).global_position
	var boss: Player = _player(world, "1", "Boss", park + Vector3(6, 0.3, 0))
	boss.admin_god = true
	for i: int in 5:
		await tree.physics_frame
	GameState.get_or_create_player_data("Boss")["inventory"] = []
	var cash0: int = int(GameState.get_or_create_player_data("Boss")["cash"])
	var xp0: int = Progression.host_xp()
	report.call(Missions.why_not(&"pier_pressure").begins_with("First") and Missions.available() == [&"first_contact"],
			"only the first mission is open ('%s')" % Missions.why_not(&"pier_pressure"))

	# --- Mission 1: talk, go to, deliver ---
	report.call(Missions.host_start(&"first_contact", boss) == "" and Missions.state()["members"] == ["Boss"],
			"start '%s': the crew in the game are its members" % m1.title)
	await tree.create_timer(0.6).timeout
	var marco: Pedestrian = Missions.mission_npc(&"marco")
	report.call(marco != null and marco.get_node_or_null("TalkBox") is MissionTalkBox and Missions.view.get("text") == "Meet Marco by the park"
			and (Missions.view.get("target") as Vector3).distance_to(marco.global_position) < 0.5,
			"Marco waits (talk box, E), HUD view: '%s'" % Missions.view.get("text"))
	boss.teleport(marco.global_position + Vector3(8, 0.3, 0))
	await tree.create_timer(0.3).timeout
	report.call(Missions.host_talk(boss, &"marco") == "too far", "too far away to talk")
	boss.teleport(marco.global_position + Vector3(1.5, 0.3, 0))
	await tree.create_timer(0.3).timeout
	var said: String = Missions.host_talk(boss, &"marco")
	report.call(said == "talked" and int(Missions.state()["step"]) == 1, "talk to Marco -> step 2: '%s'" % Missions.view.get("text"))
	# A late joiner.
	var late: Player = _player(world, "2", "Late", park + Vector3(4, 0.3, 4))
	await tree.create_timer(0.8).timeout
	report.call("Late" in (Missions.state()["late"] as Array) and "Late" in (Missions.view.get("late", []) as Array),
			"a player who joins now is 'late': gets the progress")
	await tree.create_timer(0.5).timeout
	report.call(Missions.mission_npc(&"marco") == null, "Marco leaves after his step")
	var gas: Node3D = world.find_child("GasStation", true, false) as Node3D
	boss.teleport(gas.global_position + Vector3(0, 0.3, 0))
	await tree.create_timer(0.8).timeout
	var dex: Pedestrian = Missions.mission_npc(&"dex")
	report.call(int(Missions.state()["step"]) == 2 and dex != null, "go to the gas station -> step 3, Dex waits")
	if dex:
		boss.teleport(dex.global_position + Vector3(0, 0.3, 1.5))
		await tree.create_timer(0.3).timeout
		report.call(Missions.host_talk(boss, &"dex") == "missing", "without the bags Dex says no")
		GameState.give("Boss", 0, [{"id": "weed_bag", "count": 3}])
		var late_cash: int = int(GameState.get_or_create_player_data("Late")["cash"])
		var res: String = Missions.host_talk(boss, &"dex")
		await tree.physics_frame
		var data: Dictionary = GameState.get_or_create_player_data("Boss")
		report.call(res == "delivered" and GameState.count_item("Boss", "weed_bag") == 1 and Missions.is_done(&"first_contact")
				and str(Missions.state()["active"]) == "", "deliver 2 Bags of Weed -> mission done")
		report.call(int(data["cash"]) == cash0 + m1.reward_cash and GameState.count_item("Boss", "baggie") == 10
				and Progression.host_xp() == xp0 + m1.reward_xp,
				"reward for the member: €%d, 10 baggies, +%d crew XP" % [int(data["cash"]) - cash0, Progression.host_xp() - xp0])
		report.call(int(GameState.get_or_create_player_data("Late")["cash"]) == late_cash and GameState.count_item("Late", "baggie") == 0,
				"the late joiner gets no reward")
	late.queue_free()
	await tree.physics_frame

	# --- Mission 2: go to, kill, survive ---
	report.call(Missions.available() == [&"pier_pressure"], "the next mission opens: '%s'" % m2.title)
	var pier: Vector3 = world.find_child("HarbourCrows", true, false).global_position
	boss.teleport(pier + Vector3(0, 0.3, -60))
	Missions.host_start(&"pier_pressure", boss)
	await tree.create_timer(0.6).timeout
	report.call(int(Missions.state()["step"]) == 0, "go to the pier (%d m away)" % roundi(boss.global_position.distance_to(pier)))
	boss.teleport(pier + Vector3(0, 0.3, -15))
	await tree.create_timer(0.6).timeout
	var foes: Array = Missions.enemies()
	report.call(int(Missions.state()["step"]) == 1 and foes.size() == 3 and foes.all(func(e: Node) -> bool: return e is Rival),
			"at the pier: 3 Crows to take out ('%s')" % Missions.view.get("text"))
	for e: Node in foes:
		(e as Rival).host_damage(1000, boss, boss.global_position)
	await tree.create_timer(0.8).timeout
	report.call(int(Missions.state()["step"]) == 2 and Missions.enemies().size() == 3, "all 3 down -> hold the pier, backup comes")
	Missions.state()["time"] = m2.objectives[2].seconds - 1.0
	var cash1: int = int(GameState.get_or_create_player_data("Boss")["cash"])
	await tree.create_timer(1.6).timeout
	report.call(Missions.is_done(&"pier_pressure") and int(GameState.get_or_create_player_data("Boss")["cash"]) == cash1 + m2.reward_cash,
			"survived -> done, reward €%d" % m2.reward_cash)
	for e: Node in Missions.enemies() + foes:
		if is_instance_valid(e):
			e.queue_free()

	# --- Giving up, the phone ---
	(Missions.state()["done"] as Array).clear()
	Missions.host_start(&"first_contact", boss)
	await tree.physics_frame
	Missions.request_abandon()
	await tree.physics_frame
	var gone: Pedestrian = Missions.mission_npc(&"marco")
	report.call(str(Missions.state()["active"]) == "" and not Missions.is_done(&"first_contact") and (gone == null or gone.is_queued_for_deletion()),
			"give up: the mission stops, its NPC goes ('%s')" % Missions.last_banner)
	Missions.host_start(&"first_contact", boss)
	var layer := CanvasLayer.new()
	world.add_child(layer)
	var phone := Phone.new()
	phone.player = boss
	layer.add_child(phone)
	phone.open()
	await tree.process_frame
	await tree.process_frame
	var app: Button = phone._content.get_node_or_null("MissionsApp") as Button
	report.call(app != null and app.text.contains("running"), "phone: a Missions app on the home screen (%s)" % (app.text if app else "none"))
	if app:
		app.pressed.emit()
		await tree.process_frame
		var texts: Array = phone._content.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
		report.call(phone._screen == "missions" and texts.has(m1.title) and texts.any(func(s: String) -> bool: return s.begins_with("> ")),
				"the mission log shows the steps")
	phone._show("map")
	await tree.process_frame
	await tree.process_frame
	var map: PhoneMap = phone._map
	report.call(map != null and map.get_children().any(func(c: Node) -> bool: return c is MissionMapPin), "the phone map has the mission pin")
	layer.queue_free()
	Missions.host_end(false, "test over")
	GameState.world.erase("missions")
	Missions._sync_all()
	boss.queue_free()
	await tree.physics_frame
