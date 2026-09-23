# Editable tree scenes

`oak.tscn`, `pine.tscn`, `birch.tscn` and `willow.tscn` are individual, reusable tree scenes. Each root is the visible MeshInstance3D, so the tree itself is selectable. Instances share the original central-park mesh and material resources; no extra geometry or duplicated mesh assets were introduced. Oak/birch/willow remain 96 triangles each, pine 72.

## Editing in Godot

Open the scene that owns the placements:

- `scenes/central_park.tscn`: trees are under `Woodland` and its cell folders.
- `scenes/city_life.tscn`: trees are under `Highway/NorthernForest_...` folders.
- `scenes/coastal_region.tscn`: trees are under `CoastalForest...` folders.

Click a visible tree, or select an `Oak_...`, `Pine_...`, `Birch_...` or `Willow_...` entry in the Scene tree. Move/rotate/scale normally, press Delete to remove it, or Ctrl+D to duplicate. Save the owning scene. Drag a species scene from this folder into an existing forest cell folder to add a tree. In the park, trees may also be added directly under Woodland. Opening Main or SuperCity selects the larger instanced scene by default, so open the owning scene for direct tree editing.

The Inspector's `Trunk Collision Enabled` toggle defaults to true for newly placed trees. Park instances retain collision; existing northern/coastal instances retain their previous non-colliding behavior. `tree.gd` creates a shared capsule under the tree only when enabled. These transient collision children follow the tree and disappear when it is deleted; they are not independent scene edits. Disabled trees allocate no physics bodies, avoiding the project's Jolt body limit. There is no per-frame tree script.

Existing instances retain their previous visibility distances: park 1,600 m plus 150 m margin, northern forest 4,500 m, coastal forest 12,000 m. Northern and coastal forests now render through baked chunks during play (see below); their authored individual meshes remain available for editing and fallback. A newly dragged scene uses Godot's default unlimited visibility; set Visibility Range in the Inspector as appropriate.

## Saved edits and regeneration

The northern highway forest has a gradual density transition recorded in
`forest_transition.json`: tree deletions blend the dense highway band into the
sparser surrounding trees and feather its city-facing edge. Surviving trees keep
their original transforms, visibility and collision settings. The one-time
`tools/soften_northern_forest.cjs` script records every deletion and rejects
reapplication over later edits. These saved deletions survive regeneration.

The park, city-life and coastal generators still generate initial placement candidates deterministically, keeping their random sequences stable. For scenes marked `individual_tree_scenes`, the saved forest containers are then restored as the authoritative authored layout. Saved deletions, additions, transforms and tree property changes survive regeneration, including completely cleared forests. Keep new trees within the forest containers described above. This does not preserve manual edits to unrelated generated buildings, terrain or props.

`tools/tree_instances.gd` handles creation and restoration. `tools/convert_tree_batches.gd` was the one-time migration; do not rerun it on converted scenes. Original scene backups and transform records are in `artifacts/central_park/*before_tree_nodes.tscn` and `tree_conversion_baseline.json`.

## Validation and changed files

All 10,381 placements were checked against the pre-conversion transforms, species and visibility settings: 400 park, 4,943 northern, 5,038 coastal. Tree geometry remains 834,960 triangles across the three regions. The park remains 75,574 triangles at night / 74,174 by day. Runtime scene/node overhead increases; no before/after FPS benchmark was performed.

`tests/test_tree_scenes.gd` checks individual scene links and ownership, budgets, placement, collision toggling without inactive physics bodies, and saved move/delete/clear behavior in all three regions. The existing park traversal test checks active trunk collisions and 159 path probes. GPU park and regional renders are produced by `assets/central-park/tools/render_park.gd`.

Added this directory and `tests/test_tree_scenes.gd`. Updated `scenes/central_park.tscn`, `scenes/city_life.tscn`, `scenes/coastal_region.tscn`; their three generators; central-park triangle audit tools, rendering tool, README/audit and `layout.json`; and `tests/test_central_park.gd`. The park rebuild reserialized its native assets. Main and SuperCity were not edited. User changes outside the replaced tree batches were retained by migrating the existing regional scenes rather than regenerating those regions.

## Travel-boundary trim

The placed SuperCity boundary markers now have a saved 2 km backdrop buffer in `forest_boundary.json`. Trees outside the retained ground were removed: coastal forest 3,911 -> 889; northern forest remains 973. Terrain and collision are trimmed in both regional scenes and SuperCity's river-carved overrides. The existing restoration helper preserves these authored tree deletions. Both regional generators now clip generated ground to the saved envelope.

See `docs/forest_boundary_trim.md` for the full change list, geometry checks, visual limitations and rebuild notes. Historical counts above describe the earlier conversion, not the current layout.

## Forest rendering chunks

The remaining 973 northern and 889 coastal trees are baked into 116 chunks, based on 500 m cells with sparse neighboring cells paired. Each chunk has one full-detail mesh and one simplified distant mesh, each with one surface and a shared material. During play the controller hides the individual tree renderers and selects one chunk mesh. Original tree nodes remain editable in these scenes. Park trees use the separate landmark system.

After moving, adding, deleting, or changing the visibility of trees, save the scene and run `assets/trees/tools/build_forest_chunks.gd` with Godot's headless `--script` option. Changed placements or source geometry trigger a safe fallback to individual trees until rebuilt.

See `docs/forest_chunks.md` for scene paths, Inspector controls, switching distances, regeneration, validation and the complete changed-file list.
