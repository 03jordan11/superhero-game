# Central Park triangle audit — September 13, 2026

## Current pass: individual editable tree scenes

All **10,381 trees** are now individual instances of `assets/trees/oak.tscn`, `pine.tscn`, `birch.tscn` or `willow.tscn`, replacing tree MultiMeshes in the park, northern forest and coastal region. Geometry totals are unchanged: **834,960 tree triangles** across the three regions; **75,574 nighttime / 74,174 daytime** triangles for the entire park. Meshes and materials are still shared. Node count increases and visibility is evaluated per tree; this conversion has not been benchmarked for FPS.

The 400 park trees retain active capsule collisions under their individual instances. Northern/coastal trees keep collision disabled, and allocate no unused physics bodies. Separate park trunk collision groups were cleared. Trees can be selected and deleted in their owning scenes, and saved edits are preserved by the three generators. See `assets/trees/README.md` for editing instructions and changed files. Validation checks every original transform/species/distance, scene ownership, collision toggle and saved edits in all three regions; the park traversal checks also pass. Latest shared-tree audit reports zero tree batches and 10,381 individual mesh nodes.

## Previous pass: connected, textured paths

**75,574 nighttime / 74,174 daytime park triangles.** Path geometry changes from 2,466 to **5,550** triangles (+3,084; +4.3% of the previous park nighttime total). This is the cost of fitting paths to the existing terrain facets and cutting clean junctions; the two new color textures add **zero triangles**. Terrain, trees, bushes, bridge and other props retain their previous counts. All 16 path nodes remain, with collision generated from the repaired surfaces.

The path baker subtracts overlapping footprints at junctions, connects short lake approaches, trims bridge links to the main walk, matches the bridge deck width, cuts gate ends flush at the city sidewalk's 0.03 m height, and curves cabin trails into the entry ramps. Paths follow the actual terrain triangles instead of sampling a different height surface that could let grass poke through. Coplanar pieces are merged and redundant collinear vertices removed to limit geometry. Main walks use subtle pale paving with slab seams and grain; woodland/bridge links use warm dirt with mottling and small aggregate flecks. Both are repeating, mipmapped 512 x 512 albedo textures with no displacement or added detail meshes.

Validation: `tests/test_park_paths.gd` passed 7,953 centerline coverage samples, overlap checks (0.001 m2 clipping tolerance), terrain-clearance samples and gate/ramp/deck end-height checks. The existing park test passed 159 trail probes and capsule traversal through houses and onto the dock. Actual GPU junction, gate, cabin and day/night park renders were inspected; no manual controller playtest or performance benchmark was performed. The test omits six negligible sliver triangles from spatial checks; the inventory includes every stored triangle.

Changed files: `tools/generate_park.gd`, new `tools/park_paths.gd`, `tools/render_park.gd`, all 16 `meshes/trail_*.res`, new `meshes/path_paving_albedo.res` and `meshes/path_dirt_albedo.res`, regenerated `scenes/central_park.tscn`, new `tests/test_park_paths.gd`, this audit and README. The park baker reserializes its other resources; foliage layout and the main/city/regional scene files were verified unchanged. The previous inventory is `artifacts/central_park/triangle_audit_before_paths.json`; current counts are in `triangle_audit.json`. Review images include `path_bridge_west.png`, `path_lake_junction.png`, `path_north_junction.png`, `path_southwest_gate.png`, and `path_house_entry.png` in that artifact directory.

## Previous pass: all tree species below 100 triangles

**72,490 nighttime / 71,090 daytime park triangles**, down from 123,266 / 121,866 immediately before this pass. This removes 50,776 park triangles (41.2% of the nighttime inventory) without removing or relocating trees. All four species now use a 16-triangle tapered square trunk. Birch and willow use four 20-triangle crowns, with narrow upright and broad drooping silhouettes respectively. Pine retains four eight-sided cone tiers, each using 14 triangles including a closed bottom.

