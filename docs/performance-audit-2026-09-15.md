# City performance review — September 15, 2026

## Conclusion

The strongest measured opportunities are **sharing repeated street-prop meshes**, **reducing distant traffic CPU work**, and **sharing equivalent building-window materials**. Together they explain much of the rendering and simulation cost. The general scene-node count is a useful size indicator, but it does not mean 41,000 scripts run each frame.

This review leaves production scripts, scenes, assets, controls and lighting unchanged. All experiments ran in separate disposable Godot processes. Added files are the audit scripts, this report, and generated JSON/log/image evidence under `artifacts/performance_audit/`.

## Method and limits

- Godot 4.7.2, Forward+, D3D12, local RTX 4090. Main scene instantiated with its existing high population defaults; no save was loaded.
- Most runs rendered at **1600 × 900**, VSync off. Fixed skyline and street cameras, day and night. Simulation and spawning continued; the player was held stationary, so this is not a continuous flight/combat benchmark.
- Each case warmed briefly and sampled 3–5 seconds. Tables use **median wall-clock frame time**. Lower is better. Rendering CPU and GPU counters were captured separately, along with existing script timers.
- Traffic populations evolve during a run, so small differences are noise. Baseline was repeated after restoring experimental changes. Improvements from different experiments must not be added together.
- The first broad pass accidentally placed the inspection camera inside the hidden-in-later-runs player model. Its geometry/draw-call inventory remains useful; use the subsequent unobstructed follow-up captures for the primary comparisons below.
- Existing sandbox user-directory, shader-cache, certificate and asset-UID warnings occurred. These affect confidence in cold-load stutter and are not evidence that the user's normal game has the same cache problem. Measurements exclude loading and emphasize stable medians.
- GPU clocks and scheduling produced variable GPU timings. In these local tests, GPU medians were generally around 1–3 ms, much lower than total frame time. Reducing 3D resolution did little to total frame time. This points toward CPU/render submission and simulation as the first targets on this machine; lower-end GPUs still need their own measurements.
- Confirmation at **2560 × 1440** measured **14.99 ms/frame** with **3.12 ms GPU time**. Halving the 3D render scale reduced GPU time to **2.25 ms**, while total frame time remained **15.02 ms**. This confirms that lowering resolution is a weak remedy for the tested bottleneck.

## What occupies the scene

Initial main-scene inventory: **41,226 nodes**, **20,544 MeshInstance3D nodes**, **9,506 collision shapes**, **5,520 StaticBody3D nodes**, **4,477 distinct material resources**, **260 light nodes**, and **zero OccluderInstance3D nodes**. The live tree grows modestly as nearby vehicles and full civilians spawn. Light count includes inactive pooled lights.

| Branch | Nodes | Mesh nodes | Collision shapes | Main observation |
| --- | ---: | ---: | ---: | --- |
| Building districts | 15,844 | 4,092 | 7,597 | Many material surfaces and per-placement window material copies |
| CityLife | 9,258 | 7,157 | 521 | Repeated small street props use separate primitive mesh resources |
| CoastalRegion | 7,057 | 4,516 | 41 | Mostly repeated scenery/trees; low draw-call impact in the tested view |
| Waterfront | 4,103 | 3,319 | 318 | Many separately drawn decorative pieces |
| Landmarks | 1,978 | 762 | 486 | Secondary contributor |
| Pedestrian routes | 792 | 259 | 0 | Includes debug geometry nodes, even with route display disabled |

Only 73 nodes had ordinary processing enabled in this initial snapshot, and 9 had physics processing enabled. Some systems explicitly update lightweight actors themselves, and engine-internal work is additional; these counts are not the entire CPU workload. There were 8,196 tree script instances, but the tree script has no frame callback and already shares species meshes/materials. The highway/forest branch removed only about 23 draws when hidden in the skyline view, despite its large node count.

## Measured experiments

Primary unobstructed skyline comparison:

| Temporary experiment | Draw calls | Median frame time | Rendering CPU |
| --- | ---: | ---: | ---: |
| Baseline | 4,646 | 14.78 ms | 4.37 ms |
| Share equivalent window materials | 4,167 | 14.30 ms | 4.05 ms |
| Share windows + equivalent CityLife primitive meshes | 2,591 | 10.64 ms | 2.87 ms |
| Restore original resources | 4,636 | 15.01 ms | 4.29 ms |

