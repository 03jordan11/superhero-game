# Commercial tower test pack

20 original, generic Manhattan-inspired commercial buildings for Godot 4.7.2. No real building was reproduced. Everything in this pack is generated locally by GDScript with Godot-native meshes, images, and materials. No third-party assets, addons, image services, or runtime generation are required.

## Use in City Crafter

Drag any of `commercial_skyscraper_01.tscn` through `commercial_skyscraper_20.tscn` into entries in a CityConfiguration resource's **Commercial Buildings** array. Keep the `materials`, `textures`, and `meshes` folders with the scenes. The existing collections and addon were not changed or replaced.

All scenes now use a structure like:

```text
StaticBody3D
├── MeshInstance3D
├── CollisionShape3D (BoxShape3D)
├── Additional tier collision shapes
└── RooftopHVAC (stock unit or its Blender budget variant)
```

The body and mesh have identity transforms. The collision is translated to half the building height and has unit scale. Each mesh is centered horizontally, starts exactly at Y=0, and uses meters directly. Entrances face -Z and +Z; quarter-turn rotations are supported. The default world collision layer/mask is 1.

Scene 01 now uses a blank stone podium, no tenant sign, a flat roof at 132 m,
and a separate reusable hospital HVAC instance. It has separate podium/tower
collision and a night-window script. Total height including equipment is 134.8 m;
the complete asset is **96 triangles** (48 building + 48 HVAC), previously 108.
See [its revision notes](commercial_skyscraper_01.md) for files, checks and rebuilding.
Reusable buildings should use generic asset IDs, with no baked tenant names.

Scene 02 now has a flush 30 x 21 m base, no tenant plaque, retained entrance
doors, and the stock hospital HVAC replacing its topmost mechanical box.
The smaller upper tier is preserved. The complete asset is **104 triangles**
(56 building + 48 HVAC), previously 108. Its dedicated window emission mask
follows the existing day/night clock. See [revision notes](commercial_skyscraper_02.md).
The pack generator preserves revisions 01 and 02. The validator counts their
HVAC instances and checks their separate colliders; the optional City Crafter
configuration check is skipped when that addon is absent.

## Dimensions and placement

**Current revision:** Commercial 03–20 were batch-edited in Blender. All nameplates
are removed, doors and tier silhouettes remain, rooftop boxes use the hospital
HVAC, and each has a dedicated emission PNG. Complete assets contain **86–108
triangles**, including HVAC. See [batch notes and file list](COMMERCIAL_BATCH_REWORK.md)
and the editable `blender/commercial_03_20.blend` (one scene per building).
The general generator now preserves all revised scenes. The older generation,
node-count and single-collider descriptions below are historical baseline notes.

Before generation, the addon's commercial GLBs, their import settings, CityConfiguration resources, and spawning/spacing logic were inspected. The example skyscraper imports apply a 25x scale: skyscraper A/B occupy about 34 x 34 meters; C/D about 32 x 34.7 meters. They are Y-up, horizontally centered, and grounded at Y=0. These new buildings have footprints 18–32 meters wide and 20–26 meters deep, with heights of 75.2–241.2 meters. Signs extend 2 cm beyond each front/back facade; this is included in collision and recorded bounds.

City Crafter uses distance between building centers, not mesh-aware lot packing. Its class defaults are 50 m commercial spacing and 0.3 scale variation; `example_city_resource.tres` uses 35 m spacing and 0.5 scale variation. Existing settings can therefore overlap even these smaller buildings. No asset pack can guarantee clearance at arbitrary spacing/scale values without changing placement logic.

For a separate test configuration, the following conservative bounds prevent overlap between members of this pack at any rotation. These values were calculated from the largest footprint diagonal (about 40.03 m); they were not applied to your project:

| Scale variation | Center spacing | Border margin |
| --- | ---: | ---: |
| 0 | 41 m | 21 m |
| 0.3 (maximum scale 1.3) | 54 m | 27 m |
| 0.5 (maximum scale 1.5) | 62 m | 32 m |

These margins assume a block large enough to accommodate them. Increase block size or lower requested density if a small block cannot fit the desired building count. Other building packs may need more clearance. Set scale variation to 0 if the authored real-meter dimensions should remain exact.

## Catalog

The contact sheet reads left to right, top to bottom. Each tile is framed independently to show detail, so the towers are **not shown at a common scale**. Heights include a 3.2 m rooftop mechanical housing.

