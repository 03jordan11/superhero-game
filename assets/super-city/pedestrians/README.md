# District pedestrian graphs

The citywide network is installed at `SuperCity/CityPedestrianRoutes`. The original two-block pilot remains available as `res://scenes/npcs/civilian_route_pilot.tscn`, but it is no longer the active test instance in Super City.

## Editor workflow

Open `res://scenes/super_city.tscn`, expand `CityPedestrianRoutes`, and select a district. Under **Route Checkboxes**, each named boolean enables one block or waterfront module. Checkboxes are sorted by row and column. **Enable all routes** and **Disable all routes** are convenience buttons for that district; **District Enabled** is a master switch that preserves the individual choices. **Show Debug** hides the district's lines without disabling its network.

For editing reusable defaults, open `res://scenes/npcs/city_pedestrian_routes.tscn` directly. To make a Super City-specific override, its `CityPedestrianRoutes` instance is already marked editable. Save the scene after changing settings. `main.tscn` was not edited: its existing Super City instance inherits the new network. Do not add a second copy of the network there.

```text
SuperCity
  CityPedestrianRoutes
    WestVillage
      Block_01_01
        StartHere
      ...
    NorthHeights
    Parkside
    CivicCenter
    FinancialQuarter
    Eastbank
    FoundryWard
    Docklands
```

Module nodes and `StartHere` markers are saved scene nodes. Debug lines are generated in the editor. Select a module's **StartHere** marker and press **F** to frame its location in the 3D editor. Ambient civilians now live under the separate `CivilianCrowd/ActiveCivilians` parent; see [crowd controls and tests](CROWD.md).

An enabled module contributes links to one shared navigation graph. Enabled neighboring modules can connect, including across district boundaries. Disabling a module removes its links; this can intentionally disconnect an area. Other modules' shared boundary points remain usable through their own enabled links. The graph creates no civilians and does not limit population to one per module.

## Root controls

Select `CityPedestrianRoutes`:

| Setting | Effect |
| --- | --- |
| Network Enabled | Master switch for active links; no new ambient spawns while disabled |
| Show Disabled Routes | Show unchecked modules as gray context lines |
| Crossing Passing Margin | The previously tested margin beside crossing stripes |
| Enabled Modules | Read-only count of enabled checkboxes under enabled districts |

The reusable route scene starts with one module per district enabled. Super City's existing overrides are preserved. Enable the districts/modules where you want civilians to walk; population and visibility controls are now on `CivilianCrowd`.

Changing route checkboxes while running rebuilds topology and gradually retires civilians with old journeys. New civilians populate nearby enabled routes. Disabling `CivilianCrowd/Crowd Enabled` allows graph-only inspection without changing connectivity. The CivilianCrowd/CapsuleLOD child now provides a lightweight distant population; see [capsule controls](CAPSULE_LOD.md).

Local passing treats routes as preferred paths. It tries pavement first, clear supported building setbacks next, and brief road detours last, then rejoins the route. Solid obstacles remain blocking. Outside the route, shallow ground probes reject drops and the current water placeholders. `Waypoint Arrival Distance` on the routed civilian defaults to 0.2 m. This is a small local avoidance rule; fully blocked passages can still cause waiting.

Debug legend: **cyan sidewalks**, **purple alleys**, **yellow crossings**, **gray disabled modules** when that option is enabled. Debug lines have no collision. The preview images in this directory show the entire network enabled for inspection, not the default eight-module selection.

## Coverage and organization

There are **260 modules, 5,261 graph points, and 6,133 segments**, forming exactly **two connected banks when all modules are enabled**. Every generated graph point has a connection. There are **no river-crossing links**, including over the current flat road placeholders. Sidewalks on those placeholders are clipped at the river boundary. The quay and pier remain pedestrian-accessible; river and bay surfaces do not.

| District | Modules | Initially selected module |
| --- | ---: | --- |
| West Village | 36 | Block_01_01 |
| North Heights | 56 | Block_01_04 |
| Parkside | 27 | Block_05_05 |
| Civic Center | 32 | Block_05_04 |
| Financial Quarter | 32 | Block_10_06 |
| Eastbank | 41 | Block_05_10 |
| Foundry Ward | 19 | Block_06_14 |
| Docklands | 17 | Block_10_14 |

Block names identify approximate north-to-south row and west-to-east column in an organizational grid. District boundaries can split an organizational cell into separately named modules. Waterfront and pier modules have descriptive names. The full [inventory](INVENTORY.md) lists segment counts, historical reference endpoint IDs, and neighboring modules. Ambient journeys follow enabled connections and do not use those fixed endpoint pairs.