| Species | Before per tree | After per tree | Park count | Park before | Park after |
| --- | ---: | ---: | ---: | ---: | ---: |
| Oak (already simplified) | 96 | 96 | 129 | 12,384 | 12,384 |
| Birch | 328 | 96 | 118 | 38,704 | 11,328 |
| Pine | 208 | 72 | 126 | 26,208 | 9,072 |
| Willow | 328 | 96 | 27 | 8,856 | 2,592 |
| **Total park trees** | | | **400** | **86,152** | **35,376** |

The northern forest beyond Pine Pass (`scenes/city_life.tscn`) and the coastal forest (`scenes/coastal_region.tscn`) reference these same oak and pine resources. The previous oak change and this pine change therefore apply automatically to those forests. Neither regional scene needs regeneration. Tree counts, placements, spatial batches, distance settings and collisions are preserved.

| Area, trees only | Trees | Before this pass | After | Saved |
| --- | ---: | ---: | ---: | ---: |
| Central Park | 400 | 86,152 | 35,376 | 50,776 |
| Northern / Pine Pass forest | 4,943 | 843,904 | 395,376 | 448,528 |
| Coastal forest | 5,038 | 854,368 | 404,208 | 450,160 |
| **Combined** | **10,381** | **1,784,424** | **834,960** | **949,464 (53.2%)** |

These counts include every placed tree at full mesh detail before camera/distance/occlusion culling; they are not an FPS measurement or a count for one visible frame. Collision and shadow/depth passes are excluded.

Machine-readable reports: `artifacts/central_park/triangle_audit.json` and `shared_tree_audit.json`. Immediate baselines: `triangle_audit_before_final_trees.json` and `shared_tree_audit_before_final.json`. Reproduce the external forest count with `tools/audit_shared_trees.gd` (`--headless --script ... -- --validate` also checks the budget). Comparison renders: `birch_comparison.png`, `pine_comparison.png`, `willow_comparison.png`; generate with `tools/render_tree_review.gd -- birch` (or pine/willow) and a graphics renderer. Godot park tests passed with 159 trail probes and zero failures; all-species budget checks and shared-resource audits passed. GPU comparison and in-scene day/night renders were inspected. No manual controller playtest or FPS benchmark was performed.

The sections below record earlier passes; their totals are historical.

## Previous oak review pass: simpler props and textured railings

**123,266 nighttime / 121,866 daytime triangles**, 58,984 fewer than the preceding 182,250 nighttime total. Tree and bush placements are unchanged. Only the oak tree design was simplified; other species remain for a later review.

| Item | Previous triangles each | Current triangles each | Quantity | Current placed total |
| --- | ---: | ---: | ---: | ---: |
| Oak | 328 | 96 | 129 | 12,384 |
| Bush | 168 | 12 | 140 | 1,680 |
| Trail lantern | 208 | 112 | 51 | 5,712 |
| Bridge railing, both sides | 2,400 | 80 | 1 | 80 |

Oak: 16-triangle tapered square trunk plus four 20-triangle crowns. Bush: one tapered eight-vertex shrub with a leaf texture. Lantern: 12-triangle post, 12-triangle base, unchanged 40-triangle roof and 48-triangle glass; no frame bars. Bridge: cutout railing textures on flat panels, twenty panels per side following the curved deck, with separate guard collision. The entire bridge is 456 triangles (160 deck + 216 support piers + 80 railings).

Unchanged tree designs: birch 328 triangles each (118 trees), pine 208 (126 trees), willow 328 (27 trees). Tree geometry now totals 86,152 triangles. Ground remains 22,994 triangles.

Current inventory: `artifacts/central_park/triangle_audit.json`. Previous inventory: `artifacts/central_park/triangle_audit_before_oak.json`. Review images: `oak_comparison.png`, `bridge_railings.png`, `bush_detail.png` and `lantern_detail.png` in `artifacts/central_park/`.

## Previous second pass: adaptive ground and half the bushes

**182,250 nighttime / 180,850 daytime triangles.** Ground is now **22,994** instead of 38,354 (40.0% reduction). Bushes are **140 instances at 168 triangles each = 23,520**, instead of 280 / 47,040. This pass removes another 38,880 triangles from the first pass. Tree counts, meshes and all 400 placements remain unchanged. Fireflies and lantern geometry are unchanged.

