# Generates a leaf-cluster atlas (RGBA) for alpha-scissor foliage cards.
# Usage: python gen_leaves.py <output.png>
import math, random, sys
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT = sys.argv[1]
random.seed(7)

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

def leaf(draw_img, cx, cy, length, width, angle, color):
    # Pointed leaf polygon (two arcs) rotated by angle.
    pts = []
    steps = 14
    for i in range(steps + 1):
        t = i / steps
        x = (t - 0.5) * length
        y = math.sin(t * math.pi) ** 0.8 * width * 0.5
        pts.append((x, y))
    for i in range(steps, -1, -1):
        t = i / steps
        x = (t - 0.5) * length
        y = -math.sin(t * math.pi) ** 0.8 * width * 0.5
        pts.append((x, y))
    ca, sa = math.cos(angle), math.sin(angle)
    poly = [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]
    d = ImageDraw.Draw(draw_img)
    d.polygon(poly, fill=color)
    # Midrib (slightly lighter)
    r, g, b, a = color
    vein = (min(255, r + 25), min(255, g + 30), min(255, b + 15), 255)
    x0, y0 = cx - 0.45 * length * ca, cy - 0.45 * length * sa
    x1, y1 = cx + 0.45 * length * ca, cy + 0.45 * length * sa
    d.line([(x0, y0), (x1, y1)], fill=vein, width=2)

# Leaves inside a soft round cluster; darker in the middle, lighter at the rim.
count = 420
center = SIZE / 2
for i in range(count):
    rr = (random.random() ** 0.6) * SIZE * 0.44
    ang = random.random() * math.tau
    cx = center + math.cos(ang) * rr
    cy = center + math.sin(ang) * rr
    rim = rr / (SIZE * 0.44)
    base = random.choice([(58, 92, 34), (70, 105, 40), (48, 80, 30), (85, 118, 46), (62, 98, 38)])
    shade = 0.65 + 0.45 * rim + random.uniform(-0.08, 0.08)
    col = tuple(int(max(0, min(255, c * shade))) for c in base) + (255,)
    # Leaves point roughly outward from the cluster centre.
    leaf_angle = ang + random.uniform(-0.9, 0.9)
    length = random.uniform(48, 80)
    leaf(img, cx, cy, length, length * random.uniform(0.38, 0.5), leaf_angle, col)

# A few twigs.
d = ImageDraw.Draw(img)
for i in range(10):
    ang = random.random() * math.tau
    r1 = SIZE * 0.4
    d.line([(center, center), (center + math.cos(ang) * r1, center + math.sin(ang) * r1)], fill=(70, 55, 40, 255), width=5)

# Slight blur on colour only to avoid aliasing; keep alpha crisp for scissor.
rgb = img.convert("RGB").filter(ImageFilter.GaussianBlur(0.6))
alpha = img.split()[3]
# Bleed colour into transparent pixels to avoid dark fringes in mipmaps.
bleed = rgb.filter(ImageFilter.MaxFilter(9))
mask = alpha.point(lambda a: 255 if a > 0 else 0)
rgb = Image.composite(rgb, bleed, mask)
out = rgb.copy()
out.putalpha(alpha)
out.save(OUT)
print("saved", OUT)
