class_name DayRhythmConfig
extends Resource
## Roadmap 88 (session B): when the village's ambient pedestrians are out. Every pedestrian belongs to one time block;
## outside its block it is "inside" its own house (data only). Used by `DayRhythm` (World/DayRhythm, host).

## Block names, in order.
@export var block_names: PackedStringArray = PackedStringArray(["morning", "afternoon", "evening", "night"])
## Start hour of each block (a block ends where the next one starts; the last one wraps round midnight).
@export var block_start: PackedFloat32Array = PackedFloat32Array([9.0, 12.0, 16.0, 22.0])
## Share of the whole population in each block (sums to 1).
@export var block_share: PackedFloat32Array = PackedFloat32Array([0.3, 0.3, 0.3, 0.1])
## How many walk outside in the busiest block (= the old fixed pedestrian count). The population is this divided by
## the biggest share, so the busiest block looks like before and the night is quieter.
@export var outside_busiest: int = 10
## Seconds between two host checks.
@export var interval: float = 2.0
## A pedestrian never steps out of its door while a player within this distance is looking at it.
@export var no_pop_radius: float = 35.0
## Half the viewing cone (degrees) used for that check.
@export var view_half_angle: float = 70.0
## Seconds a pedestrian gets to walk home; after that it simply goes inside once no player is near.
@export var go_home_timeout: float = 150.0
## Chance that a new customer is someone at home (home delivery: steps out of the door, deals, goes back in).
@export var home_deal_chance: float = 0.35
## A home customer's door is at most this far from a player (so the deal is reachable).
@export var home_deal_range: float = 160.0
## Seconds before a dead pedestrian's "slot" comes out of its door again.
@export var respawn_time: float = 60.0