The combined experiment reduced draw calls by approximately **44%** and median frame time by approximately **29%**. It reused the same mesh dimensions, materials, textures and six window-pattern variants. It did not remove props, simplify geometry, change light settings or remove collision. These are diagnostic results, not guaranteed final optimization gains across all camera positions.

Street simulation comparison:

| Temporary experiment | Median frame time | Interpretation |
| --- | ---: | --- |
| Street baseline | 12.38 ms | Approximately 81 FPS-equivalent median |
| Pause traffic processing, retain visible vehicles | 6.00 ms | Largest isolated script/simulation saving |
| Pause civilian crowd processing | 9.72 ms | Secondary CPU opportunity |
| Pause waterfront processing | 11.70 ms | Much smaller effect |
| Half 3D render scale | 12.12 ms | Little total-frame improvement |
| Pause all scene scripts | 3.68 ms | Diagnostic lower bound; gameplay is frozen |

### 1. Repeated prop mesh resources — highest rendering priority

CityLife has 845 hydrant mesh nodes using **845 distinct meshes**, 624 traffic-control meshes using **624 distinct meshes**, 332 bench meshes using **332 distinct meshes**, and 420 grate meshes using **420 distinct meshes**. Many are equivalent primitive shapes instantiated as separate resources.

The experiment mapped **3,160 primitive placements to 112 equivalent shared mesh resources**. Keeping the same mesh/material resource lets Forward+ batch repeated opaque instances. This explains why reducing triangle count further would miss much of the current overhead. [Godot automatic-instancing documentation](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html#use-automatic-instancing).

Recommended implementation: update the prop generators to cache primitive meshes by dimensions and mesh properties, or use shared reusable prop scenes/resources. Combine the fixed components of a hydrant/bench into one mesh with a small material set. Keep traffic-signal lenses separate from static housings where their behavior requires it. Apply the same audit to waterfront decorations next.

For repeated scenery at larger scale, use **spatially chunked MultiMeshes**. Avoid one city-wide MultiMesh: its instances are culled together, so a visible corner can cause the entire batch to render. [Godot MultiMesh guidance](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html).

### 2. Distant traffic — highest simulation priority

Existing profiling measured about **5.3–5.4 ms per physics tick** in `traffic_manager` at street level. Within that total, distant proxy simulation was approximately **3.6 ms** and proxy render updates **1.3 ms**. These nested categories overlap; do not sum them on top of the manager total.

The test had roughly **360 distant proxy vehicles**, about **97–100 render batches**, and **20 full nearby vehicles**. Regular full-vehicle physics callbacks and obstacle sweeps were much smaller than the proxy system. Skyline traffic also cost several milliseconds despite having no full nearby cars.

`traffic_box_lod.gd` repeatedly scans proxy dictionaries, reconstructs positions, sorts candidates/queues, rebuilds batch membership, writes transforms/colors and reconstructs bounds. These operations run through the 60 Hz manager loop.

Recommended implementation: retain responsive near-player simulation, but update distant traffic decisions at 10–15 Hz, interpolate visual positions, cache per-record positions/distances, and rebuild lane queues/batch membership only when relevant state changes. Update farthest silhouettes less often and avoid rewriting unchanged colors/bounds. Validate signals, following gaps, promotion near a fast-moving player, and thrown-car interactions after each change.

### 3. Window material duplication

`assets/generated-buildings/commercial/commercial_skyscraper_01.gd` duplicates every emissive material in `_ready()`. Residential and industrial building scripts inherit this behavior. The emission textures and rebuilt meshes are cached already; the material resources are still unique per placement.

The experiment reduced **3,633 emissive surface material assignments to 500 shared materials**, keeping each original mesh/surface, emission texture and brightness. Draws dropped by roughly 480 in the skyline view. Recommended implementation: cache materials by asset, surface, variant and tuning, then update each shared material once when the night amount changes. Preserve standalone buildings and any distinct emission-energy overrides in the cache key.

The seeded maps are not regenerated each frame, and windows are not individual lights. The generated UV2 mesh copy currently rebuilds surfaces without passing through imported LOD dictionaries; preserve LOD/shadow-mesh data if those are added to these assets later. That is a future compatibility concern, not a measured current bottleneck.

### 4. Crowd population work and streaming spikes

Crowd processing is smaller than traffic but measurable. Street samples showed population bookkeeping around **0.5–0.8 ms/tick**, lightweight movement around **0.8 ms/tick**, and full-walker physics around **0.5 ms/tick**; nested subcategories overlap. Population recomputation can take approximately **6 ms in an individual call**, and early first-use spawn samples included much larger spikes.

The manager rebuilds candidate route intervals and density weights periodically, even for a stationary player. Cache the route/density result until the focus moves meaningfully or settings change. Distribute spawning and promotion across frames and warm frequently used civilian assets. Use a repeated high-speed city traversal to determine which first-use spikes persist once resources are warm. [Godot pipeline-compilation guidance](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html).

### 5. Distance handling, occlusion and scene nodes

Most ordinary building meshes have visibility ranges, and the existing crowd/traffic tiers are valuable. However, CityLife small props and waterfront details commonly have no distance cutoff; thousands of tiny pieces remain candidates long after they are useful. Add size-appropriate detail ranges while keeping the skyline and major structures visible. For buildings, a block-level distant representation can replace many individual surface draws. [Godot visibility-range/HLOD guidance](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html).

There are no occluder nodes. Test simple building-volume occluders for street views, where entire blocks are hidden behind the first row of buildings. Expect less benefit above rooftops, and measure their CPU cost. [Godot occlusion guidance](https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html).

Longer term, load decorative detail and collision by area, with a generous movement-speed-based look-ahead. **Preserve solid building collision and prefetch before fast traversal**; removing distant colliders without this would reintroduce falling/running through buildings. First make low-risk resource sharing improvements, then measure whether reducing node count through streaming is worth the added complexity.

### 6. Lighting, atmosphere, grab controller and memory

- Disabling shadows removed roughly 500 draws in the broad skyline pass, but produced a much smaller frame improvement than sharing props or pausing traffic. Leave visual lighting quality intact for the first optimization pass.
- Street lighting uses a bounded pool: up to 96 street lights plus 24 frontage lights, without shadows. Smoke is distance-limited and capped at 12 active emitters. These systems already have useful limits.
- Pausing the idle grab controller did not produce a measurable improvement. It checks nearby hostiles at 10 Hz and operates on one held enemy. This does not benchmark a large active melee encounter; it rules out idle grabbing as the explanation for the reproduced city baseline.
- A separate 1,000-call microbenchmark of the actual controller measured about **0.0025 ms per target search** with one hostile and **0.286 ms per paired-pose sample** while holding that hostile. Active grabs have a real animation cost, but it is much smaller than the measured city/traffic costs. This microbenchmark excludes the rest of combat and does not replace an encounter stress test.
- Reported render memory was about **2.7 GiB**, with about **625 MiB** tracked static CPU memory in one street sample. Investigate texture residency/size before targeting lower-memory GPUs, but this run did not show evidence of memory exhaustion. No orphan-node accumulation was observed in the sampled runs.

## Suggested implementation order

1. Share equivalent CityLife primitive meshes and window materials; repeat fixed-camera screenshots and counters to confirm appearance and savings.
2. Reduce distant-traffic update frequency and avoid redundant rebuilding, with near-player collision and traffic tests.
3. Apply the prop changes to waterfront details and add sensible detail distance ranges.
4. Cache crowd population queries and investigate high-speed traversal spikes.
5. Trial building occluders and block-level HLOD; consider streaming afterward.

Performance acceptance should use median and 95th-percentile frame time for the same camera route, seed, time of day, resolution and population settings. Include street combat, grabbing/throwing, fast flight, ship/harbor views and day/night transitions. A 60 FPS budget is **16.67 ms per frame**, so leaving headroom for encounters matters even when the quiet scene currently exceeds 60 FPS.

## Reproduce and evidence

Run using the local Godot executable, with the project as the working directory:

```powershell
& 'D:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --path . --script tests/profile_city_audit.gd
& 'D:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --path . --script tests/profile_city_followup.gd
& 'D:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --path . --script tests/profile_city_resolution.gd
```

Run one at a time. These are graphical benchmarks, so do not use `--headless` for rendering measurements. They do not save experimental scene/material changes. `results.json` contains the complete inventory and broad pass; `followup.json` contains the unobstructed and resource-sharing experiments; `resolution.json` contains the 1440p follow-up. Screenshots `clear_skyline.png` and `clear_street.png` show the primary viewpoints.
