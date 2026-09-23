# Corridor distant proxies

> Historical corridor trial. Main now uses city-wide 500 m chunks with every POI excluded. See [city_building_proxies.md](city_building_proxies.md) for current behavior and validation. The measurements below describe the earlier 250 m corridor trial only.

The 14 existing 250 m corridor groups now use actual simplified stand-ins. Every chunk produces exactly **one MeshInstance3D, one ArrayMesh surface, and one shared ShaderMaterial**. The previous multi-surface merge has been replaced.

## Geometry and appearance

Each proxy is constructed from five new quads per structural box (four walls and a roof). Authored building-body and tower-tier collision boxes provide the shapes; source rendering triangles are not copied. Authored boxes are read before runtime collision consolidation so stepped towers keep their tiers. Major site bodies are retained, and open structures without suitable body boxes use an exterior envelope. Roads and gaps between buildings remain open. Small rooftop props, railings, steps and decorative geometry are omitted.

The proxy projects existing facade/roof textures onto these simple shapes and packs their material data into one texture-array shader. Vertex-painted roof colors are incorporated into the shared material data. This is a coarse representation, not a photographic bake of every sign, ornament or individual window. Transparent openings become opaque approximations. Day/night lighting, occupancy and brightness still update; seeded room data is retained, but simplified facade mapping may change individual window positions. Unknown shaders use a neutral fallback.

All original GeometryInstance3D descendants in a distant chunk are hidden, including details excluded by the old merge. Their prior visibility is restored when approaching or disabling proxies. Collision bodies, source scripts and gameplay objects remain loaded; this is rendering replacement, not scene streaming. City Hall remains excluded. No original building scene or collision asset was changed for this implementation.

## Scope and switching

The captured corridor looks east (+X) along Z = -480. The trial spans X = -1500 to the west riverbank at X = 100, with seven groups on each side. Left is north (Z = -730 to -480); right is south (Z = -480 to -230). The nominal final grid cell ends at X = 250, but members stop at X = 100. Whole buildings are assigned by their bounds centre. There are 386 member buildings/sites.

| Section | Left members | Right members |
| --- | ---: | ---: |
| 01 | 46 | 41 |
| 02 | 40 | 41 |
| 03 | 40 | 33 |
| 04 | 28 | 24 |
| 05 | 32 | 5 |
| 06 | 29 | 9 |
| 07 | 10 | 8 |

Select `SuperCity/CorridorBuildingChunks` in Main to tune `Enabled`, `Near Distance M` (300) and `Switching Margin M` (25). Entry is camera distance > 300 m + actual chunk bounds radius + 25 m; originals return at 300 m + radius. Full chunks enter around 480-510 m, smaller partial chunks around 420 m. Distance includes flight altitude. Hysteresis prevents rapid switching; there is no transparency crossfade. Runtime children are named `DistantProxy` under each group. Geometry is prepared once across frames under the existing loading screen, and rebuilt for changed material bindings/seeds.

## Validation and measurements

Godot 4.7.2, Forward+ D3D12, RTX 4090, 2560 x 1440. Same-camera pairs use the existing frozen diagnostic scene, shadows/bloom/VSync off and low population. These are controlled rendering measurements, not gameplay FPS guarantees.

- All 14 chunks have one mesh, one surface and one material binding.
- Full corridor geometry: **35,847 -> 7,260 triangles**, approximately 80% fewer.
- Source surface inventory: **1,678 -> 14**. Inventory is not the same as measured draws.
- Proxy preparation: about **318 ms** of work spread across loading frames in the graphical run.

| Comparison | Original draw calls | Proxy draw calls | Original median frame | Proxy median frame |
| --- | ---: | ---: | ---: | ---: |
| Whole city, street pair 1 | 4,271 | 4,217 | 8.297 ms | 7.837 ms |
| Whole city, street pair 2 | 4,271 | 4,217 | 7.839 ms | 7.742 ms |
| Whole city, night street | 4,280 | 4,226 | 8.030 ms | 7.901 ms |
| Whole city, flight | 5,404 | 5,319 | 9.722 ms | 9.552 ms |
| Corridor only, all proxies forced on | 290 | 13 | 1.285 ms | 0.940 ms |

The final row hides the rest of the city's geometry and forces every corridor chunk to its proxy, using the same flight camera. Thirteen chunks are rendered, producing thirteen draws. Original visibility cutoffs and occlusion remain active in the original comparison. It validates the proxy rendering cost; it does **not** claim a 95% reduction in total game rendering. With normal distance switching, eight chunks are distant at the recorded street camera. Whole-scene improvement remains modest.

Results and screenshots: `artifacts/corridor_proxies/`. The old merge's measurements remain separately in `artifacts/corridor_hlod/` for history. Do not compare FPS across separate runs as though all conditions were identical.

`tests/test_corridor_hlod.gd` passed: single-mesh/surface invariant, ten triangles per proxy box, reduction below half the source triangles in every chunk, bounds, switching/hysteresis, visibility restoration, unchanged collision, City Hall exclusion, POI geometry budgets, material/seed changes and loading completion. `tests/test_corridor_chunks.gd` passed with 14 groups, 386 unique members and zero failures. Graphical day/night and flight comparisons were run and inspected; roof-color differences found during review were corrected. Manual traversal was not performed. The environment reported unavailable user settings/shader-cache storage and certificate-store access, with no script/shader errors in the final runs.

## In-game check

1. Restart, then Start/Load and visit the same gas-station road corridor. Also enter and exit the gas station; loading should wait for proxy preparation.
2. Fly away from and return toward the corridor, including super speed. Check skyline/roof changes and ensure no whole buildings disappear or double at transitions.
3. Check at night and change window brightness/occupancy. Some small detail changes are expected from a simplified proxy.
4. Confirm collisions and City Hall remain normal.
5. For a fixed-camera comparison, toggle `Enabled` on `SuperCity/CorridorBuildingChunks` in Godot's Remote Inspector. Disabling immediately restores original visuals.

## Files changed for simplified proxies

- `scripts/city_chunk_hlod.gd`: replaces triangle merging with structural proxy generation and full source-visual switching.
- `scripts/city_hlod_materials.gd`: one material supporting facade/roof tints, generated-building windows and POI windows; caches proxy recipes.
- `assets/generated-buildings/commercial/materials/corridor_hlod.gdshader`: POI room lookup in the shared proxy shader.
- `scripts/corridor_hlod.gd`: controller description updated; existing staged preparation/switching retained.
- `assets/super-city/chunks/corridor_chunks.tscn` and `assets/super-city/tools/build_corridor_chunks.gd`: status metadata updated; membership unchanged.
- `tests/test_corridor_hlod.gd`: asserts real simplification and exactly one mesh/surface per chunk.
- `benchmarks/corridor_hlod.gd`: new output folder and isolated proxy draw verification, alongside the whole-scene comparisons.
- `docs/corridor_building_chunks.md`: these implementation, measurement and test notes.

Run Godot with `--headless --path . --script tests/test_corridor_hlod.gd` and `--headless --path . --script tests/test_corridor_chunks.gd`. Run the graphical benchmark with `--path . --script benchmarks/corridor_hlod.gd` (not headless). It pins the original `city_13296.jsonl` pose and accepts `-- --capture=res://...`. In PowerShell pipe the executable to `Out-Host` so the shell waits for completion; use a writable `--log-file`.

If building placements change, regenerate memberships with `--headless --path . --script assets/super-city/tools/build_corridor_chunks.gd`, then rerun the membership and proxy checks. Proxy shapes/textures are rebuilt from the saved source assets at scene initialization.
