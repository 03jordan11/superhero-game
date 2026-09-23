# Forest and terrain boundary trim

The user's placed Highway and Coastal markers in SuperCity define a conservative convex envelope. A **2,000 m backdrop buffer** extends outside that envelope. Rounded corners use supporting planes, so no part of the requested buffer is cut away. Marker coordinates and clipping planes are saved in `assets/trees/forest_boundary.json`.

## Removed from the loaded scenes

| Item | Before | After |
| --- | ---: | ---: |
| Coastal tree instances | 3,911 | 889 |
| Northern tree instances | 973 | 973 |
| River-carved coastal terrain triangles | 52,883 | 24,203 |
| River-carved northern ground triangles | 6,961 | 6,895 |
| Beach-wash triangles | 486 | 136 |
| Coastal terrain render tiles | 480 | 24 |
| Northern terrain render tiles | 384 | 51 |

All 973 northern trees are inside the buffer. Northern ground extended to Z=-16,000; it now ends around Z=-5,118. Coastal ground previously extended 30 km west, east and north; its retained bounds are approximately X=-6,600 to 4,807, Z=-5,118 to 1,952. These are mesh bounds, not new rectangular walls. A large northern ground area had very few triangles, explaining its small triangle reduction despite the large area removed.

Removed 3,022 coastal tree instances, including five whose crowns overlapped the cutoff but whose roots would have been outside the retained ground. Removed nodes and positions are recorded in `assets/trees/forest_boundary_report.json`. Surviving tree transforms, materials, visibility and collision settings are preserved. Individual tree rendering is still in use; this pass does not create forest proxy meshes.

Both regional terrain resources and SuperCity's carved terrain overrides are clipped, with matching collision. Nearby river cuts, airport, mountain meshes, roads, city geometry, ocean and the cheap distant mountain image remain. The original authoring mesh files remain on disk for recovery, but the scene references use the trimmed copies. Unused original collision shapes were removed from the regional scene files. Existing terrain render-tile bakes were rebuilt against the trimmed sources so culling continues to work.

## Validation and visual limits

- Godot 4.7.2: boundary checks pass for the full buffer, all retained terrain vertices, matching collision faces, original non-degenerate interior triangles, removed tree paths and grounded tree origins.
- Regional tree checks pass for all 1,862 surviving northern/coastal instances, including saved edit/deletion/empty-forest restoration.
- Coastal airport suite passes: retained/removed terrain collision, runway/access road, flights and lighting.
- Mountain river suite passes: original mountain geometry/collision, 76 mountain probes, 140 open-channel probes and 805 remaining river triangle probes.
- City occlusion suite passes with current source hashes and render tiles. Both regional generator scripts parse successfully.
- Four graphical D3D12 captures were inspected in `artifacts/forest_boundary_trim/views/`. No manual traversal or FPS benchmark was performed.

The outer ground edge is visible from elevated coastal viewpoints with the current camera/fog. The 2 km buffer is a chosen scenery budget, not proof of invisibility. Camera range, fog, flight height and player collision boundaries have not been changed. Markers still do not prevent the player from travelling past them. Test by restarting Main and flying toward each planned coastal/highway boundary, looking outward at normal and high flight heights.

The unfiltered historical tree suite still has a pre-existing Central Park count mismatch; park trees were untouched. Use `tests/test_tree_scenes.gd -- city_life coastal_region` for this pass. The river test was updated to read terrain before/after the existing render-tile substitution and inspect the river mesh children actually present, rather than assuming the previously removed Rock node.

## Files changed

- Scenes: `scenes/super_city.tscn`, `scenes/city_life.tscn`, `scenes/coastal_region.tscn`.
- Baked terrain/collision: `assets/trees/boundary_terrain/*.res` (five meshes, four collision resources).
- Cut configuration/audit: `assets/trees/forest_boundary.json`, `assets/trees/forest_boundary_report.json`.
- Authoring tools: `assets/trees/tools/forest_boundary_clip.gd`, `bake_forest_boundary.gd`, `apply_forest_boundary.py`.
- Generator hooks: `assets/city-life/tools/generate_city_life.gd`, `assets/coastal-airport/tools/generate_coastal_airport.gd`.
- Terrain culling bake: `assets/occlusion/build_terrain_chunks.gd`, `assets/occlusion/terrain/*.scn`, `assets/occlusion/terrain/audit.json`.
- Checks: `tests/test_forest_boundary.gd`, `tests/test_tree_scenes.gd`, `tests/test_coastal_airport.gd`, `tests/test_mountain_river.gd`.
- Notes: `assets/trees/README.md`, `docs/forest_boundary_markers.md`, this document.

## Recovery and future edits

Pre-trim scenes and a byte-preservation audit are in `artifacts/forest_boundary_trim/before/` and `scene_edit_audit.json`. Except for terrain resource references, collision references, tree-count metadata and removed coastal tree blocks, scene nodes retain their serialized contents. The original source terrain resource paths/hashes are recorded in the report.

The offline bake/apply scripts guard against overwriting the existing report/backups. Do not rerun a whole-city generator to change the cutoff. Rebuild from the original source terrain and saved pre-trim tree placements when expanding the envelope; already trimmed scenes cannot restore removed trees. After changing terrain outputs, rebuild `assets/occlusion/build_terrain_chunks.gd` so its source hashes and tiles match. Marker movement alone does not alter the saved clipping configuration.
