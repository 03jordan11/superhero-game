# One-building emission review

> This is the preserved historical 12% trial. Production now uses the approved
> [seeded window system](../../../../docs/seeded_city_windows.md).
> The scene explicitly opts out so its original/trial comparison stays intact.

Open `scenes/tests/window_emission_trial.tscn` in Godot and press **F6**.
Press **1** for the restored original, **2** for the trial. Drag to orbit;
use the wheel to zoom. Inspect the main facade from each side. The upper tier
is unchanged. This scene contains one commercial_skyscraper_02; the city uses
the original materials on all 20 commercial asset types.

## Controlled change

The original 64×64 texture has distinct windows, but its four-floor pattern
repeats up the tower. The trial copies those exact pixels into a 512×512 atlas,
allowing independent edits over the main facade's 11 bays and 26 floors.
It switches off 21 of 175 originally lit cells (12%). Most edits are individual
windows, with occasional horizontal pairs and no newly adjacent vertical edits.
Another 59 cells use 88–97% of their original pixel brightness. Original dark
pixels stay dark; retained windows preserve their shapes and warm RGB ratios.
Opposite facade faces retain the original shared mapping in this limited test.

The review mesh adds a second UV channel for emission only. Geometry, first UV
channel, albedo, native StandardMaterial3D rendering, and emission energy stay
unchanged. The complete building remains 104 rendered triangles. No procedural
window shader, frame-dependent variation, or additional lights are used.

The current sky, fog, bloom, ambient lighting, and street lighting files are
unchanged. Both comparison modes use the same current day/night controller,
stopped at midnight. This is an isolated asset review, not a city rollout.

## Files changed for this request

- `assets/generated-buildings/commercial/commercial_skyscraper_01.gd`: restored
  the original shared emission controller for all 20 commercial buildings.
- `assets/generated-buildings/commercial/window_trial/`: added this guide,
  `review.gd`, trial PNG and native texture/material/mesh resources.
- `scenes/tests/window_emission_trial.tscn`: added the one-building review.
- `assets/generated-buildings/commercial/tools/build_window_trial.gd` and
  `render_window_trial.gd`: added reproducible build and comparison capture.
- `tests/test_commercial_skyscraper_01.gd`, `test_commercial_skyscraper_02.gd`,
  `test_commercial_blender_batch.gd`, and `test_urban_night.gd`: restored original
  emission expectations while retaining environment and street-light checks.
- `tests/test_window_emission_trial.gd`: added pixel, UV mapping, geometry,
  isolation, and original-material checks.
- `docs/urban_night_lighting.md`: marked the previous window rollout reverted.
- `artifacts/window_trial/`: audit, unchanged-file hashes, logs, and rendered
  original/trial comparison.

## Validation

All five targeted Godot checks above passed under Godot 4.7.2. The original and
trial were rendered in Forward+ and the comparison inspected. Gameplay was not
visually tested. Existing root-certificate/settings and road-resource UID
warnings remain; no script parse errors or failed assertions occurred in the
final runs.
