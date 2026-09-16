# Commercial 03–20: Blender batch rework

All 18 assets were authored in Blender 5.2.1. Original imported geometry remains
in a hidden comparison collection in each scene of `blender/commercial_03_20.blend`.
The existing scene paths, doors, footprints, tier heights, offsets and chamfered
corners are retained. Nameplates and placeholder mechanical boxes are removed.
Hidden tier caps and undersides are omitted; separate thin trim strips are
absorbed into the wall surfaces to meet the triangle budget.

Eight buildings use the unchanged 48-triangle stock hospital HVAC. Ten use a
22-triangle Blender variant of that actual mesh: same body, lid and materials,
with hidden caps removed and the two raised top panels flattened onto the lid.
The original shared HVAC and hospital assets are unchanged. Every complete asset
is strictly below 110 triangles at full detail, including equipment instances.

| Building | Building triangles | HVAC | Complete / verified GLB |
| --- | ---: | ---: | ---: |
| 03 | 54 | 48 | **102** |
| 04 | 70 | 22 | **92** |
| 05 | 46 | 48 | **94** |
| 06 | 54 | 48 | **102** |
| 07 | 54 | 48 | **102** |
| 08 | 86 | 22 | **108** |
| 09 | 54 | 48 | **102** |
| 10 | 86 | 22 | **108** |
| 11 | 70 | 22 | **92** |
| 12 | 64 | 22 | **86** |
| 13 | 54 | 48 | **102** |
| 14 | 86 | 22 | **108** |
| 15 | 54 | 48 | **102** |
| 16 | 54 | 48 | **102** |
| 17 | 86 | 22 | **108** |
| 18 | 86 | 22 | **108** |
| 19 | 68 | 22 | **90** |
| 20 | 70 | 22 | **92** |

## Emission and collision

Each asset has its own `textures/commercial_skyscraper_NN_emission.png` plus a
mipmapped `.res` copy used by its dedicated materials. Selected window interiors
light at night; frames, doors, lobby, roof and HVAC stay dark. The existing
`commercial_skyscraper_01.gd` supplies clock binding and per-instance materials.
The Blender materials also contain their emission map; set Emission Strength
from 0 to 2 for a native Blender night preview.

Separate box colliders follow each tier and the equipment. Chamfered tier
colliders conservatively cover the corner cutouts. All 308 city placements
inherit the new colliders; old full-height overrides are removed. Placement
transforms and base footprints are unchanged. City layout heights and the
pedestrian source-scene hash are updated; routes themselves are unchanged.

## Files changed or added

- `commercial_skyscraper_03.tscn` through `commercial_skyscraper_20.tscn`.
- Matching 18 `meshes/commercial_skyscraper_NN.res` resources.
- 18 emission PNGs and matching `.res` textures in `textures/`.
- Asset-specific facade materials in `materials/commercial_skyscraper_NN_*.tres`.
- `blender/commercial_03_20.blend`, with packed textures and one scene per asset.
- `tools/export_blender_batch.gd`, `blender_rework_batch.py`,
  `import_blender_batch.gd`, `render_blender_batch.gd`, generated Godot UIDs.
- `tools/generate_pack.gd`, `tools/validate_pack.gd`, `tools/validation_report.json`,
  `manifest.json`, `README.md`, and these notes.
- `assets/props/rooftop_hvac/rooftop_hvac_lowpoly.tscn` and `.res`.
- `scenes/super_city.tscn`, `assets/super-city/layout.json`,
  `assets/super-city/pedestrians/network.json` (source hash only).
- `tests/test_commercial_blender_batch.gd` and its Godot UID.
- `artifacts/commercial_batch/`: original snapshot, exported GLBs, mesh transfer,
  triangle audit, test logs and day/night contact sheets.
- Refreshed `Asset Dashboard.html` and generated dashboard data/reports.

## Checks

The Godot importer loads each actual Blender-exported GLB and counts all meshes,
then compares that total with the final Godot resources. All 18 agree. The full
20-building validator passes (materials, winding, nondegenerate triangles,
collider coverage and budgets). The batch test passes for doors/nameplates,
18 emission masks, real noon/midnight transitions, rooftop collision and all 308
city placements. The existing pedestrian-network test also passes.

Godot-rendered day and night contact sheets were inspected. These are asset
previews, not manual gameplay verification. Engine runs report existing Windows
certificate/settings and road UID fallback warnings outside this work.

In Godot, inspect a few entrances, fly onto stepped roofs and AC tops, and switch
the clock between noon and midnight. Check for floating landings and confirm
that only window interiors illuminate.

## Rebuild

The preserved original input is `artifacts/commercial_batch/source.json`.
Run Blender with `--background --python` and `tools/blender_rework_batch.py`.
Then run Godot headless with `tools/import_blender_batch.gd`. That importer stages
scene/mesh replacements in `artifacts/commercial_batch/staged/` so existing loaded
Windows files can be replaced after the engine exits. Copy `.res` files to the
commercial `meshes/` folder, and `.tscn` files plus `manifest.json` to the commercial
folder. Materials and emission resources are saved directly. For individual edits,
use the appropriate scene in the saved Blender file.
