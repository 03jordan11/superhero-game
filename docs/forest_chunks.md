# Forest chunks

The retained highway/northern and coastal forests now use offline-baked 500 x 500 m cells. Cells containing fewer than six trees may pair with one face-adjacent cell (neighbor at most 12 trees, combined at most 16). These sparse pairs cover 1,000 x 500 m or 500 x 1,000 m. Empty cells create no geometry.

| Region | Original trees | Chunks | Full-detail triangles | Distant triangles |
| --- | ---: | ---: | ---: | ---: |
| Northern/highway | 973 | 33 | 79,224 | 17,932 |
| Coastal | 889 | 83 | 71,256 | 16,572 |
| Total | 1,862 | 116 | 150,480 | 34,504 |

Each chunk has two actual ArrayMesh resources, each with **one surface and one shared material**. Only one is visible at a time. FullDetail combines the original transformed vertices, normals and vertex colors. DistantProxy contains newly generated cone-shaped pine crowns or octahedral oak crowns and simple trunks, retaining the tree locations, sizes and colors. Distant shadows are disabled. This reduces distant triangle count by about 77%.

The 116 chunks replace up to 1,862 individual tree renderers. Those are geometry counts, not measured whole-frame draw calls or FPS: visibility, shadow passes and other city content still affect rendering. Larger meshes also have coarser culling. No FPS benchmark was run.

## Runtime nodes and tuning

- `SuperCity/CityLife/Highway/ForestChunks`
- `SuperCity/CoastalRegion/ForestChunks`

Expand either controller to see `Chunk_x_z/FullDetail` and `Chunk_x_z/DistantProxy`. Chunk roots are hidden in the editor so you can edit the original trees normally. They activate during play.

Distance is measured in 3D from the active camera to the **nearest point of the chunk's actual bounds**. Full detail switches to distant beyond 350 m; full detail returns inside 300 m. The 50 m switching margin prevents flicker. This uses bounds directly, without adding a chunk-center radius.

Inspector properties:

- **Enabled**: true renders chunks; false restores original individual trees. It is not a forest visibility toggle.
- **Force Lod**: Automatic, Full detail, or Distant proxies. Useful for checking replacement from a fixed camera.
- **Near Distance M**: 300 by default.
- **Switching Margin M**: 50 by default.
- **Max Distance M**: zero retains authored tree range limits (4,500 m north; 12,000 m coast), applied to the nearest chunk edge. Set a positive distance to override. The existing terrain/tree boundary trim remains intact.
- **Visibility > Visible**: while Enabled is true, hide the controller to hide that entire forest.

The original tree nodes are retained at their existing paths, but their renderers are hidden during batching. Use the new ForestChunks nodes to hide forests during play; the old source folders are for editing. Existing regional trees have no trunk collisions; no new physics bodies are added. Terrain, travel boundaries, backdrop wall and Central Park are unchanged by this pass. Resources remain resident: this is rendering LOD, not asynchronous asset streaming.

## Editing and rebuilding

Edit original trees in `scenes/city_life.tscn` or `scenes/coastal_region.tscn`, save, then run from the project folder:

```powershell
& 'D:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --script res://assets/trees/tools/build_forest_chunks.gd
```

The baker preserves authored placements and visibility. A tree count, pose, source mesh hash, visibility or range mismatch makes the controller retain the original trees rather than display stale baked placements. The region generators retain the chunk instances; rebake chunks after changing a generated forest. Baked scene and mesh resources are in `assets/trees/chunks/`; their JSON manifests record membership, source transforms, hashes and triangle counts.

## Validation and in-game check

Godot 4.7.2 checks passed:

- `tests/test_forest_chunks.gd`: all 1,862 trees covered once, 116 chunks, one surface per LOD, exclusive visibility, geometry bounds, 300/350 m switching, optional culling, original-tree restoration and stale-bake fallback.
- `tests/test_forest_boundary.gd`: existing terrain/tree boundary checks.
- `tests/test_tree_scenes.gd -- city_life coastal_region`: regional authored-tree checks.
- Parse checks for both regional generators and the loading-screen script.

Rendered highway original/full-detail and simplified views, plus coastal and high-flight views, were inspected. Captures are in `artifacts/forest_chunks/views/`. Automated scene captures are not a traversal playtest.

Restart Main and fly along the highway and coast. In the Remote scene tree, select the controller and compare Force Lod = Full detail versus Distant proxies. Return it to Automatic and approach/leave a forest section; detail should return near it. Toggle Enabled off/on to compare individual trees with batching, or Visible off/on to hide/show the forest. Watch for missing trees, unexpected placement changes or objectionable popping. No FPS measurements were collected.

## Files changed in this pass

- Added `scripts/forest_chunks.gd` and `assets/trees/tools/build_forest_chunks.gd`.
- Added `assets/trees/chunks/`: two scene files, two JSON manifests, a shared material and 232 mesh resources.
- Added ForestChunks instances in `scenes/city_life.tscn` and `scenes/coastal_region.tscn`.
- Updated `assets/city-life/tools/generate_city_life.gd` and `assets/coastal-airport/tools/generate_coastal_airport.gd` to retain those instances.
- Updated `scripts/ui-scripts/loading_screen.gd` status text to “Preparing distant scenery”; forest preparation joins the existing loading group.
- Updated `export_presets.cfg` to include forest JSON manifests in exports.
- Added `tests/test_forest_chunks.gd`; updated `assets/trees/README.md` and added this document.
