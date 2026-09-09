# Residential building test pack

20 original generic NYC-inspired residential PackedScenes, named `residential_building_01.tscn` through `residential_building_20.tscn`. Includes brownstones, a duplex, a three-house row, tenements, courtyard apartments, converted lofts, balcony slabs, stepped midrises, and taller residential towers. Buildings range from 9 to 128 meters tall. This pack does not replace an existing City Crafter collection.

## Use

Drag the scenes into entries of a CityConfiguration resource's **Residential Buildings** (`Array[PackedScene]`) property. Use a duplicate configuration for testing. Keep the `meshes`, `materials`, and `textures` folders with the scenes. Runtime assets in this folder are self-contained and do not depend on the commercial or industrial packs.

Each building contains exactly three nodes:

```text
StaticBody3D
├── MeshInstance3D
└── CollisionShape3D (BoxShape3D)
```

Everything visible is combined in one mesh. Root and mesh transforms are identity; collision has unit scale and is translated to the bounds center. Units are meters, the horizontal bounds center is at X=Z=0, and the lowest vertex is exactly Y=0. Entrances face -Z with secondary doors/signs on +Z where appropriate. Main stoops and balconies face -Z. Collision layer and mask use the normal world defaults of 1.

## Appearance and cost

Facade windows, curtains, lintels, brick, and some window AC units are baked into eight shared 64 x 64 textures. A single 256 x 256 atlas supplies fictional building-name plaques and doors. The textures are mipmapped native ImageTexture `.res` files and need no external image import. Ten shared StandardMaterial3D resources serve the whole pack, including one vertex-colored material for solid details. There are no custom shaders, transparent windows, interiors, lights, or runtime scripts.

Each building has 62–652 triangles and 3–5 material surfaces. The higher counts are the housing slabs with shallow balcony floors and opaque parapets; the windows themselves have no geometry. Rooftop water tanks are eight-sided. Flat roofs have dark membranes and thin stone cornice edges. This is a low-poly prototype pack, not a measured runtime performance benchmark.

## Collision and district spacing

The single box collider encloses **all** visible geometry, including stoops, balconies, water tanks, and roof caps. It deliberately fills courtyard voids, the gap between paired wings, and space around rooftop details. These courtyards are not enterable with this collider. Landings beside taller roof details can appear to float. Use the pack to test district appearance and traversal scale; precise courtyard or roof traversal would require a later collision pass.

The existing City Crafter suburban GLBs and their import settings were inspected before authoring. They are Y-up and grounded, with 20x import scaling; reference A is about 26 x 20.6 m and B about 36.6 x 22.8 m. The new buildings are about 8.8–28.2 m wide and 13.2–24.2 m deep, including protrusions, so their footprint range is comparable or smaller. A footprint comparison does not guarantee placement clearance: City Crafter uses center distance, not mesh-aware lot packing.

The class default residential spacing is only 20 m. For the **entire new pack**, these conservative values account for any rotation, using the maximum footprint diagonal of 35.60 m:

| Scale variation | Residential spacing | Border margin |
| --- | ---: | ---: |
| 0 | 37 m | 19 m |
| 0.3 | 48 m | 24 m |
| 0.5 | 55 m | 28 m |

These are optional settings for a separate test configuration; they were not applied. Residential subdivisions can be too small for this full mix of apartments and towers, especially in a 100 m block. For the larger buildings, disable residential subdivisions in a duplicate configuration or use sufficiently large blocks/subdivisions and lower requested density. Each subdivision must be wider and deeper than twice its border margin, with additional room for the intended building count. A brownstone-only selection can use tighter settings based on those scenes' dimensions. Other asset packs may need more clearance. Keep scale variation at 0 for exact authored dimensions.

## Generation, verification, and tests

`tools/generate_pack.gd` defines the twenty designs in meter dimensions. `tools/building_builder.gd` creates the combined meshes and small textures; `tools/pixel_font.gd` provides the tiny lettering. These two helpers are also used by the industrial generator. Regeneration overwrites only this district's generated resources, scenes, and manifest; scenes do not load the tools at runtime.

Run commands from the project directory, substituting the Godot executable path for `godot`. PowerShell's `Out-Host` makes the GUI executable finish before the next command starts:

```powershell
godot --headless --path . --script res://assets/generated-buildings/residential/tools/generate_pack.gd | Out-Host
godot --headless --path . --script res://assets/generated-buildings/residential/tools/validate_pack.gd | Out-Host
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --script res://assets/generated-buildings/residential/tools/render_preview.gd | Out-Host
```

