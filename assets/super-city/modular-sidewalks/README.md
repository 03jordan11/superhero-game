# Modular sidewalk kit

Open **`res://scenes/previews/modular_sidewalk_test.tscn`** to try the kit.
It contains eight loose samples and a connected example made from ordinary,
individually selectable scene instances. Press **F6** to run this test scene.
The city now uses combined road/sidewalk modules for most streets. Select them
under `Roads/roads_*` in `res://scenes/super_city.tscn`. **55 independent paving
pieces** remain under `Sidewalks/sidewalks_*` for custom gaps and frontage. Empty
chunk roots are retained. The continuous riverside promenade is unchanged.
See [the road kit guide](../modular-roads/README.md) for current counts, fitting
controls and measured performance.

This standalone kit remains useful for independent pavement and new layouts.
Disable Include Sidewalks on a road before adding separate pavement there, to
avoid overlapping geometry. The consolidation and conversion records below
are historical; their footprint audits remain inputs to the current regression
checks, but their placement counts no longer describe the live city.

## Previous sidewalk consolidation

Adjoining pieces from the same authored straight run are consolidated, up to
**200 m per piece**. Corners, access gaps, distinct paving widths, separate
authored runs and chunk boundaries are preserved. Wider paving merges only
along its existing length; neighboring rows remain independently editable.
Retained pieces keep their original names and node IDs where present.

Measured by loading the saved scene in Godot before and after:

| Sidewalk metric | Before | After | Saved |
| --- | ---: | ---: | ---: |
| All nodes under the 24 sidewalk chunks, including chunk roots | 22,530 | 11,994 | **10,536 (46.8%)** |
| Individually editable pieces | 3,555 | 1,799 | 1,756 |
| Collision shapes | 4,731 | 2,975 | 1,756 |
| Rendered sidewalk triangles | 52,068 | 30,996 | 21,072 |

All 588 corner pieces remain. The 1,211 remaining straight/paving pieces use
the existing adjustable prefab, so mesh, collision and sockets resize together
and the texture retains its world-space tile size. Ground infill is unchanged
and is excluded from the counts above. Other city nodes are unchanged, so the
city scene also has exactly 10,536 fewer nodes overall.

The saved city passed 65,454 support/seam probes across the 23 rollout chunks,
14,905 probes in the original trial, and the city POI/pedestrian integration
check. The original retained footprints and pedestrian graph are unchanged;
only the graph's source-scene fingerprint was refreshed. No script parse errors
remain. These are node/geometry measurements, not an FPS improvement claim.

Select an existing straight and edit **Length M**, or **Width M** for broad
paving. Try a long run beside an intersection, walk across its joins, and move
then undo it to check the editing granularity. Use **Scene → Reload Saved Scene**
on Super City and Main if the editor still shows the shorter pieces, after
protecting unsaved work.

Changed: `scenes/super_city.tscn`, this guide, `city_conversion.json`,
`sidewalks_3_2_conversion.json`, `assets/super-city/pedestrians/network.json`
(fingerprint only), and `tests/test_sidewalks_3_2_modular.gd` (reads current
expected counts from the placement audit). Inspection/merge helpers, measured
counts and backups are in Git-ignored `artifacts/long_sidewalks*` files/folders;
the backup folder is also excluded from Godot scanning. Earlier conversion
counts below document the previous stages, before this consolidation.

## Pieces

Standard paths are **4 m wide**; fitted paving also preserves the city's existing
plazas, building setbacks and pier widths. All roots use Y = 0 with the walkable surface at
Y = 0.03, matching the existing city's flush sidewalks. Meshes, collisions and
socket markers belong to each piece, so they move together.

| Scene in this folder | Description | Connection markers | Rendered triangles |
| --- | --- | --- | --- |
| `straight_4m.tscn` | 4 m straight | North/South, 2 m from center | 12 |
| `straight_8m.tscn` | 8 m straight | North/South, 4 m from center | 12 |
| `straight_16m.tscn` | 16 m straight | North/South, 8 m from center | 12 |
| `straight_40m.tscn` | 40 m straight | North/South, 20 m from center | 12 |
| `straight_adjustable.tscn` | Inspector-adjustable length and width, defaults 40 × 4 m | North/South, follow the length | 12 |
| `corner_l.tscn` | Square 90-degree corner, 8 × 8 m occupied bounds | North/East, 6 m from turn center | 28 |
| `junction_t.tscn` | T junction, 12 × 8 m occupied bounds | North/East/West, 6 m from center | 36 |
| `junction_cross.tscn` | Four-way junction, 12 × 12 m bounds | Four directions, 6 m from center | 44 |
| `end_cap.tscn` | 4 m terminal section with chamfered outer corners | North, 2 m from center | 20 |

North means local **-Z**, East means **+X**. Turn/intersection pivots are at the
center of the meeting paths, not necessarily the center of the mesh bounds.

## Arrange them in Godot

