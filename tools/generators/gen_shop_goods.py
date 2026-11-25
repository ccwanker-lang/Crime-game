"""City life point 1 (session B): items sold by the shop sellers (ShopTypes) -> data/items/<id>.tres and a model
prefabs/items/<id>.tscn (procedural ProcGoods, scripts/shops/proc_goods.gd). Run: python tools/generators/gen_shop_goods.py .
Then render the icons (window): --script res://scripts/debug/render_icons.gd -- --only=<ids>"""
import os, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
# id, name, price, stack, category, description
GOODS = [
    ("coffee", "Coffee", 3, 1, "meal", "Hot and black. Drunk at the counter (+6 health)."),
    ("tea", "Tea", 3, 1, "meal", "A pot of tea (+6 health)."),
    ("soda", "Soda", 2, 1, "meal", "Ice cold can (+5 health)."),
    ("beer", "Beer", 5, 1, "meal", "A cold one at the bar (+4 health)."),
    ("wine", "Glass of Wine", 7, 1, "meal", "House red (+5 health)."),
    ("cocktail", "Cocktail", 11, 1, "meal", "Something with an umbrella in it (+6 health)."),
    ("croissant", "Croissant", 3, 1, "meal", "Buttery, still warm (+12 health)."),
    ("sandwich", "Sandwich", 6, 1, "meal", "Cheese and ham (+18 health)."),
    ("apple_pie", "Apple Pie", 5, 1, "meal", "A slice with cream (+15 health)."),
    ("cake", "Cake", 5, 1, "meal", "Chocolate cake (+14 health)."),
    ("fries", "Fries", 4, 1, "meal", "With mayo (+16 health)."),
    ("burger", "Burger", 9, 1, "meal", "Double patty (+28 health)."),
    ("soup", "Soup", 7, 1, "meal", "Soup of the day (+22 health)."),
    ("pasta", "Pasta", 14, 1, "meal", "Spaghetti, the chef's way (+35 health)."),
    ("steak", "Steak", 26, 1, "meal", "Medium rare with fries (+45 health)."),
    ("rose_bouquet", "Red Roses", 25, 5, "gift", "A dozen red roses."),
    ("tulips", "Tulips", 12, 5, "gift", "A bunch of tulips."),
    ("sunflowers", "Sunflowers", 15, 5, "gift", "Big and yellow."),
    ("cap", "Cap", 25, 1, "clothing", "A plain cap. Clothes go on your character in a later update."),
    ("sunglasses", "Sunglasses", 40, 1, "clothing", "Dark glasses. Clothes go on your character in a later update."),
    ("leather_jacket", "Leather Jacket", 180, 1, "clothing", "Black leather. Clothes go on your character in a later update."),
    ("hoodie", "Hoodie", 55, 1, "clothing", "Grey hoodie. Clothes go on your character in a later update."),
    ("sneakers", "Sneakers", 90, 1, "clothing", "White sneakers. Clothes go on your character in a later update."),
]

for gid, name, price, stack, cat, desc in GOODS:
    with open(os.path.join(ROOT, "data/items", gid + ".tres"), "w", newline="\n") as f:
        f.write(f'''[gd_resource type="Resource" script_class="ItemData" format=3]

[ext_resource type="Script" path="res://scripts/item_data.gd" id="1_item"]

[resource]
script = ExtResource("1_item")
id = &"{gid}"
display_name = "{name}"
max_stack = {stack}
is_legal = true
base_price = {price}
description = "{desc}"
category = "{cat}"
''')
    with open(os.path.join(ROOT, "prefabs/items", gid + ".tscn"), "w", newline="\n") as f:
        f.write(f'''[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/shops/proc_goods.gd" id="1_g"]

[node name="{name.replace(' ', '')}" type="Node3D"]
script = ExtResource("1_g")
kind = "{gid}"
''')
print(f"{len(GOODS)} goods")
