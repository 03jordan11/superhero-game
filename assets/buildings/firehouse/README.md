# Engine House No. 7

Original exterior inspired by the supplied old brick firehouse reference: four arched red engine doors, a tall offset hose tower, terracotta cornices and a stepped crown. The 1907 date and station name are fictional design details. Metre scale, no interior, vehicles, opening-door logic, trees or surrounding sidewalk. The asset is a standalone POI and is not placed in the main scene.

## Geometry and size

**1,520 triangles total:** 1,448 for the building and 72 for two independently instanced stone benches. The complete highest-detail asset is checked against the 10,000-triangle POI budget. The architecture GLB has 45 named mesh groups, with per-mesh counts in firehouse_manifest.json. The rear service door has a simple sandstone frame and a gap in the projecting foundation trim, keeping the doorway clear down to ground level.

One Blender unit = one Godot unit = one metre. Godot front is +Z; Blender front is -Y. Root origin is ground level. Full asset bounds including benches and trim are approximately **34.65 m wide x 23.705 m deep x 26.875 m tall**. The main roof is 13.68 m high. Main front wall is Godot Z=11; engine door faces and fixtures project slightly farther. Place it next to the existing street/sidewalk without adding a surrounding terrain slab.

Window sills, sash divisions, door grids and tower louvers are texture details. Garage arch outlines, cornices, parapets, piers and keystones use modest geometry for depth and silhouette. The roofs and building envelope have simple native box collision. Engine doors are closed exterior surfaces. Decorative wall lamps, cornices, downpipes, chimney and rooftop vents are not individually collidable.

## Files

| File | Purpose |
| --- | --- |
| firehouse.blend | Editable Blender source with packed textures and architecture, props and presentation collections. |
| firehouse.glb | Building export; no preview ground, camera or lights. |
| firehouse.tscn | Native scene with Model, ExteriorCollision and independent benches under Props. |
| firehouse_preview.tscn / firehouse_preview.gd | Standalone orbit inspection with the existing game sky. |
| firehouse.gd | Per-instance night emission following the game's day/night clock. |
| firehouse_brick.png | Dedicated repeating running-bond brick texture. |
| firehouse_details_albedo.png / firehouse_details_emission.png | 2x2 detail atlas and aligned glass-only night mask. |
| props/bench.glb / props/bench.tscn | Reusable 36-triangle stone bench with collision that follows the instance. |
| firehouse_manifest.json | Actual triangle counts, bounds, collision boxes and prop placements. |
| tools/build_firehouse.py | Rebuilds the Blender model, exports, textures and manifest. |
| tools/prepare_firehouse.gd | Rebuilds the native building and bench scenes after import. |
| tools/render_firehouse.gd | Captures front, engine bays, tower, rear and night views in Godot. |

Move or remove a bench under Props without editing the base GLB. Editing the bench scene updates its instances. Rebuild tools overwrite generated assets and authored placements; preserve manual changes before regenerating.

## Night lighting

Windows, engine-door glass and small wall fixtures illuminate only at night through day_night_cycle.night_lighting_changed. Painted sills, framing, louvers, brick and stone do not emit. Some room windows stay dark. Materials are duplicated per building instance, and an instance loaded at night immediately synchronizes. Exposed window_emission_energy defaults to 2.0 and controls both glass and fixture emission; standalone_night_amount permits isolated tests. The bare GLB has no clock script. Fixtures use emissive surfaces, with no added local lights.

## Preview and tests

Open firehouse_preview.tscn and press **F6**. Drag to orbit; wheel to zoom. **1** day, **2** sunset, **5** night, **6** dawn, **3** rear, **4** engine bays, **R** reset. Inspect the window trim, numbered garage arches, tower louvers and rear elevations; compare day and night.

With the player in a temporary test scene, verify that the four closed garage doors block movement and that the main and tower roofs support landings. Move a rear bench and confirm its collision follows. No player is included in the preview.

Rebuild and validate from the project root using installed executable paths:

```powershell
blender --background --python assets/buildings/firehouse/tools/build_firehouse.py
godot --headless --editor --import --path .
godot --headless --path . --script res://assets/buildings/firehouse/tools/prepare_firehouse.gd
godot --headless --path . --script res://tests/test_firehouse.gd --quit-after 1200
godot --path . --script res://assets/buildings/firehouse/tools/render_firehouse.gd
```

The imported-asset test counts every rendered mesh instance, matches the manifest, checks the hard budget, metre bounds, material coverage, absence of sill meshes, roof and closed-bay collision, independent bench collision, real clock day/night transitions, night spawn and per-instance lighting isolation. Actual Godot GPU renders are saved in artifacts/firehouse. These checks do not constitute a manual playtest of the superhero controller.
