# Authored city pedestrian navigation

Updated September 17, 2026. The crowd research/recommendations are saved in
[docs/crowd_system_review.md](../../../docs/crowd_system_review.md).

## What changed

Routes now use the saved Main/SuperCity geometry rather than the obsolete
`assets/super-city/layout.json` sidewalk inventory. Coverage includes:

- Current road-module sidewalks, independent sidewalk pieces, narrow alleys,
  and actual painted crosswalk positions.
- City Hall's updated surrounding sidewalks.
- Curved river promenades, coastal pavement, and both concrete piers.
- Central Park trails, entrances, and Bow Bridge.
- Walkways on all three river bridges.

The existing district checkboxes, AStar graph, population manager, civilian
behavior and capsule/full-character handoffs remain in use. Crossing behavior
is unchanged: the existing fixed wait still applies. Signal coordination,
traffic gap checks and other crossing improvements are deferred. Airport and
mountain/highway navigation are excluded.

The graph stores height. Capsules follow bridge grades; full civilians check
height along the route while physics handles the slope. An upper bridge does
not connect to a lower promenade just because their overhead views overlap.

## Assessment and remaining geometry gaps

The export has **271 modules, 19,246 points and 20,038 segments**. Its largest
component contains **18,196 points**, spanning both city banks and the park.
Eight smaller components occupy physically separate pavement. They support
local walking without inventing connections through missing pavement.

- The south and City Hall bridges each have two continuous walkway routes.
- The north bridge has a continuous southern walkway linking the riverbank
  paths. Its northern approach has a break on the west side: the graph stops
  around X=100 and resumes around X=133 at Z=-972. The bridge's presence does
  not establish a connection to every adjoining street sidewalk.
- Coastal pavement around Z=784-786 is separated from the southern street
  sidewalk around Z=772. The intervening gap is not included as a paved route.
- The west concrete pier starts at Z=800, separate from coastal pavement. The
  east pier extension joins its existing paved base.
- A small City Hall-area sidewalk strip and several park trail ends are isolated
  by actual surface boundaries or obstacles. Candidates through garage structure
  collision, low bridge structure and the airport access-road boundary were
  excluded.

This pass changes navigation; it does not add sidewalk geometry or move props.
The river promenades remain local walking components where there is no clear
paved approach into the street network.

## Testing in Godot

1. Reload `super_city.tscn` after accepting external changes, then run Main.
2. On `SuperCity/CityPedestrianRoutes`, enable **Show Debug Routes**. Each district
   also has **Show Debug**, **District Enabled**, and route checkboxes. Cyan/purple
   show walking/alley routes. Yellow marks crossings, including short approaches
   where a person's footprint enters them. Population remains in `CivilianCrowd`.
3. Walk near City Hall and park entrances. Fly between bridges and river paths,
   then descend to watch capsules become full civilians. Watch for floating,
   clipping or stopping on inclines.
4. Inspect the coastal/pier gaps above. NPCs should turn back within connected
   pavement rather than cut across empty space or unmarked roads.

Headless validation passed **108,610 route samples** for walking-area membership,
ground support and 0.55 m-radius / 1.8 m-high body clearance. Ground rays allow a
2 cm lateral retry at imported triangle seams. Full civilians walked uphill and
downhill on City Hall bridge; capsule grade-following and handoff height passed.
Seven existing regressions passed: district controls, lane spacing, damage
lookup, pilot movement, stuck recovery, crowd lifecycle and capsule LOD.
These are automated checks, not a visual playthrough or an FPS benchmark.

## Rebuilding after edits

Save the city first, then run:

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://assets/super-city/tools/bake_authored_pedestrians.gd
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --fixed-fps 60 --script res://tests/test_authored_pedestrian_routes.gd --quit-after 800
```

The offline tool uses Godot's navigation baker in bounded tiles, then exports
into the existing AStar graph. There is no runtime baking or new NavigationAgent.
Box-collider clearance is baked; actual physics rejects unsupported or obstructed
candidate routes. Heights are projected back onto original pavement.

Saved checkbox choices and inherited marker paths are preserved. New modules
are enabled in SuperCity and route markers are updated. Obsolete empty marker
containers remain compatible with inherited scene overrides. The old
`generate_pedestrian_network.gd` remains as legacy/base utilities; do not run
its old-layout generation entry point for this city.

`INVENTORY.md` lists modules. Detailed reports are under ignored `artifacts/`.
The optional offline bake cache is under `.godot/`; a normal rebuild does not
require it. Profile the expanded graph before making any performance claims.

## Changed files

- `assets/super-city/tools/bake_authored_pedestrians.gd` and a legacy-tool notice.
- `assets/super-city/pedestrians/network.json`, `INVENTORY.md`, and this README.
- `scenes/npcs/city_pedestrian_routes.tscn` and navigation settings/markers in
  `scenes/super_city.tscn`.
- `scripts/npc-scripts/city_pedestrian_network.gd`, `pedestrian_surface_index.gd`,
  `capsule_civilian.gd`, and `routed_civilian.gd`.
- `tests/test_city_pedestrian_network.gd` and `test_authored_pedestrian_routes.gd`.
- `export_presets.cfg`, explicitly including the active navigation JSON.

The crowd review is separate. City meshes, props, road geometry, traffic behavior,
population defaults and crossing wait rules were not changed in this pass.
