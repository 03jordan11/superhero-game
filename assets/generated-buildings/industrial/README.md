# Industrial building test pack

10 original generic urban industrial PackedScenes, named `industrial_building_01.tscn` through `industrial_building_10.tscn`. Includes freight warehouses, a sawtooth workshop, a foundry, cold storage, a twin-gable depot, a textile mill, a boiler house, a silo mill, a utility plant, and a repair works. Heights range from 8.8 to 30.4 meters, including chimneys and roof structures. No existing City Crafter collection was replaced.

## Use

Drag the scenes into entries of a CityConfiguration resource's **Industrial Buildings** (`Array[PackedScene]`) property. Test using a duplicate configuration. Keep the `meshes`, `materials`, and `textures` subfolders with the scenes. The finished runtime assets are self-contained; neither of the other packs is needed to instance them.

Each building contains exactly three nodes:

```text
StaticBody3D
├── MeshInstance3D
└── CollisionShape3D (BoxShape3D)
```

Each scene has one combined mesh, identity root/mesh transforms, and unit collision scale. Units are meters. Bounds are centered horizontally and start exactly at Y=0. Signs and loading-door textures face -Z and +Z; the freight canopy is on -Z. Default world collision layer/mask is 1.

## Appearance and cost

Six shared 64 x 64 textures represent brick, divided factory windows, concrete panels, and corrugated cladding. One shared 256 x 256 atlas supplies fictional company signs, personnel doors, roller shutters, and muted hazard stripes. All textures are mipmapped native ImageTexture `.res` files with pixel filtering. Eight shared StandardMaterial3D resources serve the whole pack. Solid roofs, tanks, chimneys, and metal details share one vertex-colored material.

Each building has 44–226 triangles and 3–5 material surfaces. There are no individual window meshes, transparent glass, custom shaders, interior rooms, smoke particles, lights, or runtime scripts. The sawtooth roof glazing is opaque. Silos and chimneys use eight sides, and rooftop chillers are simple boxes. These are compact urban plants, not large industrial campuses.

## Collision and spacing

Each collider is one conservative box covering all visible geometry. That includes the full height of chimneys and tanks, so the box fills space above lower roofs and between silos. Pitched and sawtooth roofs also receive flat box collision. Roof landings can therefore happen above the visible surface; this pack favors minimal physics cost over precise industrial rooftop traversal. There are no enterable loading bays or interiors.

City Crafter's existing industrial GLBs, imports, configuration resources, and spacing logic were inspected. They use 25x import scaling; reference A is roughly 52.1 x 31.1 m and G roughly 42.0 x 32.1 m. The new assets occupy about 28.0–34.2 m by 22.3–27.7 m, including protrusions. Geometry is centered during generation rather than inheriting the asymmetric origins of some source examples.

City Crafter uses center spacing and random scale; it does not check building bounds. Its class default industrial spacing is 35 m, which can overlap this pack. The largest new footprint diagonal is 44.02 m. Conservative settings for the full pack at any rotation are:

| Scale variation | Industrial spacing | Border margin |
| --- | ---: | ---: |
| 0 | 45 m | 23 m |
| 0.3 | 59 m | 30 m |
| 0.5 | 68 m | 34 m |

These are recommendations for a duplicate test configuration and were not applied. Use sufficiently large blocks and reduce requested building density if few buildings fit; border margins need room on both sides of each block. Other building packs can require larger spacing. Scale variation 0 preserves exact meter dimensions.

## Generation, verification, and tests

`tools/generate_pack.gd` defines the ten designs. For **regeneration only**, it loads the shared builder and pixel-font helper from `../residential/tools/`. Keep those helper files if you want to regenerate the pack; the saved `.tscn`, `.res`, and `.tres` runtime assets do not reference them. Generation writes only this industrial folder.

Run from the project directory, replacing `godot` with your executable path. Pipe to `Out-Host` in PowerShell to wait for each GUI executable invocation to finish:

```powershell
godot --headless --path . --script res://assets/generated-buildings/industrial/tools/generate_pack.gd | Out-Host
godot --headless --path . --script res://assets/generated-buildings/industrial/tools/validate_pack.gd | Out-Host
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --script res://assets/generated-buildings/industrial/tools/render_preview.gd | Out-Host
```

Validated with Godot 4.7.2: all 10 scenes load and instantiate; exact structure, identity/unit transforms, Y=0, centered bounds, coverage of all vertices by collision, materials, triangle winding, and nondegenerate geometry pass. The actual CityConfiguration **Industrial Buildings** property accepted all ten entries in memory. Result: zero failures, recorded in `tools/validation_report.json`. Sandboxed headless startup logged a Windows certificate-store access warning; local asset validation was unaffected.

All ten assets were rendered in Godot's Compatibility renderer and visually inspected. `previews/contact_sheet.png` frames each building independently, **not at a shared scale**. `previews/street_detail.png` shows the repair works doors and sign. No superhero gameplay or generated industrial city was run.

Test in Godot: place the freight warehouse, foundry, and silo mill on a floor at Y=0; walk into their walls and try jumping and landing while visible collision shapes are enabled. Then assign the scenes to a duplicate industrial collection and generate a temporary district to inspect density, rotated footprints, and spacing. Expect conservative rooftop collision as described above.

Only the new residential and industrial folders were added. Commercial assets, existing addon scenes/resources, generation logic, player code, and game scenes were preserved.

## Catalog

See the table below and `manifest.json` for measured dimensions and mesh statistics.

| Scene | Name | Design | Width x depth | Height | Triangles |
| --- | --- | --- | ---: | ---: | ---: |
| industrial_building_01.tscn | QUAY FREIGHT | Brick freight warehouse with three loading bays, canopy, and office penthouse | 34.2 x 27.7 m | 12.6 m | 58 |
| industrial_building_02.tscn | RIVET TOOLWORKS | Four-bay sawtooth machine workshop with opaque clerestory glazing | 30.0 x 24.0 m | 9.8 m | 48 |
| industrial_building_03.tscn | IRONVALE FOUNDRY | Pitched-roof foundry with an eight-sided tapered chimney | 30.3 x 26.3 m | 25.6 m | 78 |
| industrial_building_04.tscn | NORTH COLD STORE | Insulated cold-storage warehouse with three rooftop chiller blocks | 32.2 x 26.2 m | 14.1 m | 68 |
| industrial_building_05.tscn | CROSSLINE DEPOT | Twin-gable distribution depot with four roller shutters | 32.0 x 24.0 m | 8.8 m | 56 |
| industrial_building_06.tscn | MILLSTONE TEXTILE | Six-story textile mill with stone floor bands and rooftop stair tower | 28.3 x 22.3 m | 29.0 m | 64 |
| industrial_building_07.tscn | CANAL BOILERWORKS | Masonry boiler house with paired narrow smokestacks | 30.2 x 24.2 m | 28.6 m | 130 |
| industrial_building_08.tscn | BULKLINE MILL | Compact bulk mill with four octagonal storage silos on a solid base | 32.0 x 24.0 m | 24.0 m | 226 |
| industrial_building_09.tscn | WARD POWER | Urban utility plant with raised turbine hall and square exhaust tower | 28.0 x 24.0 m | 30.4 m | 60 |
| industrial_building_10.tscn | DOCKSIDE REPAIR | Repair works with tall office wing and lower pitched service hall | 30.0 x 24.0 m | 12.0 m | 44 |
