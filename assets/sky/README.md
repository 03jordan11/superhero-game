# City day / night sky

The playable Main scene and standalone SuperCity use one `DayNightCycle`, next to
the city's existing `Daylight` and `Sun` nodes. The redundant Main environment is
empty and its static directional light is disabled; node paths are preserved.

## Try it

Run the game, open the existing developer console with backtick, and enter:

| Command | View / behavior |
| --- | --- |
| `time night` | Midnight, Milky Way, star field, moonlight |
| `time sunset` | 18:00, warm western horizon |
| `time dawn` | 06:00, sunrise on the opposite horizon |
| `time day` | Noon |
| `time 20.5` | Any fractional hour; here 20:30 |
| `time pause` | Hold the current sky and wind for a photograph |
| `time resume` | Resume the cycle |
| `time speed 20` | Accelerate solar time to watch stars move |
| `time speed 1` | Restore normal speed |
| `time` | Show clock / run state / speed |

Close the console to let time advance (the console pauses the game). Look up from
the park, rooftops or flight for the widest sky. Default start is 17:00; a full
24-hour cycle lasts 24 real minutes. Game pause freezes both the clock and clouds.
Time is session-local and restarts at the Inspector value when the scene reloads.

Select `SuperCity/DayNightCycle` in the Inspector to tune time, cycle length,
star and Milky Way brightness, celestial orientation, moon size, light energies,
fog density, and cloud coverage / drift speed. `Time Of Day` previews in the
editor; the clock does not automatically advance in the editor. `Latitude` tilts
the star-rotation pole; sun rise/set times stay artistically fixed at 06:00/18:00.
This is a cinematic solar clock, not a date/location ephemeris. The moon is an
art-directed full moon opposite the sun, with procedural surface shading.

## Research and implementation choice

