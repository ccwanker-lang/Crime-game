class_name FireBarrel
extends StaticBody3D
## Map zone 3 (the slums): a rusty oil drum with a fire in it (flames, sparks, a flickering warm light).
## Local visuals only (every peer builds its own). Origin on the ground.

var _light: OmniLight3D
var _t: float = 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var b := MeshBuilder.new()
	b.color = Color(0.42, 0.24, 0.14)
	b.cylinder(&"item_metal", Vector3.ZERO, Vector3(0, 0.9, 0), 0.3, 0.3, 12, false)
	b.color = Color(0.3, 0.17, 0.1)
	for y: float in [0.25, 0.65]:
		b.cylinder(&"item_metal", Vector3(0, y, 0), Vector3(0, y + 0.05, 0), 0.315, 0.315, 12)
	b.color = Color(0.15, 0.1, 0.08)
	b.cylinder(&"item_matte", Vector3(0, 0.75, 0), Vector3(0, 0.78, 0), 0.29, 0.29, 12)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.32
	shape.height = 0.9
	cs.shape = shape
	cs.position.y = 0.45
	add_child(cs)
	if DisplayServer.get_name() == "headless":
		return
	add_child(_flames(Color(1.0, 0.55, 0.15), 40, 0.7, 0.18))
	add_child(_flames(Color(1.0, 0.85, 0.4), 12, 1.6, 0.04))  # sparks
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.light_energy = 1.6
	_light.omni_range = 7.0
	_light.shadow_enabled = false
	_light.position = Vector3(0, 1.4, 0)
	add_child(_light)


func _flames(c: Color, amount: int, life: float, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.position = Vector3(0, 0.85, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.18
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 1.2, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 2.5
	mesh.material = mat
	p.mesh = mesh
	return p


func _process(delta: float) -> void:
	if _light == null:
		return
	_t += delta
	_light.light_energy = 1.4 + 0.35 * sin(_t * 13.0) * sin(_t * 7.3 + 1.0)
