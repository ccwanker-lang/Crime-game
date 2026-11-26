class_name CityWalker
extends Pedestrian
## City life point 3 (session B, 2026-11-25): the city's walkers with a role (synced once at spawn), on the CityLife
## sidewalk graph (Zones' residents tick drives them: `city_step`).
## - WALK: just walks.
## - SHOPPER: walks, now and then goes into a shop (hidden inside for a while: synced `inside`), comes out with one
##   or two shopping bags in the hands (synced `carry`).
## - JOGGER: runs (RUN anim, JOG_SPEED), mornings and evenings.
## - PRAM: pushes a pram (local visual), slowly.
## - DOG: walks a dog (a real `Dog`, made by the Ambience autoload on every peer like for the park's dog walkers).
## - BUILDER (city life point 4): hard hat + hi-vis vest; SiteCrew drives it. `carry` CARRY_HAMMER = hammering (the
##   hammer swings in the hand while standing), CARRY_BRICKS = a stack of bricks in front.

## - INMATE / GUARD (city life point 5): prison people for PrisonLife - orange overalls / a grey uniform with a cap.

enum Role { WALK, SHOPPER, JOGGER, PRAM, DOG, BUILDER, INMATE, GUARD }

const INMATE_ORANGE := Color(0.95, 0.45, 0.08)
const GUARD_SHIRT := Color(0.45, 0.5, 0.55)
const GUARD_DARK := Color(0.1, 0.11, 0.13)

const CARRY_HAMMER: int = 10
const CARRY_BRICKS: int = 11

const JOG_SPEED: float = 2.7
const PRAM_SPEED: float = 1.0
const BAG_COLORS: Array[Color] = [Color(0.85, 0.75, 0.55), Color(0.9, 0.25, 0.3), Color(0.2, 0.45, 0.8),
		Color(0.95, 0.95, 0.92), Color(0.3, 0.6, 0.35)]
## A shop visit: [min, max] seconds inside (tests shorten it).
static var visit_time: Vector2 = Vector2(20.0, 60.0)
## Chance per graph step that a shopper without bags looks for a shop nearby.
const SHOP_CHANCE: float = 0.25
const SHOP_RANGE: float = 45.0

## Synced at spawn.
var role: int = Role.WALK
## Synced: bags in hand (0-2).
var carry: int = 0:
	set(v):
		carry = v
		if is_inside_tree():
			_build_bags()
## Synced: inside a shop (not drawn, no collision).
var inside: bool = false:
	set(v):
		inside = v
		if is_inside_tree():
			_apply_inside()

## Host: busy with a shop visit.
var shopping: bool = false
var shops_visited: int = 0

var _bags: Array[Node3D] = []      # (BoneAttachments)
var _bag_holders: Array[Node3D] = []
var _bags_set: bool = false  # (kept hanging straight down, see _process)
var _pram: Node3D = null


func _ready() -> void:
	ambient = false
	super._ready()
	add_to_group(&"city_walkers")
	if role == Role.PRAM:
		_build_pram()
	if role == Role.BUILDER and variant != 9:  # (the "worker" model wears its own hard hat + vest)
		_build_site_gear()
	if role == Role.GUARD:
		_build_guard_cap()
	_build_bags()
	_apply_inside()


## Customers stand still; walkers with a pram or a dog, joggers and someone inside a shop don't deal.
func can_be_customer() -> bool:
	return role in [Role.WALK, Role.SHOPPER] and not inside and not shopping  # (builders, inmates, guards: never)


## Uniforms by material name (see Pedestrian._build_model; the names differ per model).
func uniform_colors() -> Dictionary:
	match role:
		Role.INMATE:
			return {"Shirt": INMATE_ORANGE, "Shirt2": INMATE_ORANGE, "Pants": INMATE_ORANGE, "White": INMATE_ORANGE,
					"Red_Dark": INMATE_ORANGE, "LightBrown": INMATE_ORANGE}
		Role.GUARD:
			return {"Shirt": GUARD_SHIRT, "Shirt2": GUARD_SHIRT, "Pants": GUARD_DARK, "White": GUARD_SHIRT,
					"Red_Dark": GUARD_DARK, "LightBrown": GUARD_DARK}
	return {}


