# Harbor cargo and distant replacement

Main's `SuperCity/Waterfront/Harbor` is now one approximately **248 x 406 m** chunk, within the existing 500 m chunk size. Its current geometry is compact enough that splitting it further would add submissions without separating large areas. The cargo ship and boats retain their separate existing systems. City streetlights were not changed.

## Geometry

| Rendering state | Mesh surfaces | Mesh triangles |
|---|---:|---:|
| Original harbor | 494 | 7,704 |
| Combined nearby harbor | 2 | 7,704 |
| Simplified distant harbor | 1 | 1,296 |

These are geometry counts, not measured frame draw calls or FPS. Shadow passes and camera culling affect actual rendering. Two existing Label3D signs remain separately rendered nearby and are hidden at distance. Conservatively including their glyphs/outlines gives 7,864 nearby triangles, below the 10,000 complete-POI budget.

**CargoCombined** is one mesh with one material surface containing all **24 shipping containers and 12 small wooden crates**, including the original container ribs and door hardware. That replaces 372 original mesh surfaces with one surface even up close, preserving 4,464 triangles and all authored positions/colors.

**StructuresCombined** is one mesh with one surface containing the other 122 source meshes: cranes, office, signs' physical boards/posts, quay walls/railings, harbor lamp geometry, and concrete pier extension. Its material preserves the original world-aligned paving texture and warm/cool night emission.

**DistantProxy** replaces both nearby meshes. Container ribs and door bars become painted shader detail; small railing posts and masonry trim are omitted; cylinder pieces become simple boxes. Crane silhouettes, cargo stacks, office, major rails and pier footprint remain. Distant shadows are off. The two full-detail meshes and their originals do not render underneath the proxy.

Original visual nodes remain editable in the scene, but the controller hides them while its valid baked replacements are enabled. Collision bodies/shapes, transforms and disabled flags are unchanged, including each crate/container collider. Original harbor lights keep their existing day/night behavior and distance fade.

## Inspector controls

Controller: `Main/SuperCity/Waterfront/Harbor/HarborChunks`.

- `Harbor_0/FullDetail/CargoCombined`: combined nearby cargo.
- `Harbor_0/FullDetail/StructuresCombined`: combined nearby structures.
- `Harbor_0/DistantProxy`: simplified whole-harbor mesh.
- `Enabled = false`: restore original visual nodes and hide replacements.
- `Force Lod = Full detail` or `Distant proxies`: inspect either version from the same camera position. Automatic is the default.
- `Near Distance M = 300`, `Switching Margin M = 50`: proxy starts beyond **350 m from the nearest point on the harbor bounds**, and nearby meshes return inside **300 m**. This measures camera distance, not distance to the chunk center.
- Controller `Visible = false` hides replacement meshes and signs. It does not disable physics or light nodes.

## Files changed

- `scripts/harbor_chunks.gd`: harbor validation, labels and preparation; extends the existing riverbank controller for distance, night amount, original-visual restoration and loading progress.
- `assets/waterfront/tools/build_harbor_chunks.gd`: offline builder using Main's actual edited placements.
- `assets/waterfront/harbor_chunks/harbor_chunks.tscn`: controller and authored replacement mesh nodes.
- `assets/waterfront/harbor_chunks/CargoCombined.res`, `StructuresCombined.res`, `DistantProxy.res`: generated meshes.
- `assets/waterfront/harbor_chunks/material.tres`, `harbor.gdshader`, `inventory.json`: shared material/shader and source/count inventory.
- `scenes/super_city.tscn`: instances the new controller under Waterfront/Harbor.
- `export_presets.cfg`: includes the inventory JSON in exports.
- `tests/test_harbor_chunks.gd`: replacement coverage, near geometry, bounds, triangle budget, collision resources and physics rays, lighting, labels, distance hysteresis, toggles and stale-bake fallback.
- `tests/test_riverbank_chunks.gd`: disables the independent harbor controller when checking that riverbank switching doesn't change harbor visuals.

Rebuild after changing harbor source meshes, materials or placement:

```powershell
& 'D:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --script res://assets/waterfront/tools/build_harbor_chunks.gd --log-file artifacts/harbor_bake.log
```

The builder only writes its baked assets. It does not regenerate the waterfront or Main. Validation rejects changed authored geometry/materials/visibility at startup and retains originals until rebuilt. The bake targets Main's overrides; a differently configured standalone scene can deliberately fall back.

## Verification and playtest

Godot 4.7.2 parse checks and both harbor/riverbank chunk test suites passed. Automatic renders of originals, combined nearby meshes and distant replacements were inspected, including cargo colors, pier texture and night emission. Captures are under `artifacts/harbor_chunks/`. This was not a manual traversal playtest or FPS benchmark.

Restart Main and visit the harbor. Walk between crates, land on container stacks, and check the pier and cranes. Fly away beyond the switching threshold and return, watching for missing/doubled geometry. At night, check the office windows and harbor lamps. Use the Remote Inspector's Enabled and Force Lod controls above for direct visual/performance comparison, then restore Enabled/Automatic.
