# Modular sidewalk performance and editor refresh audit

Measured September 16, 2026, using Godot 4.7.2, Forward+ / D3D12, an NVIDIA
GeForce RTX 4090, and a 1920 × 1080 viewport. VSync and the frame-rate cap were
disabled. The saved game scenes, rendering settings and occluder configuration
were not modified by this audit.

## Live scene measurements

The actual Main scene ran at noon with normal traffic/crowd systems. Each camera
view warmed up for eight seconds, then sampled for three seconds. The player
was stationary with movement/character rendering disabled for the camera audit.
These are stationary scene measurements, not traversal/combat stress tests.

| View | Average FPS | Mean frame time | 95th-percentile frame time |
| --- | ---: | ---: | ---: |
| Street | 181.0 | 5.526 ms | 7.555 ms |
| Aerial | 218.8 | 4.570 ms | 5.777 ms |
| Harbor | 167.2 | 5.981 ms | 9.056 ms |

FPS is frames divided by elapsed wall time, not the reciprocal of a median.
Short samples on this machine do not establish minimum performance on other
hardware or during heavy gameplay.

## Controlled sidewalk comparison

Within each view, actors were frozen and only the 23 rollout chunks and their
ground infill were swapped between the original merged geometry and the new
modules. The approved `sidewalks_3_2` trial stayed present in both variants.
All other geometry, actor positions, lighting and occluders stayed the same.
Each state settled for 0.6 seconds, then sampled for four seconds. The modular
state was sampled twice to reveal ordinary timing variation.

| View | Merged median frame | Modular median, first / repeat | Draw calls, merged → modular |
| --- | ---: | ---: | ---: |
| Street | 2.673 ms | 2.805 / 2.812 ms | 1,368 → 1,403 |
| Aerial | 2.626 ms | 2.549 / 2.555 ms | 1,361 → 1,365 |
| Harbor | 3.703 ms | 3.537 / 3.756 ms | 2,251 → 2,265 |

The street rendering cost increased by approximately 0.14 ms (about 5% of this
frozen scene's frame time). The other changes are small relative to observed
variation, so they do not demonstrate a meaningful speedup or regression.
The frozen numbers exclude normal gameplay simulation cost; use the live table
for the current game views. A matched live-simulation baseline was not measured.

The object-count cost is much larger than the measured draw-call cost. The
compared branch grew from 70 nodes / 23 meshes / 23 collision shapes to 21,984
nodes / 3,480 meshes / 4,628 collision shapes, including rollout ground infill.
Triangles grew from 12,029 to 53,086 in those branches. Extra editor nodes and
physics objects can increase scene loading, editor work and memory requirements.
This test retained both variants' resources in memory, so it does not measure
a before/after memory delta or editor load-time delta.

## Occlusion

`project.godot` enables occlusion culling. `scripts/city_occlusion.gd` constructs
ten occluder groups from district buildings, central-park structures/terrain,
and selected airport buildings. These are groups of blocking geometry, not
spatial membership volumes.

The sidewalk meshes have `ignore_occlusion_culling = false`: they can be hidden
when occluder geometry fully blocks their bounds. They do not need to be children
of an occluder group. The sidewalk slabs themselves are not used to build the
blockers, which is appropriate for these thin horizontal surfaces.

With all actors and cameras fixed, disabling culling only for the rollout's
sidewalk/infill meshes increased the renderer's visible-object count by:

| View | Additional rendered objects | Additional draw calls |
| --- | ---: | ---: |
| Street | 1,177 | 12 |
| Aerial | 825 | 5 |
| Harbor | 196 | 3 |

These counters confirm culling is active on the new geometry. Small draw-call
changes despite many objects reflect the renderer's ability to batch/instance
shared geometry; they do not mean every module submits a separate draw call.
Occlusion saves rendering work, not the existence of the node or its collision.

See [Godot's occlusion documentation](https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html).

## Main scene refresh

Main still instances `res://scenes/super_city.tscn`; it is not a detached copy.
There are no Main overrides for the sidewalk chunks. A fresh process resolves
the city's UID to the correct live scene and loads the converted modules.

The likely restart explanation is stale editor state after external scene or
tool-script edits: an open Main tab can retain an already-instantiated child.
This was not reproduced inside the user's open editor, so it is a diagnosis
from the file/resource checks rather than a confirmed engine bug.

First protect any unsaved manual work. After accepting Godot's external-change
reload prompt, use **Scene → Reload Saved Scene** on Super City and then Main,
or close and reopen Main. Reload discards unsaved scene changes; do not save a
stale editor copy over the updated disk scene. Script auto-reload is already
enabled in the local editor settings, but that setting is not a guarantee that
every open parent scene has been reconstructed.

Six historical city backups under `artifacts/` had the same UID as the live
scene. Each backup root now contains `.gdignore` so Godot does not scan these as
competing project resources. The live UID mapping was correct during this audit;
the backups are a removed ambiguity, not proof of the observed restart cause.

Godot 4.7's [editor source](https://github.com/godotengine/godot/blob/4.7/editor/editor_node.cpp)
defines the Reload Saved Scene command. The
[project organization guide](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html)
documents `.gdignore`.

## Git ignore audit

`.gitignore` now covers `artifacts/`, generated `Asset Dashboard.html` and its
validation output, local `tests/render_*.gd` / `tests/profile_*.gd` entry points
and their UID sidecars, Python bytecode/caches, and `.blend1` / `.blend2` backups.
Existing rules already cover Godot's cache, exported builds, logs, temporary
files, IDE folders and export credentials.

Regression tests (`tests/test_*.gd`) and support code remain eligible for version
control, as do actual `.blend` source files, Godot scene/resource assets, and
their required UID/import metadata. Runtime scripts do not depend on the
ignored profiling/capture entry points or artifact backups.

One previously tracked backup,
`assets/animations/blender/superher_animations.blend1`, was removed from the Git
index only. Its 24.4 MB local file remains. That removal is staged; unrelated
changes were not staged. `git ls-files -ci --exclude-standard` returns no files
after cleanup. Representative `git check-ignore` checks pass, and regression
tests plus runtime assets remain unignored.

Local raw measurements and the disposable profiling script are under
`artifacts/performance_audit/sidewalk_comparison.json` and
`artifacts/profile_sidewalk_comparison.gd`; these are intentionally Git-ignored.