The original ground color pattern is retained as a small texture, independent of mesh subdivisions. Ground uses 4 m and 8 m patches prioritized by sampled height error, with matching edges to avoid cracks. Collision uses the same simplified mesh. Tests confirm the requested triangle reduction, no unmatched interior edges, all retained trees, exactly 140 bushes, and traversal through 159 path probes with no failures.

Current inventory: `artifacts/central_park/triangle_audit.json`. First-pass inventory preserved in `artifacts/central_park/triangle_audit_before_ground.json`.

| Object | Components | Triangles each | Current quantity | Placed total |
| --- | --- | ---: | ---: | ---: |
| Oak | Trunk 48 + five canopy clumps of 56 | 328 | 129 | 42,312 |
| Birch | Trunk 48 + five canopy clumps of 56 | 328 | 118 | 38,704 |
| Pine | Trunk 48 + four cone tiers of 40 | 208 | 126 | 26,208 |
| Willow | Trunk 48 + five canopy clumps of 56 | 328 | 27 | 8,856 |
| Bush cluster | Three foliage clumps of 56 | 168 | 140 | 23,520 |
| Trail lantern | Post 48 + base 48 + roof 40 + glass 48 + two frame bars of 12 | 208 | 51 | 10,608 |
| Firefly | One billboard quad, two triangles | 2 | 700 | 1,400 |

Fireflies already use a vertex/fragment shader for movement, camera-facing orientation, pulsing and glow. One MultiMesh batches all 700 quads. They have no individual scripts, physics or Light3D nodes, cast no shadows and are hidden during daytime. Their triangle count is the shader's drawable surface, not modeled insect detail. No alternative firefly rendering implementation was benchmarked or substituted in this pass.

## Previous first pass: thinning and removal

**221,130 triangles at night / 219,730 by day**, down from 525,410 / 523,974. Reduction: 304,280 triangles, or 57.9% of the original nighttime inventory. Trees: **400**, down from 1,400 (71.4% removed). The meadow now has a 200 x 140 m tree-free footprint, with canopy clearance and no undergrowth inside.

Removed from the scene and generator: mushrooms, shore rocks, standing stones/runes, crystal grotto, magical lights, blue wisps and two discovery-only trails. The 700 surviving fireflies are warm yellow. Buildings, bridge, dock, benches, lanterns and the lake remain.

Current totals by category are in `artifacts/central_park/triangle_audit.json`; the original machine-readable baseline is preserved in `artifacts/central_park/triangle_audit_before_thinning.json`. Tree geometry is 116,080 triangles. The first-pass changes also reduce trunk collision shapes from 1,400 to 400 and lights from 56 to 54.

The rest of this document records the **original pre-change audit**, for comparison. Its old removal proposals and counts do not describe the current scene.

## Original baseline

Source: loaded `scenes/central_park.tscn` through Godot 4.7.2 and counted actual mesh vertex/index arrays. Every placed MultiMesh instance counts separately. Original inventory: `artifacts/central_park/triangle_audit_before_thinning.json`. Reproduce a current audit with `assets/central-park/tools/audit_triangles.gd` using Godot `--headless --path . --script`.

**523,974 daytime triangles; 525,410 nighttime triangles.** These are highest-detail scene inventory totals before camera, distance and occlusion culling. They are not measured triangles in a particular rendered frame, nor an FPS benchmark. Collision geometry and additional shadow/depth passes are excluded. Night adds 700 firefly quads and 18 wisp quads. Mushrooms and lantern fixtures remain visible by day, with emission disabled.

The park scene, city scene, main scene, geometry and placements were left unchanged. Scene hashes were verified before and after the audit.

## Breakdown

Percentages use the nighttime total. Benches have their own category and are excluded from house and dock totals.

