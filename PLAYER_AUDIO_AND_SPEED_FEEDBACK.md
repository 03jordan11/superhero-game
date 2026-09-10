# Player audio and speed feedback

Implemented September 10, 2026. This adds presentation feedback without adding code to `player_character.gd` or changing movement tuning, controls, or power unlocks.

## Created sounds

All four files are original procedural synthesis, labeled `_AI`. The vocal effects are synthetic effort/groan sounds, not recorded voice performances. They are replaceable prototype assets; tune their character and mix during a listening playtest.

| File in `assets/audio/player/` | Duration | Behavior |
| --- | --- | --- |
| `super_jump_charge_AI.wav` | 2 seconds | Seamless energy loop. Pitch and volume rise with jump charge; holds at full charge. Stops on release, cancellation, knockdown, or death. |
| `speed_wind_AI.wav` | 6 seconds, stereo | Seamless rushing air with slow gusts. Fades with actual speed. |
| `player_death_AI.wav` | 1.35 seconds | Short falling-pitch strained groan/exhale on entry to death. |
| `heavy_lift_AI.wav` | 0.62 seconds | Brief exertion grunt after a successful vehicle pickup. Misses, carrying, drops, and throws do not retrigger it. |

All files use 48 kHz PCM16 with a -5 dBFS source peak. The deterministic generator is `assets/audio/player/tools/generate_player_feedback_AI.py`; run with Python 3 and NumPy. It checks finite samples, headroom, one-shot fades, and loop wrap steps. Regeneration overwrites only these four WAVs. Godot reimports them normally.

## Inspector tuning and sound replacement

Open `scenes/player.tscn` and select **PlayerSoundManager**:

- **Super Jump Charge:** Jump Charge Sound and Jump Charge Volume Db (-12).
- **Speed Wind:** Speed Wind Sound and Speed Wind Volume Db (-12).
- **Death and Heavy Lift:** Death Sound / Volume Db (-6), Heavy Lift Sound / Volume Db (-6).
- **Sounds Enabled** controls the player sound manager, including the new cues. Clear an individual sound field to disable that cue.

Drag a replacement WAV, OGG, or MP3 into the corresponding Sound field. No script changes are needed. Charge and wind configure a private copy for looping, leaving the source resource unchanged. Use seamless source recordings for those two slots. Death and lift should be imported as non-looping one-shots. Replacement files can keep their own names; `_AI` identifies the assets created in this pass.

The old flight-only playback is replaced. `hero_flying.wav` remains available as an alternate asset. The existing wind EQ/limiter bus is now named **PlayerSpeedWind**; its previous mix settings are preserved. City altitude wind remains a separate environmental layer.

The [Audio settings tab](SETTINGS_MENU.md) now controls category volume: wind/charge/impacts/footsteps/punches use **SFX**, while death and heavy-lift vocal cues use **Voice**. Master controls both. Inspector clip volumes remain the per-sound tuning applied before these category levels.

Select **PlayerSpeedFeedback** for the shared audio/visual tuning:

| Setting | Default | Meaning |
| --- | --- | --- |
| Movement Start Speed | 15 m/s | Horizontal grounded speed, or full 3D flight speed, required to begin feedback. |
| Falling Start Speed | 25 m/s | Downward speed required when airborne without flight. Ascending jumps do not trigger falling wind. |
| Speed Ramp | 30 m/s | Additional speed above the applicable threshold to reach full intensity. |
| Fade Seconds | 0.4 seconds | Time for a complete 0–1 intensity change. Smaller changes take proportionally less time. |
| Visual Strength | 0.6 | Combined trail/distortion strength; zero disables visuals while retaining audio. |

Crossing the threshold fades toward at least 20% wind intensity; additional speed increases it smoothly. At default settings full intensity is reached at 45 m/s running/flying or 55 m/s falling. There is no Sprint-key or ability-unlocked requirement. Feedback reads `get_real_velocity()` after movement, so requesting high velocity without moving does not activate it. Death and knockdown stop the audio immediately and fade the visuals away.

## Visual implementation

