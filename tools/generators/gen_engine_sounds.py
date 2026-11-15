"""Synthesizes engine, tyre and brake sounds into assets/audio/vehicles/ (.ogg, CC0, own work). Session B, point 66.

Usage:  python -I tools/generators/gen_engine_sounds.py      (needs ffmpeg + numpy)

Loops are made seamless: every tone has a whole number of cycles in the loop and noise is filtered circularly (FFT),
so the end joins the start. VehicleSound (scripts/vehicles/vehicle_sound.gd) plays them with pitch = rpm / BASE_RPM.
  engine_on.ogg     - 4-cylinder under load at BASE_RPM (2 s loop): sharp firing pulses, exhaust bark, intake hiss
  engine_off.ogg    - the same engine coasting / idling (2 s loop): soft, low-passed, a little burble
  tyre_screech.ogg  - tyres sliding (1.5 s loop): band-passed noise + a wavering squeal
  brake_squeal.ogg  - a short brake squeal (one shot, 0.9 s)
"""
import subprocess
from pathlib import Path

import numpy as np

SR = 48000
OUT = Path(__file__).resolve().parents[2] / "assets" / "audio" / "vehicles"
BASE_RPM = 1500.0  # keep in sync with VehicleSound.BASE_RPM
rng = np.random.default_rng(66)


def circ_filter(x: np.ndarray, lo: float, hi: float, slope: float = 0.0) -> np.ndarray:
    """Circular band-pass (FFT): keeps the loop seamless. slope = dB per octave tilt above lo."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    gain = ((f >= lo) & (f <= hi)).astype(float)
    # soft edges
    gain = np.where(f < lo, np.exp(-((lo - f) / (lo * 0.3 + 1)) ** 2), gain)
    gain = np.where(f > hi, np.exp(-((f - hi) / (hi * 0.3 + 1)) ** 2), gain)
    if slope:
        gain *= np.where(f > lo, (np.maximum(f, 1) / max(lo, 1)) ** (slope / 6.02), 1.0)
    return np.fft.irfft(spec * gain, len(x))


def circ_convolve(x: np.ndarray, k: np.ndarray) -> np.ndarray:
    kk = np.zeros_like(x)
    kk[:len(k)] = k
    return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(kk), len(x))


def engine(load: bool, loop: float = 2.0) -> np.ndarray:
    n = int(loop * SR)
    fire_hz = BASE_RPM / 60.0 * 2.0  # 4 cylinders, 4-stroke: 2 firings per turn
    firings = int(round(fire_hz * loop))
    period = n / firings
    pulses = np.zeros(n)
    amps = 1.0 + rng.normal(0, 0.12 if load else 0.2, firings)
    # One cylinder a touch weaker: the "lumpy" half-order rhythm of a real engine.
    amps[::4] *= 0.85
    for i in range(firings):
        pos = int(i * period + rng.normal(0, 0.004 * period))
        pulses[pos % n] += amps[i]
    t = np.arange(int(0.05 * SR)) / SR
    # The pulse: a few damped resonances of the exhaust + block.
    if load:
        k = (np.exp(-t * 90) * np.sin(2 * np.pi * 110 * t) * 1.0 + np.exp(-t * 160) * np.sin(2 * np.pi * 310 * t) * 0.7
             + np.exp(-t * 420) * np.sin(2 * np.pi * 950 * t) * 0.35 + np.exp(-t * 900) * rng.normal(0, 0.25, len(t)))
    else:
        k = (np.exp(-t * 70) * np.sin(2 * np.pi * 85 * t) * 1.0 + np.exp(-t * 140) * np.sin(2 * np.pi * 220 * t) * 0.35
             + np.exp(-t * 600) * rng.normal(0, 0.08, len(t)))
    a = circ_convolve(pulses, k)
    hiss = circ_filter(rng.normal(0, 1, n), 400 if load else 200, 4000 if load else 1500, -3)
    a = a / np.abs(a).max() + hiss / np.abs(hiss).max() * (0.12 if load else 0.05)
    # Low rumble at the crank frequency (whole cycles in the loop).
    crank = round(fire_hz / 2 * loop) / loop
    tt = np.arange(n) / SR
    a += (0.25 if load else 0.35) * np.sin(2 * np.pi * crank * tt)
    if not load:
        a = circ_filter(a, 20, 1800)
    a = np.tanh(a * (1.6 if load else 1.1))
    return a


def screech(loop: float = 1.5) -> np.ndarray:
    n = int(loop * SR)
    tt = np.arange(n) / SR
    noise = circ_filter(rng.normal(0, 1, n), 900, 3200)
    noise /= np.abs(noise).max()
    # A wavering squeal: base tone + vibrato, both with whole cycles in the loop.
    f0 = round(1150 * loop) / loop
    vib = round(5 * loop) / loop
    wob = round(0.67 * loop) / loop
    ph = 2 * np.pi * f0 * tt + 6.0 * np.sin(2 * np.pi * vib * tt) + 30.0 * np.sin(2 * np.pi * wob * tt)
    tone = np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)
    env = 0.75 + 0.25 * np.sin(2 * np.pi * (round(3 * loop) / loop) * tt)
    return np.tanh((0.55 * noise + 0.6 * tone * env) * 1.2)


def brake(length: float = 0.9) -> np.ndarray:
    tt = np.arange(int(length * SR)) / SR
    f = 2650 + 40 * np.sin(2 * np.pi * 7 * tt) - 120 * tt
    ph = 2 * np.pi * np.cumsum(f) / SR
    a = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.1 * rng.normal(0, 1, len(tt))
    env = np.minimum(1, tt / 0.06) * np.clip((length - tt) / 0.35, 0, 1) * (0.7 + 0.3 * np.sin(2 * np.pi * 3 * tt))
    return a * env


def save(name: str, a: np.ndarray, db: float = -3.0) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    a = (a / max(1e-6, float(np.abs(a).max())) * 10 ** (db / 20)).astype(np.float32)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "5", str(OUT / name)], input=a.tobytes(), check=True)
    print("wrote", name)


save("engine_on.ogg", engine(True))
save("engine_off.ogg", engine(False))
save("tyre_screech.ogg", screech())
save("brake_squeal.ogg", brake(), -6.0)
