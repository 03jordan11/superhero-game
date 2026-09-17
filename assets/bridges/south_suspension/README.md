# South river suspension bridge

Golden Gate-inspired twin portal towers, international orange steel, parabolic
main cables, vertical hangers, deck-edge mounting brackets and pedestrian guardrails.
Authored in Blender 5.2.2; exported as GLB and baked into Godot 4.7.2 resources.

## Placement and editing

Open `scenes/super_city.tscn`, select `SuperCity/SouthRiverBridge`, and frame it
with F. The bridge root is at city `(300, 0, 760)`, on the southernmost crossing.
Its 400 m deck spans world X=100 to 500, with a 98 m modular straight approach
from X=2 to 100 on the west. The existing road joins are:

- West: `Roads/roads_3_3/Junction_451`, east socket `(2, 0, 760)`.
- East: `Roads/roads_4_3/Straight_177_0`, west socket `(500, 0, 760)`.

The 20 m roadway and two 4 m walkways follow a smooth sampled approach profile
to a 15.03 m central deck. Tower peaks reach 93.5 m. The sidewalk kerb tapers
flush at both ends so the current player can walk on without a step-up mechanic.
The existing modular road shader, asphalt texture and sidewalk material are
reused in Godot; the Blender source contains packed copies of city textures.

No existing road transforms or buildings were changed. The old hidden,
collision-disabled water and park placeholder groups were removed; their
replacement Waterfront, RiverFrontage and CentralPark scenes remain intact.
Traffic, stoplights, streetlights and pedestrian networks are still based on
the previous layout, as agreed. This bridge does not rebuild those networks.

## Geometry and collision

`triangle_audit.json` counts the actual Godot-imported highest-detail geometry:
**7,588 bridge triangles + 30 approach triangles = 7,618 complete POI triangles**.
This includes every visible bridge part and the placed road extension, excludes
collision and the Blender preview rig, and does not rely on LOD reductions.

Road and walkway collision uses solid convex segments from Blender's exported
`deck_profile.json`, with 2 mm overlap at segment joins. Towers, foundations,
mounting brackets, tower crossbeams and guardrails use static mesh collision.
Cables and hangers are visual. The lower longitudinal side trusses were removed,
saving 1,416 triangles overall after adding a bracket for every hanger. Each
hanger's bottom overlaps its deck bracket, and the four main-cable endpoints
enter the anchorage caps. Guardrail posts also meet the tapered walkway ends.
The Blender rig is excluded from GLB export. Imported mesh compression is
disabled to preserve the large model's coordinates and thin details.

## Rebuilding

From the project root, using the installed Godot and Blender executables:

1. Godot `--headless --path . --script res://assets/bridges/south_suspension/tools/export_city_textures.gd`
2. Blender `--background --python assets/bridges/south_suspension/tools/build_bridge.py`
3. Godot `--headless --editor --path . --import`
4. Godot `--headless --path . --script res://assets/bridges/south_suspension/tools/bake_scene.gd`
5. Godot `--headless --fixed-fps 60 --path . --script res://tests/test_south_river_bridge.gd`

`south_suspension.blend` retains separately editable named mesh groups and a
preview camera. Re-running the Python builder regenerates it; manual Blender
changes should be exported to GLB and then rebaked without rerunning the builder.
For manual deck profile edits, update the collision profile alongside the mesh.

## Verification

- Bridge test: 917 road/sidewalk surface probes, exact road joins, underwater
  passage clearance, full imported triangle count and inclusion in Main pass.
- Player-sized CharacterBody capsule crosses both road directions and the south
  sidewalk without falling or stopping at the approach joins.
- Attachment checks derive all 70 hanger endpoints from the imported mesh and
  verify that both ends enter solid geometry; the four anchor caps are checked.
- Five native Godot Forward+ views inspected: overview, both approaches, deck,
  river-facing elevation. Blender render inspected as well.
- All 7,176 retained city node blocks exactly match the user's pre-bridge scene.
- Broader park/waterfront tests retain their pre-existing failures: one tree
  placement-count assertion and five assertions for the deleted old crossings.
  Both failures were reproduced against the saved pre-bridge scene.
- No manual player-control playthrough was performed. Review in Godot by walking
  from both streets onto the deck/sidewalks, jumping onto the towers and flying
  below the central span.
