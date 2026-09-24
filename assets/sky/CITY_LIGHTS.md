# City lighting

Street fixtures and vehicle lights now use `DayNightCycle.night_lighting` and its
`night_lighting_changed` signal. They fade in around dusk, remain on through the
night and fade out after sunrise. The existing console commands work immediately,
including while the console pauses the game.

## See it in Godot

1. Run Main, open the backtick console, enter `time night`, and close the console.
2. Walk along the streets near the park or fly to the western residential areas,
   downtown, and the eastern industrial district. Look for warm/cool pools on the
   pavement and light on building fronts.
3. Watch passing traffic: white headlights point forward onto the road and red
   rear lenses remain visible as cars drive away. Newly spawned cars inherit the
   current time. Distant traffic keeps small emissive lenses as its model changes.
4. Enter `time day` to check that beams and fixture emission switch off. Try
   `time sunset`, then `time speed 20`, and close the console to watch the fade.
5. Pick up/rotate a car to check that its beams follow it; destroy it to switch
   its lamps off. Return to `time speed 1` when finished.

## Placement and tuning

`SuperCity/NightLights` reads the placed, visible road modules and sidewalks
through `scripts/current_street_layout.gd`, including saved Main overrides.
The checked city produces 1,157 decorative posts. Contiguous straight road pieces
are merged for spacing; junctions retain corner fixtures. Poles sit 1.1 m outside
the carriageway, face the road, and are omitted where no sidewalk supports them,
another road crosses the base, a building/solid prop blocks them, or another post
is too close. Base height follows the current sidewalk. The old layout.json is
used only for existing building-frontage lights, not streetlamp placements.
Shared mesh batches keep the fixtures
inexpensive. They are visual props without collisions or destruction behavior.
The placement is deterministic and built when the scene runs, not baked into the
city generator or shown by an editor tool script.

The Inspector exposes spacing (72 m target), lamp energy/range, selection radius,
update interval, and the active-light budget (96). Changing spacing or the budget
requires rerunning the scene. West-side lights are amber, central lights warm
white, and east-side lights cool white. The nearest pool follows the camera in
both Main and the standalone city. Actual pavement illumination fades near its
budget/range boundary; distant fixture lenses remain emissive. Pavement spots
are shadowless; car headlights cast shadows nearby and fade at distance.

All seven car models and their paint variants inherit the rig through `Vehicle`.
`Headlights Enabled`, `Headlight Energy`, and `Headlight Range` are exposed on the
vehicle root (apply when it spawns). The rig has beam-angle/downward-angle tuning
in `scripts/traffic/vehicle_headlights.gd`. Lens mounts are fitted to the actual
car mesh with cached intersection results, so bumper/mirror bounds do not leave
them floating away from the body. No per-car frame polling is needed.

Distant traffic uses a masked additive material pass on its existing silhouette
and flat meshes. This adds visible head/rear lenses without more physical lights,
traffic nodes, or changes to LOD geometry. The extra pass is removed during day.

Godot references:
[distance fading for lights](https://docs.godotengine.org/en/latest/classes/class_light3d.html),
[spotlight cone/range](https://docs.godotengine.org/en/stable/classes/class_spotlight3d.html),
[mesh intersection fitting](https://docs.godotengine.org/en/stable/classes/class_trianglemesh.html).
All new fixture geometry is built with Godot primitives; no external assets or
addons were added.

## Files and validation

Modified:

* `scenes/super_city.tscn` — NightLights node.
* `scripts/day_night_cycle.gd` — shared dusk/night lighting value and signal.
* `scripts/vehicle.gd` — inherited headlight rig and tuning.
* `scripts/traffic/traffic_box_lod.gd` — clock-driven distant lamp pass.

Added:

* `scripts/city_night_lights.gd` — placements, batched fixtures and light pool.
* `scripts/traffic/vehicle_headlights.gd` — beams, lenses and destruction handling.
* `scripts/traffic/traffic_night_lenses.gdshader` — distant car lenses.
* `tests/test_city_night_lights.gd` — placement, pool, day/night, car and LOD tests.
* `assets/sky/render_city_lights.gd` — reproducible rendered views.
* This document, Godot UID files, and generated `artifacts/night_lights/` previews.

Godot 4.7.2 validation: the night-light integration test passed with zero failures,
including every lamp position and all seven car models plus an inherited variant.
Day/night, vehicle engine audio, traffic silhouette LOD, and far traffic LOD
regressions passed. Real D3D12 / Forward+ views show street lighting, headlight
beams, daylight switching, aerial coverage and the distant lens material. These
are rendered checks, not a manual moving-player playtest. Sandbox certificate,
settings and shader-cache diagnostics are unrelated to these changes.

Run the checks with the project's Godot executable:

```text
godot --headless --path <project> --editor --import
godot --headless --path <project> --script res://tests/test_city_night_lights.gd
godot --headless --path <project> --script res://tests/test_day_night_cycle.gd
godot --headless --path <project> --script res://tests/test_vehicle_engine_sound.gd
godot --headless --path <project> --script res://tests/test_traffic_box_lod.gd
godot --headless --path <project> --script res://tests/test_traffic_far_lod.gd
godot --path <project> --script res://assets/sky/render_city_lights.gd
```