1. Drag a kit `.tscn` from the FileSystem into a 3D scene, or duplicate an existing
   sample. Select the complete scene root, such as `Straight8m`.
2. Enable translation snapping and set its increment to **2 m**. Set rotation
   snapping to **90 degrees**. Keep scale at **(1, 1, 1)** and root Y at **0**.
3. Move/rotate pieces until their connection markers coincide and face opposite
   directions. Expand a piece's `Sockets` node to select a marker and inspect its
   position if needed. These are alignment guides; no custom magnetic-snap addon
   is installed or required.
4. For an exact fit, use `straight_adjustable.tscn` and change **Length M** in
   the Inspector. **Width M** is also available; keep it at 4 to join the standard
   connectors. Mesh, collision and markers update together. Keep the root scale
   at (1, 1, 1). The world-aligned texture keeps its original tile size.
5. Delete the complete scene instance to remove both its mesh and collision.

For example, an unrotated `straight_8m` at `(0, 0, 0)` has ends at Z -4 and +4.
Place another at `(0, 0, 8)` to join it. A `corner_l` at `(0, 0, 10)` places its
North connection at Z +4, fitting directly to the first straight's South end.
Its East connection is then at `(6, 0, 10)`.

The shared material uses the existing sidewalk texture. Moving/rotating an
instance affects only that placement; editing its shared mesh or material would
affect every instance using that resource. Make the resource unique first if
you intend to create a different asset variant.

## Test scene controls

- **F4:** toggle overview / actual player walk test.
- **Overview:** right-drag to orbit, middle-drag to pan, mouse wheel to zoom.
- **Walking:** existing player controls. **Home** returns to `PlayerStart`.
- **F4 or Esc** returns to the overview.

Edit `LoosePieces` or `AssembledExample` while the game is stopped and run the
scene again. The preview controller does not rebuild these nodes at runtime, so
your saved rearrangements remain intact. `Labels` is a separate preview-only
group; move or hide its sample captions if you rearrange the display.

The assembled example includes every connector type and a complete loop. Try
replacing an 8 m straight with two 4 m straights, rotating a corner, deleting a
section, and walking over the resulting joins. Check that selection and snapping
feel convenient before applying the kit to the city.

## Validation and implementation

`tests/test_modular_sidewalks.gd` passed in a rendered Godot run:

- Eight scene resources, shared material, actual mesh triangle counts and heights.
- All 30 connection ends in the example pair up with opposite-facing markers.
- Collision rays at and on both sides of every join find a continuous surface.
- No bounding-box collision fills the L corner's cutout.
- Moving a module moves its collision and clears its previous location.
- The actual player walks across a corner, straight and junction without losing
  ground contact or getting stuck.

Horizontal collision edges overlap by approximately 1 mm to tolerate floating-
point error when rotating instances; collision height remains exactly 0.03 m.
The assembled example is 308 triangles. The eight loose samples add 176, for
**484 sidewalk triangles in the complete test scene**, excluding preview ground.
Overview and player-view renders were inspected. No script/shader parse errors
were reported; the host's existing log/settings/certificate/cache warnings remain.
This is a functional kit test, not a city-wide performance benchmark.

New files are confined to this folder (eight scenes, eight mesh resources,
material, shader, manifest, this guide, and authoring script), plus:

- `scenes/previews/modular_sidewalk_test.tscn`
- `scripts/previews/modular_sidewalk_test.gd`
- `tests/test_modular_sidewalks.gd`
- Generated test logs and preview images under `artifacts/`.

`build_kit.gd` is an **offline authoring tool**. Re-running it replaces the kit
resources and test scene, including manual changes to that test scene. It is not
needed for placing pieces or running the preview. No city generator, pedestrian
route generator, traffic data or existing city mesh is modified by this kit.
The first city conversion is described below.

## First city conversion: sidewalks_3_2 (before consolidation)

Open `res://scenes/super_city.tscn`, expand `Sidewalks > sidewalks_3_2`, and
select a `Straight_*` or `Corner_*` child. The parent is now a Node3D containing
**84 adjustable straights and 14 standard corners**. Every child is an ordinary
scene instance you can move, rotate, duplicate or delete independently.
If working from `main.tscn`, open Super City's source scene to edit these nodes.

The 39 retained source rectangles are covered exactly: **11,768 m²**, with the
same 4 m widths and Y = 0.03 surface. Custom lengths fit the original layout;
some positions use half metres, so temporarily disable 2 m snapping when
repositioning those exact fits. Resizing extends equally from the piece's center;
move it by half the length change if one end must stay fixed.

Removed 21 obsolete 2 m-deep waterfront step remnants (508 m²). The original
combined mesh and collision are no longer instanced. Matching ground and box
collision fill all the chunk's original cutouts at Y = 0 under
`Ground/Sidewalks3_2GroundInfill`, including beneath retained modules, so moving
a module exposes solid ground. No other sidewalk chunk or the river promenade
was changed. The original mesh resources remain available for comparison.

