# City pavement chunks and blimp fixture removal

The city's modular roads and sidewalks now render through `SuperCity/PavementChunks`.
Original road/sidewalk nodes remain editable in the scene and keep their collisions,
traffic references, and sockets. Only their mesh visibility changes during play.

## Geometry

| Representation | Meshes / material surfaces | Rendered triangles across all chunks |
| --- | --- | --- |
| Original city pavement | 798 meshes / 1,428 surfaces | 46,844 |
| Combined full detail | 24 meshes / 24 surfaces | 46,844 |
| Distant pavement | 24 meshes / 24 surfaces | 9,346 |

These are geometry/surface counts, **not measured frame draw calls or FPS**. Frustum
culling, occlusion, lights and rendering passes determine actual frame submissions.
No FPS benchmark was performed for this change.

- Pieces are grouped by their bounds' centers on a 500 × 500 m grid. Complete
  pieces stay intact at cell edges, so a chunk's bounds can extend slightly outside
  its cell. Each cell combines both road and sidewalk surfaces into one ArrayMesh
  with one shared ShaderMaterial.
- Nearby meshes retain every original triangle. The shared shader preserves the
  original road lane/crosswalk calculations. Per-vertex UV contains original road
  coordinates, UV2 contains marking orientation, and vertex color encodes an index
  into a small floating-point parameter texture (99 material configurations).
  Asphalt and sidewalk textures still use the original world-space mapping.
- Distant meshes retain exactly the original upward-facing triangles. Curb side
  faces and procedural lane/crosswalk detail disappear. Sidewalk/asphalt textures
  remain. No rectangular fill is added over junction cutouts, water or gaps.
- Pavement meshes receive lighting/shadows but do not cast shadows themselves.
- At any moment only the full or distant mesh is visible for a given chunk; the
  individual source meshes do not render underneath it.
- Original hidden pieces stay hidden. Parking lots, embedded POIs, airport access
  pavement and waterfront/bridge geometry remain with their existing systems.
  The separate northern highway already uses combined roadway/marking meshes.

## Switching and Inspector controls

Select **Remote → Main → SuperCity → PavementChunks** while running Main:

- **Enabled**: off restores the individual original visuals; on uses the bake.
- **Force LOD**: Automatic, Full detail, Distant proxies.
- **Near Distance M**: 300 m.
- **Switching Margin M**: 50 m.

Automatic switches to distant detail beyond **350 m from the closest point of the
chunk's 3D bounds** and returns to full detail inside **300 m**. This includes height
above the road when flying. Distance is from the active camera, not the chunk
center. The road network has no final disappearance distance.

Disabling the controller is the correct original-vs-combined comparison; hiding its
Visible flag merely hides the replacements. Automatic updates run every 0.1 seconds.

## Editing / rebaking

The runtime validates source transforms, visible flags, mesh arrays, road material
parameters and source shader code after road modules have rebuilt. A stale bake
keeps originals visible and warns in the output instead of hiding edited roads.
Rebake after authoring changes, with the game stopped:

```powershell
& 'D:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --log-file artifacts/pavement_bake.log --script assets/super-city/tools/build_pavement_chunks.gd | Out-Host
```

The baker reads **Main**, including its final inherited overrides, and does not
rewrite any source pavement modules. The generated shader copies the original
road marking algorithm; edit `modular-roads/road.gdshader`, then rebake.

## Blimp

The five `Blimp/Strobe*` fixtures were high-resolution emissive SphereMeshes, with
no separate Light3D nodes. They are now five blinking, shadowless OmniLight3D nodes
at the same positions with the same phase offsets. Range is 8 m; light contribution
fades from 300–400 m. The removed spheres contributed **21,120 triangles**; the
remaining blimp meshes total **1,340 triangles**. The blinking emission used to be
visible as a sphere from a distance; the new meshless light illuminates nearby
surfaces and has no visible bulb shape. Motion, propellers, signs and audio remain.
The authoring generator was updated too, and unused fixture resources were removed.

## Validation

- `tests/test_pavement_chunks.gd`: passes. Checks every chunk against its original
  triangle set, exact distant top footprint, one material surface, source hiding,
  switching/hysteresis, collision preservation and stale-bake fallback.
- `tests/test_modular_roads.gd`: passes; 132 junction configurations and 10,711
  physics probes, including resize/save/sidewalk behavior.
- `tests/test_city_life.gd`: passes; blimp triangle count, five blinking lights,
  movement, audio, pause, scenery lighting and highway collision probes.
- Forward+ / D3D12 render captures in `artifacts/pavement_chunks/` were inspected:
  original/full junction markings agree; distant geometry retains the street grid.
- Godot editor initialization completed without new GDScript parse errors. The
  scan still reports existing duplicate UIDs in artifact backups, user-directory
  access/cache warnings, and MultiMesh format warnings while reopening scenes.
- The older `tests/test_city_modular_roads.gd` conversion audit cannot complete on
  the current authored city: it assumes every child is a modular prefab with a
  `Mesh` child, but `Roads/roads_4_0/alley_6m` is a legacy alley. It also reports
  older layout/collision mismatches. That audit detaches Roads/Sidewalks from the
  city before running; the new pavement controller never runs in that test.

## Files changed in this pass

- Added `scripts/pavement_chunks.gd`, `assets/super-city/tools/build_pavement_chunks.gd`,
  `assets/super-city/pavement_chunks/` (48 meshes, shared materials/parameter texture,
  shader, scene and inventory), and `tests/test_pavement_chunks.gd`.
- Updated `scenes/super_city.tscn` and `export_presets.cfg` to include the pavement
  scene and inventory.
- Updated `scenes/city_life.tscn`, `scripts/city_life.gd`,
  `assets/city-life/tools/generate_city_life.gd`, and `tests/test_city_life.gd` for
  the blimp. Added this document.

## In-game check

Run Main, walk through intersections and along sidewalks, then fly away and back
along the same corridor. Confirm collision remains solid, nearby markings remain,
and the pavement footprint doesn't jump. Use Force LOD to compare both versions
at a fixed viewpoint, or toggle Enabled for the original-vs-combined comparison.
Fly near the blimp to check its blinking light output without the sphere fixtures.