| Category | Authored contents | Triangles | Share |
| --- | --- | ---: | ---: |
| Trees | 1,400 trees in 162 spatial batches | 405,680 | 77.21% |
| Bushes / undergrowth | 280 clusters in one batch | 47,040 | 8.95% |
| Ground and lake bed | 508 x 604 m terrain, 4 m grid | 38,354 | 7.30% |
| Trail lanterns | 51 fixtures, 208 triangles each | 10,608 | 2.02% |
| Mushrooms | 84 stem/cap pairs, 104 triangles each | 8,736 | 1.66% |
| Shore rocks | 82 rocks, 56 triangles each | 4,592 | 0.87% |
| Bridge | Deck, handrails, balusters and support piers | 2,776 | 0.53% |
| Paths | 18 walking routes | 2,564 | 0.49% |
| Houses and furnishings | Three houses, excluding benches | 1,698 | 0.32% |
| Night swarms | 700 fireflies and 18 wisps | 1,436 | 0.27% |
| Crystal grotto | Crystals and three boulders | 630 | 0.12% |
| Standing stones and runes | Nine stones, runes and central dais | 588 | 0.11% |
| Benches | Eight benches, 48 triangles each | 384 | 0.07% |
| Dock | Boardwalk, ramp, platform and pilings; bench excluded | 132 | 0.03% |
| Entrance piers | Eight rectangular piers | 96 | 0.02% |
| Lake water | Water surface only; bed counted under terrain | 96 | 0.02% |
| **Total** | **All placed geometry, night effects enabled** | **525,410** | **100%** |

## Trees

| Species | Count | Triangles per tree | Placed triangles |
| --- | ---: | ---: | ---: |
| Oak | 436 | 328 | 143,008 |
| Birch | 431 | 328 | 141,368 |
| Pine | 446 | 208 | 92,768 |
| Willow | 87 | 328 | 28,536 |
| **Total** | **1,400** | | **405,680** |

Each trunk is 48 triangles. Oak, birch and willow each have five 56-triangle canopy clumps (280 canopy triangles). Pines have four 40-triangle cone tiers (160 foliage triangles). All trunks together account for 67,200 triangles; tree foliage accounts for 338,480.

## Smaller features

- Undergrowth: three 56-triangle clumps per cluster, or 168 triangles each.
- Lantern: 48-triangle post, 48-triangle base, 40-triangle roof, 48-triangle glass and two 12-triangle frame bars. Each lantern uses six separate mesh nodes.
- Mushroom: 48-triangle stem and 56-triangle cap; 168 mesh nodes across the park.
- Bench: four boxes (seat, back and two legs), 48 triangles total. Four standalone benches, three house benches and one dock bench.
- Bridge: 160-triangle deck, 160 handrail boxes (1,920 triangles), 40 baluster boxes (480) and 18 support piers (216). These use 219 mesh nodes.

## Potential savings for discussion — not implemented

- Removing 100 oak/birch/willow trees saves 32,800 triangles; 100 pines saves 20,800.
- Keeping all trees but reducing each non-pine canopy from five clumps to three would save 106,848 triangles before any visual adjustments. This is an arithmetic example, not an approved design.
- Halving the 280 undergrowth clusters saves 23,520 triangles. Simplifying each cluster from three clumps to one saves 31,360 while retaining all 280 placements.
- Removing every mushroom saves 8,736 triangles; removing every bench saves only 384.
- Ground uses 127 x 151 cells with two triangles each. A coarser/adaptive mesh could reduce geometry while retaining the lake depression and terrain shape, but would need collision and trail alignment checks.
- Distance hiding can preserve nearby decorations while reducing their distant rendering cost. Current tree/rock/undergrowth batches use a 1,600 m visibility end with a 150 m margin; small fixtures and benches have no dedicated short-distance cutoff. Undergrowth is one park-wide batch, so per-area hiding would require smaller spatial groups.

## Costs outside the triangle total

The inventory contains 1,068 mesh-bearing nodes, including MultiMesh batches; this is not an exact draw-call count. There are 56 light nodes (51 trail lights, three house lights and two magical lights), of which three have shadows enabled. The generator already configures light distance fades.

Physics is separate: 1,400 capsule shapes, 101 boxes, nine cylinders, three convex shapes and 20 concave shapes. The concave shapes contain 41,078 collision triangles, not added to rendered geometry. Water and swarm shaders, light shading and the park's 30 Hz material update loop have costs that this geometry audit does not benchmark.
