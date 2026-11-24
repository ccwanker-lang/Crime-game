"""Synthesizes the zone ambience loops + the wood / metal footsteps (session B, user list item 2).

    python tools/generators/gen_ambience.py .

Writes assets/audio/ambience/*.ogg (seamless 32 s loops) and assets/audio/footsteps/wood_*.ogg / metal_*.ogg.
Made for this project = CC0. Needs numpy + ffmpeg on the PATH. Deterministic (fixed seeds).
"""
import os
import subprocess
import sys
import wave

import numpy as np

SR = 44100
LOOP = 32.0
FADE = 2.0


def rng(seed):
    return np.random.default_rng(seed)


def band(x, lo, hi):
    """Band-pass by FFT mask (soft edges)."""
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / SR)
    m = np.ones_like(freqs)
    if lo > 0:
        m *= 1.0 / (1.0 + (lo / np.maximum(freqs, 1e-3)) ** 4)
    if hi < SR / 2:
        m *= 1.0 / (1.0 + (freqs / hi) ** 4)
    return np.fft.irfft(f * m, len(x))


def norm(x, peak=0.9):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def smooth_noise(r, n, rate_hz):
    """Slow random curve 0..1 (for swells / gusts)."""
    pts = max(4, int(n / SR * rate_hz) + 2)
    v = r.random(pts)
    xs = np.linspace(0, pts - 1, n)
    i = np.floor(xs).astype(int)
    t = xs - i
    t = t * t * (3 - 2 * t)
    i2 = np.minimum(i + 1, pts - 1)
    return v[i] * (1 - t) + v[i2] * t


def env(n, attack, decay):
    t = np.arange(n) / SR
    return np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-t / max(decay, 1e-4))


def add_at(out, snd, start):
    s = int(start * SR)
    e = min(len(out), s + len(snd))
    if s < len(out):
        out[s:e] += snd[: e - s]


