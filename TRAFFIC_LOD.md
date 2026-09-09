# Traffic LOD: full cars, silhouettes and distant rectangles

Implemented inside `SuperCity/TrafficManager/DistantTraffic`. The near-car tuning in SuperCity is preserved. Pedestrians and particle effects are unchanged.

## Inspector settings

Select **SuperCity -> TrafficManager -> DistantTraffic**. These are separate from the parent manager's full physics vehicle settings.

| Setting | Default | Meaning |
| --- | ---: | --- |
| Enabled | On | Enable both visual tiers and transitions. Switching off clears proxies and restores the original full-only population behavior. |
| View Distance | 900 m | Inner horizontal population area, including roads beneath high flight. Civilian capsules currently use 350 m. |
| Population Target | 160 | Desired visual population inside View Distance. Lower targets recycle excess proxies out of view. |
| Max Boxes | 240 | Base proxy capacity, including demotions; Far Max Proxies adds capacity when tier 3 is enabled. |
| Retention Margin / Retire Delay | 100 m / 2 s | Remove proxies after remaining outside the outer coverage radius + Margin for this long, including visible proxies beyond this boundary. |
| Terminal Recycle Delay | 15 s | A box at a road end with no straight continuation waits, then can recycle out of view. |
| Promote Distance | 150 m | Actual 3D distance for creating a full vehicle. |
| Demote Distance / Delay | 220 m / 1 s | Actual 3D distance and sustained time for replacing a full car with a box. Turns must finish first. |
| Approach Lead Seconds | 1 s | Expand promotion distance by focus speed times this value, capped at 150 extra metres. Includes vertical dives and preview-camera movement. Demotion stays at least 40 m beyond the effective promotion radius. |
| Interaction Guard Distance | 35 m | Hide a proxy this close if it cannot become physical. It waits and retries; it does not drive through the player as a visible ghost car. |
| Transition Interval | 0.1 s | Check for promotions and replenish demotion work budgets at this interval. |
| Transitions Per Check | 2 | At most two promotion attempts and two demotions per check. Failed physical placement consumes a promotion attempt. |
| Population Interval | 0.25 s | How often to attempt new distant spawns. |
| Spawns Per Update / Spawn Attempts Per Update | 4 / 20 | Bounded work per population band (inner and outer). At most four proxy retirements per tick overall. |
| Initial Spacing | 20 m | Extra gap when placing a new box behind another box. Existing followers retain their own chosen gap. This is spawn spacing, not per-frame avoidance. |
| Region Size | 250 m | MultiMesh region width. Restart to change it. |
| Body Height Ratio | 0.55 | Lower body occupies this fraction of vehicle height. Restart after silhouette edits. |
| Cabin Width / Length Ratio | 0.8 / 0.5 | Cabin dimensions relative to the full vehicle bounds. |
| Cabin Offset Ratio | -0.08 | Cabin position along vehicle length; negative moves toward the rear. Clamped to keep the cabin inside the vehicle bounds. |
| Window Brightness | 0.12 | Window-face tint multiplier; 0 is black. Body and roof retain the vehicle's paint color. |

Under **Very Distant Traffic (Tier 3)**:

| Setting | Default | Meaning |
| --- | ---: | --- |
| Far Enabled | On | Enable the outer population and flat rectangle representation. Turning off returns remaining proxies to silhouettes and retires those outside the original coverage using the normal delay. |
| Far View Distance | 1,800 m | Outer horizontal coverage radius, never smaller than View Distance. |
| Far Population Target | 200 | Additional population outside the original 900 m inner area. This avoids spreading the original 160 cars thinner. |
| Far Max Proxies | 320 | Additional capacity above Max Boxes: default total visual cap is 560. Movement across the radial boundary shares the combined cap; this is not a rigid per-mesh-tier limit. |
| Far Promote Distance | 800 m | Actual 3D distance inside which a rectangle becomes the car silhouette again. |
| Far Demote Distance | 1,000 m | Actual 3D distance beyond which a silhouette becomes a rectangle. Enforced at least 50 m beyond the effective Far Promote Distance; promotion stays outside the full-car approach radius. |

These form three representations: full cars nearby, body-and-cabin silhouettes at intermediate distances, and two-triangle horizontal rectangles far away. Between 800 and 1,000 m, a car keeps its current visual tier to avoid flicker. Altitude counts for mesh selection: directly below a player more than 1,000 m high, traffic can use rectangles even inside the inner horizontal population area. Population bands control where cars are seeded; they do not dictate which mesh a car uses.

