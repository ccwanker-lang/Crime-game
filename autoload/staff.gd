extends Node
## Staff + dealers (DESIGN "Staff"), autoload `Staff`. HOST AUTHORITATIVE.
## - Everything lives in GameState.world["staff"] (saved with the world):
##   members: uid -> record, candidates: Array of records Benny offers, clock / cand_clock (in-game hours).
##   Worker record: {uid, role, name, variant, color, wage, employer, property, work, status, pos, yaw}.
##   Dealer record: {uid, role "dealer", name, variant, color, employer, district, commission, stock, cash,
##                   loyalty, sold, sell, pos, yaw}.
## - Host: tick() in in-game hours: workers use the stations + storage lockers of their property
##   (grower: pots -> racks; packager: racks -> locker -> packaging table -> bags in the locker),
##   dealers sell from their stock in their district (cash minus commission waits for you), risks
##   (arrest, betrayal), wages once per in-game day (an unpaid worker quits).
## - Clients ask with RPCs (hire, fire, give bags, collect); the host checks and answers with a message.
## - Every peer: the host sends the members list (`members`) -> StaffViews shows a stationary NPC per member
##   (a local visual, no network node). Hiring: phone app "Crew" (CrewWindow) - there is no bar yet.

const CONFIG_PATH: String = "res://data/staff/staff.tres"
const SYNC_DELAY: float = 0.5
const BENNY: String = "Benny (fixer)"
const DEALER_REACH: float = 4.0

## (every peer) the members list changed.
signal members_changed
## (the asking peer) answer to a request: ok + text.
signal answer(ok: bool, text: String)

var config: StaffConfig
## Every peer: uid -> record (copy from the host).
var members: Dictionary = {}
## Every peer: Benny's current candidates.
var candidates: Array = []
var _dirty: bool = false
var _sync_timer: float = 0.0
var _views: StaffViews


func _ready() -> void:
	config = load(CONFIG_PATH) as StaffConfig
	if config == null:
		config = StaffConfig.new()
	GameState.world_changed.connect(_on_world_changed)
	add_to_group(&"hours_skipped")  # Sleep (point 37): catch up on the skipped night


func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


# --- Reading (every peer) ------------------------------------------------------------

func role_info(role: String) -> Dictionary:
	return config.roles.get(role, {})


func role_name(role: String) -> String:
	return str(role_info(role).get("name", role.capitalize()))


func district_name(id: String) -> String:
	return str((config.districts.get(id, {}) as Dictionary).get("name", id))


func dealers() -> Array:
	return members.values().filter(func(r: Dictionary) -> bool: return r["role"] == "dealer")


func max_dealers() -> int:
	var r: int = Progression.rank() if Progression.gates_on() else Progression.MAX_RANK
	return config.max_dealers[mini(r, config.max_dealers.size() - 1)]


## "" if the crew may hire `role` now, else why not (rank / later).
func role_lock(role: String) -> String:
	var info: Dictionary = role_info(role)
	if info.is_empty():
		return "Unknown job."
	if info.get("later", false):
		return "Not in the game yet."
	var need: int = int(info.get("rank", 0))
	if Progression.gates_on() and Progression.rank() < need:
		return "Needs rank %d (%s)" % [need, Progression.rank_name(need)]
	return ""


## Short status line of a member (every peer).
func describe(rec: Dictionary) -> String:
	if rec["role"] == "dealer":
		return "%s - %d bags%s, €%d to collect, %d%% cut, loyalty %d" % [district_name(str(rec["district"])),
				int(rec["stock"]), meth_text(rec), int(rec["cash"]), roundi(float(rec["commission"]) * 100.0), roundi(float(rec["loyalty"]))]
	return "%s - %s (€%d/day)" % [_property_name(str(rec["property"])), str(rec.get("status", "")), int(rec["wage"])]


## Dealer stock: "stock" = all bags; these record keys count the dearer bags among them (sold first, in this
## order). The rest is weed.
const DEALER_GOODS: Array = [["coke_bag", "coke"], ["meth_bag", "meth"]]


## " (3 meth, 2 cocaine)" for the dearer bags a dealer holds, else "".
func meth_text(rec: Dictionary) -> String:
	var parts: PackedStringArray = []
	for g: Array in DEALER_GOODS:
		if int(rec.get(g[1], 0)) > 0:
			parts.append("%d %s" % [int(rec[g[1]]), Products.short_name(g[0])])
	return " (%s)" % ", ".join(parts) if not parts.is_empty() else ""


## Bags of weed among a dealer's stock.
func dealer_weed(rec: Dictionary) -> int:
	var n: int = int(rec["stock"])
	for g: Array in DEALER_GOODS:
		n -= int(rec.get(g[1], 0))
	return n


func _property_name(id: String) -> String:
	var p: Property = property_node(id)
	return p.display_name if p else id


func property_node(id: String) -> Property:
	for n: Node in get_tree().get_nodes_in_group(&"properties"):
		if String((n as Property).property_id) == id:
			return n as Property
	return null


