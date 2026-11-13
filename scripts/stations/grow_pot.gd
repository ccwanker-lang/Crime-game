class_name GrowPot
extends Station
## Pot for one weed plant. E does the next step, using what the player carries:
##   empty -> fill with a Bag of Soil -> plant a Weed Seed -> water it with the
##   Watering Can (the plant only grows while the soil is wet) -> harvest Fresh
##   Weed (the soil is used up, the pot is empty again).
## A lit GrowLamp above the pot makes it grow faster.

enum Stage { EMPTY, SOIL, GROWING, READY }

## In-game hours from seed to harvest without a lamp (1 game hour = 1 real minute).
const GROW_HOURS: float = 8.0
## One watering keeps the soil wet this long.
const WATER_HOURS: float = 4.0
## Water it again below this level.
const REFILL_BELOW: float = 0.75
const YIELD: int = 4

const RIM_HEIGHT: float = 0.3
const SOIL_HEIGHT: float = 0.26

var _plant: WeedPlant
var _soil_dry: MeshInstance3D
var _soil_wet: MeshInstance3D
var _shape: CylinderShape3D
var _collision: CollisionShape3D


func default_state() -> Dictionary:
	return {"stage": Stage.EMPTY, "water": 0.0, "growth": 0.0, "seed": 0}


func pick_up_blocker() -> String:
	return "Harvest the plant first." if int(state["stage"]) >= Stage.GROWING else ""


func refund_items() -> Array:
	return [{"id": "soil", "count": 1}] if int(state["stage"]) == Stage.SOIL else []


func _build() -> void:
	var b := MeshBuilder.new()
	# Tapered plastic pot with a rolled rim, open at the top.
	b.cylinder(&"pot_plastic", Vector3.ZERO, Vector3(0, RIM_HEIGHT - 0.03, 0), 0.12, 0.155, 16, false)
	b.cylinder(&"pot_plastic", Vector3(0, RIM_HEIGHT - 0.035, 0), Vector3(0, RIM_HEIGHT, 0), 0.165, 0.165, 16, false)
	var bottom := PackedVector3Array()
	for i: int in 16:
		var a: float = TAU * i / 16.0
		bottom.append(Vector3(cos(a) * 0.12, 0.001, sin(a) * 0.12))
	b.poly(&"pot_plastic", bottom, Vector3.DOWN)
	# Inner wall + floor, facing inward (seen from above when the pot is empty).
	for i: int in 16:
		var a0: float = TAU * i / 16.0
		var a1: float = TAU * (i + 1) / 16.0
		var mid: float = (a0 + a1) * 0.5
		b.poly(&"pot_plastic", PackedVector3Array([
			Vector3(cos(a0) * 0.118, 0.04, sin(a0) * 0.118), Vector3(cos(a1) * 0.118, 0.04, sin(a1) * 0.118),
			Vector3(cos(a1) * 0.148, RIM_HEIGHT, sin(a1) * 0.148), Vector3(cos(a0) * 0.148, RIM_HEIGHT, sin(a0) * 0.148)]),
			-Vector3(cos(mid), 0, sin(mid)))
	b.poly(&"pot_plastic", _disk(0.118, 0.04), Vector3.UP)
	for i: int in 16:  # flat top of the rim
		var a0: float = TAU * i / 16.0
		var a1: float = TAU * (i + 1) / 16.0
		b.poly(&"pot_plastic", PackedVector3Array([
			Vector3(cos(a0) * 0.148, RIM_HEIGHT, sin(a0) * 0.148), Vector3(cos(a1) * 0.148, RIM_HEIGHT, sin(a1) * 0.148),
			Vector3(cos(a1) * 0.165, RIM_HEIGHT, sin(a1) * 0.165), Vector3(cos(a0) * 0.165, RIM_HEIGHT, sin(a0) * 0.165)]),
			Vector3.UP)
	var pot := MeshInstance3D.new()
	pot.mesh = b.build()
	add_child(pot)

	_soil_dry = _soil_disk(&"soil_dry")
	_soil_wet = _soil_disk(&"soil_wet")

	_plant = WeedPlant.new()
	_plant.position.y = SOIL_HEIGHT
	add_child(_plant)

	_shape = CylinderShape3D.new()
	_shape.radius = 0.17
	_collision = CollisionShape3D.new()
	_collision.shape = _shape
	add_child(_collision)
	_set_collision_height(RIM_HEIGHT)


## The interact/collision cylinder covers the pot and the plant on it.
func _set_collision_height(h: float) -> void:
	if absf(_shape.height - h) < 0.02:
		return
	_shape.height = h
	_collision.position.y = h * 0.5


func _soil_disk(key: StringName) -> MeshInstance3D:
	var b := MeshBuilder.new()
	b.poly(key, _disk(0.147, SOIL_HEIGHT), Vector3.UP)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	return mi


