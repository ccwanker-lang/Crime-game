class_name RunOverTest
extends RefCounted
## Self-test check "run_over" (SelfTest._check_run_over), Roadmap 64: a player's car hits people from ANY side
## (PlayerCar._host_hits / impact_speed): the front, reversing, the swinging rear in a slide; someone standing beside
## a passing car is not hit; a kill by car is a crime (police report + kill hooks) and the victim ragdolls.


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	if Vehicles.current == null:
		report.call(false, "no Vehicles node")
		return
	var lot := Vector3(40.0, 0.15, 56.5)
	var car: PlayerCar = Vehicles.current.host_spawn("sedan", 1, lot, PI / 2.0)  # nose west (-X)
	for i: int in 3:
		await tree.physics_frame
	# Geometry: impact speed of the nearest point of the car towards a person.
	var fwd: Vector3 = -car.global_basis.z
	var right: Vector3 = car.global_basis.x
	var size: Vector3 = ProcCar.collision_size(int(car.spec["kind"]))
	var c: Vector3 = car.global_position
	var front_p: Vector3 = c + fwd * (size.z * 0.5 + 0.2)
	var back_p: Vector3 = c - fwd * (size.z * 0.5 + 0.2)
	var side_p: Vector3 = c + right * (size.x * 0.5 + 0.2)
	var rear_side: Vector3 = c - fwd * (size.z * 0.5 - 0.3) + right * (size.x * 0.5 + 0.2)
	var go: Vector3 = fwd * 10.0
	var f: float = car.impact_speed(front_p, go, 0.0)
	var side: float = car.impact_speed(side_p, go, 0.0)
	var rev: float = car.impact_speed(back_p, -fwd * 6.0, 0.0)
	var behind_fwd: float = car.impact_speed(back_p, go, 0.0)
	# Turning left (+yaw) swings the rear to the right.
	var swing: float = car.impact_speed(rear_side, Vector3.ZERO, 2.5)
	report.call(absf(f - 10.0) < 0.1 and side < 0.1 and absf(rev - 6.0) < 0.1 and behind_fwd == 0.0 and swing > 3.0,
			"impact from any side: front %.1f, beside %.1f, reversing %.1f, behind while driving on %.1f, swinging rear %.1f m/s"
			% [f, side, rev, behind_fwd, swing])

	# A driver for the crime.
	var p: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.auto_walk = true
	p.name = "1"
	p.player_name = "Reverser"
	GameState.player_data.erase("Reverser")
	world.get_node("Players").add_child(p)
	p.global_position = c + right * 2.5 + Vector3.UP * 0.2
	p.auto_target = p.global_position
	for i: int in 5:
		await tree.physics_frame
	car.host_enter(p)
	await tree.physics_frame
	# Reversing over a pedestrian.
	var npc: Pedestrian = world.call("_add_pedestrian", c - fwd * (size.z * 0.5 + 1.6) + Vector3.UP * 0.05, 1)
	for i: int in 5:
		await tree.physics_frame
	npc.velocity = Vector3.ZERO
	npc.health = 50  # (reversing tops out under KILL_SPEED: a hurt person, so this hit kills)
	var probe := _Probe.new()
	world.add_child(probe)
	var hits0: int = car.hits
	car.speed = -9.0
	car.test_input = Vector3(0, -1, 0)
	for i: int in 60:
		await tree.physics_frame
		if npc.dead:
			break
	car.test_input = Vector3(0, 0, 1)
	report.call(car.hits > hits0 and npc.dead, "reversing at speed over a pedestrian: down (hits %d, dead %s)" % [car.hits - hits0, npc.dead])
	await tree.create_timer(0.3).timeout
	var limp: bool = npc._ragdoll != null and npc._ragdoll.running
	report.call(limp and probe.kills > 0, "a kill by car: ragdoll %s, kill hooks %d (+ police report + wanted, like a shot)" % [
			limp, probe.kills])
	for i: int in 40:
		await tree.physics_frame
	# Driving past someone on the pavement (beside the car): no hit.
	car.speed = 0.0
	await tree.physics_frame
	var c2: Vector3 = car.global_position
	var side_npc: Pedestrian = world.call("_add_pedestrian", c2 + car.global_basis.x * (size.x * 0.5 + 0.25) + Vector3.UP * 0.05, 2)
	for i: int in 3:
		await tree.physics_frame
	side_npc.velocity = Vector3.ZERO
	var hits1: int = car.hits
	car._hit_yaw_rate = 0.0
	car.net_speed = 8.0  # (one hit pass while it rolls past)
	car._host_hits()
	report.call(car.hits == hits1 and not side_npc.dead, "someone beside a passing car is not hit (hits %d)" % (car.hits - hits1))
	car.net_speed = 0.0
	probe.queue_free()
	car.host_exit(p)
	await tree.physics_frame
	for n: Pedestrian in [npc, side_npc]:
		if is_instance_valid(n):
			n.queue_free()
	if is_instance_valid(car):
		car.queue_free()
	GameState.player_data.erase("Reverser")
	p.queue_free()
	await tree.physics_frame


## Counts the kill hooks of a kill by car (kill_hooks on_kill, like PlayerCombat's; Territory listens there).
class _Probe:
	extends Node
	var kills: int = 0

	func _ready() -> void:
		add_to_group(&"kill_hooks")

	func on_kill(_killer: Node, _victim: Node) -> void:
		kills += 1
