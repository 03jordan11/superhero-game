# Authored city traffic roads

Vehicle traffic now follows the saved road modules in Main/SuperCity, including
the three river bridges, the north-bank road links, and City Hall's east road.
The snapshot contains 630 road pieces and three bridge profiles. These compile
to 342 continuous corridors, 684 directional lanes, and 188 junctions with 1,880
permitted connections. Chunk seams are merged before junctions split corridors.

This is a **vehicle-only** layout. The legacy `assets/super-city/layout.json`,
pedestrian network, crowd configuration, and lamp/sign generation are unchanged.
Highway, airport, and the road leaving the southeast city edge are excluded.
Existing junction control IDs are retained by position; three added junctions
receive new IDs. Traffic population and the existing one-lane-per-direction
behavior are unchanged. Distant proxies retain their existing simplified rules.

## Files

- `scenes/super_city.tscn`: selects this layout and overrides the small stretch of
  highway furniture that protruded into the in-town junction at (-740, -960).
  The rails and first median stop at the northern curb, Z = -974. External road
  geometry/routing is otherwise unchanged; the original CityLife asset is intact.
- `scripts/traffic/traffic_lanes.gd`: explicit junction IDs, deck elevation,
  vehicle pitch and support across changes of grade.
- `scripts/traffic/traffic_manager.gd`: elevated spawning/driving and obstacle
  sweeps along bridge slopes. Flat streets still use a single sweep. Bridge
  sweeps use segments of at most 2 m; obstacles and vehicles still block traffic.
- `scripts/traffic/traffic_box_lod.gd`: both distant tiers follow the same deck
  elevation and pitch, including prediction and transitions to full vehicles.
- `layout.json`: runtime traffic data; `road_snapshot.json`: authored inputs.
- `export_presets.cfg`: explicitly includes the runtime traffic JSON in builds.
- `junction_guardrails*.res`, `junction_median*.res`: trimmed render/collision
  resources used only by the SuperCity overrides.
- `assets/super-city/tools/export_traffic_roads.gd`, `build_traffic_layout.py`,
  `clear_city_junction_barriers.gd`: offline authoring tools.
- `tests/test_authored_traffic_roads.gd`, `tests/test_bridge_traffic.gd`: new
  physics, connectivity, traversal, and LOD handoff checks.

## Regenerating after road edits

Save Main and SuperCity first. From the project root, using the project's Godot
4.7 executable and Python 3:

```powershell
godot --headless --path . --script res://assets/super-city/tools/export_traffic_roads.gd
python assets/super-city/tools/build_traffic_layout.py
godot --headless --path . --script res://tests/test_authored_traffic_roads.gd
godot --headless --path . --script res://tests/test_bridge_traffic.gd --fixed-fps 60
```

This rebuild is offline, not a scene scan on every game launch. The exporter
records hashes of the saved scenes. It supports the current level, cardinally
aligned road modules and the three named bridge deck profiles. A future curved
road or moved/reshaped bridge needs its corresponding authored route support.
The barrier tool is only needed when rebuilding its trimmed resources.

## Validation and player check

- Every lane is reachable from every other lane; no terminal or isolated routes.
- 26,236 straight-lane surface/clearance samples plus samples along all 1,880
  intersection curves: no missing support or static obstruction.
- All seven distinct vehicle shapes cross all three bridges in both directions
  and spawn/demote/promote at their crests without changing pose. The optional
  test argument `-- --entry=N` selects a vehicle entry (0, 3, 6, 9, 12, 15, 16).
- Existing manager, intersection, box/far LOD, city integration, and driving-range
  tests pass. Godot-rendered bridge and junction views were inspected; an
  interactive player playthrough is still the user's next check.

In Main, watch traffic at all three bridge approaches, the north-bank links,
and City Hall's new east road. Check turns, stops, bridge climbs/descents, and
that cars no longer cross the removed streets over the river. Fly away and
return to check distant/full vehicle transitions. Walkway/crowd repairs follow
after the traffic playtest.
