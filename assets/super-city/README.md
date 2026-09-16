# Super City

The September 2026 [POI integration](poi-integration/README.md) places city hall,
the hospital, both banks, a police station and a firehouse in the city, with
revised pavement and A* routes. There are now 2,043 generated building instances
plus six POIs. The original generation figures below are retained as historical
context; see the integration notes for current placements and validation.

Open `res://scenes/super_city.tscn` in Godot. This is a baked, editable city scene using the existing 50 generated building designs. It has no runtime generator or CityCrafter dependency. No player or camera is included; drag in your player as planned. `TraversalStarts/ParkToSkyline` at `(-520, 1.4, 286)` is an optional placement reference.

## Layout

The total footprint is 3,000 × 2,000 m: X -1500 to 1500, Z -1000 to 1000. Positive Z is south, toward the bay. The southern 200 m is the blue bay placeholder, included in these bounds.

There are 2,060 building instances, with unchanged source meshes, dimensions and collisions. Blocks combine street frontage, inner courtyards and alley frontage. Low roofs in the west and north transition toward taller park frontage and a dense southern commercial skyline, providing different street, rooftop and flight routes.

| District | Buildings | Character |
| --- | ---: | --- |
| West Village | 530 | Lower residential streets and close rooftop routes |
| North Heights | 528 | Residential blocks with increasing height toward the center |
| Parkside | 147 | Taller mixed frontage beside the park |
| Civic Center | 232 | Commercial transition into downtown |
| Financial Quarter | 138 | Tallest concentration along the river and bay |
| Eastbank | 372 | Residential and mixed skyline across the river |
| Foundry Ward | 67 | Factories, warehouses and open industrial yards |
| Docklands | 46 | Industrial waterfront and pier approach |

Central Park fills 508 × 604 m with a lake, walking trails, varied woodland, lanterns and hidden houses. See [Central Park](../central-park/README.md) for editing, nighttime discoveries and validation. The approximately 140 m wide river now has animated water and stone embankments, opening into an ocean south of the city. Five road crossings connect both banks. The original 240 × 160 m pier apron now connects to working docks with cranes, cargo and boats. Blackwater prison island lies offshore. See [Waterfront](../waterfront/README.md) for locations, tuning and validation. Water surfaces have submerged beds; swimming is not implemented.

## Roads, sidewalks and ground

[Coastal International and the extended coastline](../coastal-airport/README.md) add a western airport with scheduled arrivals/departures, beaches and wooded terrain extending 30 km beyond the city, plus a distant panorama horizon. The western access road begins at X −1460, Z −480.

- Standard streets: 20 m carriageway with 4 m sidewalks on each side.
- Selected avenues: 28 m; quieter local streets: 12 m.
- 100 alleys: 6 m wide, connecting to the street network.
- Riverside walks: 6 m; waterfront promenade: 10 m, with a broad pier apron.
- Road top: Y 0.03; sidewalk top: Y 0.03 (flush with roads to remove the raised curb); ground: Y 0; park edges: Y 0.025, rising into low hills inland.

Road textures include asphalt grain, lane markings and intersection crosswalks. Sidewalks use a custom repeating slab texture. These are generated native ImageTexture resources in `textures/`. The separate [City Life layer](../city-life/README.md) adds diners, hotdog carts, benches, bus shelters, hydrants, traffic controls, steaming grates, a West Village baseball sandlot, an advertising blimp and the forest highway to Pine Pass. Four original West Village courtyard buildings are hidden for the sandlot; the district table above retains the original generated instance counts.

All road and sidewalk bodies have exactly this structure:

```text
StaticBody3D
  MeshInstance3D
  CollisionShape3D
```

The city combines 645 road patches and 1,257 sidewalk patches into 24 spatial chunks each. Their static concave collisions follow the actual slab surfaces. Ground is cut around paved surfaces to avoid overlapping top faces and distant flickering. Park, ground and blue placeholder bodies also have mesh and collision children.

`prefabs/` contains reusable 40 m long `road_12m.tscn`, `road_20m.tscn`, `road_28m.tscn`, `alley_6m.tscn` and `sidewalk_4m.tscn`. These simple pieces use BoxShape3D collisions with the same three-node structure.

Building visibility distances are baked as instance overrides: 850 m for buildings up to 60 m tall, 1,500 m for buildings up to 130 m tall, and 2,200 m for taller buildings, with 60 m margins. Adjust these in the Inspector if your flight altitude exposes disappearing buildings. Source building assets are untouched. Existing building collisions retain their original simplified shape, including any conservative boxes around stepped roofs. Performance and traversal feel still need your in-game assessment.

## Files and editing

- `scenes/super_city.tscn`: editable city, organized by surface type and district.
- `assets/super-city/meshes/`, `materials/`, `textures/`, `prefabs/`: authored city resources.
- `layout.json`: building placements, surface rectangles and route markers.
- `tools/generate_super_city.gd`: deterministic offline authoring script.
- `tools/city_mesh.gd`: mesh, UV and collision construction helper.
- `tools/validate_super_city.gd` and `validate_surfaces.gd`: geometry and physics checks.
- `tools/render_super_city.gd`: six views of the actual scene saved in `previews/`.

The scene is ready to edit directly; generation is not required to open or run it. Regeneration overwrites the city scene and its generated resources, so preserve a copy of any manual edits before rerunning the generator. No changes were made to the project's current main scene, player, controls or existing building packs.

To run tools from the project directory in PowerShell, substitute your Godot executable if needed:

```powershell
$cityGodot = 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
& $cityGodot --headless --path . --script res://assets/super-city/tools/generate_super_city.gd | Out-Host
& $cityGodot --headless --path . --script res://assets/super-city/tools/validate_super_city.gd | Out-Host
& $cityGodot --headless --path . --script res://assets/super-city/tools/validate_surfaces.gd | Out-Host
& $cityGodot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --script res://assets/super-city/tools/render_super_city.gd | Out-Host
```

## Validation and your playtest

Godot 4.7.2 loaded and ran the authoring, validation and preview scripts. Geometry validation passed: all 50 assets appear, building footprints do not overlap each other or reserved surfaces, all road patches connect, and mesh winding, collisions, scene references and body structure are valid. Eight named surface-height probes and 4,180 coverage samples passed. Exact shared triangle-edge ray misses were checked with four adjacent rays; these numerical seam cases are counted in `tools/surface_report.json`. Detailed geometry results are in `tools/validation_report.json`.

Six rendered views were inspected. Preview rendering shows all buildings regardless of distance and uses brighter ambient lighting; these overrides do not modify the scene. A Windows root-certificate-store message appeared during headless validation, without preventing resource loading or checks.

No player was included or tested. After adding yours, test curb transitions and alley entrances on foot, rooftop jumps from West Village toward Parkside, the five flat river crossings, downtown street flight, and landings around the pier edge. The green park provides a broad open area for comparing jump and flight distances.
