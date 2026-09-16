# Medical Center — low-poly hospital

Original exterior inspired by the two supplied NewYork-Presbyterian / Weill Cornell photographs: pale limestone, a tall ribbed tower, stepped symmetrical wings, Gothic arched glazing and an open entrance court. This is an interpretation, not a surveyed replica. The entrance reads **MEDICAL CENTER**, with one teal H wayfinding sign on the viewer's left. No red cross symbol or photographic/map imagery is used.

## Files to use

**POI budget:** 10,000 triangles maximum. The hospital now meets it at **5,612 triangles**, after removing all 1,126 projecting sill boxes. The existing painted sill detail and all window panels remain. See [TRIANGLE_AUDIT.md](TRIANGLE_AUDIT.md) for the original breakdown and completed reduction.

| File | Purpose |
| --- | --- |
| `hospital.blend` | Editable Blender 5.2 source, UVs, packed textures, grouped architectural meshes and separate presentation rig. |
| `hospital.glb` | Portable Godot-ready mesh with embedded PBR textures, no preview cameras, lights or ground. |
| `hospital.tscn` | Recommended Godot instance: GLB, simple exterior collision, canopy collision, two entrance lights and automatic night emission. |
| `hospital_preview.tscn` | Standalone inspection scene using the game's existing sky/day-night cycle. |
| `hospital.gd` | Per-instance emission and entrance lighting, connected to `day_night_cycle.night_lighting_changed`. |
| `hospital_windows_emission.png` | 1024 × 1024 RGB emission atlas for room windows. |
| `hospital_curtain_emission.png` | 512 × 1024 RGB emission texture for tall arched glazing. |
| `hospital_manifest.json` | Geometry statistics, dimensions and collision source data. |

**Geometry:** 5,612 triangles, 25 mesh objects, 11 materials. Godot importer can generate mesh LODs. Metres, ground-level origin, **+Z is the entrance/front** in Godot (-Y in Blender). Bounds approximately **104.55 m wide × 131.80 m tall × 72.33 m deep**. Scale the scene root uniformly if a smaller city footprint is desired; adjust the two light ranges to suit.

The asset includes rear/side façades, roof parapets, rooftop mechanical units, two rounded front wings with full-width faceted glazing, a canopy, doors, one wayfinding sign and bollards. It is an **exterior asset** with opaque glazing; interiors and opening doors are not modelled. Collision uses boxes and two convex rounded-wing prisms, preserving the open courtyard and solid main rooftops. Small decorative trim, rooftop equipment and bollards are not individually collidable.

## Google Doc corrections — September 11, 2026

