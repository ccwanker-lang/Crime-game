class_name Poof
extends RefCounted
## Point 58: a short dust "poof" at an object (placing, picking up, using a station) instead of a body animation.
## Local visual only: World.host_poof sends it to every peer.


static func spawn(scene: Node, pos: Vector3, color: Color = Color(0.92, 0.9, 0.85, 0.75), size: float = 1.0) -> void:
	if scene == null or not scene.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 14
	p.lifetime = 0.55
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 0.6 * size
	p.initial_velocity_max = 1.5 * size
	p.damping_min = 2.5
	p.damping_max = 4.0
	p.gravity = Vector3(0, 0.4, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25 * size
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var mesh := SphereMesh.new()
	mesh.radius = 0.09 * size
	mesh.height = 0.18 * size
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	p.mesh = mesh
	scene.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
