class_name Quality
extends RefCounted
## Product quality (milestone 3, session B). Tier 1 = the plain item (weed_bag), tier 2 = "<id>_q2" (Good),
## tier 3 = "<id>_q3" (Premium): separate items (tools/generators/gen_quality_items.py), so inventory, lockers,
## dealers, loot bags and the police need no changes. Quality starts at a "source" and is carried along the chain:
##   weed: GrowPot (premium seed +1, grown under a lamp +1) -> fresh_weed -> DryingRack -> weed_bud -> bag
##   meth: CookStation (Pure Reagent +1, Fume Hood next to it +1) -> meth_tray -> CoolingPlate -> meth_shard -> bag
##   coke: Refinery (Pure Solvent +1, Fume Hood +1) -> cocaine -> bag
## Higher tiers sell for more (`PRICE`): Products.price, customers asking for them (Products.pick_customer_product).

const MAX: int = 3
const TIERED: Array[String] = ["fresh_weed", "weed_bud", "weed_bag", "meth_tray", "meth_shard", "meth_bag", "cocaine", "coke_bag"]
const NAMES: Array[String] = ["", "Standard", "Good", "Premium"]
## Price factor per tier (index = tier).
const PRICE: Array[float] = [1.0, 1.0, 1.4, 1.9]


## "weed_bag_q3" -> "weed_bag" (other ids unchanged).
static func base(id: String) -> String:
	if id.length() > 3 and id[id.length() - 3] == "_" and id[id.length() - 2] == "q":
		var b: String = id.left(id.length() - 3)
		if b in TIERED:
			return b
	return id


## "weed_bag_q3" -> 3, "weed_bag" -> 1, untiered ids -> 1.
static func tier(id: String) -> int:
	var b: String = base(id)
	if b == id:
		return 1
	return clampi(id.right(1).to_int(), 1, MAX)


static func is_tiered(id: String) -> bool:
	return base(id) in TIERED


## The id of `base_id` at quality `t` (clamped 1..MAX). Untiered ids are returned unchanged.
static func with_tier(base_id: String, t: int) -> String:
	var b: String = base(base_id)
	if not b in TIERED:
		return base_id
	t = clampi(t, 1, MAX)
	return b if t == 1 else "%s_q%d" % [b, t]


## Every quality of `id`, best first (["weed_bag_q3", "weed_bag_q2", "weed_bag"]); untiered: [id].
static func variants(id: String) -> Array[String]:
	var b: String = base(id)
	if not b in TIERED:
		return [id] as Array[String]
	return [with_tier(b, 3), with_tier(b, 2), b] as Array[String]


## The best quality of `id` with at least `need` available (`count.call(variant_id) -> int`); "" if none has enough.
static func best_with(id: String, need: int, count: Callable) -> String:
	for v: String in variants(id):
		if int(count.call(v)) >= need:
			return v
	return ""


static func price_factor(id: String) -> float:
	return PRICE[tier(id)]


## "Premium" / "Good" / "" for tier 1.
static func word(id: String) -> String:
	var t: int = tier(id)
	return NAMES[t] if t > 1 else ""


## Host: remember the best quality the crew has made of a product (GameState.world["quality"][base]), so
## customers start asking for it (Products.pick_customer_product).
static func host_made(id: String) -> void:
	var t: int = tier(id)
	if t <= 1:
		return
	var q: Dictionary = GameState.world.get_or_add("quality", {})
	var b: String = product_of(id)
	if t > int(q.get(b, 1)):
		q[b] = t


## The sellable bag for a chain item: weed_bud_q2 -> weed_bag, meth_tray -> meth_bag, cocaine_q3 -> coke_bag.
static func product_of(id: String) -> String:
	var b: String = base(id)
	if b.begins_with("meth"):
		return "meth_bag"
	if b == "cocaine" or b == "coke_bag":
		return "coke_bag"
	return "weed_bag"


## Best quality the crew has made of a bag product (1 if none better yet).
static func best_made(bag_id: String) -> int:
	var q: Variant = GameState.world.get("quality")
	return int((q as Dictionary).get(base(bag_id), 1)) if q is Dictionary else 1
