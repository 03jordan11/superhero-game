# Seeded city windows

Industrial models 01–10 also use this system. **Industrial Windows Off** defaults
to 0.75, with six variants spanning 70–80% fewer previously lit windows (75.45%
measured). Their individual-window masks allow adjacent dark groups to reach this
sparser occupancy; original lit shapes and warm color ratios remain intact. The
commercial/residential restriction on long dark groups is unchanged. Industrial
maps use the same saved seed and cache, with no per-frame texture generation.
See the [industrial asset guide](../assets/generated-buildings/industrial/README.md).

Residential models 01–20 also use this system. `Residential Extra Windows Off`
adds 0.20 to their removal rate, giving six variants from 50–70% (about 60% fewer
previously lit windows). Commercial patterns retain their existing seeds and
30–50% rates. See the [residential asset guide](../assets/generated-buildings/residential/README.md).

Commercial skyscrapers 01–20 now use six emission variants per asset, generated
from the current game's city seed. They switch off 30%, 34%, 38%, 42%, 46%, or 50%
of the **previously lit** windows, averaging about 40% across the variants. Existing
dark windows remain dark. Minor rounding applies to small upper tiers.

## Appearance

The original 64×64 emission artwork is copied over each facade's complete UV
extent, then selected individual window cells are darkened. Occasional horizontal
pairs remain; the generator prevents new three-cell dark runs and 2×2 patches.
It never creates lit rectangles or overwrites the original window silhouettes.
About 35% of retained windows receive subtle brightness attenuation (88–100%).
The original warm color ratios, emission strength, albedo, and frames are retained.

Each asset's native mesh is shared, with an added UV2 channel for emission only.
Geometry and collisions are unchanged. Opposite faces retain their original shared
mapping; different placements select among six variants using their asset path,
world position and city seed. This breaks the four-floor repetition of occupancy
edits while preserving the original authored pattern underneath.

## New game and saves

- **Play** in the main menu starts a new lighting seed before loading the city.
- Manual saves include `world.window_lighting.seed` and `pattern_version` (1).
- Loading restores the seed and rebuilds any live tower patterns from it.
- On startup, an existing save's seed is read before the city loads. This does
  not load player progression; the existing manual Load command still does that.
- Older saves without a lighting seed consistently use 8421.
- `SaveManager.begin_new_game(123456)` can start a reproducible test game.
- Nothing writes or deletes the user's save merely to choose a new seed.

Maps are generated once when a particular asset/variant is first needed, cached
and shared by placements. They do not flicker or regenerate as the camera moves
or the clock changes. Only the seed is saved; the textures are reconstructed.
No window lights or new shaders are used. The fully populated six-variant native
texture set measured 34.23 MiB of image data (GPU allocation can differ).

## Tuning

During play, select **Remote → CityWindows** in the Scene tree. These exported
controls rebuild patterns immediately when edited. Edit script defaults to keep
tuning across runs; these development controls are not saved as player settings.

| Control | Default | Meaning |
| --- | --- | --- |
| Additional Windows Off | 0.40 | Fraction removed from originally lit windows |
| Industrial Windows Off | 0.75 | Industrial removal rate; variation is capped at ±0.05 |
| Building Variation | 0.10 | Spread around that fraction, giving 30–50% |
| Variants Per Asset | 6 | Shared variants per asset; more uses more texture memory |
| Minimum Window Brightness | 0.88 | Minimum multiplier for subtly dimmed windows |
| City Seed | Current game's seed | Reproducible pattern and placement selection |

Very high removal settings may be limited by the rule against long dark groups.
Set a building's `seeded_window_patterns` to false before it enters the tree to
keep original emission, as the historical one-building review scene does.
The old DayNightCycle window occupancy controls remain inactive. Its sky,
environment, fog and bloom settings, and all street lighting are unchanged.

## Verify in Godot

1. Press Play, open the developer console, and enter `time night`, then `time pause`.
2. View the downtown towers close up and from a rooftop. Check the reduced number
   of lit windows, preserved frames/colors, and variation between repeated models.
3. Enter `save`. Note a tower's pattern, then change CityWindows' City Seed in the
   Remote Inspector. Enter `load`; its original saved pattern should return exactly.
4. Switch to `time day`, then `time night`. Occupancy should stay identical.
5. Starting again through the main menu's Play chooses a new pattern seed.

## Validation and changed files

Godot 4.7.2 checks cover all 20 meshes, every surface and six variants, full image
pixel/hue preservation, target occupancy, prohibited patches, cache sharing,
placement variation, seed reproducibility and save/load restoration of live towers.
The audited reduction was 40.05%. Existing building geometry/collision, night-light,
save progression, and historical review checks also pass. Original and seeded
real-city skyline/office views were rendered in Forward+ and inspected; traversal
gameplay was not visually tested. Existing certificate, settings and road UID
warnings remain. The save-failure test intentionally logs one failed write.

- `scripts/city_window_lighting.gd`: new seeded native texture/UV cache and tuning.
- `project.godot`: registers CityWindows before SaveManager.
- `scripts/save_manager.gd`: seed creation, startup restore and save/load field.
- `scripts/ui-scripts/main_menu.gd`: starts a fresh seed on Play.
- `assets/generated-buildings/commercial/commercial_skyscraper_01.gd`: shared
  controller applies seeded textures to all 20 commercial types.
- `scenes/tests/window_emission_trial.tscn` and its builder: opt the old trial out.
- `tests/test_seeded_city_windows.gd`: new seeded asset and texture audit.
- `tests/test_power_token_saves.gd`: adds seed persistence and live restoration tests.
- `tests/test_urban_night.gd`, `tests/test_window_emission_trial.gd`: current behavior.
- `assets/sky/tools/render_seeded_windows.gd`: reproducible city comparison renderer.
- This guide, `docs/urban_night_lighting.md`, and the old trial README: current status.
- `artifacts/seeded_windows/`: original/seeded screenshots and validation summary.

All authored commercial textures/materials/meshes and the sky/environment/street
files were checked against the existing hash ledger and remain byte-identical.
