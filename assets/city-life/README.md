# City life and Pine Pass

`scenes/city_life.tscn` is instanced at `SuperCity/CityLife`, so the additions appear in both the playable Main scene and the standalone city preview. All models are original low-poly Godot geometry. No addons are required.

## What is in the city

| Addition | Count / location |
| --- | --- |
| Roadstar Tires blimp | One 104 m airship, circling above the skyline every 7 minutes |
| Baseball sandlot | One 68 × 62 m backlot in West Village, centered at X −1051, Z 116 |
| Retro diners | Five rounded red diners with chrome roofs, warm windows, signs, counters and stools |
| Hotdog stands | 38 carts with striped umbrellas and condiment bottles |
| Benches / bus stops | 85 benches and 24 shelters |
| Fire hydrants | 170 |
| Steaming road grates | 35, with 12 inexpensive animated billboards per grate |
| Pine Pass highway | About 1.9 km north from X −740, Z −960 to a mountain tunnel at X −1100, Z −2780 |
| Northern landscape | 4,943 batched pine/oak trees, seven faceted mountain peaks, extended background land |

The sandlot has bases, foul lines and poles, a mound, chain-link fences, bleachers, a scoreboard and nighttime floodlights. Four small courtyard buildings are hidden with their collision disabled in `super_city.tscn`; their original nodes and resource references remain intact. The field is scenery for traversal, without baseball gameplay.

Diner centers (X, Z): (−772, 346.5), (312, 22.5), (668, 457.5), (1216, −178.5), (1448, −937.5). Their entrances are open and have small ramps. Shelters and carts sit toward the back of sidewalks, leaving walking space. Placement checks avoid building footprints, streets and existing lamp posts. Shops and bus stops are decorative; there is no purchasing or bus service.

The highway has two carriageways, lane markings, guardrails, a median barrier, embankments and overhead signs. It ends inside the dark Pine Pass tunnel as the boundary for the future region. Existing city traffic remains on its current road network; the new highway does not spawn commuter traffic.

## Blimp and lights

The blimp follows a smooth ellipse at about 360 m altitude, safely above the existing 241 m maximum roof height. Propellers spin, five beacons flash, and both advertising panels cycle four messages. The recorded advertisement plays spatially from its gondola when the listener is within 1 km, repeating every 70 seconds. It uses the existing Voice audio bus.

Roadstar Tires and its copy are fictional and original to this prototype. `audio/roadstar_ad.wav` was synthesized locally with the installed Windows SAPI voice. The game uses the baked `audio/roadstar_ad.res`, so playback needs no speech service or network access. WAV conversion uses Godot's native [AudioStreamWAV.load_from_file](https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html#class-audiostreamwav-method-load-from-file).

Neon/windows, diner lights, field floodlights and tunnel lamps follow the existing day/night controller. Blimp beacons remain visible during daylight. Game pause freezes the airship animation. `time pause` freezes only the sky's clock, allowing the rest of the city to keep moving.

Select the CityLife root in the Inspector to tune blimp altitude/lap time, animation speed, and advertisement volume/repeat/mute. These runtime values take effect when running the scene.

## Traffic behavior

TrafficControls has been removed: signal poles, stop signs, labels and animated signal lenses no longer spawn. The generator also omits them. TrafficManager remains active: cars retain junction pauses, queues, crossing reservations and exit checks, without traffic-light phase waits. Distant traffic remains active.

## Files and regeneration

- `scenes/city_life.tscn`: baked scenery and resource references.
- `scripts/city_life.gd`: airship, spatial ad and scenery lighting.
- `scripts/traffic/traffic_manager.gd`, `traffic_box_lod.gd`: vehicle integration.
- `scenes/super_city.tscn`: scene instance and four sandlot building overrides.
- `assets/city-life/meshes`, `audio`, `steam.gdshader`, `fence.gdshader`: native assets.
- `locations.json`: chosen backlot and diner sites; `placements.json`: counts and street furniture footprints.
- `tools/plan_locations.cjs`: deterministic layout search using the existing city manifest.
- `tools/generate_city_life.gd`: offline authoring; reuses the waterfront tool's primitive helpers and the park's original pine/oak meshes.
- `tools/render_city_life.gd`: reproducible day/night GPU captures in `artifacts/city_life`.
- `tests/test_city_life.gd`, `tests/test_city_traffic_controls.gd`: geometry/traversal and traffic integration checks.

Run tools from the project root. Rebuild this layer only; the older whole-city generator would replace later scene edits. The city-life generator must run with a graphics renderer, because Godot's headless dummy renderer does not preserve authored MultiMesh transform buffers.

```powershell
$cityGodot = 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
& $cityGodot --path . --script res://assets/city-life/tools/generate_city_life.gd
& $cityGodot --path . --script res://assets/city-life/tools/render_city_life.gd
& $cityGodot --headless --path . --script res://tests/test_city_life.gd
& $cityGodot --headless --path . --script res://tests/test_city_traffic_controls.gd
```

## Validation and playtest

Godot 4.7.2 checks passed for road/building clearance, both highway carriageways, the tunnel entrance, player-sized capsules walking into all five diners, blimp loop/roof clearance/beacons/audio playback/muting, night lighting and pausing. The traffic-controls test now checks removal and continued physical/distant vehicle crossings. Existing intersection, box-LOD and far-LOD regression suites also passed. Day/night GPU captures were inspected and corrected. This is scripted validation, not a manual gameplay playthrough.

In Godot, run Main and use the developer console's `time night`. Look up for the flashing blimp, fly closer to hear its ad, enter a lit diner. Confirm that signal poles and stop signs are absent while moving cars continue through junctions. Visit the West Village sandlot and follow the northern road from (−740, −960) to Pine Pass. Check that the street additions feel comfortably spaced while sprinting, and that the blimp ad volume feels appropriate. The standalone SuperCity preview supports right-mouse look, WASD, Q/E for altitude and Shift for speed.
