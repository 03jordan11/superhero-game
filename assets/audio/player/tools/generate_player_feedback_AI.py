"""Original procedural player sounds; no recordings. Requires Python 3 + NumPy.

Run from any directory. Overwrites only the four named _AI WAVs alongside this
tools directory. Voice cues are synthesized formant effects, not human recordings.
"""
from pathlib import Path
import wave
import numpy as np

RATE = 48000
OUT = Path(__file__).resolve().parent.parent
rng = np.random.default_rng(9102026)


def noise(seconds, low, high):
    """Periodic band-limited noise: FFT construction makes seamless wind loops."""
    n = round(RATE * seconds)
    f = np.fft.rfftfreq(n, 1 / RATE)
    spectrum = rng.normal(size=len(f)) + 1j * rng.normal(size=len(f))
    shape = (f / max(low, 1)) ** 2 / (1 + (f / max(low, 1)) ** 2)
    shape /= np.sqrt(1 + (f / high) ** 6)
    spectrum *= shape
    spectrum[0] = 0
    x = np.fft.irfft(spectrum, n=n)
    return x / np.sqrt(np.mean(x * x))


def save(name, x, loop=False):
    x = x - np.mean(x, axis=0)
    if not loop:
        fade = round(RATE * .018)
        x[:fade] *= np.linspace(0, 1, fade)
        x[-fade:] *= np.linspace(1, 0, fade)
    x *= 10 ** (-5 / 20) / np.max(np.abs(x))
    pcm = np.rint(x * 32767).astype('<i2')
    channels = 1 if x.ndim == 1 else x.shape[1]
    with wave.open(str(OUT / name), 'wb') as wav:
        wav.setparams((channels, 2, RATE, 0, 'NONE', 'not compressed'))
        wav.writeframes(pcm.tobytes())
    assert np.isfinite(x).all() and np.max(np.abs(x)) < 1
    if loop:
        # Compare the wrap step with ordinary sample steps in this bandwidth.
        assert np.max(np.abs(x[0] - x[-1])) < np.quantile(np.abs(np.diff(x, axis=0)), .999), 'Loop boundary discontinuity'
    else:
        assert x[0] == x[-1] == 0
    print(f'{name}: {len(x)/RATE:.2f}s, {channels} channels, peak -5 dBFS, '
          f'RMS {20*np.log10(np.sqrt(np.mean(x*x))):.1f} dBFS')


# A stable energy bed; gameplay raises its pitch and level as charge builds.
t = np.arange(RATE * 2) / RATE
charge = (.45*np.sin(2*np.pi*110*t) + .24*np.sin(2*np.pi*220*t)
          + .09*np.sin(2*np.pi*440*t)) * (.8 + .2*np.cos(2*np.pi*4*t))
charge += .055*noise(2, 350, 1800)
save('super_jump_charge_AI.wav', charge, loop=True)

# Wide, rushing air with slow gusts. All modulation completes whole loop cycles.
t = np.arange(RATE * 6) / RATE
body = noise(6, 90, 1600)
left = .75*body + .25*noise(6, 600, 4300)
right = .75*np.roll(body, 270) + .25*noise(6, 600, 4300)
gust = .72 + .18*np.sin(2*np.pi*t/6) + .1*np.cos(2*np.pi*3*t/6)
save('speed_wind_AI.wav', np.column_stack((left*gust, right*gust)), loop=True)


def voice(seconds, start_pitch, end_pitch, formants):
    t = np.arange(round(RATE * seconds)) / RATE
    progress = t / seconds
    frequency = start_pitch + (end_pitch - start_pitch)*progress
    phase = 2*np.pi*np.cumsum(frequency)/RATE
    phase += .09*np.sin(2*np.pi*29*t) # Breath strain.
    x = np.zeros_like(t)
    for harmonic in range(1, 45):
        hz = harmonic*frequency
        weight = sum(np.exp(-.5*((hz-center)/width)**2)
                     for center, width in formants) / harmonic**.65
        x += weight*np.sin(harmonic*phase)
    air = noise(seconds, 180, 2800)
    envelope = np.sin(np.pi*progress)**1.2 * np.exp(-1.8*progress)
    return np.tanh(1.6*x)*envelope + .075*air*envelope


save('heavy_lift_AI.wav', voice(.62, 125, 92, [(490, 110), (1150, 190), (2400, 260)]))
save('player_death_AI.wav', voice(1.35, 135, 62, [(580, 160), (1000, 180), (2300, 300)]))
