# TrafficControls removal

Removed `SuperCity/CityLife/TrafficControls`: 845 nodes, including 624 MeshInstance3Ds and 80 Label3Ds, plus 840 exclusive subresources. All retained non-root node blocks in `city_life.tscn` are unchanged. Signal registry, phase timing and 216 lens-material updates are removed. The scenery generator no longer creates signals or stop signs.

TrafficManager and its vehicle resources/scripts were not changed. Physical cars retain intersection pauses, reservations, queues and exit checks; without a signal provider they no longer wait for red/amber phases. Distant traffic remains active. Forests, streetlamps, benches and the blimp were not removed.

## Modified files

- `scenes/city_life.tscn`
- `scripts/city_life.gd`
- `assets/city-life/tools/generate_city_life.gd`
- `assets/city-life/tools/render_city_life.gd`
- `assets/city-life/placements.json`
- `assets/city-life/README.md`
- `tests/test_city_traffic_controls.gd`
- `tests/test_city_life.gd`
- `tests/test_city_poi_integration.gd`
- `tests/profile_city_followup.gd` (skip absent scenery branches)
- `benchmarks/FOREST_TRAFFIC_BASELINE.md` (clarified final scope)
- `docs/traffic_controls_removal.md` (this report)

## Validation

Godot 4.7.2 headless: traffic-controls removal regression passed, including physical vehicle spawn/pause/crossing/reservation release and distant crossing; CityLife suite passed; generator parse check passed. POI integration reported three unrelated assertions about pedestrian bank connectivity, district module count and City Hall X position; these inputs were not changed. TrafficControls absence and remaining integration assertions passed. Environment emitted root certificate/settings-access warnings.

No FPS benchmark was rerun and no FPS gain is claimed. Gameplay was not visually verified.

Run Main afresh: signal poles and stop signs should be gone; cars should still spawn and cross junctions. Streetlamps, benches, forests and the blimp should remain.

Scene edit audit and the pre-removal scene backup are in `artifacts/traffic_controls_removal/`.
