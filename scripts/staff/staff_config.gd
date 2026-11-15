class_name StaffConfig
extends Resource
## Staff + dealers (DESIGN "Staff"): every number in one place. Tune in the Inspector
## (data/staff/staff.tres). Hours are in-game hours (DayNight; F7 speeds them up).

## role -> {name, rank, wage (€ per in-game day), about, later (true = not in the game yet)}.
@export var roles: Dictionary = {
	"grower": {"name": "Grower", "rank": 1, "wage": 80,
			"about": "Fills, plants, waters and harvests the weed pots in a property (harvest onto the racks) and tends the coca beds (seedlings + soil from the locker)."},
	"packager": {"name": "Packager", "rank": 2, "wage": 100,
			"about": "Takes dried weed off the racks and packages weed, meth shards and cocaine at a packaging table (baggies from the locker)."},
	"cook": {"name": "Cook", "rank": 2, "wage": 150,
			"about": "Runs the machines in a property from the storage locker: meth (cooking station, cooling plate) and cocaine (leaf press, refinery). Stirs and vents in time."},
	"courier": {"name": "Courier", "rank": 3, "wage": 120,
			"about": "Works from a property: buys the supplies its stations use into the locker, brings your dealers bags from the locker and their cash back to you."},
	"guard": {"name": "Guard", "rank": 4, "wage": 200,
			"about": "Guards a property against Crow raids: takes one raider down first, and holds the place while you're away."},
	"dealer": {"name": "Dealer", "rank": 1, "wage": 0,
			"about": "Sells your bags in a district for a commission. Give them stock, collect the cash."},
}
## Worker actions per in-game hour (one action = water/plant/fill/harvest one pot, or package one bag).
@export var grower_actions_per_hour: float = 4.0
@export var packager_bags_per_hour: float = 6.0
## Cook actions per in-game hour (start a cook, stir, pour a tray, break a tray).
@export var cook_actions_per_hour: float = 3.0
## Courier trips per in-game hour (one trip = buy one supply, or restock + collect one dealer).
@export var courier_trips_per_hour: float = 1.0
## Supplies a courier keeps in the property's lockers (id -> how many), bought only when a station there uses them
## (`courier_uses`) and the crew's rank allows buying it. Price = base price x `courier_markup`.
@export var courier_stock: Dictionary = {"soil": 4, "weed_seed": 4, "baggie": 20, "lab_chemicals": 4, "activator": 2,
		"coca_seedling": 4, "process_fluid": 2}
@export var courier_uses: Dictionary = {"grow_pot": ["soil", "weed_seed"], "packaging_table": ["baggie"],
		"cook_station": ["lab_chemicals", "activator"], "coca_bed": ["coca_seedling", "soil"], "leaf_press": ["process_fluid"]}
@export var courier_markup: float = 1.1
## A courier restocks a dealer whose stock is below this part of `dealer_capacity`.
@export var courier_restock_below: float = 0.5
## Workers in one property: at most one per bed or storage locker placed in it.
@export var bed_items: PackedStringArray = ["bed", "storage_locker", "staff_locker"]
## NOTES part 12: most stations one worker can be assigned to (E on the worker), per role.
@export var max_stations: Dictionary = {"grower": 6, "cook": 4, "packager": 3}

@export_group("Dealers")
## Most dealers the crew may have, index = rank.
@export var max_dealers: PackedInt32Array = [0, 1, 1, 2, 2, 4, 5]
## Bags a dealer holds at most.
@export var dealer_capacity: int = 20
## Commission range of new dealer candidates (part of each sale they keep).
@export var commission_min: float = 0.15
@export var commission_max: float = 0.30
## Chance per in-game hour that a dealer with stock gets arrested (stock + cash lost, dealer gone).
@export var arrest_chance_per_hour: float = 0.004
## Disloyal dealers (loyalty below `betray_below`) run off with stock + cash with this chance per hour.
@export var betray_chance_per_hour: float = 0.02
@export var betray_below: float = 25.0
## Loyalty (0-100): +collect_loyalty per collection, -per hour while more than `greedy_cash` waits uncollected.
@export var start_loyalty: float = 60.0
@export var collect_loyalty: float = 6.0
@export var greedy_cash: int = 600
@export var greed_loyalty_per_hour: float = 1.5
## XP for the crew per bag a dealer sells.
@export var xp_per_dealer_bag: int = 4
## Territory influence per bag a dealer sells in their district (a fair street sale by a player = 4, A's Territory).
@export var turf_per_dealer_bag: float = 2.0
## Districts: id -> {name, anchor (pavement near here, snapped to the navmesh), sales_per_hour, price}.
@export var districts: Dictionary = {
	"old_town": {"name": "Old Town", "anchor": Vector3(-24.0, 0.0, -4.6), "sales_per_hour": 1.2, "price": 55},
	"main_east": {"name": "Main Road East", "anchor": Vector3(36.0, 0.0, 4.6), "sales_per_hour": 1.5, "price": 60},
	"north": {"name": "North Road", "anchor": Vector3(18.0, 0.0, -43.4), "sales_per_hour": 0.9, "price": 70},
	"south": {"name": "South Street", "anchor": Vector3(-34.0, 0.0, 55.4), "sales_per_hour": 1.0, "price": 65},
	"docks": {"name": "The Docks", "anchor": Vector3(-110.4, 0.0, 40.0), "sales_per_hour": 0.8, "price": 75},
	"countryside": {"name": "Countryside", "anchor": Vector3(-146.0, 0.0, -60.0), "sales_per_hour": 0.5, "price": 80},
}

@export_group("Hiring")
## Candidates Benny offers at a time (refreshed every in-game day and after each hire).
@export var candidates: int = 5
@export var first_names: PackedStringArray = ["Mia", "Jonas", "Lena", "Tibo", "Yara", "Arne", "Zoë", "Lucas", "Noor",
		"Stijn", "Emma", "Ruben", "Fien", "Wannes", "Lies", "Jarne", "Amira", "Kobe", "Saar", "Ilias"]
