# Weather placeholder sounds

These four mono 22,050 Hz PCM WAV files are original synthetic placeholders generated for this project. No downloaded recordings, third-party samples, or external attribution requirements are involved.

- `rain_loop.wav`: continuous filtered noise with a crossfaded loop seam.
- `thunder_1.wav`, `thunder_2.wav`, `thunder_3.wav`: distinct seeded noise, bass rumble, onset crack, and decaying rolls.
- `tools/generate_weather_audio.py`: reproducible standard-library Python generator. Run it with Python 3 from any working directory to recreate the files here.

Godot loops the rain stream and varies thunder pitch slightly. All weather audio routes through the Weather bus into SFX. A low-pass filter and lower gain create the indoor versions in real time; the same treatment applies to a thunder roll already playing when entering shelter. These are gameplay placeholders, not recordings of real storms.
