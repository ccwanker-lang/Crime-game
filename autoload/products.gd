extends Node
## Products (DESIGN "Products", milestone 3), autoload `Products`. Session B.
## - The sellable product units (bags) with their street price factor, used by dealers (Staff) and the
##   customer hook `pick_customer_product` (World/Pedestrian, session A).
## - Black-market supplies: Rook (the night-only Shopkeeper) gets the meth/cocaine supplies + stations
##   added to his stock at runtime, so the garage prefab (session A's map) stays untouched. Shops that sell the
##   storage locker get the staff locker (NOTES part 12) the same way.

## Bag item id -> {name (short), price factor vs a bag of weed, rank needed for customers to ask for it}.
const BAGS: Dictionary = {
	"weed_bag": {"name": "weed", "factor": 1.0, "rank": 0},
	"meth_bag": {"name": "meth", "factor": 2.2, "rank": 2},
	"coke_bag": {"name": "cocaine", "factor": 3.6, "rank": 4},
}
## Extra stock for the black market (appended once, in this order).
const BLACK_MARKET_EXTRA: Array[StringName] = [&"lab_chemicals", &"activator", &"cook_station", &"cooling_plate",
		&"coca_seedling", &"process_fluid", &"coca_bed", &"leaf_press", &"refinery",
		&"premium_seed", &"pure_reagent", &"fume_hood", &"pure_solvent"]
## Chance that a new customer wants meth instead of weed once the crew reaches its rank.
const METH_CUSTOMER_CHANCE: float = 0.35
## Chance that a new customer wants cocaine once the crew reaches rank 4 (checked before meth).
const COKE_CUSTOMER_CHANCE: float = 0.2


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is Shopkeeper and (n as Shopkeeper).night_only:
		add_black_market_stock(n as Shopkeeper)
	elif n is Shopkeeper and &"storage_locker" in (n as Shopkeeper).stock and not &"staff_locker" in (n as Shopkeeper).stock:
		# NOTES part 12: whoever sells storage lockers sells the staff locker too (no prefab change).
		(n as Shopkeeper).stock.append(&"staff_locker")


func add_black_market_stock(k: Shopkeeper) -> void:
	for id: StringName in BLACK_MARKET_EXTRA:
		if not id in k.stock:
			k.stock.append(id)


func is_bag(id: String) -> bool:
	return BAGS.has(Quality.base(id))


## Every sellable bag id, every quality (best first per product).
func bag_ids() -> Array:
	var out: Array = []
	for b: String in BAGS:
		out.append_array(Quality.variants(b))
	return out


## "weed", "good meth", "premium cocaine".
func short_name(id: String) -> String:
	var n: String = str((BAGS.get(Quality.base(id), {}) as Dictionary).get("name", id))
	var w: String = Quality.word(id)
	return (w.to_lower() + " " + n) if w != "" else n


## Street price of one bag of `id` (any quality) where a bag of standard weed goes for `weed_price`.
func price(id: String, weed_price: int) -> int:
	return roundi(weed_price * float((BAGS.get(Quality.base(id), {}) as Dictionary).get("factor", 1.0)) * Quality.price_factor(id))


## Share of new customers asking for the best quality the crew has made (once it made better than standard);
## the rest ask one step lower (or standard).
const BEST_QUALITY_CHANCE: float = 0.5


## Host: what a new customer asks for ("weed_bag" / "meth_bag_q2"...). For session A's customer code
## (World.make_customer -> Pedestrian.product): meth only once the crew reached rank 2, cocaine rank 4;
## better quality once the crew has made it (Quality.best_made) - those customers pay more (`price`).
func pick_customer_product() -> String:
	var choices: Array = []
	for id: String in BAGS:
		if Progression.rank() >= int(BAGS[id]["rank"]):
			choices.append(id)
	var product: String = "weed_bag"
	if choices.has("coke_bag") and randf() < COKE_CUSTOMER_CHANCE:
		product = "coke_bag"
	elif choices.has("meth_bag") and randf() < METH_CUSTOMER_CHANCE:
		product = "meth_bag"
	return pick_quality(product)


## Host: the quality a buyer of `bag_id` asks for (see BEST_QUALITY_CHANCE).
func pick_quality(bag_id: String) -> String:
	var best: int = Quality.best_made(bag_id)
	if best <= 1:
		return bag_id
	var t: int = best if randf() < BEST_QUALITY_CHANCE else randi_range(1, best - 1)
	return Quality.with_tier(bag_id, t)
