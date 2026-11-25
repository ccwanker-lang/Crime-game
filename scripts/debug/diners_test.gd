class_name DinersTest
extends RefCounted
## Self-test check "diners" (SelfTest._check_diners), city life point 2: DinerLife finds the seats (bakery chairs)
## and counter spots (snack bar), guests walk in through the door and sit, food appears on the table, they leave
## again and the seat frees up; a gunshot ends the visit; the busy hours per type.


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	var dl: DinerLife = DinerLife.current
	for i: int in 120:
		if dl and not dl.places.is_empty():
			break
		await tree.physics_frame
		dl = DinerLife.current
	if dl == null or dl.places.is_empty():
		report.call(false, "no DinerLife places")
		return
	var bakery: Dictionary = {}
	var snack: Dictionary = {}
	for pl: Dictionary in dl.places:
		if pl["type"] == "bakery":
			bakery = pl
		elif pl["type"] == "snack_bar":
			snack = pl
	report.call(not bakery.is_empty() and (bakery["seats"] as Array).size() == 2 and bakery["door"] != null
			and not snack.is_empty() and (snack["stands"] as Array).size() >= 2,
			"places: the Bakery's 2 chairs at its table, %d spots at the Snack Bar counter, doors found"
			% ((snack.get("stands", []) as Array).size()))
	var hours: Array = [["bar", 21.0, 1.0], ["bar", 1.0, 0.7], ["bar", 11.0, 0.0], ["restaurant", 19.0, 1.0],
			["restaurant", 16.0, 0.2], ["bakery", 22.0, 0.0], ["cafe", 12.0, 0.9]]
	var wrong: PackedStringArray = []
	for hcase: Array in hours:
		if not is_equal_approx(DinerLife.busy(hcase[0], hcase[1]), hcase[2]):
			wrong.append("%s %.0f h = %.1f" % [hcase[0], hcase[1], DinerLife.busy(hcase[0], hcase[1])])
	report.call(wrong.is_empty(), "busy hours: bars full at night, restaurants at dinner, the bakery closed at 22 h%s"
			% ("" if wrong.is_empty() else ": " + ", ".join(wrong)))

	# Guests (20x faster, every place open).
	DinerLife.force = true
	DinerLife.always_open = true
	DinerLife.speed = 20.0
	var bi: int = dl.places.find(bakery)
	var sat: int = 0
	var dish: bool = false
	var talk: int = 0
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 40000:
		await tree.create_timer(0.25).timeout
		sat = 0
		for s: int in 2:
			var npc := dl.taken.get("%d:%d" % [bi, s]) as Pedestrian
			if npc and is_instance_valid(npc) and npc._sitting and npc.anim_state == Pedestrian.Anim.SIT \
					and npc.global_position.distance_to((bakery["seats"][s] as Dictionary)["pos"]) < 0.4:
				sat += 1
		for k: String in dl.dishes:
			if k.begins_with("%d:" % bi):
				dish = true
		for key: String in dl.taken:
			var st := dl.taken[key] as Pedestrian
			if ":s" in key and is_instance_valid(st) and st.anim_state == Pedestrian.Anim.TALK:
				talk += 1
		if sat == 2 and dish and talk > 0:
			break
	report.call(sat == 2 and dish, ("guests walk in through the Bakery door and sit at the table (%d of 2), food on the "
			+ "table (%s) - after %.1f s at 20x") % [sat, dish, (Time.get_ticks_msec() - t0) / 1000.0])
	report.call(talk > 0, "guests stand at the Snack Bar counter and chat (talk animation seen %d times)" % talk)

	# A shot inside: the sitters run, their seats and tables clear.
	var first := dl.taken.get("%d:0" % bi) as Pedestrian
	if first and is_instance_valid(first):
		for n: Node in tree.get_nodes_in_group(&"npc"):
			if n.has_meta(&"diner"):
				(n as Pedestrian).hear_gunshot(first.global_position + Vector3(1, 0, 1))
		await tree.create_timer(1.0).timeout
		var cleared: bool = not dl.dishes.has("%d:0" % bi)
		var ran: bool = not is_instance_valid(first) or not first._sitting
		report.call(cleared and ran, "a gunshot: the guest jumps up and runs, the table is cleared (%s, %s)" % [ran, cleared])

	# Closing time: nobody new comes, the place empties.
	DinerLife.always_open = false
	DinerLife.force = false
	var empty: bool = false
	var stuck: PackedStringArray = []
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 45000:
		await tree.create_timer(0.5).timeout
		var left: int = 0
		stuck.clear()
		for n: Node in tree.get_nodes_in_group(&"npc"):
			if n.has_meta(&"diner") and is_instance_valid(n) and not (n as Pedestrian).dead:
				left += 1
				var pd := n as Pedestrian
				stuck.append("%s at %s moving %s flee %s sit %s anim %d" % [pd.name, pd.global_position.snapped(Vector3.ONE * 0.1),
						pd._moving, pd.is_fleeing(), pd._sitting, pd.anim_state])
		if left == 0 and dl.taken.is_empty():
			empty = true
			break
	report.call(empty and dl.served > 0, "when nobody is near (or it closes) the guests finish, walk out and go: none "
			+ "left after %.1f s (%d guests, %d served)%s" % [(Time.get_ticks_msec() - t0) / 1000.0, dl.guests, dl.served,
			"" if empty else " - still there: " + "; ".join(stuck) + " taken " + str(dl.taken.keys())])
	DinerLife.speed = 1.0