## Crew-owned properties: [[id, name], ...].
func crew_properties() -> Array:
	var out: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"properties"):
		var p := n as Property
		if p.is_crew_owned():
			out.append([String(p.property_id), p.display_name])
	return out


# --- Host: data --------------------------------------------------------------------------

func _data() -> Dictionary:
	var d: Variant = GameState.world.get("staff")
	if not d is Dictionary:
		d = {"members": {}, "candidates": [], "clock": 0.0, "cand_clock": 0.0, "next": 1}
		GameState.world["staff"] = d
	return d


func _members() -> Dictionary:
	return _data()["members"]


func _mark() -> void:
	_dirty = true


# --- Host: the clock ---------------------------------------------------------------------

func _process(delta: float) -> void:
	var tree := get_tree()
	var world: Node = tree.current_scene
	if world == null or world.get_node_or_null("Players") == null:
		if _views != null:
			_views = null
			members = {}  # left the game
			candidates = []
		return
	if _views == null or not is_instance_valid(_views):
		_views = StaffViews.new()
		world.add_child(_views)
		_views.rebuild(members)
		if not _is_host():
			request_sync()
	if not _is_host() or GameState.world.is_empty():
		return
	var dn := tree.get_first_node_in_group(&"day_night") as DayNight
	if dn:
		tick(delta * dn.hours_per_second())
	_sync_timer -= delta
	if _dirty and _sync_timer <= 0.0:
		_sync_timer = SYNC_DELAY
		_dirty = false
		_broadcast()


## Host: group call "hours_skipped" (the night was slept away): catch up in small steps
## (a worker does only a few actions per step, like in normal play).
func on_hours_skipped(hours: float) -> void:
	if not _is_host() or GameState.world.is_empty():
		return
	var steps: int = ceili(hours / 0.1)
	for i: int in steps:
		tick(hours / steps)
	print("[Staff] caught up on %.1f skipped hours" % hours)


## Host: advance `hours` in-game hours.
func tick(hours: float) -> void:
	if hours <= 0.0:
		return
	var d: Dictionary = _data()
	if (d["candidates"] as Array).is_empty():
		_new_candidates()
	for uid: String in (d["members"] as Dictionary).keys():
		var rec: Dictionary = d["members"].get(uid, {})
		if rec.is_empty():
			continue
		if rec["role"] == "dealer":
			_dealer_tick(rec, hours)
		else:
			_worker_tick(rec, hours)
	d["clock"] = float(d["clock"]) + hours
	if float(d["clock"]) >= 24.0:
		d["clock"] = float(d["clock"]) - 24.0
		_pay_wages()
	d["cand_clock"] = float(d["cand_clock"]) + hours
	if float(d["cand_clock"]) >= 24.0:
		d["cand_clock"] = 0.0
		_new_candidates()


func _pay_wages() -> void:
	var paid: Dictionary = {}  # employer -> total
	for uid: String in _members().keys():
		var rec: Dictionary = _members()[uid]
		var wage: int = int(rec.get("wage", 0))
		if wage <= 0:
			continue
		var boss: String = str(rec["employer"])
		if GameState.add_cash(boss, -wage):
			_send_wallet(boss)
			paid[boss] = int(paid.get(boss, 0)) + wage
			print("[Staff] paid %s (%s) €%d" % [rec["name"], rec["role"], wage])
		else:
			_members().erase(uid)
			_text(boss, "%s quit: you couldn't pay the €%d wage." % [rec["name"], wage])
			print("[Staff] %s quit (unpaid)" % rec["name"])
	for boss: String in paid:
		_text(boss, "Paid today's wages: €%d." % int(paid[boss]))
	_mark()


# --- Host: workers -------------------------------------------------------------------------

func _worker_tick(rec: Dictionary, hours: float) -> void:
	var rate: float = config.packager_bags_per_hour
	match str(rec["role"]):
		"grower": rate = config.grower_actions_per_hour
		"cook": rate = config.cook_actions_per_hour
		"courier": rate = config.courier_trips_per_hour
	rec["work"] = minf(float(rec.get("work", 0.0)) + hours * rate, 3.0)
	var did: int = 0
	while float(rec["work"]) >= 1.0:
		var what: String = ""
		match str(rec["role"]):
			"grower":
				what = _grower_step(rec)
				if what == "":
					what = _machine_step(rec, GROWER_MACHINES, false)
			"cook": what = _cook_step(rec)
			"courier": what = _courier_step(rec)
			_: what = _packager_step(rec)
		if what == "":
			rec["work"] = minf(float(rec["work"]), 1.0)  # nothing to do: wait
			break
		rec["work"] = float(rec["work"]) - 1.0
		did += 1
	if did > 0:
		_mark()


## Stations of one kind in the worker's property.
func _stations_in(prop_id: String, kind: Script) -> Array:
	var out: Array = []
	var prop: Property = property_node(prop_id)
	if prop == null:
		return out
	for n: Node in get_tree().get_nodes_in_group(&"stations"):
		if n.get_script() == kind and prop.contains((n as Node3D).global_position):
			out.append(n)
	return out


