# Point 27: building colours from the one palette. A building's wall/roof tint multiplies its
# stylized material colour (gen_materials.py), so ptint() returns the tint that turns material
# `mat` exactly into palette swatch `swatch`.
from gen_palette import SWATCHES

PCOL = {n: c for n, c in SWATCHES}
# Stylized material -> its own swatch (keep in sync with gen_materials.py).
MATERIAL_SWATCH = {"brick_old": "brick_brown", "brick_mixed": "brick_red", "brick_yellow": "brick_yellow",
                   "brick_white": "brick_white", "plaster": "plaster_cream", "concrete": "concrete",
                   "roof_red": "roof_red", "roof_dark": "roof_dark"}


def _lin(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def _srgb(v):
    return v * 12.92 if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055


def ptint(mat, swatch, shade=1.0):
    base = PCOL[MATERIAL_SWATCH[mat]]
    t = PCOL[swatch]
    c = [_srgb(min(4.0, _lin(t[i]) / _lin(base[i]) * shade)) for i in range(3)]
    return "Color(%.3f, %.3f, %.3f, 1)" % tuple(c)


def pcol(swatch):
    c = PCOL[swatch]
    return "Color(%s, %s, %s, 1)" % c
