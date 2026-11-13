extends Node
## Products (DESIGN "Products", milestone 3), autoload `Products`. Session B.
## - The sellable product units (bags) with their street price factor, used by dealers (Staff) and the
##   customer hook `pick_customer_product` (World/Pedestrian, session A).
## - Black-market supplies: Rook (the night-only Shopkeeper) gets the meth/cocaine supplies + stations
##   added to his stock at runtime, so the garage prefab (session A's map) stays untouched.

## Bag item id -> {name (short), price factor vs a bag of weed, rank needed for customers to ask for it}.
const BAGS: Dictionary = {
	"weed_bag": {"name": "weed", "factor": 1.0, "rank": 0},
	"meth_bag": {"name": "meth", "factor": 2.2, "rank": 2},
}
## Extra stock for the black market (appended once, in this order).
const BLACK_MARKET_EXTRA: Array[StringName] = [&"lab_chemicals", &"activator", &"cook_station", &"cooling_plate"]
## Chance that a new customer wants meth instead of weed once the crew reaches its rank.
const METH_CUSTOMER_CHANCE: float = 0.35


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is Shopkeeper and (n as Shopkeeper).night_only:
		add_black_market_stock(n as Shopkeeper)


func add_black_market_stock(k: Shopkeeper) -> void:
	for id: StringName in BLACK_MARKET_EXTRA:
		if not id in k.stock:
			k.stock.append(id)


func is_bag(id: String) -> bool:
	return BAGS.has(id)


func bag_ids() -> Array:
	return BAGS.keys()


func short_name(id: String) -> String:
	return str((BAGS.get(id, {}) as Dictionary).get("name", id))


## Street price of one bag of `id` where a bag of weed goes for `weed_price`.
func price(id: String, weed_price: int) -> int:
	return roundi(weed_price * float((BAGS.get(id, {}) as Dictionary).get("factor", 1.0)))


## Host: what a new customer asks for ("weed_bag" / "meth_bag"). For session A's customer code
## (World.make_customer -> Pedestrian.product): meth only once the crew reached rank 2.
func pick_customer_product() -> String:
	var choices: Array = []
	for id: String in BAGS:
		if Progression.rank() >= int(BAGS[id]["rank"]):
			choices.append(id)
	if choices.has("meth_bag") and randf() < METH_CUSTOMER_CHANCE:
		return "meth_bag"
	return "weed_bag"
