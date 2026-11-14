class_name DogsTest
extends RefCounted
## Self-test check "dogs" (SelfTest._check_dogs), Roadmap 67: a dog walker gets a real Dog (World/Dogs), it follows on
## the lead, plays fetch (ball thrown, fetched, dropped at the owner's feet), runs off when its owner is killed, and
## can be killed itself (ragdoll carcass, no person-kill).


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	var path: Array[Vector3] = world.call("park_path")
	if path.is_empty():
		report.call(false, "no park path")
		return
	var start: Vector3 = path[0]
	Dog.auto_fetch = false  # (only the fetch this test starts)
	var walker: ParkGoer = world.call("add_park_goer", start, ParkGoer.Role.DOG)
	var map: RID = world.get_world_3d().navigation_map
	var next: Vector3 = NavigationServer3D.map_get_closest_point(map, start + (path[1] - start).normalized() * 2.0)
	walker.path = [start, next] as Array[Vector3]  # (paces up and down: stays close; the test starts the fetch)
	walker.laps_left = 100000
	for i: int in 20:
		await tree.physics_frame
	var dog: Dog = Dog.of(walker)
	report.call(dog != null and dog.get_parent().name == "Dogs" and dog.collision_layer == 4 and dog.owner_npc == walker,
			"a dog walker has a real dog on the NPC layer (%s)" % (dog.get_path() if dog else "none"))
	if dog == null:
		walker.queue_free()
		return
	await tree.create_timer(1.0).timeout
	var beside: float = dog.global_position.distance_to(walker.global_position)
	report.call(dog.state == Dog.State.FOLLOW and beside < 1.6 and dog._visual.lead_on,
			"it walks beside its owner on the lead (%.1f m)" % beside)

	# Fetch: one round.
	var fetch_done: Array = [false]
	var f := func() -> void:
		await dog.host_fetch(1)
		fetch_done[0] = true
	f.call()
	var thrown_to: Vector3 = dog._flight_to
	var max_away: float = 0.0
	var carried: bool = false
	for i: int in 900:
		await tree.physics_frame
		max_away = maxf(max_away, dog.global_position.distance_to(walker.global_position))
		carried = carried or dog._visual.carrying
		if fetch_done[0]:
			break
	var ball_at: Vector3 = dog.ball_position()
	report.call(fetch_done[0] and carried and max_away > Dog.THROW_MIN - 2.0 and ball_at != Vector3.INF
			and ball_at.distance_to(walker.global_position) < 1.6,
			"fetch: the ball flies %.0f m, the dog runs %.0f m out, carries it (%s) back and drops it %.1f m from the owner (done %s, state %d)" % [
			walker.global_position.distance_to(thrown_to), max_away, carried,
			ball_at.distance_to(walker.global_position) if ball_at != Vector3.INF else -1.0, fetch_done[0], dog.state])

	# The owner is killed: the dog runs off.
	walker.host_damage(500, null, walker.global_position + Vector3(0, 0, 3))
	var body_at: Vector3 = walker.global_position
	await tree.create_timer(Dog.MOURN + 0.5).timeout
	var mourned: bool = dog.state == Dog.State.FLEE
	await tree.create_timer(4.0).timeout
	var fled: float = dog.global_position.distance_to(body_at)
	report.call(mourned and fled > 10.0, "the owner is killed: the dog stays a moment, then runs off (%.0f m away, state %d, path %d pts)" % [
			fled, dog.state, dog._path.size()])

	# A dog can be killed: no person kill, a carcass.
	var hurt: bool = dog.host_damage(10, null, dog.global_position + Vector3(2, 0, 0))
	var alive_after_10: bool = dog.state != Dog.State.DEAD
	var killed: bool = dog.host_damage(40, null, dog.global_position + Vector3(2, 0, 0))
	await tree.create_timer(0.5).timeout
	var carcass: RigidBody3D = dog.carcass()
	report.call(not hurt and alive_after_10 and not killed and dog.state == Dog.State.DEAD and carcass != null
			and dog.collision_layer == 0, "a dog can be shot: limp carcass (%s), not counted as a person kill" % carcass)
	if carcass:
		carcass.queue_free()
	dog.queue_free()
	Dog.auto_fetch = true
	if is_instance_valid(walker):
		walker.queue_free()
	await tree.physics_frame
