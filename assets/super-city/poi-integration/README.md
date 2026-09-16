# City POI integration — September 2026

The edited `scenes/super_city.tscn` contains all six POIs. `scenes/main.tscn`
uses those instances; the old six-building east-edge test lineup was removed.
No player transforms, controls, district checkboxes or crowd settings were changed.

| Instance | Position X / Y / Z (metres) | Front | Placement |
| --- | --- | --- | --- |
| CityHall | -292 / 0.1 / -404 | South | Centered exactly on Central Park, moved about 4 m south to clear the road behind it |
| Hospital | -292 / 0.03 / 387 | North | Across the park, within 21 m of the user's placement |
| PoliceStation | -435 / 0.03 / -356 | South | West side of the civic plaza |
| Bank1 | -139 / 0.03 / 516 | North | Financial Quarter |
| Bank2 | 109 / 0.03 / 602 | South | Financial Quarter |
| Firehouse | -616 / 0.03 / 507 | North | Civic Center, southwest of the hospital |

## Streets and pedestrians

- Removed 17 generated building instances and their collision nodes. Their source
  scenes remain available. `integration.json` lists every removed instance.
- Closed the two north-south street sections at X -380 and -200 between Z -470
  and -334, giving city hall one civic block. Traffic follows its perimeter.
- Closed the alley at X -290 between Z 334 and 470, through the hospital site.
- Rebuilt affected road/sidewalk meshes and collision resources, with connected
  perimeter aprons and recut ground. Existing intersections retain their order,
  preserving traffic-signal IDs. Road-arm flags and crosswalk textures were updated.
- Cleared one hotdog stand, two benches and one hydrant conflicting with the
  sites or revised paths. Other CityLife scenery and trees were preserved.
- Rebuilt the A* inventory: **260 modules, 5,322 points, 6,210 segments**, with
  **two** intentionally separate pedestrian riverbanks. POI envelopes are now
  included in the offline route generator's obstacle checks. Editor StartHere
  markers match the new inventory; district selections remain intact.
- Added one hospital-owned rescue drop-off at the relocated entrance. Its ring
  uses 256 triangles rather than the default dense torus.

## Checks

Passed `test_city_poi_integration.gd`: POI/road/building separation, removed
colliders, marker synchronization, **2,615 physics path samples**, **702 traffic
lanes / 1,834 turn connections**, and one hospital rescue destination.

Passed the existing pedestrian-network, civilian-crowd, actual-city traffic,
traffic-controls and city-night-light tests. `test_poi_crowds.gd` spawned six
full civilians and observed all six moving at each of five POI neighborhoods,
including population relocation and the six-person cap.

Rendered the actual scene and inspected civic, hospital, bank and firehouse
views in `artifacts/poi_integration/`. These are authored scene renders and
automated simulation checks, not a manual player traversal playtest.

In Godot, run Main and walk the civic perimeter/stairs, hospital entrance,
financial-bank frontages and firehouse apron. Watch crosswalk waits and traffic
turns, then check the hospital rescue drop-off and nighttime POI lighting.

## Files

Changed scenes: `scenes/super_city.tscn`, `scenes/main.tscn`,
`scenes/city_life.tscn`, and `scenes/npcs/city_pedestrian_routes.tscn`.
Updated layout/network/inventory: `assets/super-city/layout.json` and
`assets/super-city/pedestrians/`. Generated pavement/ground resources live in
`assets/super-city/meshes/`; replacement collisions live here.

The task baseline is in `artifacts/poi_integration/before/` and preserves the
user's starting files. Integration scripts are one-time authoring records;
do not rerun them over subsequent manual city edits. The original full-city
generator likewise overwrites manual edits. The pedestrian generator alone
can rebuild routes from the current saved layout and city.

The HTML asset dashboard is a separate static snapshot; it does not refresh
automatically when these scenes change.
