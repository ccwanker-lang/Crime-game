class_name ItemData
extends Resource
## Definition of one item type. Create new items as .tres files in data/items/.

@export var id: StringName = &""
@export var display_name: String = ""
@export var max_stack: int = 1
## Legal items can later be bought in the phone webshop; illegal only via NPCs.
@export var is_legal: bool = true
## Price in whole euros.
@export var base_price: int = 0
@export_multiline var description: String = ""
## Shops sell this many per "Buy" (ammo boxes); the price is per pack.
@export var pack_size: int = 1
## 3D model (held in the hand, dropped, icon). Empty = res://prefabs/items/<id>.tscn if it exists.
@export var model_scene: PackedScene

const ITEM_MODELS: String = "res://prefabs/items/"
const ICONS: String = "res://assets/icons/"


func get_model() -> PackedScene:
	if model_scene:
		return model_scene
	var path: String = ITEM_MODELS + String(id) + ".tscn"
	return load(path) as PackedScene if ResourceLoader.exists(path) else null


## Icon rendered from the model (scripts/debug/render_icons.gd), null if there is none yet.
func get_icon() -> Texture2D:
	var path: String = ICONS + String(id) + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
