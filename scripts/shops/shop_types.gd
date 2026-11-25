class_name ShopTypes
extends RefCounted
## City life point 1 (session B, 2026-11-25): what each kind of shop sells and who stands behind the till.
## `type_for(building)` ("" = no idea, "-" = a business with its own trade: no counter staff) reads the type from (in this order) meta "shop_type" on the building or on its
## ShopkeeperSpot marker, the shop sign (Building.shop_sign) and the node name.
## Meals (item category "meal") are eaten on the spot: they heal (MEAL_HEAL) instead of going in your pockets.

const TYPES: Dictionary = {
	"bakery": {"shop": "Bakery", "names": ["Mrs. Vos", "Hanna", "Piet"], "greeting": "Fresh out of the oven!",
			"stock": [&"coffee", &"croissant", &"sandwich", &"apple_pie"], "variants": [3, 6]},
	"snack_bar": {"shop": "Snack Bar", "names": ["Ricky", "Fatima", "Joey"], "greeting": "What'll it be? Fries are hot.",
			"stock": [&"fries", &"burger", &"soda", &"coffee"], "variants": [1, 4]},
	"restaurant": {"shop": "Restaurant", "names": ["Marco", "Lucia", "Chef Dimitri"],
			"greeting": "Welcome! Table for one? Here's the menu.", "stock": [&"pasta", &"steak", &"soup", &"wine"],
			"variants": [2, 5]},
	"cafe": {"shop": "Cafe", "names": ["Noor", "Sven", "Bella"], "greeting": "Hi! Coffee, tea, something sweet?",
			"stock": [&"coffee", &"tea", &"cake", &"sandwich"], "variants": [3, 6]},
	"bar": {"shop": "Bar", "names": ["Big Tony", "Ines", "Kees"], "greeting": "Pull up a stool. What are you drinking?",
			"stock": [&"beer", &"cocktail", &"soda", &"fries"], "variants": [0, 4]},
	"florist": {"shop": "Florist", "names": ["Rosa", "Lily", "Mr. Bloom"], "greeting": "Flowers for someone special?",
			"stock": [&"rose_bouquet", &"tulips", &"sunflowers"], "variants": [3, 5]},
	"clothing": {"shop": "Clothing", "names": ["Chantal", "Dex", "Yara"],
			"greeting": "New look? Everything's on the rail. (You can wear it later.)",
			"stock": [&"cap", &"sunglasses", &"leather_jacket", &"hoodie", &"sneakers"], "variants": [5, 2]},
	"kiosk": {"shop": "Kiosk", "names": ["Ali", "Mo", "Greta"], "greeting": "Papers, snacks, drinks.",
			"stock": [&"soda", &"coffee", &"sandwich", &"croissant"], "variants": [1, 0]},
}

## Health from a meal (eaten at the counter).
const MEAL_HEAL: Dictionary = {
	&"coffee": 6, &"tea": 6, &"soda": 5, &"beer": 4, &"wine": 5, &"cocktail": 6, &"croissant": 12, &"sandwich": 18,
	&"apple_pie": 15, &"cake": 14, &"fries": 16, &"burger": 28, &"soup": 22, &"pasta": 35, &"steak": 45,
}

## Shop sign / node name words -> type (first match wins).
const WORDS: Array = [
	["barber", "-"], ["laundr", "-"], ["gun", "-"], ["estate", "-"], ["dealer", "-"], ["police", "-"],
	["florist", "florist"], ["flower", "florist"], ["bloem", "florist"],
	["bakery", "bakery"], ["bakker", "bakery"], ["bread", "bakery"],
	["snack", "snack_bar"], ["fries", "snack_bar"], ["frit", "snack_bar"], ["burger", "snack_bar"], ["kebab", "snack_bar"],
	["restaurant", "restaurant"], ["pizza", "restaurant"], ["diner", "restaurant"], ["bistro", "restaurant"],
	["trattoria", "restaurant"], ["grill", "restaurant"], ["sushi", "restaurant"], ["steak", "restaurant"],
	["cafe", "cafe"], ["café", "cafe"], ["coffee", "cafe"], ["espresso", "cafe"], ["tea", "cafe"],
	["pub", "bar"], ["bar", "bar"], ["tavern", "bar"], ["lounge", "bar"],
	["fashion", "clothing"], ["boutique", "clothing"], ["cloth", "clothing"], ["wear", "clothing"], ["shoe", "clothing"],
	["kiosk", "kiosk"], ["news", "kiosk"], ["mini", "kiosk"], ["market", "kiosk"],
]


static func type_for(building: Node, marker: Node = null) -> String:
	for n: Node in [marker, building]:
		if n and n.has_meta(&"shop_type"):
			return str(n.get_meta(&"shop_type"))
	var sign: String = str(building.get(&"shop_sign")) if building.get(&"shop_sign") != null else ""
	for text: String in [sign.to_lower(), str(building.name).to_lower()]:
		if text == "" or text == "<null>":
			continue
		for w: Array in WORDS:
			if (w[0] as String) in text:
				return w[1]  # ("-" = a shop with its own trade: no counter staff)
	return ""


static func info(type: String) -> Dictionary:
	return TYPES.get(type, {})


static func is_meal(id: StringName) -> bool:
	return MEAL_HEAL.has(id)
