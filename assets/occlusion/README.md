# City and terrain occlusion

`scripts/city_occlusion.gd` now covers the district buildings, park and airport structures, newer standalone POIs, all placed parking garages, bridges, harbor/prison structures and solid terrain. The gym owns an inset box occluder in its reusable exterior scene. Other structures use opaque source triangles so ramps, garage openings and bridge clearances stay open.

Trees, small props, actors, vehicles and transparent effects remain eligible to be hidden; they are not baked into solid blockers. The distant `CoastalRegion/DistantLandscape` mountain image strip is explicitly excluded as both a blocker and target.

## Terrain

Four large terrain meshes have offline spatially clipped render sections. Their original nodes, transforms and collision children remain intact. Runtime substitutes the render meshes only and copies the current instance materials. Tiles preserve surface shape, UVs, normals, vertex colors and tangents. Borders add some triangles, but allow hidden/out-of-view portions to be rejected independently.

| Source | Tile width | Sections |
| --- | ---: | ---: |
| City ground | 256 m | 94 |
| Northern ground | 1,024 m | 384 |
| Coastal terrain | 2,048 m | 480 |
| Physical mountains | 512 m | 85 |

Visible land is not deleted or distance-hidden. Ground beyond the playable area can still render if visible; sections behind solid buildings or landforms can now be rejected separately. Original source resources remain editable. If a source hash changes, runtime safely keeps the source mesh and warns that the tiles need rebuilding.

Rebuild with Godot `--headless --path <project> --script res://assets/occlusion/build_terrain_chunks.gd`. Generated scenes and audit data are in `terrain/`. Restart the game after editing static occluder sources. Changing garage dimensions in the editor is supported on the next run.

## Checks

Run `tests/test_city_occlusion.gd` headless. It verifies coverage, current source hashes, actual exported tile bounds/triangle counts/surface area, copied materials, the mountain-image exception, and region toggles. Add `-- --write-inventory` to regenerate `docs/occlusion-inventory.md`.

Six fixed-camera 1080p renders (gym, City Hall, garage, mountain highway, coastal land, aerial city) were compared with occlusion enabled/disabled using the player's 60,000 m far distance. All six image pairs matched pixel-for-pixel. With simulation frozen, the gym view fell from 5,307 to 1,193 draw calls and from 10.743 ms to 4.575 ms median frame time. These are controlled rendering comparisons, not guaranteed gameplay FPS. Open coastal views showed a small CPU cost from occlusion; dense street views benefited most.

`CityOcclusion.trial_enabled` toggles the generated regions. The gym's independent `Occluder` visibility toggles its own blocker. The viewport's occlusion setting disables all culling for comparisons.
