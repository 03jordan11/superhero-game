# Outdoor benches and riverbank railings

## Result

Removed 119 outdoor benches and their collision bodies from Main: 83 CityLife benches, six prison yard benches, four Central Park benches, 18 City Hall benches, and two each at Bank1, Bank2, Firehouse and PoliceStation. Together these used 380 MeshInstance3D nodes. Reusable bench assets remain available for future placement. Interior workbenches and gym equipment were not part of this outdoor prop removal.

Replaced 124 riverbank railing runs (124 bars and 374 posts, 498 mesh nodes, 5,976 triangles) with one MeshInstance3D, one material surface and 496 triangles. Each run uses a vertical textured card plus a thin horizontal top strip. The alpha-cutout texture supplies the open gaps and posts; both sides render. Shadows are disabled. The original railings had no collision, so no invisible collision panels were added. Quay walls and their collisions are preserved.

**The old riverbank railings were already hidden in Main by inherited QuayWall visibility overrides.** The replacement remains hidden there. This is a stored-geometry reduction, not an active draw-call saving in the current Main scene. It is visible in the standalone waterfront scene. The updated scenery audit distinguishes stored geometry from scene-tree-visible geometry; neither count is a camera-specific draw-call measurement.

The six affected landmark proxies and the prison island proxy were rebaked without benches. No FPS benchmark was performed.

## Files changed in this pass

- Placement scenes: `scenes/city_life.tscn`, `scenes/central_park.tscn`, `scenes/waterfront.tscn`, `scenes/super_city.tscn`.
- POI scenes: `assets/buildings/{bank1,bank2,city_hall,firehouse,police_station}/{name}.tscn`.
- Placement metadata: `assets/city-life/placements.json`.
- Generators: `assets/city-life/tools/generate_city_life.gd`, `assets/central-park/tools/generate_park.gd`, `assets/waterfront/tools/generate_waterfront.gd`, and `assets/buildings/{bank1,bank2,city_hall,firehouse,police_station}/tools/prepare_{name}.gd`. These no longer place outdoor benches. The old CityLife furniture shuffle remains only to preserve subsequent procedural RNG results.
- Helpers accepting absent prop categories: `assets/city-life/tools/render_city_life.gd`, `assets/super-city/tools/integrate_pois.gd`.
- New railing builder: `assets/waterfront/tools/riverbank_railings.gd`.
- New railing assets: `assets/waterfront/railings/{riverbank_railings.res,railing_material.tres,railing.png,README.md}`.
- Proxy baker: `assets/super-city/tools/bake_landmark_proxies.gd` now accepts optional source paths after `--`, preserving unselected inventory entries. Its regional subclass supports the same option.
- Rebuilt assets and inventories: `assets/super-city/landmark_proxies/` for Bank1, Bank2, CityHall, Firehouse, PoliceStation and Landmarks/CentralPark; `assets/super-city/regional_proxies/` for Waterfront/PrisonIsland.
- Audit: `assets/super-city/tools/audit_scenery.gd` and `assets/super-city/regional_proxies/scenery_audit.json`.
- Tests: `tests/test_benches_railings.gd`, `tests/test_city_life.gd`, `tests/test_city_hall.gd`, `tests/test_banks.gd`, `tests/test_firehouse.gd`, `tests/test_police_station.gd`.

## Validation and manual checks

Godot 4.7.2 parse checks passed for all 13 changed authoring scripts. Bench/railing, CityLife, City Hall, bank, firehouse, police station, landmark proxy, regional proxy and forest chunk tests passed. POI tests now expect building-only triangle counts and footprints where removed benches previously extended the bounds. Existing root-certificate/settings warnings remain unrelated. The forest test deliberately checks the stale-bake fallback and emits its expected warning.

Standalone waterfront renders were inspected from the front, back and above. This was an automated visual check, not a Main traversal playtest. Comparison screenshots and logs are in `artifacts/benches_railings/`.

1. Restart Main. Check the sidewalks, Central Park, City Hall and prison yard: outdoor benches should be gone.
2. Walk through former bench positions to confirm no leftover bench collisions. Approach and leave those POIs to check their distant proxies also have no benches.
3. To inspect the replacement rail, open `scenes/waterfront.tscn`, select `Riverbanks/RiverbankRailings`, and frame it in the 3D editor. Check its open gaps from both sides and its handrail from above. Main intentionally retains its previously hidden state.