func _set_status(rec: Dictionary, text: String) -> void:
	if str(rec.get("status", "")) != text:
		rec["status"] = text
		_mark()


func _stand_at(rec: Dictionary, st: Node3D) -> void:
	# Two workers at one station stand side by side (odd / even uid).
	var side: float = 0.45 if str(rec.get("uid", "s0")).trim_prefix("s").to_int() % 2 == 1 else -0.45
	var front: Vector3 = st.global_position + st.global_basis.z * 0.95 + st.global_basis.x * side
	front.y = st.global_position.y
	rec["pos"] = front
	var to: Vector3 = st.global_position - front
	rec["yaw"] = atan2(-to.x, -to.z)
	_mark()


## Host: one grower action. Returns what was done ("" = nothing possible).
func _grower_step(rec: Dictionary) -> String:
	var prop: String = str(rec["property"])
	var pots: Array = _stations_in(prop, GrowPot)
	if pots.is_empty():
		if _stations_in(prop, CocaBed).is_empty():
			_set_status(rec, "no grow pots here")
		return ""
	var lockers: Array = _stations_in(prop, StorageLocker)
	var racks: Array = _stations_in(prop, DryingRack)
	var missing: String = ""
	# Harvest first, then water, then plant, then fill with soil.
	for stage: int in [GrowPot.Stage.READY, GrowPot.Stage.GROWING, GrowPot.Stage.SOIL, GrowPot.Stage.EMPTY]:
		for pot: GrowPot in pots:
			var s: Dictionary = pot.state
			if int(s["stage"]) != stage:
				continue
			match stage:
				GrowPot.Stage.READY:
					if not _store_harvest(racks, lockers, GrowPot.YIELD):
						missing = "no room on the racks / in the locker"
						continue
					s["stage"] = GrowPot.Stage.EMPTY
					s["growth"] = 0.0
					s["water"] = 0.0
					return _did(rec, pot, "harvested a plant")
				GrowPot.Stage.GROWING:
					if float(s["water"]) >= GrowPot.REFILL_BELOW:
						continue
					s["water"] = 1.0
					return _did(rec, pot, "watered a plant")
				GrowPot.Stage.SOIL:
					if not _locker_take(lockers, "weed_seed", 1):
						missing = "needs Weed Seeds in the locker"
						continue
					s["stage"] = GrowPot.Stage.GROWING
					s["growth"] = 0.0
					s["seed"] = randi() % 100000
					return _did(rec, pot, "planted a seed")
				GrowPot.Stage.EMPTY:
					if not _locker_take(lockers, "soil", 1):
						missing = "needs Soil in the locker" if missing == "" else missing
						continue
					s["stage"] = GrowPot.Stage.SOIL
					s["water"] = 0.0
					return _did(rec, pot, "filled a pot with soil")
	_set_status(rec, missing if missing != "" else "plants are growing")
	return ""


func _did(rec: Dictionary, st: Station, what: String) -> String:
	st.changed()
	_stand_at(rec, st)
	_set_status(rec, what)
	print("[Staff] %s (%s, %s) %s" % [rec["name"], rec["role"], rec["property"], what])
	return what


## Host: fresh weed onto the racks (the rest in a locker). False if it doesn't all fit.
func _store_harvest(racks: Array, lockers: Array, amount: int) -> bool:
	var room: int = 0
	for r: DryingRack in racks:
		room += DryingRack.CAPACITY - int(r.state["wet"]) - int(r.state["dry"])
	for l: StorageLocker in lockers:
		room += _locker_room(l, "fresh_weed")
	if room < amount:
		return false
	for r: DryingRack in racks:
		var free: int = DryingRack.CAPACITY - int(r.state["wet"]) - int(r.state["dry"])
		var hang: int = mini(free, amount)
		if hang <= 0:
			continue
		var wet: int = int(r.state["wet"])
		r.state["progress"] = float(r.state["progress"]) * wet / float(wet + hang)
		r.state["wet"] = wet + hang
		r.changed()
		amount -= hang
	if amount > 0:
		_locker_put(lockers, "fresh_weed", amount)
	return true


