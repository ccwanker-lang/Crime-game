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


func prompt_for(player: Player) -> String:
	var buds: int = carried(player, "weed_bud")
	var bags: int = carried(player, "baggie")
	if buds > 0 and bags > 0:
		return "Package %d Bag%s of Weed" % [mini(buds, bags), "" if mini(buds, bags) == 1 else "s"]
	if buds > 0:
		return "Packaging table - you need Baggies (store)"
	return "Packaging table - bring Dried Weed + Baggies"


func do_action(player: Player) -> String:
	var who: String = player.player_name
	var n: int = mini(GameState.count_item(who, "weed_bud"), GameState.count_item(who, "baggie"))
	if n <= 0:
		return "You need Dried Weed and Baggies to package."
	GameState.remove_item(who, "weed_bud", n)
	GameState.remove_item(who, "baggie", n)
	var left: Array = GameState.give(who, 0, [{"id": "weed_bag", "count": n}])
	var not_packed: int = 0
	for it: Dictionary in left:
		not_packed += int(it.get("count", 0))
	if not_packed > 0:
		# Pockets full: give back what couldn't be packed.
		GameState.give(who, 0, [{"id": "weed_bud", "count": not_packed}, {"id": "baggie", "count": not_packed}])
	var packed: int = n - not_packed
	if packed <= 0:
		return "Your pockets are full."
	work = "pack"
	return "Packaged %d Bag%s of Weed." % [packed, "" if packed == 1 else "s"]
