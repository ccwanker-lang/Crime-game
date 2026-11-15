"""Map blueprint zone 9: the snowy border mountains round the whole map.

One coarse heightmap (2 m cells) over the whole map. Inside the playable land (village, city, the mountain-pass zone
with the prison + army base, the sea) it lies 3 m under the ground and is not drawn; outside it rises: a short
walkable grass foot, then too steep to climb (> 50 deg), up to rocky peaks with snow. Pines on the lower slopes.

Writes data/border/border.json (grid, pines) + data/border/height.bin (float32, rows = z from Z0, columns = x from
X0). Built at runtime by BorderRange (scripts/procgen/border_range.gd).

Run: python tools/generators/gen_border.py .
"""
import json
import math
import os
import random
import sys

import numpy as np
from scipy.ndimage import distance_transform_edt, gaussian_filter

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
OUT = os.path.join(ROOT, "data", "border")

CELL = 2.0
X0, X1 = -480.0, 300.0
Z0, Z1 = -620.0, 560.0
SNOW_LINE = 48.0

# The playable land + the sea (x0, z0, x1, z1). Keep in step with gen_world.py (BORDER_LAND).
LAND = [
    (-201.0, -141.0, 83.0, 105.0),    # village: docks, farm, centre, slums (= the Ground slab)
    (-72.0, 100.0, 140.0, 400.0),     # the city + the highway strip
    (83.0, -141.0, 140.0, 105.0),     # the highway strip east of the village
    (-262.0, -445.0, -30.0, -139.0),  # the mountain pass zone (Mountain heightmap): prison, army base, bunker
    (-30.0, -445.0, 240.0, -346.0),   # point 85: the airfield east of the army base (= gen_world GroundAirfield)
    (-340.0, 100.0, -60.0, 440.0),    # the sea (the mountains rise out of the water at its far side)
]
SEA = (-340.0, 104.0, -72.5, 440.0)

xs = np.arange(X0, X1 + 0.001, CELL)
zs = np.arange(Z0, Z1 + 0.001, CELL)
X, Z = np.meshgrid(xs, zs)
inside = np.zeros(X.shape, dtype=bool)
for x0, z0, x1, z1 in LAND:
    inside |= (X >= x0) & (X <= x1) & (Z >= z0) & (Z <= z1)
d = distance_transform_edt(~inside) * CELL          # metres outside the land (0 inside)
d_in = distance_transform_edt(inside) * CELL        # metres inside the land

rng = np.random.default_rng(909)
noise = np.zeros_like(X)
for k in range(7):
    f = 0.006 * (1.7 ** k)
    a = rng.uniform(0, math.tau)
    ph = rng.uniform(0, math.tau, 2)
    u = X * math.cos(a) + Z * math.sin(a)
    v = -X * math.sin(a) + Z * math.cos(a)
    noise += np.sin(u * f + ph[0]) * np.cos(v * f * 1.3 + ph[1]) / (1.6 ** k)
noise = gaussian_filter(noise, 1.0)


def smooth01(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3 - 2 * t)


# Height profile by distance from the land:
#   0..6 m   grass foot from -0.05 to ~1.5 m (walkable)
#   6..40 m  steep wall up to ~45 m (not walkable, not drivable)
#   40 m +   high ground, peaks 70-110 m
foot = 1.5 * smooth01(d / 6.0)
wall = 44.0 * np.clip((d - 6.0) / 34.0, 0, 1) ** 1.15
high = (25.0 + 22.0 * noise) * smooth01((d - 40.0) / 60.0) + 14.0 * np.clip(noise, 0, None) * smooth01((d - 20.0) / 30.0)
sink = np.clip(d_in - 2 * CELL, 0.0, 3.0)  # the land's edge cells sit at ground height, deeper inside it drops
height = np.where(d > 0, -0.05 + foot + wall + np.maximum(high, -10.0), -0.05 - sink)
height += np.where(d > 8, noise * 3.0 * smooth01((d - 8.0) / 20.0), 0.0)
# The sea: deep under the water, mountains straight out of it.
in_sea = (X >= SEA[0]) & (X <= SEA[2]) & (Z >= SEA[1]) & (Z <= SEA[3])
height = np.where(in_sea, -6.0, height)
# The pass mountain (data/mountain, from gen_mountain.py) runs on into the range: outside the land, every cell is at
# least the mountain heightmap's nearest edge value (its ridge extruded outwards), so the two meet without a step.
M_DIR = os.path.join(ROOT, "data", "mountain")
with open(os.path.join(M_DIR, "mountain.json")) as _f:
    _mg = json.load(_f)["grid"]
