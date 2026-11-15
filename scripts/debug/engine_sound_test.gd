class_name EngineSoundTest
extends RefCounted
## Self-test check "engine_sound" (SelfTest._check_engine_sound), Roadmap 66: every car gets a VehicleSound, the
## gearbox model (rpm per speed, shifts), engine loops play near the camera with pitch from rpm, tyres screech in a
## hard turn, silence far away, idle when stopped.


static func run(t: Node, world: Node3D) -> void:
	var tree: SceneTree = t.get_tree()
	var report := func(ok: bool, text: String) -> void: t.call("_report", ok, text)
	var own: PlayerCar = null
	if tree.get_nodes_in_group(&"cars").is_empty() and Vehicles.current:
		own = Vehicles.current.host_spawn("van", 0, Vector3(40.0, 0.15, 56.5), PI / 2.0)  # (no traffic in this run)
	await tree.create_timer(1.2).timeout  # (Ambience scans every 0.5 s)
	var cars: Array = tree.get_nodes_in_group(&"cars") + tree.get_nodes_in_group(&"player_cars")
	var with_sound: int = 0
	for c: Node in cars:
		if c.get_node_or_null("VehicleSound") != null:
			with_sound += 1
	report.call(cars.size() > 0 and with_sound == cars.size(), "every car has an engine sound (%d of %d)" % [with_sound, cars.size()])

	var g1: Array = VehicleSound.rpm_for(4.9)
	var g2: Array = VehicleSound.rpm_for(5.5)
	var idle: Array = VehicleSound.rpm_for(0.0)
	report.call(int(idle[0]) == 0 and is_equal_approx(float(idle[1]), VehicleSound.IDLE_RPM) and int(g1[0]) == 1
			and int(g2[0]) == 2 and float(g2[1]) < float(g1[1]),
			"gearbox: idle %d rpm, 1st %d rpm at 4.9 m/s, shift to 2nd drops to %d rpm" % [idle[1], g1[1], g2[1]])

	# A stand-in car we drive by hand, with a camera next to it.
	var fake := Node3D.new()
	fake.name = "SoundTestCar"
	world.add_child(fake)
	fake.global_position = Vector3(0, 30, 0)  # (in the air: nothing in the way)
	var s: VehicleSound = Ambience.attach_sound(fake)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.global_position = fake.global_position + Vector3(6, 2, 0)
	var old_cam: Camera3D = world.get_viewport().get_camera_3d()
	cam.make_current()
	# Accelerate to ~12 m/s.
	var v: float = 0.0
	for i: int in 120:
		await tree.physics_frame
		var dt: float = 1.0 / Engine.physics_ticks_per_second
		v = minf(12.0, v + 6.0 * dt)
		fake.global_position += Vector3(0, 0, -v * dt)
		cam.global_position = fake.global_position + Vector3(6, 2, 0)
	report.call(s.speed > 10.0 and s.gear == 3 and s.engine_load > 0.5 and s.is_playing() and s._on.pitch_scale > 1.5,
			"accelerating at %.1f m/s: gear %d, %d rpm, load %.2f, pitch %.2f, playing %s" % [s.speed, s.gear, s.rpm,
			s.engine_load, s._on.pitch_scale, s.is_playing()])
	# A hard turn at speed: the tyres screech.
	for i: int in 30:
		await tree.physics_frame
		var dt: float = 1.0 / Engine.physics_ticks_per_second
		fake.rotation.y += 1.2 * dt
		fake.global_position += -fake.global_basis.z * v * dt
		cam.global_position = fake.global_position + Vector3(6, 2, 0)
	report.call(s.slide > 0.2 and s._tyres.playing, "a hard turn at %.0f m/s: tyres screech (slide %.2f)" % [s.speed, s.slide])
	# Far from the camera: silent.
	cam.global_position = fake.global_position + Vector3(150, 0, 0)
	for i: int in 3:
		await tree.physics_frame
	report.call(not s.is_playing() and not s._tyres.playing, "out of earshot (150 m): silent")
	# Stop: idle.
	cam.global_position = fake.global_position + Vector3(6, 2, 0)
	for i: int in 90:
		await tree.physics_frame
	report.call(s.speed < 0.3 and s.gear == 0 and absf(s.rpm - VehicleSound.IDLE_RPM) < 60.0 and s.is_playing(),
			"standing still: idling at %d rpm" % s.rpm)
	if old_cam:
		old_cam.make_current()
	cam.queue_free()
	fake.queue_free()
	if own:
		own.queue_free()
	await tree.physics_frame
