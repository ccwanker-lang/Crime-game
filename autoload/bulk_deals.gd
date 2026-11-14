extends Node
## Bulk deals (DESIGN "Progression" rank 4 Boss: "bulk deals"; Products: "selling ... bulk"), autoload `BulkDeals`.
## Session B. HOST AUTHORITATIVE. State in GameState.world["bulk"] = {offer: {} or {id, product, bags, price, pos,
## yaw, district, until, name}, next (in-game clock of the next offer), time (in-game hours), done, missed}.
## - From rank 4, every OFFER_EVERY in-game hours (random spread) the bulk buyer texts the crew: N bags of a product
##   for one total price (BULK_DISCOUNT below the street price, but all at once), waiting in a district until `until`.
## - Every peer shows him (BulkBuyerNPC, local, synced offer). E on him with enough bags in your pockets ->
##   `request_sell()` -> host `host_sell(p)`: distance, bags, pay (dirty cash), XP, offer gone.
## - Not met in time: a text, the offer is gone (`missed` + 1).

const RANK: int = 4
const CONTACT: String = "The Dutchman (bulk)"
## In-game hours between offers (base, + up to OFFER_SPREAD) and how long the buyer waits.
const OFFER_EVERY: float = 20.0
const OFFER_SPREAD: float = 10.0
const WAIT_HOURS: float = 6.0
const BAG_COUNTS: Array[int] = [20, 25, 30, 40]
## Part of the street price the buyer pays per bag (he takes a lot at once).
const BULK_DISCOUNT: float = 0.8
const XP_PER_BAG: int = 6
const MEET_RANGE: float = 4.0
const NAMES: Array[String] = ["Henk", "Joop", "Bram"]

## Host: random offers on/off (off in --selftest so other checks get no surprise texts; the bulk check turns it on).
var enabled: bool = not "--selftest" in OS.get_cmdline_user_args()
## Every peer: the current offer ({} = none), synced by the host.
var offer: Dictionary = {}
var _view: Node3D = null


func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _data() -> Dictionary:
	var d: Variant = GameState.world.get("bulk")
	if not d is Dictionary:
		d = {"offer": {}, "next": OFFER_EVERY, "time": 0.0, "done": 0, "missed": 0}
		GameState.world["bulk"] = d
	return d


