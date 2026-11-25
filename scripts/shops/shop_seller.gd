class_name ShopSeller
extends Shopkeeper
## City life point 1 (session B): the person behind the till of a bakery / snack bar / restaurant / cafe / bar /
## florist / clothing shop / kiosk (ShopStaff puts one in every enterable shop of the map). Sells like any
## Shopkeeper; a meal (ShopTypes.MEAL_HEAL) is eaten on the spot: it heals instead of going in your pockets.

## ShopTypes key ("bakery", "restaurant", ...).
@export var shop_type: String = ""


func get_interaction_prompt() -> String:
	if shop_type in ["restaurant", "cafe", "bar", "snack_bar", "bakery"]:
		return "Order from %s (%s)" % [npc_name, shop_name]
	return super.get_interaction_prompt()


func _server_buy(peer: int, id: StringName, count: int) -> void:
	if not ShopTypes.is_meal(id):
		super._server_buy(peer, id, count)
		return
	var buyer := get_tree().current_scene.get_node_or_null("Players/%d" % peer) as Player
	if buyer == null or buyer.dead:
		return
	var item: ItemData = ItemDB.get_item(id)
	var msg: String = ""
	if buyer.global_position.distance_to(global_position) > Player.INTERACT_DISTANCE + 2.0:
		msg = "You walked away."
	elif item == null or not id in stock or count < 1 or count > MAX_PER_BUY:
		msg = "\"We don't serve that here.\""
	else:
		count = mini(count, 3)  # (nobody eats more than three at once)
		var total: int = price_of(id) * count
		if not GameState.add_cash(buyer.player_name, -total, true):
			msg = "Not enough cash (€%d needed)." % total
		else:
			var heal: int = int(ShopTypes.MEAL_HEAL[id]) * count
			var before: int = buyer.health
			buyer.health = mini(Player.MAX_HEALTH, buyer.health + heal)
			buyer.send_wallet()
			print("[Shop] %s ate %dx %s at %s (+%d health) for €%d" % [buyer.player_name, count, id, npc_name,
					buyer.health - before, total])
			_answer(peer, true, "Enjoy! %s%s: +%d health, €%d." % ["" if count == 1 else "%d x " % count,
					item.display_name, buyer.health - before, total])
			return
	_answer(peer, false, msg)
