"""Create an original, non-looping superhero bullet impact using synthesis only."""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 48000
DURATION = 0.42
rng = random.Random(71023)
samples = []
low_noise = 0.0
body_phase = 0.0
ring_phase = 0.0
for index in range(round(RATE * DURATION)):
    t = index / RATE
    noise = rng.uniform(-1.0, 1.0)
    low_noise += 0.075 * (noise - low_noise)
    # A dry projectile snap over a dense, low superhero-body impact.
    snap = 0.65 * (noise - low_noise) * math.exp(-t / 0.009)
    body_phase += math.tau * (68.0 + 100.0 * math.exp(-t / 0.018)) / RATE
    body = 0.85 * math.sin(body_phase) * math.exp(-t / 0.063)
    grit = 1.1 * low_noise * math.exp(-t / 0.038)
    # Short, inharmonic metal fleck: the bullet striking a superhuman surface.
    ring_phase += math.tau * (1350.0 + 400.0 * math.exp(-t / 0.012)) / RATE
    ring = (0.09 * math.sin(ring_phase) + 0.04 * math.sin(ring_phase * 1.483))
    ring *= math.exp(-t / 0.043)
    attack = min(1.0, t / 0.0005)
    tail = min(1.0, max(0.0, (DURATION - t - 1.0 / RATE) / 0.035))
    samples.append(math.tanh((snap + body + grit + ring) * 1.35) * attack * tail)

peak = max(abs(value) for value in samples)
gain = 10 ** (-3.0 / 20.0) / peak
pcm = b"".join(struct.pack("<h", round(value * gain * 32767)) for value in samples)
output = Path(__file__).resolve().parent.parent / "superhero_bullet_hit.wav"
with wave.open(str(output), "wb") as wav:
    wav.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
    wav.writeframes(pcm)
assert samples[0] == samples[-1] == 0.0
print(f"Created {output}: {DURATION}s, {RATE} Hz, mono PCM16, peak -3 dBFS")
