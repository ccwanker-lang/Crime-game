class_name ZonesTest
extends RefCounted
## Self-test check "zones" (SelfTest._check_zones), NOTES part 18: Fort Halden (guards, gate warning, intruder shot,
## alarm + reinforcements), slum residents + cheap customers, city office workers + dear customers, the bunker
## (A's complex: for sale, door locked until owned, placing inside, never raided).


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	var dn := tree.get_first_node_in_group(&"day_night") as DayNight
	var old_hours: float = dn.hours if dn else 12.0
	if dn:
		dn.set_hours(12.0)
	report.call(Zones.zone_at(Vector3(-70, 0, -390)) == &"army" and Zones.zone_at(Vector3(-40, 0, -80)) == &"slums"
			and Zones.zone_at(Vector3(20, 0, 250)) == &"city" and Zones.zone_at(Vector3(0, 0, 0)) == &"",
			"zones: base, slums, city, village")
	# A's point 85: the airfield is part of the base (runway, jet hangars, every watchtower and fence post inside).
	var army_base: Node = t.get_tree().current_scene.find_child("ArmyBase", true, false) if t.get_tree().current_scene else null
	var outside: PackedStringArray = []
	if army_base:
		for n: Node in army_base.get_children():
			var nm: String = str(n.name)
			if n is Node3D and (nm.begins_with("Runway") or nm.begins_with("JetHangar") or nm.begins_with("Watchtower")
					or nm.begins_with("BaseFence")) and not Zones.near_army_base((n as Node3D).global_position, 1.0):
				outside.append(nm)
	report.call(army_base != null and outside.is_empty() and Zones.in_army_base(Vector3(200, 0, -425))
			and not Zones.in_army_base(Vector3(245, 0, -400)),
			"the airfield counts as the base too (runway at x 200 inside, x 245 outside%s)"
			% ("; outside: %s" % ", ".join(outside.slice(0, 6)) if not outside.is_empty() else ""))
	var p: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Recruit"
	world.get_node("Players").add_child(p)
	for i: int in 5:
		await tree.physics_frame

	# --- Fort Halden ---
	if world.get_node_or_null("ArmyBase") == null:
		report.call(false, "no ArmyBase in the map")
	else:
		p.teleport(Zones.ARMY_GATE + Vector3(-40, 0.3, 0))
		Zones.army_on = true
		await tree.create_timer(2.0).timeout
		var guards: Array = Zones.guards()
		var towers: Array = guards.filter(func(s: Soldier) -> bool: return s.global_position.y > 5.0)
		var snipers: int = towers.filter(func(s: Soldier) -> bool: return s.gun == &"sniper" and s.profile == Soldier.MARKSMAN_PROFILE).size()
		var patrols: Array = guards.filter(func(s: Soldier) -> bool: return not s.route.is_empty())
		var chatty: int = guards.filter(func(s: Soldier) -> bool: return s.chatty).size()
		report.call(guards.size() == Zones.guard_posts().size() and guards.size() >= 18 and towers.size() >= 4 and snipers == towers.size()
				and patrols.size() == 4 and chatty >= 4,
				"Fort Halden: %d soldiers (%d marksmen with sniper rifles on the towers, %d on patrol, %d at the hangars/helipads)"
				% [guards.size(), snipers, patrols.size(), chatty])
		var start: Array = patrols.map(func(s: Soldier) -> Vector3: return s.global_position)
		await tree.create_timer(4.0).timeout
		var moved: int = 0
		for i: int in patrols.size():
			if (patrols[i] as Soldier).global_position.distance_to(start[i]) > 3.0:
				moved += 1
		var blocked: Array = []
		for post: Dictionary in Zones.guard_posts():
			var rt: Array = post.get("route", [])
			for i: int in rt.size():
				var a: Vector3 = rt[i]
				var b: Vector3 = rt[(i + 1) % rt.size()]
				var q := PhysicsRayQueryParameters3D.create(a + Vector3.UP * 0.6, b + Vector3.UP * 0.6, 1 | 2)
				if not world.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
					blocked.append("%s->%s" % [a, b])
		report.call(moved == patrols.size() and blocked.is_empty(), "the patrols walk their rounds (%d/%d moving, blocked legs: %s)"
				% [moved, patrols.size(), blocked])
		p.teleport(Zones.ARMY_GATE + Vector3(-9, 0.3, 0))
		await tree.create_timer(1.2).timeout
		report.call(Zones._warned.has(p) and not Zones.is_army_hostile(p) and p.health == 100,
				"at the boom: a warning, nobody shoots yet")
		var hp0: int = p.health
		p.teleport(Zones.ARMY_GATE + Vector3(4, 0.3, 0))
		var hit: bool = false
		for i: int in 75:
			await tree.create_timer(0.2).timeout
			if p.health < hp0 or p.dead:
				hit = true
				break
		report.call(Zones.is_army_hostile(p) and Zones.alarm_on() and Zones.reinforcements().size() == Zones.REINFORCEMENTS and hit,
				"through the gate: shot at (health %d), ALARM, %d reinforcements out of the barracks" % [p.health, Zones.reinforcements().size()])
		# Back out; the alarm ends, the reinforcements go home and are gone.
		p.teleport(Vector3(0, 0.3, 0))
		await tree.create_timer(0.5).timeout
		Zones._hostile.clear()
		Zones._alarm_until = -1.0
		for s: Soldier in Zones.reinforcements():
			s.target = null
			s.global_position = s.home
			s.net_pos = s.home
		await tree.create_timer(1.5).timeout
		report.call(Zones.reinforcements().is_empty(), "after the alarm the reinforcements return and leave")
		# A pass for missions.
		Zones.allow_army(p, 30.0)
		p.teleport(Zones.ARMY_GATE + Vector3(4, 0.3, 0))
		await tree.create_timer(1.0).timeout
		report.call(not Zones.is_army_hostile(p) and not Zones.alarm_on(), "with a pass (missions) you may go in")
		# A's bug report 2026-11-25: a soldier on patrol must not take a pass holder inside the fence for an intruder.
		var spotted: int = 0
		for s: Node in tree.get_nodes_in_group(&"soldiers"):
			var sol := s as Soldier
			var was: Vector3 = sol.global_position
			sol.global_position = p.global_position + Vector3(0, 0, 6)
			if sol.spot_intruder() == p:
				spotted += 1
			sol.global_position = was
			break
		report.call(spotted == 0 and Zones.has_pass(p), "a soldier next to a pass holder inside the base doesn't see an intruder")
		Zones._passes.clear()
		Zones.army_on = false
		for s: Soldier in Zones.guards() + Zones.reinforcements():
			s.queue_free()
		Zones._guards.clear()
		p.teleport(Vector3(0, 0.3, 0))
		await tree.create_timer(0.3).timeout
		if p.dead:
			p.queue_free()
			await tree.physics_frame
			p = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
			p.auto_walk = true
			p.name = "1"
			p.player_name = "Recruit"
			world.get_node("Players").add_child(p)
			await tree.physics_frame

	# --- Slums + city ---
	Zones.npcs_on = true
	p.teleport(Vector3(-40, 0.3, -70))
	await tree.create_timer(1.5).timeout
	var slum: Array = Zones.residents(&"slums")
	var barrels: int = world.find_children("FireBarrel*", "", true, false).size()
	report.call(slum.size() >= barrels * 2 and barrels > 0, "the slums: %d residents round %d fire barrels" % [slum.size(), barrels])
	var cust: Pedestrian = _customer(&"slums")
	report.call(cust != null and cust.wants > 0 and Zones.customer_price(cust, 100) == 60 and cust.is_in_group(&"customer"),
			"a slum resident becomes a customer at 60%% prices (%s, €%d)" % [cust.name if cust else "none", cust.offer if cust else 0])
	var cars0: int = world.get_node("Traffic").get_children().filter(func(n: Node) -> bool: return n is Car).size()
	p.teleport(Vector3(20, 0.3, 200))
	await tree.create_timer(1.5).timeout
	var city: Array = Zones.residents(&"city")
	var kinds: Dictionary = {}
	for r: Dictionary in Zones._residents.values():
		if r.get("zone") == &"city" and is_instance_valid(r.get("npc")):
			kinds[r.get("kind", "stand")] = int(kinds.get(r.get("kind", "stand"), 0)) + 1
	var walkers: Array = Zones._residents.values().filter(func(r: Dictionary) -> bool: return r.get("kind") == "walk" and is_instance_valid(r.get("npc")))
	var w0: Array = walkers.map(func(r: Dictionary) -> Vector3: return (r["npc"] as Node3D).global_position)
	await tree.create_timer(4.0).timeout
	var walking: int = 0
	for i: int in walkers.size():
		if is_instance_valid(walkers[i]["npc"]) and (walkers[i]["npc"] as Node3D).global_position.distance_to(w0[i]) > 2.0:
			walking += 1
	var sitting: int = Zones.residents(&"city").filter(func(n: Pedestrian) -> bool: return n._sitting).size()
	var cars1: int = world.get_node("Traffic").get_children().filter(func(n: Node) -> bool: return n is Car).size()
	report.call(int(kinds.get("walk", 0)) == _walkers_at(Zones._hours()) and walking >= walkers.size() * 0.7 and sitting >= 4
			and int(kinds.get("stand", 0)) >= 20 and cars1 >= cars0 + CityLife.EXTRA_CARS,
			"city life: %s, %d of %d walkers on their way, %d sitting, +%d cars" % [kinds, walking, walkers.size(), sitting, cars1 - cars0])
	var ccust: Pedestrian = _customer(&"city")
	report.call(city.size() >= 6 and ccust != null and Zones.customer_price(ccust, 100) == 150,
			"the city: %d office workers by day, customers pay 150%% (%s)" % [city.size(), ccust.name if ccust else "no customer"])
	# A's NpcStreamer puts far NPCs to sleep: Zones must leave a sleeping resident where it is (no walk / sit jumps).
	var sleepers: Array = Zones._residents.values().filter(func(r: Dictionary) -> bool:
		return is_instance_valid(r.get("npc")) and not (r["npc"] as Pedestrian)._sitting and (r["npc"] as Pedestrian).wants <= 0)
	var moved: int = 0
	var slept: int = 0
	var s0: Array = []
	for r: Dictionary in sleepers:
		(r["npc"] as Pedestrian).set_lod(Pedestrian.Lod.ASLEEP)
		s0.append((r["npc"] as Node3D).global_position)
	await tree.create_timer(4.0).timeout
	for i: int in sleepers.size():
		var n: Pedestrian = sleepers[i]["npc"] as Pedestrian
		if not is_instance_valid(n):
			continue
		if n.lod == Pedestrian.Lod.ASLEEP:
			slept += 1
		if n.global_position.distance_to(s0[i]) > 0.5 or n._sitting:
			moved += 1
		n.set_lod(Pedestrian.Lod.FULL)
	report.call(slept >= 5 and moved == 0, "sleeping residents (NpcStreamer) stay put: %d asleep, %d moved" % [slept, moved])
	if dn:
		dn.set_hours(22.0)
		await tree.create_timer(1.0).timeout
		var night_kinds: Dictionary = {}
		for r: Dictionary in Zones._residents.values():
			if r.get("zone") == &"city" and is_instance_valid(r.get("npc")) and not (r["npc"] as Node).is_queued_for_deletion() \
					and (r["npc"] as Pedestrian).wants <= 0 and not (r["npc"] is CityWalker and (r["npc"] as CityWalker).shopping):
				var kind: String = "office" if str(r.get("key", "")).begins_with("Tower") else str(r.get("kind", "stand"))
				night_kinds[kind] = int(night_kinds.get(kind, 0)) + 1
		report.call(not night_kinds.has("office") and int(night_kinds.get("walk", 0)) == _walkers_at(Zones._hours()) and not night_kinds.has("sit"),
				"at night the offices + benches empty, %d walkers stay (%s)" % [_walkers_at(Zones._hours()), night_kinds])
		dn.set_hours(12.0)
	p.teleport(Vector3(20, 0.3, 330))
	await tree.create_timer(1.0).timeout
	report.call(Zones.residents(&"slums").filter(func(n: Pedestrian) -> bool: return n.wants <= 0).is_empty(),
			"far away: the residents are gone (only a waiting customer stays)")
	Zones.npcs_on = false
	for r: Dictionary in Zones._residents.values():
		if is_instance_valid(r.get("npc")):
			(r["npc"] as Node).queue_free()
	Zones._residents.clear()

	# --- The bunker (A's BunkerComplex; here: for sale, the door locked until the crew owns it, no raids) ---
	var prop: BunkerProperty = Zones.bunker
	var door: BunkerDoor = Zones.bunker_door()
	if prop == null or door == null:
		report.call(false, "no bunker property / door (Mountain/Bunker)")
	else:
		var root: Node3D = prop.get_parent() as Node3D
		var props: Dictionary = GameState.world.get_or_add("properties", {})
		props.erase(&"bunker")
		Zones.bunker_lock_forced = true
		await tree.create_timer(0.7).timeout
		var listed: bool = prop.for_sale and prop.price == Zones.BUNKER_PRICE and prop.is_in_group(&"properties")
		door.interact()
		await tree.create_timer(0.6).timeout
		report.call(listed and door.locked and not door.is_open and door.get_interaction_prompt().contains("locked"),
				"bunker for sale (€%s, rank %d), the blast door stays locked" % [Property.money(prop.price),
				Progression.config.property_rank.get(&"bunker", 0)])
		prop.host_set_owned("Recruit")
		await tree.create_timer(0.7).timeout
		door.interact()
		await tree.create_timer(0.6).timeout
		report.call(not door.locked and door.is_open, "owned by the crew: the door unlocks and opens")
		var spot: Vector3 = (root.get_node("LabSpot1") as Node3D).global_position
		report.call(Zones.zone_at(spot + Vector3.UP) == &"bunker", "the lab hall counts as zone 'bunker'")
		var item: ItemData = ItemDB.get_item(&"cook_station")
		var place_why: String = Placement.check(world.get_world_3d(), tree, item, spot, 0.0)
		report.call(place_why == "" and Placement.property_at(tree, spot) == prop, "you can place stations in the lab hall ('%s')" % place_why)
		var st: Node = world.call("host_place", "cook_station", spot, 0.0)
		await tree.physics_frame
		report.call(not Raids.lab_properties().has(prop) and Raids._production_in(prop) > 0, "a lab in the bunker is never raided")
		if st:
			world.call("host_remove_placed", (st as Station).station_id.trim_prefix("placed/"))
		props.erase(&"bunker")
		prop._update_label()
		await tree.create_timer(0.7).timeout
		report.call(door.locked and not door.is_open, "sold / not owned again: locked and shut")
		Zones.bunker_lock_forced = false
		door.host_set_locked(false)
	if dn:
		dn.set_hours(old_hours)
	p.queue_free()
	await tree.physics_frame


## The zone's waiting customer (the zone loop may have made one already), else a new one.
static func _customer(zone: StringName) -> Pedestrian:
	for n: Pedestrian in Zones.residents(zone):
		if n.wants > 0:
			return n
	return Zones.make_zone_customer(zone)


## City walkers (plain + CityWalker roles, point 3) whose hours cover `h`.
static func _walkers_at(h: float) -> int:
	var n: int = 0
	for sp: Dictionary in Zones.city_spots():
		if sp.get("kind") == "walk" and CityLife.in_hours(sp.get("hours", Vector2(0, 24)), h):
			n += 1
	return n
