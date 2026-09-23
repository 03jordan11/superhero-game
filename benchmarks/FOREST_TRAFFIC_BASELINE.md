# Forest comparison and traffic-removal baseline

`forest_traffic_baseline.gd` runs the real main scene with the current ordinary-building and landmark proxies. Nothing is removed from the game by this benchmark. It hides only the northern/coastal tree MeshInstance3Ds in a disposable game process, then restores their visibility.

The fixed configuration is `forest_traffic_baseline_config.json`:

- 17:00, stopped day/night clock; seed 8421.
- 2560 x 1440, 100% render scale, Forward+ / D3D12, uncapped, VSync off.
- Shadows off, bloom off; Low civilian/vehicle density, High population view distance. These are the latest captured graphics/density settings, not the project's High defaults. Low density still spawns traffic/civilians.
- Two saved viewpoints: the latest aerial capture (`city_59360.jsonl`) and the earlier road-corridor capture (`artifacts/corridor_rendering/results.json`). Positions and rotations are copied into the config, so subsequent captures cannot silently change the benchmark.
- 15 seconds warmup per view, 3 seconds settling after each switch, three 8-second samples per forest state. On/off order reverses for the second trial.
- Player locomotion/input and performance HUD/monitor processing are disabled. Traffic, civilian simulation, collisions and other world processes continue. Populations can change during a sample and are recorded at both endpoints. This is a live stationary comparison, not identical frozen actors or a traversal benchmark.
- In the saved before-removal baseline, roads, terrain, occluders, park, building/landmark proxies, traffic controls and traffic manager were present. Forests-off does not hide their containing Highway/CoastalRegion branches.

Run with the graphical Godot executable from the project directory:

```powershell
& 'D:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --path . --script benchmarks/forest_traffic_baseline.gd --resolution 2560x1440 --position 0,0 --log-file 'D:/Superhero Game/superhero-demo/artifacts/forest_baseline_after.log' -- --label=after_traffic_removal | Out-Host
```

Use a new `--label` for every run. Existing result files are protected against overwrite. Before/after comparisons must use the same config, camera views and forest state, with other game instances stopped. Keep the benchmark window rendering normally; do not minimize it while collecting samples.

Outputs under `artifacts/forest_traffic_baseline/` include the report, per-frame raw JSON, screenshots outside measured intervals, renderer/GPU metadata, source hashes, actual forest counts, traffic-presence flags and actor counts. FPS is calculated from wall-clock frame intervals. Other metrics: mean/P95/P99 frame time, CPU process time, physics tick time, CPU rendering including frame setup, GPU rendering time, draw calls, rendered objects/primitives, node count and render-memory allocation. Timings overlap and must not be summed.

Run `python benchmarks/summarize_forest_traffic.py <label>` to produce a Markdown table and JSON summary pooled from the raw frames of all three trials. The summarizer rejects incomplete/unverified runs.

The accepted baseline is **before_traffic_removal_verified.json**, with `valid_baseline: true` after all samples complete. The earlier `before_traffic_removal.json` is explicitly rejected: the in-game CityPerformanceMonitor continued resetting GPU timing even with `enabled=false`. The benchmark now disables monitor processing too and rejects samples with unavailable GPU timers. Do not compare against that preliminary report.

## Applied removal scope

The user clarified that only `SuperCity/CityLife/TrafficControls` should be removed. Its 72 signal poles, 40 stop signs, 624 meshes and 80 labels are removed, along with the control registry and 216 animated signal-lens material updates. The city-life generator no longer creates them.

`SuperCity/TrafficManager` is preserved, including moving cars, distant traffic, junction pauses, queues, reservations and exit checks. Roads, streetlamps, benches, pedestrians, forests, building/landmark proxies and player movement are unchanged by this removal.

The accepted baseline above predates this change and still contains both systems. No after-removal benchmark was run, as requested. Future runs use the scene as it exists at that time; they do not recreate removed traffic controls.
