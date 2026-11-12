class_name NpcCombatProfile
extends Resource
## Point 21: how well an armed NPC (police, later rivals) fights. Tune in the
## Inspector (data/npc/*.tres). Spread is a random cone around the aim line; it
## grows with the distance and when the target is moving, so NPCs miss a lot
## at range and against a running player.

## 0 = sprays everywhere, 1 = laser accurate (sets the base cone).
@export_range(0.0, 1.0) var accuracy: float = 0.4
## Seconds between first seeing a target and the first shot.
@export var reaction_time: float = 1.2
## Damage per hit.
@export var damage: int = 7
## Shots per second inside a burst.
@export var fire_rate: float = 2.0
## Shots per burst, then a pause.
@export var burst_size: int = 3
@export var burst_pause: float = 1.8
## Extra cone (radians) per metre of distance.
@export var spread_per_metre: float = 0.004
## Extra cone (radians) when the target runs (scaled by its speed / 5 m/s).
@export var moving_spread: float = 0.09
## How far it sees a target (line of sight needed).
@export var sight_range: float = 32.0

const MIN_SPREAD: float = 0.01
const MAX_SPREAD: float = 0.13


## The cone (radians) for a shot at `distance` metres at a target moving `speed` m/s.
func spread(distance: float, speed: float) -> float:
	return lerpf(MAX_SPREAD, MIN_SPREAD, accuracy) + distance * spread_per_metre \
			+ moving_spread * clampf(speed / 5.0, 0.0, 1.0)
