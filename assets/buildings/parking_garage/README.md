# Configurable parking garage

Open-sided concrete parking structure authored in Blender, with teal wayfinding,
painted parking stalls, open top parking, and real connecting ramps.

## Try the configurations

Open `parking_garage_test.tscn` in Godot and press **F6** (Run Current Scene).
It starts with Small / 3 levels, Medium / 6 levels, and Large / 10 levels.

- Select Garage A, B, or C, then change its width menu and **3–10** floor slider.
- Hold the left mouse button to orbit; scroll to zoom.
- Hold the right mouse button and use WASD to fly, Q/E down/up, Shift to move faster.
- Keys 1/2/3 focus a garage; Home returns to the comparison view.
- Runtime changes are temporary. Save permanent values in the Inspector.

Instance `parking_garage.tscn` in another scene and set **Width Preset** and
**Floors** on its root. All three widths support all eight floor counts.
The scene previews these changes in the editor. Rotate/move the root normally;
keep scale at 1 so ramp slope and clearance remain consistent.

| Preset | Footprint | Parking rows |
|---|---|---|
| Small | 32 × 54 m | 1 |
| Medium | 44 × 54 m | 3 |
| Large | 56 × 54 m | 5 |

Floors **includes the ground level and open top deck**. Deck spacing is 3.6 m.
The highest deck is `(floors - 1) × 3.6 m` above the ground; the perimeter rail
is another 1.16 m above that. Entrance faces local **-Z**, with
the slab top at local Y=0. Its X coordinate varies by width to line up with a
drive aisle; baked scene metadata `entrance_x` records this coordinate.

The 30 m ramps rise 3.6 m (12% grade), with an approximately 7.5 m clear width
between barriers and 3.28 m clearance beneath the next ramp. All ramps rise in
the same direction (+Z); each deck's aisles and end landings connect the next
ramp. Collision covers slabs, ramps, structural columns, perimeter barriers,
and perimeter rails. White upward (entry) and downward (exit) arrows are painted
on the concrete wall above the entrance. There are no floor-number signs,
rooftop P, IN/OUT board, or yellow floor arrows. The ramp-side parking row is
unmarked on every level to keep the approaches clear; the ramp centre line remains.
This is a building asset and inspection scene; it
does not introduce parking AI or route traffic into garages.

## Performance and geometry

The eight placed garage instances in `scenes/super_city.tscn` each have an
`EntranceAlley` MeshInstance3D child. These 8 m wide asphalt strips connect the
door openings to the road in front of each garage, with lengths fitted to the
current placements. They reuse the city's asphalt texture and world-aligned
4 m tiling. They are visual only: no traffic, route, or collision changes.
Each strip is two triangles. Moving a garage also moves its strip; if the gap
to the road changes, adjust that child's position and PlaneMesh size.

All 24 combinations are generated offline. Changing parameters selects a baked
scene; a placed garage has no per-frame generation or processing. It uses six
mesh groups/materials, shared texture/material resources, and one static body
with box and convex-ramp shapes. Repeated instances of a configuration share
its mesh resources. The explicit variant dependencies include every size in
Godot exports. Blender sources are excluded using `source/.gdignore`.

Actual imported triangle counts, including every sign, marking, rail, and
column, are recorded in `TRIANGLE_AUDIT.json`. The range is **976–4,214**,
below the project's 10,000-triangle complete-POI limit. Preview ground, labels,
and UI are separate from the building. No parked cars or additional props are
included in this budget.

## Blender source and regeneration

`source/parking_garage.blend` contains editable geometry for the three showcase
configurations. `tools/build_garage.py` is the single parameterized modeling
source for every exported configuration; edit it to make structural changes
that should apply to all widths/floor counts. Editing just the showcase meshes
does not automatically update the baked variants.

1. Run `tools/create_textures.py` with Python + Pillow when changing textures.
2. Run Blender: `blender --background --python tools/build_garage.py`.
3. Let Godot import the PNG textures, then run from the project root:
   `godot --headless --path . --script res://assets/buildings/parking_garage/tools/prepare_garage.gd`
4. Validate with:
   `godot --headless --path . --script res://tests/test_parking_garage.gd`

The importer reads the actual Blender GLBs, shares external Godot materials,
saves static meshes/collision scenes, and updates the audit. The automated
test counts imported triangles for all 24 variants and checks floors, landings,
ramp slope/transitions, standing clearance, entrance access, barriers, and
parameter bounds. Godot overview and interior renders were also inspected.
The inspection scene uses a flying camera, not the game's player controller;
player/vehicle handling in these garages should be tested when placing them.

## Photo references

- [1111 Lincoln Road — Herzog & de Meuron](https://www.herzogdemeuron.com/projects/279-1111-lincoln-road/)
  and [Hufton + Crow's photographs](https://www.huftonandcrow.com/projects/gallery/1111-lincoln-road-miami/): exposed concrete slabs and open parking decks.
- [Parking House in Dolní Břežany — Fránek Architects](https://www.archdaily.com/977330/parking-house-in-dolni-brezany-franek-architects): simple repeated floor structure and ramp circulation.

These informed the design; reference photographs are not bundled or used as textures.
