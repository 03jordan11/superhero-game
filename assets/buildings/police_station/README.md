# Police station

Five-story precinct inspired by the user's tan masonry and blue window-band reference, extended vertically to five occupied levels. Original fictional PRECINCT 05 identity, a textured police shield, raised entrance tower, lower public entrance wing, rooftop radio mast and two separate stone benches.

## Budget and placement

**1,147 triangles total** at highest detail: 1,075 building triangles across 42 mesh groups, plus two 36-triangle bench instances. The native Godot scene's actual imported meshes are counted by `tests/test_police_station.gd`, including every prop instance. Hard POI limit: 10,000 triangles.

One Blender/Godot unit is one metre. Ground floor: 4.8 m; four upper floors: 4 m each. Main roof surface: 20.9 m; entrance tower coping: 23.74 m; radio mast tip: 27.2 m. Front is Godot +Z / Blender -Y, with the origin at ground level. Main body measures 36 x 24 m; full bounds including trim, entrance canopy and benches are 36.25 x 30.60 x 27.20 m.

Standalone exterior scene with closed doors, opaque glazing and no interior. No surrounding sidewalk or ground slab is included; align with the existing city sidewalks. Preview ground is excluded from the asset. The main scene and project settings are unchanged.

Window mullions, blinds and sill shadows are texture detail on single quads. The shield is one textured quad. Door surrounds and major silhouette features use simple geometry. Front and rear base bands stop clear of the doors.

## Files

| File | Purpose |
| --- | --- |
| police_station.blend | Editable Blender source with packed textures and separate architecture, props and preview collections. |
| police_station.glb | Building export, excluding benches and preview rig. |
| police_station.tscn | Placeable native Godot scene with Model, ExteriorCollision and Props. |
| police_station_preview.tscn / .gd | Standalone inspection scene with orbit controls and the game's day/night sky. |
| police_station.gd | Per-instance night emission synchronized to the existing day/night clock. |
| police_station_manifest.json | Triangle breakdown, bounds, collision shapes, roof checks and prop positions. |
| police_station_masonry.png | Tan coursed masonry. |
| police_station_windows_albedo.png / police_station_windows_emission.png | Blue window atlas and matching glass/blind illumination. Frames and sill shadows remain dark. |
| police_station_crest.png | Original gold/blue police shield. |
| police_station_lamps_emission.png | Wall-lamp illumination. |
| props/bench.glb / bench.tscn | Independent bench model and scene with collision. |
| tools/build_police_station.py | Blender builder with precinct-specific procedural textures and geometry. |
| tools/prepare_police_station.gd | Native scene and prop preparation after model import. |
| tools/render_police_station.gd | Actual Godot front, entrance, rear and night captures. |

The builder reuses the existing authoring utilities in `../bank_tools/geometry.py`; it provides its own materials and does not modify either bank. Rebuilding overwrites generated files and native placements; preserve manual changes before rebuilding.

## Lighting and collision

Windows and wall lamps emit only at night. Emitting materials are duplicated per building instance, synchronize on night spawn and respond to `day_night_cycle.night_lighting_changed`. `window_emission_energy`, `follow_day_night_cycle` and `standalone_night_amount` remain adjustable in the Inspector. There are no local light nodes or daylight emissions in the native scene. The bare GLB does not contain the clock script.

Main walls, closed doors, entrance canopy, roof, parapets, tower and rooftop equipment have native collision. The antenna and fine trim are decorative. Each bench is an independent scene under Props; moving it moves its collision.

## Preview and validation

Open `police_station_preview.tscn` and press **F6**. Drag to orbit, wheel to zoom, **R** reset, **3** rear and **4** entrance. **1** day, **2** sunset, **5** night, **6** dawn. Inspect all five rows of office windows, doorway trim, and window/lamp emission switching between day and night.

For a player test, instance `police_station.tscn` in a temporary test scene, approach both closed doors, land on the main roof and entrance wing, then move a bench and check that collision follows it. No player is included in the asset preview.

Commands from the project root using the installed Blender and Godot executable paths:

```powershell
blender --background --python assets/buildings/police_station/tools/build_police_station.py
godot --headless --editor --import --path .
godot --headless --path . --script res://assets/buildings/police_station/tools/prepare_police_station.gd
godot --headless --path . --script res://tests/test_police_station.gd --quit-after 1200
godot --path . --script res://assets/buildings/police_station/tools/render_police_station.gd
```

Validation passed: actual imported triangle total, metre scale, material assignment, absence of sill meshes, roof/door collision, movable prop collision, night spawn and independent day/night materials. Godot renders were inspected at front, rear, entrance and night; images are in `artifacts/police_station`. This was not a manual playtest of the superhero controller.
