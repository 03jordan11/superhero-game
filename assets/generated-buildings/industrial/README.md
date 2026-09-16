# Industrial buildings

All ten industrial models were edited in Blender. Their existing scene paths update 113 city placements. Nameplates are removed; personnel doors and loading shutters remain. Editable source: `blender/industrial_01_10.blend`.

## Lighting and smoke

Each model has facade emission maps preserving window frames and warm detail. The foundry (03) originally had no windows; its private `foundry_windows` texture adds a narrow painted clerestory without adding geometry.

`industrial_building.gd` uses the commercial controller and CityWindows cache. Six seeded variants remove 70-80% of previously lit windows (75.45% measured), leaving industrial buildings darker than residential. Existing dark pixels stay dark. Individual windows are switched off, with subtle attenuation on retained windows. Industrial patterns permit adjacent dark windows to reach this sparse occupancy. No additional window lights are used.

Tune **Remote > CityWindows > Industrial Windows Off** (default 0.75). Patterns are reconstructed from the saved game seed and remain stable across day/night transitions. See [seeded windows](../../../docs/seeded_city_windows.md).

Models 03, 07 and 09 instance the shared `res://assets/effects/stack_smoke/stack_smoke.tscn` at their stack outlets. Each uses 18 soft GPU particles; at most 12 emitters run within 350 m of the camera. Smoke has no collision, lights or shadows. See the effect's README for tuning.

## Solid collision

The ten models contain 43 solid collision shapes. Main walls use boxes; pitched and sawtooth roofs, tapered stacks and silos use closed convex volumes. Roof collision follows each section instead of filling the entire building bounds. Small trim is covered within a 0.25 m tolerance. Buildings have no enterable interiors.

Existing `StaticBody3D`, `MeshInstance3D` and primary `CollisionShape3D` paths are preserved. Additional solids are named `SolidCollision1`, etc. Shapes use layer 1. Collision objects are also included in the Blender source for inspection.

## Geometry audit

Actual GLB and native Godot triangle counts match. Non-rendered collision is excluded.

| Model | Design | Building triangles | Solid shapes | Maximum smoke triangles |
| --- | --- | ---: | ---: | ---: |
| 01 | Freight warehouse | 54 | 3 | 0 |
| 02 | Sawtooth workshop | 44 | 5 | 0 |
| 03 | Foundry | 74 | 4 | 36 |
| 04 | Cold storage | 64 | 4 | 0 |
| 05 | Twin-gable depot | 52 | 3 | 0 |
| 06 | Textile mill | 60 | 2 | 0 |
| 07 | Boiler house | 126 | 5 | 36 |
| 08 | Silo mill | 222 | 10 | 0 |
| 09 | Utility plant | 56 | 4 | 36 |
| 10 | Repair works | 40 | 3 | 0 |

## Build and validation

`tools/export_blender_batch.gd` extracts source data for `tools/blender_rework_batch.py`. Blender exports GLBs and solid-shape data into `artifacts/industrial_batch`. `tools/import_blender_batch.gd` writes native Godot resources, staging replacement scenes and meshes under that artifact directory. Apply staged resources only after the importing Godot process exits. The older `generate_pack.gd` describes the original assets and does not preserve this rework.

Godot 4.7.2 validation passed for all ten scenes. `tests/test_industrial_rework.gd` checks exported geometry, solid interior overlaps, upward wall movement, roof landings, visible-vertex coverage, emission targets, seed restoration and smoke limits. Commercial seeded-window, residential wall-collision and save/load regression tests passed. Existing certificate/settings/road UID warnings remain.

Day and night contact sheets were rendered in Godot and inspected. Traversal gameplay was not visually tested. Day previews are in `previews/`; night previews and test logs are in `artifacts/industrial_batch/` at the project root.

## Test in the game

1. Restart the running scene so existing placements reload their resources.
2. Run up warehouse walls and land on pitched and sawtooth roofs. Walk around silos and stacks with visible collision shapes enabled; check for gaps or floating landings.
3. Enter `time night`, then `time pause`; inspect sparse warm windows and smoke on models 03, 07 and 09. Move beyond 350 m to check smoke distance culling.
4. Save, change the City Seed, then load. The saved window pattern should return.

## Modified files

- This pack's ten scenes, meshes, manifest, facade materials and emission textures.
- `blender/industrial_01_10.blend`, batch tools, preview tools and validation report.
- `industrial_building.gd` and the project script `scripts/city_window_lighting.gd`.
- Shared `assets/effects/stack_smoke/` scene and script.
- `tests/test_industrial_rework.gd` and `docs/seeded_city_windows.md`.

Commercial/residential asset resources and the sky, fog and environment settings were checked against their pre-edit hashes and remain unchanged.
