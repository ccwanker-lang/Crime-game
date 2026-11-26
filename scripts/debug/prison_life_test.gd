class_name PrisonLifeTest
extends RefCounted
## Self-test check "prison_life" (SelfTest._check_prison_life), city life point 5a: inmates in the yard by day,
## in the canteen at meal times, locked up at night; guards on A's posts + the patrol, relieved at a shift change.


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	var pl: PrisonLife = PrisonLife.current
	var dn := tree.get_first_node_in_group(&"day_night") as DayNight
	if pl == null or pl.prison() == null or dn == null:
		report.call(false, "no PrisonLife / Prison / DayNight")
		return
	var old_h: float = dn.hours
	report.call(PrisonLife.phase(7.5) == "meal" and PrisonLife.phase(10.0) == "yard" and PrisonLife.phase(12.5) == "meal"
			and PrisonLife.phase(22.0) == "cells" and PrisonLife.phase(3.0) == "cells" and PrisonLife.phase(19.0) == "yard",
			"schedule: breakfast 7, yard, lunch 12, yard, dinner 17:30, yard, lock-up 20-07")
	var prison: Node3D = pl.prison()
	var canteen := Rect2(Vector2(18.0, -30.0), Vector2(16.0, 18.0))

	PrisonLife.force = true
	PrisonLife.speed = 5.0
	dn.set_hours(10.0)
	var st: Dictionary = {}
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 40000:
		await tree.create_timer(0.5).timeout
		st = pl.status()
		if st["inmates"] >= 10 and st["posted"] >= 5 and st["sitting"] >= 2:
			break
	report.call(st["inmates"] >= 10 and st["sitting"] >= 2, "10:00 yard time: %d inmates out, %d sitting (benches / weights)"
			% [st["inmates"], st["sitting"]])
	report.call(st["guards"] == 5 and st["posted"] == 5, "guards at the 4 posts + the patrol (%d / %d)" % [st["posted"], st["guards"]])
	var roles_ok: bool = true
	for k: String in pl.people:
		var npc := pl.people[k].get("npc") as CityWalker if is_instance_valid(pl.people[k].get("npc")) else null
		if npc:
			var want: int = CityWalker.Role.INMATE if k.begins_with("inmate") else CityWalker.Role.GUARD
			roles_ok = roles_ok and npc.role == want and not npc.can_be_customer() \
					and npc.uniform_colors().has("Pants")
	report.call(roles_ok, "inmates wear orange, guards a uniform; nobody of them deals")

	# Lunch: into the canteen, onto the benches.
	dn.set_hours(12.2)
	var in_canteen: int = 0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 60000:
		await tree.create_timer(0.5).timeout
		in_canteen = 0
		for k: String in pl.people:
			var npc := pl.people[k].get("npc") as CityWalker if is_instance_valid(pl.people[k].get("npc")) else null
			if npc and k.begins_with("inmate") and npc._sitting:
				var lp: Vector3 = prison.to_local(npc.global_position)
				if canteen.has_point(Vector2(lp.x, lp.z)):
					in_canteen += 1
		if in_canteen >= 10:
			break
	report.call(in_canteen >= 10, "12:00 lunch: %d inmates sit in the canteen (%.1f s)" % [in_canteen,
			(Time.get_ticks_msec() - t0) / 1000.0])

	# Shift change at 15:00.
	var before: int = pl.reliefs
	var old_guard: Variant = pl.people.get("guard_2", {}).get("npc")
	dn.set_hours(15.05)
	t0 = Time.get_ticks_msec()
	var new_posted: bool = false
	while Time.get_ticks_msec() - t0 < 60000:
		await tree.create_timer(0.5).timeout
		var r: Dictionary = pl.people.get("guard_2", {})
		if pl.reliefs >= before + 5 and r.get("state") == "post" and r.get("npc") != old_guard and not is_instance_valid(old_guard):
			new_posted = true
			break
	report.call(new_posted, "15:00 shift change: %d reliefs, the yard post has a new guard and the old one left (%.1f s)"
			% [pl.reliefs - before, (Time.get_ticks_msec() - t0) / 1000.0])

	# Lock-up.
	dn.set_hours(20.5)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 60000:
		await tree.create_timer(0.5).timeout
		st = pl.status()
		if st["inmates"] == 0:
			break
	report.call(st["inmates"] == 0 and st["guards"] >= 4, "20:00 lock-up: the yard is empty (%d inmates), guards stay (%d)"
			% [st["inmates"], st["guards"]])
	PrisonLife.force = false
	PrisonLife.speed = 1.0
	pl._clear()
	dn.set_hours(old_h)