## Host: one packager action.
func _packager_step(rec: Dictionary) -> String:
	var prop: String = str(rec["property"])
	var lockers: Array = _stations_in(prop, StorageLocker)
	if lockers.is_empty():
		_set_status(rec, "needs a storage locker here")
		return ""
	# Dried weed off the racks into the locker.
	for r: DryingRack in _stations_in(prop, DryingRack):
		var dry: int = int(r.state["dry"])
		if dry <= 0:
			continue
		var fits: int = 0
		for l: StorageLocker in lockers:
			fits += _locker_room(l, "weed_bud")
		var take: int = mini(dry, fits)
		if take <= 0:
			break
		_locker_put(lockers, "weed_bud", take)
		r.state["dry"] = dry - take
		return _did(rec, r, "took %d Dried Weed off a rack" % take)
	var tables: Array = _stations_in(prop, PackagingTable)
	if tables.is_empty():
		_set_status(rec, "needs a packaging table here")
		return ""
	# Weed first, then meth, then cocaine (PackagingTable.PACKS: product -> bag).
	var product: Array = []
	for pk: Array in PackagingTable.PACKS:
		if _locker_count(lockers, pk[0]) > 0:
			product = pk
			break
	if product.is_empty():
		_set_status(rec, "waiting for dried weed / meth shards / cocaine")
		return ""
	if _locker_count(lockers, "baggie") <= 0:
		_set_status(rec, "needs Baggies in the locker")
		return ""
	var room: int = 0
	for l: StorageLocker in lockers:
		room += _locker_room(l, product[1])
	if room <= 0:
		_set_status(rec, "the locker is full")
		return ""
	_locker_take(lockers, product[0], 1)
	_locker_take(lockers, "baggie", 1)
	_locker_put(lockers, product[1], 1)
	for l: StorageLocker in lockers:
		l.changed()
	return _did(rec, tables[0], "packaged a bag of %s" % Products.short_name(product[1]))


## Machines a cook runs (milestone 3: meth, cocaine processing) / a grower tends besides the weed pots.
var COOK_MACHINES: Array[Script] = [CookStation, CoolingPlate, LeafPress, Refinery]
var GROWER_MACHINES: Array[Script] = [CocaBed]


## Host: one cook action: run the machines in the property from the lockers.
func _cook_step(rec: Dictionary) -> String:
	return _machine_step(rec, COOK_MACHINES, true)


## Host: one action on the ProcessStations of `kinds` in the worker's property, in this order: take finished
## output into the locker, attend (stir / water), start a run with inputs from the locker. A machine's output
## can be the next one's input (Hot Trays -> cooling plate), so the locker is the hand-over point.
## `report` = set the status when there is nothing to do.
func _machine_step(rec: Dictionary, kinds: Array[Script], report: bool) -> String:
	var prop: String = str(rec["property"])
	var machines: Array = []
	for k: Script in kinds:
		machines.append_array(_stations_in(prop, k))
	if machines.is_empty():
		if report:
			_set_status(rec, "no machines here")
		return ""
	var lockers: Array = _stations_in(prop, StorageLocker)
	if lockers.is_empty():
		if report:
			_set_status(rec, "needs a storage locker here")
		return ""
	var put: Callable = func(id: String, n: int) -> int: return _locker_put(lockers, id, n)
	var have: Callable = func(id: String) -> int: return _locker_count(lockers, id)
	var take: Callable = func(id: String, n: int) -> bool: return _locker_take(lockers, id, n)
	for m: ProcessStation in machines:
		var n: int = m.staff_take(put)
		if n > 0:
			return _did(rec, m, "took %d %s off the %s" % [n, Station.item_name(m.output_id), m.label.to_lower()])
	for m: ProcessStation in machines:
		if m.staff_attend():
			return _did(rec, m, "%s" % m.attend_verb.to_lower())
	for m: ProcessStation in machines:
		if m.staff_load(have, take):
			return _did(rec, m, "started the %s" % m.label.to_lower())
	if report:
		var running: Array = machines.filter(func(m: ProcessStation) -> bool: return int(m.state["stage"]) == ProcessStation.Stage.RUNNING)
		if not running.is_empty():
			_set_status(rec, "busy: " + ", ".join(running.map(func(m: ProcessStation) -> String: return m.status_text())))
		elif machines.any(func(m: ProcessStation) -> bool: return int(m.state["stage"]) == ProcessStation.Stage.DONE):
			_set_status(rec, "the locker is full")
		else:
			var need: PackedStringArray = []
			for m: ProcessStation in machines:
				need.append(m.inputs_text())
			_set_status(rec, "needs supplies in the locker: " + " / ".join(need))
	return ""


