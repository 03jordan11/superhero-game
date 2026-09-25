# Weather: Thunderstorm

The `Weather` autoload keeps session weather across city, hideout, and other interior transitions. It starts Clear. There is no random weather selection, automatic storm expiry, or weather save-file field in this first version. Once started, a storm remains active until explicitly cleared, including across scene reloads. Combat Arena suppresses weather presentation while retaining the outdoor weather state for the return trip.

## Developer console

Open the development console with the existing backtick binding. Commands are case-insensitive and support help/autocomplete:

| Command | Result |
| --- | --- |
| `weather thunderstorm` | Fade into a thunderstorm over six seconds |
| `weather clear` | Fade back to the current time-of-day sky; cancel pending thunder/flashes |
| `weather` | Show weather, transition amount, and shelter state |
| `weather lightning` | Trigger one test lightning/thunder pair during a storm |
| `help weather` | Show command usage |

The console pauses gameplay: close it to see the transition or queued test strike. Repeating the current weather command does not restart the transition or storm schedule. Invalid arguments leave state unchanged.

Q / RT is **Power Special**, the activatable ability of the elemental power selected through Alt. Electricity tier 2 now invokes the same weather system with a fresh press, without Aim. See [Thunderstorm ability details](electricity.md#thunderstorm).

The summoned storm remains until `weather clear`, has no combat effects, and shares the same scene-persistent presentation as manual storms. Its five-minute cooldown starts at the casting release and belongs to this autoload, so changing scenes or recreating the player cannot reset it. It uses scaled gameplay time, freezes while paused, and is not stored in save files. Manual weather commands neither consume nor reset this cooldown. An active storm always prevents another summon, even after cooldown expiry.

Electricity tier 3 adds a separate, player-triggered Lightning Strike during any active storm. Natural/distant weather lightning stays cosmetic. The player's strike cooldown is exposed as `Weather.lightning_strike_cooldown_remaining` (60 scaled seconds on impact); it persists with the summon cooldown across scenes and is independent of it. Both timers appear in the [plain-text cooldown display](cooldowns.md). See [Lightning Strike](electricity.md#lightning-strike).

## Visuals, sound, and timing

- The existing day/night sky blends to broad gray cloud banks, weaker sunlight/moonlight, cooler ambient light, and thicker haze. Lightning appears in distant sky directions with a short double flash and brief ambient illumination. These strikes are decorative and cannot damage actors or buildings.
- One moderate rain intensity is rendered near the active camera. There are 2,800 GPU-animated streaks in one MultiMesh, not one particle node per drop. A 9×9 physics height map clips rain below roofs and ground. It updates every 0.15 seconds, or sooner after moving eight meters, and follows flight altitude. It is intentionally a coarse prototype: narrow awnings/roof edges may need finer sampling later. Interior scenes suppress rain geometry entirely.
- Thunder starts after the flash, using a randomized 600–1,800 meter distance divided by 343 m/s (about 1.75–5.25 seconds). New strikes are scheduled 8–18 seconds apart; the first is scheduled 3–6 seconds after starting a storm. Three original synthesized thunder clips have slight pitch variation. Rain uses one continuous generated loop.
- Indoors and under roofs, rain and thunder remain audible at lower volume through an 850 Hz low-pass filter. Outdoors the cutoff returns to 18 kHz. Indoor/outdoor gain and filtering blend over about half a second. Loading pauses audio with the game; scene presentation is rebound on arrival without resetting weather.
- Weather timers and rain motion use scaled game seconds, so Anticipation slows them and the pause menu freezes them. Global audio playback now follows gameplay slow motion through the shared SlowMotion helper, including rain and thunder. The per-clip pitch variation remains intact. Changing or pausing the solar clock does not stop weather, and weather never changes the solar hour. Clouds continue drifting when the solar clock is held.

Any scene entered through `HideoutTravel` is tagged `weather_indoors`; scenes with no day/night controller are also treated as interiors for presentation. New outdoor scenes should use the day/night controller. Spaces without an active player remain silent. Rain generation and roof probes stop when fully clear.

## Tuning and preparation

Select the running `/root/Weather` node in the Remote inspector to tune transition duration, strike intervals/distances, and rain/thunder volumes. Audio lives in `assets/audio/weather/`, with a reproducible generator and provenance notes. The Weather bus feeds SFX so normal sound settings apply.

The rain mesh/material is instantiated hidden by the autoload at startup. Storm/bolt uniforms are part of the existing sky shader. Shader changes are recorded in [the shader inventory](shaders.md); this preparation is not a guarantee of zero first-use pipeline work on every GPU.

## Validation and playtest

`tests/test_weather.gd` checks commands, smooth transitions, exact thunder delay, invalid input, shelter clipping, muffling, pause, scene replacement, indefinite duration, and clear cleanup. `tests/test_boxing_gym_travel.gd` also checks weather during actual repeated city/interior trips. `tests/render_weather.gd` captures city views in Clear, Thunderstorm, lightning, and night conditions.

Validation completed: weather, day/night, developer-console, and two complete gym round trips passed. Actual city captures were inspected in clear, storm, lightning, and night conditions. Final editor import and Forward+ rendering reported no script or shader compilation errors. WAV duration/peak checks passed without clipping. Existing command-line certificate/user-data/cache, duplicate UID, and some shutdown resource warnings remain. Sound balance still needs a listening playtest; no claim of subjective audio verification is made.

Playtest: run `weather thunderstorm`, close the console, and watch the sky and rain blend in. Wait for several lightning/thunder pairs. Fly at different heights; step below roofs; enter the hideout and gym, listen for muffled weather, then return outside. Use `time night` and `time pause` to inspect the storm at night. Pause during a queued thunder roll. Finally run `weather clear` and confirm lighting/audio return to normal. Try `weather lightning` while clear to confirm it refuses the request.

Modified/added files: `project.godot`; `scripts/weather_controller.gd`; `scripts/day_night_cycle.gd`; `assets/sky/hero_sky.gdshader`; `effects/weather_rain.gd` and `.gdshader`; `scripts/ui-scripts/developer_commands.gd`; `scripts/hideout_travel.gd`; `CONTROLS.md`; `CURRENT_CONTROLS.md`; this document and `docs/shaders.md`; the four WAVs, import settings, generator and README in `assets/audio/weather/`; `tests/test_weather.gd`; `tests/render_weather.gd`; and `tests/test_boxing_gym_travel.gd`, with generated UIDs.
