class_name CityCrowdTest
extends RefCounted
## Self-test check "city_crowd" (SelfTest._check_city_crowd), city life point 3: CityWalker roles (shopper goes into a
## shop and comes out with bags, jogger runs, pram walks slowly, dog walker gets a real Dog) and the role hours that
## follow the day rhythm (point 88).


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	# Hours.
	var wrong: PackedStringArray = []
	for c: Array in [["Shopper", 13.0, true], ["Shopper", 7.0, false], ["Shopper", 23.0, false],
			["JoggerAm", 7.0, true], ["JoggerAm", 13.0, false], ["JoggerPm", 19.0, true], ["Pram", 11.0, true],
			["Pram", 21.0, false], ["DogWalker", 8.0, true], ["NightOwl", 23.5, true], ["NightOwl", 0.5, true],
			["NightOwl", 13.0, false]]:
		for g: Array in CityLife.role_groups():
			if g[0] == c[0] and CityLife.in_hours(g[3], c[1]) != c[2]:
				wrong.append("%s at %.1f h" % [c[0], c[1]])
	report.call(wrong.is_empty(), "role hours: shoppers while shops are open, joggers early + after work, prams by day, "
			+ "night owls late%s" % ("" if wrong.is_empty() else ": wrong " + ", ".join(wrong)))
	var spots: Array = Zones.city_spots()
	var roles: Dictionary = {}
	for sp: Dictionary in spots:
		if sp.has("role"):
			roles[sp["role"]] = int(roles.get(sp["role"], 0)) + 1
	report.call(roles.size() == 5, "city spots hold every role (%s)" % str(roles))

	# A shopper at the Bakery: in through the door, out with bags.
	var shop: Dictionary = {}
	for sh: Dictionary in CityWalker.shops():
		if sh["type"] == "bakery":
			shop = sh
	if shop.is_empty():
		report.call(false, "no bakery shop for the shopper")
		return
	CityWalker.visit_time = Vector2(1.5, 2.0)
	var front: Vector3 = shop["front"]
	var start: Vector3 = front + (shop["door"] as NetDoor).get_outward() * 3.0 if shop["door"] else front
	start.y = 0.3
	var sh_npc := Zones.add_resident(start, 0.0, &"city", -1, CityWalker.Role.SHOPPER) as CityWalker
	await tree.create_timer(0.5).timeout
	var r: Dictionary = {"node": -1}
	sh_npc._go_shopping(shop, r)
	var was_inside: bool = false
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25000:
		await tree.physics_frame
		if sh_npc.inside:
			was_inside = true
		if was_inside and not sh_npc.shopping:
			break
		if not sh_npc.shopping and not was_inside:
			print("[CityCrowd] gave up at %s (front %s)" % [sh_npc.global_position, front])
			break
	report.call(was_inside and sh_npc.carry > 0 and not sh_npc.inside and sh_npc.visible and sh_npc.shops_visited == 1,
			"a shopper walks to the Bakery, goes in (hidden), comes out with %d bag(s) (inside seen %s)" % [sh_npc.carry, was_inside])
	report.call(not sh_npc.can_be_customer() or sh_npc.carry > 0, "shopper state ok")
	CityWalker.visit_time = Vector2(20.0, 60.0)

	# Jogger / pram / dog walker on the city sidewalk graph.
	var nodes: Array[Vector3] = CityLife.graph()
	var n0: int = CityLife.nearest_node(nodes[0])
	var jog := Zones.add_resident(nodes[n0], 0.0, &"city", -1, CityWalker.Role.JOGGER) as CityWalker
	var pram := Zones.add_resident(nodes[n0] + Vector3(0.5, 0, 0.5), 0.0, &"city", -1, CityWalker.Role.PRAM) as CityWalker
	var dogw := Zones.add_resident(nodes[n0] + Vector3(-0.5, 0, 0.5), 0.0, &"city", -1, CityWalker.Role.DOG) as CityWalker
	await tree.create_timer(0.5).timeout
	var rj: Dictionary = {"node": n0}
	var rp: Dictionary = {"node": n0}
	var ran: bool = false
	var j_from: Vector3 = jog.global_position
	var p_from: Vector3 = pram.global_position
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000:
		jog.city_step(rj)
		pram.city_step(rp)
		if jog.anim_state == Pedestrian.Anim.RUN:
			ran = true
		await tree.create_timer(0.25).timeout
	var j_m: float = jog.global_position.distance_to(j_from)
	var p_m: float = pram.global_position.distance_to(p_from)
	report.call(ran and j_m > p_m + 2.0 and is_equal_approx(pram._move_speed(), CityWalker.PRAM_SPEED),
			"a jogger runs (%.1f m in 4 s), a pram walks slowly (%.1f m)" % [j_m, p_m])
	report.call(not jog.can_be_customer() and not pram.can_be_customer() and not dogw.can_be_customer(),
			"joggers, prams and dog walkers don't stop for deals")
	var dog := world.get_node_or_null("Dogs/Dog_%s" % dogw.name) as Dog
	report.call(dog != null and dog.owner_npc == dogw, "the dog walker has a real dog (World/Dogs/%s)" % ("Dog_" + dogw.name))
	for n: Node in [sh_npc, jog, pram, dogw]:
		if is_instance_valid(n):
			n.queue_free()
	await tree.create_timer(0.5).timeout
