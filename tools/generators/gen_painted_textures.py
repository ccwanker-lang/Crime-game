# Point 27 art direction: "painted" versions of the colour textures of imported models
# (Poly Haven), so they fit the flat stylized look without remodelling them:
# downscaled, softened, colours pulled towards the game palette and posterized.
# Only the colour (diff/albedo/basecolor) maps; normal/roughness maps are dropped at run time
# (ArtStyle.paint_material). Output: assets/painted/<same sub path>_painted.png
# Usage: python gen_painted_textures.py <project root>
import os, sys
from PIL import Image, ImageFilter, ImageEnhance

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_palette import SWATCHES  # noqa: E402

ROOT = sys.argv[1]
SRC = os.path.join(ROOT, "assets", "polyhaven")
DST = os.path.join(ROOT, "assets", "painted")
SIZE = 128
PULL = 0.35     # how far each colour moves towards the nearest palette colour
LEVELS = 12     # colours per texture after posterizing
PAL = [tuple(round(v * 255) for v in c) for _, c in SWATCHES]


def nearest(c):
    return min(PAL, key=lambda p: (p[0] - c[0]) ** 2 * 0.3 + (p[1] - c[1]) ** 2 * 0.59 + (p[2] - c[2]) ** 2 * 0.11)


def is_colour_map(name):
    n = name.lower()
    return any(k in n for k in ("_diff", "albedo", "basecolor", "base_color", "_col")) and n.endswith((".jpg", ".png"))


count = 0
for dirpath, _, files in os.walk(SRC):
    for f in files:
        if not is_colour_map(f):
            continue
        src = os.path.join(dirpath, f)
        rel = os.path.relpath(src, SRC)
        out = os.path.join(DST, os.path.splitext(rel)[0] + "_painted.png")
        if os.path.exists(out) and os.path.getmtime(out) > os.path.getmtime(src) and "--force" not in sys.argv:
            continue
        img = Image.open(src)
        has_alpha = img.mode in ("RGBA", "LA") or "transparency" in img.info
        img = img.convert("RGBA")
        alpha = img.getchannel("A").resize((SIZE * 2, SIZE * 2), Image.BOX)
        rgb = img.convert("RGB").resize((SIZE, SIZE), Image.BOX).filter(ImageFilter.GaussianBlur(1.6))
        rgb = ImageEnhance.Color(rgb).enhance(1.25)
        q = rgb.quantize(colors=LEVELS, method=Image.Quantize.MEDIANCUT)
        pal = q.getpalette()[: LEVELS * 3]
        new = []
        for i in range(LEVELS):
            c = tuple(pal[i * 3: i * 3 + 3])
            n = nearest(c)
            new += [round(c[k] + (n[k] - c[k]) * PULL) for k in range(3)]
        q.putpalette(new + [0] * (768 - len(new)))
        rgb = q.convert("RGB").resize((SIZE * 2, SIZE * 2), Image.NEAREST).filter(ImageFilter.SMOOTH)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        if has_alpha:
            rgb = rgb.convert("RGBA")
            rgb.putalpha(alpha)
        rgb.save(out)
        count += 1
open(os.path.join(DST, "LICENSE.txt"), "w").write(
    "Derived from Poly Haven assets (CC0) by tools/generators/gen_painted_textures.py.\n")
print("painted %d textures" % count)
