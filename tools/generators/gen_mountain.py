"""Point 49b: the mountain pass between Hollow Farm and the prison.

Writes data/mountain/mountain.json (road centre line with heights, guardrails, pines, rocks, traffic route 5, the
bus path) and data/mountain/height.bin (float32 heightmap, 1 m cells, row-major: z rows from GRID_Z0, x columns
from GRID_X0). The Mountain node (scripts/procgen/mountain.gd) builds terrain, road and props from them; Traffic
loads route 5, Intro the bus path.

Run: python tools/generators/gen_mountain.py .
"""
import json
import math
import os
import random
import sys

import numpy as np

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
OUT = os.path.join(ROOT, "data", "mountain")

# Heightmap area (world metres). South edge = the village's north border.
GRID_X0, GRID_X1 = -262.0, -30.0
GRID_Z0, GRID_Z1 = -445.0, -140.0
CELL = 1.0
LANE = 1.75
ROAD_HALF = 3.5
RIBBON_START_Z = -77.6      # the end of Country Lane's last tile (z -78) - a little overlap
CLIMB_FROM_Z = -141.0       # flat (on the village ground) until here
SUMMIT_Z = (-246.0, -262.0)  # flat summit between these z (on the north leg over the saddle)
DESCEND_TO_Z = -333.0       # back at ground height here (the prison yard starts at z -339)
PRISON = (-150.0, -385.0)

# The centre line: corners (x, z) with fillet radii, in driving order from Main Road's west end (route 5's
# U-turn) up Country Lane, across the farmyard, up the hairpins, over the saddle, down to the prison stub.
CORNERS = [
    ((-174.0, 0.0), 0.0),       # start (route U-turn end)
    ((-150.0, 0.0), 6.75),      # Country Lane junction: left, north
    ((-150.0, -83.0), 5.0),     # farmyard: right, east
    ((-124.0, -83.0), 8.0),     # left, north (through the hedge gap)
    ((-124.0, -156.0), 9.0),    # climb: west
    ((-204.0, -163.0), 9.0),    # hairpin 1
    ((-204.0, -181.0), 9.0),
    ((-118.0, -189.0), 9.0),    # hairpin 2
    ((-118.0, -207.0), 9.0),
    ((-204.0, -215.0), 9.0),    # hairpin 3
    ((-204.0, -233.0), 9.0),
    ((-150.0, -240.0), 12.0),   # onto the saddle: north
    ((-150.0, -268.0), 9.0),    # descent: west
    ((-214.0, -274.0), 9.0),    # hairpin 4
    ((-214.0, -292.0), 9.0),
    ((-108.0, -300.0), 9.0),    # hairpin 5
    ((-108.0, -318.0), 9.0),
    ((-182.0, -324.0), 9.0),    # north to the prison
    ((-182.0, -355.65), 7.0),   # east onto the bus road in front of the gate
    ((-106.0, -355.65), 0.0),   # end (route U-turn) - map zone 2: at the army base gate
]


def fillet_polyline(corners, step=0.5):
    """Open polyline through the corners, each inner corner rounded with its radius."""
    pts = [np.array(corners[0][0])]
    for i in range(1, len(corners) - 1):
        prev = np.array(corners[i - 1][0])
        c = np.array(corners[i][0])
        nxt = np.array(corners[i + 1][0])
        r = corners[i][1]
        d_in = (c - prev) / np.linalg.norm(c - prev)
        d_out = (nxt - c) / np.linalg.norm(nxt - c)
        turn = math.atan2(d_in[0] * d_out[1] - d_in[1] * d_out[0], d_in @ d_out)
        if abs(turn) < 0.01 or r <= 0:
            pts.append(c)
            continue
        t = r * math.tan(abs(turn) / 2)
        assert t < np.linalg.norm(c - prev) and t < np.linalg.norm(nxt - c), f"corner {i} radius too big"
        p0 = c - d_in * t
        normal = np.array([-d_in[1], d_in[0]]) * math.copysign(1, turn)
        centre = p0 + normal * r
        a0 = math.atan2(p0[1] - centre[1], p0[0] - centre[0])
        n = max(2, int(math.ceil(abs(turn) * r / 0.25)))
        for s in range(n + 1):
            a = a0 + turn * s / n
            pts.append(centre + r * np.array([math.cos(a), math.sin(a)]))
    pts.append(np.array(corners[-1][0]))
    # Check the fillets don't overlap on short legs.
    for i in range(1, len(corners) - 2):
        a, b = np.array(corners[i][0]), np.array(corners[i + 1][0])
        ta = corners[i][1] * math.tan(abs(_turn(corners, i)) / 2)
        tb = corners[i + 1][1] * math.tan(abs(_turn(corners, i + 1)) / 2)
        assert ta + tb <= np.linalg.norm(b - a) + 1e-6, f"leg {i}-{i + 1} too short for its fillets"
    return resample(np.array(pts), step)


