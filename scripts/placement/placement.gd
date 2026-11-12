class_name Placement
extends RefCounted
## Point 6: shared rules for placing stations and furniture (client ghost + host check).
## A placeable item (ItemData.place_scene) goes on a floor or table top inside a
## property the crew owns, without overlapping walls, furniture, stations or people.

const GRID: float = 0.25
const MAX_REACH: float = 5.0
## Mask for "something is in the way": world, props, npcs, players.
const BLOCK_MASK: int = 1 | 2 | 4 | 8

static var _shapes: Dictionary = {}


## Collision boxes of a placeable in its own space: [{xform: Transform3D, size: Vector3}] (cached per id).
static func shapes(item: ItemData) -> Array:
	if _shapes.has(item.id):
		return _shapes[item.id]
	var out: Array = []
	if STATION_BOXES.has(String(item.id)):
		for b: Array in STATION_BOXES[String(item.id)]:
			out.append({"xform": Transform3D(Basis.IDENTITY, b[0]), "size": b[1]})
	else:
		var inst: Node3D = item.place_scene.instantiate() as Node3D
		for n: Node in inst.find_children("*", "CollisionShape3D", true, false):
			var cs := n as CollisionShape3D
			if cs.shape == null:
				continue
			var a: AABB = _shape_box(cs.shape)
			out.append({"xform": _relative(inst, cs) * Transform3D(Basis.IDENTITY, a.get_center()), "size": a.size})
		inst.free()
	if out.is_empty():
		out.append({"xform": Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0)), "size": Vector3(0.6, 0.8, 0.6)})
	_shapes[item.id] = out
	return out


## Local bounding box of all collision boxes.
static func local_box(item: ItemData) -> AABB:
	var box := AABB()
	var first: bool = true
	for s: Dictionary in shapes(item):
		var a: AABB = (s["xform"] as Transform3D) * AABB(-(s["size"] as Vector3) * 0.5, s["size"])
		box = a if first else box.merge(a)
		first = false
	return box


## Collision of the procedural stations (made in code): [[centre, size], ...]. The grow lamp
## only counts its posts and top bar, so pots fit underneath.
const STATION_BOXES: Dictionary = {
	"grow_pot": [[Vector3(0, 0.15, 0), Vector3(0.34, 0.3, 0.34)]],
	"grow_lamp": [[Vector3(-0.65, 0.875, 0), Vector3(0.05, 1.75, 0.5)], [Vector3(0.65, 0.875, 0), Vector3(0.05, 1.75, 0.5)],
			[Vector3(0, 1.73, 0), Vector3(1.33, 0.04, 0.04)]],
	"drying_rack": [[Vector3(0, 0.8, 0), Vector3(1.14, 1.6, 0.46)]],
	"packaging_table": [[Vector3(0, 0.41, 0), Vector3(1.0, 0.82, 0.55)]],
	"storage_locker": [[Vector3(0, 0.95, 0), Vector3(0.9, 1.9, 0.5)]],
}


static func _shape_box(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var s: Vector3 = (shape as BoxShape3D).size
		return AABB(-s * 0.5, s)
	if shape is CylinderShape3D:
		var c := shape as CylinderShape3D
		return AABB(Vector3(-c.radius, -c.height * 0.5, -c.radius), Vector3(c.radius * 2, c.height, c.radius * 2))
	if shape is CapsuleShape3D:
		var k := shape as CapsuleShape3D
		return AABB(Vector3(-k.radius, -k.height * 0.5, -k.radius), Vector3(k.radius * 2, k.height, k.radius * 2))
	return shape.get_debug_mesh().get_aabb()


static func _relative(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


## The owned-by-the-crew property that contains `pos`, or null.
static func property_at(tree: SceneTree, pos: Vector3) -> Property:
	for n: Node in tree.get_nodes_in_group(&"properties"):
		var p := n as Property
		if p and p.contains(pos):
			return p
	return null


## "" when `item` can stand at `pos` (floor point) turned by `yaw`; otherwise why not.
## `ignore` = bodies to leave out of the overlap test (the placing player).
static func check(world: World3D, tree: SceneTree, item: ItemData, pos: Vector3, yaw: float,
		ignore: Array[RID] = []) -> String:
	if item == null or item.place_scene == null:
		return "You can't place that."
	var prop: Property = property_at(tree, pos)
	if prop == null:
		return "Only inside a property you own."
	if not prop.is_crew_owned():
		return "This isn't your property."
	var box: AABB = local_box(item)
	var space := world.direct_space_state
	# Something must carry it: the floor (small things also a table top) right below.
	var down := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.25, pos + Vector3.DOWN * 0.08, support_mask(item))
	down.exclude = ignore
	var hit: Dictionary = space.intersect_ray(down)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.8:
		return "It needs a floor to stand on."
	# Nothing in the way (walls, furniture, people): each collision box, lifted off the floor a little.
	var basis := Basis(Vector3.UP, yaw)
	var place := Transform3D(basis, pos + Vector3.UP * 0.03)
	for s: Dictionary in shapes(item):
		var size: Vector3 = s["size"]
		var shape := BoxShape3D.new()
		shape.size = Vector3(maxf(0.03, size.x - 0.04), maxf(0.03, size.y - 0.06), maxf(0.03, size.z - 0.04))
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.collision_mask = BLOCK_MASK
		q.exclude = ignore
		q.transform = place * (s["xform"] as Transform3D)
		if not space.intersect_shape(q, 1).is_empty():
			return "Something is in the way."
	# The whole footprint stays inside the property.
	for corner: Vector3 in [Vector3(box.position.x, 0, box.position.z), Vector3(box.end.x, 0, box.position.z),
			Vector3(box.position.x, 0, box.end.z), Vector3(box.end.x, 0, box.end.z)]:
		if not prop.contains(pos + basis * corner + Vector3.UP * 0.1):
			return "It doesn't fit here."
	return ""


## Small things (TV, plant, pot, register) may stand on furniture; big ones only on the floor.
static func is_small(item: ItemData) -> bool:
	var box: AABB = local_box(item)
	return box.size.x <= 0.7 and box.size.z <= 0.7


## Physics layers that can carry `item`: world (floors) + props (table tops) for small things.
static func support_mask(item: ItemData) -> int:
	return (1 | 2) if is_small(item) else 1


## Client ghost: where the item would go when looking along `from` -> `dir`. Returns
## {pos: Vector3} or {} (nothing in reach). Snaps x/z to GRID, y to the surface below
## (`support` = layers it may stand on, see support_mask).
static func aim_point(world: World3D, from: Vector3, dir: Vector3, ignore: Array[RID], support: int = 1 | 2) -> Dictionary:
	var space := world.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * MAX_REACH, 1 | 2)
	q.exclude = ignore
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return {}
	var p: Vector3 = hit["position"]
	var n: Vector3 = hit["normal"]
	if n.y < 0.7:
		p += n * 0.3  # aimed at a wall: in front of it
	p.x = snappedf(p.x, GRID)
	p.z = snappedf(p.z, GRID)
	var down := PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y + 0.4, p.z), Vector3(p.x, p.y - 2.5, p.z), support)
	down.exclude = ignore
	var floor_hit: Dictionary = space.intersect_ray(down)
	if floor_hit.is_empty():
		return {}
	return {"pos": floor_hit["position"]}
