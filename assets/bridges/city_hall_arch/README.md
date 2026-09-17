# City Hall arch bridge

Blender-authored twin tied-arch bridge installed as `SuperCity/CityHallBridge` in `scenes/super_city.tscn`. Design reference: [SteelConstruction.info tied-arch bridges](https://steelconstruction.info/sectors/bridges/tied-arch-bridges), with a simple red steel silhouette matching the southern suspension bridge and thin dark hangers.

## Dimensions and placement

- Connects existing road ends at world `(2, 0.03, -320)` and `(322, 0.03, -320)`.
- Complete crossing including approaches: 320 m; arch span: 180 m.
- Road: 28 m wide, with 4 m sidewalks on both sides.
- Raised central deck: 8.03 m; supports are outside the river promenades.
- Minimum measured underpass clearance across the tested curved promenade footprint: **6.675 m**.
- Existing city road shader and sidewalk material are reused.

Both river promenades retain their walking surfaces. Existing pedestrian route data still contains gaps at the former road crossing; route synchronization remains deferred with the wider road-network work. Physical clearance does not itself update NPC routes.

## Geometry audit

Actual exported/imported highest-detail geometry: **2,264 rendered triangles**, including every visible bridge component. Collision and Blender preview rig are excluded.

| Component | Triangles |
| --- | ---: |
| Road deck | 132 |
| Walkways | 264 |
| Arches | 428 |
| Tie beams | 72 |
| Hangers | 264 |
| Guardrails | 1,032 |
| Supports | 72 |

`triangle_audit.json` records the Godot mesh counts; `blender_geometry.json` records source counts. The complete bridge is below the requested 2,500-triangle target.

## Rebuild

Run from the project root, using the installed Godot and Blender executables:

1. `godot --headless --path . --script res://assets/bridges/city_hall_arch/tools/export_city_textures.gd`
2. `blender --background --python assets/bridges/city_hall_arch/tools/build_bridge.py`
3. `godot --headless --path . --editor --import`
4. `godot --headless --path . --script res://assets/bridges/city_hall_arch/tools/bake_scene.gd`

The Blender file includes packed reference textures and an export-excluded preview rig. Godot uses baked mesh resources and native collision shapes in `city_hall_bridge.tscn`.

## Validation

`godot --headless --fixed-fps 60 --path . --script res://tests/test_city_hall_bridge.gd --quit-after 20000`

Passed: imported triangle budget, road-end alignment, 750 surface/clearance probes, seven capsule crossings (road both directions, bridge sidewalk, and both river promenades in both directions), and inclusion in the main scene. Native Godot renders were also inspected. Manual player gameplay was not tested.

In Godot, inspect `SuperCity/CityHallBridge`, cross both road joins, walk the elevated sidewalk, and follow each river promenade beneath the bridge.
