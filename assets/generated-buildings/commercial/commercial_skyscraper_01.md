# commercial_skyscraper_01

Revised asset: no tenant plaque or painted ground-floor windows. The paired
front/rear entrance doors remain. Subtle stone joints replace the lobby glass;
the upper limestone facade keeps its original window texture. No window geometry
was added.

The old roof tiers are removed. A flat roof at Y=132 m supports the actual
48-triangle rooftop mechanical unit extracted from the hospital, now reusable as
`res://assets/props/rooftop_hvac/rooftop_hvac.tscn`. Its hospital source geometry
and materials are retained. The original hospital is unchanged.

| Rendered geometry | Triangles |
| --- | ---: |
| Building including doors | 48 |
| HVAC instance | 48 |
| Complete asset | **96** |
| Previous complete asset | 108 |

The reduction is 12 triangles (11.1%). Footprint stays 22 × 20.04 m, including
the door projection. Height is now 134.8 m including HVAC. Separate simple box
colliders follow the podium, tower and equipment, so landing on the roof works.
All 28 existing city instances inherit the revision; obsolete tall collision
overrides were removed. Placement, pedestrian points and edges are unchanged.

The dedicated 64 × 64 emission mask lights selected upper-story glass only.
Stone, mullions, doors and equipment stay dark. `commercial_skyscraper_01.gd`
uses the existing DayNightCycle signal, including buildings loaded after dark.
It duplicates the emission material per instance, not the mesh. Inspector
controls expose emission strength, clock following and standalone night amount.

## Files

- `commercial_skyscraper_01.tscn`, `.gd`, `meshes/commercial_skyscraper_01.res`.
- `materials/commercial_skyscraper_01_facade.tres` and `_podium.tres`.
- `textures/commercial_skyscraper_01_emission.png`, `_emission.res`, `_podium_albedo.res`.
- `assets/props/rooftop_hvac/rooftop_hvac.tscn` and `.res`.
- Commercial `manifest.json`, `README.md`, and builder helpers.
- `scenes/super_city.tscn`, `assets/super-city/layout.json`, and the pedestrian
  network's source-scene hash (route data unchanged).
- `tests/test_commercial_skyscraper_01.gd`.
- Refreshed `Asset Dashboard.html` and its snapshot/validation data.

Rebuild only this asset with Godot's headless `--script` option and
`res://assets/generated-buildings/commercial/tools/revise_skyscraper_01.gd`.
The original pack generator preserves this revision and its metadata.

## Verification

`tests/test_commercial_skyscraper_01.gd` checks complete triangle counts, the
blank podium, removal of plaque geometry, mask pixels and multiplication mode,
real clock transitions, independent materials, spawning after dark, all 28 city
instances and physics rays landing on the roof/HVAC. The existing pedestrian
network test also passes. Actual Godot renderer captures of the entrance, roof,
day and night are in `artifacts/skyscraper_01/`.
The project-wide headless editor import completed without GDScript parse errors,
but reported road UID fallbacks and MultiMesh editor errors outside this asset,
as well as local certificate/user-directory warnings. The focused building and
route checks passed, and the real renderer produced the inspected captures.

In Godot, inspect the base and roof, land on the roof beside the HVAC, then switch
the Main scene clock between noon and midnight: selected windows should illuminate
only at night. These automated checks and renders do not replace a manual traversal
playtest.
