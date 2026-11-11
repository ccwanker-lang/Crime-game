"""Prepares weapon sounds into assets/audio/weapons/ (.ogg).

Usage:  python -I tools/generators/gen_weapon_sounds.py <source_dir>

<source_dir> holds the downloaded CC0 originals (not in git):
  Prepared SFX Library/1911/A_42P.wav, A_34P.wav  - "The Free Firearm Sound Library" (OpenGameArt, CC0)
  reload.wav                                     - "Handgun reload sound effect" by zer0_sol (OpenGameArt, CC0)
  equipmentclicks.wav                            - "Equipment clicks II" (OpenGameArt, CC0)
Casing and impact sounds are synthesized here (no source needed).
Needs ffmpeg and numpy.
"""
import subprocess
import sys
from pathlib import Path

import numpy as np

SR = 48000
OUT = Path(__file__).resolve().parents[2] / "assets" / "audio" / "weapons"


def load(path: Path, start: float, length: float, channels: int) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", str(start), "-t", str(length), "-i", str(path),
                          "-ac", str(channels), "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, channels).copy()


def fade(a: np.ndarray, fade_in: float = 0.002, fade_out: float = 0.3) -> np.ndarray:
    n_in, n_out = int(fade_in * SR), int(fade_out * SR)
    a[:n_in] *= np.linspace(0, 1, n_in)[:, None]
    a[-n_out:] *= (np.linspace(1, 0, n_out) ** 2)[:, None]
    return a


def normalize(a: np.ndarray, peak_db: float = -1.0) -> np.ndarray:
    return a / max(1e-6, float(np.abs(a).max())) * 10 ** (peak_db / 20)


def save(name: str, a: np.ndarray) -> None:
    a = np.clip(a, -1, 1).astype(np.float32)
    if a.ndim == 1:
        a = a[:, None]
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", str(a.shape[1]),
                    "-i", "-", "-c:a", "libvorbis", "-q:a", "6", str(OUT / f"{name}.ogg")],
                   input=a.tobytes(), check=True)
    print(f"{name}.ogg  {len(a) / SR:.2f} s  {a.shape[1]} ch")


def onset(a: np.ndarray, threshold: float = 0.15) -> int:
    mono = np.abs(a).max(axis=1)
    return int(np.argmax(mono > threshold * mono.max()))


def clip_shot(path: Path, start: float, length: float, channels: int) -> np.ndarray:
    a = load(path, max(0.0, start - 0.1), length + 0.2, channels)
    a = a[max(0, onset(a) - int(0.003 * SR)):][: int(length * SR)]
    return normalize(fade(a, 0.001, length * 0.6))


# --- Synthesized ------------------------------------------------------------------

rng = np.random.default_rng(7)


def env(n: int, decay: float) -> np.ndarray:
    return np.exp(-np.arange(n) / SR / decay)


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    alpha = 1 - np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def brass_tink(n: int, base: float) -> np.ndarray:
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, amp, decay in [(1.0, 1.0, 0.06), (2.76, 0.6, 0.04), (5.40, 0.35, 0.025), (8.93, 0.2, 0.015)]:
        out += amp * np.sin(2 * np.pi * base * ratio * t + rng.uniform(0, 6)) * env(n, decay)
    out += rng.normal(0, 0.3, n) * env(n, 0.002)
    return out


def casing(seed: int) -> np.ndarray:
    """A brass casing bouncing on stone: 3-4 tinks getting closer and softer."""
    r = np.random.default_rng(seed)
    total = np.zeros(int(0.7 * SR))
    t, amp, gap = 0.0, 1.0, r.uniform(0.11, 0.16)
    base = r.uniform(3600, 4400)
    for _ in range(int(r.integers(3, 5))):
        i = int(t * SR)
        n = min(int(0.15 * SR), len(total) - i)
        if n <= 0:
            break
        total[i:i + n] += amp * brass_tink(n, base * r.uniform(0.97, 1.03))[:n]
        t += gap
        gap *= r.uniform(0.55, 0.7)
        amp *= r.uniform(0.45, 0.6)
    return normalize(total[:, None], -6)


def impact(kind: str, seed: int) -> np.ndarray:
    r = np.random.default_rng(seed)
    n = int(0.35 * SR)
    noise = r.normal(0, 1, n)
    t = np.arange(n) / SR
    if kind == "concrete":   # sharp crack + gritty debris
        a = noise * env(n, 0.012)
        a = a - lowpass(a, 700)
        debris = lowpass(r.normal(0, 1, n), 3000) * env(n, 0.06) * 0.25 * (r.random(n) > 0.92)
        a = a + debris
    elif kind == "metal":    # ping
        a = noise * env(n, 0.004) * 0.6
        for f, amp, d in [(1850, 1.0, 0.09), (3120, 0.6, 0.06), (4870, 0.4, 0.04)]:
            a += amp * np.sin(2 * np.pi * f * r.uniform(0.95, 1.05) * t) * env(n, d)
    elif kind == "wood":     # dull knock
        a = lowpass(noise, 1800) * env(n, 0.02) * 2
        a += np.sin(2 * np.pi * r.uniform(170, 230) * t) * env(n, 0.03)
    else:                    # flesh: soft low thud
        a = lowpass(noise, 600) * env(n, 0.03) * 3
        a += np.sin(2 * np.pi * 90 * t) * env(n, 0.05)
    return normalize(a[:, None], -3)


def dry_fire(src: Path) -> np.ndarray:
    a = load(src, 2.0, 0.25, 1)
    return normalize(fade(a[max(0, onset(a) - 100):], 0.001, 0.08), -4)


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src = Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    lib = src / "Prepared SFX Library" / "1911"
    # Close (first person, stereo) and mid-distance (3D, mono) shots, two takes each.
    save("pistol_shot_1", clip_shot(lib / "A_42P.wav", 0.94, 1.6, 2))
    save("pistol_shot_2", clip_shot(lib / "A_42P.wav", 5.00, 1.6, 2))
    save("pistol_shot_far_1", clip_shot(lib / "A_34P.wav", 1.54, 2.2, 1))
    save("pistol_shot_far_2", clip_shot(lib / "A_34P.wav", 6.65, 2.2, 1))
    rel = load(src / "reload.wav", 0.0, 1.6, 1)
    save("pistol_reload", normalize(fade(rel, 0.005, 0.1), -3))
    save("pistol_dry_fire", dry_fire(src / "equipmentclicks.wav"))
    for i in range(3):
        save(f"casing_{i + 1}", casing(i))
    for kind in ["concrete", "metal", "wood", "flesh"]:
        for i in range(2):
            save(f"impact_{kind}_{i + 1}", impact(kind, i + 10 * len(kind)))


if __name__ == "__main__":
    main()
