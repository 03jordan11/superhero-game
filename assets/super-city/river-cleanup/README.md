# River frontage cleanup after manual road editing

The user's saved layout contains 751 road modules after removing 29 pieces.
All remaining road node blocks, dimensions, junction settings and transforms
are preserved exactly. The saved layout already had no road decks over water.

`scenes/river_frontage.tscn` now uses a clean 12 m promenade on each riverbank,
without the old straight connector fragments or bridge sidewalk strips.
The Quay node and collision retain their paths and IDs; their resources are
`quay.res` and `quay_collision.res` here. Bank walls, bed, railings, water and
existing frontage ground are unchanged. Promenade geometry is 720 triangles,
down from 842. Existing railing openings remain available for future bridges.

`scenes/waterfront.tscn` no longer contains BridgePier through BridgePier10 or
their collision children (30 nodes removed). Other waterfront content remains.

`scenes/super_city.tscn` adds `Ground/RoadGroundInfill`, an instance of
`road_ground_infill.tscn`. It uses the existing ground material at Y=0 and
includes static collision. Its 24 spatial chunks contain 2,754 triangles.
It fills approximately 35,060 m2 currently exposed by the road edits and
frontage cleanup. It also extends beneath retained roads on their original
footprints, so deleting more of those road pieces reveals ground rather than
a hole. Existing ground is subtracted to avoid coplanar overlap. The actual
curved water channel is excluded; no land bridge is created across the river.

Validation: `tests/test_river_frontage_cleanup.gd` passes 1,471 surface probes,
checks all 751 retained road paths, promenade bounds, and removal of bridge
props. Native Main renders were inspected from the north, middle, mouth and
bank. Scene parsing passes. No manual player traversal was performed.
Existing host log/certificate warnings remain. A text-level scope check confirms
all unrelated node blocks and Main are unchanged.

Traffic and pedestrian route data have not been regenerated for the user's
new street layout. The scene fingerprint intentionally remains stale; updating
that hash alone would falsely imply the routes were synchronized. Older tests
that require 780 roads, the original footprint, or five functioning bridges
describe the previous layout and no longer apply. Route rebuilding and updating
those layout audits belongs with the upcoming bridge/road-layout work.

Review in Godot: reload the changed source scenes, walk across cleared road
footprints and former frontage strips, and fly the river to check that the
channel is open. Alignment helpers and traffic routes are not bridge remnants.
One-off authoring scripts, backups and render output are in ignored
`artifacts/river_cleanup/`. Do not rerun the old mouth generator: it restores
the obsolete connectors and bridge geometry.

Northern bridge update: RiverFrontage now uses assets/bridges/north_arch/river_quay.res and river_quay_collision.res. Both promenades end at world Z -946, at the city-side bridge walkway; the portions crossing the northern road and continuing toward the mountains were removed. The original cleanup resources remain as source history. See the northern bridge README and test_north_river_bridge.gd for current validation.
