class_name WeaponFX
extends RefCounted
## Cosmetic gunfire effects, played on every peer (no gameplay effect):
## muzzle flash, ejected casings, bullet impacts (decal + particles + sound per
## surface) and positional sounds. Textures and materials are made in code once.

const FLASH_SHADER: Shader = preload("res://prefabs/materials/shaders/muzzle_flash.gdshader")
const SOUND_DIR: String = "res://assets/audio/weapons/"
const MAX_DECALS: int = 80
const MAX_CASINGS: int = 24
const DECAL_LIFETIME: float = 40.0

## Surfaces: concrete (default), metal, wood, flesh, glass, grass.
const METAL_WORDS: PackedStringArray = ["metal", "container", "barrel", "car", "lamp", "trash", "fence",
		"pole", "post_box", "utility", "aircon", "barrier", "rack", "bollard", "sign", "gate", "shelves", "register"]
const WOOD_WORDS: PackedStringArray = ["wood", "crate", "bench", "door", "plank", "table", "bookshelf",
		"bed", "planter", "picket", "garden_fence"]
const SOFT_WORDS: PackedStringArray = ["tree", "shrub", "hedge", "grass", "fern", "flower", "plant", "bag", "sofa", "chair"]

static var _decal_tex: Texture2D
static var _decal_normal: Texture2D
static var _decals: Array[Node3D] = []
static var _casings: Array[Node3D] = []
static var _casing_mesh: Mesh
static var _streams: Dictionary = {}


# --- Sounds ----------------------------------------------------------------------

static func stream(sound_name: String) -> AudioStream:
	if not _streams.has(sound_name):
		var path: String = SOUND_DIR + sound_name + ".ogg"
		_streams[sound_name] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sound_name]


## Picks one of `base_1`, `base_2`, ... (as many as exist).
static func random_stream(base: String) -> AudioStream:
	var options: Array[AudioStream] = []
	for i: int in range(1, 6):
		var s: AudioStream = stream("%s_%d" % [base, i])
		if s:
			options.append(s)
	return options.pick_random() if not options.is_empty() else null


## Positional one-shot sound, removed when done.
static func play_3d(parent: Node, s: AudioStream, pos: Vector3, volume_db: float = 0.0,
		max_distance: float = 60.0, pitch_jitter: float = 0.06, pitch: float = 1.0) -> void:
	if s == null or parent == null or not parent.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.unit_size = 4.0
	p.attenuation_filter_cutoff_hz = 9000.0
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


## Non-positional one-shot (the local player's own weapon).
static func play_2d(parent: Node, s: AudioStream, volume_db: float = 0.0, pitch_jitter: float = 0.04,
		pitch: float = 1.0) -> void:
	if s == null or parent == null or not parent.is_inside_tree():
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# --- Muzzle flash ----------------------------------------------------------------