The route network covers the authored sidewalks, alleys and promenades. The green park interior has no pedestrian routes yet, so population uses its perimeter. Ordinary building interiors, rooftops and water have no spawn routes. Civilians retain existing movement, crossing waits, passing and animation behavior, with random starts along segments and per-civilian sideways preferences.

## What to test next

1. Select a district and toggle one **Route Checkboxes** entry. Its colored lines should appear/disappear. Toggle **Show Disabled Routes** to see unchecked modules in gray, then turn it back off.
2. Save, close and reopen the route scene. Verify the checkbox selections persist.
3. Run Super City with F6. Visit a selected module's `StartHere` location. Expect one civilian walking continuously between two reachable destinations, pausing before crossings and going around people when there is safe space.
4. Enable two or three neighboring modules in one district. Expect the graph to join at their shared boundaries. Each enabled module supplies one test civilian until the cap is reached; journeys may share segments or pass into another enabled module.
5. Lower **Max Test Civilians** to 2 with several checkboxes enabled. The read-only count and actual population should be 2; extra enabled route lines should remain visible.
6. Disable **Spawn Test Civilians**, enable all modules, and inspect the river. Lines must stop at the water; no route should connect the two banks. Inspect the pier, park perimeter and district boundaries for missing connections or lines crossing walls.
7. Report any sticking, unsafe corner cutting or route that does not match current geometry using **district + module name**, plus the civilian's status label if visible.

The eight default civilians moved in a short headless check; this is not a full visual traversal or crowd performance assessment. Player spawning was not tested. The user retains control of player placement and the next visual walkthrough.

## Generation, validation and fallback

`assets/super-city/tools/generate_pedestrian_network.gd` is an offline authoring tool. It reads the layout's sidewalk/alley rectangles and the current Super City building collision footprints. It finds shared surface portals, inserts clear orthogonal turns where diagonals would clip corners, and adds the setback crosswalk connections on ordinary road approaches. Links are sampled with a 0.56 m body-clearance margin against surface unions, buildings and excluded water.

Generation writes only the pedestrian data, inventory and route component scene. It does not regenerate or repack city geometry. Existing root controls and district checkbox dictionaries in the route component scene are preserved when regenerating; new modules default off. Preserve a backup before intentionally rebuilding after layout edits, especially if you have manually edited module nodes. Overrides saved on a parent scene remain that parent scene's responsibility.

```powershell
$cityGodot = 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
& $cityGodot --headless --path . --script res://assets/super-city/tools/generate_pedestrian_network.gd | Out-Host
& $cityGodot --headless --path . --fixed-fps 60 --quit-after 500 --script res://tests/test_city_pedestrian_network.gd | Out-Host
```

The graph check covers actual two-component connectivity, named checkbox read/write and serialization, and absence of graph-owned test spawning. `tests/test_civilian_crowd.gd` covers the separate population lifecycle. Earlier graph previews were rendered during authoring; ambient population and skin appearance still require visual assessment. The headless environment's existing certificate-store warning did not prevent checks.

Generation currently targets `super_city.tscn`, not arbitrary new geometry placed only in `main.tscn`. Local passing handles temporary obstacles, but added sidewalks or permanent layout changes require updating the source surface data and regenerating. Do not assume old graph data automatically adapts to future edits. Adding a bridge later means adding its walkable surfaces and explicit bank connections, then checking connectivity; no bridge module is active now.

For a quick population fallback, turn **Crowd Enabled** off. To use the old pilot, keep the crowd disabled and instance `res://scenes/npcs/civilian_route_pilot.tscn` at identity in the city.

## Changed files

- `scenes/super_city.tscn`: swaps the old pilot instance for the new district route component; other existing scene text is preserved.
- `scenes/npcs/city_pedestrian_routes.tscn`: saved district/module hierarchy and defaults.
- `scripts/npc-scripts/city_pedestrian_network.gd`: active shared graph and debug batches.
- `scripts/npc-scripts/civilian_crowd.gd` and `scenes/npcs/civilian_crowd.tscn`: nearby ambient population and settings.
- `scripts/npc-scripts/pedestrian_district.gd`: per-district named checkboxes and bulk buttons.
- `assets/super-city/tools/generate_pedestrian_network.gd`: offline generator.
- `assets/super-city/pedestrians/`: graph JSON, inventory, this guide and previews.
- `tests/test_city_pedestrian_network.gd`: focused topology and checkbox checks.
- `tests/test_civilian_crowd.gd`: nearby population lifecycle check with a movable marker.
- `tests/test_civilian_route_pilot.gd`: continues to test the preserved original pilot in isolation.
- `CIVILIAN_CROWD_PLAN.md` and `assets/super-city/PEDESTRIAN_PILOT.md`: current checkpoint and entrypoint notes.

`main.tscn`, player code, buildings and road assets are preserved. The shared routed civilian now also supports segment starts, connected ambient journeys and sideways offsets.