def _turn(corners, i):
    prev, c, nxt = (np.array(corners[k][0]) for k in (i - 1, i, i + 1))
    d_in = (c - prev) / np.linalg.norm(c - prev)
    d_out = (nxt - c) / np.linalg.norm(nxt - c)
    return math.atan2(d_in[0] * d_out[1] - d_in[1] * d_out[0], d_in @ d_out)


def resample(pts, step):
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    keep = np.concatenate([[True], seg > 1e-6])
    pts = pts[keep]
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    s = np.concatenate([[0.0], np.cumsum(seg)])
    n = int(s[-1] / step)
    ss = np.linspace(0.0, s[-1], n + 1)
    return np.stack([np.interp(ss, s, pts[:, 0]), np.interp(ss, s, pts[:, 1])], axis=1), ss


centre, S = fillet_polyline(CORNERS)
L = S[-1]


def first_s(cond):
    for i, p in enumerate(centre):
        if cond(p, i):
            return S[i]
    raise ValueError


s_ribbon = first_s(lambda p, i: S[i] > 30 and p[1] <= RIBBON_START_Z)
s_climb = first_s(lambda p, i: p[1] <= CLIMB_FROM_Z)
s_top0 = first_s(lambda p, i: S[i] > s_climb and p[1] <= SUMMIT_Z[0] and abs(p[0] + 150) < 1.0)
s_top1 = first_s(lambda p, i: p[1] <= SUMMIT_Z[1])
s_down = first_s(lambda p, i: S[i] > s_top1 and p[1] <= DESCEND_TO_Z and abs(p[0] + 182) < 1.0)
GRADE_UP = 0.085
H_TOP = GRADE_UP * (s_top0 - s_climb)
grade_down = H_TOP / (s_down - s_top1)
print(f"road {L:.0f} m, ribbon from s {s_ribbon:.0f}, climb {s_top0 - s_climb:.0f} m to {H_TOP:.1f} m, "
      f"descent {s_down - s_top1:.0f} m at {grade_down * 100:.1f}%")
assert grade_down < 0.115, "descent too steep"

BASE = 0.08  # ribbon top on flat ground (over the 0.06 farmyard)


def smooth01(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3 - 2 * t)


def road_h(s):
    s = np.asarray(s, dtype=float)
    up = BASE + H_TOP * smooth_ramp(s, s_climb, s_top0)
    down = H_TOP * smooth_ramp(s, s_top1, s_down)
    h = np.where(s < s_top1, up, BASE + H_TOP - down)
    # Village part (before the ribbon): on the road tiles (y 0); the ribbon starts at 0.02 and rises to BASE.
    h = np.where(s < s_ribbon, 0.0, h)
    ramp = np.clip((s - s_ribbon) / 3.0, 0, 1)
    h = np.where((s >= s_ribbon) & (s < s_ribbon + 3), 0.02 + (BASE - 0.02) * ramp, h)
    return h


def smooth_ramp(s, a, b):
    """0 before a, 1 after b, linear grade in between with 12 m rounded ends (vertical curves)."""
    t = np.clip((s - a) / (b - a), 0, 1)
    k = 12.0 / (b - a)
    # soften the kinks: blend linear with smoothstep near both ends
    lin = t
    sm = smooth01(t)
    w = np.clip(np.minimum(t, 1 - t) / k, 0, 1)
    return lin * w + sm * (1 - w)


H = road_h(S)
# ------------------------------------------------------------------ terrain
xs = np.arange(GRID_X0, GRID_X1 + 0.001, CELL)
zs = np.arange(GRID_Z0, GRID_Z1 + 0.001, CELL)
X, Z = np.meshgrid(xs, zs)  # rows = z


def ridge(z):
    up = smooth01((-140.0 - z) / (-140.0 + 250.0))      # 0 at z -140 -> 1 at z -250
    down = smooth01((z + 338.0) / (-250.0 + 338.0))      # 1 at z -250 -> 0 at z -338
    return np.where(z > -250.0, up, down)


across = smooth01((X - GRID_X0) / 30.0) * smooth01((GRID_X1 - X) / 30.0)
peak = 66.0 - 30.0 * np.exp(-((X + 150.0) / 40.0) ** 2)
rng = np.random.default_rng(49)
noise = np.zeros_like(X)
for k in range(6):
    fx, fz = rng.uniform(0.01, 0.05, 2)
    ph = rng.uniform(0, math.tau, 2)
    noise += np.sin(X * fx + ph[0]) * np.cos(Z * fz + ph[1]) / (k + 1)
