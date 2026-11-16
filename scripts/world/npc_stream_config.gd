class_name NpcStreamConfig
extends Resource
## Point 87: NPC streaming / level-of-detail settings (data/npc/streaming.tres).

## NPCs closer than this to a player wake up (and may be counted as active).
@export var spawn_radius: float = 250.0
## NPCs further than this from every player go to sleep (hysteresis between the two: no flicker).
@export var despawn_radius: float = 300.0
## Within this distance an active NPC runs at full detail; beyond it at MID (AI every 3rd tick, slow animation).
@export var full_radius: float = 45.0
## At most this many awake NPCs at once (the nearest + the ones with a deal / mission first). Point 89 (npc_bench).
@export var max_active_npcs: int = 60
## A sleeping NPC never wakes up in a player's view closer than this (no popping in front of you).
@export var no_pop_radius: float = 60.0
## Seconds between two passes of the streamer.
@export var interval: float = 0.25
## MID NPCs further than this are not animated at all (their meshes stop drawing at 90 m, Pedestrian).
@export var anim_radius: float = 95.0
## Traffic cars further than this from every player think every 3rd tick and sense the lane less often.
@export var far_car_radius: float = 120.0
## Animation rate of MID NPCs (updates per second).
@export var mid_anim_hz: float = 10.0
