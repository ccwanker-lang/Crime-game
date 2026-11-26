class_name ArmyDayTest
extends RefCounted
## Self-test check "army_day" (SelfTest._check_army_day), city life point 5b: Fort Halden's day rhythm (ArmyLife):
## lunch in Barracks1, the hangar / helipad crews off duty at night, reliefs at the 14:00 shift change.


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	var al: ArmyLife = ArmyLife.current
	var dn := tree.get_first_node_in_group(&"day_night") as DayNight
	var p: Player = null
	var own: bool = false
	for n: Node in tree.get_nodes_in_group(&"players"):
		p = n as Player
		break
	if p == null and world.get_node_or_null("Players"):
		p = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
		p.auto_walk = true
		p.name = "1"
		p.player_name = "Recruit"
		world.get_node("Players").add_child(p)
		own = true
		await tree.physics_frame
	if al == null or dn == null or p == null or world.get_node_or_null("ArmyBase") == null:
		report.call(false, "no ArmyLife / DayNight / player / ArmyBase")
		return
	var old_h: float = dn.hours
	var old_pos: Vector3 = p.global_position
	report.call(ArmyLife.in_window(ArmyLife.NIGHT, 23.0) and ArmyLife.in_window(ArmyLife.NIGHT, 3.0)
			and not ArmyLife.in_window(ArmyLife.NIGHT, 12.0) and ArmyLife.in_window(ArmyLife.LUNCH, 12.5),
			"army hours: lunch 12-13, chatty crews off 22-06, shifts at 06 / 14 / 22")
	dn.set_hours(11.5)
	p.teleport(Zones.ARMY_GATE + Vector3(-40, 0.3, 0))
	Zones.army_on = true
	await tree.create_timer(2.5).timeout
	var posts: int = Zones.guard_posts().size()
	var chat_posts: int = Zones.guard_posts().filter(func(d: Dictionary) -> bool: return ArmyLife.kind_of(d) == "chat").size()

	# Lunch.
	dn.set_hours(12.1)
	var st: Dictionary = {}
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 90000:
		await tree.create_timer(0.5).timeout
		st = al.status()
		if st["lunch"] >= chat_posts and st["sitting"] >= 2:
			break
	report.call(st["lunch"] >= mini(4, chat_posts) and st["sitting"] >= 2, "12:00 lunch: %d of %d hangar / helipad soldiers in "
			% [st["lunch"], chat_posts] + "the barracks, %d on the stools (%.0f s)" % [st["sitting"], (Time.get_ticks_msec() - t0) / 1000.0])
	dn.set_hours(13.1)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 90000:
		await tree.create_timer(0.5).timeout
		st = al.status()
		if st["errands"] == 0:
			break
	report.call(st["errands"] == 0, "13:00 back to the posts (%d still away)" % st["errands"])

	# Shift change.
	var before: int = al.reliefs
	dn.set_hours(13.95)
	await tree.create_timer(1.5).timeout
	dn.set_hours(14.05)
	t0 = Time.get_ticks_msec()
	var manned: int = 0
	while Time.get_ticks_msec() - t0 < 60000:
		await tree.create_timer(0.5).timeout
		manned = 0
		for g: Variant in Zones._guards.values():
			if g is Soldier and is_instance_valid(g) and (g as Soldier).errand == "" \
					and (g as Soldier).global_position.distance_to((g as Soldier).home) < 2.0:
				manned += 1
		if al.reliefs > before and manned >= posts - 4:
			break
	report.call(al.reliefs >= before + 4, "14:00 shift change: %d reliefs walk out of Barracks3 to the gate / flag / towers"
			% (al.reliefs - before))
	report.call(manned >= posts - 4, "after the change the posts are manned again (%d of %d at their post)" % [manned, posts])

	# Night: the chatty crews go to bed; the rest stays.
	dn.set_hours(22.3)
	t0 = Time.get_ticks_msec()
	var chat_left: int = 99
	while Time.get_ticks_msec() - t0 < 90000:
		await tree.create_timer(0.5).timeout
		chat_left = Zones.guards().filter(func(s: Soldier) -> bool: return s.chatty).size()
		if chat_left == 0:
			break
	var on_watch: int = Zones.guards().size()
	report.call(chat_left == 0 and on_watch >= posts - chat_posts - 1, "22:00 the hangar / helipad crews turn in (%d left), "
			% chat_left + "%d soldiers stay on watch" % on_watch)
	dn.set_hours(6.3)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000:
		await tree.create_timer(0.5).timeout
		chat_left = Zones.guards().filter(func(s: Soldier) -> bool: return s.chatty).size()
		if chat_left >= chat_posts:
			break
	report.call(chat_left >= chat_posts, "06:00 they are back on duty (%d of %d)" % [chat_left, chat_posts])

	Zones.army_on = false
	for s: Soldier in Zones.guards() + Zones.reinforcements():
		s.queue_free()
	for n: Node in tree.get_nodes_in_group(&"soldiers"):
		n.queue_free()
	Zones._guards.clear()
	p.teleport(old_pos)
	if own:
		p.queue_free()
	dn.set_hours(old_h)
	await tree.create_timer(0.5).timeout
