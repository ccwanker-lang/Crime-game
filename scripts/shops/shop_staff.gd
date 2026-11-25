class_name ShopStaff
extends RefCounted
## City life point 1 (session B, 2026-11-25): a seller behind the till of every enterable shop of the map. Runs on
## every peer the same way when a World loads (Zones._on_world), so each seller sits at the same node path
## everywhere (like the hand-placed Shopkeepers in the prefabs).
## A till = a Marker3D "ShopkeeperSpot*" (A can put one in any prefab; meta "shop_type" optional: the seller stands
## ON the marker and looks along its -Z), or else a cash register (Building's shop furniture / the bakery's
## Register): the seller stands 0.75 m behind it, facing the shop's front. The kind of shop comes from
## ShopTypes.type_for (meta / shop sign / name); buildings that already have a Shopkeeper (store, gun shop, ...) or
## a trade of their own (barber, laundromat) get nobody.

const SCENE: String = "res://prefabs/npc/shop_seller.tscn"
const BEHIND: float = 0.75
const SIDE: float = 0.6

## Every seller made for the current World (tests).
static var sellers: Array[ShopSeller] = []


static func populate(world: Node) -> void:
	sellers.clear()
	if world == null or not world.is_inside_tree():
		return
	for i: int in 4:
		await world.get_tree().physics_frame  # (the furniture's collision must be in the space for the floor ray)
	if not is_instance_valid(world):
		return
	var spots: Array = []  # [path string, till node, building, type]
	var done: Dictionary = {}
	for n: Node in world.find_children("*", "Node3D", true, false):
		var marker: bool = n is Marker3D and str(n.name).begins_with("ShopkeeperSpot")
		var till: bool = str(n.scene_file_path).ends_with("cash_register.tscn") or (n.name == &"Register" and n.scene_file_path != "")
		if not marker and not till:
			continue
		var b: Node = _building_of(n)
		if b == null or done.has(b):
			continue
		if _has_shopkeeper(b):
			continue
		var type: String = ShopTypes.type_for(b, n if marker else null)
		if type == "" or type == "-" or ShopTypes.info(type).is_empty():
			continue
		done[b] = true
		spots.append([str(n.get_path()), n, b, type, marker])
	spots.sort_custom(func(a: Array, c: Array) -> bool: return a[0] < c[0])
	for s: Array in spots:
		var seller: ShopSeller = _make(world, s[1], s[2], s[3], s[4])
		if seller:
			sellers.append(seller)
	if not sellers.is_empty():
		print("[ShopStaff] %d sellers: %s" % [sellers.size(), ", ".join(sellers.map(func(x: ShopSeller) -> String:
				return "%s (%s)" % [x.npc_name, x.shop_name]))])


## The building (prefab root) a till belongs to: the nearest ancestor with a shop sign / shop type, else the
## nearest one that is a Building or a prefab instance.
static func _building_of(n: Node) -> Node:
	var p: Node = n.get_parent()
	var first: Node = null
	for i: int in 5:
		if p == null or p is Window:
			break
		if p.has_meta(&"shop_type") or p is Building or p.scene_file_path.begins_with("res://prefabs/buildings/"):
			return p
		if first == null and p.scene_file_path != "":
			first = p
		p = p.get_parent()
	return first


static func _has_shopkeeper(b: Node) -> bool:
	for c: Node in b.find_children("*", "Node3D", true, false):
		if c is Shopkeeper:
			return true
	return false


static func _make(world: Node, till: Node3D, b: Node3D, type: String, marker: bool) -> ShopSeller:
	var info: Dictionary = ShopTypes.info(type)
	var h: int = absi(hash(str(b.get_path())))
	var front: Vector3 = b.global_basis.z
	front.y = 0.0
	front = front.normalized() if front.length() > 0.01 else Vector3.BACK
	var pos: Vector3
	var look: Vector3 = front
	if marker:
		pos = till.global_position
		look = -till.global_basis.z
		look.y = 0.0
		look = look.normalized()
	else:
		pos = till.global_position - front * BEHIND
		# A bit to the side, towards the middle of the shop: the register itself must not hide the seller.
		var side: Vector3 = b.global_basis.x.normalized()
		var lx: float = b.to_local(till.global_position).x
		pos += side * clampf(-lx, -SIDE, SIDE)
		var space: PhysicsDirectSpaceState3D = (world as Node3D).get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.3, pos + Vector3.DOWN * 3.0, 1)
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			return null
		pos = hit["position"]
	var seller := (load(SCENE) as PackedScene).instantiate() as ShopSeller
	seller.name = "ShopSeller"
	seller.shop_type = type
	seller.npc_name = (info["names"] as Array)[h % (info["names"] as Array).size()]
	seller.shop_name = str(b.get(&"shop_sign")).capitalize() if str(b.get(&"shop_sign")) not in ["", "<null>"] else str(info["shop"])
	seller.greeting = info["greeting"]
	seller.stock.assign(info["stock"])
	seller.variant = (info["variants"] as Array)[h % 2]
	seller.color_seed = h % 100000
	b.add_child(seller)
	seller.global_position = pos
	seller.global_rotation = Vector3(0, atan2(-look.x, -look.z), 0)  # (the model looks along -Z)
	return seller
