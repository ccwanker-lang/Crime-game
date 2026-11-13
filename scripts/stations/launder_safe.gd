class_name LaunderSafe
extends Station
## Point 9: the back-office safe of a front business (bakery, barber, laundromat).
## Once the crew owns the business (its Property), E puts your dirty cash in the safe
## (up to MAX_DAYS days of turnover in total). The business "books" it as turnover:
## `daily_max` per in-game day (spread evenly over the hours) becomes clean money for
## whoever deposited it, minus `fee`. First in, first out. HOST AUTHORITATIVE: the
## host converts in tick() and credits GameState (clean money is paid out per CHUNK).

const CHUNK: int = 100
const MAX_DAYS: float = 2.0

## Point 40: the ledger window (HUD) refreshes on this (every peer).
signal ledger_changed

@export var daily_max: int = 1500
@export_range(0.0, 0.5) var fee: float = 0.1


func default_state() -> Dictionary:
	# queue: player name -> dirty euros still in the safe (insertion order = FIFO)
	# paid: player name -> clean euros paid out of their current deposits (point 40 message)
	return {"queue": {}, "buffer": 0.0, "laundered": 0, "paid": {}}


func pick_up_blocker() -> String:
	return "It's bolted to the floor."


func _build() -> void:
	var b := MeshBuilder.new()
	# Heavy floor safe: dark body, door with a dial and a handle on the front (+Z).
	b.box(&"metal_dark", Vector3(0, 0.4, 0), Vector3(0.6, 0.8, 0.55), 0.02)
	b.box(&"gun_metal", Vector3(0, 0.4, 0.28), Vector3(0.5, 0.7, 0.02), 0.01)
	b.cylinder(&"zinc", Vector3(-0.08, 0.5, 0.29), Vector3(-0.08, 0.5, 0.32), 0.06, 0.06, 16, true)
	b.box(&"zinc", Vector3(0.15, 0.4, 0.31), Vector3(0.03, 0.16, 0.03))
	b.box(&"zinc", Vector3(-0.08, 0.27, 0.3), Vector3(0.12, 0.02, 0.01))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 0.8, 0.6)
	cs.shape = shape
	cs.position.y = 0.4
	add_child(cs)


## The Property of the building this safe stands in.
func property() -> Property:
	var p: Node = get_parent()
	while p != null and not p is Building:
		p = p.get_parent()
	if p == null:
		return null
	for c: Node in p.get_children():
		if c is Property:
			return c as Property
	return null


func business_name() -> String:
	var prop: Property = property()
	return prop.display_name if prop else "Business"


func state_changed() -> void:
	ledger_changed.emit()


## Tap E (point 40): in an owned business the ledger window opens (deposit from there);
## otherwise the host answers why not.
func interact() -> void:
	var me: Player = _local_player()
	var prop: Property = property()
	if me and prop and prop.is_crew_owned():
		me.open_safe(self)
	else:
		super()


## Owner: the Deposit button of the ledger window (the host runs do_action).
func deposit() -> void:
	super.interact()


## In-game hours until `who`'s money in the queue is all clean (first in, first out), or -1.
func hours_until_clean(who: String) -> float:
	var queue: Dictionary = state["queue"]
	if not queue.has(who):
		return -1.0
	var ahead: int = 0
	for n: String in queue:
		ahead += int(queue[n])
		if n == who:
			break
	return maxf(0.0, (ahead - float(state["buffer"])) / (daily_max / 24.0))


## "around 14:00 tomorrow" for `hours` from now.
static func eta_text(now: float, hours: float) -> String:
	var at: int = ceili(now + hours - 0.001)  # the next full hour
	var day: int = floori(at / 24.0)
	var when: String = "today" if day == 0 else ("tomorrow" if day == 1 else "in %d days" % day)
	return "around %02d:00 %s" % [at % 24, when]


func _now() -> float:
	var dn := get_tree().get_first_node_in_group(&"day_night") as DayNight
	return dn.hours if dn else 12.0