## Builds the (hidden) flash for a muzzle marker: a front star, two side flames
## and a short light. Call flash() to show it.
static func make_flash(muzzle: Node3D, viewmodel: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Flash"
	root.visible = false
	var depth: float = 0.4 if viewmodel else 1.0
	var front := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	front.mesh = q
	front.material_override = _flash_material(false, depth)
	root.add_child(front)
	for i: int in 2:
		var side := MeshInstance3D.new()
		var sq := QuadMesh.new()
		sq.size = Vector2(0.24, 0.1)
		sq.center_offset = Vector3(0.12, 0, 0)
		side.mesh = sq
		side.material_override = _flash_material(true, depth)
		# Card along -Z (barrel direction), one vertical and one horizontal.
		side.rotation = Vector3(PI / 2.0 * i, PI / 2.0, 0)
		root.add_child(side)
	for m: Node in root.get_children():
		(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(1.0, 0.75, 0.45)
	light.light_energy = 0.0
	light.omni_range = 5.0
	light.shadow_enabled = false
	light.position = Vector3(0, 0, -0.1)
	muzzle.add_child(light)
	muzzle.add_child(root)
	return root


static func _flash_material(side: bool, depth: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLASH_SHADER
	m.set_shader_parameter("side_card", side)
	m.set_shader_parameter("depth_scale", depth)
	return m


## Shows the flash of `muzzle` (made by make_flash) for a few frames.
static func flash(muzzle: Node3D) -> void:
	if muzzle.is_inside_tree():
		Wildlife.scare_at(muzzle.global_position)  # (Roadmap 68: birds, cats, ducks get a fright on every peer)
	var root := muzzle.get_node_or_null("Flash") as Node3D
	var light := muzzle.get_node_or_null("Light") as OmniLight3D
	if root == null:
		return
	root.visible = true
	root.rotation.z = randf() * TAU
	root.scale = Vector3.ONE * randf_range(0.8, 1.2)
	for m: Node in root.get_children():
		((m as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("seed", randf() * 100.0)
	if light:
		light.light_energy = 2.5
	var t := root.create_tween()
	t.tween_interval(0.045)
	t.tween_callback(func() -> void:
		root.visible = false
		if light:
			light.light_energy = 0.0)


# --- Casings ---------------------------------------------------------------------

## Ejects a brass casing from `xform` (the ejection port) with the shooter's velocity.
static func eject_casing(parent: Node, xform: Transform3D, carry_velocity: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if _casing_mesh == null:
		var c := CylinderMesh.new()
		c.top_radius = 0.0045
		c.bottom_radius = 0.0048
		c.height = 0.022
		c.radial_segments = 8
		c.rings = 1
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.78, 0.6, 0.28)
		mat.metallic = 1.0
		mat.roughness = 0.35
		c.material = mat
		_casing_mesh = c
	var body := RigidBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1
	body.mass = 0.01
	body.contact_monitor = true
	body.max_contacts_reported = 1
	body.continuous_cd = true
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.005
	cyl.height = 0.022
	shape.shape = cyl
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _casing_mesh
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh)
	parent.add_child(body)
	# Casing lies across the barrel, flies to the right, up and a bit back.
	body.global_transform = Transform3D(xform.basis * Basis(Vector3.RIGHT, PI / 2.0), xform.origin)
	var b: Basis = xform.basis
	body.linear_velocity = carry_velocity + b.x * randf_range(2.2, 3.0) + b.y * randf_range(1.2, 1.8) + b.z * randf_range(0.2, 0.6)
	body.angular_velocity = Vector3(randf_range(-25, 25), randf_range(-25, 25), randf_range(-25, 25))
	var bounced: Array[bool] = [false]
	body.body_entered.connect(func(_other: Node) -> void:
		if not bounced[0]:
			bounced[0] = true
			play_3d(body, random_stream("casing"), body.global_position, -10.0, 15.0, 0.1))
	_casings.append(body)
	while _casings.size() > MAX_CASINGS:
		var old: Node3D = _casings.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	body.get_tree().create_timer(5.0).timeout.connect(func() -> void:
		if is_instance_valid(body):
			_casings.erase(body)
			body.queue_free())


# --- Impacts ---------------------------------------------------------------------

## Which material a collider is made of (for impact effect and sound).
static func surface_of(collider: Object) -> String:
	var n: Node = collider as Node
	if n == null:
		return "concrete"
	if n is CharacterBody3D:
		return "flesh"
	var path: String = str(n.get_path()).to_lower()
	for w: String in SOFT_WORDS:
		if path.contains(w):
			return "soft"
	for w: String in WOOD_WORDS:
		if path.contains(w):
			return "wood"
	for w: String in METAL_WORDS:
		if path.contains(w):
			return "metal"
	if path.contains("window") or path.contains("glass"):
		return "glass"
	return "concrete"


## Bullet impact at `pos` on a surface facing `normal`.
static func impact(parent: Node, pos: Vector3, normal: Vector3, surface: String) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var n: Vector3 = normal.normalized() if normal.length() > 0.1 else Vector3.UP
	if surface != "flesh" and surface != "soft":
		_add_decal(parent, pos, n, surface)
	_add_particles(parent, pos, n, surface)
	var sound: String = {"metal": "impact_metal", "wood": "impact_wood", "flesh": "impact_flesh",
			"soft": "impact_wood"}.get(surface, "impact_concrete")
	play_3d(parent, random_stream(sound), pos, -4.0 if surface != "flesh" else 0.0, 35.0, 0.12)


static func _add_decal(parent: Node, pos: Vector3, n: Vector3, surface: String) -> void:
	if _decal_tex == null:
		_make_decal_textures()
	var d := Decal.new()
	d.texture_albedo = _decal_tex
	d.texture_normal = _decal_normal
	var s: float = 0.07 if surface == "wood" else 0.06
	d.size = Vector3(s, 0.06, s)
	d.cull_mask = 1  # world only, never on characters walking past
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	d.modulate = Color(0.75, 0.7, 0.65) if surface == "wood" else Color.WHITE
	parent.add_child(d)
	# The decal projects along its -Y: point -Y into the surface.
	var up: Vector3 = n
	var side: Vector3 = up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
	var fwd: Vector3 = side.cross(up)
	d.global_transform = Transform3D(Basis(side, up, fwd).rotated(up, randf() * TAU), pos)
	_decals.append(d)
	while _decals.size() > MAX_DECALS:
		var old: Node3D = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	d.get_tree().create_timer(DECAL_LIFETIME).timeout.connect(func() -> void:
		if is_instance_valid(d):
			_decals.erase(d)
			d.queue_free())


## Bullet hole: dark centre, torn grey rim, a few cracks. Made once.
static func _make_decal_textures() -> void:
	var size: int = 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var height := Image.create(size, size, false, Image.FORMAT_RF)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var crack_dirs: Array[float] = []
	for i: int in 6:
		crack_dirs.append(rng.randf() * TAU)
	for y: int in size:
		for x: int in size:
			var p := Vector2(x + 0.5, y + 0.5) / size * 2.0 - Vector2.ONE
			var r: float = p.length()
			var ang: float = p.angle()
			var wobble: float = 0.04 * sin(ang * 7.0 + 1.3) + 0.03 * sin(ang * 13.0)
			var hole: float = 1.0 - smoothstep(0.16 + wobble, 0.24 + wobble, r)
			var rim: float = (1.0 - smoothstep(0.3, 0.62 + wobble * 2.0, r)) * (1.0 - hole)
			var crack: float = 0.0
			for d: float in crack_dirs:
				var diff: float = absf(wrapf(ang - d, -PI, PI))
				crack = maxf(crack, (1.0 - smoothstep(0.0, 0.06, diff)) * (1.0 - smoothstep(0.3, 0.85, r)))
			var dark: float = maxf(hole, crack * 0.6)
			var col: Color = Color(0.05, 0.045, 0.04).lerp(Color(0.42, 0.4, 0.38), 1.0 - dark)
			var alpha: float = clampf(maxf(dark, rim * 0.55), 0.0, 1.0)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, alpha))
			height.set_pixel(x, y, Color(1.0 - hole - rim * 0.3, 0, 0))
	img.generate_mipmaps()
	_decal_tex = ImageTexture.create_from_image(img)
	# Normal map from the height field (hole sinks in).
	var nimg := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y: int in size:
		for x: int in size:
			var hx: float = height.get_pixel(mini(x + 1, size - 1), y).r - height.get_pixel(maxi(x - 1, 0), y).r
			var hy: float = height.get_pixel(x, mini(y + 1, size - 1)).r - height.get_pixel(x, maxi(y - 1, 0)).r
			var nv := Vector3(-hx * 3.0, -hy * 3.0, 1.0).normalized()
			nimg.set_pixel(x, y, Color(nv.x * 0.5 + 0.5, nv.y * 0.5 + 0.5, nv.z * 0.5 + 0.5, 1.0))
	nimg.generate_mipmaps()
	_decal_normal = ImageTexture.create_from_image(nimg)


static func _add_particles(parent: Node, pos: Vector3, n: Vector3, surface: String) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3(0, 0, 1)  # along the node's +Z = surface normal
	var quad := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	quad.material = mat
	p.mesh = quad
	var fade := Gradient.new()
	match surface:
		"metal":  # sparks
			p.amount = 14
			p.lifetime = 0.35
			p.spread = 50.0
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 7.0
			p.gravity = Vector3(0, -9.8, 0)
			quad.size = Vector2(0.012, 0.012)
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			fade.set_color(0, Color(1.0, 0.85, 0.5, 1.0))
			fade.set_color(1, Color(1.0, 0.4, 0.1, 0.0))
		"wood":  # splinters
			p.amount = 10
			p.lifetime = 0.6
			p.spread = 35.0
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 3.5
			p.gravity = Vector3(0, -9.8, 0)
			quad.size = Vector2(0.015, 0.03)
			fade.set_color(0, Color(0.45, 0.32, 0.2, 1.0))
			fade.set_color(1, Color(0.4, 0.3, 0.2, 0.0))
		"flesh":  # small dark-red mist
			p.amount = 10
			p.lifetime = 0.35
			p.spread = 40.0
			p.initial_velocity_min = 0.6
			p.initial_velocity_max = 1.6
			p.gravity = Vector3(0, -2.0, 0)
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.5
			quad.size = Vector2(0.05, 0.05)
			fade.set_color(0, Color(0.35, 0.03, 0.03, 0.8))
			fade.set_color(1, Color(0.3, 0.02, 0.02, 0.0))
		"soft":  # leaves / fabric bits
			p.amount = 8
			p.lifetime = 0.8
			p.spread = 60.0
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 1.5
			p.gravity = Vector3(0, -3.0, 0)
			quad.size = Vector2(0.02, 0.02)
			fade.set_color(0, Color(0.3, 0.35, 0.2, 1.0))
			fade.set_color(1, Color(0.3, 0.35, 0.2, 0.0))
		_:  # concrete / brick: dust puff + chips
			p.amount = 16
			p.lifetime = 0.7
			p.spread = 30.0
			p.initial_velocity_min = 0.8
			p.initial_velocity_max = 2.5
			p.gravity = Vector3(0, -1.5, 0)
			p.damping_min = 2.0
			p.damping_max = 4.0
			p.scale_amount_min = 1.0
			p.scale_amount_max = 3.0
			quad.size = Vector2(0.04, 0.04)
			fade.set_color(0, Color(0.6, 0.57, 0.52, 0.7))
			fade.set_color(1, Color(0.6, 0.57, 0.52, 0.0))
	p.color_ramp = fade
	parent.add_child(p)
	var up: Vector3 = Vector3.UP if absf(n.y) < 0.95 else Vector3.RIGHT
	p.global_transform = Transform3D(Basis.looking_at(-n, up), pos + n * 0.01)
	p.emitting = true
	p.finished.connect(p.queue_free)
