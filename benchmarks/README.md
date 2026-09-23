# Civilian model benchmark

`civilian_models.gd` compares the old civilian body/accessory hair with the current shared civilian scene. Run each variant in a separate Godot process, sequentially, with other game/editor rendering stopped:

```powershell
$godot = 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
foreach ($variant in @('before', 'after')) {
    Start-Process $godot -WindowStyle Hidden -Wait -ArgumentList @(
        '--path', '.', '--script', 'benchmarks/civilian_models.gd', '--', "--variant=$variant"
    )
}
```

Do not use `--headless`: these measurements require actual GPU rendering. Use the same rendering backend for both runs; the project currently selects Forward+ / D3D12. Output JSON, logs when requested, and screenshots are stored under `artifacts/civilian_mesh_benchmark/`.

The benchmark renders a continuously updating 1920×1080 offscreen viewport with a fixed camera, ground plane, directional shadows, 100% render scale, no MSAA, uncapped frames and VSync off. It measures 40 and 100 fully animated civilian instances. All actors use the real civilian scene and animation controller, a walking loop with staggered phases, and identical placements. Legacy hair choices are balanced across the three original styles. Imported mesh LOD settings are retained. The legacy scene is preserved in `tests/fixtures/civilian_legacy_benchmark.tscn`, so the baseline can be repeated after the gameplay asset swap.

Each population gets five seconds of initial resource/shader warmup, then three trials with three seconds of additional warmup and eight seconds of measurement each. Frame time uses elapsed wall-clock microseconds between process frames, not the once-per-second FPS monitor. GPU/render CPU timings come from the measured viewport. Draw calls and primitive counts come from the rendering performance monitors and include shadow passes; they are not the source mesh triangle counts. Screenshots are taken outside the measured intervals.

This isolates the cost of the model, its skeleton animation, materials, hair and shadows. Actors remain stationary and have gameplay physics disabled; crowd routing, spawning, capsule transitions, city geometry, traffic, player and combat are excluded. The resulting FPS is **render/animation throughput in this controlled scene**, not a prediction of city gameplay FPS. Skeletons still have 65 bones each, so reducing mesh triangles does not remove animation evaluation costs.

The gameplay change is in `scenes/npcs/civilian.tscn`: it shares the exact player Meshy asset and disables separate accessory hair. The historical `Superhero_Female_FullBody` node name remains because existing civilian controllers and rescue-patient code address that path. Routed civilians, POI civilians and rescue patients inherit the new model. Distant capsules and population budgets are unchanged. All full civilians now have the same textured appearance; the old randomized hair/body palette only applies to the preserved legacy fixture.

Relevant verification: `tests/test_civilian_meshy.gd` checks civilian, routed civilian and rescue-patient scenes, geometry sharing, 1,552 triangles, no duplicate hair, all seven animation track targets, finite poses at four timestamps, and actual walking bone motion. It also checks the rescue carry anchor and paused injury pose. `tests/test_character_hair.gd` retains legacy accessory coverage against the fixture. Crowd lifecycle and capsule promotion/demotion use their existing tests. See the dated results report for test outcomes and limitations.
