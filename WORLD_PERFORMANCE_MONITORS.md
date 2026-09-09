# World performance monitors

All five monitors live under `Main/PerformanceMonitors`. Each has an independent Enabled switch and Sample Interval (five seconds by default). The three new monitors collect only in debug builds and discard timing buckets after each sample. Disabling one skips its timing collection. Instrumentation adds some CPU overhead; it is for diagnosis, not a benchmark of an uninstrumented build.

## New logs

- `[CityPerf]`: city route-network rebuilding and walkable-area checks; graph size; player coordinates; engine-wide FPS, physics/render-frame ratio, physics time, draw calls, primitives, memory and object counts. Engine metrics describe the whole game, not just the city. Rendering cost cannot be assigned to a building or vehicle with these counters. Headless rendering counters are zero/unavailable.
- `[CrowdPerf]`: population manager and update, spawn attempts, full civilian physics, route following, lane spacing, stuck recovery, distant capsule movement, and LOD promotion/demotion. Includes actual full/capsule counts, following counts, statuses, pending removals/damage, and cumulative spawn/transition counters. A timing bucket's failures counts unsuccessful boolean operations, not engine errors. Walkable-area misses in CityPerf can be normal. Nested timings overlap and must not be added together. The old `plan_pass`, `ground_support`, and `detouring` fields were removed with detour planning.
- `[VehiclePerf]`: vehicle physics callbacks, damage and health-label updates; frozen, sleeping, awake, moving, carried, impact-armed and contact-monitor counts; visible health labels and active explosion effects. Includes vehicles reparented to the player when carried. Frozen vehicles can still execute scripts and be rendered. Engine physics-server and GPU time are not measured per vehicle.

## Test in Godot

Start Main, stand still for 10 seconds, then repeat the walk that caused the FPS collapse. Leave the crowd and vehicle display enabled for the baseline. Once FPS drops, wait another 10 seconds and stop the game. All five log prefixes appear in the normal Godot output/log file. Toggle the three new Enabled switches independently to verify control. Pick up and drop a vehicle to check the carried and frozen/awake counts.

For an isolation run, turn off `SuperCity/CivilianCrowd`'s Crowd Enabled setting, not just its performance monitor. Disabling a monitor does not disable the subsystem it observes.

## Changed files

- `scenes/main.tscn`
- `scripts/ui-scripts/city_performance_monitor.gd` (new)
- `scripts/ui-scripts/civilian_crowd_performance_monitor.gd` (new)
- `scripts/ui-scripts/vehicle_performance_monitor.gd` (new)
- `scripts/npc-scripts/city_pedestrian_network.gd`
- `scripts/npc-scripts/civilian_crowd.gd`
- `scripts/npc-scripts/civilian_capsule_lod.gd`
- `scripts/npc-scripts/routed_civilian.gd`
- `scripts/npc-scripts/capsule_civilian.gd`
- `scripts/vehicle.gd`
- `tests/test_world_performance_monitors.gd` (new)
- `WORLD_PERFORMANCE_MONITORS.md` (new)

The original monitor addition only added diagnostics. Ambient crowd movement now uses directional lanes and spacing as described in `CIVILIAN_LANES.md`.
