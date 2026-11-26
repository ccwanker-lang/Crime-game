class_name BuildersTest
extends RefCounted
## Self-test check "builders" (SelfTest._check_builders), city life point 4: SiteCrew staffs every BuilderSpot of
## A's building sites in work hours (hard hats are local visuals: the role is what is checked), the hammerers hold
## the hammer, the bricks carrier delivers, the top-floor builder stands on the top slab, the office one chats; after
## work they all leave; at night nobody comes.


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	var sites: Array[Node] = tree.get_nodes_in_group(&"building_sites")
	var sc: SiteCrew = SiteCrew.current
	if sites.is_empty() or sc == null:
		report.call(false, "no building sites (%d) or no SiteCrew" % sites.size())
		return
	var spots: int = 0
	var tasks: Dictionary = {}
	for s: Node in sites:
		for sp: Dictionary in SiteCrew.staffed_spots(s as Node3D):
			spots += 1
			tasks[sp["task"]] = true
	report.call(spots >= 6 and tasks.has("bricks") and tasks.has("upper") and tasks.has("office"),
			"%d sites with %d builder spots (%s)" % [sites.size(), spots, ", ".join(tasks.keys())])
	report.call(SiteCrew.work_time(10.0) and not SiteCrew.work_time(6.0) and not SiteCrew.work_time(18.0),
			"work hours 07:00-17:00")

	SiteCrew.force = true
	SiteCrew.always_open = true
	SiteCrew.speed = 4.0
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 40000 and sc.working().size() < spots:
		await tree.create_timer(0.5).timeout
	var working: Array[CityWalker] = sc.working()
	var hammer: int = 0
	var upper_ok: bool = false
	var office_talk: bool = false
	var roles_ok: bool = true
	for k: int in 24:
		for key: String in sc.crew:
			var r: Dictionary = sc.crew[key]
			var npc := r.get("npc") as CityWalker if is_instance_valid(r.get("npc")) else null
			if npc == null or r.get("state") != "work":
				continue
			roles_ok = roles_ok and npc.role == CityWalker.Role.BUILDER and not npc.can_be_customer()
			if npc.carry == CityWalker.CARRY_HAMMER:
				hammer += 1
			if r["task"] == "upper" and absf(npc.global_position.y - (r["pos"] as Vector3).y) < 0.5 \
					and npc.global_position.y > 3.0:
				upper_ok = true
			if r["task"] == "office" and npc.anim_state == Pedestrian.Anim.TALK:
				office_talk = true
		await tree.create_timer(0.5).timeout
	report.call(working.size() == spots and roles_ok, "a builder at every spot (%d of %d at work after %.1f s)"
			% [working.size(), spots, (Time.get_ticks_msec() - t0) / 1000.0])
	report.call(hammer > 0 and upper_ok and office_talk, "hammering (%d samples), one on the top floor (%s), the office one "
			% [hammer, upper_ok] + "chats (%s)" % office_talk)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000 and sc.deliveries == 0:
		await tree.create_timer(0.5).timeout
	report.call(sc.deliveries > 0, "the bricks carrier takes bricks to the mixer (%d deliveries)" % sc.deliveries)

	# End of the day: everybody leaves, nobody comes back.
	SiteCrew.always_open = false
	var dn := tree.get_first_node_in_group(&"day_night") as DayNight
	var old_h: float = dn.hours if dn else 12.0
	if dn:
		dn.set_hours(18.0)
	t0 = Time.get_ticks_msec()
	var left: int = 99
	while Time.get_ticks_msec() - t0 < 60000:
		await tree.create_timer(0.5).timeout
		left = 0
		for n: Node in tree.get_nodes_in_group(&"npc"):
			if n.has_meta(&"builder") and not n.is_queued_for_deletion():
				left += 1
		if left == 0:
			break
	report.call(left == 0 and sc.working().is_empty(), "after 17:00 they all leave the site (%d left after %.1f s)"
			% [left, (Time.get_ticks_msec() - t0) / 1000.0])
	await tree.create_timer(3.0).timeout
	var back: int = 0
	for n: Node in tree.get_nodes_in_group(&"npc"):
		if n.has_meta(&"builder") and not n.is_queued_for_deletion():
			back += 1
	report.call(back == 0, "nobody comes back at night (%d)" % back)
	SiteCrew.force = false
	SiteCrew.speed = 1.0
	if dn:
		dn.set_hours(old_h)
