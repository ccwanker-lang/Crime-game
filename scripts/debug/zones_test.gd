class_name ZonesTest
extends RefCounted
## Self-test check "zones" (SelfTest._check_zones), NOTES part 18: Fort Halden (guards, gate warning, intruder shot,
## alarm + reinforcements), slum residents + cheap customers, city office workers + dear customers, the bunker lab
## (for sale, keypad locked, teleport in/out, placing inside, never raided).


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
		var towers: int = guards.filter(func(s: Soldier) -> bool: return s.global_position.y > 5.0).size()
		report.call(guards.size() == Zones.guard_posts().size() and guards.size() >= 6 and towers >= 2,
				"Fort Halden: %d guards at their posts (%d up on the watchtowers)" % [guards.size(), towers])
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
	p.teleport(Vector3(20, 0.3, 200))
	await tree.create_timer(1.5).timeout
	var city: Array = Zones.residents(&"city")
	var ccust: Pedestrian = _customer(&"city")
	report.call(city.size() >= 6 and ccust != null and Zones.customer_price(ccust, 100) == 150,
			"the city: %d office workers by day, customers pay 150%% (%s)" % [city.size(), ccust.name if ccust else "no customer"])
	if dn:
		dn.set_hours(22.0)
		await tree.create_timer(1.0).timeout
		report.call(Zones.residents(&"city").filter(func(n: Pedestrian) -> bool: return n.wants <= 0).is_empty(),
				"at night the office workers go home")
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

	# --- The bunker ---
	var lab: BunkerLab = BunkerLab.current
	if lab == null or lab.property == null:
		report.call(false, "no bunker (Mountain.bunker_spot)")
	else:
		var prop: BunkerProperty = lab.property
		var listed: bool = prop.for_sale and prop.price == BunkerLab.PRICE and prop.is_in_group(&"properties")
		var props: Dictionary = GameState.world.get_or_add("properties", {})
		props.erase(BunkerLab.PROPERTY_ID)
		p.teleport(lab.outside_pad.global_position + lab.spot.basis * Vector3(0, -1.2, -1.5))
		await tree.create_timer(0.3).timeout
		var why: String = lab.host_use_player(p, true)
		report.call(listed and why.begins_with("Access denied") and not lab.inside(p.global_position),
				"bunker for sale (€%s, rank %d), the keypad stays shut ('%s')" % [Property.money(prop.price),
				Progression.config.property_rank.get(&"bunker", 0), why])
		prop.host_set_owned("Recruit")
		why = lab.host_use_player(p, true)
		await tree.create_timer(0.4).timeout
		var floor_ok: bool = absf(p.global_position.y - lab.hall.origin.y) < 0.6
		report.call(why == "" and lab.inside(p.global_position) and floor_ok and Zones.zone_at(p.global_position) == &"bunker",
				"owned: the keypad takes you down into the hall (y %.1f, %.0f m under the portal)" % [p.global_position.y,
				lab.spot.origin.y - lab.hall.origin.y])
		var item: ItemData = ItemDB.get_item(&"cook_station")
		var spot: Vector3 = lab.hall * Vector3(6, 0.0, 2)
		var place_why: String = Placement.check(world.get_world_3d(), tree, item, spot, 0.0)
		report.call(place_why == "" and Placement.property_at(tree, spot) == prop, "you can place stations in the hall ('%s')" % place_why)
		var st: Node = world.call("host_place", "cook_station", spot, 0.0)
		await tree.physics_frame
		report.call(not Raids.lab_properties().has(prop) and Raids._production_in(prop) > 0, "a lab in the bunker is never raided")
		if st:
			world.call("host_remove_placed", (st as Station).station_id.trim_prefix("placed/"))
		why = lab.host_use_player(p, false)
		await tree.create_timer(0.4).timeout
		report.call(why == "" and not lab.inside(p.global_position) and p.global_position.distance_to(lab.spot.origin) < 6.0,
				"the lift keypad takes you back up to the portal")
		props.erase(BunkerLab.PROPERTY_ID)
		prop._update_label()
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