Actual sidewalk geometry is **1,400 triangles** (previously 566); ground infill
adds 120 triangles. There are more render instances in exchange for editability;
no city-wide performance claim is made from this one-chunk trial.

`layout.json` and the pedestrian network exclude the deleted strips. Two leaf
route segments were removed; all 262 modules, their start/destination positions
and the two connected riverbanks remain. Moving pieces later does **not** move
the offline pedestrian routes automatically; route updates are a separate step
after layout edits are settled.

`sidewalks_3_2_conversion.json` records exact original/retained/removed rectangles
and module placements. `tests/test_sidewalks_3_2_modular.gd` checks the actual
rendered area, 14,905 support probes, removed-strip ground infill, independent
collision movement and instance-local resizing. River-mouth and pedestrian
network regression checks also pass. Original scene/layout/network snapshots
are under `artifacts/sidewalk_3_2_backup/`.

Files changed for this conversion:

- `scenes/super_city.tscn`
- `assets/super-city/layout.json`
- `assets/super-city/pedestrians/network.json` and `INVENTORY.md`
- This `README.md`

Files added:

- `adjustable_straight.gd` and `straight_adjustable.tscn`
- `sidewalks_3_2_ground_infill.tscn` and `sidewalks_3_2_conversion.json`
- `tests/test_sidewalks_3_2_modular.gd`
- Inspection, conversion, scope-audit and render helpers plus logs under `artifacts/`.

No script parse errors were reported. Existing host log/certificate/UID fallback
warnings remain. The pavement-only render was inspected; the city was not
manually playtested. In Godot, move and undo a module, adjust its length, and walk
across the joins. Confirm the edit granularity suits your workflow before
converting another chunk.

## Full city rollout (before consolidation)

The other **23 chunks** now contain **3,457 modules**, bringing the city total
to **3,555**, including the unchanged 98-piece trial. Their retained footprints
match the actual pre-conversion meshes: **453,491.04 m²** across these 23 chunks.
Building-specific fractional dimensions and broad plaza/pier areas were kept.
No roads, buildings, POIs, river promenade or trial-piece placements were edited.

Expand any `Sidewalks/sidewalks_*` group. Select `CornerL_*`, `Straight_*` or
`Paving_*` children to move or duplicate them. `Paving_*` pieces use the same
adjustable prefab, with **Width M** as well as **Length M** fitted to the original
area. Keep physics-body scale at (1, 1, 1). There are no regenerated-at-runtime
sidewalk placements; saved editor changes persist.

Removed **47 additional waterfront remnants** (68 across both conversions).
Ground beneath land-based paving is restored through
`Ground/CitySidewalkGroundInfill`: one combined ground mesh/collider per chunk.
This keeps ground infill inexpensive while sidewalks remain individually
editable. Paving over water does not create new land; removing a pier piece
exposes the water beneath it.

The rollout's actual sidewalk meshes total **50,668 triangles**, plus **2,418**
ground-infill triangles. Including the earlier trial gives **52,068 sidewalk
triangles and 2,538 infill triangles**. Additional render instances are the cost
of editability; the full city has not undergone a controlled performance
comparison. The existing shared meshes and world-aligned material are reused.

Two more pedestrian dead-end segments were removed. The network still has
**262 modules and two connected banks**, now with **5,427 points / 6,511 edges**.
Module start/destination positions and neighboring modules are unchanged.
Moving pavement later still requires a separate offline route update.

Validation completed:

- `tests/test_city_modular_sidewalks.gd`: actual mesh footprints/areas/counts,
  75,720 support/seam probes, deleted-strip infill, and independent collision
  movement in every converted chunk.
- The original `test_sidewalks_3_2_modular.gd`, river-mouth, pedestrian-network
  and city-POI integration checks pass.
- The game was run for rendered street, river and harbor views at 1280 × 800
  using Compatibility rendering, and those images were inspected. This was
  camera-based visual inspection, not a manual traversal playtest.
- A structural scope audit confirms all unrelated city nodes, including the
  approved trial, are unchanged. No script parse errors remain. Existing host
  log/certificate/UID and renderer shutdown warnings remain.

Modified: `scenes/super_city.tscn`, `assets/super-city/layout.json`,
`assets/super-city/pedestrians/network.json`, its `INVENTORY.md`, and this guide.
Added here: `city_conversion.json` (exact footprint/placement audit) and
`city_ground_infill.tscn`. Added test: `tests/test_city_modular_sidewalks.gd`.
Inspection, conversion and scope-audit helpers plus rendered images/logs are
under `artifacts/`; the pre-rollout scene and route/layout snapshots are under
`artifacts/city_sidewalks_backup/`. Conversion helpers are one-off authoring
tools and must not be rerun over subsequent manual scene edits.

In Godot, try moving and undoing pieces in different districts, resizing a
straight and a wider paving piece, and walking across chunk boundaries and
around the waterfront. Open the source city scene when editing from Main.
