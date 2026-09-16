# bank1

Traditional stone bank inspired by the supplied ornate historic-bank reference and the user request for an older New York style. Features a projecting columned entrance, bronze doors, a grand arched window, cornices and a raised BANK sign. This is an original interpretation, not a replica or real bank brand.

## Geometry and placement

**1,082 triangles for the complete POI**: 1,010 building triangles and two independently placed 36-triangle benches. There are 38 architecture mesh groups. The highest-detail imported scene is checked against the hard 10,000-triangle limit, counting each placed prop instance.

One Blender unit = one Godot unit = one metre. Front is Godot +Z / Blender -Y. The root origin is at ground level. Full dimensions including trim and benches: **35 m wide x 32.15 m deep x 25.65 m tall**. Main roof is 20.1 m high; the raised sign crest reaches 25.65 m.

This is a standalone exterior asset, with closed doors and opaque glazing. It includes no interior, vault, NPCs, interactions, surrounding sidewalk, ground slab or trees. The existing main scene and project settings are not modified. The doors reach ground level without a decorative base band crossing their faces.

Window sills and small window divisions are painted into textures. Major silhouette features use simple meshes. Materials and textures are specific to this bank, so rebuilding does not change hospital, City Hall or firehouse materials.

## Files

| File | Purpose |
| --- | --- |
| bank1.blend | Editable Blender source with packed textures and separate architecture, props and presentation collections. |
| bank1.glb | Exported building, excluding props and preview rigs. |
| bank1.tscn | Native Godot scene: Model, ExteriorCollision and Props. |
| bank1_preview.tscn / bank1_preview.gd | Standalone orbit inspection with the existing day/night sky. |
| bank1.gd | Per-instance night lighting, following the existing game clock. |
| bank1_manifest.json | Exported triangle totals, per-mesh breakdown, bounds, collision and prop placements. |
| bank1_stone.png | Procedural stone coursing. |
| bank1_windows_albedo.png / bank1_windows_emission.png | Window atlas and aligned glass-only emission mask. |
| props/bench.glb / props/bench.tscn | Separate stone bench with its own collision. |
| tools/build_bank1.py | Bank-specific Blender authoring script. |
| tools/prepare_bank1.gd | Rebuilds the native scene and reusable bench scene after import. |

Shared authoring helpers are in ../bank_tools/geometry.py. ../bank_tools/render_banks.gd captures both banks in actual Godot rendering. These are authoring tools, not game systems. Rebuilding overwrites generated source/export/texture/manifest files and native scene placements; preserve manual edits first.

The large entrance window has dedicated bank1_great_window_albedo.png and bank1_great_window_emission.png textures for sharper detail. The clock has been removed from the front glazing. Every glass pane in the large entrance window illuminates at night; its frames remain dark. The split column entablature leaves the arched glazing unobstructed.

## Props and collision

Each rear bench is a separate native instance under Props, so it can be moved or removed without changing the base model; collision follows the instance. Main walls, closed doors and roofs have native collision. The entrance columns use convex collision; the roof parapets, canopy and raised crest are supported. Small ornamental trim and rooftop equipment are decorative and not individually collidable.

## Night lighting

The wrapper duplicates emitting materials per instance and connects to day_night_cycle.night_lighting_changed. Office occupancy is a fixed pattern; there is no random flicker. Frames, painted sills and other opaque surfaces do not emit. Night spawn synchronizes immediately, and daylight sets intensity to zero. window_emission_energy defaults to 2.0; standalone_night_amount is available for a scene without a clock. The bare GLB has no clock script. No local light nodes are added.

## Preview and validation

Open bank1_preview.tscn and press **F6**. Drag to orbit; wheel to zoom. Keys: **1** day, **2** sunset, **5** night, **6** dawn, **3** rear, **4** entrance, **R** reset. Inspect all elevations and the entrance at ground level; compare day/night illumination.

In a temporary player test scene, walk toward the closed front and rear doors, land on the main roof and the raised entrance crest, and move a bench to check its collision. No player is included in the preview.

Run from the project root, substituting installed executable paths:

```powershell
blender --background --python assets/buildings/bank1/tools/build_bank1.py
godot --headless --editor --import --path .
godot --headless --path . --script res://assets/buildings/bank1/tools/prepare_bank1.gd
godot --headless --path . --script res://tests/test_banks.gd --quit-after 1200
godot --path . --script res://assets/buildings/bank_tools/render_banks.gd
```

The test checks both complete imported scenes: actual triangle totals, manifest agreement, metre scale, materials, absence of sill meshes, roof and doorway collision, independent props, real clock transitions, night spawn and material isolation. Actual GPU renders are in artifacts/bank1. This does not constitute a manual playtest of the superhero controller.