func _move_speed() -> float:
	if is_fleeing():
		return RUN_SPEED
	match role:
		Role.JOGGER:
			return JOG_SPEED
		Role.PRAM:
			return PRAM_SPEED
	return super._move_speed()


# --- Host brain (called by Zones._resident_step instead of CityLife.walk_step) --------------------

func city_step(r: Dictionary) -> void:
	if shopping or inside:
		return
	if role == Role.SHOPPER and carry == 0 and not _moving and not is_fleeing() and randf() < SHOP_CHANCE:
		var shop: Dictionary = nearest_shop(global_position, SHOP_RANGE)
		if not shop.is_empty():
			_go_shopping(shop, r)
			return
	if role == Role.JOGGER and not _moving and not is_fleeing():
		_jog_step(r)
		return
	CityLife.walk_step(self, r)


func _jog_step(r: Dictionary) -> void:
	var nodes: Array[Vector3] = CityLife.graph()
	var at: int = int(r.get("node", -1))
	if at < 0 or global_position.distance_to(nodes[at]) > 3.0:
		CityLife.walk_step(self, r)
		return
	var options: Array = CityLife.neighbours(at).duplicate()
	options.shuffle()
	if options.size() > 1:
		options.erase(int(r.get("prev", -1)))
	for nb: int in options:
		if straight_way_clear(nodes[nb], 80.0):
			r["prev"] = at
			r["node"] = nb
			_go_direct(nodes[nb], Anim.RUN)
			return


## The shops a walker can go into: every seller's building (ShopStaff) - entrance = its door, else the pavement in
## front of the counter.
static func shops() -> Array:
	var out: Array = []
	for s: ShopSeller in ShopStaff.sellers:
		if not is_instance_valid(s):
			continue
		var b := s.get_parent() as Node3D
		var door: NetDoor = null
		for c: Node in b.find_children("*", "Node3D", true, false):
			if c is NetDoor and (door == null or (c as Node3D).global_position.distance_to(s.global_position)
					< door.global_position.distance_to(s.global_position)):
				door = c as NetDoor
		if door and door.global_position.distance_to(s.global_position) > 16.0:
			door = null  # (a tower: that door belongs to another part)
		var gap: Dictionary = ShopStaff.entrance(s) if door == null else {}
		if door == null and gap.is_empty():
			continue
		var front: Vector3 = (door.get_center() + door.get_outward() * 1.4) if door else gap["front"]
		out.append({"seller": s, "door": door, "gap": gap, "front": front, "type": s.shop_type})
	return out