## [{who, dirty, clean, hours}] in queue order (the ledger window).
func ledger() -> Array:
	var out: Array = []
	for who: String in (state["queue"] as Dictionary):
		var dirty: int = int(state["queue"][who])
		out.append({"who": who, "dirty": dirty, "clean": int(floor(dirty * (1.0 - fee))),
				"paid": int((state.get("paid", {}) as Dictionary).get(who, 0)), "hours": hours_until_clean(who)})
	return out


func queued_total() -> int:
	var total: int = 0
	for who: String in (state["queue"] as Dictionary):
		total += int(state["queue"][who])
	return total


func capacity_left() -> int:
	return maxi(0, int(daily_max * MAX_DAYS) - queued_total())


func prompt_for(player: Player) -> String:
	var prop: Property = property()
	if prop == null or not prop.is_crew_owned():
		return "%s safe - buy the business at Vos Real Estate to launder money here" % business_name()
	var queued: int = queued_total()
	var info: String = "€%d/day, %d%% fee, €%d in the safe" % [daily_max, roundi(fee * 100.0), queued]
	if player and player.cash > 0 and capacity_left() > 0:
		return "Launder €%d dirty cash (%s)" % [mini(player.cash, capacity_left()), info]
	if capacity_left() <= 0:
		return "%s safe is full (%s)" % [business_name(), info]
	return "%s safe (%s) - you carry no dirty cash" % [business_name(), info]


func do_action(player: Player) -> String:
	var prop: Property = property()
	if prop == null or not prop.is_crew_owned():
		return "Your crew doesn't own the %s." % business_name()
	var who: String = player.player_name
	var amount: int = mini(int(GameState.get_or_create_player_data(who)["cash"]), capacity_left())
	if amount <= 0:
		return "You carry no dirty cash." if capacity_left() > 0 else "The safe is full. Come back tomorrow."
	GameState.get_or_create_player_data(who)["cash"] = int(GameState.player_data[who]["cash"]) - amount
	var queue: Dictionary = state["queue"]
	queue[who] = int(queue.get(who, 0)) + amount
	changed()
	# Point 40: "€5000 deposited -> €4500 clean, around 14:00 tomorrow".
	return "€%d deposited at the %s -> €%d clean (minus %d%%), ready %s." % [
		amount, business_name(), int(floor(queue[who] * (1.0 - fee))), roundi(fee * 100.0),
		eta_text(_now(), hours_until_clean(who))]


## Host: book the turnover. Clients only show the state the host sends.
func tick(hours: float) -> bool:
	if not _is_host():
		return false
	var queue: Dictionary = state["queue"]
	if queue.is_empty():
		state["buffer"] = 0.0
		return false
	state["buffer"] = float(state["buffer"]) + daily_max / 24.0 * hours
	var dirty: bool = false
	while not queue.is_empty():
		var who: String = queue.keys()[0]
		var left: int = int(queue[who])
		var step: int = mini(CHUNK, left)
		if float(state["buffer"]) < step:
			break
		state["buffer"] = float(state["buffer"]) - step
		left -= step
		if left <= 0:
			queue.erase(who)
		else:
			queue[who] = left
		var clean: int = int(floor(step * (1.0 - fee)))
		state["laundered"] = int(state["laundered"]) + clean
		GameState.add_clean(who, clean)
		var paid: Dictionary = state.get_or_add("paid", {})
		paid[who] = int(paid.get(who, 0)) + clean
		if left <= 0:
			_done(who, int(paid[who]))
			paid.erase(who)
		_notify(who)
		dirty = true
	if dirty:
		changed()
	return false


## Host (point 40): all of `who`'s deposits are clean -> a text from the business.
func _done(who: String, total: int) -> void:
	print("[Launder] %s: %s's €%d is clean" % [business_name(), who, total])
	for p: Node in get_tree().get_nodes_in_group(&"players"):
		var pl := p as Player
		if pl.player_name == who:
			pl.phone_message(business_name(), "All done: €%d of your money is clean now (in your clean account)." % total, "")


func _notify(who: String) -> void:
	for p: Node in get_tree().get_nodes_in_group(&"players"):
		var pl := p as Player
		if pl.player_name == who:
			pl.send_wallet()