## Host: one courier trip (rank 3): first restock a dealer that runs low (bags from the property's lockers, dearest
## first) and bring their cash to the employer, else buy one missing supply for the stations in the property.
func _courier_step(rec: Dictionary) -> String:
	var prop: String = str(rec["property"])
	var lockers: Array = _stations_in(prop, StorageLocker)
	if lockers.is_empty():
		_set_status(rec, "needs a storage locker here")
		return ""
	var boss: String = str(rec["employer"])
	for d: Dictionary in _members().values():
		if d["role"] != "dealer" or str(d["employer"]) != boss:
			continue
		var low: bool = int(d["stock"]) < roundi(config.dealer_capacity * config.courier_restock_below)
		var room: int = config.dealer_capacity - int(d["stock"])
		var brought: int = 0
		if low:
			for g: Array in DEALER_GOODS + [["weed_bag", ""]]:
				var k: int = mini(_locker_count(lockers, g[0]), room - brought)
				if k <= 0:
					continue
				_locker_take(lockers, g[0], k)
				if g[1] != "":
					d[g[1]] = int(d.get(g[1], 0)) + k
				d["stock"] = int(d["stock"]) + k
				brought += k
		var cash: int = int(d["cash"]) if brought > 0 or int(d["cash"]) > config.greedy_cash * 0.5 else 0
		if brought <= 0 and cash <= 0:
			continue
		if cash > 0:
			GameState.add_cash(boss, cash)
			d["cash"] = 0
			d["loyalty"] = minf(100.0, float(d["loyalty"]) + config.collect_loyalty)
			_send_wallet(boss)
		_mark()
		var what: String = "brought %s %d bags, collected €%d" % [d["name"], brought, cash]
		_set_status(rec, what)
		print("[Staff] courier %s %s" % [rec["name"], what])
		if cash > 0:
			_text(boss, "%s here. Picked up €%d from %s%s." % [rec["name"], cash, d["name"],
					" and dropped off %d bags" % brought if brought > 0 else ""], str(rec["name"]))
		return what
	# Supplies for the stations in this property.
	var wanted: Dictionary = {}
	var prop_node: Property = property_node(prop)
	for n: Node in get_tree().get_nodes_in_group(&"stations"):
		var st := n as Station
		if prop_node == null or not prop_node.contains(st.global_position):
			continue
		var item_id: String = _station_item(st)
		for id: String in config.courier_uses.get(item_id, []):
			wanted[id] = true
	for id: String in wanted:
		var want: int = int(config.courier_stock.get(id, 0))
		var short: int = want - _locker_count(lockers, id)
		if short <= 0 or Progression.item_lock(StringName(id)) != "":
			continue
		var item: ItemData = ItemDB.get_item(StringName(id))
		if item == null:
			continue
		var cost: int = roundi(item.base_price * config.courier_markup) * short
		if not GameState.add_cash(boss, -cost, item.is_legal):
			_set_status(rec, "can't pay €%d for %d %s" % [cost, short, item.display_name])
			return ""
		var left: int = _locker_put(lockers, id, short)
		if left > 0:
			GameState.add_cash(boss, roundi(item.base_price * config.courier_markup) * left)  # no room: money back
		_send_wallet(boss)
		var what: String = "bought %d %s (€%d)" % [short - left, item.display_name, cost - roundi(item.base_price * config.courier_markup) * left]
		_set_status(rec, what)
		_stand_at(rec, lockers[0])
		print("[Staff] courier %s %s" % [rec["name"], what])
		return what
	_set_status(rec, "everything is stocked")
	return ""


## Tests: one courier trip right now.
func courier_test_trip(rec: Dictionary) -> String:
	return _courier_step(rec)


## The item id a station was built from ("cook_station" for a CookStation...).
func _station_item(st: Station) -> String:
	var path: String = st.scene_file_path
	return path.get_file().get_basename() if path.begins_with("res://prefabs/stations/") else ""


# --- Host: locker helpers -------------------------------------------------------------------

func _locker_count(lockers: Array, id: String) -> int:
	var n: int = 0
	for l: StorageLocker in lockers:
		for it: Dictionary in l.state["items"]:
			if str(it["id"]) == id:
				n += int(it.get("count", 1))
	return n


func _locker_room(l: StorageLocker, id: String) -> int:
	var items: Array = l.state["items"]
	var stack: int = GameState.max_stack_of(id)
	var room: int = (StorageLocker.SLOTS - items.size()) * stack
	for it: Dictionary in items:
		if str(it["id"]) == id:
			room += maxi(0, stack - int(it.get("count", 1)))
	return room


func _locker_take(lockers: Array, id: String, count: int) -> bool:
	if _locker_count(lockers, id) < count:
		return false
	for l: StorageLocker in lockers:
		var items: Array = l.state["items"]
		for i: int in range(items.size() - 1, -1, -1):
			if count <= 0:
				break
			var it: Dictionary = items[i]
			if str(it["id"]) != id:
				continue
			var take: int = mini(count, int(it.get("count", 1)))
			it["count"] = int(it.get("count", 1)) - take
			count -= take
			if int(it["count"]) <= 0:
				items.remove_at(i)
		l.changed()
	return true


func _locker_put(lockers: Array, id: String, count: int) -> int:
	for l: StorageLocker in lockers:
		if count <= 0:
			break
		count = GameState.add_to_stacks(l.state["items"], id, count, StorageLocker.SLOTS)
		l.changed()
	return count


# --- Host: dealers ---------------------------------------------------------------------------

