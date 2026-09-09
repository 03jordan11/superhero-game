# One-civilian route pilot

**Current entrypoint:** Super City now uses the district-organized network documented in `pedestrians/README.md`. This original two-block pilot is preserved as a fallback component and in its isolated smoke test. The location/instructions below describe that component when manually instanced; it is not also running alongside the citywide network.

Status: implemented; short headless smoke check passed. Visual walking, turning, crossing and obstruction behavior await the user's assessment. No crowd streaming, density controls, navigation mesh or new animations have been added.

## Where to find it

Open `res://scenes/super_city.tscn` and run the current scene (F6). It now includes one `CivilianRoutePilot` instance, alongside the existing player. Player placement is unchanged.

The civilian starts at **(-572, 0.04, 80)** on the sidewalk immediately west of the central park, near the middle of the block. In the editor, expand `CivilianRoutePilot`, select `StartHere`, and press F to frame the location. The pilot instance is editable. To adjust its defaults directly, open `res://scenes/npcs/civilian_route_pilot.tscn` and select `Civilian`.

The pilot component scene contains no environment or player; run it inside Super City, not by itself. Keep the component at its authored identity transform so its graph remains aligned with the city.

## What to watch

1. **Start and walk:** The civilian starts walking south immediately using the existing Walk animation at 2.5 m/s. It follows a fixed itinerary so repeated tests are comparable.
2. **First crossing:** After roughly 28 seconds, it reaches (-573.5, 148), waits 1.2 seconds, and crosses to (-573.5, 172). The yellow route follows the painted crossing on the road approach, outside the junction. The 3 m crossing band is set back 2 m from the intersection. It should leave the road immediately onto the opposite sidewalk, without wandering along the carriageway.
3. **Alley:** It turns west along the sidewalk, then enters the alley centered on X -650 in the southern block (Z 172–304). Alley pavement is allowed even though it shares the asphalt appearance of roads.
4. **Corners and destinations:** It should keep walking through corners and itinerary destinations without switching to Idle. Scheduled pauses happen only before crossing. The circuit includes both blocks, both alleys, the crossing in both directions, and repeats.
5. **Block its path:** Stand directly ahead on the sidewalk or spawn another civilian there. Expected status: `Passing`, as it chooses a clear side, goes around, then rejoins its route. Try the sidewalk center and either edge. The full capsule must stay on pavement. If both sides are blocked or the obstacle is too wide, `No safe passing space` is a necessary safety stop; it must not force its way into the street. Dense crowd negotiation and dynamic rerouting remain future work.
6. **Watch for faults:** Report sticking while the route is clear, diagonal corner cutting, entering roads outside the yellow route, feet floating/sinking, abrupt turns, animation sliding, or the status staying `Off route — stopped`. Include the approximate location/status when possible.

Keep the first route assessment calm. Existing damage, hit reactions, fleeing and death still take over if the civilian is attacked. Panic routing and recovery onto the graph are not implemented, so an attacked civilian may leave the route under its old flee behavior; restart the scene for another calm circuit.

Debug lines: **cyan = sidewalk**, **purple = alley**, **yellow = crossing**. A label above the civilian displays route status. This is debug geometry only and has no collision.

## Inspector settings

On `Civilian` (inherited walking settings plus the new **Pedestrian Route** category):

| Setting | Purpose |
| --- | --- |
| Walk Speed | Existing movement speed, default 2.5 m/s; try 4–5 temporarily to inspect the circuit sooner |
| Route Enabled | Stop/resume calm route walking without falling back to random wandering |
| Crossing Wait Seconds | Pause on the sidewalk before entering a crossing |
| Obstacle Lookahead | How early the civilian detects something ahead and plans to pass |
| Passing Offset | Sideways offset of the passing maneuver, default 1.25 m |
| Sidewalk Clearance | Extra clearance beyond the civilian capsule radius at walkable boundaries |
| Show Route Status | Show the debug label |
| Allow Crossings | If off, a destination requiring the crossing is unreachable and the civilian waits |
| Route Graph Path | Reference to this pilot's shared route graph |
| Start Point ID / Patrol Stop IDs | Authored start and repeatable destination sequence; IDs refer to the graph JSON |

