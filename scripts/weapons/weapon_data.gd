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
## Pistol only: rounds of ammo_id a player gets on (re)spawn.
@export var starting_reserve: int = 32
## Ammunition item (data/items/) this weapon loads; the spare rounds are
## inventory items, so they are bought, carried and lost on death.
@export var ammo_id: StringName = &""

@export var reload_time: float = 1.6
@export var max_range: float = 150.0
## Spread in radians (standing still / moving / in the air); crouching x0.6.
@export var spread_still: float = 0.004
@export var spread_moving: float = 0.03
@export var spread_air: float = 0.08
## Camera kick per shot in radians (pitch up, random yaw).
@export var recoil_pitch: float = 0.022
@export var recoil_yaw: float = 0.008
## Number key that selects this weapon (1 = pistol ... 5 = sniper).
@export var slot: int = 1
## Keeps firing while the button is held.
@export var automatic: bool = false
## Shotgun: projectiles per shot (each does `damage`), spread around the aim.
@export var pellets: int = 1
@export var pellet_spread: float = 0.0
## Right mouse button: field of view while aiming (scope_fov < 20 = sniper scope
## overlay, the viewmodel hides) and the spread while aiming.
@export var aim_fov: float = 55.0
@export var aim_spread: float = -1.0
## First person: grip position offset from Viewmodel.GUN_POS (long guns sit lower/closer).
@export var vm_offset: Vector3 = Vector3.ZERO
## First person: shoulders moved forward and the arms made longer (long guns: the
## left hand must reach the handguard; the hands keep their size).
@export var vm_shoulder_shift: Vector3 = Vector3.ZERO
@export var vm_arm_scale: float = 1.0
## First person: yaw of the weapon towards the screen centre (radians, < 0 = Viewmodel.GUN_YAW).
@export var vm_yaw: float = -1.0
## Shot / reload sounds: pitch and volume (long guns reuse the pistol samples deeper and louder).
@export var sound_pitch: float = 1.0
@export var sound_volume_db: float = 0.0
## model_scene (ItemData): the WeaponModel (holds Muzzle / Ejection / Support markers).
@export var shot_sounds: Array[AudioStream] = []
@export var shot_far_sounds: Array[AudioStream] = []
@export var reload_sound: AudioStream
@export var dry_fire_sound: AudioStream
