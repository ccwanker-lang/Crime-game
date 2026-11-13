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


func default_state() -> Dictionary:
	return {"stage": Stage.IDLE, "progress": 0.0, "out": 0, "attend": 0}  # attend: 0 not yet, 1 needed now, 2 done


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
			return "%s: %d %s ready" % [label, int(state["out"]), item_name(output_id)]
	return "%s (empty)" % label


## Owner side: can the carried items start a run?
func _has_inputs_carried(player: Player) -> bool:
	for id: String in inputs:
		if carried(player, id) < int(inputs[id]):
			return false
	return true


func prompt_for(player: Player) -> String:
	if needs_attention():
		return "%s   [%s]" % [attend_verb, status_text()]
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
			if needs_attention():
				state["attend"] = 2
				changed()
				work = work_attend
				return attend_done
			return "%s: %d%%." % [label, int(float(state["progress"]) * 100.0)]
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
	state["attend"] = 0
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
