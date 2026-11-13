extends Node
## Lawyer + bribes (DESIGN "Progression": rank 4 lawyer, rank 5 bribe the police), autoload `Legal`. Session B.
## HOST AUTHORITATIVE, state in GameState.world["legal"] = {lawyer: "" or hiring player, clock: in-game hours}.
## - Lawyer on retainer (rank 4): a daily fee; when a crew member is arrested the lawyer gets part of the
##   fine back and half of the confiscated goods (`on_player_arrested`, called by the arrest hook in
##   Player.host_arrest - session A - or by tests).
## - Bribe (rank 5): pay the corrupt cop per wanted star -> `Wanted.clear(p, "bribe")`. Cooldown per player.
## Requests come in through `Staff.request("lawyer_hire" | "lawyer_fire" | "bribe")` (same answer signal).

const LAWYER: String = "Mr. Hale (lawyer)"
const COP: String = "Dekker (police)"
const LAWYER_RANK: int = 4
const BRIBE_RANK: int = 5
## Retainer, € per in-game day (first day at hiring).
const LAWYER_FEE: int = 400
## Part of the fine the lawyer gets back, part of every confiscated stack that comes back.
const FINE_BACK: float = 0.6
const GOODS_BACK: float = 0.5
## Bribe price per star, and in-game hours before the same player can bribe again.
const BRIBE_PER_STAR: int = 1500
const BRIBE_COOLDOWN: float = 6.0

## Every peer: who hired the crew's lawyer ("" = none), synced by the host (`sync`).
var lawyer: String = ""
var _bribed_at: Dictionary = {}  # host: player name -> in-game clock of the last bribe


func _data() -> Dictionary:
	var d: Variant = GameState.world.get("legal")
	if not d is Dictionary:
		d = {"lawyer": "", "clock": 0.0, "time": 0.0}
		GameState.world["legal"] = d
	return d


func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


## Host: from the data. Clients: use `lawyer` (synced).
func has_lawyer() -> bool:
	return str(_data()["lawyer"]) != ""


## Host: send the lawyer state to every peer (Staff._broadcast calls this too).
func sync() -> void:
	if not _is_host():
		return
	lawyer = str(_data()["lawyer"]) if not GameState.world.is_empty() else ""
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		_sync.rpc(lawyer)


@rpc("authority", "call_remote", "reliable")
func _sync(who: String) -> void:
	lawyer = who


func bribe_price(stars: int) -> int:
	return BRIBE_PER_STAR * stars


func _rank_ok(need: int) -> bool:
	return not Progression.gates_on() or Progression.rank() >= need


func _process(delta: float) -> void:
	if not _is_host() or GameState.world.is_empty() or get_tree().current_scene == null:
		return
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	if dn:
		tick(delta * dn.hours_per_second())


## Host: in-game hours pass (retainer once per day; an unpaid lawyer quits).
func tick(hours: float) -> void:
	var d: Dictionary = _data()
	d["time"] = float(d.get("time", 0.0)) + hours
	if not has_lawyer():
		return
	d["clock"] = float(d["clock"]) + hours
	if float(d["clock"]) < 24.0:
		return
	d["clock"] = float(d["clock"]) - 24.0
	var boss: String = str(d["lawyer"])
	if GameState.add_cash(boss, -LAWYER_FEE, true):
		Staff._send_wallet(boss)
		print("[Legal] retainer €%d paid by %s" % [LAWYER_FEE, boss])
	else:
		d["lawyer"] = ""
		sync()
		Staff._text(boss, "You missed my fee. Find yourself another lawyer.", LAWYER)
		print("[Legal] lawyer quit (unpaid)")


## Host: hire the lawyer (`who` pays the first day).
func host_hire(who: String) -> String:
	if not _rank_ok(LAWYER_RANK):
		return "!A lawyer needs rank %d (%s)." % [LAWYER_RANK, Progression.rank_name(LAWYER_RANK)]
	if has_lawyer():
		return "!Your crew already has a lawyer."
	if not GameState.add_cash(who, -LAWYER_FEE, true):
		return "!The first day costs €%d." % LAWYER_FEE
	_data()["lawyer"] = who
	_data()["clock"] = 0.0
	sync()
	Staff._send_wallet(who)
	print("[Legal] %s hired the lawyer" % who)
	return "Mr. Hale is on retainer (€%d a day). Get arrested and he gets part of the fine and your stuff back." % LAWYER_FEE


func host_fire(_who: String) -> String:
	if not has_lawyer():
		return "!You don't have a lawyer."
	_data()["lawyer"] = ""
	sync()
	return "Mr. Hale is off the case."


## Host: an arrest happened (`fine` paid, `taken` = the confiscated item dicts {id, count}). With a lawyer:
## part of the fine and half of every stack come back. Returns what came back (tests).
func on_player_arrested(p: Player, fine: int, taken: Array) -> Dictionary:
	if not _is_host() or p == null or not has_lawyer():
		return {}
	var who: String = p.player_name
	var cash: int = roundi(fine * FINE_BACK)
	var items: Array = []
	for it: Dictionary in taken:
		var n: int = ceili(int(it.get("count", 1)) * GOODS_BACK)
		if n > 0:
			items.append({"id": str(it["id"]), "count": n})
	GameState.give(who, 0, items)  # what doesn't fit is lost (the lawyer can't carry everything either)
	if cash > 0:
		GameState.add_clean(who, cash)
	p.send_wallet()
	var parts: PackedStringArray = []
	for it: Dictionary in items:
		parts.append("%dx %s" % [int(it["count"]), Station.item_name(str(it["id"]))])
	var text: String = "Got you €%d of the fine back%s. Procedural errors - happens all the time." % [cash,
			(" and " + ", ".join(parts)) if not parts.is_empty() else ""]
	p.phone_message(LAWYER, text, "")
	print("[Legal] lawyer for %s: €%d + %s back" % [who, cash, parts])
	return {"cash": cash, "items": items}


## Host: `p` bribes the corrupt cop to drop their stars.
func host_bribe(p: Player) -> String:
	if not _rank_ok(BRIBE_RANK):
		return "!Dekker only deals with rank %d (%s)." % [BRIBE_RANK, Progression.rank_name(BRIBE_RANK)]
	var stars: int = p.wanted_stars
	if stars <= 0:
		return "!\"You're clean. Don't waste my time.\""
	var now: float = float(_data().get("time", 0.0))
	if _bribed_at.has(p.player_name) and now - float(_bribed_at[p.player_name]) < BRIBE_COOLDOWN:
		return "!\"Too hot right now. Call me in a few hours.\""
	var price: int = bribe_price(stars)
	if not GameState.add_cash(p.player_name, -price):
		return "!\"%d stars is €%d. Come back with the money.\"" % [stars, price]
	_bribed_at[p.player_name] = now
	Wanted.clear(p, "bribe")
	p.send_wallet()
	print("[Legal] %s bribed the police: %d stars, €%d" % [p.player_name, stars, price])
	p.phone_message(COP, "Done. Your file got lost. Don't make me regret it.", "")
	return "Paid Dekker €%d: your %d star%s are gone." % [price, stars, "" if stars == 1 else "s"]
