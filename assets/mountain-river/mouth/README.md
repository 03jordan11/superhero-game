# Wider river mouth and curved sidewalks

Open `scenes/main.tscn` and look north from the ocean. The mouth widens smoothly
from the existing river toward the east, reaching **350 m** at Z=800. Six regular
Financial Quarter buildings were removed; both banks and the other POIs remain.

Both urban banks now have continuous **12 m promenades**, using the existing
sidewalk texture. Old stepped paving and its vertical slab edges were cut away;
matching ground fills the space behind the new walks. Bridge roads, bridge
sidewalks and the promenade have separate, nonoverlapping surface footprints.
The eastern seawall and its collision were shortened to the new mouth, and 30
quay lamps were repositioned along the curves.

One short north/south road fragment and one alley were removed. Their manifest
entries and connected junction arms were updated. All five bridge crossings
remain, with 700 vehicle lanes and 1,830 junction turns across the city.

Pedestrian generation and runtime footprint checks now support the curved
walkways. The generated network has **262 modules, 5,431 points and 6,515 edges**,
with two connected banks and no isolated A* points. Pedestrian crossings of the
river remain disabled, as before. Obsolete editor markers were removed and
remaining markers refreshed while preserving valid district selections.

## Files changed

- `scenes/super_city.tscn`: building removal, mesh/collision replacements,
  lamp/seawall overrides, `RiverFrontage` instance and route marker updates.
- `scenes/main.tscn`: enables the city's replacement urban water.
- `scenes/mountain_river.tscn`: retains only the northern mountain reach.
- `scenes/river_frontage.tscn`: new urban paving, ground, banks, bed and railings.
- `scenes/npcs/city_pedestrian_routes.tscn`: rebuilt editor route nodes.
- `assets/super-city/layout.json`, `assets/super-city/pedestrians/`: current
  roads, building list, curve coordinates, route graph and inventory.
- `assets/mountain-river/mouth/`: replacement meshes, collisions and audit report.
- `assets/mountain-river/tools/*mouth*`: one-off inspection, authoring and review
  scripts using the saved pre-revision baseline in `artifacts/river_mouth/before`.
- `assets/super-city/tools/generate_pedestrian_network.gd`: curved quay links and
  removal of unconnected points.
- `scripts/npc-scripts/pedestrian_route_graph.gd` and
  `scripts/npc-scripts/city_pedestrian_network.gd`: curved walking-area support.
- River, pedestrian, POI and waterfront tests were updated for the new layout.

## Verification

`tests/test_river_mouth.gd` checks 276 bridge deck/sidewalk samples for support
and overlapping collision surfaces, probes the open mouth, and checks 4,204
nearby route samples against actual collision and runtime walking constraints.
Godot renders are saved in `artifacts/river_mouth/`.

In Godot, run Main, inspect the mouth from the ocean, walk the bridge sidewalks,
and enable nearby Financial Quarter/Eastbank crowd routes to watch pedestrians
follow the curved banks. Renders and automated physics/crowd checks are separate
from manual player traversal.

Do not rerun the one-off authoring scripts over later manual edits without
refreshing their baseline. The ordinary pedestrian generator can be rerun from
the current layout; refresh saved scene marker overrides afterward with
`sync_mouth_routes.py`.
