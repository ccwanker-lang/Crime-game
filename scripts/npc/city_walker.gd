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

enum Role { WALK, SHOPPER, JOGGER, PRAM, DOG }

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
var _bag_holders: Array[Node3D] = []  # (kept hanging straight down, see _process)
var _pram: Node3D = null


func _ready() -> void:
	ambient = false
	super._ready()
	add_to_group(&"city_walkers")
	if role == Role.PRAM:
		_build_pram()
	_build_bags()
	_apply_inside()


## Customers stand still; walkers with a pram or a dog, joggers and someone inside a shop don't deal.
func can_be_customer() -> bool:
	return role in [Role.WALK, Role.SHOPPER] and not inside and not shopping


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
		var front: Vector3 = (door.get_center() + door.get_outward() * 1.4) if door else s.global_position - s.global_basis.z * 4.0
		out.append({"seller": s, "door": door, "front": front, "type": s.shop_type})
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
	set_process(false)
	if carry <= 0 or DisplayServer.get_name() == "headless":
		return
	var sk: Skeleton3D = _skeleton_of()
	if sk == null:
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
		body.mesh = ProcGoods.box(Vector3(0.28, 0.32, 0.12))
		body.material_override = ProcGoods.mat(col)
		body.position = Vector3(0, -0.2, 0.0)  # (below the hand)
		bag.add_child(body)
		var handle := MeshInstance3D.new()
		handle.mesh = ProcGoods.box(Vector3(0.12, 0.08, 0.015))
		handle.material_override = ProcGoods.mat(col.darkened(0.3))
		handle.position = Vector3(0, -0.04, 0)
		bag.add_child(handle)
		_bags.append(att)
	set_process(not _bags.is_empty())


## Bags hang straight down from the hand whatever the arm does (metres, upright, facing the walk direction).
func _process(_delta: float) -> void:
	if not visible:
		return
	var b := Basis(Vector3.UP, global_rotation.y)
	for h: Node3D in _bag_holders:
		if is_instance_valid(h):
			h.global_basis = b


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
	body.mesh = ProcGoods.box(Vector3(0.45, 0.3, 0.75))
	body.material_override = ProcGoods.mat(col)
	body.position = Vector3(0, 0.62, 0)
	_pram.add_child(body)
	var hood := MeshInstance3D.new()
	hood.mesh = ProcGoods.ball(0.24, 0.3)
	hood.material_override = ProcGoods.mat(col.darkened(0.2))
	hood.position = Vector3(0, 0.78, -0.22)
	_pram.add_child(hood)
	var bar := MeshInstance3D.new()
	bar.mesh = ProcGoods.box(Vector3(0.45, 0.03, 0.03))
	bar.material_override = ProcGoods.mat(Color(0.1, 0.1, 0.1))
	bar.position = Vector3(0, 0.98, 0.5)
	_pram.add_child(bar)
	for sx: float in [-0.2, 0.2]:
		var pole := MeshInstance3D.new()
		pole.mesh = ProcGoods.box(Vector3(0.025, 0.45, 0.025))
		pole.material_override = ProcGoods.mat(Color(0.1, 0.1, 0.1))
		pole.position = Vector3(sx, 0.8, 0.43)
		pole.rotation.x = -0.35
		_pram.add_child(pole)
		for sz: float in [-0.28, 0.28]:
			var wheel := MeshInstance3D.new()
			wheel.mesh = ProcGoods.cyl(0.13, 0.13, 0.04, 12)
			wheel.material_override = ProcGoods.mat(Color(0.08, 0.08, 0.08))
			wheel.position = Vector3(sx * 1.15, 0.13, sz)
			wheel.rotation.z = PI / 2.0
			_pram.add_child(wheel)
