class_name DayRhythmTest
extends RefCounted
## Self-test check "day_rhythm" (SelfTest._check_day_rhythm), Roadmap 88 (session B): the village crowd by the clock -
## blocks, walking home at the end of a block, stepping out of the door at the start of one (never in view),
## home deliveries, a dead pedestrian's slot comes back later.


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	var dn := tree.get_first_node_in_group(&"day_night") as DayNight
	var old_hours: float = dn.hours if dn else 12.0
	if dn == null:
		report.call(false, "day rhythm: no DayNight")
		return
	dn.set_hours(10.0)
	await t.call("_wait_for_navmesh", world)
	var p: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Rhythm"
	world.get_node("Players").add_child(p)
	p.teleport(Vector3(0, 0.3, -4.6))
	for i: int in 5:
		await tree.physics_frame

	var rhythm := DayRhythm.new()
	rhythm.name = "DayRhythm"
	rhythm.outside_busiest = 10
	world.add_child(rhythm)
	for i: int in 30:
		await tree.physics_frame
		if not rhythm.people.is_empty():
			break
	await tree.physics_frame
	var cfg: DayRhythmConfig = rhythm.config
	report.call(cfg != null and rhythm.homes.size() >= 15 and rhythm.people.size() == 33
			and rhythm.count_block("morning") == 10 and rhythm.count_block("night") == 3,
			"day rhythm: %d people in %d homes (morning %d, afternoon %d, evening %d, night %d)" % [rhythm.people.size(),
			rhythm.homes.size(), rhythm.count_block("morning"), rhythm.count_block("afternoon"),
			rhythm.count_block("evening"), rhythm.count_block("night")])
	var live := func() -> Array:
		return world.get_node("NPCs").get_children().filter(func(n: Node) -> bool:
			return n.has_meta(DayRhythm.META) and not n.is_queued_for_deletion())
	var st: Dictionary = rhythm.status()
	report.call(int(st["out"]) == 10 and (live.call() as Array).size() == 10
			and (live.call() as Array).all(func(n: Node) -> bool: return rhythm.record_of(n)["block"] == 0),
			"10:00 (morning block): the 10 morning people are out, the other 23 inside (%s)" % st)

	# End of the morning: they walk to their front doors (put close by so the test is quick) and go in.
	var morning: Array = live.call()
	for n: Node in morning:
		var npc := n as Pedestrian
		var home: Dictionary = rhythm.home_of(rhythm.record_of(npc))
		npc.global_position = (home["door"] as Vector3) + (home["out"] as Vector3) * 5.0 + Vector3.UP * 0.1
		npc.net_pos = npc.global_position
	p.teleport(Vector3(-150, 0.3, -380))  # far away: nothing is "seen", nothing sleeps (no streamer in the self-test)
	await tree.physics_frame
	dn.set_hours(12.5)
	rhythm._tick(false)
	var homeward: int = morning.filter(func(n: Variant) -> bool:
		return is_instance_valid(n) and (n as Pedestrian).home_call != Vector3.INF).size()
	report.call(homeward == morning.size(), "12:30: every morning person sets off home (%d of %d)" % [homeward, morning.size()])
	var gone: int = 0
	for i: int in 90:  # (one may be sitting on a bench: up to 25 s)
		await tree.create_timer(0.5).timeout
		rhythm._tick(false)
		gone = morning.filter(func(n: Variant) -> bool: return not is_instance_valid(n) or (n as Node).is_queued_for_deletion()).size()
		if gone == morning.size():
			break
	var afternoon: Array = (live.call() as Array).filter(func(n: Node) -> bool: return rhythm.record_of(n)["block"] == 1)
	report.call(gone == morning.size() and afternoon.size() == 10,
			"they reach their doors and go in (%d of %d); the afternoon people stepped out of theirs (%d)"
			% [gone, morning.size(), afternoon.size()])
	var at_door: int = 0
	for n: Node in afternoon:
		var npc := n as Pedestrian
		var rr: Dictionary = rhythm.record_of(npc)
		if (rr.get("spawned_at", Vector3.INF) as Vector3).distance_to(rhythm.home_of(rr)["door"]) < 0.5:
			at_door += 1
	report.call(at_door == 10, "the afternoon people came out of their own front doors (%d of 10)" % at_door)

	# Never popping out in view: a player right in front of the door, looking at it -> wait; looking away -> out.
	for n: Node in afternoon:
		rhythm._go_in(rhythm.record_of(n))
	var r: Dictionary = rhythm.people.filter(func(x: Dictionary) -> bool: return int(x["block"]) == 1)[0]
	var home: Dictionary = rhythm.home_of(r)
	var door: Vector3 = home["door"]
	var out: Vector3 = home["out"]
	p.teleport(door + out * 12.0 + Vector3.UP * 0.3)
	p.rotation.y = atan2(out.x, out.z)  # -Z (forward) towards the door
	await tree.physics_frame
	for x: Dictionary in rhythm.people:
		if x != r and int(x["state"]) == DayRhythm.State.INSIDE:
			x["back"] = 1.0e12  # only this one may come out
	rhythm._tick(false)
	var held: bool = r["npc"] == null and int(r["state"]) == DayRhythm.State.INSIDE
	p.rotation.y = atan2(-out.x, -out.z)  # back to the door
	await tree.physics_frame
	rhythm._tick(false)
	report.call(held and is_instance_valid(r["npc"]),
			"nobody steps out of a door a player is looking at 12 m away (held: %s); looking away -> out (%s)"
			% [held, is_instance_valid(r["npc"])])

	# Home delivery: someone at home steps out, deals, goes back in.
	for x: Dictionary in rhythm.people:
		if int(x["state"]) == DayRhythm.State.INSIDE:
			x["back"] = 0.0
	p.teleport(Vector3(0, 0.3, -4.6))
	p.rotation.y = 0.0
	await tree.physics_frame
	var cust: Pedestrian = rhythm.home_customer()
	if cust:
		world.call("make_customer", cust)
	var rec: Dictionary = rhythm.record_of(cust)
	report.call(cust != null and not cust.ambient and cust.wants > 0 and int(rec.get("state", -1)) == DayRhythm.State.DEAL,
			"home delivery: %s steps out of their door as a customer (wants %d)" % [cust.name if cust else "nobody",
			cust.wants if cust else 0])
	var back_in: bool = false
	if cust:
		await tree.create_timer(1.5).timeout
		cust.wants = 0  # the deal is done
		for i: int in 40:
			await tree.create_timer(0.5).timeout
			rhythm._tick(false)
			if int(rec["state"]) == DayRhythm.State.INSIDE:
				back_in = true
				break
	if not back_in and is_instance_valid(cust):
		print("[DayRhythmTest] customer: state %d pos %s door %s call %s moving %s reached %s flee %s wants %d" % [rec["state"],
				cust.global_position, rhythm.home_of(rec)["door"], cust.home_call, cust._moving, cust.home_reached,
				cust.is_fleeing(), cust.wants])
	report.call(back_in, "after the deal the home customer goes back inside")

	# A dead pedestrian: no World respawn; its slot comes out of the door again after respawn_time.
	var victim: Pedestrian = null
	for n: Node in live.call():
		if (n as Pedestrian).ambient and not (n as Pedestrian).dead:
			victim = n as Pedestrian
			break
	var vrec: Dictionary = rhythm.record_of(victim)
	var peds_before: int = world.get_node("NPCs").get_children().filter(func(n: Node) -> bool:
		return n is Pedestrian and not n.has_meta(DayRhythm.META)).size()
	if victim:
		victim.host_damage(500)
	await tree.physics_frame
	rhythm._tick(false)
	report.call(victim != null and int(vrec["state"]) == DayRhythm.State.INSIDE and vrec["npc"] == null
			and float(vrec["back"]) > rhythm._now() + cfg.respawn_time - 5.0,
			"a dead pedestrian's slot stays inside for %d s, then comes out of the door again" % int(cfg.respawn_time))

	# Clean up.
	for n: Node in live.call():
		n.queue_free()
	rhythm.queue_free()
	p.queue_free()
	await tree.create_timer(0.5).timeout
	var peds_after: int = world.get_node("NPCs").get_children().filter(func(n: Node) -> bool:
		return n is Pedestrian and not n.has_meta(DayRhythm.META) and not n.is_queued_for_deletion()).size()
	report.call(peds_after == peds_before, "no ordinary World respawn for them (%d -> %d other pedestrians)" % [peds_before, peds_after])
	dn.set_hours(old_hours)
