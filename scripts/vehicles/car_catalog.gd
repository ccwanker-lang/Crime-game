class_name CarCatalog
extends RefCounted
## Point 45: the cars Carlo's Cars sells (game data). `kind` = ProcCar.Kind (the look), the rest is how it drives.
## Prices are in euro; a car is a legal purchase (clean money first, like a property).

const MODELS: Dictionary = {
	"hatch": {"name": "Pony Hatch", "kind": ProcCar.Kind.HATCHBACK, "price": 4500, "max_speed": 15.0, "accel": 5.0,
			"seats": 4, "text": "Small, cheap, parks anywhere."},
	"sedan": {"name": "Comet Sedan", "kind": ProcCar.Kind.SEDAN, "price": 9000, "max_speed": 19.0, "accel": 6.5,
			"seats": 4, "text": "Quick and comfortable, room for the whole crew."},
	"van": {"name": "Mule Van", "kind": ProcCar.Kind.VAN, "price": 14000, "max_speed": 14.5, "accel": 4.2,
			"seats": 2, "text": "Slow but roomy. Nobody looks twice at a van."},
}
## Paint per model on the lot (index into ProcCar.PAINTS); the buyer gets the car in that colour.
const LOT_PAINT: Dictionary = {"hatch": 8, "sedan": 4, "van": 0}


static func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in MODELS.keys():
		out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool: return int(MODELS[a]["price"]) < int(MODELS[b]["price"]))
	return out


static func get_model(id: String) -> Dictionary:
	return MODELS.get(id, MODELS["hatch"])


static func money(n: int) -> String:
	return Property.money(n)
