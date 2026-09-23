# Park and northern forest deletion benchmark — September 22, 2026

The edits reduce rendering work. In a controlled comparison using today's code,
median frame time decreased about **5% in the daytime park, 6% in the nighttime
park, and 3% above the northern forest**. The night result was consistent across
repeats; day and forest timings overlap between trials, so their smaller gains
should be treated as approximate. This is a modest improvement, not a large
citywide FPS jump.

## What the saved edits removed

Counts come from actual nodes rather than the scenes' now-stale count metadata.

| Item | Before manual edits | Current | Removed |
| --- | ---: | ---: | ---: |
| Park trees | 366 | 294 | 72 |
| Park light nodes | 54 | 26 | 28 |
| Park houses | 3 | 0 | 3 |
| CityLife trees | 1,710 | 973 | 737 |
| Park runtime nodes, including tree collisions | 1,974 | 1,377 | 597 |
| Northern highway/forest runtime nodes | 2,839 | 2,094 | 745 |

The park also loses associated house paths, undergrowth and decorative geometry.
The park's highest-detail rendered mesh inventory falls from 72,598 to 60,061
triangles; the highway/forest branch falls from 159,805 to 102,685. These are mesh
inventory counts, not per-frame GPU primitive counters or visibility estimates.
The complete static benchmark scene has 1,342 fewer runtime nodes.

The forest baseline already includes the earlier automated 596-tree thinning.
Thus the 737-tree reduction above measures the subsequent manual deletions.

## Controlled comparison: effect of these edits

Godot 4.7.2, Forward+ / D3D12, NVIDIA GeForce RTX 4090, 1600 × 900, 100% render
scale, High graphics, VSync off and unlimited FPS. The same current SuperCity,
camera transforms, 75° FOV, occlusion code, asset resources and window seed 8421
are used for both layouts. Only the park scene and northern forest containers
are restored in the disposable before-layout process.

Traffic and crowd nodes are removed, and world scripts are frozen after startup.
This isolates stationary rendering overhead; it does **not** measure live
gameplay FPS, moving collision cost, or the per-frame savings from fewer park
lights. Geometry/collision ownership, visibility and occlusion still reflect
each layout. Screenshots were inspected for the matching park night views.

Run order: current, before, before, current. Each run measures day park, night
park and forest views. Each view settles for four seconds, then receives two
four-second samples, each preceded by another 0.6-second settling interval.
The values below are medians of four trial medians, not a single combined frame
distribution. P95 values are likewise medians of the four per-trial P95 values.

| View | Before median | Current median | Frame-time reduction | Draw calls before → current | P95 before → current |
| --- | ---: | ---: | ---: | ---: | ---: |
| Park, day | 5.350 ms | 5.084 ms | 5.0% | 3,622 → 3,345 | 6.031 → 6.029 ms |
| Park, night | 5.165 ms | 4.855 ms | 6.0% | 3,250 → 3,034 | 5.808 → 5.602 ms |
| Northern forest, day | 2.448 ms | 2.379 ms | 2.8% | 1,232 → 1,232 | 3.143 → 2.895 ms |

Median render-CPU time falls from 2.766 to 2.597 ms in the daytime park, 2.673 to
2.502 ms at night, and 1.318 to 1.265 ms over the forest. GPU medians are roughly
0.73/0.73 ms, 0.74/0.70 ms, and 0.41/0.37 ms respectively. CPU submission remains
the larger measured rendering component on this machine.

Forest visible object count falls from 3,815 to 3,099 and primitives from 668,229
to 612,669, while draw calls remain identical. This is consistent with removing
instances that already share meshes/materials: fewer trees need not remove
whole draw batches. Park draw calls fall 7.6% by day and 6.6% at night.

Trial-median ranges:

| View | Before | Current |
| --- | ---: | ---: |
| Park, day | 5.298–5.393 ms | 4.937–5.508 ms |
| Park, night | 5.142–5.211 ms | 4.818–4.892 ms |
| Forest | 2.435–2.473 ms | 2.362–2.472 ms |