`PlayerSpeedFeedback` builds four thin curved ribbons once (96 triangles total), aligned behind the player along the direction of travel. Their shader adds a little motion and breaks up their opacity. A screen shader adds a pronounced radial pull and tunnel shading in peripheral vision; the center remains clear. It does not change camera FOV or shake settings.

Following the first playtest, the screen effect was strengthened: radial pull increased from 0.018 to 0.14, edge shading from 0.09 to 0.40, and the effect extends farther inward. At full speed with the default Visual Strength of 0.6, the outer edge darkens by up to 24%. The shader still uses one screen-texture sample; audio and trail intensity retain their existing tuning.

The overlay ignores mouse input and draws before the gameplay HUD and menus. Both the trails and overlay are hidden at zero intensity, avoiding idle transparent draws and the screen-texture copy. No per-frame mesh creation, particles, or addons are used.

## Validation

- Godot 4.7.2 headless editor import and script loading completed without GDScript parse errors.
- All 29 player, gameplay HUD, camera, and combat/wind regression scripts passed.
- `test_player_power_feedback.gd` checks thresholds, real versus requested movement, fades, visual disable, stream replacement, mute, charge events, an actual camera-ray vehicle pickup, and lethal/nonlethal/repeated damage.
- `test_player_charge_interruptions.gd` now also checks that release and actual loss of floor contact stop the charge audio.
- Rendered and inspected the new shaders using Direct3D 12 / Forward+ on the project's renderer. Trails are faint and the HUD remains clear. This was a controlled preview, not a traversal playtest or performance benchmark.
- The power-feedback test also passed with Windows WASAPI audio. The dummy headless audio driver reports pending playback resources at shutdown; these reports were absent with WASAPI. Restricted test processes also report inaccessible user-log/settings paths and a certificate-store warning.

### Test in Godot

1. Hold jump through full charge, release, and repeat. Walk off/remove support while charging using the existing test setup; verify the charging sound stops and can start again on landing. Confirm a quick normal jump has no charge loop.
2. Run through 15 m/s, stop, fly through that speed without holding Sprint, and hover. Check that rushing air and faint trails follow actual motion and fade away at rest.
3. Fall below and above 25 m/s, including a fast ground slam. Compare an ascending jump and a fast descent. Death or knockdown should stop the rushing sound.
4. Pick up a car, try pickup while already carrying, drop/throw it, and press pickup while looking at empty space. Only the successful lift should grunt.
5. Take nonfatal damage, then die. The death cue should play once; charging/wind/lift audio should stop. Pause during movement and check that menus remain readable and clickable.
6. Tune levels against footsteps, impacts, and city wind. Replace a stream in the Inspector and set Visual Strength to zero to verify independent visual control. Check the trails during steep flight and at the usual gameplay camera distance.

## Files added or changed in this pass

- `scripts/player-scripts/player_sound_manager.gd`: four stream slots, charge/wind playback, pickup and death event listeners; removes old flight-only playback.
- `scripts/player-scripts/player_speed_feedback.gd` (+ generated UID): speed envelope and visual setup.
- `scripts/player-scripts/player_dead_state.gd`, `player_vehicle_interactor.gd`: death-entry and successful-pickup signals.
- `scenes/player.tscn`, `default_bus_layout.tres`: feedback/audio nodes and general speed-wind bus name.
- `effects/player_speed_screen.gdshader`, `effects/player_speed_trails.gdshader` (+ generated UIDs): subtle speed effects.
- Four `_AI.wav` files and their Godot `.import` files; `assets/audio/player/tools/generate_player_feedback_AI.py`.
- `tests/test_player_power_feedback.gd` (+ generated UID), `tests/test_player_charge_interruptions.gd`, `tests/test_combat_and_wind_audio.gd`.
- This guide, `COMBAT_AND_WIND_AUDIO.md`, and the follow-up note in `PLAYER_ARCHITECTURE_REVIEW.md`.

The deferred architecture/audit findings remain tracked in `PLAYER_ARCHITECTURE_REVIEW.md`.
