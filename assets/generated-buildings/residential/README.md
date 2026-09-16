# Residential buildings — Blender rework

All 20 models are updated at their existing scene paths, covering 1,551 residential
placements in the current city.

## Changes

- Removed balconies on 10, 12 and 14 and nameplates on every model.
- Removed old roof utility blocks, chimneys and baked water tanks. Model 02's
  pitched roofs are now flat. Other architectural tiers, doors and stoops remain.
- Every model instances the shared hospital AC prop, scaled to fit its rooftop.
- Models 04, 09 and 16 also instance the same shared water-tower scene.
- Solid BoxShape3D colliders cover each main building section and stepped tier.
  Courtyards stay open, and removed balconies leave no invisible obstacles.
  Stoops and the entry canopy have separate simple boxes. Hollow mesh collision
  was reverted after it caused wall-run pass-through.

## Seeded night lighting

Each facade style has an emission PNG and native RES texture matching its window
shapes. Frames, mullions and painted sills remain dark. CityWindows expands the
texture over the full facade and creates six shared variants from the saved seed.

Residential removes an extra **20 percentage points** of originally lit windows:
50–70%, averaging about 60%, versus commercial's 30–50%, averaging 40%. The audit
measured 60.17% with whole-window rounding. This typically leaves about 23% of all
window cells illuminated. Warm colors and subtle brightness variation are preserved.

Tune `Residential Extra Windows Off` (default 0.20) on **Remote → CityWindows**.
Commercial patterns remain unchanged. Patterns stay stable through day/night
cycles and save/load; emission switches off during daylight.

## Shared assets and Blender source

- AC: `assets/props/rooftop_hvac/rooftop_hvac_lowpoly.tscn`, 22 triangles.
- Water tower: `assets/props/rooftop_water_tower/rooftop_water_tower.tscn`, 64 triangles.
- Editable pack: `blender/residential_01_20.blend`, one scene per model with hidden
  originals and separate rooftop objects.
- Editable standalone tower: `assets/props/rooftop_water_tower/rooftop_water_tower.blend`.

The current pipeline uses `tools/export_blender_batch.gd`, Blender background mode
with `tools/blender_rework_batch.py`, then `tools/import_blender_batch.gd`.
Import stages replacement scenes/meshes in `artifacts/residential_batch/staged`;
copy them into the existing asset paths after Godot exits. Baseline snapshots and
independently checked GLBs are in `artifacts/residential_batch`.

`generate_pack.gd` and `building_builder.gd` describe the historical assets; do not
rerun that original generator over the rework.

## Geometry audit

Complete models range from **60 to 232 rendered triangles**, including every AC
and water-tower instance. Counts match actual Blender GLB exports and final Godot
resources. All are below the 10,000-triangle complete-POI limit. The three-house
row is largest because it retains the individual stoops and doors.

The former balcony models now total 60 / 60 / 80 triangles (10 / 12 / 14).
Per-model counts are in `manifest.json` and `artifacts/residential_batch/triangle_audit.json`.

## Validation and Godot checks

Passed under Godot 4.7.2: pack validation, residential geometry/emission/collision
checks, commercial seeded-window regression, and full save/load integration.
Day/night contact sheets were rendered and inspected. Traversal gameplay was not
visually tested. Existing certificate/settings and road UID warnings remain; the
save test intentionally exercises one failed write using a temporary path.

In Godot, inspect 10/12/14 for flush walls and clear space. Land on roofs and AC
units, and check 04/09/16 for separate water towers. Enter `time night` and
`time pause` in the developer console to inspect sparse warm windows. Save/load
must restore the same pattern; `time day` switches emission off.

## Files changed

- All 20 residential scenes and meshes at their existing paths.
- New per-building/per-style emission PNG/RES textures and facade materials.
- `residential_building.gd`, using the existing shared clock/seed controller.
- `scripts/city_window_lighting.gd`, adding the residential-only removal offset.
- Shared water-tower blend, scene, mesh, material and README under `assets/props`.
- Blender export/edit/import tools, editable pack, render tools, validator,
  manifest, previews, this README and `docs/seeded_city_windows.md`.
- `tests/test_residential_rework.gd` and audit/render artifacts.

Commercial authored assets, sky, environment, fog, bloom and street lighting
remain unchanged, verified against hashes captured before this work.

## Wall-run collision correction

All 20 scenes use solid building volumes again (40 main sections total).
`tools/residential_collision.gd` defines the boxes and preserves the baked origin
shift. Both `tools/fix_collision.gd` and the Blender import pipeline use it.
No visible meshes, emissions or props changed in this correction.

`tests/test_residential_wall_collision.gd` checks upward capsule motion using the
actual movement motor at 12 and 120 m/s, fast wall approaches, and solid interior
overlap. Existing residential geometry, rooftop and balcony-clearance checks pass.
Restart the running scene and repeat the wall run that previously went through
the building. Also check transitions past setbacks and rooftop edges. Gameplay
was not visually verified.
