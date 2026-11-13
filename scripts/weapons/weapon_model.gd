class_name WeaponModel
extends Node3D
## Visual weapon (no logic): used as first-person viewmodel and in the hand of
## third-person characters. The origin is the middle of the grip, the barrel
## points to -Z, up is +Y. Markers: Muzzle, Ejection, RightHand / Support
## (first-person wrist targets), MagazineDir (its -Y = magazine slides out).
##
## The imported model keeps all parts as separate nodes; this script hides the
## spare variants and animates slide, hammer and magazine.

## Model parts by node name (in the imported glTF).
@export var part_slide: String = "service_pistol_slide_a"
@export var part_hammer: String = "service_pistol_hammer_a"
@export var part_magazine: String = "service_pistol_magazine_loaded"
@export var hidden_parts: PackedStringArray = []
## Slide travel in metres along slide_axis (the slide part's parent space).
@export var slide_travel: float = 0.028
## Direction towards the shooter in the slide part's parent space (glTF models
## lie along X; procedural guns are built along Z).
@export var slide_axis: Vector3 = Vector3(-1, 0, 0)
## Left hand on the weapon (weapon space): finger direction and palm normal.
## Pistol: wraps around the right fist. Long guns: palm up under the handguard.
@export var support_fingers: Vector3 = Vector3(0.45, 0.55, -0.7)
@export var support_palm: Vector3 = Vector3(1, 0.1, 0.2)
## Per shot: wait, move back, return (seconds). Pump / bolt actions are slow.
@export var cycle_delay: float = 0.0
@export var cycle_back: float = 0.025
@export var cycle_return: float = 0.06
## Local position of the magazine inside the grip (in model space).
@export var magazine_home: Vector3 = Vector3.ZERO

@onready var muzzle: Marker3D = $Muzzle
@onready var ejection: Marker3D = $Ejection
@onready var right_hand: Marker3D = $RightHand
@onready var support: Marker3D = $Support
@onready var magazine_dir: Marker3D = $MagazineDir

var _slide: Node3D
var _hammer: Node3D
var _magazine: Node3D
var _slide_home: Vector3
var _hammer_home: Basis
var _slide_tween: Tween
var _meshes: Array[MeshInstance3D] = []

## 0 = in the grip, 1 = fully out (metres along MagazineDir, see set_magazine).
var magazine_out: float = 0.0


func _ready() -> void:
	if ArtStyle.stylized:
		ArtStyle.restyle(self)  # point 27: imported models (sniper) get painted textures
	for n: Node in find_children("*", "", true, false):
		if n.name in hidden_parts:
			(n as Node3D).visible = false
	_slide = find_child(part_slide, true, false) as Node3D if part_slide != "" else null
	_hammer = find_child(part_hammer, true, false) as Node3D if part_hammer != "" else null
	_magazine = find_child(part_magazine, true, false) as Node3D if part_magazine != "" else null
	if _magazine:
		_magazine.position = magazine_home
	if _slide:
		_slide_home = _slide.position
	if _hammer:
		_hammer_home = _hammer.basis
	for mi: Node in find_children("*", "MeshInstance3D", true, false):
		_meshes.append(mi as MeshInstance3D)


## Slide blows back and returns (or stays back on the last round).
func cycle(last_round: bool = false) -> void:
	if _slide == null:
		return
	if _slide_tween:
		_slide_tween.kill()
	_slide_tween = create_tween()
	var back: Vector3 = _slide_home + slide_axis * slide_travel
	if cycle_delay > 0.0:
		_slide_tween.tween_interval(cycle_delay)
	_slide_tween.tween_property(_slide, "position", back, cycle_back)
	if not last_round:
		_slide_tween.tween_property(_slide, "position", _slide_home, cycle_return).set_ease(Tween.EASE_IN)
	if _hammer:
		_hammer.basis = _hammer_home.rotated(Vector3.FORWARD, 0.6)
		_slide_tween.parallel().tween_property(_hammer, "basis", _hammer_home, 0.08)


## 0 = slide forward, 1 = fully back (reload animation drives this).
func set_slide(amount: float) -> void:
	if _slide:
		if _slide_tween:
			_slide_tween.kill()
		_slide.position = _slide_home + slide_axis * slide_travel * amount


## Moves the magazine `distance` metres out of the grip; hidden when `visible_mag` is false.
func set_magazine(distance: float, visible_mag: bool = true) -> void:
	magazine_out = distance
	if _magazine == null:
		return
	_magazine.visible = visible_mag
	# MagazineDir lives in this node's space, the magazine in the model's space.
	var dir_world: Vector3 = -magazine_dir.global_basis.y
	var parent := _magazine.get_parent() as Node3D
	var dir_local: Vector3 = (parent.global_basis.inverse() * dir_world).normalized()
	_magazine.position = magazine_home + dir_local * distance


## First person: viewmodel shader (always in front of walls), no shadows.
func make_viewmodel() -> void:
	for m: MeshInstance3D in _meshes:
		Viewmodel.convert_meshes(m)


## Third person: no extra work, but the hand model never needs high detail far away.
func set_cast_shadows(on: bool) -> void:
	for m: MeshInstance3D in _meshes:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
