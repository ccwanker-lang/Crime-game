class_name RoadsideTest
extends RefCounted
## Self-test check "roadside" (SelfTest._check_roadside): the roadside team tows a crew car to the caller (Roadside).


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	var veh: Vehicles = Vehicles.current
	var lot: Node3D = world.find_child("CarDelivery2", true, false) as Node3D
	if veh == null or lot == null:
		report.call(false, "roadside: no Vehicles node or CarDelivery2 marker")
		return
	var p: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Boss"
	GameState.player_data.erase("Boss")
	world.get_node("Players").add_child(p)
	var sr: Property = world.find_child("StarterRoom", true, false).get_node("Property") as Property
	var front: Vector3 = sr.building().to_global(Vector3(0.0, 0.2, 5.0))
	p.teleport(front)
	p.auto_target = front
	for i: int in 5:
		await tree.physics_frame
	GameState.get_or_create_player_data("Boss")["cash"] = 1000
	var car: PlayerCar = veh.host_spawn("sedan", 1, lot.global_position, lot.global_rotation.y)
	for i: int in 3:
		await tree.physics_frame
	var old_tow: float = Roadside.tow_seconds
	Roadside.tow_seconds = 0.0
	var gates0: bool = Progression.force_gates

	# Rank gate.
	Progression.force_gates = true
	Progression.debug_set_rank(4)
	var res: String = Roadside.host_tow(p, car.uid)
	report.call(res.begins_with("!") and GameState.player_data["Boss"]["cash"] == 1000, "rank 4: roadside refused ('%s')" % res)

	# Rank 5: the car comes to the road next to the player, fee paid.
	Progression.debug_set_rank(5)
	var far: float = car.global_position.distance_to(p.global_position)
	res = Roadside.host_tow(p, "")
	for i: int in 3:
		await tree.physics_frame
	var d: float = car.global_position.distance_to(p.global_position)
	var traffic := world.get_node("Traffic") as Traffic
	var lane: float = float(traffic.nearest(car.global_position)[2])
	var cash: int = int(GameState.player_data["Boss"]["cash"])
	report.call(not res.begins_with("!") and far > 40.0 and d < 30.0 and cash == 1000 - Roadside.FEE,
			"towed: %.0f m -> %.0f m from the caller, €%d paid" % [far, d, 1000 - cash])
	report.call(lane > 2.2 and lane < 4.0 and not Roadside._in_junction(car.global_position),
			"dropped on the pavement beside the lane (%.1f m from the lane), not in a junction" % lane)
	var rec: Dictionary = GameState.world["vehicles"][car.uid]
	report.call((rec["pos"] as Vector3).distance_to(car.global_position) < 0.5, "the new spot is in the save record")
	report.call(p.last_phone.size() >= 2 and str(p.last_phone[0]) == Roadside.CONTACT and str(p.last_phone[1]).contains("parked"),
			"texted by %s: '%s'" % [Roadside.CONTACT, str(p.last_phone[1]) if p.last_phone.size() >= 2 else ""])

	# Already close: refused, no money.
	res = Roadside.host_tow(p, car.uid)
	report.call(res.begins_with("!") and int(GameState.player_data["Boss"]["cash"]) == cash, "car already here: refused ('%s')" % res)
	# Close by but out of fuel (A's point 48): the team comes with a jerrycan.
	car.fuel = 0.0
	res = Roadside.host_tow(p, car.uid)
	report.call(not res.begins_with("!") and is_equal_approx(car.fuel, Roadside.JERRYCAN)
			and int(GameState.player_data["Boss"]["cash"]) == cash - Roadside.FEE and str(p.last_phone[1]).contains("jerrycan"),
			"empty tank: a jerrycan (fuel %d%%), '%s'" % [roundi(car.fuel * 100.0), str(p.last_phone[1])])

	Roadside.tow_seconds = old_tow
	Progression.force_gates = gates0
	GameState.world.erase("progress")
	veh.host_remove(car)
	GameState.player_data.erase("Boss")
	p.queue_free()
	await tree.physics_frame
