"""Reproducible, original synthetic WAVs for HeyDrum; no external samples.
Run: python3 tools/generate_original_sounds.py   (needs numpy; writes into HeyDrum/Resources/Sounds/)
"""
from pathlib import Path
import math
import wave
import numpy as np

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "HeyDrum" / "Resources" / "Sounds"
OUT.mkdir(parents=True, exist_ok=True)
RNG = np.random.default_rng(20261019)

def write_mono16(name: str, signal: np.ndarray):
    signal = np.nan_to_num(signal.astype(np.float64))
    peak = float(np.max(np.abs(signal)))
    assert peak > 0
    # 0.70 peak (-3.1dBFS), gentle headroom against clipping.
    signal = 0.70 * signal / peak
    pcm = np.round(signal * 32767).astype('<i2')
    with wave.open(str(OUT / name), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(pcm.tobytes())
    print(name, f'{len(signal)/RATE:.3f}s', f'peak={float(np.max(np.abs(signal))):.2f}', f'rms={float(np.sqrt(np.mean(signal**2))):.3f}')

# A compact low drum: descending fundamental, click transient, damped breath/noise.
secs = 0.58
t = np.arange(int(RATE * secs)) / RATE
fundamental_hz = 64 + 96 * np.exp(-t * 26)
phase = 2 * np.pi * np.cumsum(fundamental_hz) / RATE
body = np.sin(phase) * np.exp(-t * 10.7)
body += 0.25 * np.sin(2 * phase + 0.4) * np.exp(-t * 20.2)
white = RNG.standard_normal(len(t))
# soften high frequencies without extra dependencies
smooth_noise = np.convolve(white, [0.16, 0.68, 0.16], mode='same')
click = smooth_noise * np.exp(-t * 86) * 0.44
thump = (body + click) * np.minimum(1.0, t * 800)
write_mono16('drum.wav', thump)

# A struck metal plate/gong, inharmonic partials and subtle beating. No sample use.
secs = 1.37
t = np.arange(int(RATE * secs)) / RATE
freqs = [407.0, 588.2, 826.3, 1261.9, 1888.5, 2911.2]
weights = [0.42, 0.35, 0.23, 0.18, 0.10, 0.07]
metal = np.zeros_like(t)
for idx, (freq, weight) in enumerate(zip(freqs, weights)):
    decay = 2.8 + idx * 1.07
    wobble = 0.0014 * np.sin(2 * np.pi * (3.0 + idx * 0.71) * t)
    metal += weight * np.sin(2 * np.pi * freq * t + wobble) * np.exp(-decay * t)
impact = RNG.standard_normal(len(t)) * np.exp(-t * 60) * 0.13
metal = (metal + impact) * np.minimum(1.0, t * 1200)
# tame long tail
metal *= np.minimum(1.0, np.maximum(0.0, (secs-t) * 12))
write_mono16('metal.wav', metal)