On `RouteGraph`, **Debug Visible** toggles the colored lines. **Crossing Passing Margin** defaults to 0.5 m beside each edge of the painted crossing: this allows a full capsule to pass someone while crossing, without enabling ordinary road wandering. The painted markings remain unchanged. **Graph File** selects the JSON topology. Reload the scene after changing the graph file or start/itinerary configuration. The start position must match Start Point ID; the character stops safely instead of teleporting to a nearby route when misconfigured.

Speed and personal behavior settings belong on the civilian. Later, density, maximum active civilians, spawn radius and LOD limits should live on a shared crowd controller/settings resource. That will let a graphics preset adjust the population globally without editing hundreds of civilian instances. No unused population settings are exposed in this pilot.

## Scope, checks and fallback

The graph contains 15 points and 18 bidirectional links spanning two blocks. Godot AStar3D selects paths through these explicit links. We do not connect arbitrary nearby points, bake the whole city, or regenerate existing city geometry. For the pilot's single crossing, disabling crossings rejects paths that use it; alternate crossing-free route search across a larger graph is future work.

`tests/test_civilian_route_pilot.gd` checks scene loading, graph connectivity, invalid destinations, crossing restriction, physical walking, passing one stationary character while staying on the sidewalk, existing Walk animation selection, and the disable switch. It removes the player before entering the scene tree. It is not an exhaustive route, gameplay, performance or visual test. A rendered intersection preview also confirmed that the crosswalk markings are outside the junction instead of overlapping its corners.

The check passed on Godot 4.7.2. Headless Godot reported the environment's existing root-certificate-store warning, but no script/scene errors occurred. Existing city text was verified unchanged apart from the pilot resource, instance and editable-instance declaration.

For fallback, remove the `CivilianRoutePilot` instance from Super City. For a temporary pause, uncheck the civilian's Route Enabled setting. Hiding a node alone does not stop its physics. The original civilian scene/script and shared NPC movement/avoidance scripts are unchanged.

## Files

- `scenes/super_city.tscn`: adds the pilot instance only.
- `scenes/npcs/civilian_route_pilot.tscn`: one civilian, shared graph and start marker.
- `scenes/npcs/routed_civilian.tscn`: opt-in civilian variant using the existing model and animations.
- `scripts/npc-scripts/routed_civilian.gd`: route following, pauses, safe stopping and Inspector settings.
- `scripts/npc-scripts/pedestrian_route_graph.gd`: graph loading, AStar routing and debug lines.
- `assets/super-city/pedestrian_pilot.json`: pilot points and typed connections.
- `tests/test_civilian_route_pilot.gd`: short smoke check.
- `CIVILIAN_CROWD_PLAN.md`: staged plan and implementation checkpoint.

Revision after the first walkthrough: updated route-following and graph scripts, the pilot JSON and smoke test; removed corner/destination pauses; added constrained passing. `assets/super-city/tools/generate_super_city.gd` now paints approach crosswalks. `tools/update_crosswalks.gd` updates existing road visual resources from the layout manifest without repacking scenes or changing collision geometry. It is an offline asset update, not a runtime script. Scene files, including `main.tscn`, were not edited for this revision. Scenes sharing these road resources receive the visual correction too.

After visual feedback, refine this single civilian before enabling crowd behavior or increasing population.

Crosswalk passing follow-up: added the crossing-only margin to fix the previous safety rejection (1.25 m passing offset plus capsule clearance exceeded the old 1.5 m half-width). A short check passed for a stationary person in the crossing in both directions, including full-body corridor containment and continued road exclusion during normal sidewalk walking. Re-test by standing in the crosswalk, letting the civilian pass and watching it return to the sidewalk. Completely blocked routes can still require waiting. No scene files, road visuals or player behavior changed in this follow-up.
