class_name AnimalsTest
extends RefCounted
## Self-test check "animals" (SelfTest._check_animals), Roadmap 68: the local Wildlife (birds on roofs, pigeon flocks,
## cats, ducks on the sea) is there, birds fly roof to roof, pigeons fly up from a player and come back (not at
## night), cats bolt, a gunshot (WeaponFX.flash) scares ducks and birds, ducks bob on the water.


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	for i: int in 80:
		if Wildlife.current and Wildlife.current.ready_done:
			break
		await tree.create_timer(0.1).timeout
	var wl: Wildlife = Wildlife.current
	if wl == null or not wl.ready_done:
		report.call(false, "no Wildlife node")
		return
	Wildlife.always_active = true
	var old_return: Vector2 = AmbientBird.return_time
	var dn: DayNight = tree.get_first_node_in_group(&"day_night") as DayNight
	var old_hours: float = dn.hours if dn else 12.0
	if dn:
		dn.set_hours(12.0)
	var c: Dictionary = wl.census()
	report.call(int(c["birds"]) >= 10 and int(c["pigeons"]) >= 8 and int(c["flocks"]) >= 2 and int(c["cats"]) >= 3
			and (int(c["ducks"]) >= 4 or not wl.has_sea) and int(c["roof_spots"]) >= 30 and int(c["cat_spots"]) >= 20,
			"wildlife: %s" % c)
	var perched: int = 0
	var birds: Array[AmbientBird] = wl.of_kind(AmbientBird.Kind.BIRD)
	for b: AmbientBird in birds:
		if b.state == AmbientBird.State.FLY or b.global_position.y > 3.0:
			perched += 1
	report.call(perched == birds.size(), "birds sit up on the roofs (%d of %d high up)" % [perched, birds.size()])

	# A bird flies to another roof: an arc, flapping, lands on the spot.
	var bird: AmbientBird = null
	for b: AmbientBird in birds:
		if b.state == AmbientBird.State.SIT:
			bird = b
			break
	if bird:
		var spot: Dictionary = wl.roof_spot_near(bird.global_position, 60.0, 15.0)
		var start: Vector3 = bird.global_position
		bird.fly_to(spot["pos"], 5.0, AmbientBird.State.SIT, spot["yaw"])
		var top: float = -INF
		var wings: Array[float] = []
		for i: int in 600:
			await tree.process_frame
			top = maxf(top, bird.global_position.y)
			wings.append(bird.wing_angle())
			if bird.state != AmbientBird.State.FLY:
				break
		var flapped: bool = wings.max() - wings.min() > 1.0
		report.call(bird.state == AmbientBird.State.SIT and bird.global_position.distance_to(spot["pos"]) < 0.05
				and top > maxf(start.y, (spot["pos"] as Vector3).y) + 2.0 and flapped,
				"a bird flies %.0f m to another roof: arc %.1f m over the higher end, wings flap %s, lands on the spot" % [
				start.distance_to(spot["pos"]), top - maxf(start.y, (spot["pos"] as Vector3).y), flapped])

	# Pigeons: a player walks up -> the flock flies onto a roof -> comes back down.
	AmbientBird.return_time = Vector2(2.0, 3.0)
	var flock: Array[AmbientBird] = []
	for b: AmbientBird in wl.of_kind(AmbientBird.Kind.PIGEON):
		if b.flock == 0:
			flock.append(b)
	var home: Vector3 = wl.flock_homes[0]
	await tree.create_timer(0.3).timeout
	var on_ground: bool = flock.all(func(b: AmbientBird) -> bool: return absf(b.global_position.y - home.y) < 0.5)
	var threat := Node3D.new()
	threat.add_to_group(&"wildlife_threats")
	world.add_child(threat)
	threat.global_position = home
	await tree.create_timer(0.8).timeout
	var flying: int = flock.filter(func(b: AmbientBird) -> bool: return b.state == AmbientBird.State.FLY).size()
	threat.global_position = home + Vector3(0, -200, 0)
	var up_high: int = 0
	for i: int in 60:
		await tree.create_timer(0.1).timeout
		up_high = _count_up(flock, home)
		if up_high == flock.size():
			break
	report.call(on_ground and flying == flock.size() and up_high == flock.size(),
			"a player walks into the pigeon flock (%d birds, on the ground %s): all fly up (%d) and land on a roof (%d)" % [
			flock.size(), on_ground, flying, up_high])
	var back: int = 0
	for i: int in 120:
		await tree.create_timer(0.1).timeout
		back = _count_back(flock, home)
		if back == flock.size():
			break
	report.call(back == flock.size(), "after a while the flock comes back down (%d of %d on the ground)" % [back, flock.size()])
	# At night they stay up.
	if dn:
		dn.set_hours(23.0)
		await tree.create_timer(0.2).timeout
		threat.global_position = home
		await tree.create_timer(0.8).timeout
		threat.global_position = home + Vector3(0, -200, 0)
		await tree.create_timer(7.0).timeout
		var stay: int = flock.filter(func(b: AmbientBird) -> bool: return b.up_on_roof).size()
		report.call(dn.is_night() and stay == flock.size(), "at night the scared flock stays on the roof (%d of %d)" % [stay, flock.size()])
		dn.set_hours(12.0)

	# A cat bolts from a player and stays on the ground.
	var cat: AmbientCat = wl.add_cat(wl.cat_spots[0])
	await tree.create_timer(0.5).timeout
	var cat_y: float = cat.global_position.y
	var cat_from: Vector3 = cat.global_position
	threat.global_position = cat_from + Vector3(2.0, 0, 0)
	await tree.create_timer(0.5).timeout
	var bolted: bool = cat.state == AmbientCat.State.FLEE
	await tree.create_timer(4.0).timeout
	var ran: float = cat.global_position.distance_to(threat.global_position)
	report.call(bolted and cat.flees >= 1 and ran > 5.0 and absf(cat.global_position.y - cat_y) < 0.5,
			"a cat bolts from a player 2 m away: %.1f m away now, ground height kept (%.2f -> %.2f), %d wall stops" % [
			ran, cat_y, cat.global_position.y, cat.blocked])
	threat.queue_free()

	# A gunshot: ducks fly off and land on the water further on; a roof bird takes off.
	var ducks: Array[AmbientBird] = wl.of_kind(AmbientBird.Kind.DUCK)
	if not ducks.is_empty():
		var duck: AmbientBird = ducks[0]
		var ys: Array[float] = []
		for i: int in 40:
			await tree.create_timer(0.05).timeout
			ys.append(duck.global_position.y - wl.sea_y)
		report.call(ys.max() - ys.min() > 0.01 and absf(ys.max()) < 0.2 and absf(ys.min()) < 0.2,
				"a duck bobs on the waves (%.2f .. %.2f m)" % [ys.min(), ys.max()])
		var d_from: Vector3 = duck.global_position
		var muzzle := Node3D.new()
		world.add_child(muzzle)
		muzzle.global_position = d_from + Vector3(0, 1.5, -8.0)
		var roof_bird: AmbientBird = null
		for b: AmbientBird in birds:
			if b.state == AmbientBird.State.SIT and b.global_position.distance_to(muzzle.global_position) < Wildlife.GUNSHOT_RANGE:
				roof_bird = b
		var rb_flights: int = roof_bird.flights if roof_bird else 0
		WeaponFX.flash(muzzle)
		await tree.create_timer(0.2).timeout
		var took_off: bool = duck.state == AmbientBird.State.FLY
		for i: int in 80:
			await tree.create_timer(0.1).timeout
			if duck.state == AmbientBird.State.SWIM:
				break
		var r: Rect2 = Wildlife.DUCK_AREA
		var in_area: bool = r.grow(0.1).has_point(Vector2(duck.global_position.x, duck.global_position.z))
		report.call(took_off and duck.state == AmbientBird.State.SWIM and in_area
				and absf(duck.global_position.y - wl.sea_y) < 0.2 and duck.global_position.distance_to(d_from) > 10.0,
				"a gunshot: the duck flies off and lands on the water %.0f m further (in the harbour %s)" % [
				duck.global_position.distance_to(d_from), in_area])
		if roof_bird:
			report.call(roof_bird.flights > rb_flights, "... and a bird on a roof nearby takes off (%s)" % roof_bird.name)
		muzzle.queue_free()
	AmbientBird.return_time = old_return
	Wildlife.always_active = false
	cat.queue_free()
	wl.cats.erase(cat)
	if dn:
		dn.set_hours(old_hours)
	await tree.physics_frame


static func _count_up(flock: Array[AmbientBird], home: Vector3) -> int:
	var n: int = 0
	for b: AmbientBird in flock:
		if b.up_on_roof and b.state == AmbientBird.State.SIT and b.global_position.y > home.y + 2.5:
			n += 1
	return n


static func _count_back(flock: Array[AmbientBird], home: Vector3) -> int:
	var n: int = 0
	for b: AmbientBird in flock:
		if not b.up_on_roof and b.state != AmbientBird.State.FLY and absf(b.global_position.y - home.y) < 0.5 				and b.global_position.distance_to(home) < AmbientBird.FLOCK_R + 1.0:
			n += 1
	return n
