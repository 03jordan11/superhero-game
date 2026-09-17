# Northern river arch bridge

Blender-authored companion to the City Hall arch, placed at `SuperCity/NorthRiverBridge` on the road nearest the mountains. The root is `(195, 0, -960)`; road joins are `(116, .03, -960)` and `(274, .03, -960)`.

- Length: 158 m; road width: 20 m; sidewalks: 4 m each.
- Arch span: 152 m; arch rise: 22 m.
- **1,688 rendered triangles**, counted from imported Godot mesh buffers, including the road, sidewalks, arches, hangers, railings and supports. Collision is excluded.
- Reuses the City Hall road shader, asphalt texture, sidewalk material, graphite hangers/railings, and concrete material.
- Arch frame matches the southern suspension bridge: Blender linear RGB `(0.57, 0.075, 0.027)`, metallic `.32`, roughness `.73`.

The shorter crossing meets the existing roads at ground level. River promenades terminate at the city-side bridge walkway (world Z -946). Their geometry and collision across the road and toward the mountains have been removed. This bridge does not have City Hall's raised underpasses. Supports are outside the river paths. The river-edge railing terminates there as well. NPC and traffic routing remain deferred with the wider road-network update.

## Source and rebuild

`north_arch.blend` contains editable named meshes and packed reference textures. `tools/build_bridge.py` authors and exports the Blender model. It reads the same reference PNGs in `artifacts/city_hall_bridge` as City Hall; regenerate these with the City Hall `tools/export_city_textures.gd` tool if needed.

From the project root:

1. `blender --background --python assets/bridges/north_arch/tools/build_bridge.py`
2. `godot --headless --path . --editor --import`
3. `godot --headless --path . --script res://assets/bridges/north_arch/tools/bake_scene.gd`
4. `godot --headless --path . --script res://assets/bridges/north_arch/tools/open_river_railing.gd`

`river_railing.res`, `river_quay.res`, and `river_quay_collision.res` preserve the river frontage south of world Z -946. The river frontage scene references them. The cutting tool updates all three and can run again without extending the cut.

## Validation

`godot --headless --fixed-fps 60 --path . --script res://tests/test_north_river_bridge.gd --quit-after 20000`

Checks imported triangle count, both road joins, 390 deck/sidewalk probes, seven capsule traversals, matching frame colors on both arch bridges, the river-railing opening, and inclusion in the main scene. Godot renders were inspected; manual player gameplay was not tested.

In Godot, cross both road joins, walk the bridge sidewalk, and follow both city-side river paths onto the bridge walkway. City Hall's existing 750-probe/seven-crossing test also passes after recoloring, retaining its 6.675 m minimum underpass clearance.
