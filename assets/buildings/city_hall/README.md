# City Hall

Metre-scale civic landmark. Front is Godot +Z; the root is at ground level.
The building is approximately 158 m wide, 87 m deep and 78 m tall.

## Current frontage and materials

The four stepped lawn terraces flanking the central stairs have been removed.
Full-height limestone retaining walls now hug the upper esplanade at Z=41.8 m.
Open paved forecourts occupy the former tiers, at ground level on both sides.
The four central stair flights and their smooth traversal collision are retained.
Their side walls are now two continuous solids, including the sections beside
the landings, and use the exact limestone material of the retaining walls.

The surrounding public paving is authored in `scenes/super_city.tscn` under
`Sidewalks/CityHallSurrounds`: a front apron meeting the stair foot, rear paving,
and fitted edge strips. `Roads/roads_2_1/CityHallEastConnection` is the 120 m road
between the rear intersection and the intersection beside the park. Both
junctions have their connecting arms and crosswalks enabled. These additions
reuse the existing adjustable road/sidewalk pieces and their collision.

The saved City Hall placement (X/Z scale 0.9, position -301, 0.019211411, -404)
now lives in `super_city`; the redundant `main` transform override was removed.
Traffic routes were not changed.

The front walls use the same limestone material as the other retaining walls.
Walking surfaces, including the front forecourts, upper paths, esplanade,
landings and courtyard, use the exact shared city material:
`res://assets/super-city/modular-sidewalks/sidewalk.tres`.
Its texture repeats in world space at the same scale as surrounding sidewalks.
`tools/city_sidewalk_import.gd` applies it when Godot imports the building GLB.

The [Superhero City Color Palette Guide](https://docs.google.com/document/d/1Ei42N1fOiKi5Oz9Ini6oioNT8moRGq8uQoVhiqnsWQY/edit)
informs the muted civic materials: warm gray stone around #C4C0B6, restrained
trim, weathered green roofs around #53645C, and lawn around #687763. Texture
variation remains; the shared city window palette and night occupancy settings
remain active. The building is deliberately a little lighter than its neighbors.

## Preserved props and geometry budget

The user-authored native `GardenProps` scene block and all files in `props/`
were preserved byte-for-byte. This includes moved/scaled hedges and removed
furniture. Native scene placements are authoritative; the historical Blender
presentation collection is not used to overwrite them.

| Component | Imported triangles |
| --- | ---: |
| Architecture, stairs, walls and grounds | 5,082 |
| 4 tables and 18 benches | 792 |
| 6 hedge instances | 72 |
| **Complete POI** | **5,946** |

`TRIANGLE_AUDIT.json` counts actual Godot-imported geometry at highest detail,
including every placed prop instance. Preview ground/lighting and collision
shapes are excluded. The total remains under the 10,000-triangle POI limit.

## Editing and rebuilding

- `city_hall.blend`: editable architecture with packed textures.
- `city_hall.glb`: exported architecture and grounds, excluding native props.
- `city_hall.tscn`: collision, model instance, and user-edited prop layout.
- `city_hall_manifest.json`: geometry/collision data and current prop inventory.
- `civic_*.png`: dedicated recolored building textures; prop textures are separate.
- `city_hall_preview.tscn`: standalone preview using the game's day/night clock.

For this frontage revision, run from the project root:

```powershell
blender --background --python assets/buildings/city_hall/tools/update_frontage.py
python assets/buildings/city_hall/tools/update_frontage_collision.py
godot --headless --editor --import --path . --quit
```

The Blender updater edits only the architecture collection and exports only
the building GLB. The collision updater patches the affected frontage shapes
while retaining the native GardenProps text exactly. The shared sidewalk
material is assigned during GLB import, so Blender itself shows its original
paving preview material.

`build_city_hall.py` and `prepare_city_hall.gd` are the historical full-generation
tools. They recreate default props and placements; do not use them for routine
updates to the hand-edited native scene. If intentionally rebuilding the base
architecture, reapply the frontage updater and preserve the native props first.
Then run `tools/update_stair_sides.py` in Blender, reimport the GLB, and run
`tools/prepare_stair_sides.gd` to replace the old segmented collision. This last
step preserves the native GardenProps block verbatim.

`tests/test_city_hall_surrounds.gd` checks the saved main/super_city placement,
continuous stair materials/collision, sidewalk coverage, and 483 road collision
probes across the new connection and both intersections. Pass `-- --write-audit`
to refresh the complete imported triangle audit.

## Verify in Godot

Open `city_hall_preview.tscn` and press F6. Drag to orbit, scroll to zoom;
1 = day, 5 = night, 3 = courtyard, 4 = entrance, R = reset.
Inspect the flat spaces beside the stairs, the wall at the upper terrace,
matching sidewalk tiling, muted roof/stone, and preserved courtyard furniture.
Also inspect the instance in `scenes/super_city.tscn` beside neighboring buildings.

```powershell
godot --headless --fixed-fps 60 --path . --script res://tests/test_city_hall.gd --quit-after 1500
godot --headless --path . --script res://tests/test_city_hall_lighting.gd --quit-after 180
```

Checks cover actual complete-POI geometry, authored prop inventory, ground-level
forecourt collision, setback retaining walls, roof/dome collision and three
CharacterBody3D ascents of the main stairs. Day/night tests cover emission,
clock transitions and per-instance materials. Day and night GPU captures,
including views with nearby city buildings, are in `artifacts/city_hall/`.
These automated traversal probes are not a manual superhero-controller playtest.