func _dealer_tick(rec: Dictionary, hours: float) -> void:
	var dist: Dictionary = config.districts.get(str(rec["district"]), {})
	var stock: int = int(rec["stock"])
	if stock > 0:
		rec["sell"] = float(rec.get("sell", 0.0)) + hours * float(dist.get("sales_per_hour", 1.0))
		var sold: int = 0
		while float(rec["sell"]) >= 1.0 and int(rec["stock"]) > 0:
			rec["sell"] = float(rec["sell"]) - 1.0
			rec["stock"] = int(rec["stock"]) - 1
			var price: int = int(dist.get("price", 60))
			for g: Array in DEALER_GOODS:
				if int(rec.get(g[1], 0)) > 0:
					rec[g[1]] = int(rec[g[1]]) - 1
					price = Products.price(g[0], price)
					break
			rec["cash"] = int(rec["cash"]) + roundi(price * (1.0 - float(rec["commission"])))
			rec["sold"] = int(rec.get("sold", 0)) + 1
			sold += 1
		if sold > 0:
			Progression.host_add(sold * config.xp_per_dealer_bag, "dealer sale")
			print("[Staff] dealer %s sold %d (stock %d, cash €%d)" % [rec["name"], sold, rec["stock"], rec["cash"]])
			if int(rec["stock"]) == 0:
				_text(str(rec["employer"]), "%s here. Sold out in %s, bring me more. €%d waiting for you." % [
						rec["name"], district_name(str(rec["district"])), int(rec["cash"])], str(rec["name"]))
			_mark()
	else:
		rec["sell"] = 0.0
	if int(rec["cash"]) > config.greedy_cash:
		rec["loyalty"] = maxf(0.0, float(rec["loyalty"]) - hours * config.greed_loyalty_per_hour)
		_mark()
	if int(rec["stock"]) + int(rec["cash"]) <= 0:
		return  # nothing to lose
	if randf() < config.arrest_chance_per_hour * hours:
		_lose_dealer(rec, "%s got arrested in %s. %d bags and €%d are gone." % [rec["name"],
				district_name(str(rec["district"])), int(rec["stock"]), int(rec["cash"])], "arrested")
	elif float(rec["loyalty"]) < config.betray_below and randf() < config.betray_chance_per_hour * hours:
		_lose_dealer(rec, "%s is gone - with %d bags and €%d of yours. Should have paid more attention." % [
				rec["name"], int(rec["stock"]), int(rec["cash"])], "betrayed you")


func _lose_dealer(rec: Dictionary, text: String, why: String) -> void:
	_members().erase(str(rec["uid"]))
	_text(str(rec["employer"]), text)
	print("[Staff] dealer %s %s" % [rec["name"], why])
	_mark()


# --- Host: hiring --------------------------------------------------------------------------------

func _new_candidates() -> void:
	var list: Array = []
	var roles: Array = ["grower", "packager", "dealer", "dealer", "grower", "packager", "cook", "courier"]
	for i: int in config.candidates:
		list.append(_make_candidate(roles[i % roles.size()] if i < 3 else roles.pick_random()))
	_data()["candidates"] = list
	_mark()


func _make_candidate(role: String) -> Dictionary:
	var info: Dictionary = role_info(role)
	var base: int = int(info.get("wage", 0))
	var rec: Dictionary = {"role": role, "name": config.first_names[randi() % config.first_names.size()],
			"variant": randi() % Pedestrian.VARIANTS.size(), "color": randi() % 1000,
			"wage": roundi(base * randf_range(0.85, 1.2))}
	if role == "dealer":
		rec["commission"] = snappedf(randf_range(config.commission_min, config.commission_max), 0.01)
	return rec


func _new_uid() -> String:
	var d: Dictionary = _data()
	var n: int = int(d.get("next", 1))
	d["next"] = n + 1
	return "s%d" % n


## Host: `who` hires candidate `index` for `place` (property id for workers, district id for dealers).
func host_hire(who: String, index: int, place: String) -> String:
	var cands: Array = _data()["candidates"]
	if index < 0 or index >= cands.size():
		return "!That person isn't available any more."
	var cand: Dictionary = cands[index]
	var role: String = str(cand["role"])
	var lock: String = role_lock(role)
	if lock != "":
		return "!%s: %s." % [role_name(role), lock]
	var rec: Dictionary = cand.duplicate(true)
	rec["uid"] = _new_uid()
	rec["employer"] = who
	if role == "dealer":
		if not config.districts.has(place):
			return "!Pick a district."
		var n_dealers: int = _members().values().filter(func(r: Dictionary) -> bool: return r["role"] == "dealer").size()
		if n_dealers >= max_dealers_host():
			return "!Your crew can't run more than %d dealer%s at this rank." % [max_dealers_host(), "" if max_dealers_host() == 1 else "s"]
		for r: Dictionary in _members().values():
			if r["role"] == "dealer" and str(r["district"]) == place:
				return "!%s already works %s." % [r["name"], district_name(place)]
		rec.merge({"district": place, "stock": 0, "meth": 0, "coke": 0, "cash": 0, "loyalty": config.start_loyalty, "sold": 0, "sell": 0.0})
		_place_dealer(rec)
	else:
		var prop: Property = property_node(place)
		if prop == null or not prop.is_crew_owned():
			return "!Pick a property your crew owns."
		var beds: int = beds_in(place)
		var used: int = _members().values().filter(func(r: Dictionary) -> bool:
				return r["role"] != "dealer" and str(r.get("property", "")) == place).size()
		if used >= beds:
			return "!No room for staff in the %s: every worker needs a bed or a storage locker there (%d)." % [prop.display_name, beds]
		if not GameState.add_cash(who, -int(rec["wage"])):
			return "!You can't pay the first day (€%d)." % int(rec["wage"])
		rec.merge({"property": place, "work": 0.0, "status": "just started"})
		_place_worker(rec, prop)
	_members()[rec["uid"]] = rec
	cands.remove_at(index)
	cands.append(_make_candidate(["grower", "packager", "dealer", "cook", "courier"].pick_random()))
	_mark()
	print("[Staff] %s hired %s as %s (%s)" % [who, rec["name"], role, place])
	if role == "dealer":
		return "%s works %s now for a %d%% cut. Bring them bags (E on them)." % [rec["name"], district_name(place),
				roundi(float(rec["commission"]) * 100.0)]
	return "%s starts as %s in the %s. Paid the first day (€%d)." % [rec["name"], role_name(role).to_lower(),
			_property_name(place), int(rec["wage"])]


