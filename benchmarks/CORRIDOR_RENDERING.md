# Road corridor rendering isolation — September 22, 2026

`corridor_rendering.gd` extends the existing city audit/follow-up scripts. It
replays the camera and player position from the last JSONL row of a live capture.
The default is the newest capture; `--capture=res://...jsonl` selects one.

Run from the project in PowerShell, after stopping the playable game:

```powershell
& 'D:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --path . --script benchmarks/corridor_rendering.gd -- --capture=res://artifacts/live_performance/city_13296.jsonl
```

This opens a disposable graphical run and exits automatically. Do not use
`--headless`. Results overwrite `artifacts/corridor_rendering/results.json`;
baseline, hidden-building and shared-material screenshots accompany it.

The reproduction uses 2560×1440, 100% render scale, shadows/bloom/VSync off,
uncapped frames, low crowd/traffic, and a stopped clock at 17:00. The generated
population and window seed are controlled, rather than restored from a save.
Camera FOV comes from the player camera. It measures a live baseline, then freezes
simulation to hold actors and their positions constant. Each geometry group is
hidden independently and restored; occluders, lights and collisions remain.
These are diagnostic comparisons, not proposed visual deletions or gameplay FPS
predictions. Runtime resources and settings are never saved.

## Results on the RTX 4090

The live baseline reproduced the corridor at 4,872 draws and 11.85 ms median
frame time. Frozen baselines stayed between 8.73 and 8.89 ms. CPU-render values
below include render setup. The paired group trials agreed on draw counts.

| Frozen comparison | Draw calls | CPU render, mean | Frame, median |
| --- | ---: | ---: | ---: |
| Baseline | 4,872 | 4.71 ms | 8.80 ms |
| Building geometry hidden | 3,489 | 3.31–3.32 ms | 6.24–6.25 ms |
| Road/sidewalk geometry hidden | 3,714 | 3.85–3.90 ms | 7.18–7.30 ms |
| Street props and CityLife geometry hidden | 3,814 | 3.57–3.74 ms | 6.79–6.84 ms |
| Traffic geometry hidden | 4,829 | 4.73–4.78 ms | 8.60–8.73 ms |
| Crowd geometry hidden | 4,860 | 4.66–4.70 ms | 8.71–8.79 ms |
| Buildings beyond 150 m hidden | 3,523 | 3.39 ms | 6.36 ms |
| Buildings beyond 300 m hidden | 3,588 | 3.36 ms | 6.35 ms |
| Equivalent building shader materials shared | 4,274 | 4.34 ms | 8.02 ms |
| Final restored baseline | 4,872 | 4.65 ms | 8.73 ms |

Distant building removal accounts for 1,284 of the 1,383 draws removed by hiding
all building geometry (about 93%). Distance uses each geometry node's horizontal
origin distance to the camera. Removal is an upper bound on possible savings;
replacement geometry still has a cost. The 50 unique generated-building mesh
pairs inspected had no stored mesh LODs in either source or runtime surfaces.

Equivalent-material sharing compares the shader, render priority, next pass and
all shader parameters, including textures. It shares 3,567 surface assignments
among 501 equivalent materials, reducing 598 draws while keeping rendered object
and primitive counts unchanged. Baseline and shared-material screenshots were
visually inspected. A production implementation must also preserve independent
window updates, seed/palette changes, and correct ownership of shared resources.

The evidence supports a small HLOD trial: keep nearby buildings, replace distant
street-block groups with combined meshes using few material surfaces, and retain
the skyline, occlusion and traversal collision. Ordinary triangle-reduction LOD
does not itself combine separate mesh/material draws. Roads and props should
receive their own batching audit because together they also remove 2,216 draws
in these separate comparisons. Savings from separate tests are not additive.

Validation: GDScript parse check and the full graphical benchmark passed;
restored draws matched the original exactly. The environment reported unavailable
user settings/shader-cache storage and certificate-store access. Warmup precedes
measurements. Process/physics monitors can retain stale values across pauses;
use wall-frame and render timings for the frozen comparisons.

Added files: this guide, `benchmarks/corridor_rendering.gd` (and any Godot-generated
UID sidecar). Generated evidence is under `artifacts/corridor_rendering/` and
`artifacts/corridor_run.log`. No production gameplay scenes or assets were edited.
