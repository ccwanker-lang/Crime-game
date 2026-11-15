class_name MissionsTest
extends RefCounted
## Self-test check "missions" (SelfTest._check_missions), NOTES parts 19 + 20 (Marco's dialogue starts mission 1): the two test missions from data/missions/
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

	# --- Mission 1 through Marco's dialogue (part 20): talk -> start, go to, deliver, report back ---
	Missions.talkers_on = true
	await tree.create_timer(0.8).timeout
	var marco: Pedestrian = Missions.mission_npc(&"marco")
	report.call(marco != null and marco.get_node_or_null("TalkBox") is MissionTalkBox and not marco.ambient,
			"Marco (a talker from data/dialogue/npcs/) stands by the park with a talk box")
	if marco == null:
		return
	boss.teleport(marco.global_position + Vector3(8, 0.3, 0))
	await tree.create_timer(0.3).timeout
	report.call(Missions.host_talk(boss, &"marco") == "too far", "too far away to talk")
	boss.teleport(marco.global_position + Vector3(1.5, 0.3, 0))
	await tree.create_timer(0.3).timeout
	var said: String = Missions.host_talk(boss, &"marco")
	var md: DialogueData = Missions.last_talk.get("dialogue") as DialogueData
	var entry: DialogueNode = md.entry() if md else null
	var texts: Array = entry.visible_choices().map(func(c: DialogueChoice) -> String: return c.text) if entry else []
	report.call(said == "dialogue" and entry != null and entry.id == &"hello" and texts.has("Got anything for me?")
			and not texts.has("Any bigger work?"), "E on Marco: dialogue '%s' with choices %s" % [entry.id if entry else &"", texts])
	var layer := CanvasLayer.new()
	world.add_child(layer)
	var box := DialogueBox.new()
	box.player = boss
	layer.add_child(box)
	box.start(&"marco", "Marco", md, PackedStringArray(), false)
	box.choose(0)  # Got anything for me?
	await tree.process_frame
	var page1: StringName = box.node.id if box.node else &""
	box.choose(1)  # What's in it for me?
	await tree.process_frame
	var page2: StringName = box.node.id if box.node else &""
	box.choose(0)  # Deal. -> START_MISSION
	await tree.process_frame
	report.call(page1 == &"work1" and page2 == &"pay1" and str(Missions.state()["active"]) == "first_contact"
			and Missions.state()["members"] == ["Boss"] and box.visible and box.node.id == &"go1",
			"choices lead through the pages; 'Deal.' starts '%s' for the crew" % m1.title)
	box.choose(0)  # Bye
	await tree.process_frame
	report.call(not box.visible, "the last page closes the box")
	Missions.host_talk(boss, &"marco")
	md = Missions.last_talk.get("dialogue") as DialogueData
	report.call(md != null and md.entry().id == &"busy", "during a mission Marco says: '%s'" % (md.entry().text if md else ""))
	# A late joiner.
	var late: Player = _player(world, "2", "Late", park + Vector3(4, 0.3, 4))
	await tree.create_timer(0.8).timeout
	report.call("Late" in (Missions.state()["late"] as Array) and "Late" in (Missions.view.get("late", []) as Array),
			"a player who joins now is 'late': gets the progress")
	var gas: Node3D = world.find_child("GasStation", true, false) as Node3D
	boss.teleport(gas.global_position + Vector3(0, 0.3, 0))
	await tree.create_timer(0.8).timeout
	var dex: Pedestrian = Missions.mission_npc(&"dex")
	report.call(int(Missions.state()["step"]) == 1 and dex != null, "go to the gas station -> step 2, Dex waits")
	if dex:
		boss.teleport(dex.global_position + Vector3(0, 0.3, 1.5))
		await tree.create_timer(0.3).timeout
		report.call(Missions.host_talk(boss, &"dex") == "missing" and not (Missions.last_talk.get("lines", []) as PackedStringArray).is_empty(),
				"without the bags Dex says no ('%s')" % ", ".join(Missions.last_talk.get("lines", [])))
		GameState.give("Boss", 0, [{"id": "weed_bag", "count": 3}])
		var res: String = Missions.host_talk(boss, &"dex")
		await tree.create_timer(0.6).timeout
		report.call(res == "delivered" and GameState.count_item("Boss", "weed_bag") == 1 and int(Missions.state()["step"]) == 2
				and Missions.mission_npc(&"dex") == null and Missions.mission_npc(&"marco") != null,
				"deliver 2 Bags of Weed -> step 3: '%s' (Dex leaves, Marco stays)" % Missions.view.get("text"))
	var late_cash: int = int(GameState.get_or_create_player_data("Late")["cash"])
	report.call((Missions.view.get("target") as Vector3).distance_to(marco.global_position) < 1.0, "the waypoint points at Marco")
	boss.teleport(marco.global_position + Vector3(1.5, 0.3, 0))
	await tree.create_timer(0.3).timeout
	report.call(Missions.host_talk(boss, &"marco") == "dialogue" and Missions.last_talk.get("mission") == "first_contact"
			and not Missions.is_done(&"first_contact"), "report back: the step's own dialogue opens (not done yet)")
	box.start(&"marco", "Marco", Missions.talk_dialogue(&"marco", "first_contact", 2, PackedStringArray()), PackedStringArray(), true)
	box.choose(0)  # Easy money. -> FINISH_STEP
	await tree.physics_frame
	var data: Dictionary = GameState.get_or_create_player_data("Boss")
	report.call(Missions.is_done(&"first_contact") and str(Missions.state()["active"]) == "" and box.visible and box.node.id == &"pay",
			"the answer finishes the step -> mission done")
	box.close()
	report.call(int(data["cash"]) == cash0 + m1.reward_cash and GameState.count_item("Boss", "baggie") == 10
			and Progression.host_xp() == xp0 + m1.reward_xp,
			"reward for the member: €%d, 10 baggies, +%d crew XP" % [int(data["cash"]) - cash0, Progression.host_xp() - xp0])
	report.call(int(GameState.get_or_create_player_data("Late")["cash"]) == late_cash and GameState.count_item("Late", "baggie") == 0,
			"the late joiner gets no reward")
	Missions.host_talk(boss, &"marco")
	md = Missions.last_talk.get("dialogue") as DialogueData
	texts = md.entry().visible_choices().map(func(c: DialogueChoice) -> String: return c.text) if md else []
	report.call(texts.has("Any bigger work?") and not texts.has("Got anything for me?"), "now Marco offers the next job: %s" % [texts])
	layer.queue_free()
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
	report.call(str(Missions.state()["active"]) == "" and not Missions.is_done(&"first_contact") and Missions.mission_npc(&"marco") != null,
			"give up: the mission stops, Marco stays ('%s')" % Missions.last_banner)
	Missions.host_start(&"first_contact", boss)
	var phone_layer := CanvasLayer.new()
	world.add_child(phone_layer)
	var phone := Phone.new()
	phone.player = boss
	phone_layer.add_child(phone)
	phone.open()
	await tree.process_frame
	await tree.process_frame
	var app: Button = phone._content.get_node_or_null("MissionsApp") as Button
	report.call(app != null and app.text.contains("running"), "phone: a Missions app on the home screen (%s)" % (app.text if app else "none"))
	if app:
		app.pressed.emit()
		await tree.process_frame
		var log_texts: Array = phone._content.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
		report.call(phone._screen == "missions" and log_texts.has(m1.title) and log_texts.any(func(s: String) -> bool: return s.begins_with("> ")),
				"the mission log shows the steps")
	phone._show("map")
	await tree.process_frame
	await tree.process_frame
	var map: PhoneMap = phone._map
	report.call(map != null and map.get_children().any(func(c: Node) -> bool: return c is MissionMapPin), "the phone map has the mission pin")
	phone_layer.queue_free()
	Missions.host_end(false, "test over")
	Missions.talkers_on = false
	var mn: Node = Missions.mission_npc(&"marco")
	if mn:
		mn.queue_free()
	GameState.world.erase("missions")
	Missions._sync_all()
	boss.queue_free()
	await tree.physics_frame
