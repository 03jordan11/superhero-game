# Simple civilian lanes

Ambient pedestrians follow the existing validated sidewalk/crosswalk routes. Each spawn chooses a positive lane offset between Minimum Lane Offset and Maximum Lane Offset (0.55–1.4 m by default), relative to its travel direction. Opposite directions therefore favor opposite sides; existing waypoint validation narrows offsets where space is tight. These are preferred offsets from the route centerline, not guaranteed distances at every corner or narrow segment.

Every 0.2 seconds the crowd groups live walkers by directed route segment and sorts them by progress. Followers reduce speed to leave Minimum NPC Spacing plus a speed-dependent gap controlled by Following Time. Full civilians and distant capsules share this rule. The temporary dictionary and lists are released after each update; no historical records or extra nodes are retained. Route transitions and merges are intentionally approximate.

There is no passing search, obstacle lookahead sweep, or off-route ground-ray sampling in ambient movement. One footprint check against existing walkable rectangles keeps the next intended step within the route area. Ordinary character physics still handles collisions, gravity and sliding. Collision layers/masks and damage/flee behavior are unchanged. A prolonged blockage uses the existing cooldown-limited turnaround, walking toward the preferred lane in the new direction. Intentional crossing/spacing waits do not trigger recovery.

This deliberately gives up finding detours around people and parked cars. Sliding and occasional overlap are acceptable; a fully blocked route can make a pedestrian turn back. The system does not guarantee intersection-free crowds or passage through every narrow space.

## Inspector tuning

On SuperCity/CivilianCrowd:
- Minimum Lane Offset: 0.55 m default.
- Maximum Lane Offset: 1.4 m default. Both bounds can be tuned up to 3 m in the Inspector; route validation still pulls positions inward where needed. Changes affect newly spawned civilians; restart the scene to refresh the entire crowd.
- Minimum NPC Spacing: 1.6 m default, also used for spawn spacing.
- Spacing Update Interval: 0.2 seconds default.
- Following Time: 0.5 seconds default; larger values leave more room at walking speed.

## Validation

Headless checks: `test_civilian_lane_spacing.gd`, `test_civilian_route_pilot.gd`, `test_civilian_stuck_recovery.gd`, `test_civilian_crowd.gd`, `test_civilian_capsule_lod.gd`, and `test_world_performance_monitors.gd`.

In Main, repeat the area/route that previously slowed down for several minutes. Observe lane placement, following gaps, corner/crosswalk transitions, and blocked-route turnarounds. Test civilian sliding visually, including head-on contact; it is not covered by the automated checks. Approach distant capsules and hit a civilian to check representation transitions and existing reactions. Compare CrowdPerf walker_physics, route_step, lane_spacing and CityPerf walkable_area_check against the old run; plan_pass and ground_support should no longer appear. Headless tests do not establish visual quality or in-game FPS.

## Files changed for lane movement

- scripts/npc-scripts/routed_civilian.gd
- scripts/npc-scripts/civilian_crowd.gd
- scripts/npc-scripts/capsule_civilian.gd
- scripts/npc-scripts/pedestrian_journey.gd
- scripts/npc-scripts/civilian_capsule_lod.gd
- scripts/ui-scripts/civilian_crowd_performance_monitor.gd
- tests/test_civilian_lane_spacing.gd (new)
- tests/test_civilian_route_pilot.gd
- tests/test_civilian_stuck_recovery.gd
- WORLD_PERFORMANCE_MONITORS.md
- CIVILIAN_LANES.md (new)