def chirp(r, f0, f1, dur, harm=(1.0, 0.3)):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = np.linspace(f0, f1, n) * (1.0 + 0.04 * np.sin(2 * np.pi * r.uniform(20, 45) * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = sum(a * np.sin(ph * (k + 1)) for k, a in enumerate(harm))
    return s * env(n, 0.005, dur * 0.4)


def bird_song(r):
    notes = []
    base = r.uniform(2500, 4200)
    for _ in range(r.integers(3, 8)):
        d = r.uniform(0.04, 0.12)
        notes.append(chirp(r, base * r.uniform(0.8, 1.25), base * r.uniform(0.7, 1.4), d))
        notes.append(np.zeros(int(r.uniform(0.02, 0.09) * SR)))
    return np.concatenate(notes)


def gull(r):
    d = r.uniform(0.35, 0.6)
    s = chirp(r, r.uniform(1400, 1700), r.uniform(700, 900), d, harm=(1.0, 0.6, 0.4, 0.25))
    return band(s, 500, 5000)


def wind(r, n, lo=80, hi=900, gust=0.12):
    w = band(r.standard_normal(n), lo, hi)
    g = 0.35 + 0.65 * smooth_noise(r, n, gust)
    return norm(w) * g


def loopify(x):
    """Crossfade the last FADE seconds into the start: a seamless LOOP-second loop."""
    n = int(LOOP * SR)
    f = int(FADE * SR)
    out = x[:n].copy()
    tail = x[n:n + f]
    a = np.linspace(0, 1, f)
    out[:f] = out[:f] * a + tail * (1 - a)
    return out


def total():
    return int((LOOP + FADE) * SR)


# --- The loops ----------------------------------------------------------------------

def city():
    r = rng(1)
    n = total()
    rumble = norm(band(np.cumsum(r.standard_normal(n)), 25, 260)) * 0.55
    murmur = norm(band(r.standard_normal(n), 250, 1600)) * (0.15 + 0.15 * smooth_noise(r, n, 0.5))
    out = rumble + murmur
    for _ in range(14):  # passing cars: a band-noise swell
        d = r.uniform(3.0, 6.0)
        m = int(d * SR)
        car = norm(band(r.standard_normal(m), r.uniform(120, 200), r.uniform(1200, 2600)))
        car *= np.sin(np.linspace(0, np.pi, m)) ** 2 * r.uniform(0.25, 0.5)
        add_at(out, car, r.uniform(0, LOOP))
    for _ in range(3):  # far horns
        d = r.uniform(0.25, 0.6)
        m = int(d * SR)
        t = np.arange(m) / SR
        f = r.choice([350.0, 420.0, 480.0])
        h = (np.sign(np.sin(2 * np.pi * f * t)) * 0.4 + np.sin(2 * np.pi * f * 1.26 * t) * 0.6)
        add_at(out, band(h, 300, 2500) * env(m, 0.02, d) * 0.08, r.uniform(1, LOOP - 1))
    return loopify(norm(out, 0.7))


def village_day():
    r = rng(2)
    n = total()
    out = wind(r, n, 60, 700, 0.1) * 0.25
    out += norm(band(r.standard_normal(n), 2000, 9000)) * 0.02  # leaves
    for _ in range(22):
        add_at(out, bird_song(r) * r.uniform(0.08, 0.25), r.uniform(0, LOOP))
    return loopify(norm(out, 0.6))


def village_night():
    r = rng(3)
    n = total()
    out = wind(r, n, 60, 500, 0.08) * 0.18
    t = np.arange(n) / SR
    for k in range(5):  # crickets: pulsed carriers
        f = r.uniform(4200, 5600)
        rate = r.uniform(25, 40)
        train = (np.sin(2 * np.pi * rate * t + r.uniform(0, 6)) > 0.3).astype(float)
        gate = (np.sin(2 * np.pi * r.uniform(0.3, 0.7) * t + r.uniform(0, 6)) > -0.2).astype(float)
        out += np.sin(2 * np.pi * f * t) * band(train * gate, 0, 400) * r.uniform(0.03, 0.07)
    return loopify(norm(out, 0.55))


def docks():
    r = rng(4)
    n = total()
    swell = 0.2 + 0.8 * np.clip(np.sin(2 * np.pi * np.arange(n) / SR / 7.3) * 0.5 + 0.5
                                + 0.3 * smooth_noise(r, n, 0.3) - 0.15, 0, 1) ** 2
    waves = norm(band(r.standard_normal(n), 120, 2200)) * swell * 0.5
    out = waves + wind(r, n, 50, 400, 0.1) * 0.2
    for _ in range(7):
        add_at(out, gull(r) * r.uniform(0.08, 0.2), r.uniform(0, LOOP))
    for _ in range(4):  # rope / hull creaks
        d = r.uniform(0.4, 0.9)
        m = int(d * SR)
        tt = np.arange(m) / SR
        f = r.uniform(140, 260) * (1 + 0.2 * np.sin(2 * np.pi * 3 * tt))
        cr = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * (r.random(m) > 0.6)
        add_at(out, band(cr, 200, 1800) * env(m, 0.05, d * 0.5) * 0.05, r.uniform(0, LOOP))
    return loopify(norm(out, 0.65))


def forest():
    r = rng(5)
    n = total()
    out = wind(r, n, 70, 1400, 0.18) * 0.45
    out += norm(band(r.standard_normal(n), 1800, 7000)) * 0.05 * smooth_noise(r, n, 0.25)
    for _ in range(8):
        add_at(out, bird_song(r) * r.uniform(0.05, 0.12), r.uniform(0, LOOP))
    return loopify(norm(out, 0.6))


def bunker():
    r = rng(6)
    n = total()
    t = np.arange(n) / SR
    hum = sum(a * np.sin(2 * np.pi * 50 * k * t) for k, a in [(1, 0.5), (2, 0.25), (3, 0.12), (6, 0.04)])
    vent = norm(band(r.standard_normal(n), 150, 1500)) * 0.12
    out = hum * 0.35 + vent
    for _ in range(10):  # drips
        m = int(0.25 * SR)
        f = r.uniform(900, 1700)
        tt = np.arange(m) / SR
        drip = np.sin(2 * np.pi * f * (1 + 0.6 * np.exp(-tt * 30)) * tt) * env(m, 0.001, 0.05)
        add_at(out, drip * r.uniform(0.05, 0.12), r.uniform(0, LOOP))
    return loopify(norm(out, 0.55))


# --- Footsteps (wood + metal; stone / grass / snow are CC0 recordings) ---------------

def step_wood(seed):
    r = rng(100 + seed)
    m = int(0.32 * SR)
    t = np.arange(m) / SR
    thump = np.sin(2 * np.pi * r.uniform(90, 130) * t) * env(m, 0.002, 0.04)
    body = sum(np.sin(2 * np.pi * f * t) * env(m, 0.001, d) * a
               for f, d, a in [(r.uniform(220, 300), 0.06, 0.4), (r.uniform(520, 700), 0.03, 0.25)])
    click = band(r.standard_normal(m), 1500, 6000) * env(m, 0.0005, 0.012) * 0.5
    return norm(thump + body + click, 0.8)


def step_metal(seed):
    r = rng(200 + seed)
    m = int(0.6 * SR)
    t = np.arange(m) / SR
    hit = band(r.standard_normal(m), 400, 7000) * env(m, 0.0005, 0.02)
    ring = sum(np.sin(2 * np.pi * f * t) * env(m, 0.001, d) * a
               for f, d, a in [(r.uniform(380, 460), 0.18, 0.3), (r.uniform(1150, 1300), 0.12, 0.2),
                               (r.uniform(2300, 2600), 0.08, 0.12)])
    return norm(hit + ring, 0.8)


def write_ogg(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path[:-4] + ".tmp.wav"
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5", path], check=True)
    os.remove(tmp)
    print("wrote", path)


def main(root):
    amb = os.path.join(root, "assets", "audio", "ambience")
    for name, fn in [("city", city), ("village_day", village_day), ("village_night", village_night),
                     ("docks", docks), ("forest", forest), ("bunker", bunker)]:
        write_ogg(os.path.join(amb, name + ".ogg"), fn())
    steps = os.path.join(root, "assets", "audio", "footsteps")
    for i in range(4):
        write_ogg(os.path.join(steps, "wood_%d.ogg" % (i + 1)), step_wood(i))
        write_ogg(os.path.join(steps, "metal_%d.ogg" % (i + 1)), step_metal(i))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
