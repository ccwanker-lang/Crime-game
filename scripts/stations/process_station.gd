class_name ProcessStation
extends Station
## Milestone 3 (meth / cocaine): a generic machine that turns a fixed set of input items into
## output items over a number of in-game hours. Abstract game mechanic, no real procedures.
##   IDLE -> E with the inputs in your pockets loads them and starts -> RUNNING (progress 0..1)
##   -> DONE -> E takes the output (what doesn't fit stays in the machine).
## Subclasses set the recipe in `_init` (inputs/output/hours/labels) and build their visuals
## in `_build` + `state_changed`. Staff (cook) use `staff_load` / `staff_take` / `staff_attend`.

enum Stage { IDLE, RUNNING, DONE }

## Item id -> count needed per run.
var inputs: Dictionary = {}
var output_id: String = ""
var output_count: int = 1
var hours: float = 1.0
## Shown in prompts: "Cooking station", "Cooling plate"...
var label: String = "Machine"
## "Start cooking", "Pour the tray"...
var start_verb: String = "Start"
var work_start: String = "pack"
var work_take: String = "take"
## Optional hands-on moment while running (stir a cook, water a plant): from progress `attend_at`
## (-1 = none) the run waits for E; attended = `output_count`, never attended = `missed_count`.
var attend_at: float = -1.0
var missed_count: int = 1
## "Stir the batch", "Water the plants"; shown in the prompt. `attend_flag` floats over the station.
var attend_verb: String = "Attend"
var attend_flag: String = "!"
var attend_done: String = "Done."
var work_attend: String = "water"
## Product quality (Quality): a tiered input carries its tier to the output (cooling plate: Good tray -> Good
## shards). A `quality_step` machine (cooking station, refinery) is where quality is made: +1 when a `mix_id`
## item is at hand at the start (consumed), +1 with a Fume Hood within FumeHood.RANGE.
var quality_step: bool = false
var mix_id: String = ""


func default_state() -> Dictionary:
	return {"stage": Stage.IDLE, "progress": 0.0, "out": 0, "attend": 0, "tier": 1}  # attend: 0 not yet, 1 needed now, 2 done


func pick_up_blocker() -> String:
	return "" if int(state["stage"]) == Stage.IDLE else "Empty the %s first." % label.to_lower()


func tick(h: float) -> bool:
	if int(state["stage"]) != Stage.RUNNING:
		return false
	state["progress"] = minf(1.0, float(state["progress"]) + h / hours)
	_on_progress()
	if float(state["progress"]) >= 1.0 and _is_host():
		state["stage"] = Stage.DONE
		state["out"] = _yield()
		changed()
	return true


## Host, while running: the attend moment comes up.
func _on_progress() -> void:
	if attend_at >= 0.0 and int(state["attend"]) == 0 and float(state["progress"]) >= attend_at and _is_host():
		state["attend"] = 1
		changed()


func needs_attention() -> bool:
	return int(state["stage"]) == Stage.RUNNING and int(state["attend"]) == 1


## The output item of the current run at its quality ("meth_tray_q2").
func out_id() -> String:
	return Quality.with_tier(output_id, int(state.get("tier", 1)))


## Fume Hood (FumeHood) within range: +1 quality on a quality_step machine.
func hood_near() -> bool:
	for h: Node in get_tree().get_nodes_in_group(&"fume_hoods"):
		if (h as Node3D).global_position.distance_to(global_position) <= FumeHood.RANGE:
			return true
	return false


## Picks the inputs (best quality first) with `count(id) -> int`; {} if something is missing, else
## {"take": {id: n}, "tier": run quality before the quality_step bonus}.
func _plan(count: Callable) -> Dictionary:
	var take: Dictionary = {}
	var tier: int = 0
	for id: String in inputs:
		var v: String = Quality.best_with(id, int(inputs[id]), count)
		if v == "":
			return {}
		take[v] = int(inputs[id])
		if Quality.is_tiered(id):
			tier = Quality.tier(v) if tier == 0 else mini(tier, Quality.tier(v))
	return {"take": take, "tier": maxi(tier, 1)}


## Run quality after the quality_step bonus; takes one `mix_id` with `take(id, n)` when `count` has it.
func _quality_for(tier: int, count: Callable, take: Callable) -> int:
	if not quality_step:
		return tier
	if mix_id != "" and int(count.call(mix_id)) > 0:
		take.call(mix_id, 1)
		tier += 1
	if hood_near():
		tier += 1
	return clampi(tier, 1, Quality.MAX)


## Output count of a finished run.
func _yield() -> int:
	if attend_at < 0.0:
		return output_count
	return output_count if int(state["attend"]) == 2 else missed_count