| Scene number | Fictional tenant | Design | Height |
| --- | --- | --- | ---: |
| 01 | Unnamed | Narrow limestone tower, flat roof and reusable HVAC | 134.8 m |
| 02 | Portman Group | Broad dark-glass office slab | 113.2 m |
| 03 | Alder Capital | Square light-glass tower | 163.2 m |
| 04 | Civic Exchange | Limestone tower with three setbacks | 161.2 m |
| 05 | Ashford House | Broad brick tower with stone crown | 81.2 m |
| 06 | North Quay | Offset glass tower on wide podium | 133.2 m |
| 07 | Bryden Media | Narrow steel office tower | 181.2 m |
| 08 | Fulton Trust | Brick and stone wedding-cake setbacks | 143.2 m |
| 09 | Mason Partners | Wide concrete office slab | 91.2 m |
| 10 | Westbridge | Bronze facade, chamfered corners | 159.2 m |
| 11 | Larch & Co | Slim stepped stone crown | 141.2 m |
| 12 | Union Ledger | Asymmetric concrete setbacks | 151.2 m |
| 13 | Rivet Studios | Brick office loft tower, steel penthouse | 75.2 m |
| 14 | Harborline | Tall chamfered light-glass tower | 205.2 m |
| 15 | Grayson Trade | Broad bronze tower on stone base | 99.2 m |
| 16 | Sterling Annex | Very narrow concrete tower | 125.2 m |
| 17 | Vector Systems | Dark chamfered tower with cyan crown* | 193.2 m |
| 18 | Hexa Network | Eight-sided glass tower* | 169.2 m |
| 19 | Axiom Labs | Offset stacked glass volumes* | 213.2 m |
| 20 | Nova Exchange | Tall stepped steel/glass tower* | 241.2 m |

*The four restrained future-inspired buildings. No neon lighting, emission, or custom shaders.

## Cost and collision limitations

- 108–156 triangles, one combined ArrayMesh, and three nodes per scene.
- 11 shared StandardMaterial3D resources across the entire pack. Each mesh has 5–7 material surfaces; one mesh does not mean one draw call. Materials and mesh resources are reused by repeated scene instances.
- Nine 64 x 64 facade textures plus one 256 x 256 signs/doors atlas. These are native ImageTexture `.res` resources with mipmaps, requiring no texture import step. Pixel filtering retains the low-resolution appearance; there are no normal maps, transparency, interiors, or modeled window geometry.
- All roof/trim/mechanical colors share one material using vertex colors. Doors and fictional company signs are flat quads combined into the building mesh.
- One full-bounds box collider per building, including rooftop housings. **Setbacks, terraces, and the space beside rooftop housings have conservative invisible collision.** Rooftop landings may float above the visible main roof. This is the requested performance tradeoff, not precision rooftop traversal collision.
- This is a simple test pack. Hundreds of shadow-casting instances should still be profiled in the actual project; no runtime performance benchmark was performed.

## Generation and checks

From the project directory, replace `godot` with your Godot executable. In PowerShell, pipe each GUI executable invocation to `Out-Host` (or use `Start-Process -Wait`) so it finishes before the next command.

```powershell
godot --headless --path . --script res://assets/generated-buildings/commercial/tools/generate_pack.gd | Out-Host
godot --headless --path . --script res://assets/generated-buildings/commercial/tools/validate_pack.gd | Out-Host
```

Edit `get_designs()` in `tools/generate_pack.gd` to change meter dimensions, tiers, facade selections, offsets, and corner cuts. Regeneration overwrites this pack's scenes, meshes, textures, materials, and manifest. It does not write outside this pack. Generated scenes do not reference the scripts.

`tools/validate_pack.gd` loaded and instantiated all 20 final scenes in Godot 4.7.2, checked the exact node structure, unit transforms, positive geometry, ground plane, centered bounds, box coverage of every vertex, valid materials, triangle winding, and nondegenerate geometry. It also assigned the entire typed array to an instance of the actual CityConfiguration script **in memory only**. Result: **20 scenes, 20 typed array entries, zero failures**. Details are in `tools/validation_report.json`.

The headless sandbox reported a Windows root-certificate-store access error during engine startup; it did not affect local resource loading or these checks. Rendering outside the sandbox had no such error.

`tools/render_preview.gd` rendered all 20 final assets with Godot's Compatibility renderer. The contact sheet and a street-level entrance view were visually inspected; signs were corrected to read from outside. Previews are in `previews/`. These were asset previews, not a run of the superhero game or a generated City Crafter city.

To regenerate previews using a graphics-capable Godot process:

```powershell
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --script res://assets/generated-buildings/commercial/tools/render_preview.gd | Out-Host
```

## Test in Godot

1. Open a building scene and inspect its street-facing signs, facade, footprint, and height against the player at unit scale.
2. Instance a few scenes on a floor at Y=0 in a temporary test scene. Walk into the base, jump alongside it, and land on top with visible collision shapes enabled. Check whether the deliberately broad box collision is suitable for this test.
3. Add the scenes to a duplicate CityConfiguration and generate a temporary city. Inspect overlaps at the actual chosen spacing, border margin, rotation, and scale variation. Try a mixed selection of tall, short, and stepped silhouettes.

Only this asset-pack directory was added. Existing addon assets, City Crafter logic and collections, player scripts, and game scenes were left as found.
