"""Tiny .tscn writer used by the prefab / world generators."""
import os


def v3(x, y, z):
    return f"Vector3({x:g}, {y:g}, {z:g})"


def col(r, g, b, a=1.0):
    return f"Color({r:g}, {g:g}, {b:g}, {a:g})"


def xform(pos=(0, 0, 0), rot_y=0.0, scale=1.0):
    """Transform3D with a Y rotation in degrees and uniform scale."""
    import math
    c = math.cos(math.radians(rot_y)) * scale
    s = math.sin(math.radians(rot_y)) * scale
    sc = scale
    x, y, z = pos
    return (f"Transform3D({c:.6g}, 0, {s:.6g}, 0, {sc:g}, 0, {-s:.6g}, 0, {c:.6g}, "
            f"{x:g}, {y:g}, {z:g})")


def strarr(items):
    return "PackedStringArray(" + ", ".join(f'"{i}"' for i in items) + ")"


class Scene:
    def __init__(self):
        self.ext = []      # (type, path, id)
        self.sub = []      # (type, id, props)
        self.nodes = []    # lines

    def res(self, rtype, path):
        for t, p, i in self.ext:
            if p == path:
                return f'ExtResource("{i}")'
        i = f"{len(self.ext) + 1}_r"
        self.ext.append((rtype, path, i))
        return f'ExtResource("{i}")'

    def script(self, path):
        return self.res("Script", path)

    def scene(self, path):
        return self.res("PackedScene", path)

    def subres(self, rtype, props):
        i = f"{rtype}_{len(self.sub) + 1}"
        self.sub.append((rtype, i, props))
        return f'SubResource("{i}")'

    def node(self, name, ntype=None, parent=None, instance=None, props=None, groups=None):
        head = f'[node name="{name}"'
        if ntype:
            head += f' type="{ntype}"'
        if parent is not None:
            head += f' parent="{parent}"'
        if instance:
            head += f" instance={self.scene(instance)}"
        if groups:
            head += " groups=[" + ", ".join(f'"{g}"' for g in groups) + "]"
        head += "]"
        lines = [head]
        for k, v in (props or {}).items():
            lines.append(f"{k} = {v}")
        self.nodes.append("\n".join(lines))

    def save(self, path):
        out = [f"[gd_scene format=3]", ""]
        for t, p, i in self.ext:
            out.append(f'[ext_resource type="{t}" path="{p}" id="{i}"]')
        if self.ext:
            out.append("")
        for t, i, props in self.sub:
            out.append(f'[sub_resource type="{t}" id="{i}"]')
            for k, v in props.items():
                out.append(f"{k} = {v}")
            out.append("")
        out.append("\n\n".join(self.nodes))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(out) + "\n")
