"""Generates the ItemData .tres files for placeable things (point 6): every furniture prefab in
prefabs/interiors/ and the stations. Selecting one in the hotbar = placement mode.

    python tools/generators/gen_items.py .

Hand-made items (soil, seeds, weapons...) are not touched.
"""
import os
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
OUT = os.path.join(ROOT, "data", "items")

# id: (display name, price, max_stack, description)
FURNITURE = {
    "sofa": ("Sofa", 350, 2, "A worn three-seater."),
    "sofa_modern": ("Modern Sofa", 420, 2, "Grey fabric sofa."),
    "armchair": ("Armchair", 180, 2, "Comfortable armchair."),
    "rocking_chair": ("Rocking Chair", 130, 2, "Wooden rocking chair."),
    "coffee_table": ("Coffee Table", 90, 2, "Low wooden table."),
    "round_coffee_table": ("Round Coffee Table", 110, 2, "Round low table."),
    "side_table": ("Side Table", 45, 4, "Small side table."),
    "bookshelf": ("Bookshelf", 160, 2, "Tall wooden bookshelf."),
    "wall_shelf": ("Wall Shelf", 70, 4, "Open shelf rack."),
    "television": ("Television", 220, 2, "An old TV."),
    "low_cabinet": ("TV Cabinet", 140, 2, "Long low cabinet."),
    "drawer_cabinet": ("Drawer Cabinet", 180, 2, "Tall cabinet with drawers."),
    "wardrobe": ("Wardrobe", 280, 1, "Big vintage wardrobe."),
    "nightstand": ("Nightstand", 60, 4, "Bedside table."),
    "bed": ("Bed", 300, 1, "Single bed."),
    "dining_table": ("Dining Table", 260, 1, "Table for four."),
    "dining_chair": ("Dining Chair", 45, 8, "Wooden chair."),
    "office_desk": ("Office Desk", 200, 1, "Metal office desk."),
    "stool": ("Stool", 25, 8, "Metal stool."),
    "plastic_chair": ("Plastic Chair", 15, 8, "Monobloc garden chair."),
    "picnic_table": ("Picnic Table", 150, 1, "Wooden picnic table."),
    "painted_bench": ("Bench", 90, 2, "Painted wooden bench."),
    "barber_chair": ("Barber Chair", 400, 1, "Classic barber chair."),
    "steel_shelves": ("Steel Shelves", 90, 2, "Storage rack."),
    "metal_rack": ("Metal Rack", 70, 2, "Worn metal rack."),
    "tool_cart": ("Tool Cart", 150, 2, "Rolling tool cart."),
    "cash_register": ("Cash Register", 150, 2, "Old cash register."),
    "wheelchair": ("Wheelchair", 120, 1, "A wheelchair."),
    "cardboard_box": ("Cardboard Box", 5, 8, "Just a box."),
    "potted_plant": ("Potted Plant", 30, 4, "A bit of green."),
    "washing_machine": ("Washing Machine", 350, 2, "Front-loading washer."),
}

STATIONS = {
    "grow_pot": ("Grow Pot", 40, 10, "Place it in your property, add soil and a seed, water it."),
    "grow_lamp": ("Grow Lamp", 120, 4, "Plants under it grow faster. Place it next to your pots."),
    "drying_rack": ("Drying Rack", 80, 2, "Dries Fresh Weed into Dried Weed."),
    "packaging_table": ("Packaging Table", 100, 2, "Packs Dried Weed + Baggies into Bags of Weed."),
    "storage_locker": ("Storage Locker", 150, 2, "A lockable cabinet with room for 16 stacks. Shared with your crew."),
    "trash_bin": ("Trash Bin", 60, 2, "A wheelie bin for empty boxes and plant waste. Put it outside your property: the garbage truck empties it every morning."),
    # Milestone 3 (session B): meth.
    "cook_station": ("Cooking Station", 900, 1, "Cooks 2 Lab Chemicals + 1 Activator into Hot Trays. Stir it halfway for a full batch."),
    "cooling_plate": ("Cooling Plate", 400, 2, "Cools a Hot Tray; then break it into Meth Shards."),
}


def write(item_id, name, price, stack, desc, scene, category, legal=True):
    text = f"""[gd_resource type="Resource" script_class="ItemData" format=3]

[ext_resource type="Script" path="res://scripts/item_data.gd" id="1_item"]
[ext_resource type="PackedScene" path="{scene}" id="2_place"]

[resource]
script = ExtResource("1_item")
id = &"{item_id}"
display_name = "{name}"
max_stack = {stack}
is_legal = {"true" if legal else "false"}
base_price = {price}
description = "{desc}"
place_scene = ExtResource("2_place")
category = "{category}"
"""
    with open(os.path.join(OUT, item_id + ".tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


# Point 38: furniture that works as a station when placed (a bookshelf is storage).
FURNITURE_STATIONS = {"bookshelf": "bookshelf_storage"}
for i, (n, p, s, d) in FURNITURE.items():
    assert os.path.exists(os.path.join(ROOT, "prefabs", "interiors", i + ".tscn")), i
    scene = f"res://prefabs/stations/{FURNITURE_STATIONS[i]}.tscn" if i in FURNITURE_STATIONS else f"res://prefabs/interiors/{i}.tscn"
    write(i, n, p, s, d + (" Storage for 16 stacks." if i in FURNITURE_STATIONS else ""), scene, "furniture")
# Production stations are illegal (DESIGN core rules): only the black market sells them.
# The storage locker is just a cabinet, the trash bin a bin: legal (store + webshop).
for i, (n, p, s, d) in STATIONS.items():
    assert os.path.exists(os.path.join(ROOT, "prefabs", "stations", i + ".tscn")), i
    write(i, n, p, s, d, f"res://prefabs/stations/{i}.tscn", "station", legal=(i in ("storage_locker", "trash_bin")))
print(f"wrote {len(FURNITURE) + len(STATIONS)} items")