func inputs_text() -> String:
	var parts: PackedStringArray = []
	for id: String in inputs:
		parts.append("%d %s" % [int(inputs[id]), item_name(id)])
	return " + ".join(parts)


func status_text() -> String:
	if needs_attention():
		return "%s: %d%% - %s!" % [label, int(float(state["progress"]) * 100.0), attend_verb.to_lower()]
	match int(state["stage"]):
		Stage.RUNNING:
			return "%s: %d%%" % [label, int(float(state["progress"]) * 100.0)]
		Stage.DONE:
			return "%s: %d %s ready" % [label, int(state["out"]), item_name(out_id())]
	return "%s (empty)" % label


## Owner side: can the carried items start a run?
func _has_inputs_carried(player: Player) -> bool:
	return not _plan(func(id: String) -> int: return carried(player, id)).is_empty()


func prompt_for(player: Player) -> String:
	if needs_attention():
		return "%s   [%s]" % [attend_verb, status_text()]
	match int(state["stage"]):
		Stage.RUNNING:
			return status_text()
		Stage.DONE:
			return "Take %d %s   [%s]" % [int(state["out"]), item_name(out_id()), label]
	if _has_inputs_carried(player):
		var extra: String = ""
		if quality_step and mix_id != "" and carried(player, mix_id) > 0:
			extra = " + 1 %s: +1 quality" % item_name(mix_id)
		return "%s  (uses %s%s)" % [start_verb, inputs_text(), extra]
	return "%s - bring %s" % [label, inputs_text()]


func do_action(player: Player) -> String:
	var who: String = player.player_name
	match int(state["stage"]):
		Stage.RUNNING:
			if needs_attention():
				state["attend"] = 2
				changed()
				work = work_attend
				return attend_done
			return "%s: %d%%." % [label, int(float(state["progress"]) * 100.0)]
		Stage.DONE:
			var oid: String = out_id()
			var n: int = mini(int(state["out"]), GameState.space_for(who, oid))
			if n <= 0:
				return "Your pockets are full."
			GameState.give(who, 0, [{"id": oid, "count": n}])
			_took(n)
			work = work_take
			return "Took %d %s." % [n, item_name(oid)]
	var count := func(id: String) -> int: return GameState.count_item(who, id)
	var remove := func(id: String, n: int) -> void: GameState.remove_item(who, id, n)
	var plan: Dictionary = _plan(count)
	if plan.is_empty():
		return "You need %s." % inputs_text()
	for id: String in plan["take"]:
		remove.call(id, int(plan["take"][id]))
	_start(_quality_for(int(plan["tier"]), count, remove))
	work = work_start
	var q: String = Quality.NAMES[int(state["tier"])]
	return "%s: done in about %d hours.%s" % [label, ceili(hours),
			(" Quality: %s." % q) if Quality.is_tiered(output_id) else ""]


func _start(tier: int = 1) -> void:
	state["stage"] = Stage.RUNNING
	state["progress"] = 0.0
	state["out"] = 0
	state["attend"] = 0
	state["tier"] = tier
	if _is_host():
		Quality.host_made(Quality.with_tier(output_id, tier))
	changed()


func _took(n: int) -> void:
	state["out"] = int(state["out"]) - n
	if int(state["out"]) <= 0:
		state["stage"] = Stage.IDLE
		state["progress"] = 0.0
		state["out"] = 0
	changed()


# --- Staff (host) ------------------------------------------------------------------------------

## Starts a run with inputs from storage: `take(id, count) -> bool` removes them. True if started.
func staff_load(have: Callable, take: Callable) -> bool:
	if int(state["stage"]) != Stage.IDLE:
		return false
	var plan: Dictionary = _plan(have)
	if plan.is_empty():
		return false
	for id: String in plan["take"]:
		take.call(id, int(plan["take"][id]))
	_start(_quality_for(int(plan["tier"]), have, take))
	return true


## Takes the finished output: `put(id, count) -> int` returns what did NOT fit. Returns how many were taken.
func staff_take(put: Callable) -> int:
	if int(state["stage"]) != Stage.DONE:
		return 0
	var n: int = int(state["out"])
	var left: int = int(put.call(out_id(), n))
	if n - left > 0:
		_took(n - left)
	return n - left


## Hands-on step while running (stir, water). True if the worker did something.
func staff_attend() -> bool:
	if needs_attention():
		state["attend"] = 2
		changed()
		return true
	return false


## Label3D with `attend_flag` (call in _build); shown while the station needs attention.
func make_attend_label(at: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = attend_flag
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(1.0, 0.6, 0.15)
	l.outline_size = 8
	l.font_size = 48
	l.pixel_size = 0.004
	l.position = at
	l.visible = false
	add_child(l)
	return l