r = ridge(Z)
natural = r * across * peak + noise * 4.0 * r * across
# Keep the prison yard flat (and a margin round it).
px0, px1, pz0, pz1 = PRISON[0] - 50, PRISON[0] + 50, PRISON[1] - 40, PRISON[1] + 52
dx = np.maximum(np.maximum(px0 - X, X - px1), 0)
dz = np.maximum(np.maximum(pz0 - Z, Z - pz1), 0)
natural *= smooth01(np.hypot(dx, dz) / 25.0)
natural = np.maximum(natural, 0.0)

# Road carving: within 6 m of the centre line the road height, blending to the natural slope at 18 m.
ribbon = S >= s_ribbon
rc = centre[ribbon]
rh = H[ribbon]
height = natural.copy()
for row in range(X.shape[0]):
    px = X[row][:, None]
    pz = Z[row][:, None]
    d = np.hypot(px - rc[None, :, 0], pz - rc[None, :, 1])  # (cols, samples)
    w = smooth01((18.0 - d) / 12.0)  # 1 within 6 m, 0 beyond 18 m
    wsum = w.sum(axis=1)
    has = wsum > 1e-6
    hroad = np.where(has, (w * rh[None, :]).sum(axis=1) / np.maximum(wsum, 1e-6), 0.0)
    wmax = w.max(axis=1)
    hrow = natural[row] * (1 - wmax) + hroad * wmax
    dmin = d.min(axis=1)
    near = d.argmin(axis=1)
    under = dmin < ROAD_HALF + 1.6
    hrow = np.where(under, np.minimum(hrow, rh[near] - 0.12), hrow)
    height[row] = hrow
height = np.maximum(height, -0.05)

# ------------------------------------------------------------------ props
def h_at(x, z):
    ix = int(round((x - GRID_X0) / CELL))
    iz = int(round((z - GRID_Z0) / CELL))
    if 0 <= ix < len(xs) and 0 <= iz < len(zs):
        return float(height[iz, ix])
    return 0.0


def slope_at(x, z):
    a, b = h_at(x + 1, z) - h_at(x - 1, z), h_at(x, z + 1) - h_at(x, z - 1)
    return math.degrees(math.atan(math.hypot(a, b) / 2.0))


def road_dist(x, z):
    return float(np.min(np.hypot(rc[:, 0] - x, rc[:, 1] - z)))


prng = random.Random(4949)
pines, rocks = [], []
for _ in range(20000):
    if len(pines) >= 520:
        break
    x, z = prng.uniform(GRID_X0 + 4, GRID_X1 - 4), prng.uniform(GRID_Z0 + 4, -146.0)
    y = h_at(x, z)
    if y < 1.5 or y > 46 or slope_at(x, z) > 42 or road_dist(x, z) < 9.0:
        continue
    if px0 - 8 < x < px1 + 8 and pz0 - 8 < z < pz1 + 8:
        continue
    pines.append([round(x, 2), round(y - 0.1, 2), round(z, 2), round(prng.uniform(0.75, 1.35), 2), 1 if y > 27 else 0])
for _ in range(6000):
    if len(rocks) >= 160:
        break
    x, z = prng.uniform(GRID_X0 + 4, GRID_X1 - 4), prng.uniform(GRID_Z0 + 4, -150.0)
    y = h_at(x, z)
    if y < 4 or road_dist(x, z) < 7.0 or (prng.random() > 0.35 and y < 20):
        continue
    if px0 - 8 < x < px1 + 8 and pz0 - 8 < z < pz1 + 8:
        continue
    rocks.append([round(x, 2), round(y - 0.3, 2), round(z, 2), round(prng.uniform(0.6, 2.4), 2), round(prng.uniform(0, 360), 1)])

# Guardrails both sides on the mountain stretch (from the climb to the foot on the prison side).
s_rail0 = s_climb + 6.0
s_rail1 = first_s(lambda p, i: S[i] > s_top1 and p[1] <= -330.0 and abs(p[0] + 182) < 1.0)


def offset(points, side):
    """Offset an (n,2) polyline sideways: side > 0 = to the right of the driving direction (x, z)."""
    d = np.gradient(points, axis=0)
    d /= np.linalg.norm(d, axis=1)[:, None]
    right = np.stack([-d[:, 1], d[:, 0]], axis=1)
    return points + right * side


rails = []
sel = (S >= s_rail0) & (S <= s_rail1)
idx = np.where(sel)[0][::5]  # every 2.5 m
for side in (-1, 1):
    off = offset(centre, side * (ROAD_HALF + 1.15))
    rails.append([[round(float(off[i, 0]), 2), round(float(H[i]), 3), round(float(off[i, 1]), 2)] for i in idx])

