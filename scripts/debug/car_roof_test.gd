class_name CarRoofTest
extends RefCounted
## Self-test check "car_roof" (SelfTest._check_car_roof), Roadmap 65: cars have a body box + a cabin box
## (CarShapes), so a player lands on the bonnet at bonnet height and on the roof at roof height, and a jump reaches
## the bonnet from the street and the roof from the bonnet.


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	if Vehicles.current == null:
		report.call(false, "no Vehicles node")
		return
	var lot := Vector3(40.0, 0.15, 56.5)
	var car: PlayerCar = Vehicles.current.host_spawn("sedan", 3, lot, PI / 2.0)
	for i: int in 3:
		await tree.physics_frame
	var kind: int = int(car.spec["kind"])
	var shapes: int = 0
	for c: Node in car.get_children():
		if c is CollisionShape3D:
			shapes += 1
	report.call(shapes == 2 and car.get_node_or_null("Shape") != null and car.get_node_or_null("CabinShape") != null,
			"a car has a body + a cabin collision box (%d shapes)" % shapes)
	var jump_h: float = Player.JUMP_VELOCITY * Player.JUMP_VELOCITY / (2.0 * float(ProjectSettings.get_setting("physics/3d/default_gravity")))
	var bonnet: float = CarShapes.bonnet_y(kind)
	var roof: float = CarShapes.roof_y(kind)
	report.call(jump_h > bonnet + 0.1 and jump_h > roof - bonnet + 0.1,
			"a jump (%.2f m) reaches the bonnet (%.2f m) and from there the roof (+%.2f m)" % [jump_h, bonnet, roof - bonnet])

	var p: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Climber"
	GameState.player_data.erase("Climber")
	world.get_node("Players").add_child(p)
	# Dropped over the bonnet / the roof.
	var fwd: Vector3 = -car.global_basis.z
	var s: Dictionary = ProcCar.SPECS[kind]
	var bonnet_spot: Vector3 = car.global_position + fwd * (float(s["len"]) * 0.5 - 0.5)  # front: z = -len/2 + 0.5
	var roof_spot: Vector3 = car.to_global(Vector3(0, 0, (float(s["cab_f"]) + float(s["cab_b"])) * 0.5))
	var ground_y: float = car.global_position.y
	var landed: Array[float] = []
	for spot: Vector3 in [bonnet_spot, roof_spot]:
		p.teleport(spot + Vector3.UP * 2.6)
		p.velocity = Vector3.ZERO
		p.auto_target = spot + Vector3.UP * 2.6  # (auto walk: stay above this spot)
		for i: int in 70:
			await tree.physics_frame
		landed.append(p.global_position.y - ground_y)
	report.call(absf(landed[0] - bonnet) < 0.15 and absf(landed[1] - roof) < 0.15 and p.is_on_floor(),
			"standing on the bonnet at %.2f m (body %.2f) and on the roof at %.2f m (roof %.2f)" % [landed[0], bonnet, landed[1], roof])
	car.queue_free()
	GameState.player_data.erase("Climber")
	p.queue_free()
	await tree.physics_frame
