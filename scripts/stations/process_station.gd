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


func default_state() -> Dictionary:
	return {"stage": Stage.IDLE, "progress": 0.0, "out": 0}


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


## Host, while running (subclasses: events like "needs a stir").
func _on_progress() -> void:
	pass


## Output count of a finished run (subclasses: quality / mistakes).
func _yield() -> int:
	return output_count


func inputs_text() -> String:
	var parts: PackedStringArray = []
	for id: String in inputs:
		parts.append("%d %s" % [int(inputs[id]), item_name(id)])
	return " + ".join(parts)


func status_text() -> String:
	match int(state["stage"]):
		Stage.RUNNING:
			return "%s: %d%%" % [label, int(float(state["progress"]) * 100.0)]
		Stage.DONE:
			return "%s: %d %s ready" % [label, int(state["out"]), item_name(output_id)]
	return "%s (empty)" % label


## Owner side: can the carried items start a run?
func _has_inputs_carried(player: Player) -> bool:
	for id: String in inputs:
		if carried(player, id) < int(inputs[id]):
			return false
	return true


func prompt_for(player: Player) -> String:
	match int(state["stage"]):
		Stage.RUNNING:
			return status_text()
		Stage.DONE:
			return "Take %d %s   [%s]" % [int(state["out"]), item_name(output_id), label]
	if _has_inputs_carried(player):
		return "%s  (uses %s)" % [start_verb, inputs_text()]
	return "%s - bring %s" % [label, inputs_text()]


func do_action(player: Player) -> String:
	var who: String = player.player_name
	match int(state["stage"]):
		Stage.RUNNING:
			return ""
		Stage.DONE:
			var n: int = mini(int(state["out"]), GameState.space_for(who, output_id))
			if n <= 0:
				return "Your pockets are full."
			GameState.give(who, 0, [{"id": output_id, "count": n}])
			_took(n)
			work = work_take
			return "Took %d %s." % [n, item_name(output_id)]
	for id: String in inputs:
		if GameState.count_item(who, id) < int(inputs[id]):
			return "You need %s." % inputs_text()
	for id: String in inputs:
		GameState.remove_item(who, id, int(inputs[id]))
	_start()
	work = work_start
	return "%s: done in about %d hours." % [label, ceili(hours)]


func _start() -> void:
	state["stage"] = Stage.RUNNING
	state["progress"] = 0.0
	state["out"] = 0
	_on_start()
	changed()


## Host: a run starts (subclasses reset their extra state here).
func _on_start() -> void:
	pass


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
	for id: String in inputs:
		if int(have.call(id)) < int(inputs[id]):
			return false
	for id: String in inputs:
		take.call(id, int(inputs[id]))
	_start()
	return true


## Takes the finished output: `put(id, count) -> int` returns what did NOT fit. Returns how many were taken.
func staff_take(put: Callable) -> int:
	if int(state["stage"]) != Stage.DONE:
		return 0
	var n: int = int(state["out"])
	var left: int = int(put.call(output_id, n))
	if n - left > 0:
		_took(n - left)
	return n - left


## Hands-on step while running (stir...). True if the worker did something.
func staff_attend() -> bool:
	return false