func max_dealers_host() -> int:
	return max_dealers()


## Host: workers a property can house (beds + storage lockers in it).
func beds_in(prop_id: String) -> int:
	var prop: Property = property_node(prop_id)
	if prop == null:
		return 0
	var n: int = 0
	for rec: Dictionary in (GameState.world.get("placed", {}) as Dictionary).values():
		if str(rec.get("item", "")) in config.bed_items and prop.contains(rec["pos"]):
			n += 1
	return n


func _place_worker(rec: Dictionary, prop: Property) -> void:
	var lockers: Array = _stations_in(String(prop.property_id), StorageLocker)
	if not lockers.is_empty():
		_stand_at(rec, lockers[0])
		return
	var b: Node3D = prop.building()
	rec["pos"] = b.to_global(Vector3(0.0, 0.05, -3.0)) if b else prop.global_position
	rec["yaw"] = b.global_rotation.y if b else 0.0


func _place_dealer(rec: Dictionary) -> void:
	var dist: Dictionary = config.districts[str(rec["district"])]
	var anchor: Vector3 = dist["anchor"]
	var world: Node3D = get_tree().current_scene as Node3D
	var pos: Vector3 = anchor
	if world:
		var map: RID = world.get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			var snapped: Vector3 = NavigationServer3D.map_get_closest_point(map, anchor)
			if snapped.distance_to(anchor) < 8.0:
				pos = snapped
	rec["pos"] = pos
	# Face the street (the anchor's nearest road axis).
	rec["yaw"] = 0.0 if anchor.z > 0.0 else PI
	if absf(anchor.z) > 40.0:
		rec["yaw"] = PI if anchor.z > 0.0 else 0.0


## Host: fire a member (a dealer hands back stock + cash).
func host_fire(who: String, uid: String) -> String:
	var rec: Dictionary = _members().get(uid, {})
	if rec.is_empty():
		return "!Nobody by that name works for you."
	_members().erase(uid)
	_mark()
	print("[Staff] %s fired %s" % [who, rec["name"]])
	if rec["role"] == "dealer":
		var back: Array = [{"id": "weed_bag", "count": dealer_weed(rec)}]
		for g: Array in DEALER_GOODS:
			back.append({"id": g[0], "count": int(rec.get(g[1], 0))})
		var left: Array = GameState.give(who, int(rec["cash"]), back)
		_send_wallet(who)
		var lost: int = 0
		for it: Dictionary in left:
			lost += int(it["count"])
		return "%s is out. You got €%d and %d bags back%s." % [rec["name"], int(rec["cash"]), int(rec["stock"]) - lost,
				" (%d didn't fit in your pockets)" % lost if lost > 0 else ""]
	return "%s is out." % rec["name"]


## Host: `player` gives a dealer bags / collects the cash (must stand next to them).
func host_dealer(player: Player, uid: String, action: String) -> String:
	var rec: Dictionary = _members().get(uid, {})
	if rec.is_empty() or rec["role"] != "dealer":
		return "!That dealer isn't around."
	if player.global_position.distance_to(rec["pos"]) > DEALER_REACH:
		return "!Go to %s in person (%s)." % [rec["name"], district_name(str(rec["district"]))]
	var who: String = player.player_name
	match action:
		"give":
			# Every kind of bag (DEALER_GOODS first, then weed); "stock" = all bags.
			var carried: int = GameState.count_item(who, "weed_bag")
			for g: Array in DEALER_GOODS:
				carried += GameState.count_item(who, g[0])
			var n: int = mini(carried, config.dealer_capacity - int(rec["stock"]))
			if n <= 0:
				return "!You have no bags to give." if carried == 0 else "!%s can't carry more." % rec["name"]
			var left: int = n
			for g: Array in DEALER_GOODS:
				var k: int = mini(GameState.count_item(who, g[0]), left)
				GameState.remove_item(who, g[0], k)
				rec[g[1]] = int(rec.get(g[1], 0)) + k
				left -= k
			GameState.remove_item(who, "weed_bag", left)
			rec["stock"] = int(rec["stock"]) + n
			_mark()
			player.send_wallet()
			print("[Staff] %s gave dealer %s %d bags" % [who, rec["name"], n])
			return "Gave %s %d bag%s." % [rec["name"], n, "" if n == 1 else "s"]
		"collect":
			var cash: int = int(rec["cash"])
			if cash <= 0:
				return "\"Nothing yet, boss.\""
			GameState.add_cash(who, cash)
			rec["cash"] = 0
			rec["loyalty"] = minf(100.0, float(rec["loyalty"]) + config.collect_loyalty)
			_mark()
			player.send_wallet()
			print("[Staff] %s collected €%d from %s" % [who, cash, rec["name"]])
			return "Collected €%d from %s." % [cash, rec["name"]]
	return ""


