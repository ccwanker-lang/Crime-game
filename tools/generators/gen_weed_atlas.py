# Generates the weed plant atlas (RGBA, alpha-scissor cards) used by WeedPlant.
# 2x2 cells of 512 px:
#   (0,0) fan leaf, 7 serrated leaflets   (1,0) small leaf, 5 leaflets
#   (0,1) bud / cola (dense, with orange pistils and frost)   (1,1) dried bud (darker, browner)
# In every leaf cell the petiole starts at the bottom centre (the card attaches to the stem there).
# Usage: python gen_weed_atlas.py <output.png>
import math, random, sys
from PIL import Image, ImageDraw, ImageFilter

CELL = 512
SIZE = CELL * 2
OUT = sys.argv[1]
random.seed(11)
img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)


def leaflet(ox, oy, length, width, angle, color, teeth=13):
    """Narrow lanceolate leaflet with a serrated edge, base at (ox, oy), pointing along angle."""
    steps = teeth * 2
    left, right = [], []
    for i in range(steps + 1):
        t = i / steps
        w = math.sin(min(1.0, t * 1.15) * math.pi) ** 0.9 * width * 0.5
        w *= 1.0 - 0.15 * t
        tooth = 0.0 if i % 2 == 0 else width * 0.09 * math.sin(t * math.pi)
        left.append((t * length, w + tooth))
        right.append((t * length, -(w + tooth)))
    pts = left + right[::-1]
    ca, sa = math.cos(angle), math.sin(angle)
    poly = [(ox + x * ca - y * sa, oy + x * sa + y * ca) for x, y in pts]
    draw.polygon(poly, fill=color)
    r, g, b, _ = color
    vein = (min(255, r + 30), min(255, g + 35), min(255, b + 20), 255)
    draw.line([(ox, oy), (ox + length * 0.92 * ca, oy + length * 0.92 * sa)], fill=vein, width=3)


def fan(cx, cy, count, scale, base_color):
    """Palmate leaf: petiole from the bottom centre of the cell up to the hub, leaflets fan out."""
    bottom = (cx, cy + CELL / 2 - 4)
    hub = (cx, cy + CELL * 0.18)
    draw.line([bottom, hub], fill=(88, 112, 52, 255), width=7)
    spread = math.radians(200 if count >= 7 else 170)
    for i in range(count):
        k = i / (count - 1) - 0.5  # -0.5 .. 0.5
        ang = -math.pi / 2 + k * spread
        length = CELL * scale * (1.0 - 0.75 * abs(k) ** 1.4)
        shade = 1.0 + random.uniform(-0.07, 0.07)
        col = tuple(int(max(0, min(255, c * shade))) for c in base_color) + (255,)
        leaflet(hub[0], hub[1], length, length * 0.2, ang, col)


fan(CELL * 0.5, CELL * 0.5, 7, 0.62, (52, 104, 38))
fan(CELL * 1.5, CELL * 0.5, 5, 0.5, (66, 118, 44))


def bud(cx, cy, dried):
    """Elongated dense cola: overlapping calyx blobs, pistil hairs and frosty dots."""
    h, w = CELL * 0.86, CELL * 0.42
    top = cy - h / 2
    for i in range(520):
        t = random.random()  # 0 top .. 1 bottom
        width = w * (0.35 + 0.65 * math.sin(min(1.0, t * 1.3) * math.pi * 0.5)) * (1.0 - 0.25 * t)
        x = cx + random.uniform(-0.5, 0.5) * width
        y = top + t * h
        r = random.uniform(10, 22) * (0.7 + 0.5 * (1 - t))
        g = random.uniform(0.75, 1.1)
        if dried:
            base = (92, 98, 50)
        else:
            base = (96, 140, 58)
        col = tuple(int(max(0, min(255, c * g))) for c in base) + (255,)
        draw.ellipse([x - r, y - r * 1.2, x + r, y + r * 1.2], fill=col)
    for i in range(170):  # pistils
        t = random.random()
        x = cx + random.uniform(-0.45, 0.45) * w * (1 - 0.3 * t)
        y = top + t * h
        ang = random.uniform(0, math.tau)
        ln = random.uniform(8, 18)
        col = (196, 110, 44, 255) if not dried else (150, 84, 40, 255)
        draw.line([(x, y), (x + math.cos(ang) * ln, y + math.sin(ang) * ln)], fill=col, width=2)
    for i in range(600):  # trichome frost
        t = random.random()
        x = cx + random.uniform(-0.45, 0.45) * w * (1 - 0.3 * t)
        y = top + t * h
        v = random.randint(200, 245)
        draw.point((x, y), fill=(v, v, v - 10, 255))
    # Small sugar leaves sticking out.
    for i in range(14):
        t = random.uniform(0.1, 0.95)
        side = random.choice([-1, 1])
        x = cx + side * w * 0.3
        y = top + t * h
        ang = (-math.pi / 2) + side * random.uniform(0.6, 1.2)
        base = (60, 104, 40) if not dried else (78, 82, 42)
        leaflet(x, y, random.uniform(40, 70), 12, ang, base + (255,), teeth=6)


bud(CELL * 0.5, CELL * 1.5, False)
bud(CELL * 1.5, CELL * 1.5, True)

rgb = img.convert("RGB").filter(ImageFilter.GaussianBlur(0.5))
alpha = img.split()[3]
bleed = rgb.filter(ImageFilter.MaxFilter(9))
mask = alpha.point(lambda a: 255 if a > 0 else 0)
rgb = Image.composite(rgb, bleed, mask)
out = rgb.copy()
out.putalpha(alpha)
out.save(OUT)
print("saved", OUT)
