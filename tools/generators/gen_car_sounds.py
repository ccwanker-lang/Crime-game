"""Synthesizes car sounds into assets/audio/vehicles/ (.ogg). No sources needed.

Usage:  python -I tools/generators/gen_car_sounds.py
Needs ffmpeg and numpy.
  car_horn.ogg   - two-tone European car horn (~420 + 520 Hz), 0.6 s
  car_horn_short.ogg - a short double toot
"""
import subprocess
from pathlib import Path

import numpy as np

SR = 48000
OUT = Path(__file__).resolve().parents[2] / "assets" / "audio" / "vehicles"


def horn(length: float) -> np.ndarray:
    t = np.arange(int(length * SR)) / SR
    a = np.zeros_like(t)
    for f in (420.0, 523.0):
        # Buzzy (odd + even harmonics) like a real diaphragm horn, slight wobble.
        ph = 2 * np.pi * f * t + 0.02 * np.sin(2 * np.pi * 6 * t)
        for k, amp in [(1, 1.0), (2, 0.55), (3, 0.4), (4, 0.22), (5, 0.15), (6, 0.08)]:
            a += amp * np.sin(k * ph)
    a = np.tanh(a * 0.6)
    env = np.minimum(1, t / 0.015) * np.minimum(1, (length - t) / 0.04)
    return a * env


def save(name: str, a: np.ndarray) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    a = (a / max(1e-6, float(np.abs(a).max())) * 10 ** (-3 / 20)).astype(np.float32)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "5", str(OUT / name)], input=a.tobytes(), check=True)
    print("wrote", name)


save("car_horn.ogg", horn(0.6))
gap = np.zeros(int(0.08 * SR))
save("car_horn_short.ogg", np.concatenate([horn(0.14), gap, horn(0.2)]))
(OUT / "LICENSE.txt").write_text("Synthesized by tools/generators/gen_car_sounds.py (CC0, own work).\n")
