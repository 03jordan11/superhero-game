# bank2

Contemporary glass-and-steel bank tower, following the user choice of a modern tower rather than the historic high-rise in the second reference. Features a glazed banking podium, steel fins, two upper setbacks, a projecting entrance canopy and a sealed sloped crown.

## Geometry and placement

**1,896 triangles for the complete POI**: 1,824 building triangles and two independently placed 36-triangle benches. There are 32 architecture mesh groups. The highest-detail imported scene is checked against the hard 10,000-triangle limit, counting each placed prop instance.

One Blender unit = one Godot unit = one metre. Front is Godot +Z / Blender -Y. The root origin is at ground level. Full dimensions including trim and benches: **40.3 m wide x 34.29 m deep x 128 m tall**. The podium roof is 9.1 m high; upper terraces are 90.1 m and 112.1 m. The crown rises from 120 m to 128 m across its width.

This is a standalone exterior asset, with closed doors and opaque glazing. It includes no interior, vault, NPCs, interactions, surrounding sidewalk, ground slab or trees. The existing main scene and project settings are not modified. The doors reach ground level without a decorative base band crossing their faces.

Window sills and small window divisions are painted into textures. Major silhouette features use simple meshes. Materials and textures are specific to this bank, so rebuilding does not change hospital, City Hall or firehouse materials.

## Files

| File | Purpose |
| --- | --- |
| bank2.blend | Editable Blender source with packed textures and separate architecture, props and presentation collections. |
| bank2.glb | Exported building, excluding props and preview rigs. |
| bank2.tscn | Native Godot scene: Model, ExteriorCollision and Props. |
| bank2_preview.tscn / bank2_preview.gd | Standalone orbit inspection with the existing day/night sky. |
| bank2.gd | Per-instance night lighting, following the existing game clock. |
| bank2_manifest.json | Exported triangle totals, per-mesh breakdown, bounds, collision and prop placements. |
| bank2_stone.png | Procedural stone coursing. |
| bank2_windows_albedo.png / bank2_windows_emission.png | Window atlas and aligned glass-only emission mask. |
| props/bench.glb / props/bench.tscn | Separate stone bench with its own collision. |
| tools/build_bank2.py | Bank-specific Blender authoring script. |
| tools/prepare_bank2.gd | Rebuilds the native scene and reusable bench scene after import. |

Shared authoring helpers are in ../bank_tools/geometry.py. ../bank_tools/render_banks.gd captures both banks in actual Godot rendering. These are authoring tools, not game systems. Rebuilding overwrites generated source/export/texture/manifest files and native scene placements; preserve manual edits first.

Curtain-wall modules use textured spandrels and mullions, with warm and cool occupied offices in the nighttime mask. Broad steel fins retain depth while keeping the facade geometry low. On the ground-floor front facade, only the corner pillars remain; the two middle pillars have been removed. A generated clock texture is unused by this modern model.

## Props and collision

Each rear bench is a separate native instance under Props, so it can be moved or removed without changing the base model; collision follows the instance. Main walls, closed doors and roofs have native collision. The sloped crown has a matching convex collision hull; terrace edge rails and vertical fins are decorative. Small ornamental trim and rooftop equipment are decorative and not individually collidable.

## Night lighting

The wrapper duplicates emitting materials per instance and connects to day_night_cycle.night_lighting_changed. Office occupancy is a fixed pattern; there is no random flicker. Frames, painted sills and other opaque surfaces do not emit. Night spawn synchronizes immediately, and daylight sets intensity to zero. window_emission_energy defaults to 2.0; standalone_night_amount is available for a scene without a clock. The bare GLB has no clock script. No local light nodes are added.

## Preview and validation

Open bank2_preview.tscn and press **F6**. Drag to orbit; wheel to zoom. Keys: **1** day, **2** sunset, **5** night, **6** dawn, **3** rear, **4** entrance, **R** reset. Inspect all elevations and the entrance at ground level; compare day/night illumination.

In a temporary player test scene, walk toward the closed front and rear doors, land on the main roof , both setback terraces and the sloped crown, and move a bench to check its collision. No player is included in the preview.

Run from the project root, substituting installed executable paths:

```powershell
blender --background --python assets/buildings/bank2/tools/build_bank2.py
godot --headless --editor --import --path .
godot --headless --path . --script res://assets/buildings/bank2/tools/prepare_bank2.gd
godot --headless --path . --script res://tests/test_banks.gd --quit-after 1200
godot --path . --script res://assets/buildings/bank_tools/render_banks.gd
```

The test checks both complete imported scenes: actual triangle totals, manifest agreement, metre scale, materials, absence of sill meshes, roof and doorway collision, independent props, real clock transitions, night spawn and material isolation. Actual GPU renders are in artifacts/bank2. This does not constitute a manual playtest of the superhero controller.

