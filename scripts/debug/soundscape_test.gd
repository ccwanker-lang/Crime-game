class_name SoundscapeTest
extends RefCounted
## Self-test check "soundscape" (SelfTest._check_soundscape), session B user list item 2: which ambience plays where
## and when, calm / tense music, every sound file loads (loops loop), footstep surfaces and the step rhythm.


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	var ss: Node = tree.root.get_node("Soundscape")
	var spots: Array = [
		[Vector3(20, 0, 250), 12.0, "city"], [Vector3(0, 0, 0), 12.0, "village_day"], [Vector3(0, 0, 0), 23.5, "village_night"],
		[Vector3(-40, 0, -80), 2.0, "village_night"], [Vector3(-150, 0, 94), 12.0, "docks"],
		[Vector3(-70, 0, -390), 12.0, "forest"], [Vector3(-150, 0, -250), 12.0, "forest"],
	]
	var bunker_ok: bool = true
	if Zones.bunker and is_instance_valid(Zones.bunker):
		var lab: Vector3 = Mountain.bunker_spot() * Vector3(3, -13.7, 30)
		spots.append([lab, 12.0, "bunker"])
	var wrong: PackedStringArray = []
	for s: Array in spots:
		var got: String = ss.call("zone_key_at", s[0], s[1])
		if got != s[2]:
			wrong.append("%s %.0fh -> %s (want %s)" % [s[0], s[1], got, s[2]])
	report.call(wrong.is_empty() and bunker_ok, "ambience per zone: city, village day/night (slums too), docks, forest (army "
			+ "base, mountains), bunker%s" % ("" if wrong.is_empty() else ": " + "; ".join(wrong)))

	var bad: PackedStringArray = []
	for table: Dictionary in [ss.get("AMBIENCE"), ss.get("MUSIC")]:
		for k: String in table:
			var st: AudioStream = load(table[k][0])
			if st == null or not st is AudioStreamOggVorbis or st.get_length() < 20.0:
				bad.append(k)
	for kind: String in Footsteps.SURFACES:
		var def: Array = Footsteps.SURFACES[kind]
		for i: int in int(def[1]):
			if load(str(def[0]) % (i + 1)) == null:
				bad.append("%s_%d" % [kind, i + 1])
	report.call(bad.is_empty(), "every ambience loop, music track and footstep loads%s" % (
			"" if bad.is_empty() else " (missing %s)" % ", ".join(bad)))

	var p: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.name = "1"
	p.player_name = "Ears"
	world.get_node("Players").add_child(p)
	for i: int in 5:
		await tree.physics_frame
	var calm: String = ss.call("music_key_for", p, 12.0)
	var night: String = ss.call("music_key_for", p, 23.0)
	p.wanted_stars = 2
	var wanted: String = ss.call("music_key_for", p, 12.0)
	p.wanted_stars = 0
	ss.set("_combat_until", 0.0)
	ss.call("heard_shot", p.global_position + Vector3(400, 0, 0))
	var far_shot: String = ss.call("music_key_for", p, 12.0)
	var cam: Camera3D = tree.root.get_viewport().get_camera_3d()
	ss.call("heard_shot", (cam.global_position if cam else p.global_position) + Vector3(20, 0, 0))
	var near_shot: String = ss.call("music_key_for", p, 12.0)
	ss.set("_combat_until", 0.0)
	report.call(calm == "calm_day" and night == "calm_night" and wanted == "tense" and far_shot == "calm_day"
			and near_shot == "tense", "music: calm by day (%s) / night (%s), tense with stars (%s), a shot 20 m away (%s) but not 400 m (%s)"
			% [calm, night, wanted, near_shot, far_shot])

	# Surfaces under the feet.
	var space := world.get_world_3d().direct_space_state
	var probe := func(at: Vector3) -> String:
		var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 3.0, 1 | 2)
		var hit: Dictionary = space.intersect_ray(q)
		return Footsteps.surface_of(hit) if not hit.is_empty() else "none"
	var road: String = probe.call(Vector3(-20, 0, 0))  # Main Road
	var grass_at: Vector3 = Vector3.INF
	for n: Node in world.find_children("*", "", true, false):
		if n is GroundArea and (n as GroundArea).grass and (n as GroundArea).collision:
			grass_at = (n as Node3D).global_position
			break
	var grass: String = probe.call(grass_at) if grass_at != Vector3.INF else "none"
	var snow_at: Vector3 = Vector3.INF
	for x: int in range(-260, -40, 10):
		for z: int in range(-330, -180, 10):
			if Mountain.height_at(x, z) > Mountain.SNOW_LINE + 5.0:
				snow_at = Vector3(x, Mountain.height_at(x, z), z)
				break
		if snow_at != Vector3.INF:
			break
	var snow: String = probe.call(snow_at) if snow_at != Vector3.INF else "none"
	var wood: String = "none"
	for n: Node in world.find_children("*", "", true, false):
		var b := n as Building
		if b and b.enterable and b.floor_material == "wood_floor" and b.is_visible_in_tree():
			wood = probe.call(b.global_transform * Vector3(0, 0.5, -b.depth * 0.5))
			break
	report.call(road == "stone" and grass == "grass" and snow == "snow" and wood == "wood",
			"footstep surfaces: road %s, grass field %s, mountain top %s, house floor %s" % [road, grass, snow, wood])

	# Rhythm: 6 m at walking pace on the road = 4 steps; standing still = none.
	var fs := p.get_node_or_null(^"Footsteps") as Footsteps
	var walked: int = 0
	var still: int = 0
	if fs:
		p.teleport(Vector3(-20, 0.3, 0.0))
		for i: int in 20:
			await tree.physics_frame
		var s0: int = fs.steps
		var start: Vector3 = p.global_position
		for i: int in 240:  # 4 s at 1.5 m/s
			p.global_position = start + Vector3(-1.5 * (i + 1) / 60.0, 0, 0)
			await tree.physics_frame
		walked = fs.steps - s0
		var s1: int = fs.steps
		for i: int in 60:
			await tree.physics_frame
		still = fs.steps - s1
	report.call(fs != null and walked >= 3 and walked <= 5 and still == 0 and fs.surface == "stone",
			"footsteps: every player has them; 6 m walked on the road = %d steps on %s, standing still = %d"
			% [walked, fs.surface if fs else "-", still])
	p.queue_free()
	await tree.process_frame