* [Godot sky shaders](https://docs.godotengine.org/en/latest/tutorials/shaders/shader_reference/sky_shader.html)
  support a separate visible background and lighting cubemap pass. A custom sky
  is the best fit here: it can combine baked HDR celestial cubemaps with animated
  atmospheric colors, sun/moon discs and independently moving clouds.
* [ProceduralSkyMaterial](https://docs.godotengine.org/en/stable/classes/class_proceduralskymaterial.html)
  is lightweight and useful for basic daylight, but does not supply the requested
  layered star/Milky Way/cloud treatment.
* [PhysicalSkyMaterial](https://docs.godotengine.org/en/stable/classes/class_physicalskymaterial.html)
  offers atmospheric scattering, but the stylized night treatment still calls for
  a custom shader. This implementation favors art direction and quick tuning over
  physical scattering or expensive volumetric clouds.
* [Sky](https://docs.godotengine.org/en/latest/classes/class_sky.html): changing
  uniforms invalidates the radiance cubemap. The implementation uses realtime
  processing, a 256-pixel radiance map, updates at most 30 times per second, and
  omits star maps / moon detail / sun disc from the reflection pass. Stars remain
  full resolution in the visible sky. HDR cubemaps use BC6H compression and mipmaps.
* [DirectionalLight3D](https://docs.godotengine.org/en/stable/classes/class_directionallight3d.html)
  shines along local -Z. The clock drives both the shader's source direction and
  light orientation together; sun and moon are Light Only so sky discs are not
  duplicated. Only the risen light casts shadows. Ambient light and distance fog
  follow the clock; sky fog is handled in the shader to keep overhead stars clear.

The star maps share one rotation matrix, so the synthetic stars stay aligned with the
Milky Way. Rotation happens in 3D around a tilted celestial pole, and is periodic
across midnight. Cloud motion uses a separately animated seamless noise texture;
clouds occlude the celestial sky and pick up sunset light. No addons are required.

Weather patterns, precipitation, lightning, cloud shadows, lunar phases and
volumetric fly-through clouds are future work. Coverage, wind, fog and light
controls provide a foundation without adding those systems yet.

## Original baked starscape

The previous downloaded panoramas have been replaced by original, procedurally
authored HDR cubemaps. No downloaded star imagery or catalog data is used:

* `custom_galaxy.res`: native Godot Cubemap, six 1024² faces; continuous 3D noise
  builds a pale blue/gold Milky Way band, a brighter galactic core and dark dust lanes.
* `custom_stars.res`: native Godot Cubemap, six 2048² faces; 220,000 synthetic stars
  with varied sizes, colours and brightness. 75,000 cover the sphere uniformly;
  145,000 form the denser galactic population. This is an artistic sky, not a real
  constellation chart.
* `tools/generate_starscape.py`: deterministic offline authoring, seed 842119.
  Requires Python with NumPy. Generates directly from 3D directions, including
  overlapping star footprints at face edges. No latitude/longitude image mapping.
* `tools/pack_starscape.gd`: generates mipmaps, applies BC6H compression, and packs
  the six faces into each native resource. Must use the real renderer; Godot's
  headless dummy renderer does not preserve layered texture image data on save.

The runtime uses `samplerCube` with direct rotated 3D directions. The former
equirectangular pole singularity and atan/acos UV conversion are gone. Cubemap
filtering handles neighboring faces. Separate galaxy and star brightness controls
remain available. Clouds, atmosphere, moon, city lighting and time controls continue
to use the existing clock.

The two cube payloads use **40 MiB total** of compressed GPU image data including
mipmaps (8 MiB galaxy + 32 MiB stars), versus roughly 21.3 MiB for the previous two
4K panoramas. This buys more star detail. There are still two celestial texture
lookups per visible nighttime sky fragment and no per-frame star generation, star
nodes or star lights. It is not an FPS benchmark; total scene performance also
depends on resolution, clouds, reflections and the rest of the city.

To regenerate from the project root (use the installed executable paths if they
are not on PATH):

```text
python assets/sky/tools/generate_starscape.py
godot --path . --script res://assets/sky/tools/pack_starscape.gd
godot --path . --script res://tests/test_starscape.gd
godot --path . --script res://assets/sky/tools/render_starscape.gd
```

Intermediate RGB half-float faces and the bake manifest live in
`artifacts/starscape_bake/`, excluded from Godot imports. Only the two `.res` files
are needed at runtime. The generator uses original math and random distributions;
there are no external image, model or addon dependencies for the starscape.

## Validation

Using the project's Godot 4.7 executable:

```text
godot --headless --path <project> --editor --import
godot --headless --path <project> --script res://tests/test_day_night_cycle.gd
godot --headless --path <project> --script res://tests/test_developer_console.gd
godot --headless --path <project> --script res://tests/test_city_preview_camera.gd
godot --path <project> --script res://tests/test_starscape.gd
godot --path <project> --script res://assets/sky/tools/render_starscape.gd
godot --path <project> --script res://assets/sky/render_sky_previews.gd
```

The last command uses the real renderer to save eight sky and city views in
`artifacts/sky/`. It requires a working graphics device; headless dummy rendering
cannot validate the shader visually. Automated tests cover clock wrap, pause,
lighting ownership, celestial rotation, scene integration and console validation.
For manual testing, watch one accelerated full cycle, look toward both horizons,
check moonlit street/roof readability, and verify pause/resume during traversal.

Initial day/night validation on 2026-09-10 with Godot 4.7.2:

* Editor import completed with no remaining GDScript parse errors.
* Day/night suite: zero failures. Existing developer console and city preview
  camera regression suites: PASS.
* Eight D3D12 / Forward+ renders were produced on the RTX 4090. Inspected the
  daytime, dawn, sunset, Milky Way, moon and street-level night views. No shader
  compilation errors. This is render inspection, not a manual traversal playtest.
* Sandbox runs emitted certificate/settings/shader-cache access diagnostics;
  the console suite also intentionally exercises a failed save. These did not
  prevent the tests or renders from completing.

Modified existing files: `scenes/main.tscn`, `scenes/super_city.tscn`, and
`scripts/ui-scripts/developer_commands.gd`. Added `scripts/day_night_cycle.gd`,
`tests/test_day_night_cycle.gd`, this sky asset directory (shader, textures,
import settings, preview script and documentation), Godot UID sidecars, and
generated previews under `artifacts/sky/`. The pre-existing audio-bus edit was
left untouched.

Cubemap replacement on 2026-09-11: updated `scripts/day_night_cycle.gd` and
`hero_sky.gdshader`, added the two custom cube resources, authoring/packing and
inspection tools, and `tests/test_starscape.gd`. Removed the retired panorama EXRs,
their import settings and generated import-cache files. GPU inspection covers both
poles, all twelve cube edges, and the old pinch direction through the real game
shader. Preview captures are in `artifacts/starscape/`; whole-city day, dusk, night
and dawn captures are refreshed in `artifacts/sky/`.

Final validation after removing the panoramas: editor import completed without
GDScript parse errors; the day/night suite reported zero failures. The GPU cubemap
test passed format, resolution, mipmap and edge-continuity checks (maximum galaxy
edge difference: 0.00818 in linear RGB). Both poles, representative cube edges,
the former pinch direction and the city midnight capture were visually inspected.
No frame-rate benchmark or manual traversal playtest was performed.
