# Generates tileable PBR textures for the procedural firearms (CC0, made for this project):
#   gun_metal_albedo.png / gun_metal_orm.png    parkerized steel with worn edges and scratches
#   gun_polymer_albedo.png / gun_polymer_orm.png  matte black polymer with a fine stipple
# ORM = R ambient occlusion, G roughness, B metallic (Godot ORMMaterial3D layout).
# Usage: python gen_gun_textures.py <output dir>
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
S = 512
random.seed(21)


def noise(scale, octaves=4, seed=0):
    """Tileable value noise (bilinear) summed over octaves, 0..1."""
    rnd = random.Random(seed)
    img = Image.new("L", (S, S), 128)
    acc = [[0.0] * S for _ in range(S)]
    amp, total = 1.0, 0.0
    for o in range(octaves):
        n = max(2, int(scale * (2 ** o)))
        grid = [[rnd.random() for _ in range(n)] for _ in range(n)]
        for y in range(S):
            gy = y / S * n
            y0 = int(gy) % n
            y1 = (y0 + 1) % n
            fy = gy - int(gy)
            fy = fy * fy * (3 - 2 * fy)
            row = acc[y]
            for x in range(S):
                gx = x / S * n
                x0 = int(gx) % n
                x1 = (x0 + 1) % n
                fx = gx - int(gx)
                fx = fx * fx * (3 - 2 * fx)
                a = grid[y0][x0] + (grid[y0][x1] - grid[y0][x0]) * fx
                b = grid[y1][x0] + (grid[y1][x1] - grid[y1][x0]) * fx
                row[x] += (a + (b - a) * fy) * amp
        total += amp
        amp *= 0.5
    for y in range(S):
        for x in range(S):
            img.putpixel((x, y), int(acc[y][x] / total * 255))
    return img


def scratches(count, length, seed):
    rnd = random.Random(seed)
    img = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(img)
    for _ in range(count):
        x, y = rnd.random() * S, rnd.random() * S
        ang = rnd.uniform(-0.5, 0.5) + (math.pi / 2 if rnd.random() < 0.3 else 0)
        ln = rnd.uniform(0.3, 1.0) * length
        for ox in (-S, 0, S):  # wrap around so it tiles
            for oy in (-S, 0, S):
                d.line([(x + ox, y + oy), (x + ox + math.cos(ang) * ln, y + oy + math.sin(ang) * ln)],
                       fill=rnd.randint(90, 255), width=1)
    return img


# --- Metal ---
n = noise(4, 5, 1)
wear = noise(6, 4, 2)
sc = scratches(260, 60, 3)
alb = Image.new("RGB", (S, S))
orm = Image.new("RGB", (S, S))
for y in range(S):
    for x in range(S):
        v = n.getpixel((x, y)) / 255.0
        w = wear.getpixel((x, y)) / 255.0
        s = sc.getpixel((x, y)) / 255.0
        worn = max(0.0, (w - 0.68) * 4.0)  # patches of bare steel
        worn = min(1.0, worn + s * 0.8)
        base = 0.075 + 0.04 * v
        r = base + worn * 0.3
        g = base + worn * 0.3
        b = base * 1.05 + worn * 0.31
        alb.putpixel((x, y), (int(r * 255), int(g * 255), int(b * 255)))
        rough = 0.62 - worn * 0.35 + (v - 0.5) * 0.1
        metal = 0.55 + worn * 0.4
        orm.putpixel((x, y), (255, int(max(0, min(1, rough)) * 255), int(min(1, metal) * 255)))
alb.save(os.path.join(OUT, "gun_metal_albedo.png"))
orm.save(os.path.join(OUT, "gun_metal_orm.png"))

# --- Polymer ---
n = noise(24, 3, 4)
alb = Image.new("RGB", (S, S))
orm = Image.new("RGB", (S, S))
for y in range(S):
    for x in range(S):
        v = n.getpixel((x, y)) / 255.0
        c = int((0.06 + 0.025 * v) * 255)
        alb.putpixel((x, y), (c, c, int(c * 1.03)))
        orm.putpixel((x, y), (255, int((0.7 + 0.15 * v) * 255), 0))
alb = alb.filter(ImageFilter.GaussianBlur(0.4))
alb.save(os.path.join(OUT, "gun_polymer_albedo.png"))
orm.save(os.path.join(OUT, "gun_polymer_orm.png"))
print("saved gun textures to", OUT)