func _process(delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null or scene.get_node_or_null("Players") == null:
		_view = null
		offer = {}
		return
	_update_view(scene)
	if not _is_host() or GameState.world.is_empty():
		return
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	if dn:
		tick(delta * dn.hours_per_second())


## Host: in-game hours pass.
func tick(hours: float) -> void:
	var d: Dictionary = _data()
	d["time"] = float(d.get("time", 0.0)) + hours
	var now: float = float(d["time"])
	var o: Dictionary = d["offer"]
	if not o.is_empty():
		if now >= float(o["until"]):
			d["offer"] = {}
			d["missed"] = int(d.get("missed", 0)) + 1
			_text_crew("Waited for nothing. Next time be on time.")
			print("[Bulk] offer expired")
			sync()
		elif offer.is_empty():
			sync()  # (after loading a save)
		return
	if not enabled or now < float(d.get("next", OFFER_EVERY)) or Progression.rank() < RANK:
		return
	new_offer()


## Host: a new offer now (also tests/scenarios: `product`/`bags`/`at` override the random pick).
func new_offer(product: String = "", bags: int = 0, at: Vector3 = Vector3.INF, yaw: float = 0.0) -> Dictionary:
	var d: Dictionary = _data()
	if product == "":
		var choices: Array = []
		for id: String in Products.BAGS:
			if Progression.rank() >= int(Products.BAGS[id]["rank"]):
				choices.append(id)
		product = choices.pick_random() if not choices.is_empty() else "weed_bag"
	if bags <= 0:
		bags = BAG_COUNTS.pick_random()
	var district: String = ""
	if at == Vector3.INF:
		var ids: Array = Staff.config.districts.keys()
		district = ids.pick_random()
		var spot: Array = _meet_spot(district)
		at = spot[0]
		yaw = spot[1]
	var weed: int = int(Staff.config.districts.get(district, {"price": 60}).get("price", 60)) if district != "" else 60
	var total: int = roundi(Products.price(product, weed) * BULK_DISCOUNT * bags / 10.0) * 10
	var o: Dictionary = {"id": str(randi()), "product": product, "bags": bags, "price": total, "pos": at, "yaw": yaw,
			"district": district, "until": float(d["time"]) + WAIT_HOURS, "name": NAMES.pick_random()}
	d["offer"] = o
	d["next"] = float(d["time"]) + OFFER_EVERY + randf() * OFFER_SPREAD
	var where: String = str(Staff.config.districts[district]["name"]) if district != "" else "town"
	_text_crew("I take %d bags of %s off your hands at once: €%d for the lot. %s, I wait %d hours. Bring them in your pockets." % [
			bags, Products.short_name(product), total, where, roundi(WAIT_HOURS)])
	print("[Bulk] offer: %d x %s for €%d at %s" % [bags, product, total, at])
	sync()
	return o


## A spot on the pavement near the district's anchor, a few metres from where a dealer would stand.
func _meet_spot(district: String) -> Array:
	var anchor: Vector3 = Staff.config.districts[district]["anchor"]
	var want: Vector3 = anchor + Vector3(7.0, 0.0, 0.0)
	var world := get_tree().current_scene as Node3D
	if world:
		var map: RID = world.get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			var p: Vector3 = NavigationServer3D.map_get_closest_point(map, want)
			if p.distance_to(want) < 8.0:
				want = p
	var yaw: float = 0.0 if anchor.z > 0.0 else PI
	if absf(anchor.z) > 40.0:
		yaw = PI if anchor.z > 0.0 else 0.0
	return [want, yaw]


## Host: `p` hands over the bags. Returns the answer text ("!" = refused).
func host_sell(p: Player) -> String:
	var o: Dictionary = _data()["offer"]
	if o.is_empty():
		return "!Nobody is waiting for a bulk deal."
	if p.global_position.distance_to(o["pos"]) > MEET_RANGE:
		return "!Go to the buyer first."
	var product: String = str(o["product"])
	var bags: int = int(o["bags"])
	var have: int = GameState.count_item(p.player_name, product)
	if have < bags:
		return "!\"%d bags of %s, I said. You have %d.\"" % [bags, Products.short_name(product), have]
	GameState.remove_item(p.player_name, product, bags)
	GameState.add_cash(p.player_name, int(o["price"]))
	p.send_wallet()
	var d: Dictionary = _data()
	d["offer"] = {}
	d["done"] = int(d.get("done", 0)) + 1
	Progression.host_add(bags * XP_PER_BAG, "bulk deal", p)
	print("[Bulk] %s sold %d x %s for €%d" % [p.player_name, bags, product, int(o["price"])])
	sync()
	return "Sold %d bags of %s in one go: €%d." % [bags, Products.short_name(product), int(o["price"])]


# --- Requests + sync -----------------------------------------------------------------------

## Owner: sell to the waiting buyer (E on him).
func request_sell() -> void:
	if _is_host():
		_answer(host_sell(_local_player()))
	else:
		_request_sell.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_sell() -> void:
	if not multiplayer.is_server():
		return
	var peer: int = multiplayer.get_remote_sender_id()
	var p := get_tree().current_scene.get_node_or_null("Players/%d" % peer) as Player
	if p and not p.dead:
		_answer_rpc.rpc_id(peer, host_sell(p))


@rpc("authority", "call_remote", "reliable")
func _answer_rpc(text: String) -> void:
	_answer(text)


func _answer(text: String) -> void:
	var me: Player = _local_player()
	if me and me.ui and text != "":
		me.ui.toast(text.trim_prefix("!"))


## Host: send the offer to every peer (also on a late join via Staff._broadcast).
func sync() -> void:
	if not _is_host():
		return
	offer = (_data()["offer"] as Dictionary).duplicate() if not GameState.world.is_empty() else {}
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_sync.rpc(offer)


@rpc("authority", "call_remote", "reliable")
func _sync(o: Dictionary) -> void:
	offer = o


## Every peer: the buyer stands where the offer says (local visual).
func _update_view(scene: Node) -> void:
	var want: String = str(offer.get("id", ""))
	if _view and is_instance_valid(_view) and (_view as BulkBuyerNPC).offer_id == want:
		return
	if _view and is_instance_valid(_view):
		_view.queue_free()
	_view = null
	if want == "":
		return
	var npc := BulkBuyerNPC.new()
	npc.offer_id = want
	scene.add_child(npc)
	npc.show_offer(offer)
	_view = npc


func _text_crew(text: String) -> void:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if n is Player:
			(n as Player).phone_message(CONTACT, text, "")


func _local_player() -> Player:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if n is Player and (n as Player).is_local():
			return n as Player
	return null