Daytime P95 is effectively unchanged. The night improvement is the strongest
repeatable timing result; forest gains are small in absolute terms (about 0.07 ms).

## Comparison with the older September 15 results

These use the original matching camera transforms, FOV, times of day and
1600 × 900 resolution, with live traffic and crowds enabled. Current runs settle
12 seconds per view and measure five seconds. The old skyline/street values
come from `artifacts/performance_audit/followup.json`; the old park/aerial values
come from `artifacts/performance_audit/city_occlusion.json`.

| View | September 15 median | Current median | FPS equivalent, old → current | Draw calls, old → current |
| --- | ---: | ---: | ---: | ---: |
| Night skyline | 14.776 ms | 8.926 ms | 68 → 112 | 4,646 → 3,839 |
| Night street | 12.384 ms | 5.756 ms | 81 → 174 | 2,348 → 1,853 |
| Day park | 4.930 ms | 8.917 ms | 203 → 112 | 2,329 → 3,422 |
| Day city aerial | 3.477 ms | 7.584 ms | 288 → 132 | 1,295 → 3,633 |

FPS equivalent means 1000 divided by median frame time, not average gameplay
FPS. The skyline/street are substantially faster than the old baseline, but
park/aerial views are slower and render more draw calls. These comparisons
include a week of other geometry, materials, occlusion, crowd and traffic
changes, plus evolving live populations. They cannot attribute gains or losses
to today's deletions. The controlled same-code comparison above is the evidence
for the deletion benefit. Historical runs are single samples, not repeated A/B.

## Evidence and validation

- `benchmarks/results/park_forest_2026-09-22.json`: metrics, all valid static
  trials, live historical rerun, inventories, engine/GPU and source hashes.
- `artifacts/park_forest_benchmark/`: before/current screenshots, raw JSON/logs,
  and disposable baseline scenes.
- Baseline park: git `7679e234789e272071d1008f692b2f238cee5a42`. Baseline forest:
  tree containers from that commit, with `assets/trees/forest_transition.json`
  deletions applied. Existing SuperCity terrain overrides remain intact.
- Every accepted run asserts the actual park tree/light and forest tree counts.
- All five accepted GPU benchmark processes exited successfully, with no
  GDScript parse/runtime errors. JavaScript syntax checks passed.
- Actual game scene SHA-256 hashes remained unchanged throughout the benchmark.
- An initial fixture-UID collision was detected and corrected. Initial runs are
  retained under `invalid_uid_runs` and are excluded from every reported figure.
  Baseline copies now omit the source UID, and the harness resolves the original
  park UID explicitly before instantiation.
- Existing sandbox shader-cache, settings-directory and certificate warnings
  appeared. Samples exclude initial loading; cold-load stutter was not measured.
- No manual player traversal or combat benchmark was performed.

## Reproduce

1. Run `node benchmarks/prepare_park_forest.cjs` to prepare disposable baselines
   and refresh saved-scene counts. Do not run preparation during a benchmark.
2. Run `benchmarks/park_forest_edits.gd` using the graphical Godot executable,
   one process at a time, with arguments in this order:
   `--variant=current --run=1`, `--variant=before_manual --run=1`,
   `--variant=before_manual --run=2`, `--variant=current --run=2`,
   `--variant=historical --run=1`. Pass script arguments after `--`.
   Launch using PowerShell `Start-Process -WindowStyle Hidden -Wait`; do not use
   `--headless`, which would remove the rendering workload.
3. Run `node benchmarks/summarize_park_forest.cjs` to regenerate the combined JSON.

Added files are the three benchmark scripts, the combined results JSON and this
report (plus Godot-generated script UID metadata). Screenshots, logs and fixture
scenes are generated artifacts. No production gameplay scripts or scenes were
edited for this benchmark.
