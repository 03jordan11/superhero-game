# River, South Harbor and Blackwater Island

`scenes/waterfront.tscn` is an authored, editable scene instanced by SuperCity. It replaces the old blue river/bay placeholder with flowing river shading and a broad ocean beyond the southern waterfront. The original water placeholder nodes remain hidden with collision disabled, preserving their paths. Existing street crossings, traffic, park, buildings and controls remain intact.

## Included

- River water with irregular animated ripples, reflections and edge foam. Stone retaining walls, coping, railings, night lamps and structural bridge piers follow the existing city channel.
- Ocean extending 90 km across and 60 km south, with calmer distant detail to avoid repeating wave patterns at flight altitude.
- South Harbor: two long timber piers, connecting boardwalk, fishing/ferry fingers, mooring bollards, two cranes, container stacks, cargo crates, a harbor office and night lighting. The existing concrete apron is retained.
- Blackwater Penitentiary: a roughly 620 × 480 m rocky island, solid coastal outcrops, an accessible boat landing and sloping road, open front gate, walled yard, two barred-window cell blocks, administration building, exercise court, guard towers, wall walks and a coastal beacon. Building exteriors and roofs are solid; cell-block interiors are not modeled.
- Nine boats in four styles: tug, fishing trawler, ferry and sailboat. Boats stay moored/anchored and gently bob; they are scenery rather than controllable vehicles. Animated hull collisions support landings. Red/green navigation lenses illuminate at night.
- Eight channel buoys. Harbor, prison, boat and beacon lights follow the existing day/night cycle. Five sweeping spotlights animate around the guard towers and coastal beacon.

The river bed is at Y -12 and the ocean bed at Y -32. Water itself has no collision; the existing flight and jump controls still apply beneath its surface. Swimming and boat driving are outside this scenery change.

## Explore and test

Run Main and travel south (positive world Z). Follow the river to its mouth, then east to the harbor. From the outer dock, the prison island lies southwest offshore. Open the backtick console and use `time day`, `time sunset` or `time night` to compare the water and lighting.

| Location | World position |
| --- | --- |
| River mouth | (190, 3, 795) |
| South Harbor apron | (1130, 3, 910) |
| Outer boardwalk | (1130, 3, 1198) |
| Prison landing | (300, 5, 2090) |
| Prison arrival / open gate | (300, 18, 2318) |
| Island center | (300, 15, 2400) |

Check walking from the original apron onto both new piers, land on a boat hull, and fly to the island. Walk up its landing ramp and through the front gate; jump onto the wall walks and roofs. At night, check harbor lamps, prison windows, navigation lights and sweeping pools from the searchlights. Pause the game and confirm the boats and water stop moving.

## Tuning and generation

The Waterfront root exposes wave strength, animation speed, night-light brightness, boat-motion and searchlight toggles. Geometry is baked; runtime work only animates water, boat transforms and lights. All meshes/shaders are original native Godot assets, with no new addons or external dependencies.

`tools/generate_waterfront.gd` reads the existing city layout and rebuilds only the waterfront scene and its meshes. It does not rebuild the city. Running it overwrites direct edits inside the generated waterfront scene/assets. This generator does not use MultiMesh and can run headlessly.

```powershell
$waterfrontGodot = 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
& $waterfrontGodot --headless --path . --script res://assets/waterfront/tools/generate_waterfront.gd
& $waterfrontGodot --headless --path . --script res://tests/test_waterfront.gd
& $waterfrontGodot --path . --script res://assets/waterfront/tools/render_waterfront.gd
```

Tests cover water/bed collision, dock and island surfaces, all five existing crossings, the open prison gate, a player-sized capsule walking from landing to yard, boat hulls and placement, lighting transitions, pause behavior and animation toggles. Actual renderer captures are saved to `artifacts/waterfront/`.

## Files changed

- Added `scenes/waterfront.tscn` and `scripts/waterfront.gd`.
- Added `assets/waterfront/`: water/foam/deck shaders, generated meshes, generator, render tool and this guide.
- Added `tests/test_waterfront.gd`.
- Updated `scenes/super_city.tscn` to instance the waterfront and hide/disable the old water placeholder.
- Updated `assets/super-city/README.md` to describe the completed waterfront.