# ------------------------------------------------------------------ traffic route 5 + the bus path
def lane(side):
    pts = offset(centre, side)
    return [[float(pts[i, 0]), float(H[i]), float(pts[i, 1])] for i in range(len(pts))]


up = lane(LANE)[::2]                      # 1 m
down = lane(LANE)[::-1]                   # reversed below
down = [list(p) for p in np.array(lane(-LANE))[::-1][::2]]


def u_turn(a, b, steps=8):
    """Half circle from lane end a to lane start b (same height)."""
    a, b = np.array(a), np.array(b)
    c = (a + b) / 2
    r = np.linalg.norm(b[[0, 2]] - a[[0, 2]]) / 2
    ang0 = math.atan2(a[2] - c[2], a[0] - c[0])
    ang1 = math.atan2(b[2] - c[2], b[0] - c[0])
    # go round the far side (away from where we came from)
    out = []
    for k in range(1, steps):
        t = k / steps
        da = (ang1 - ang0)
        if da > 0:
            da -= math.tau
        if abs(da) < math.pi - 0.01:
            da = da + math.tau if da < 0 else da
        a_ = ang0 + da * t
        out.append([c[0] + r * math.cos(a_), a[1], c[2] + r * math.sin(a_)])
    return out


def far_turn(end, start, fwd):
    """U-turn round the end of the road: a half circle that bulges forward (in `fwd` direction)."""
    end, start = np.array(end), np.array(start)
    c = (end + start) / 2
    r = float(np.linalg.norm((start - end)[[0, 2]])) / 2
    v = (end - c)[[0, 2]] / r
    f = np.array(fwd) / np.linalg.norm(fwd)
    out = []
    for k in range(1, 12):
        a = math.pi * k / 12
        p = c[[0, 2]] + v * math.cos(a) * r + f * math.sin(a) * r
        out.append([float(p[0]), float(end[1]), float(p[1])])
    return out


route = up + far_turn(up[-1], down[0], centre[-1] - centre[-2]) + down + \
    far_turn(down[-1], up[0], centre[0] - centre[1])
route = [[round(p[0], 3), round(p[1], 3), round(p[2], 3)] for p in route]

# Bus path: from the bus at the prison gate (on the westbound/down lane) down the pass, down Country Lane, left
# onto Main Road's eastbound lane, to the bus stop at x -60 (south side).
BUS_START = (-150.0, -357.4)
dl = np.array(down)
i0 = int(np.argmin(np.hypot(dl[:, 0] - BUS_START[0], dl[:, 2] - BUS_START[1])))
i1 = next(i for i in range(i0, len(dl)) if dl[i, 2] >= -8.0 and abs(dl[i, 0] + 151.75) < 0.3)
bus = [list(map(float, p)) for p in dl[i0:i1 + 1]]
# Left turn (south -> east) round the corner (-151.75, 1.75), radius 5.
cx, cz, rr = -146.75, -3.25, 5.0
last = bus[-1]
while last[2] < -3.25:
    last = [last[0], 0.0, min(last[2] + 1.0, -3.25)]
    bus.append(last)
for k in range(1, 13):
    a = math.pi - (math.pi / 2) * k / 12  # from (-151.75, -3.25) round to (-146.75, 1.75)
    bus.append([cx + rr * math.cos(a), 0.0, cz + rr * math.sin(a)])
x = -146.75
while x < -60.0:
    x = min(x + 1.0, -60.0)
    bus.append([x, 0.0, 1.75])
bus = [[round(p[0], 3), round(p[1], 3), round(p[2], 3)] for p in bus]

os.makedirs(OUT, exist_ok=True)
height.astype(np.float32).tofile(os.path.join(OUT, "height.bin"))
data = {
    "grid": {"x0": GRID_X0, "z0": GRID_Z0, "nx": len(xs), "nz": len(zs), "cell": CELL},
    "summit": round(H_TOP + BASE, 2),
    "road": [[round(float(centre[i, 0]), 3), round(float(H[i]), 3), round(float(centre[i, 1]), 3)]
             for i in range(len(centre)) if S[i] >= s_ribbon - 0.01],
    "rails": rails,
    "pines": pines,
    "rocks": rocks,
    "route": route,
    "bus": bus,
    "hedge_gap": [-129.0, -119.0],
}
with open(os.path.join(OUT, "mountain.json"), "w") as f:
    json.dump(data, f, separators=(",", ":"))
print(f"heightmap {len(xs)} x {len(zs)}, max {height.max():.1f} m; {len(pines)} pines, {len(rocks)} rocks, "
      f"route {len(route)} pts, bus {len(bus)} pts, rails {len(rails[0])} posts per side")
