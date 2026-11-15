class_name RankConfig
extends Resource
## Ranks + XP (DESIGN "Progression"): every number in one place. Tune in the Inspector
## (data/progression/ranks.tres). Arrays are indexed by rank (0 = Street Hustler .. 6 = Godfather).

## Rank names, index = rank.
@export var names: PackedStringArray = ["Street Hustler", "Hustler", "Dealer", "Plug", "Boss", "Kingpin", "Godfather"]
## Total crew XP needed for each rank (index 0 must be 0).
@export var xp_for_rank: PackedInt32Array = [0, 300, 1000, 2500, 5000, 9000, 15000]
## What a rank unlocks, as shown in the HUD and the rank-up banner. Things that don't exist
## yet in the game are listed as "(later)".
@export var unlock_text: PackedStringArray = [
	"Weed, pistol, phone + webshop, Starter Room",
	"Grow lamp, Premium Weed Seeds (better quality), shotgun, Small House, a grower, 1 dealer",
	"Meth (cooking station, cooling plate, lab supplies + Pure Reagent at the black market), a cook, SMG, Bakery front, Family House, Hollow Farm Barn, packagers, the shooting range (Hollow Creek Gun Club: drills + try any gun)",
	"Couriers, Fume Hood (better meth/cocaine quality), AK-47, Barber + Laundromat fronts, Lab Warehouse, 2 dealers",
	"Cocaine (coca bed, leaf press, refinery, Pure Solvent at the black market), sniper rifle, South Warehouse, Harbour Storage, a lawyer, guards (Crows raid your labs), bulk deals (the Dutchman buys 20-40 bags at once)",
	"Bribe the police, up to 4 dealers, the roadside team (tow your car to you)",
	"Up to 5 dealers. (Later: attack the Crows' HQ, the highway to region 2)",
]
## Item id -> rank needed to BUY it in a shop (ids not listed: rank 0). Owning/using is never blocked.
@export var item_rank: Dictionary = {
	&"grow_lamp": 1, &"shotgun": 1, &"premium_seed": 1,
	&"smg": 2,
	&"cook_station": 2, &"cooling_plate": 2, &"lab_chemicals": 2, &"activator": 2, &"pure_reagent": 2,
	&"ak47": 3, &"fume_hood": 3,
	&"sniper": 4,
	&"coca_seedling": 4, &"process_fluid": 4, &"coca_bed": 4, &"leaf_press": 4, &"refinery": 4, &"pure_solvent": 4,
}
## Property id -> rank needed to buy it from the estate agent (ids not listed: rank 0).
@export var property_rank: Dictionary = {
	&"small_house": 1,
	&"bakery": 2, &"family_house": 2, &"barn": 2,
	&"barber": 3, &"laundromat": 3, &"lab_warehouse": 3,
	&"south_warehouse": 4, &"harbor_storage": 4,
}

@export_group("XP")
## A fair sale: XP per bag sold.
@export var xp_per_bag: int = 10
## Extra XP per finished deal (on top of the bags; since point 34 every sale is a phone deal).
@export var xp_per_deal: int = 15
## A short-changed sale gives this part of the XP; a customer who runs gives none.
@export var xp_short_factor: float = 0.5
## Fights: XP for killing a Black Crow / a police officer / a civilian.
@export var xp_kill_rival: int = 40
@export var xp_kill_officer: int = 10
@export var xp_kill_civilian: int = 0