The parent **Population Target** remains the baseline for newly spawned full cars. Promotions can use the headroom up to the parent's **Max Vehicles** (30 in SuperCity), including carried/released vehicles. Full cars above the baseline are retained until normal demotion/retirement. Visual proxies share a separate combined cap and do not consume physics-vehicle slots. A car has one traffic ID and one representation at a time; switching tiers does not duplicate it. Physical ownership references are pruned after queued deletion before their capacity is reused. Lowering caps may temporarily retain existing visible proxies above the new limit; new spawns and demotions respect the limit immediately.

At high altitude the manager stops creating fresh full vehicles on roads outside the 3D promotion radius. Existing distant full cars demote. The visual population stays spread across the horizontal road area rather than shrinking to nothing beneath the player. Initial population takes roughly ten seconds for 160 inner slots and at least 12.5 seconds for 200 outer slots at the default work budgets, possibly longer where placement fails. New distant proxies may appear in view; near full-scene spawns still use the existing offscreen rule. Camera clipping and city geometry still determine what is actually visible.

## Movement and appearance

- One shared ArrayMesh combines a low rectangular body and smaller rear-offset cabin. Dark cabin faces represent the windshield, rear window and side windows; the roof and body retain the vehicle paint. It has 22 triangles in one surface with one material, replacing the original 12-triangle box. No additional per-car nodes or rendering regions are added.
- Per-instance scale and color still use regional MultiMeshInstance3D nodes. No per-proxy physics bodies, health labels or collision queries. The silhouette is generated once at startup from the Inspector proportions; restart to rebuild it.
- Tier 3 uses one shared horizontal PlaneMesh with two triangles, the vehicle footprint and paint color, and the same material as the silhouette. It has no cabin, windows, wheels or shadow. Each region has a separate batch for each visual mesh it currently contains; empty batches are hidden and freed when cars switch tiers or leave.
- Bounds are measured once per vehicle entry from its existing scaled MeshInstance3D, without adding the scene to the tree. The box color comes from that entry's Distant Color. Full meshes/materials are untouched.
- Road lanes and straight-ahead junction connections are cached once at startup. Boxes keep lane, progress, scene entry, ID and sampled driver settings in small manager-owned records.
- Distant movement uses a common speed halfway between the parent's minimum and maximum cruise speed. It accelerates toward that speed after demotion. No turns, obstacle stopping, junction reservation, honking or neighbor searches occur in box simulation. Cross traffic may overlap.
- Only aligned straight connections are followed. At a genuine road end or turn-only junction, a box stops and recycles once out of view and its timer has elapsed. There is no visible teleport/wrap through buildings.
- Regions hold their own visibility bounds and share the meshes/material. Capacity grows only when a batch needs more instances. Shadows are disabled on both visual tiers. Rendering still updates each proxy transform; tier 3 reduces per-car geometry from 22 triangles to 2, while the additional coverage/population and batches still have CPU/rendering costs. No shader-driven movement or lower simulation frequency was added.

## Transition protection

Promotion preserves the exact scene entry/color, logical identity, road position, speed, sampled following gap and sampled intersection speed. It may create a scene in view because that scene replaces an existing box. Physical space and full-car spacing are checked before creation. A box already crossing straight can promote in place if it can acquire the junction; the full car retains its progress and releases the junction after its rear clears.

Switching between silhouettes and rectangles changes only the mesh batch. It uses the same record, color, lane and progress, including during a straight intersection crossing. There is no respawn or new physics body. A fast approach or teleport can promote a rectangle directly to a full vehicle using the existing space checks and work budget; it need not wait for an intermediate silhouette stage.

Unsuccessful promotions wait at their current position and retry with bounded work. Close blocked/cap-limited boxes are hidden inside the interaction guard distance. With the hard cap exhausted by carried/dropped cars, some near boxes can remain waiting until capacity returns; abandoned cleanup can free those slots. This fallback preserves the hard cap rather than creating unlimited physical cars.

Full vehicles finish turns before demotion. Damaged cars remain full so health state is not discarded; ordinary full-car retirement still applies to them. Picked-up or thrown vehicles leave traffic as before and never enter the box tier. Their existing abandoned cleanup applies independently. No focus pauses box motion/spawning; disabling traffic clears boxes while the existing full-car shutdown and abandoned cleanup handle physical cars.

## Performance monitoring