Validated in Godot 4.7.2: 20 scenes load and instantiate; exact node structure, transforms, grounded/centered bounds, collision coverage of every vertex, materials, nondegenerate triangles, and outward winding all pass. The scenes were assigned to the actual CityConfiguration **Residential Buildings** array in memory, with 20 entries and zero failures. `tools/validation_report.json` records the results. A Windows certificate-store access warning occurred during sandboxed headless startup; it did not affect local assets or checks.

Godot rendered all 20 assets and their previews were visually inspected. The sheet at `previews/contact_sheet.png` frames each building separately, **not at a shared scale**. The superhero game itself and a generated residential city were not run.

Test in Godot: instance a brownstone, a courtyard block, and a tower on a floor at Y=0; compare them to the player, walk into their bases, and try jump/landing behavior with visible collision shapes enabled. Then add the pack to a duplicate residential collection and inspect generated spacing, rotations, and subdivision fit. Expect the conservative collision behavior described above.

Only the new residential and industrial folders were added for this request. Existing addon assets, configuration collections, commercial buildings, player code, and game scenes were preserved.

## Catalog

See the table below and `manifest.json` for measured dimensions and mesh statistics.

| Scene | Name | Design | Width x depth | Height | Triangles |
| --- | --- | --- | ---: | ---: | ---: |
| residential_building_01.tscn | BRIAR HOUSE | Four-story brownstone with entrance stoop and deep cornice | 8.8 x 15.4 m | 13.9 m | 94 |
| residential_building_02.tscn | TWO ELMS | Attached duplex with twin pitched roofs | 12.6 x 13.2 m | 9.0 m | 102 |
| residential_building_03.tscn | ASH ROW | Three-house row with separate doors and unequal rooflines | 18.1 x 14.3 m | 12.7 m | 214 |
| residential_building_04.tscn | WILLOW WALK | Six-story tenement with textured window AC units and water tank | 12.4 x 16.2 m | 23.6 m | 110 |
| residential_building_05.tscn | GROVE COURT | L-shaped corner walk-up with rear light court | 20.1 x 18.1 m | 20.7 m | 86 |
| residential_building_06.tscn | MAPLE MANSIONS | Prewar stone apartment house with penthouse and belt course | 18.4 x 16.2 m | 26.4 m | 72 |
| residential_building_07.tscn | ORCHARD HOUSE | Five-story buff-brick apartment house with entrance canopy | 18.1 x 15.2 m | 17.3 m | 62 |
| residential_building_08.tscn | LINDEN TERRACE | Brick terrace apartments with two deep setbacks | 20.1 x 18.1 m | 34.2 m | 82 |
| residential_building_09.tscn | HAWTHORN LOFTS | Converted warehouse loft apartments with large divided windows | 21.1 x 16.2 m | 29.4 m | 148 |
| residential_building_10.tscn | CEDAR APARTMENTS | Wide apartment block with two stacks of simple slab balconies | 24.1 x 19.1 m | 33.3 m | 332 |
| residential_building_11.tscn | FERN COURT | U-shaped courtyard apartments; courtyard uses conservative box collision | 23.1 x 20.1 m | 22.0 m | 114 |
| residential_building_12.tscn | ELM GARDENS | Long postwar housing slab with repeated balcony strips | 28.1 x 17.1 m | 43.0 m | 652 |
| residential_building_13.tscn | PARKSIDE HOUSE | Unequal paired apartment wings over a shared base | 26.1 x 20.1 m | 41.0 m | 82 |
| residential_building_14.tscn | BIRCH RESIDENCES | Modern midrise apartments with stepped penthouse | 22.1 x 19.1 m | 47.2 m | 382 |
| residential_building_15.tscn | STONEGATE | Stone residential tower with a compact stepped crown | 24.1 x 20.1 m | 56.0 m | 82 |
| residential_building_16.tscn | HEMLOCK HOUSE | Square brick housing tower with broad horizontal belt | 20.2 x 20.2 m | 68.0 m | 62 |
| residential_building_17.tscn | QUAY RESIDENCES | Waterfront residential tower on a broad stone podium | 26.1 x 22.1 m | 90.0 m | 72 |
| residential_building_18.tscn | JUNIPER TOWER | Slender square residential high-rise | 18.1 x 18.1 m | 112.2 m | 62 |
| residential_building_19.tscn | CANAL TERRACES | Asymmetric cascade of residential terraces | 24.1 x 22.1 m | 77.5 m | 102 |
| residential_building_20.tscn | ALDER HEIGHTS | Tall modern apartment tower with contrasting penthouse | 26.1 x 24.1 m | 128.0 m | 82 |
