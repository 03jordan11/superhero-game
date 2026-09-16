# Downtown traffic occlusion trial

**Historical trial results.** The implementation has since expanded to eight districts, Central Park and the airport. Current controls and the complete source list are in [occlusion-inventory.md](occlusion-inventory.md). `CityOcclusion` replaces the former `TrafficOcclusionTrial` node. Current distant traffic behavior is described in [distant-traffic.md](distant-traffic.md).

## What runs in the game

`SuperCity/TrafficOcclusionTrial` builds one static occluder at startup from the actual opaque building triangles in `Districts/FinancialQuarter`: 116 buildings, 7,268 triangles. It excludes rooftop props, moving vehicles and transparent surfaces. There is no per-frame script work and no added collision. The shape follows the existing building geometry, including setbacks and openings.

The scene adds one node rather than a node on every car or building. The shape is constructed during play; it is not visible as an editor gizmo before running. Restart after changing building geometry or `buildings_path`.

Godot already supports occluding both full vehicle meshes and distant MultiMesh batches. `DistantTraffic.occlusion_culling_enabled` now provides a live switch for the distant batches. The original 250 m batch size remains unchanged. No moving vehicle was turned into an occluder, and traffic simulation, population and collisions are unchanged.

Occluders can hide any eligible geometry, so the downtown blockers also reduce rendering of other buildings. Enabling the project setting alone does not create blockers. See [Godot's occlusion guide](https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html).

## Compare while playing

1. Start the city and use `debug hud on` in the developer console.
2. Visit downtown at street level, then fly above it.
3. In Godot's **Remote** scene tree, select `SuperCity/TrafficManager/DistantTraffic`. Toggle **Occlusion Culling Enabled** to isolate distant vehicle rendering.
4. Select `SuperCity/TrafficOcclusionTrial` and toggle **Trial Enabled** to compare the whole district with/without its blockers.
5. Keep the camera stationary for each comparison. Watch frame time as well as draw calls. Drive/fly around corners and descend toward traffic to check for disappearing visible cars or broken transitions to full vehicles.

## Measured result

1600x900, Forward+, RTX 4090; two fixed daytime views. Simulation was warmed and then paused to hold geometry, vehicles and camera positions constant. These are rendering comparisons, not gameplay FPS claims.

| View | No downtown blockers | Blockers, distant culling off | Blockers, distant culling on |
| --- | ---: | ---: | ---: |
| Street | 4,080 draws | 1,902 draws | 1,884 draws |
| Aerial | 3,783 draws | 1,334 draws | 1,312 draws |

The distant-vehicle-only benefit was 18–22 draw calls, too small to demonstrate a reliable frame-time gain in these samples. Most savings came from other blocked geometry. Trying 100 m batches instead of 250 m increased submissions and did not consistently improve frame time; production keeps 250 m.

Before/after screenshots were byte-identical for both tested views. The traffic LOD regression passed with tier 3 enabled, including descent/promotion to a full vehicle, toggle propagation, and shutdown. Editor parsing passed. Existing user-directory/certificate/asset-UID warnings remain.

The previous audit's distant traffic CPU cost still needs separate simulation work. Rendering occlusion does not pause vehicle logic.

To repeat the comparison, run the existing `tests/profile_city_followup.gd` with `-- --traffic-occlusion` using a graphical Godot process. Results are in `artifacts/performance_audit/traffic_occlusion.json`.

## Files and cleanup

Changed: `scenes/super_city.tscn`, `scripts/traffic/traffic_box_lod.gd`, `tests/test_super_city_traffic_lod.gd`, `tests/profile_city_followup.gd`. Added runtime script: `scripts/traffic/traffic_occlusion_trial.gd`.

Removed 13 finished one-off scripts (and their UID sidecars where present):

- `artifacts/remove_street_props.ps1`
- `artifacts/check_rooftop_equipment.gd`
- `artifacts/render_performance_hud.gd`
- `artifacts/build_hair_fitting_scene.gd`
- `artifacts/inspect_hair_bind.gd`
- `artifacts/inspect_hair_lods.gd`
- `artifacts/render_hair_lod.gd`
- `artifacts/render_hair_lod_after.gd`
- `artifacts/render_hair_rear.gd`
- `artifacts/verify_character_folders.gd`
- `artifacts/window_trial/inspect_facades.gd`
- `artifacts/authored_combo/inspect_library.gd`
- `artifacts/authored_combo/render_combo.gd`

Reusable asset generators, regression tests, saved audit results and historical backup copies remain. The new comparison extends an existing profiler rather than adding another disposable helper.
