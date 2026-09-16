# Central Park

The city instances `scenes/central_park.tscn` at world position `(-292, 0, 0)`. Its 508 × 604 m footprint contains rolling ground, Moonwater Lake, a wooden arch bridge and dock, 16 walking routes, 51 warm trail lanterns, and 400 faceted oak, pine, birch and willow trees. Narrow woodland trails remain unlit. The southern Great Lawn is a gently graded, tree-free meadow roughly 200 × 140 m, with a canopy clearance buffer and no undergrowth inside.

Three small furnished houses have open doorways and warm windows. There are 700 warm yellow animated fireflies at night. The September 13 first pass removed mushrooms, shore rocks, standing stones/runes, the crystal grotto, magical lights and blue wisps, along with the two discovery-only trail spurs. Trees were reduced from 1,400 to 400 (71.4% fewer), with a 13 m minimum trunk spacing. Lighting fades with the existing day/night clock. Water and fireflies stop when the game is paused. All meshes are original, generated with Godot primitives; no downloads or addons are required.

Current highest-detail geometry totals: **74,174 triangles by day; 75,574 at night**, including every tree and prop instance. Oak, birch and willow use **96 triangles each**, pine **72**, bushes **12**, and trail lanterns **112**. All 400 tree placements and the 140 bush placements are preserved. Camera/distance culling and collision geometry are excluded from these inventory counts. See `TRIANGLE_AUDIT.md` for current and earlier counts.

The 16 paths now have trimmed junctions, connected lake approaches, squared gate/bridge/ramp ends, and surfaces fitted to the actual terrain facets to prevent grass poking through. Main walks have subtle paving textures; narrow trails have dirt textures. The 512 x 512 repeating albedo maps add no geometry. Terrain fitting and junction repairs bring paths from 2,466 to 5,550 triangles. `tools/park_paths.gd` builds the repaired meshes and textures while keeping the original placement routes in `park_layout.gd` for deterministic trees and lanterns. `tests/test_park_paths.gd` checks path coverage, overlaps, terrain clearance and entrance heights. Open Main and walk the bridge junctions, the lake approach, the southwest gate and all three cabin ramps; compare texture readability at ground level and while flying.

The northern forest beyond Pine Pass and the coastal forest share these oak/pine mesh resources, so their trees receive the same simplifications automatically. Across all three scenes, 10,381 trees now total 834,960 triangles, down from 1,784,424 before the final birch/pine/willow pass. `tools/audit_shared_trees.gd` counts these references and checks the per-tree budget with `-- --validate`.

All trees have a 16-triangle tapered square trunk. Oak, birch and willow have four 20-triangle faceted crowns shaped for each species; pine retains four layered, closed cones at 14 triangles each. Shrubs use one tapered eight-vertex form with a leafy texture (`meshes/bush_albedo.res`). Lantern posts and bases are boxes, with frame bars removed; glass, roofs and lighting remain. Bridge railings use double-sided flat panels and a cutout texture (`meshes/bridge_railing_albedo.res`), totaling 80 triangles for both sides. Twenty panels per side follow the arch, with separate continuous guard collision. The full bridge is 456 triangles including deck and support piers.

Ground uses adaptive 4 m / 8 m patches, with finer sampling in areas of greater height variation and shared edge vertices at transitions. Its original 4 m patchwork colors are stored in `meshes/terrain_albedo.res`, so visual color detail is independent of mesh subdivision. The largest sampled unsplit-patch height error during baking was 0.0094 m; this is a sampled estimate, not a global error bound. Terrain collision is regenerated from the same mesh.

## Explore

Run Main, open the developer console with backtick, enter `time night`, then close the console. Approach the park west of the initial player area. Follow lanterns around the lake; smaller dirt paths lead into darker woods. Test walking across the bridge, up to the dock, and through all three house doorways. Fly above the trees to inspect the full layout. Use `time day` to compare the foliage and paths in daylight.

Discovery coordinates below are world X/Z. Godot markers also live under `SuperCity/Landmarks/CentralPark/Discoveries`.

| Place | X | Z |
| --- | ---: | ---: |
| Moonwater Lake | -260 | -54 |
| Willow Hermitage | -463 | -186 |
| Birch Hideaway | -137 | 156 |
| Mosskeeper Cottage | -449 | 177 |
| Great Lawn | -317 | 170 |

The lake has a depressed, solid bed beneath its visual water surface. Existing traversal still applies underwater; this change does not add swimming.

## Editing and tuning

Open the dedicated park scene to edit its authored nodes. On its root, Inspector exports control lantern and firefly brightness, firefly visibility and animation speed. Terrain and tree meshes are shared native `.res` resources. Trees use individual reusable species scenes with optional trunk collisions; fireflies use one animated batch. See `assets/trees/README.md` for selection, deletion and placement. Distant park lights fade out to limit rendering cost.

`tools/park_layout.gd` defines heights, paths, `TREE_COUNT`, `MEADOW` and `MEADOW_RADII`. `tools/park_terrain.gd` builds the adaptive terrain and its color texture, targeting about 23,000 triangles. `tools/generate_park.gd` deterministically rebuilds only the park scene, meshes and `layout.json`; it preserves saved tree edits inside the authored forest containers, while other generated content is rebuilt. The full-city generator is not needed.

Run the park baker with a graphics renderer, **without `--headless`**. Godot's dummy renderer discards MultiMesh buffers. The baker rejects that mode and validates buffers before saving:

```powershell
$parkGodot = 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
& $parkGodot --path . --script res://assets/central-park/tools/generate_park.gd
& $parkGodot --headless --path . --script res://tests/test_central_park.gd
& $parkGodot --path . --script res://assets/central-park/tools/render_park.gd
```

The test checks serialized foliage buffers, 400 tree instances and matching trunk collisions, 140 bushes, all-species tree/bush triangle budgets, outward shrub faces, square lantern supports without frame bars, textured rail geometry and guard collision, reduced terrain triangle count and matching interior mesh edges, absence of removed decorations, tree-free meadow clearance, gentle meadow slopes, terrain/trail/bridge collisions, open doorways, tree placement and species, day/night switching, effect toggles and pause behavior. A player-sized capsule also simulates walking into each house and onto the dock. The render tool captures actual Forward+ day/night views into `artifacts/central_park/`, including `bridge_railings.png`, `lantern_detail.png` and `bush_detail.png`. `tools/render_oak_review.gd` captures `oak_comparison.png` using the saved original oak in `artifacts/central_park/oak_before_100.res`. No manual superhero-controller playtest was performed.

## Changed files

- Added `scenes/central_park.tscn`, `scripts/central_park.gd`, and this `assets/central-park/` asset/tool directory.
- Updated `scenes/super_city.tscn` to instance the park, disable its old flat placeholder, and move its CentralPark start marker onto the Great Lawn.
- Added `tests/test_central_park.gd` and updated the park description in `assets/super-city/README.md`.


