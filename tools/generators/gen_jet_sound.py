"""Synthesizes the fighter jet loop into assets/audio/vehicles/jet_loop.ogg (CC0, own work). Point 85.

Usage:  python -I tools/generators/gen_jet_sound.py      (needs ffmpeg + numpy)

A 3 s seamless loop: a deep turbine roar (low-passed noise with a slow swell), a hiss on top and a turbine whine
(two tones with whole cycles in the loop). Airfield (scripts/world/airfield.gd) plays it on every jet with pitch and
volume by speed.
"""
import subprocess
from pathlib import Path

import numpy as np

SR = 48000
LOOP = 3.0
OUT = Path(__file__).resolve().parents[2] / "assets" / "audio" / "vehicles"
rng = np.random.default_rng(85)


def circ_filter(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    """Circular band-pass (FFT) with soft edges: keeps the loop seamless."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    gain = ((f >= lo) & (f <= hi)).astype(float)
    gain = np.where(f < lo, np.exp(-((lo - f) / (lo * 0.3 + 1)) ** 2), gain)
    gain = np.where(f > hi, np.exp(-((f - hi) / (hi * 0.3 + 1)) ** 2), gain)
    return np.fft.irfft(spec * gain, len(x))


def jet() -> np.ndarray:
    n = int(SR * LOOP)
    t = np.arange(n) / SR
    roar = circ_filter(rng.standard_normal(n), 25, 380)
    roar /= np.abs(roar).max()
    rumble = circ_filter(rng.standard_normal(n), 15, 90)
    rumble /= np.abs(rumble).max()
    hiss = circ_filter(rng.standard_normal(n), 1800, 7000)
    hiss /= np.abs(hiss).max()
    swell = 0.85 + 0.15 * np.sin(2 * np.pi * (1 / LOOP) * t)  # one slow swell per loop
    whine = np.zeros(n)
    for f0, amp in [(1240.0, 0.10), (2480.0, 0.05), (870.0, 0.06)]:
        f0 = round(f0 * LOOP) / LOOP  # whole cycles in the loop
        whine += amp * np.sin(2 * np.pi * f0 * t + 0.4 * np.sin(2 * np.pi * (2 / LOOP) * t))
    return (0.75 * roar + 0.5 * rumble) * swell + 0.18 * hiss + whine


def save(name: str, a: np.ndarray, db: float = -3.0) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    a = (a / max(1e-6, float(np.abs(a).max())) * 10 ** (db / 20)).astype(np.float32)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "5", str(OUT / name)], input=a.tobytes(), check=True)
    print("wrote", name)


save("jet_loop.ogg", jet())
