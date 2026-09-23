# Meshy civilian comparison — September 21, 2026

Civilian NPCs now share `assets/characters/hero_meshy/hero_meshy.glb`, including the rigid chin, flattened chest, short fro and reference texture. The body/hair uses one surface and 1,552 triangles per NPC. Population settings, animation clips, routing, collision and distant capsule behavior are unchanged.

## Measured results

Hardware: Intel Core i9-13900KF, NVIDIA RTX 4090. Godot 4.7.2, Forward+ / D3D12, 1920×1080, shadows enabled, uncapped and VSync disabled. Baseline completed before the Meshy benchmark began; processes ran sequentially. Three eight-second samples per model/population followed warmup.

| Animated civilians | Before frame time | Meshy frame time | Reduction | Before throughput | Meshy throughput |
| --- | ---: | ---: | ---: | ---: | ---: |
| 40 | 1.746 ms | 1.334 ms | **23.6%** | 573 FPS | 750 FPS |
| 100 | 4.309 ms | 2.895 ms | **32.8%** | 232 FPS | 345 FPS |

Frame times are the mean of the three trial means; displayed FPS is their reciprocal. These are **controlled rendering/animation measurements, not whole-city gameplay FPS**. Actors stay fixed while their real walking animations run. Gameplay AI/physics, traffic, buildings, population management and tier transitions are excluded. Cameras, placements, lighting and count are identical; screenshots confirmed the crowds were rendered. The 100-character case intentionally stresses full models beyond the usual 40-character target.

| Other metric | 40 before → Meshy | 100 before → Meshy |
| --- | ---: | ---: |
| Mean of trial p95 frame times | 1.979 → 1.572 ms | 4.924 → 3.234 ms |
| Viewport GPU time | 0.517 → 0.249 ms | 1.082 → 0.528 ms |
| Draw calls, including shadows | 406 → 125 | 960 → 305 |
| Highest-detail crowd triangles | 696,566 → 62,080 | 1,740,566 → 155,200 |
| Mesh surfaces | 160 → 40 | 400 → 100 |
| Reported render memory | 257.7 → 256.4 MiB | 310.2 → 293.9 MiB |

The highest-detail geometry drops approximately 91%; actual GPU workload includes shadow passes and imported mesh LODs. GPU time roughly halves, while overall frame time improves less because all 65 skeleton bones and animation evaluation remain. Render memory includes the test scene and loaded/cached resources, not solely per-NPC allocations. Trial FPS ranges were 571–574 → 736–760 for 40 civilians and 229–237 → 343–347 for 100. Sandbox settings/certificate/shader-cache warnings appeared in both variants; warmed-up rendering completed on D3D12 without rendering or animation errors.

## Verification and files

- Godot editor import and the civilian animation regression passed. The latter checks civilian, routed civilian and rescue-patient models, seven clips at four timestamps, shared geometry, and actual walking bone motion.
- Legacy accessory-hair coverage, crowd lifecycle, and capsule promotion/demotion/damage checks passed. Crowd lifecycle coverage checks lane variation and the shared Meshy texture instead of the former randomized skin materials.
- The broader `test_rescue_encounter.gd` could not complete: the current hospital scene lacks the `RescueDropOff` node the test requests. That hospital asset was already modified before this task. The standalone rescue-patient mesh, paused injury animation and carry anchor checks passed.
- Rendered crowd screenshots were inspected. Manual city traversal was not performed.

Changed gameplay file: `scenes/npcs/civilian.tscn`. Updated tests: `tests/test_character_hair.gd` and `tests/test_civilian_crowd.gd`. Added: `tests/test_civilian_meshy.gd`, preserved legacy fixture `tests/fixtures/civilian_legacy_benchmark.tscn`, `benchmarks/civilian_models.gd`, benchmark documentation and raw results at `benchmarks/results/civilian_models_2026-09-21.json`.

Restart with **F5**, approach a crowd and check walking/fleeing at close range, then fly away and return to check capsule handoffs. Full civilians now all use the same Meshy appearance, including civilians created through inherited POI/rescue scenes.

Reproduction procedure and scope: `benchmarks/README.md`. Screenshots: `artifacts/civilian_mesh_benchmark/before_40.png`, `before_100.png`, `after_40.png`, `after_100.png`.
