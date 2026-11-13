class_name WantedConfig
extends Resource
## Point 28: every number of the wanted system (GTA-style stars). Tune in the Inspector
## (data/police/wanted.tres). Arrays are indexed by star count (0..5) unless noted.

## Heat needed for 1..5 stars (index 0 = 1 star). A civilian kill adds `kill_heat`.
@export var heat_for_star: PackedInt32Array = [1, 6, 12, 20, 30]
@export var kill_heat: int = 1
## An officer killed: this much heat and at least `officer_kill_stars`.
@export var officer_kill_heat: int = 3
@export var officer_kill_stars: int = 2
## Shooting at the police (hit an officer or a patrol car), resisting arrest.
@export var assault_stars: int = 2
@export var resist_stars: int = 2
## A driving patrol car sees a wanted player this close (line of sight).
@export var car_sight_range: float = 30.0

## Point 28b: the search phase. Out of sight of every officer / patrol car this many seconds
## (index = current stars) and ALL stars go at once; seen again = the timer starts over.
@export var search_time: PackedFloat32Array = [0.0, 10.0, 20.0, 30.0, 40.0, 50.0]
## Inside a crew-owned property the search timer runs this many times faster.
@export var hide_multiplier: float = 3.0

## Point 28c: EXTRA police cars sent after one player, on top of the town's normal patrol
## cars (2, Traffic). They drive off and disappear once the stars are gone.
@export var units_per_star: PackedInt32Array = [0, 1, 1, 2, 3, 4]
## Officers in a car sent after a player.
@export var crew_per_star: PackedInt32Array = [0, 1, 2, 2, 3, 3]
## From this many stars the police shoot as soon as they see you.
@export var shoot_on_sight_stars: int = 3
## From this many stars they shoot when you hold a weapon (below: arrest, unless you resist).
@export var shoot_armed_stars: int = 2
## From this many stars: heavy teams (SMG, more health, sharper) and road blocks.
@export var heavy_stars: int = 4
@export var roadblock_stars: int = 4
@export var max_roadblocks: int = 2
## Sent cars start this far (along the road) before the last known spot.
@export var dispatch_distance: float = 75.0
## Seconds between sending cars after the same player.
@export var dispatch_interval: float = 7.0
## Never more police cars in town than this (patrols included).
@export var max_police_cars: int = 10
## A sent car stops and its crew gets out this close to the last known spot.
@export var arrive_distance: float = 25.0
## Police cars with the siren on drive this much faster than normal traffic.
@export var siren_speed: float = 1.45
