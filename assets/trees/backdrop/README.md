# Forest boundary landscape backdrop

`SuperCity/ForestBoundaryBackdrop` is one MeshInstance3D with **one surface, one material and 860 triangles**. Its rectangular panels follow the saved 2 km terrain cutoff, forming a single curved strip around the west, north and east sides. They taper into the coastline and leave open water unobstructed. The image shows distant hills and a treeline; the deleted terrain and trees remain deleted.

The backdrop has no collision, shadow casting, GI contribution or per-frame script processing. It receives normal scene fog and changes its material through the existing day/night signal. It is not used as an occluder and ignores occlusion culling, like the existing far mountain image. Normal depth testing still lets nearby terrain hide it. One surface does not guarantee exactly one draw call across every renderer pass.

## Adjust or replace

- In SuperCity, toggle `ForestBoundaryBackdrop` Visibility to compare it with the bare cutoff.
- `landscape.png`: editable 4096 x 512 landscape painting; transparent sky above the silhouette, opaque ground below.
- `landscape.res`: runtime texture with mipmaps, avoiding a new image import requirement.
- `landscape_material.tres` and `landscape.gdshader`: material, night tint and fog-compatible rendering.
- `landscape_wall.res` and `forest_boundary_backdrop.tscn`: mesh and reusable scene.
- `assets/trees/tools/build_boundary_backdrop.gd`: offline authoring. HEIGHT/BASE control the wall size; the shoreline taper is in `wall_vertex()`.

After editing/replacing the PNG, run the builder with `-- --use-existing-texture`. This preserves the PNG and refreshes the runtime texture, mesh and material. Running without that argument regenerates the procedural painting. The builder uses `assets/trees/forest_boundary.json`, not unsaved/live marker positions. If the boundary changes, rebake that configuration first.

Example from the project root:

```powershell
& 'D:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --script res://assets/trees/tools/build_boundary_backdrop.gd -- --use-existing-texture | Out-Host
```

## Validation

Godot 4.7.2 headless checks confirmed one mesh/surface, 860 triangles, no collision/shadows/per-frame processing, isolated material state, working day/night binding and all four existing terrain chunk sets still active. D3D12 captures were inspected from both coastal edges, the mountain approach, high flight and at night. The visible texture seam was moved into the omitted ocean arc. Captures and the validation script are in `artifacts/forest_boundary_backdrop/`.

This is a flat scenery illusion, not traversable terrain; very high or behind-the-wall views can expose its flat construction. Restart Main and view the coastal cutoff at your intended flight heights, then use `time night` to check the night blend. No FPS benchmark or manual gameplay traversal was performed.

Files added: this asset directory, `scripts/forest_boundary_backdrop.gd`, `assets/trees/tools/build_boundary_backdrop.gd`. `scenes/super_city.tscn` received only the resource reference and backdrop instance; its existing serialized content was preserved. A pre-addition scene copy is in `artifacts/forest_boundary_backdrop/super_city_before.tscn`.
