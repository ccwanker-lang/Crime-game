class_name RangeTest
extends RefCounted
## Self-test check "range" (SelfTest._check_range): the shooting range (RangeClub / ShootingRange): it stands in
## the world, gunfire there is legal, a real shot from the firing line hits a target, drills (fee, pop-ups, points,
## bullseye), skill + less spread, loaner guns (lend, refused twice, back when leaving), the rank gate.


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	for i: int in 3:
		await tree.process_frame
	var r: ShootingRange = ShootingRange.current
	report.call(r != null and r.get_parent() == world and r.desk != null and r.targets.size() == ShootingRange.LANES,
			"the shooting range stands in the world (%s)" % (r.global_position if r else "none"))
	if r == null:
		return
	var spot: Vector3 = r.firing_spot(1)
	report.call(RangeClub.covers(spot + Vector3.UP * 1.6) and not RangeClub.covers(Vector3(0, 1.6, 0)),
			"gunfire on the range is legal, in town it is not")
	# The ground under the range: walkable at the firing line + the hut, nothing in the way of the targets.
	var space := world.get_world_3d().direct_space_state
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 3.0, spot + Vector3.DOWN * 3.0, 1))
	report.call(not down.is_empty() and absf((down["position"] as Vector3).y - spot.y) < 0.4,
			"the firing line has a floor (y %.2f)" % ((down["position"] as Vector3).y if not down.is_empty() else -99.0))
	var clear: int = 0
	for lane: int in ShootingRange.LANES:
		for i: int in ShootingRange.DISTANCES.size():
			var tg: RangeTarget = r.target(lane, i)
			var from: Vector3 = r.firing_spot(lane) + Vector3.UP * 1.55
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, tg.center() + (tg.center() - from).normalized() * 0.3, PlayerCombat.HIT_MASK))
			if not hit.is_empty() and hit["collider"] == tg:
				clear += 1
			elif lane == 0:
				print("[RangeTest] lane %d target %d: blocked by %s at %s (target %s)" % [lane, i,
						(hit["collider"] as Node).get_path() if not hit.is_empty() else "nothing", hit.get("position"), tg.center()])
	report.call(clear == ShootingRange.LANES * ShootingRange.DISTANCES.size(), "every target is in clear sight from its lane (%d/%d)" % [
			clear, ShootingRange.LANES * ShootingRange.DISTANCES.size()])

	var p: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Marksman"
	GameState.player_data.erase("Marksman")
	world.get_node("Players").add_child(p)
	p.global_position = r.desk.global_position + r.desk.global_basis.z * 1.3 + Vector3.UP * 0.2
	p.auto_target = p.global_position
	for i: int in 5:
		await tree.physics_frame
	var pd: Dictionary = GameState.get_or_create_player_data("Marksman")
	pd["inventory"] = []
	pd["cash"] = 0
	pd["clean"] = 200
	var data0: Variant = GameState.world.get("range")
	GameState.world.erase("range")
	RangeClub.skill.erase("Marksman")

	# Rank gate.
	var gates0: bool = Progression.force_gates
	var xp0: int = Progression.host_xp()
	Progression.force_gates = true
	Progression.debug_set_rank(1)
	var refused: String = RangeClub.host_request(p, "drill", "")
	Progression.debug_set_rank(2)
	report.call(refused.begins_with("!") and "rank 2" in refused, "rank 1 is refused: '%s'" % refused)

	# A drill: fee, a free lane, pop-ups, points.
	var answer: String = RangeClub.host_request(p, "drill", "")
	var lane: int = -1
	for l: int in RangeClub.drills:
		if RangeClub.drills[l]["name"] == "Marksman":
			lane = l
	report.call(lane >= 0 and int(pd["clean"]) == 200 - RangeClub.DRILL_FEE and not r.target(lane, 0).up,
			"a drill starts on lane %d (€%d paid, targets down): '%s'" % [lane + 1, RangeClub.DRILL_FEE, answer])
	if lane < 0:
		_cleanup(p, data0, gates0, xp0)
		return
	p.global_position = r.firing_spot(lane) + Vector3.UP * 0.1  # (the drill stops when you leave the range)
	p.auto_target = p.global_position
	RangeClub.host_pop(lane, 1)
	var t1: RangeTarget = r.target(lane, 1)
	var t2: RangeTarget = r.target(lane, 2)
	t2.host_damage(26, p)  # a target that is down: nothing
	t1.host_damage(26, p)  # a hit
	var after_hit: int = int(RangeClub.drills[lane]["score"])
	var down_after: bool = not t1.up
	RangeClub.host_pop(lane, 2)
	t2.is_head_hit(t2.center())
	t2.host_damage(104, p)  # a bullseye
	report.call(after_hit == 1 and down_after and int(RangeClub.drills[lane]["score"]) == 3 and int(RangeClub.drills[lane]["bulls"]) == 1,
			"hits score (down target 0, hit 1, bullseye 2): %d points" % int(RangeClub.drills[lane]["score"]))
	# A real shot from the lane (PlayerCombat on the host) at a standing target.
	RangeClub.host_pop(lane, 0)
	var t0: RangeTarget = r.target(lane, 0)
	await tree.create_timer(0.3).timeout
	GameState.give("Marksman", 0, [{"id": "pistol", "count": 1}, {"id": "ammo_9mm", "count": 16}])
	var c: PlayerCombat = p.combat
	c._h_mags[0] = 8
	p.net_weapon = 1
	var origin: Vector3 = p.head.global_position
	var probe := _Probe.new()  # counts "heard a shot" group calls (in the groups only during the calls)
	world.add_child(probe)
	probe.listen(true)
	c._host_fire(0, origin, (t0.center() - origin).normalized())
	probe.listen(false)
	report.call(int(RangeClub.drills[lane]["score"]) >= 4 and not t0.up,
			"a real pistol shot hits the target (%d points, from %.1f m)" % [int(RangeClub.drills[lane]["score"]), origin.distance_to(t0.center())])
	report.call(probe.heard == 0, "nobody hears a range shot as a crime (%d calls)" % probe.heard)
	RangeClub._range.position.y += 500.0  # the same shot with the range elsewhere: heard
	c._h_last_fire = -10.0
	probe.listen(true)
	c._host_fire(0, origin, (t0.center() - origin).normalized())
	probe.listen(false)
	RangeClub._range.position.y -= 500.0
	report.call(probe.heard == 3, "outside the range the same shot is heard (%d calls: npc, police, cars)" % probe.heard)
	probe.queue_free()
	p.net_weapon = 0
	var text: String = RangeClub.host_finish(lane)
	var s: float = RangeClub.skill_of("Marksman")
	report.call(not RangeClub.drills.has(lane) and s > 0.0 and RangeClub.spread_factor("Marksman") < 1.0
			and RangeClub.best_of("Marksman") >= 4 and r.target(lane, 0).up and r.target(lane, 2).up,
			"after the drill: skill %.3f, spread x%.3f, targets back up ('%s')" % [s, RangeClub.spread_factor("Marksman"), text])
	var f: float = RangeClub.spread_factor("Marksman")
	(GameState.world["range"]["skill"] as Dictionary)["Marksman"] = 1.0
	RangeClub.skill["Marksman"] = 1.0
	report.call(is_equal_approx(RangeClub.spread_factor("Marksman"), 1.0 - RangeClub.SKILL_BONUS) and f > 1.0 - RangeClub.SKILL_BONUS,
			"max skill = %d%% less spread" % roundi(RangeClub.SKILL_BONUS * 100.0))

	# Loaner guns.
	pd["inventory"] = []
	pd["clean"] = 100
	p.global_position = r.desk.global_position + r.desk.global_basis.z * 1.3 + Vector3.UP * 0.2
	var lend: String = RangeClub.host_request(p, "try", "ak47")
	var twice: String = RangeClub.host_request(p, "try", "smg")
	report.call(GameState.count_item("Marksman", "ak47") == 1 and GameState.count_item("Marksman", "ammo_762") == 60
			and int(pd["clean"]) == 100 - RangeClub.TRY_FEE and twice.begins_with("!") and RangeClub.loans.get("Marksman") == "ak47",
			"try the AK-47 (any rank): '%s'; a second gun is refused" % lend)
	GameState.remove_item("Marksman", "ammo_762", 10)  # (shot some)
	p.global_position = r.global_position + Vector3(0, 0.5, 80)
	p.auto_target = p.global_position
	RangeClub.host_check_loans()
	report.call(GameState.count_item("Marksman", "ak47") == 0 and GameState.count_item("Marksman", "ammo_762") == 0
			and not pd.has("range_loan") and not RangeClub.loans.has("Marksman"), "leaving the range: the loaner goes back")

	_cleanup(p, data0, gates0, xp0)
	await tree.physics_frame


static func _cleanup(p: Player, data0: Variant, gates0: bool, xp0: int) -> void:
	for l: int in RangeClub.drills.keys():
		RangeClub.host_finish(l)
	if data0 is Dictionary:
		GameState.world["range"] = data0
	else:
		GameState.world.erase("range")
	RangeClub.skill.erase("Marksman")
	RangeClub.loans.erase("Marksman")
	Progression.force_gates = gates0
	Progression.host_add(xp0 - Progression.host_xp(), "debug")
	GameState.player_data.erase("Marksman")
	p.queue_free()


## Counts the "heard a shot" group calls of PlayerCombat._host_fire.
class _Probe:
	extends Node
	var heard: int = 0

	func listen(on: bool) -> void:
		for g: StringName in [&"npc", &"police", &"cars"]:
			if on:
				add_to_group(g)
			else:
				remove_from_group(g)

	func hear_gunshot(_origin: Vector3) -> void:
		heard += 1

	func report_crime(_p: Node, _pos: Vector3, _murder: bool) -> void:
		heard += 1