The existing VehiclePerformanceMonitor reports `boxes` (all visual proxies), `box_regions` (region/mesh batches), `box_promotions`, `box_demotions`, `blocked_box_promotions` and `hidden_nearby_boxes`, alongside full-car counts. It also reports rendered `silhouettes`, `rectangles`, `rectangle_to_silhouette` and `silhouette_to_rectangle` transitions. Fresh spawns are excluded from those mesh-transition counters. Silhouettes + rectangles + hidden nearby proxies equals total proxies. `traffic_box_simulation` and `traffic_box_render_update` timings are nested within `traffic_manager`; do not add overlapping timings together. These are CPU timings, not measurements of GPU rendering time.

## Validation and manual tests

- `tests/test_traffic_box_lod.gd`: batching/bounds, visual motion through a distant obstacle, exact handoff, blocked/full-cap promotion, carry protection, straight-junction handoff, dive lead, high-altitude population and record/region cleanup.
- `tests/test_super_city_traffic_lod.gd`: actual city coverage, physical promotion on a real road after descent, and shutdown. Default mode isolates tier 2; `-- --tier3` enables all three. Add `--capture` to save city and close representation previews to the system temp directory; use a rendering-capable run for capture. Close previews intentionally retain distant representations for inspection.
- `tests/test_traffic_far_lod.gd`: rectangle mesh/batching, stable identity/color/position, distance hysteresis, crossing continuity, direct full-car promotion, separate inner/outer coverage, combined caps, repeated relocations and disabling.
- Existing full-traffic fixtures explicitly disable DistantTraffic to isolate their movement/intersection/cleanup/range checks.
- A D3D12 Forward+ test run rendered 160 boxes in 27 regions, with 54 boxes in the camera frustum, and passed descent promotion. The screenshot was inspected for colored boxes on roads. This is not a gameplay FPS benchmark or full visual verification of every transition.
- After the silhouette update, the D3D12 city run and transition tests passed again. Close and city-wide screenshots were inspected for the painted body/roof, dark windows and two-part profile. LOD distances and population settings were unchanged.
- The three-tier D3D12 run rendered 161 silhouettes and 198 rectangles across 65 batches, with traffic reaching about 1.8 km. City and close rectangle previews were inspected. These checks establish rendering/transition behavior, not a gameplay FPS improvement.

In Godot:

1. Restart Main. Walk near traffic and confirm the near-car behavior still feels the same.
2. Fly 400–600 m high and wait roughly ten seconds. Look across several blocks: small colored boxes should move on roads well beyond pedestrian coverage, including beneath you.
3. Fly toward a particular box, then descend quickly. It should become the corresponding full vehicle before you interact. Check paint, placement and sudden speed changes visually, including when it crosses an intersection.
4. Ascend again and watch full cars become boxes. Cars already turning should complete their turn first. Carry and throw a car to confirm it stays physical.
5. Fly several kilometres or turn off Traffic Enabled. Watch the monitor's box/region counts retire rather than continually accumulate. Disabling DistantTraffic alone clears the box tier.
6. Start by adjusting View Distance and Population Target if the sky view looks sparse. Raising distance spreads the same population more thinly. Compare FPS and monitor timings on the same route before raising caps substantially.
7. Allow 15–20 seconds for the outer population, then fly high and look over roads more than a kilometre away. Approach one: it should become a silhouette inside 800 m and a full car at the existing near threshold. Move back out past 1,000 m to check the reverse mesh switch. Also try a fast dive, watch the per-tier monitor counts, and compare Far Enabled on/off on the same route.

## Files changed for this tier

- New: `scripts/traffic/traffic_box_lod.gd`, `scripts/traffic/traffic_proxy_mesh.gd`, `tests/test_traffic_box_lod.gd`, `tests/test_super_city_traffic_lod.gd`, `TRAFFIC_LOD.md`.
- Updated integration: `scripts/traffic/traffic_manager.gd`, `scripts/traffic/traffic_vehicle_entry.gd`, `scenes/vehicles/traffic_manager.tscn`, `scripts/ui-scripts/vehicle_performance_monitor.gd`, `TRAFFIC_README.md`.
- Updated fixture isolation: `tests/test_traffic_manager.gd`, `tests/test_super_city_traffic.gd`, `tests/test_traffic_intersections.gd`, `tests/test_traffic_population.gd`, `tests/test_traffic_abandoned_cleanup.gd`, `tests/test_traffic_driving_ranges.gd`.
- Third-tier update: `scripts/traffic/traffic_box_lod.gd`, `scripts/ui-scripts/vehicle_performance_monitor.gd`, `tests/test_traffic_box_lod.gd`, `tests/test_super_city_traffic_lod.gd`, new `tests/test_traffic_far_lod.gd`, this guide and `TRAFFIC_README.md`.