static func _disk(r: float, y: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i: int in 16:
		var a: float = TAU * i / 16.0
		pts.append(Vector3(cos(a) * r, y, sin(a) * r))
	return pts


func state_changed() -> void:
	if _plant == null:
		return
	var stage: int = int(state["stage"])
	var water: float = float(state["water"])
	_soil_dry.visible = stage != Stage.EMPTY and water <= 0.0
	_soil_wet.visible = stage != Stage.EMPTY and water > 0.0
	_plant.visible = stage >= Stage.GROWING
	if _plant.visible:
		_plant.plant_seed = int(state["seed"])
		_plant.growth = float(state["growth"])
		_plant.thirst = 1.0 if (stage == Stage.GROWING and water <= 0.0) else 0.0
	var plant_h: float = 0.05 + (WeedPlant.MAX_HEIGHT - 0.05) * smoothstep(0.0, 1.0, float(state["growth"]))
	_set_collision_height(SOIL_HEIGHT + plant_h if _plant.visible else RIM_HEIGHT + 0.05)


func growth_rate() -> float:
	for lamp: Node in get_tree().get_nodes_in_group(&"grow_lamps"):
		if (lamp as GrowLamp).boosts(global_position):
			return GrowLamp.BOOST
	return 1.0


func tick(hours: float) -> bool:
	if int(state["stage"]) != Stage.GROWING:
		return false
	var water: float = float(state["water"])
	if water <= 0.0:
		return false
	var old_step: int = roundi(float(state["growth"]) * WeedPlant.STEPS)
	state["water"] = maxf(0.0, water - hours / WATER_HOURS)
	state["growth"] = minf(1.0, float(state["growth"]) + hours / GROW_HOURS * growth_rate())
	if float(state["growth"]) >= 1.0 and _is_host():
		state["stage"] = Stage.READY
		changed()
		return false
	return roundi(float(state["growth"]) * WeedPlant.STEPS) != old_step or float(state["water"]) <= 0.0


func status_text() -> String:
	match int(state["stage"]):
		Stage.EMPTY:
			return "Empty pot"
		Stage.SOIL:
			return "Pot with soil"
		Stage.GROWING:
			var w: float = float(state["water"])
			return "Weed plant %d%% - %s" % [int(float(state["growth"]) * 100.0),
					"DRY, not growing" if w <= 0.0 else "water %d%%" % int(w * 100.0)]
		_:
			return "Weed plant - ready to harvest"


func prompt_for(player: Player) -> String:
	var status: String = status_text()
	match int(state["stage"]):
		Stage.EMPTY:
			return ("Fill with soil" if carried(player, "soil") > 0 else "Needs a Bag of Soil (Store)") + "   [%s]" % status
		Stage.SOIL:
			return ("Plant a Weed Seed" if carried(player, "weed_seed") > 0 else "Needs a Weed Seed (Contact)") + "   [%s]" % status
		Stage.GROWING:
			if float(state["water"]) >= REFILL_BELOW:
				return status
			return ("Water the plant" if carried(player, "watering_can") > 0 else "Needs water (Watering Can)") + "   [%s]" % status
		_:
			return "Harvest %d Fresh Weed" % YIELD


func do_action(player: Player) -> String:
	var who: String = player.player_name
	match int(state["stage"]):
		Stage.EMPTY:
			if not GameState.remove_item(who, "soil", 1):
				return "You need a Bag of Soil."
			state["stage"] = Stage.SOIL
			state["water"] = 0.0
			changed()
			work = "soil"
			return "Filled the pot with soil."
		Stage.SOIL:
			if not GameState.remove_item(who, "weed_seed", 1):
				return "You need a Weed Seed."
			state["stage"] = Stage.GROWING
			state["growth"] = 0.0
			state["seed"] = randi() % 100000
			changed()
			work = "plant"
			return "Planted a seed. Water it!"
		Stage.GROWING:
			if float(state["water"]) >= REFILL_BELOW:
				return "It doesn't need water yet."
			if GameState.count_item(who, "watering_can") <= 0:
				return "You need a Watering Can."
			state["water"] = 1.0
			changed()
			work = "water"
			return "Watered the plant."
		_:
			if GameState.space_for(who, "fresh_weed") < YIELD:
				return "Your pockets are full."
			GameState.give(who, 0, [{"id": "fresh_weed", "count": YIELD}])
			state["stage"] = Stage.EMPTY
			state["growth"] = 0.0
			state["water"] = 0.0
			changed()
			# Point 39: stems and leaves are left over (a trash bin takes them).
			GameState.give(who, 0, [{"id": "plant_waste", "count": 1}])
			work = "harvest"
			return "Harvested %d Fresh Weed. Dry it on the rack." % YIELD
