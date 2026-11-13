class_name PackagingTable
extends Station
## Work table with a scale and a tub of baggies. E packs the Dried Weed you carry
## into Bags of Weed: 1 Dried Weed + 1 Baggie (store) -> 1 Bag of Weed, as many
## as you can at once. Bags are what customers buy.

const WIDTH: float = 1.0
const DEPTH: float = 0.55
const HEIGHT: float = 0.82


func _build() -> void:
	var b := MeshBuilder.new()
	var hw: float = WIDTH * 0.5
	var hd: float = DEPTH * 0.5
	b.box(&"planks", Vector3(0, HEIGHT - 0.02, 0), Vector3(WIDTH, 0.04, DEPTH), 0.005)
	for x: float in [-hw + 0.04, hw - 0.04]:
		for z: float in [-hd + 0.04, hd - 0.04]:
			b.box(&"metal_dark", Vector3(x, (HEIGHT - 0.04) * 0.5, z), Vector3(0.035, HEIGHT - 0.04, 0.035))
	b.box(&"metal_dark", Vector3(0, 0.18, 0), Vector3(WIDTH - 0.08, 0.02, DEPTH - 0.08))  # shelf
	var top: float = HEIGHT
	# Digital scale: dark base + metal plate.
	b.box_mm(&"metal_dark", Vector3(-0.12, top, -0.1), Vector3(0.08, top + 0.03, 0.08), 0.004)
	b.box_mm(&"zinc", Vector3(-0.1, top + 0.03, -0.085), Vector3(0.06, top + 0.036, 0.065))
	# Tub of empty baggies and a few filled ones.
	b.cylinder(&"pot_plastic", Vector3(0.32, top, -0.08), Vector3(0.32, top + 0.09, -0.08), 0.08, 0.09, 12, true)
	for i: int in 4:
		var x: float = -0.38 + i * 0.06
		b.box_mm(&"glass_clear", Vector3(x, top, 0.08), Vector3(x + 0.05, top + 0.012, 0.15))
		b.box_mm(&"hedge_core", Vector3(x + 0.01, top + 0.002, 0.09), Vector3(x + 0.04, top + 0.01, 0.13))
	# Small pile of buds on the scale.
	b.box_mm(&"hedge_core", Vector3(-0.06, top + 0.036, -0.04), Vector3(0.02, top + 0.06, 0.03), 0.01)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, HEIGHT, DEPTH)
	cs.shape = shape
	cs.position.y = HEIGHT * 0.5
	add_child(cs)


## Product -> packaged unit (milestone 3: meth; cocaine later). 1 product + 1 baggie -> 1 bag.
const PACKS: Array = [["weed_bud", "weed_bag"], ["meth_shard", "meth_bag"]]


func prompt_for(player: Player) -> String:
	var bags: int = carried(player, "baggie")
	var parts: PackedStringArray = []
	var any_product: bool = false
	for pk: Array in PACKS:
		var have: int = carried(player, pk[0])
		if have <= 0:
			continue
		any_product = true
		var n: int = mini(have, bags)
		bags -= n
		if n > 0:
			parts.append(_bags(n, pk[1]))
	if not parts.is_empty():
		return "Package " + " + ".join(parts)
	if any_product:
		return "Packaging table - you need Baggies (store)"
	return "Packaging table - bring Dried Weed / Meth Shards + Baggies"


func do_action(player: Player) -> String:
	var who: String = player.player_name
	var done: PackedStringArray = []
	var full: bool = false
	for pk: Array in PACKS:
		var n: int = mini(GameState.count_item(who, pk[0]), GameState.count_item(who, "baggie"))
		if n <= 0:
			continue
		GameState.remove_item(who, pk[0], n)
		GameState.remove_item(who, "baggie", n)
		var left: Array = GameState.give(who, 0, [{"id": pk[1], "count": n}])
		var not_packed: int = 0
		for it: Dictionary in left:
			not_packed += int(it.get("count", 0))
		if not_packed > 0:
			# Pockets full: give back what couldn't be packed.
			GameState.give(who, 0, [{"id": pk[0], "count": not_packed}, {"id": "baggie", "count": not_packed}])
			full = true
		var packed: int = n - not_packed
		if packed > 0:
			done.append(_bags(packed, pk[1]))
	if done.is_empty():
		return "Your pockets are full." if full else "You need Dried Weed or Meth Shards, and Baggies, to package."
	work = "pack"
	return "Packaged %s." % " + ".join(done)


## "1 Bag of Weed" / "3 Bags of Weed".
static func _bags(n: int, id: String) -> String:
	var name: String = item_name(id)
	if n != 1 and name.begins_with("Bag "):
		name = "Bags " + name.trim_prefix("Bag ")
	return "%d %s" % [n, name]