Applied all six items in the supplied [illustrated feedback](https://docs.google.com/document/d/1pL8fTHC1zhT78Ys_RdWtRG7cmRoIP1G4bhLn9vFcr9Q/edit?tab=t.0):

1. Removed room windows and sills beneath the front tower's projecting pillars. No albedo or emission faces remain behind them.
2. Removed both upper half-cylinder bays. Each remaining front bay is 18 metres wide, centered on its wing, extends from ground to the roof, and has a rounded roof/parapet. The rectangular wing starts at the rounded end's diameter, with no wider rectangular front exposed behind it.
3. Added reusable `canopy_glass_albedo.png` and `canopy_glass.tres`, with large blue glass panels and black framing. The canopy does not use the window/emission atlas. Entrance text is now **MEDICAL CENTER**.
4. Removed the viewer-right entrance sign, its lettering and its collider; kept the left sign.
5. Omitted room windows and sills obscured by the projecting side pavilions. The generator checks all candidate room windows against adjacent masonry before creating geometry; 160 additional obstructed windows are omitted across the model.
6. Removed the tower H sign and moved the six tall crown windows into the spaces between the pillars. Removed the previous small crown windows where the tall windows now sit.

The prior Blender/GLB/scene/generator files are preserved under `artifacts/hospital/before_doc_revision/` (excluded from Godot imports). The shared room-window atlas stays reusable; removing specific windows is done by omitting their geometry/UV usage, which removes both their colour and emission without changing other windows that share atlas cells.

## Reusable materials

Shared files are in `../materials/` so future buildings can use them:

| Texture / material | Mapping |
| --- | --- |
| `limestone_warm_albedo.png`, `limestone_warm_roughness.png`, `limestone_warm.tres` | Seamless 512² stone; hospital uses one UV repeat per 8 metres. Albedo is colour; roughness is non-colour data. |
| `windows_bluegray_atlas_albedo.png`, `windows_bluegray.tres` | 1024² atlas, 8 × 8 cells, 128 pixels per cell. Each cell includes a complete framed room window. |
| `curtain_glazing_albedo.png`, `curtain_glazing.tres` | 512 × 1024 curtain wall with 4 vertical panes and 12 horizontal floor modules. Hospital maps each bay facet across U 0–1 and V once per 24 metres. |
| `canopy_glass_albedo.png`, `canopy_glass.tres` | 512² skylight panel, tiled 4 × 3 across the entrance canopy; subtle blue glass with a black border, no emission. |

The standalone shared `.tres` materials have no hospital emission enabled. For another building, duplicate the room/curtain material, enable emission, assign its matching hospital emission PNG or author a new occupancy pattern, and use white emission colour with the map. Keep the albedo and emission UVs identical. In the room atlas, the hospital uses 3.5% inset UVs inside each cell to avoid bleeding. Black emission texels keep frames, spandrels and unoccupied rooms dark; lit texels contain warm or cool colour. Lettering and narrow canopy/bollard strips use a dedicated solid emissive material, so no image mask is needed for those mesh shapes.

All textures and geometry were authored procedurally in Blender for this asset. No external model, texture pack or third-party addon is required. The GLB embeds its own texture copies; changing external PNGs does not change an already exported GLB. Re-export from Blender after editing/reloading textures to update it. Packed Blender images should be reloaded/unpacked when replacing their external PNGs.

Godot's default importer also extracts working texture copies beside the GLB, prefixed `hospital_`. These are import-generated copies; the deliberately reusable source textures and `.tres` materials remain in `../materials/`.

## Use and test in Godot

1. Open `hospital_preview.tscn` and run it with **F6**.
2. Use **1 day**, **2 sunset**, **3 night**, **4 dawn**. Drag with the left mouse button to orbit; scroll to zoom. Inspect the clear pillar strips, relocated crown windows, rounded front wings, canopy glass, left-only entrance sign and side pavilion edges.
3. At night, selected windows, lettering and small strips illuminate; two warm lights brighten the entrance. Daylight fades their emission back to zero. The night textures represent a fixed occupancy pattern, not randomized or flickering windows.
4. Instance `hospital.tscn` in the level when choosing the hospital's location. It follows the existing clock automatically. Without a clock, set `standalone_night_amount` from 0 to 1. Tune `window_emission_energy`, `sign_emission_energy` and `entrance_light_energy` in the Inspector.
5. Test traversal onto the main roofs and canopy and through the open approach. Collision is deliberately simpler than the decorative mesh.

The preview's controls are confined to its own scene. The revised files retain the existing model and scene paths for reimport.

## Rebuild / validation

From the project root, with the installed executables on PATH:

```powershell
blender --background --python assets/buildings/hospital/tools/build_hospital.py
godot --headless --editor --import --path .
godot --headless --path . --script res://assets/buildings/hospital/tools/prepare_hospital.gd
godot --headless --path . --script res://tests/test_hospital.gd
godot --path . --script res://assets/buildings/hospital/tools/render_hospital.gd
```

The authoring script regenerates the authored model, textures and manifest; it will overwrite manual edits to those generated files. The preparation script rebuilds the native wrapper. GPU rendering writes day, night, courtyard, rear, crown, canopy, entrance and both side views to `artifacts/hospital/`; it uses the actual imported mesh and game sky. The Blender presentation render is saved there separately. Automated validation checks scale/orientation, material coverage, isolated instance emission, texture masks, entrance lights, removed objects/collision, rounded-wing collision and courtyard/rooftop collision.
