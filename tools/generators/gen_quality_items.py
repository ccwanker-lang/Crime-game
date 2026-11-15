"""Product quality (milestone 3, session B): writes the quality variants of the product items and the premium
supplies, with icons = the base item's icon + gold stars.

  python tools/generators/gen_quality_items.py

Tier 1 = the existing item (e.g. weed_bag). Tier 2 = <id>_q2 "Good", tier 3 = <id>_q3 "Premium" (same model as the
base item via model_scene, price x TIER_PRICE). Keep TIERED / TIER_* in sync with scripts/products/quality.gd.
"""
import math
import os
import re

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ITEMS = os.path.join(ROOT, "data", "items")
ICONS = os.path.join(ROOT, "assets", "icons")

TIERED = ["fresh_weed", "weed_bud", "weed_bag", "meth_tray", "meth_shard", "meth_bag", "cocaine", "coke_bag"]
TIER_NAMES = {2: "Good", 3: "Premium"}
TIER_PRICE = {2: 1.4, 3: 1.9}

# id -> (name, price, stack, description, model/icon base item)
SUPPLIES = {
    "premium_seed": ("Premium Weed Seed", 45, 20,
                     "A seed from a better strain. Plant it like a normal seed: the harvest is one quality step higher.",
                     "weed_seed"),
    "pure_reagent": ("Pure Reagent", 160, 10,
                     "Lab-grade additive. Carry it (or keep it in the locker for your cook) when a cook starts: +1 quality.",
                     "activator"),
    "pure_solvent": ("Pure Solvent", 220, 10,
                     "Clean solvent for the refinery. Carry it (or keep it in the locker) when a refinery run starts: +1 quality.",
                     "process_fluid"),
}


def read_item(item_id):
    with open(os.path.join(ITEMS, item_id + ".tres"), encoding="utf-8") as f:
        text = f.read()

    def field(name, default=""):
        m = re.search(r'^%s = (.*)$' % name, text, re.M)
        return m.group(1) if m else default

    return {
        "name": field("display_name").strip('"'),
        "stack": int(field("max_stack", "1")),
        "legal": field("is_legal", "true") == "true",
        "price": int(field("base_price", "0")),
        "desc": field("description").strip('"'),
    }


def write_item(item_id, name, price, stack, legal, desc, model_base):
    model = f"res://prefabs/items/{model_base}.tscn"
    lines = [
        '[gd_resource type="Resource" script_class="ItemData" format=3]',
        "",
        '[ext_resource type="Script" path="res://scripts/item_data.gd" id="1_item"]',
        f'[ext_resource type="PackedScene" path="{model}" id="2_model"]',
        "",
        "[resource]",
        'script = ExtResource("1_item")',
        f'id = &"{item_id}"',
        f'display_name = "{name}"',
        f"max_stack = {stack}",
        f"is_legal = {'true' if legal else 'false'}",
        f"base_price = {price}",
        f'description = "{desc}"',
        'model_scene = ExtResource("2_model")',
        "",
    ]
    with open(os.path.join(ITEMS, item_id + ".tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


def tier_name(base_name, tier):
    word = TIER_NAMES[tier]
    if base_name.startswith("Bag of "):
        return "Bag of %s %s" % (word, base_name[len("Bag of "):])
    return "%s %s" % (word, base_name)


def star(draw, cx, cy, r, fill, outline):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    draw.polygon(pts, fill=fill, outline=outline)


def write_icon(item_id, base_icon, stars):
    src = os.path.join(ICONS, base_icon + ".png")
    img = Image.open(src).convert("RGBA")
    w, h = img.size
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    r = w * 0.11
    for i in range(stars):
        cx = w - r * 1.25 - i * r * 2.0
        cy = r * 1.25
        star(d, cx, cy, r * 1.12, (40, 30, 10, 255), None)  # dark rim
        star(d, cx, cy, r, (255, 200, 40, 255), None)
    img = Image.alpha_composite(img, layer)
    img.save(os.path.join(ICONS, item_id + ".png"))


def main():
    n = 0
    for base in TIERED:
        b = read_item(base)
        for tier in (2, 3):
            item_id = f"{base}_q{tier}"
            desc = "%s Quality: %s (%d of 3)." % (b["desc"], TIER_NAMES[tier], tier)
            write_item(item_id, tier_name(b["name"], tier), round(b["price"] * TIER_PRICE[tier]), b["stack"],
                       b["legal"], desc, base)
            write_icon(item_id, base, tier - 1)
            n += 1
    for item_id, (name, price, stack, desc, base) in SUPPLIES.items():
        legal = read_item(base)["legal"]
        write_item(item_id, name, price, stack, legal, desc, base)
        write_icon(item_id, base, 1)
        n += 1
    print(f"wrote {n} items + icons")


if __name__ == "__main__":
    main()
