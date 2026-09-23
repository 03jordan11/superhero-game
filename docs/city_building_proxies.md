# City-wide 500 m building proxies

Main now uses `SuperCity/CityBuildingChunks`: **24 occupied 500 x 500 m cells covering all 1,955 ordinary generated buildings**. The grid covers both sides of the river and all city districts. All **16 POI roots** are explicitly excluded, including City Hall, the gas station, police station and parking garages. Streetlights, other street props, roads and population systems are outside this change.

Each cell has one runtime `DistantProxy` MeshInstance3D with one mesh surface and one shared material. Proxies use simple textured building bodies and tower tiers; the original rendering triangles are not merged into them. Source visuals are hidden while their proxy is active, then restored when approaching. Physics/collision and source gameplay objects remain loaded. POI visuals and collisions are never switched by this controller.

Static geometry inventory across all ordinary buildings: 153,786 original triangles versus 41,950 proxy triangles, and 8,727 source surfaces versus 24 proxy surfaces. These are asset counts, not measured frame draw calls or FPS. **No FPS benchmark was run for this city-wide change, at the user's request.**

## Switching and tuning

The grid is aligned to multiples of 500 m in city X/Z coordinates. Whole buildings belong to the cell containing their authored visible-bounds centre, so no building is split or assigned twice. Sparse/edge cells contain only existing buildings.

The near-detail clearance is now **100 m**, reduced from 300 m, with the existing 25 m switching margin. A chunk switches to its proxy when camera distance from its actual bounds centre exceeds `100 + bounds radius + 25` metres. It returns to original visuals at `100 + radius`. Current entry thresholds range from approximately **355 to 476 m**, depending on the occupied bounds; distance includes flight altitude. This brings every transition 200 m closer while retaining the 500 m cells. There is no fade; silhouette, roof and window changes may be more noticeable at the closer transition.

Select `SuperCity/CityBuildingChunks` to adjust `Enabled`, `Near Distance M` and `Switching Margin M`. Toggle `Enabled` in the Remote Inspector for a fixed-camera original/proxy comparison. The old `CorridorBuildingChunks` instance was replaced, so two proxy systems do not run over the same buildings.

The loading screen waits for staged proxy preparation. Its progress denominator now uses the actual number of chunks, rather than the old fixed count of 14.

## Validation and user check

Passed Godot headless checks:

- `tests/test_city_chunks.gd`: all 1,955 ordinary buildings assigned exactly once; 24 cells with 500 m dimensions; resolved paths/bounds; all 16 POIs excluded; no old controller in Main.
- `tests/test_corridor_hlod.gd` (now validates the active city grid): one mesh/surface per chunk, fewer than half the original triangles in every chunk, source hiding/restoration, distance hysteresis, bounds, collision, loading completion, lighting updates and seed/material rebinding.
- `tests/test_loading_screen.gd`: loading behavior passes, including the intentional missing-destination error case.

A graphical correctness run produced and inspected day/night screenshots under `artifacts/city_proxies_500/`, with all 24 proxies successfully prepared and the controller enabled. No FPS measurement was performed. Manual traversal is still for the user to check. The environment emitted existing certificate/user-settings/shader-cache warnings; there were no script or shader errors in the successful proxy runs.

Restart the game, Start/Load, and revisit the same long corridor to measure FPS. Fly toward/away from buildings on both riverbanks and check for missing/doubled geometry or distracting transitions. Confirm POIs and collisions remain normal. Enter/exit a building once to check loading completion.

## Files

- `assets/super-city/tools/build_city_chunks.gd`: offline 500 m city-grid generator with explicit POI exclusion.
- `assets/super-city/chunks/city_chunks.tscn` and `city_chunks.json`: grid scene and reviewable membership manifest.
- `scenes/main.tscn`: replaces the old corridor instance with the city-wide instance; original building placements unchanged.
- `scripts/corridor_hlod.gd`: existing proxy controller, now exposes actual chunk count for loading progress.
- `scripts/ui-scripts/loading_screen.gd`: dynamic preparation progress denominator.
- `scripts/city_hlod_materials.gd`: city-wide description; shared proxy material behavior retained.
- `tests/test_city_chunks.gd`: city coverage/exclusion validation.
- `tests/test_corridor_hlod.gd`: updated to validate the active city grid.
- `tests/test_corridor_chunks.gd`: historical corridor fixture is mounted explicitly for its independent test.
- `benchmarks/corridor_hlod.gd`: points to the new controller/output location for any future requested benchmark; not run for this change.
- `docs/corridor_building_chunks.md`: marked as historical; this document describes the current system.

After moving buildings, run Godot with `--headless --path . --script assets/super-city/tools/build_city_chunks.gd`, then the city membership and proxy tests. In PowerShell pipe the executable to `Out-Host` and use a writable `--log-file`. Runtime proxy geometry is rebuilt from source assets after scene initialization.
