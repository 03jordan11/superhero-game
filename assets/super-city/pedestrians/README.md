# Roadside pedestrian navigation

Routes use the saved Main/SuperCity road geometry and its overrides. Allowed surfaces are current street-module sidewalks, painted crossings, independent sidewalk pieces clipped within 4.25 m of those streets, and the three river bridges' walkways. Independent pavement still needs actual ground support and body clearance.

Piers/docks, river promenades, Central Park trails and Bow Bridge, detached City Hall pavement, and alley asphalt no longer supply ambient pedestrian routes. Airport and mountain/highway navigation remain excluded. The existing AStar graph, district toggles, crowd manager, lane spacing, height handling, population settings and crossing waits remain in use.

## Current export

- 247 modules, 14,993 points, 15,454 segments.
- Component sizes: 14,982, 9, and 2 points. Small components are physically separate road-adjacent strips; no unsupported connections are added.
- 168,727 candidate physics probes during baking; three blocked candidates omitted.
- Independent validation: 78,414 route samples, zero clearance/support failures.
- South and City Hall bridges retain both continuous walkways. The north bridge retains its one continuous southern walkway; its existing northern approach gap is not filled by an invented connection.

## Rebuild after saved road edits

Run Godot headless against the project with `--script assets/super-city/tools/bake_authored_pedestrians.gd`, then validate with `--fixed-fps 60 --script tests/test_authored_pedestrian_routes.gd --quit-after 800`.

Use an absolute `--log-file` path if user:// logs are unavailable. The offline navigation bake runs in bounded tiles and exports to the existing crowd graph. It does not add runtime NavigationAgents or modify physical sidewalk geometry. Do not run the old `generate_pedestrian_network.gd` entry point: it is retained only for shared authoring utilities and its old manifest does not match the city.

Saved district choices and inherited marker paths are preserved. Obsolete marker containers may remain for scene compatibility; absent inventory modules cannot spawn civilians. `INVENTORY.md` lists current modules. Detailed audit outputs are in ignored `artifacts/`; the optional offline bake cache is in `.godot/`.

## Manual test

Restart Main to clear existing walkers. Enable Show Debug Routes on SuperCity/CityPedestrianRoutes to inspect cyan sidewalks and yellow crossings. Check the docks, City Hall surrounds, removed-road locations and park interior: there should be no ambient routes on those non-street surfaces. Then walk beside the current roads and cross each bridge to check population and slopes. Test capsule/full-character transitions by flying up and descending.

Headless route, district-toggle, crowd lifecycle and lane-spacing checks pass. No visual playthrough or FPS claim was made. Separate startup messages reported certificate/settings environment warnings and a stale standalone harbor bake fallback; harbor geometry was not changed by this cleanup.

## Changed navigation files

- `assets/super-city/tools/bake_authored_pedestrians.gd`
- `assets/super-city/pedestrians/network.json`, `INVENTORY.md`, this README
- `scenes/npcs/city_pedestrian_routes.tscn`, `scenes/super_city.tscn` (route markers)
- `tests/test_authored_pedestrian_routes.gd`

Streetlamp changes are documented in `assets/sky/CITY_LIGHTS.md`.