static func nearest_shop(from: Vector3, range_m: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = range_m
	for sh: Dictionary in shops():
		var d: float = from.distance_to(sh["front"])
		if d < best_d:
			best_d = d
			best = sh
	return best


func _go_shopping(shop: Dictionary, r: Dictionary) -> void:
	shopping = true
	var front: Vector3 = shop["front"]
	front.y = global_position.y  # (door centre is at chest height: walk on our own level)
	if not straight_way_clear(front, SHOP_RANGE + 5.0) and Vector2(front.x - global_position.x, front.z - global_position.z).length() > 0.6:
		var map: RID = get_world_3d().navigation_map
		var snap: Vector3 = NavigationServer3D.map_get_closest_point(map, front)
		if Vector2(snap.x - front.x, snap.z - front.z).length() < 1.5:
			await walk_to(snap)
		else:
			shopping = false
			return
	elif Vector2(front.x - global_position.x, front.z - global_position.z).length() > 0.6:
		await _go_direct(front, Anim.WALK)
	if not is_instance_valid(self) or dead or is_fleeing() 			or Vector2(front.x - global_position.x, front.z - global_position.z).length() > 2.5:
		shopping = false
		return
	front = global_position
	var door: NetDoor = shop["door"]
	if door:
		target_door = door
		face(door.get_center())
		await get_tree().create_timer(0.6).timeout
	inside = true
	await get_tree().create_timer(randf_range(visit_time.x, visit_time.y)).timeout
	if not is_instance_valid(self) or dead:
		return
	global_position = front
	net_pos = front
	carry = 1 if randf() < 0.6 else 2
	inside = false
	shops_visited += 1
	if door:
		await get_tree().create_timer(0.8).timeout
		target_door = null
	r["node"] = CityLife.nearest_node(global_position)
	r["prev"] = -1
	shopping = false


func _apply_inside() -> void:
	visible = not inside
	if collision:
		collision.disabled = inside or _sitting
	if inside:
		anim_state = Anim.IDLE


# --- Looks (every peer) ---------------------------------------------------------------------------

func _skeleton_of() -> Skeleton3D:
	var model: Node3D = get_node_or_null("Model") as Node3D
	if model == null:
		return null
	var sk: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	return sk[0] as Skeleton3D if not sk.is_empty() else null


func _build_bags() -> void:
	for b: Node3D in _bags:
		if is_instance_valid(b):
			b.queue_free()
	_bags.clear()
	_bag_holders.clear()
	_bags_set = false
	set_process(false)
	if carry <= 0 or DisplayServer.get_name() == "headless":
		return
	var sk: Skeleton3D = _skeleton_of()
	if sk == null:
		return
	if carry >= CARRY_HAMMER:
		_build_tool(sk)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = color_seed + shops_visited
	for k: int in mini(carry, 2):
		var side: String = "R" if k == 0 else "L"
		var bone: int = sk.find_bone("Palm." + side)
		if bone < 0:
			bone = sk.find_bone("Wrist." + side)
		if bone < 0:
			continue
		var att := BoneAttachment3D.new()
		att.bone_idx = bone
		sk.add_child(att)
		var bag := Node3D.new()
		att.add_child(bag)
		_bag_holders.append(bag)
		var col: Color = BAG_COLORS[rng.randi() % BAG_COLORS.size()]
		var body := MeshInstance3D.new()
		body.mesh = _mesh("box", Vector3(0.28, 0.32, 0.12))
		body.material_override = ProcGoods.mat(col)
		body.position = Vector3(0, -0.2, 0.0)  # (below the hand)
		bag.add_child(_gear(body))
		var handle := MeshInstance3D.new()
		handle.mesh = _mesh("box", Vector3(0.12, 0.08, 0.015))
		handle.material_override = ProcGoods.mat(col.darkened(0.3))
		handle.position = Vector3(0, -0.04, 0)
		bag.add_child(_gear(handle))
		_bags.append(att)
	set_process(not _bags.is_empty())


## Bags hang straight down from the hand whatever the arm does (metres, upright, facing the walk direction); a
## builder's hammer swings while it stands (hammering), the bricks are held in front.
func _process(_delta: float) -> void:
	if not visible:
		return
	var b := Basis(Vector3.UP, global_rotation.y)
	var cam: Camera3D = get_viewport().get_camera_3d()
	var close: bool = cam != null and cam.global_position.distance_squared_to(global_position) < 35.0 * 35.0
	if not close and _bags_set:
		return  # (far away: bags / tools keep their last pose)
	_bags_set = true
	if carry == CARRY_HAMMER and anim_state == Anim.IDLE and close:
		var t: float = Time.get_ticks_msec() / 1000.0 * 2.6 + float(color_seed % 100)
		var swing: float = pow(absf(sin(t)), 3.0) * 1.4  # (a quick blow, a slow lift)
		b = b * Basis(Vector3.RIGHT, -0.4 + swing)
	for h: Node3D in _bag_holders:
		if is_instance_valid(h):
			h.global_basis = b


## Hammer (right hand) or a stack of bricks (between the hands, in front of the belly).
func _build_tool(sk: Skeleton3D) -> void:
	var bone: int = sk.find_bone("Palm.R")
	if bone < 0:
		bone = sk.find_bone("Wrist.R")
	if carry == CARRY_BRICKS:
		bone = sk.find_bone("Torso")
	if bone < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_idx = bone
	sk.add_child(att)
	var holder := Node3D.new()
	att.add_child(holder)
	_bag_holders.append(holder)
	_bags.append(att)
	if carry == CARRY_HAMMER:
		var grip := MeshInstance3D.new()
		grip.mesh = _mesh("box", Vector3(0.03, 0.03, 0.3))
		grip.material_override = ProcGoods.mat(Color(0.55, 0.35, 0.18))
		grip.position = Vector3(0, 0, -0.1)
		holder.add_child(_gear(grip))
		var head := MeshInstance3D.new()
		head.mesh = _mesh("box", Vector3(0.05, 0.05, 0.13))
		head.material_override = ProcGoods.mat(Color(0.3, 0.3, 0.32))
		head.position = Vector3(0, 0, -0.25)
		head.rotation.x = PI / 2.0
		holder.add_child(_gear(head))
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = color_seed
		for k: int in 3:
			var brick := MeshInstance3D.new()
			brick.mesh = _mesh("box", Vector3(0.24, 0.07, 0.11))
			brick.material_override = ProcGoods.mat(Color(0.66, 0.28, 0.18).darkened(rng.randf() * 0.15))
			brick.position = Vector3(0, -0.12 + k * 0.075, -0.3)
			holder.add_child(_gear(brick))
	set_process(true)


## A guard's cap (the police cap mesh) on the head bone.
func _build_guard_cap() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var sk: Skeleton3D = _skeleton_of()
	if sk == null:
		return
	var head: int = sk.find_bone("Head")
	if head < 0:
		return
	var s: float = maxf(0.001, sk.global_basis.get_scale().x / global_basis.get_scale().x)
	var att := BoneAttachment3D.new()
	att.bone_idx = head
	sk.add_child(att)
	var cap := MeshInstance3D.new()
	cap.mesh = PoliceOfficer._cap_mesh()
	cap.scale = Vector3.ONE / s
	att.add_child(_gear(cap))


## Hard hat on the head (follows the head) and a hi-vis vest on the chest.
func _build_site_gear() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var sk: Skeleton3D = _skeleton_of()
	if sk == null:
		return
	var s: float = maxf(0.001, sk.global_basis.get_scale().x / global_basis.get_scale().x)
	var head: int = sk.find_bone("Head")
	if head >= 0:
		var att := BoneAttachment3D.new()
		att.bone_idx = head
		sk.add_child(att)
		var hat := Node3D.new()
		hat.scale = Vector3.ONE / s
		att.add_child(hat)
		var col: Color = [Color(0.95, 0.78, 0.1), Color(0.95, 0.95, 0.92), Color(0.95, 0.45, 0.1)][color_seed % 3]
		var dome := MeshInstance3D.new()
		dome.mesh = _mesh("ball", 0.13, 0.16)
		dome.material_override = ProcGoods.mat(col)
		dome.position = Vector3(0, 0.2, 0.0)
		hat.add_child(_gear(dome))
		var brim := MeshInstance3D.new()
		brim.mesh = _mesh("cyl", 0.155, 0.155, 0.015, 14)
		brim.material_override = ProcGoods.mat(col.darkened(0.1))
		brim.position = Vector3(0, 0.17, 0.02)
		hat.add_child(_gear(brim))
	var torso: int = sk.find_bone("Torso")
	if torso >= 0:
		var att2 := BoneAttachment3D.new()
		att2.bone_idx = torso
		sk.add_child(att2)
		var vest := Node3D.new()
		vest.scale = Vector3.ONE / s
		att2.add_child(vest)
		var body := MeshInstance3D.new()
		body.mesh = _mesh("box", Vector3(0.36, 0.34, 0.24))
		body.material_override = ProcGoods.mat(Color(0.98, 0.5, 0.08))
		body.position = Vector3(0, 0.08, 0)
		vest.add_child(_gear(body))
		for y: float in [0.0, 0.12]:
			var stripe := MeshInstance3D.new()
			stripe.mesh = _mesh("box", Vector3(0.37, 0.035, 0.245))
			stripe.material_override = ProcGoods.mat(Color(0.85, 0.88, 0.85))
			stripe.position = Vector3(0, y, 0)
			vest.add_child(_gear(stripe))


## Shared meshes for the gear (one resource per shape + size, every walker uses it).
static var _meshes: Dictionary = {}


static func _mesh(kind: String, a: Variant, b: Variant = null, c: Variant = null, d: Variant = null) -> Mesh:
	var key: String = "%s|%s|%s|%s|%s" % [kind, a, b, c, d]
	if not _meshes.has(key):
		match kind:
			"box":
				_meshes[key] = ProcGoods.box(a)
			"ball":
				_meshes[key] = ProcGoods.ball(a, -1.0 if b == null else b)
			_:
				_meshes[key] = ProcGoods.cyl(a, b, c, 10 if d == null else d)
	return _meshes[key]


## Small gear: no shadow, not drawn beyond GEAR_RANGE (performance rules).
const GEAR_RANGE: float = 70.0


static func _gear(mi: MeshInstance3D) -> MeshInstance3D:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = GEAR_RANGE
	return mi


func _build_pram() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_pram = Node3D.new()
	_pram.name = "Pram"
	add_child(_pram)
	_pram.position = Vector3(0, 0, -0.75)
	var rng := RandomNumberGenerator.new()
	rng.seed = color_seed
	var col: Color = [Color(0.15, 0.2, 0.35), Color(0.45, 0.15, 0.2), Color(0.2, 0.2, 0.22), Color(0.3, 0.45, 0.35)][rng.randi() % 4]
	var body := MeshInstance3D.new()
	body.mesh = _mesh("box", Vector3(0.45, 0.3, 0.75))
	body.material_override = ProcGoods.mat(col)
	body.position = Vector3(0, 0.62, 0)
	_pram.add_child(_gear(body))
	var hood := MeshInstance3D.new()
	hood.mesh = _mesh("ball", 0.24, 0.3)
	hood.material_override = ProcGoods.mat(col.darkened(0.2))
	hood.position = Vector3(0, 0.78, -0.22)
	_pram.add_child(_gear(hood))
	var bar := MeshInstance3D.new()
	bar.mesh = _mesh("box", Vector3(0.45, 0.03, 0.03))
	bar.material_override = ProcGoods.mat(Color(0.1, 0.1, 0.1))
	bar.position = Vector3(0, 0.98, 0.5)
	_pram.add_child(_gear(bar))
	for sx: float in [-0.2, 0.2]:
		var pole := MeshInstance3D.new()
		pole.mesh = _mesh("box", Vector3(0.025, 0.45, 0.025))
		pole.material_override = ProcGoods.mat(Color(0.1, 0.1, 0.1))
		pole.position = Vector3(sx, 0.8, 0.43)
		pole.rotation.x = -0.35
		_pram.add_child(_gear(pole))
		for sz: float in [-0.28, 0.28]:
			var wheel := MeshInstance3D.new()
			wheel.mesh = _mesh("cyl", 0.13, 0.13, 0.04, 12)
			wheel.material_override = ProcGoods.mat(Color(0.08, 0.08, 0.08))
			wheel.position = Vector3(sx * 1.15, 0.13, sz)
			wheel.rotation.z = PI / 2.0
			_pram.add_child(_gear(wheel))
