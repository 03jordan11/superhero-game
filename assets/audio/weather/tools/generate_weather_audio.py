"""Original synthetic weather placeholders. Standard library only; deterministic.
Run with Python 3. Outputs mono PCM WAVs beside this tools directory.
No recordings or third-party samples are used.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent


def write(name, samples, peak=0.85):
    scale = peak / max(max(abs(v) for v in samples), 0.001)
    with wave.open(str(OUT / name), "wb") as wav:
        wav.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        wav.writeframes(b"".join(struct.pack("<h", int(v * scale * 32767)) for v in samples))


def thunder(seed, seconds):
    rng = random.Random(seed)
    low = deep = high = 0.0
    samples = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        low += 0.07 * (noise - low)
        deep += 0.012 * (noise - deep)
        high += 0.3 * (noise - high)
        attack = min(t / 0.065, 1)
        tail = max(0, 1 - t / seconds) ** 1.7
        rolls = 0.6 + 0.4 * math.sin(t * 5.3 + math.sin(t * 2.1)) ** 2
        crack = math.exp(-t * 7) * high * 0.5
        value = (deep * 5 + low * 1.2 + crack) * attack * tail * rolls
        samples.append(value)
    return samples


def rain():
    rng = random.Random(1942)
    samples = []
    low = 0.0
    for i in range(RATE * 12):
        noise = rng.uniform(-1, 1)
        low += 0.08 * (noise - low)
        t = i / RATE
        samples.append((noise * 0.18 + low * 1.8) * (0.92 + 0.08 * math.sin(t * math.tau / 12)))
    # Crossfade the loop seam without a silent gap.
    overlap = RATE // 4
    for i in range(overlap):
        weight = i / overlap
        samples[i] = samples[-overlap + i] * (1 - weight) + samples[i] * weight
    return samples[:-overlap]


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    write("rain_loop.wav", rain(), 0.55)
    for index, duration in enumerate([5.5, 6.8, 7.5], 1):
        write(f"thunder_{index}.wav", thunder(729 + index * 13, duration))
    print("Generated rain loop and three original thunder variations.")
