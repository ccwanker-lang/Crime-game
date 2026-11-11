class_name WeaponData
extends ItemData
## A firearm. Lives in data/items/ like every item (ItemDB loads it), with the
## combat numbers the host uses to validate shots and apply damage.

## Damage of one body hit; the host multiplies it for headshots.
@export var damage: int = 26
@export var headshot_multiplier: float = 4.0
## Seconds between shots (semi-automatic: one shot per click).
@export var fire_interval: float = 0.16
@export var magazine_size: int = 8
## Spare rounds a player starts with (ammo items come later).
@export var starting_reserve: int = 32
@export var reload_time: float = 1.6
@export var max_range: float = 150.0
## Spread in radians (standing still / moving / in the air); crouching x0.6.
@export var spread_still: float = 0.004
@export var spread_moving: float = 0.03
@export var spread_air: float = 0.08
## Camera kick per shot in radians (pitch up, random yaw).
@export var recoil_pitch: float = 0.022
@export var recoil_yaw: float = 0.008
## Visual model (holds Muzzle / Ejection / Support markers, see WeaponModel).
@export var model_scene: PackedScene
@export var shot_sounds: Array[AudioStream] = []
@export var shot_far_sounds: Array[AudioStream] = []
@export var reload_sound: AudioStream
@export var dry_fire_sound: AudioStream
