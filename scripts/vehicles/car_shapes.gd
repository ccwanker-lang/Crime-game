class_name CarShapes
extends RefCounted
## Roadmap 65 (session B): car collision in two boxes instead of one, so people can jump onto a car and stand on
## it: the body (bonnet + boot height, full length) and the cabin on top (roof height, between the windscreen and
## the rear window, from ProcCar.SPECS). Used by Car (traffic) and PlayerCar. The total outline is the same as the
## old single box (ProcCar.collision_size), so traffic sensing, kerbs and hits are unchanged.


## Adds the two shapes to `body` (bottom of the body box at `bottom` m). The body box is named `body_name`.
static func add(body: CollisionObject3D, kind: int, bottom: float, body_name: String = "Shape") -> void:
	var s: Dictionary = ProcCar.SPECS[kind]
	var top: float = float(s["roof"])  # the painted roof (the old single box ended within 5 cm of it)
	var body_top: float = float(s["body"])
	var low := CollisionShape3D.new()
	low.name = body_name
	var lb := BoxShape3D.new()
	lb.size = Vector3(float(s["w"]), body_top - bottom, float(s["len"]))
	low.shape = lb
	low.position = Vector3(0, bottom + lb.size.y / 2.0, 0)
	body.add_child(low)
	var cab := CollisionShape3D.new()
	cab.name = "CabinShape"
	var cb := BoxShape3D.new()
	var cf: float = float(s["cab_f"])
	var cr: float = float(s["cab_b"])
	cb.size = Vector3(float(s["w"]) - 0.12, maxf(0.1, top - body_top), cr - cf)
	cab.shape = cb
	cab.position = Vector3(0, body_top + cb.size.y / 2.0, (cf + cr) / 2.0)
	body.add_child(cab)


## Height of the roof / the bonnet over the car's origin (tests).
static func roof_y(kind: int) -> float:
	return float(ProcCar.SPECS[kind]["roof"])


static func bonnet_y(kind: int) -> float:
	return float(ProcCar.SPECS[kind]["body"])