# --- Requests (owner -> host) ------------------------------------------------------------------

## Owner: ask the host (hire / fire / give / collect). The answer comes back as `answer`.
## Failed host messages start with "!" (stripped before `answer`).
func request(action: String, a: Variant = null, b: Variant = null) -> void:
	if _is_host():
		var me: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
		_answer_to(me, _run(me, action, a, b))
	else:
		_request.rpc_id(1, action, a, b)


@rpc("any_peer", "call_remote", "reliable")
func _request(action: String, a: Variant, b: Variant) -> void:
	if multiplayer.is_server():
		var peer: int = multiplayer.get_remote_sender_id()
		_answer_to(peer, _run(peer, action, a, b))


func _run(peer: int, action: String, a: Variant, b: Variant) -> String:
	var world: Node = get_tree().current_scene
	var player := world.get_node_or_null("Players/%d" % peer) as Player if world else null
	if player == null or player.dead:
		return ""
	var msg: String = ""
	match action:
		"hire":
			msg = host_hire(player.player_name, int(a), str(b))
		"fire":
			msg = host_fire(player.player_name, str(a))
		"give", "collect":
			msg = host_dealer(player, str(a), action)
		"lawyer_hire":
			msg = Legal.host_hire(player.player_name)
		"lawyer_fire":
			msg = Legal.host_fire(player.player_name)
		"bribe":
			msg = Legal.host_bribe(player)
		"sync":
			pass
	_broadcast()
	return msg


func _answer_to(peer: int, text: String) -> void:
	if text == "":
		return
	var ok: bool = not text.begins_with("!")
	text = text.trim_prefix("!")
	if peer == multiplayer.get_unique_id() or not multiplayer.has_multiplayer_peer():
		answer.emit(ok, text)
	else:
		_answer.rpc_id(peer, ok, text)


@rpc("authority", "call_remote", "reliable")
func _answer(ok: bool, text: String) -> void:
	answer.emit(ok, text)


# --- Sync ------------------------------------------------------------------------------------------

func _on_world_changed() -> void:
	if _is_host():
		_broadcast()


func _broadcast() -> void:
	var d: Variant = GameState.world.get("staff")
	var m: Dictionary = (d as Dictionary).get("members", {}) if d is Dictionary else {}
	var c: Array = (d as Dictionary).get("candidates", []) if d is Dictionary else []
	_set_members(m.duplicate(true), c.duplicate(true))
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and multiplayer.get_peers().size() > 0:
		_set_members.rpc(m, c)
	Legal.sync()


## Client: ask for the members list (its World is up).
func request_sync() -> void:
	if _is_host():
		_broadcast()
	else:
		_request_sync.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_sync() -> void:
	if multiplayer.is_server():
		var d: Variant = GameState.world.get("staff")
		var m: Dictionary = (d as Dictionary).get("members", {}) if d is Dictionary else {}
		var c: Array = (d as Dictionary).get("candidates", []) if d is Dictionary else []
		_set_members.rpc_id(multiplayer.get_remote_sender_id(), m, c)
		Legal.sync()


@rpc("authority", "call_remote", "reliable")
func _set_members(m: Dictionary, c: Array) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server() and m.size() != members.size():
		print("[Staff] client %d: %d crew members %s" % [multiplayer.get_unique_id(), m.size(),
				m.values().map(func(r: Dictionary) -> String: return "%s/%s@%s" % [r["name"], r["role"], r.get("pos")])])
	members = m
	candidates = c
	if _views and is_instance_valid(_views):
		_views.rebuild(members)
	members_changed.emit()


# --- Host: helpers ---------------------------------------------------------------------------------

func _player_named(who: String) -> Player:
	for p: Node in get_tree().get_nodes_in_group(&"players"):
		if (p as Player).player_name == who:
			return p as Player
	return null


func _send_wallet(who: String) -> void:
	var p: Player = _player_named(who)
	if p:
		p.send_wallet()


## Host: a phone text from Benny / a dealer to the member's employer (if online).
func _text(who: String, text: String, contact: String = BENNY) -> void:
	var p: Player = _player_named(who)
	if p:
		p.phone_message(contact, text, "")


## Tests: hire without the phone (returns the host message).
func debug_hire(who: String, role: String, place: String) -> String:
	var cands: Array = _data()["candidates"]
	cands.append(_make_candidate(role))
	return host_hire(who, cands.size() - 1, place)
