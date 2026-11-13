class_name StaffConfig
extends Resource
## Staff + dealers (DESIGN "Staff"): every number in one place. Tune in the Inspector
## (data/staff/staff.tres). Hours are in-game hours (DayNight; F7 speeds them up).

## role -> {name, rank, wage (€ per in-game day), about, later (true = not in the game yet)}.
@export var roles: Dictionary = {
	"grower": {"name": "Grower", "rank": 1, "wage": 80,
			"about": "Fills, plants, waters and harvests the pots in a property; hangs the harvest on the racks."},
	"packager": {"name": "Packager", "rank": 2, "wage": 100,
			"about": "Takes dried weed off the racks and packages it at a packaging table (baggies from the locker)."},
	"cook": {"name": "Cook", "rank": 2, "wage": 150, "later": true, "about": "Runs the meth stations (comes with meth)."},
	"courier": {"name": "Courier", "rank": 3, "wage": 120, "later": true,
			"about": "Fetches supplies and restocks your dealers (later)."},
	"dealer": {"name": "Dealer", "rank": 1, "wage": 0,
			"about": "Sells your bags in a district for a commission. Give them stock, collect the cash."},
}
## Worker actions per in-game hour (one action = water/plant/fill/harvest one pot, or package one bag).
@export var grower_actions_per_hour: float = 4.0
@export var packager_bags_per_hour: float = 6.0
## Workers in one property: at most one per bed or storage locker placed in it.
@export var bed_items: PackedStringArray = ["bed", "storage_locker"]

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
## Districts: id -> {name, anchor (pavement near here, snapped to the navmesh), sales_per_hour, price}.
@export var districts: Dictionary = {
	"old_town": {"name": "Old Town", "anchor": Vector3(-24.0, 0.0, -4.6), "sales_per_hour": 1.2, "price": 55},
	"main_east": {"name": "Main Road East", "anchor": Vector3(36.0, 0.0, 4.6), "sales_per_hour": 1.5, "price": 60},
	"north": {"name": "North Road", "anchor": Vector3(18.0, 0.0, -43.4), "sales_per_hour": 0.9, "price": 70},
	"south": {"name": "South Street", "anchor": Vector3(-34.0, 0.0, 49.4), "sales_per_hour": 1.0, "price": 65},
}

@export_group("Hiring")
## Candidates Benny offers at a time (refreshed every in-game day and after each hire).
@export var candidates: int = 5
@export var first_names: PackedStringArray = ["Mia", "Jonas", "Lena", "Tibo", "Yara", "Arne", "Zoë", "Lucas", "Noor",
		"Stijn", "Emma", "Ruben", "Fien", "Wannes", "Lies", "Jarne", "Amira", "Kobe", "Saar", "Ilias"]