mh = np.fromfile(os.path.join(M_DIR, "height.bin"), dtype=np.float32).reshape(_mg["nz"], _mg["nx"])
mix = np.clip(np.round((X - _mg["x0"]) / _mg["cell"]).astype(int), 0, _mg["nx"] - 1)
miz = np.clip(np.round((Z - _mg["z0"]) / _mg["cell"]).astype(int), 0, _mg["nz"] - 1)
ext = mh[miz, mix] + noise * 3.0 * smooth01(d / 30.0)
height = np.where(d > 0, np.maximum(height, ext), height)
height = gaussian_filter(height, 1.2)  # (also softens the crease where the pass mountain's edge is extruded)
# ...but right at the pass mountain's edge it must match that heightmap exactly (no step at the seam), blending
# back to the smoothed range over 10 m.
mdx = np.maximum(np.maximum(_mg["x0"] - X, X - (_mg["x0"] + (_mg["nx"] - 1) * _mg["cell"])), 0)
mdz = np.maximum(np.maximum(_mg["z0"] - Z, Z - (_mg["z0"] + (_mg["nz"] - 1) * _mg["cell"])), 0)
mdist = np.hypot(mdx, mdz)
seam = (d > 0) & (mdist < 10.0)
wseam = 1.0 - smooth01(mdist / 10.0)
height = np.where(seam, height * (1 - wseam) + mh[miz, mix] * wseam, height)
height = np.where(inside, np.minimum(height, -0.05 - sink), height)
# Point 81: just inside the pass mountain's edge the range runs on 0.5 m UNDER the mountain heightmap. The range's
# 4 m render quads straddle the edge (x -30 is not on its grid); without this they dipped to -3 m right there and
# left a slit you could see down into along the whole seam.
m_in = np.minimum(np.minimum(X - _mg["x0"], _mg["x0"] + (_mg["nx"] - 1) * _mg["cell"] - X),
                  np.minimum(Z - _mg["z0"], _mg["z0"] + (_mg["nz"] - 1) * _mg["cell"] - Z))
under = (m_in >= 0) & (m_in < 8.0) & (mh[miz, mix] > 0.6)
height = np.where(under, mh[miz, mix] - 0.5, height)
edge = (~inside) & (d <= CELL * 1.01)
height = np.where(edge, np.maximum(height, -0.05), height)

# ------------------------------------------------------------------ pines on the lower slopes
def h_at(x, z):
    ix = int(round((x - X0) / CELL))
    iz = int(round((z - Z0) / CELL))
    if 0 <= ix < len(xs) and 0 <= iz < len(zs):
        return float(height[iz, ix])
    return -10.0


def d_at(x, z):
    ix = int(round((x - X0) / CELL))
    iz = int(round((z - Z0) / CELL))
    if 0 <= ix < len(xs) and 0 <= iz < len(zs):
        return float(d[iz, ix])
    return 0.0


prng = random.Random(9090)
pines = []
for _ in range(60000):
    if len(pines) >= 1400:
        break
    x, z = prng.uniform(X0 + 4, X1 - 4), prng.uniform(Z0 + 4, Z1 - 4)
    dd = d_at(x, z)
    if dd < 3.0 or dd > 120.0:
        continue
    y = h_at(x, z)
    if y < 0.5 or y > SNOW_LINE + 15:
        continue
    gx = (h_at(x + 2, z) - h_at(x - 2, z)) / 4.0
    gz = (h_at(x, z + 2) - h_at(x, z - 2)) / 4.0
    if math.degrees(math.atan(math.hypot(gx, gz))) > 55:
        continue
    pines.append([round(x, 1), round(y - 0.2, 2), round(z, 1), round(prng.uniform(0.9, 1.6), 2), 1 if y > SNOW_LINE - 6 else 0])

os.makedirs(OUT, exist_ok=True)
height.astype(np.float32).tofile(os.path.join(OUT, "height.bin"))
data = {
    "grid": {"x0": X0, "z0": Z0, "nx": len(xs), "nz": len(zs), "cell": CELL},
    "snow_line": SNOW_LINE,
    "land": [list(r) for r in LAND],
    "pines": pines,
}
with open(os.path.join(OUT, "border.json"), "w") as f:
    json.dump(data, f, separators=(",", ":"))
print(f"border heightmap {len(xs)} x {len(zs)} ({CELL:g} m), max {height.max():.1f} m, {len(pines)} pines")
