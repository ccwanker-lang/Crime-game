class_name RepairBay
extends Station
## Point 52: the car lift in the cover garage. Once the crew owns the garage, a customer drops a car off every
## few in-game hours; E works on it (one step per press, with the work animation). Bigger jobs need Spare Parts
## (legal, QuickShip webshop). A finished job pays CLEAN money to whoever finished it (+ a little crew XP): the
## garage is a real business, the front of the hidden room behind the shelf. HOST AUTHORITATIVE (Station).

const JOBS: Array[Dictionary] = [
	{"name": "an oil change", "steps": 3, "parts": 0, "pay": 140},
	{"name": "new brake pads", "steps": 4, "parts": 1, "pay": 260},
	{"name": "a clutch repair", "steps": 5, "parts": 2, "pay": 420},
	{"name": "an engine tune-up", "steps": 6, "parts": 3, "pay": 600},
]
const CUSTOMERS: Array[String] = ["Mrs. de Wit", "Ahmed", "old Jan", "Sanne", "Mr. Peeters", "Lotte", "Kees", "Fatima"]
const XP_PER_JOB: int = 10

## In-game hours between a finished job and the next customer.
@export var wait_hours: Vector2 = Vector2(2.0, 4.0)

var _car: Node3D
var _car_shape: CollisionShape3D


func default_state() -> Dictionary:
	return {"job": -1, "done": 0, "parts_in": 0, "wait": 1.0, "kind": 0, "paint": 0, "who": "", "jobs_done": 0}


func pick_up_blocker() -> String:
	return "It's bolted to the floor."


func _build() -> void:
	# Two-post lift: yellow posts left and right of the car, arms under it, a base plate.
	var b := MeshBuilder.new()
	for x: float in [-1.45, 1.45]:
		b.box(&"metal_dark", Vector3(x, 0.03, 0), Vector3(0.5, 0.06, 0.5))
		b.color = Color(0.95, 0.72, 0.1)
		b.box(&"item_matte", Vector3(x, 1.4, 0), Vector3(0.22, 2.8, 0.26), 0.01)
	b.box(&"metal_dark", Vector3(0, 2.86, 0), Vector3(3.15, 0.14, 0.2))  # top beam
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	add_child(mi)
	for x: float in [-1.45, 1.45]:  # the posts
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.4, 2.9, 0.4)
		cs.shape = shape
		cs.position = Vector3(x, 1.45, 0)
		add_child(cs)
	# The customer's car (only while there is a job): solid + what E aims at.
	_car_shape = CollisionShape3D.new()
	var car_box := BoxShape3D.new()
	car_box.size = Vector3(1.8, 1.4, 4.4)
	_car_shape.shape = car_box
	_car_shape.position.y = 1.2
	_car_shape.disabled = true
	add_child(_car_shape)


func state_changed() -> void:
	var job: int = int(state.get("job", -1))
	if _car_shape:
		_car_shape.disabled = job < 0
	if job < 0:
		if _car:
			_car.queue_free()
			_car = null
		return
	if _car == null:
		_car = Node3D.new()
		_car.name = "CustomerCar"  # nose to the garage door (+Z), between the posts
		_car.rotation.y = PI
		add_child(_car)
		ProcCar.build(_car, int(state.get("kind", 0)), ProcCar.PAINTS[int(state.get("paint", 0)) % ProcCar.PAINTS.size()])
	# The more work done, the higher the lift.
	var steps: int = int(JOBS[job]["steps"])
	_car.position.y = 0.4 + 0.6 * float(state.get("done", 0)) / maxf(1.0, steps)


## The Property of the building this bay stands in (the garage), or null.
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


func _owned() -> bool:
	var prop: Property = property()
	return prop != null and prop.is_crew_owned()


func tick(hours: float) -> bool:
	if int(state.get("job", -1)) >= 0 or not _owned():
		return false
	state["wait"] = float(state.get("wait", 1.0)) - hours
	if float(state["wait"]) <= 0.0 and _is_host():
		new_job()
	return false


## Host: a customer drops a car off (also used by tests / scenarios with a fixed job).
func new_job(job: int = -1) -> void:
	state["job"] = job if job >= 0 else randi() % JOBS.size()
	state["done"] = 0
	state["parts_in"] = 0
	state["kind"] = randi() % 3
	state["paint"] = randi() % ProcCar.PAINTS.size()
	state["who"] = CUSTOMERS[randi() % CUSTOMERS.size()]
	changed()


func prompt_for(player: Player) -> String:
	if not _owned():
		return "Car lift (the garage is for sale at Vos Real Estate)"
	var job: int = int(state.get("job", -1))
	if job < 0:
		return "Car lift: no car yet (next customer in ~%d h)" % maxi(1, ceili(float(state.get("wait", 1.0))))
	var j: Dictionary = JOBS[job]
	var text: String = "Work on %s's car: %s (%d/%d)" % [state["who"], j["name"], int(state["done"]), int(j["steps"])]
	var need: int = int(j["parts"]) - int(state.get("parts_in", 0))
	if need > 0:
		text += "  - needs %d Spare Parts (you have %d)" % [need, Station.carried(player, "car_parts")]
	return text + "  - pays €%d clean" % int(j["pay"])


func do_action(player: Player) -> String:
	if not _owned():
		return "Buy the garage first (Vos Real Estate)."
	var job: int = int(state.get("job", -1))
	if job < 0:
		return "No car on the lift yet. Customers bring one every few hours."
	var j: Dictionary = JOBS[job]
	var need: int = int(j["parts"]) - int(state.get("parts_in", 0))
	if need > 0:
		if GameState.count_item(player.player_name, "car_parts") < need:
			return "This job needs %d Spare Parts (order them on your phone: Shop)." % need
		GameState.remove_item(player.player_name, "car_parts", need)
		state["parts_in"] = int(j["parts"])
	work = "repair"
	state["done"] = int(state.get("done", 0)) + 1
	if int(state["done"]) < int(j["steps"]):
		changed()
		return "Working on %s's car (%d/%d)" % [state["who"], int(state["done"]), int(j["steps"])]
	var pay: int = int(j["pay"])
	var who: String = str(state["who"])
	GameState.add_clean(player.player_name, pay)
	Progression.host_add(XP_PER_JOB, "repair", player)
	state["jobs_done"] = int(state.get("jobs_done", 0)) + 1
	state["job"] = -1
	state["done"] = 0
	state["parts_in"] = 0
	state["wait"] = randf_range(wait_hours.x, wait_hours.y)
	changed()
	print("[Garage] %s finished %s for %s: +€%d clean" % [player.player_name, j["name"], who, pay])
	return "Done: %s for %s. +€%d clean money." % [j["name"], who, pay]
