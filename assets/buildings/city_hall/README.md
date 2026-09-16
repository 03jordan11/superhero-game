# City Hall

Exterior-only, metre-scale civic landmark inspired by the supplied Pennsylvania Capitol references. No interiors, statues or trees. The main scene is not modified by the asset builder.

## Current geometry

| Component | Triangles |
| --- | ---: |
| Building, stairs and retained garden terraces | 5,490 |
| Six stone tables | 216 |
| 24 stone benches (12 dining benches and 12 standalone benches) | 864 |
| 14 textured hedge rows | 168 |
| **Furnished site total** | **6,738** |

The previous revision used 23,008 triangles. This revision removes 16,270 triangles (70.7%). The hospital reference asset uses 19,124 triangles.

Each table and bench uses three rectangular boxes: one slab and two supports, totaling 36 triangles. Each hedge is one 8 m long, 1.2 m deep, 1.3 m high textured box (12 triangles). All 44 props are independent scene instances under GardenProps, with collision that follows each prop.

Window sills and arch surrounds are painted into city_hall_windows_albedo.png. Every window is one rectangular panel. The upper half of the atlas holds arched windows, and city_hall_windows_emission.png follows the glass shapes without illuminating the painted stone. The 16 dome columns use diamond-oriented rectangular shafts, bases and caps. The six entrance columns retain simple round shafts with rectangular bases and caps.

## Scale and placement

One Blender unit equals one Godot unit equals one metre. Godot front is +Z; Blender front is -Y. The root origin stays at ground level. Building size remains approximately 158 m wide, 87 m deep including the entrance, and 78 m tall.

The site now ends at its retaining walls and stair foot, approximately 184.65 x 133.575 m including coping. Godot X limits are -92.325 to 92.325; Z limits are -65.325 to 68.25. The outer lawn, stair forecourt and central park walkup are removed, including their collision. Align the stair foot at Z=68 with the existing sidewalk. No surrounding ground is included in this asset.

Interior lawns, four flat front garden tiers, upper garden paths and the rear courtyard remain. The central staircase is 42 m wide, 3 m beyond each side of the 36 m entrance portico. It has four flights of ten steps, 0.20 m risers, 0.44 m treads and 3 m intermediate landings. Dark risers and textured tread edges improve readability. Invisible collision ramps meet the top landing at 8 m.

## Files and editing

- city_hall.blend: editable Blender source with packed textures and separate architecture, props and presentation collections.
- city_hall.glb: 56 building/grounds meshes, excluding furniture.
- city_hall.tscn: reusable native scene with collision and independent props.
- city_hall_preview.tscn: standalone orbit preview with the game's day/night sky.
- props/bench.tscn, table.tscn, hedge.tscn and corresponding GLBs: current reusable props. Older chair/planter files are unused by this scene.
- city_hall_manifest.json: counts, metre dimensions, collision and prop placements.
- city_hall_windows_albedo.png, city_hall_windows_emission.png, city_hall_hedge.png, city_hall_stair_treads.png: dedicated textures.
- tools/build_city_hall.py, prepare_city_hall.gd and render_city_hall.gd: generation, scene preparation and Godot captures.

Editing a prop scene updates its instances. Moving an individual GardenProps child moves its collision with it. Rebuilding overwrites generated model files and preparing overwrites the native scene/prop placements; preserve manual edits first.

## Night lighting

city_hall.gd duplicates emitting materials per building and follows day_night_cycle.night_lighting_changed, matching the hospital's dusk/dawn fade. Daytime intensity is zero; instances loaded at night synchronize immediately. window_emission_energy defaults to 2.0. Without a clock, standalone_night_amount defaults to daytime. The GLB alone has no clock script.

## Verification

Open city_hall_preview.tscn and press F6. Drag to orbit and use the wheel to zoom. Keys: 1 day, 2 sunset, 5 night, 6 dawn, 3 courtyard, 4 entrance, R reset. Inspect the painted window trim, six dining sets, hedge texture, simplified columns and trimmed site boundary. Compare 1 and 5 to verify glass-only night lighting.

Test player traversal in a separate player test scene: start on your sidewalk in front of Z=68, walk up all four flights and onto the entrance esplanade, then follow the upper side paths to the courtyard. The rear retaining wall has no ground-level entrance. This asset does not include a player controller.

Rebuild/check from the project root using installed executable paths:

```powershell
blender --background --python assets/buildings/city_hall/tools/build_city_hall.py
godot --headless --editor --import --path .
godot --headless --path . --script res://assets/buildings/city_hall/tools/prepare_city_hall.gd
godot --headless --path . --script res://tests/test_city_hall.gd --quit-after 3600
godot --headless --path . --script res://tests/test_city_hall_lighting.gd --quit-after 1200
godot --path . --script res://assets/buildings/city_hall/tools/render_city_hall.gd
```

Automated checks cover scale, reduced mesh budget, removed trim/outer-ground geometry, exact prop counts, moveable prop collision, retaining walls, garden tier heights, roof/dome collision and CharacterBody3D stair ascent at three lateral positions. Lighting checks exercise the actual clock, night spawn, per-instance isolation and nonemitting frames. Actual Godot GPU captures are in artifacts/city_hall. These checks do not constitute a manual playtest of the superhero controller.
