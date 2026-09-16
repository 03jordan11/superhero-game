# Simplified distant traffic

## Population and behavior

- The default combined distant population target and capacity is **40**: 24 in the inner distant coverage area, 16 in the outer area. Graphics density/distance presets can lower this. Actual counts may temporarily be lower while spawning or promoting cars. Nearby interactive traffic retains its original target.
- Proxies travel at a constant assigned cruise speed and continue straight through intersections. They ignore red lights, stop signs, queues, other cars and physical obstacles. Cars may visually cross through each other by design.
- Initial spawn spacing is retained. Cars stop at genuine route ends and recycle when out of view, instead of continuing off-road.
- Lane/crossing state advances at **10 Hz** for silhouettes and **5 Hz** for the farthest rectangles. Lightweight linear position prediction between updates keeps motion continuous without delayed handoffs.
- Distance-based promotion still checks promptly, including a speed-based approach margin for fast flight. Cars finish an active crossing before entering full traffic rules. A full vehicle only spawns if its physical collision area is clear and capacity is available. Blocked close proxies are held/hidden as before.
- Nearby cars still respect signals, following gaps, junction reservations and obstacle collisions. Carried, thrown and damaged cars retain their existing rules.

## Work reduced

- Removed all distant intersection queue construction/sorting and traffic-control checks.
- Moved retirement/population counting to the transition cadence instead of every physics tick.
- Cache distances before promotion sorting; do not calculate positions repeatedly inside its comparator.
- Cache spawn lane candidates until the focus moves 40 m or coverage/settings change.
- Cache render batch membership until IDs, visibility, regions or detail tiers change. Write colors only when that membership changes.
- Reuse each proxy's calculated render position within the draw update. Transform and conservative bounds updates remain lightweight per-physics-tick work for smooth movement and correct culling.

## Inspector tuning

On `SuperCity/TrafficManager/DistantTraffic`:

- `population_target`, `max_boxes`: inner distant target/cap (24).
- `far_population_target`, `far_max_proxies`: additional outer target/cap (16).
- `movement_interval`, `far_movement_interval`: lane state update intervals (0.1 / 0.2 seconds).
- `transition_interval`: promotion and population/retirement checks (0.1 seconds).
- `promote_distance`, `approach_lead_seconds`: when vehicles become interactive.
- `occlusion_culling_enabled`: comparison switch for distant rendering.

## Validation and files

Regression coverage includes red-light/stop-sign bypass for distant cars, normal signals for physical cars, smooth motion commits, blocked/capped promotion, crossing completion before promotion, flight approach lead, both visual tiers, settings scaling and cleanup. The city test checks that all ten occluders have valid source geometry.

Gameplay: drive/fly around the city, descend toward a distant vehicle, and pick it up. Watch for jumps during detail changes. Confirm the HUD distant count remains at or below 40 on default high settings and nearby traffic still queues normally. At long distance, overlapping traffic is intentional.

Runtime changes: `scripts/traffic/traffic_box_lod.gd`, `scripts/city_occlusion.gd` (replaces `scripts/traffic/traffic_occlusion_trial.gd`), `scenes/super_city.tscn`.

Validation changes: `tests/test_city_occlusion.gd`, `tests/test_city_traffic_controls.gd`, `tests/test_traffic_box_lod.gd`, `tests/test_traffic_far_lod.gd`, `tests/test_super_city_traffic_lod.gd`, `tests/test_population_settings.gd`, `tests/test_traffic_manager.gd`, `tests/profile_city_followup.gd`. The full-vehicle test's obsolete fixed lane count was replaced with a nonempty paired-lane assertion; its driving, obstacle and interaction assertions remain.

The existing profiler supports `-- --city-occlusion` for live traffic measurements plus fixed street/aerial/park/airport culling comparisons. Its current output is `artifacts/performance_audit/city_occlusion.json`.

## Measured result

The current 1600×900 daytime street sample had 40 distant and 20 nearby vehicles. Traffic-manager CPU time averaged **0.86 ms per physics tick**, with nested distant simulation **0.22 ms** and visual updates **0.20 ms**. The earlier audit measured about 5.3 ms for the manager with roughly 360 distant cars. This is a combined population/code improvement across separate runs, not an isolated same-population speedup or a promised FPS gain.

With actors frozen for matching rendering comparisons, enabling the regional occluders reduced draw calls from 4,066 to 1,891 in the street view, 3,718 to 1,295 in the aerial view, and 3,205 to 2,341 in the park view. The open airport view stayed at 833 draws: little is hidden from that angle. Street, aerial and airport before/after screenshots were byte-identical; the park views were also inspected visually. No collision geometry was edited.

Existing user-directory, certificate and asset-UID warnings appeared in the validation environment.
