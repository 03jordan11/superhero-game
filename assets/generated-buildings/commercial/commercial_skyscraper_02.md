# commercial_skyscraper_02 revision

The projecting 32 x 23 m lower section is removed. The lobby and dark-glass
tower now share a 30 x 21 m footprint. The PORTMAN GROUP plaque is removed;
the original paired doors remain on the front (-Z) and rear (+Z), moved inward
to the new walls. The smaller upper tier at Y=104–110 m is retained.

The topmost plain mechanical box is replaced with the existing stock hospital
unit, instanced from `assets/props/rooftop_hvac/rooftop_hvac.tscn` at Y=110 m.
The shared HVAC mesh and hospital are unchanged. Total height is about 112.8 m.

| Actual rendered geometry at full detail | Triangles |
| --- | ---: |
| Building, doors and exposed terraces | 56 |
| Stock HVAC, one placed instance | 48 |
| Complete revised asset | **104** |
| Actual original mesh (local before snapshot) | **108** |

Four triangles are saved (3.7%). Hidden tier caps are omitted. The original
root, mesh and primary collision node names/IDs are preserved. Separate boxes
follow the main tower, upper tier and HVAC so terrace and roof landings match
visible elevations. All 15 city placements inherit the revision; their old
full-height collision overrides were removed. Placement transforms are unchanged.
Layout footprint/height entries and the pedestrian source-scene hash are updated.
Existing pedestrian routes remain valid because the building footprint shrinks.

## Night emission

`textures/commercial_skyscraper_02_emission.png` is the dedicated 64 x 64
window mask. Its mipmapped Godot texture is `_emission.res`, shared by the
asset's dedicated dark-glass and steel materials. Both use multiplication so
black pixels stay dark. The lobby, doors, trim, roof and HVAC do not emit.

`commercial_skyscraper_02.gd` reuses the existing asset 01 lighting script:
materials are independent per instance, windows follow DayNightCycle, and
buildings spawned after dark immediately use the clock's current lighting.
Inspector controls expose emission strength, standalone night amount and
whether to follow the scene clock.

Rebuild this asset with Godot's `--headless --path . --script
res://assets/generated-buildings/commercial/tools/revise_skyscraper_02.gd`.
This generates the mask, mesh, scene and manifest entry. The general pack
generator preserves both revised assets.

## Files changed or added

- `commercial_skyscraper_02.tscn`, `.gd`, `.md`, and `meshes/commercial_skyscraper_02.res`.
- `materials/commercial_skyscraper_02_dark_glass.tres` and `_steel.tres`.
- `textures/commercial_skyscraper_02_emission.png` and `_emission.res`.
- `tools/revise_skyscraper_02.gd`, `render_skyscraper_02.gd`, generated Godot UID/import files.
- Commercial `manifest.json`, `README.md`, `tools/generate_pack.gd`,
  `tools/validate_pack.gd` and its `validation_report.json`.
- `scenes/super_city.tscn`, `assets/super-city/layout.json`,
  `assets/super-city/pedestrians/network.json` (source hash only).
- `tests/test_commercial_skyscraper_02.gd` and its Godot UID file.
- `artifacts/skyscraper_02/`: before snapshot, validation logs and Godot renders.
- Refreshed `Asset Dashboard.html` and generated dashboard snapshot/report files.

## Verification and manual test

Godot 4.7.2 focused checks pass: actual before/after triangle counts, winding,
relocated door geometry, mask boundaries, clock transitions, after-dark spawning,
independent materials, 15 inherited city instances, terrace/roof/HVAC ray hits,
and no collision where the projecting podium used to be. The 20-building pack
validator and existing pedestrian-network test pass. The absent City Crafter
addon is explicitly skipped in the pack validator report.

The headless editor import completes with no GDScript parse errors. It reports
existing certificate/user-directory, road UID fallback and MultiMesh editor
messages outside this asset. Actual Godot Compatibility-renderer captures of
day, entrance, roof and night were inspected in `artifacts/skyscraper_02/`.
These are asset previews, not a manual gameplay traversal test.

In Godot, inspect the flush base and front door. Fly onto the terrace at 104 m,
roof at 110 m, and HVAC top at approximately 112.8 m; check for floating or
snagging. Set the Main scene clock to noon, then midnight: selected upper
windows should light only at night while the doors, roof and equipment stay dark.
