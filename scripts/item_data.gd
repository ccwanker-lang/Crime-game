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
