extends Node
## Registry of all items. Loads every ItemData resource in data/items/ at startup.
## Usage: ItemDB.get_item(&"weed_seed").base_price

const ITEMS_DIR: String = "res://data/items/"

## StringName id -> ItemData
var _items: Dictionary = {}


func _ready() -> void:
	_load_all()


func get_item(id: StringName) -> ItemData:
	return _items.get(id) as ItemData


func has_item(id: StringName) -> bool:
	return _items.has(id)


func get_all_ids() -> Array:
	return _items.keys()


func _load_all() -> void:
	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		push_error("[ItemDB] Missing folder %s" % ITEMS_DIR)
		return
	for file_name: String in dir.get_files():
		# Exported builds rename resources to *.remap; load() handles the original path.
		var res_name: String = file_name.trim_suffix(".remap")
		if not res_name.ends_with(".tres"):
			continue
		var item := load(ITEMS_DIR + res_name) as ItemData
		if item == null:
			push_warning("[ItemDB] %s is not an ItemData" % res_name)
			continue
		if _items.has(item.id):
			push_warning("[ItemDB] Duplicate item id '%s' in %s" % [item.id, res_name])
			continue
		_items[item.id] = item
	print("[ItemDB] Loaded %d items" % _items.size())
