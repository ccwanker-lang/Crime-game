"""Downloads Poly Haven models (CC0) as 1k glTF into assets/polyhaven/<id>/.

    python tools/fetch_polyhaven.py <project root> <id> [<id> ...]

Skips models that are already there. Godot imports them on the next --import run.
"""
import json
import os
import sys
import urllib.request

UA = {"User-Agent": "crime-coop-asset-fetch"}


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
        return r.read()


def fetch(root, asset_id, res="1k"):
    out = os.path.join(root, "assets", "polyhaven", asset_id)
    if os.path.exists(os.path.join(out, asset_id + ".gltf")):
        print("have", asset_id)
        return
    files = json.loads(get("https://api.polyhaven.com/files/" + asset_id))
    entry = files["gltf"].get(res) or next(iter(files["gltf"].values()))
    g = entry["gltf"]
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, asset_id + ".gltf"), "wb") as f:
        f.write(get(g["url"]))
    for rel, info in g.get("include", {}).items():
        dest = os.path.normpath(os.path.join(out, rel))
        if not dest.startswith(os.path.normpath(out)):
            raise ValueError("bad include path " + rel)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "wb") as f:
            f.write(get(info["url"]))
    print("got", asset_id)


if __name__ == "__main__":
    for a in sys.argv[2:]:
        fetch(sys.argv[1], a)
