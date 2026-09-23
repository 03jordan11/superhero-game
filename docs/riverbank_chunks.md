# Riverbank chunks

This pass covers `SuperCity/Waterfront/Riverbanks` in Main. Harbor is unchanged. The separate MountainRiver water/bed is already combined geometry and is not part of this prop batch.

## What renders

The current city overrides leave 105 source mesh surfaces visible: 30 lamps (post, housing and lens) and three seawalls (wall, coping and three masonry courses). The other old river walls, foam and railings stay hidden. They are not counted as active savings.

| Representation | Surfaces for the entire category | Triangles |
|---|---:|---:|
| Original visible geometry | 105 | 2,700 |
| Combined nearby chunks | 11 | 2,940 |
| Simplified distant chunks | 11 | 1,248 |

Each chunk is **one MeshInstance3D with one material surface**, at either detail level. These are geometry inventory counts, not measured frame draw calls or FPS. Camera culling and shadow passes affect actual rendering. No FPS comparison was run.

Seven seawall sections are each at most 500 m long; shorter sections meet wall endpoints without filling the river mouth or harbor entrance. Four 500 x 500 m grid cells group the riverside lamp assemblies. Nearby geometry retains the original shapes and vertex colors. Splitting long walls introduces closed end caps, explaining the small increase in near triangles in exchange for independent chunk culling.

Distant walls retain their wall and coping silhouettes but paint the three masonry courses in the shared shader instead of drawing protruding bars. Distant lamp poles use simple boxes instead of cylinders. Distant shadows are disabled. One representation per chunk is visible at a time; editable original mesh nodes are hidden during play, not drawn underneath the replacements.

## Distance and controls

Controller: **`Main/SuperCity/Waterfront/Riverbanks/RiverbankChunks`**. Its 11 authored child chunks are visible in the scene tree, with `FullDetail` and `DistantProxy` mesh children. Baked chunks start hidden in the editor so original meshes remain editable.

- Automatic switches to the proxy beyond **350 m from the camera to the nearest point of the actual chunk bounds**. It returns to full detail inside **300 m**. The 50 m margin prevents rapid toggling at one threshold.
- Inspector `Near Distance M` and `Switching Margin M` tune those thresholds.
- `Force Lod`: Automatic, Full detail or Distant proxies. Forcing full detail still uses the combined nearby meshes.
- `Enabled = false` restores original geometry and hides both baked representations.
- Controller `Visible = false` hides the replacement geometry while enabled. This does not turn off the original light nodes or collisions.

Original collision nodes, shapes, disabled flags and transforms are untouched. The 30 original lights retain their clock, brightness and existing distance fade. Baked lamp lenses follow the same night amount and waterfront brightness. The controller participates in the loading screen's existing scenery-preparation group.

The bake records effective visibility, transforms, geometry and materials. If those authored inputs change, startup retains the original visuals and prints a stale-bake warning until rebuilt. It does not continuously rebuild while playing.

## Changed files

- `scripts/riverbank_chunks.gd`: validation, visibility replacement, nearest-bound distance switching, night emission and restoration.
- `assets/waterfront/tools/build_riverbank_chunks.gd`: offline builder using Main's final authored overrides, not the obsolete standalone river layout.
- `assets/waterfront/chunks/riverbank_chunks.tscn`: authored controller and 11 pairs of mesh nodes.
- `assets/waterfront/chunks/*.res`: 22 generated near/far meshes.
- `assets/waterfront/chunks/material.tres` and `riverbank.gdshader`: shared colors, painted masonry and night emission.
- `assets/waterfront/chunks/inventory.json`: source validation and geometry counts.
- `scenes/super_city.tscn`: instances RiverbankChunks below Waterfront/Riverbanks.
- `export_presets.cfg`: includes the inventory JSON in exported builds.
- `tests/test_riverbank_chunks.gd`: coverage, seams, bounds, replacement, switching, restoration, lighting, collision preservation, Harbor preservation and stale-bake fallback.

Rebuild after editing source riverbank placement/geometry:

```powershell
& 'D:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --script res://assets/waterfront/tools/build_riverbank_chunks.gd --log-file artifacts/riverbank_bake.log
```

The builder updates only the chunk assets. It does not regenerate Main or the original waterfront scene. It refuses unhandled visible geometry so new props cannot silently disappear.

## Validation and in-game checks

Godot 4.7.2: riverbank chunk tests, existing benches/railings tests and regional proxy tests pass. The changed GDScripts parse. Original/near/proxy renders were inspected for wall shape and color, distant appearance and day/night lamp emission. Screenshots are under `artifacts/riverbank_chunks/`. This was automated rendering, not a manual traversal playtest or FPS benchmark.

1. Restart Main, then walk along the south seawall and the riverside lamps. Check wall ends, river-mouth openings and collisions.
2. Fly away and return: expect distant replacement beyond 350 m from each chunk's edge and near detail back inside 300 m. No missing sections or doubled walls should appear.
3. In the Remote Inspector, select the controller above. Toggle `Enabled` for originals versus chunked rendering, or use `Force Lod` to inspect both replacements from the same position. Restore Enabled/Automatic afterward.
4. At night, check the lamp lenses and their illumination. Nearby lights should behave as before.
