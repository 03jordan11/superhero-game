# Coastal International and the extended coastline

The new `CoastalRegion` instance in `scenes/super_city.tscn` adds an airport west of the city and continuous green land beyond its former edges. It appears in both Main and the standalone SuperCity preview.

## Explore

- **Airport:** runway centered at X −3500, Z 200; terminal at X −3200, Z −285.
- **Access road:** leave the western junction at X −1460, Z −480 and follow the airport signs west.
- **Coast:** follow the waterfront east or west past the city boundary. The bay, existing docks and prison island stay open to the sea.
- **Night:** enter `time night` in the existing developer console, close it, and watch the runway, blue taxiway lights, tower beacon and aircraft strobes.

The airport has an approximately 1.9 km runway, parallel taxiway, an apron with three gates and jet bridges, a terminal/concourse, control tower, two open-front hangars, a parking lot, windsocks, maintenance vehicles and an access road.

## Flights

Two animated airliners share a 330-second circuit with a 100-second schedule offset. Each approaches runway 09 from the west, lands, rolls out, taxis to the third gate, waits for 25 seconds, pushes back, taxis to the runway, takes off eastward and turns out over the coast before returning. Two additional jets remain at the other gates.

The planes have swept wings, engines, cockpit/cabin windows, landing gear, navigation lights and flashing strobes. Landing gear hides during the airborne circuit. Aircraft are scripted AnimatableBody3D scenery with simple hull/wing collision; they are not player-piloted vehicles or a general air-traffic simulator. There is no passenger boarding or airport mission system.

Select `SuperCity/CoastalRegion` to adjust `Air Traffic Running`, `Air Traffic Speed` and `Airport Light Brightness`. Game pause freezes the flights. `time pause` only holds the sky clock. `flight_state` metadata on each live plane reports its current stage for debugging.

## Land and horizon

The native terrain extends 30 km east/west and 30 km inland, following an irregular coastline into the existing ocean. Beaches meet green low hills, and 5,038 additional pine/oak trees are batched by region. Existing city surfaces and the northern forest/highway are preserved. The airport occupies a flat plateau with an approach road sampled against the terrain.

An original transparent panorama image supplies layered distant ridges on a curved backdrop about 24 km away. Its endpoints taper into the ground, and its shading follows the night-light amount. This is distant visual scenery; the image itself has no collision. The terrain carries the walkable ground. Player and city-preview camera far planes are increased to 60 km so the landscape no longer disappears at the old viewing limit. Existing building visibility ranges are unchanged.

All new geometry and the panorama were authored locally with Godot. The trees reuse the project's original Central Park meshes. No third-party models, addons or image licenses are required.

## Changed files

- `scenes/super_city.tscn`: instances CoastalRegion and extends the preview camera's far plane.
- `scenes/player.tscn`: extends the player's camera far plane.
- `scenes/coastal_region.tscn`: new baked airport, land, forest batches and horizon.
- `scripts/coastal_airport.gd`: flight schedules, transforms, gear, strobes and night lights.
- `scripts/coastal_landscape.gd`: shared coastline/terrain measurements.
- `assets/coastal-airport/horizon.gdshader`, `textures/`, `meshes/`: new native assets.
- `assets/coastal-airport/tools/generate_coastal_airport.gd`: reproducible offline authoring.
- `assets/coastal-airport/tools/render_coastal_airport.gd`: day/night GPU previews.
- `tests/test_coastal_airport.gd`: geometry, real aircraft transforms, flight clearance/separation, lighting and pause checks.
- `assets/super-city/README.md`: links this addition.

## Validation and rebuilding

Run from the project root with the project's Godot 4.7 executable. The generator requires a graphics renderer because the headless dummy renderer does not preserve authored MultiMesh transforms. Rebuild this layer only; do not rerun the original whole-city generator over the later city additions.

```powershell
$regionGodot = 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
& $regionGodot --path . --script res://assets/coastal-airport/tools/generate_coastal_airport.gd
& $regionGodot --path . --script res://assets/coastal-airport/tools/render_coastal_airport.gd
& $regionGodot --headless --path . --script res://tests/test_coastal_airport.gd
```

Godot 4.7.2 editor import and the full Main scene launch completed without script errors. The airport, waterfront, city-life and city-preview-camera suites passed. The airport checks cover extended ground, preserved open water, runway and access-road collision, flight continuity, gate dwell/pushback, departure climb, clearance against actual scenery, aircraft separation, real starting transforms, lighting and pausing. The minimum sampled separation between active aircraft is about 157 m. Day/night rendered previews were inspected and corrected; they live in `artifacts/coastal_airport`.

For a manual playtest, watch at least one landing and one departure from the runway, follow a plane around its full circuit, walk along the new access road, and fly east/west along the coastline at both street and rooftop altitude. Compare `time day` and `time night`. The screenshots and scripted checks do not substitute for testing traversal feel in the game.
