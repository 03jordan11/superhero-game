# Static regional map

## HUD minimap

Scene-travel fix: the HUD refreshes its minimap reference after each tree entry and whenever the preference changes. This is necessary because hideout travel preserves the player/HUD while freeing the city. Indoors, the outdoor map is hidden; after returning, the reference resolves to the new SuperCity. `tests/test_main_menu_load.gd` now covers actual saved-game loading into the hideout, exit to the reloaded city, map texture coverage at the returned player position, and two off/on cycles through the pause menu checkbox. That test and the HUD suite pass without script errors. The travel run also reports an ObjectDB cleanup warning, alongside the existing certificate/settings startup messages. No gameplay screenshot verification was performed for this fix.

`scenes/ui/gameplay_hud.tscn` now contains a bottom-right `Minimap` Control, implemented by `scripts/ui-scripts/minimap.gd`. It draws a region of the same static texture used in the P menu. No camera, SubViewport or additional 3D rendering is involved. The map stays north-up, the cyan arrow follows the hero's ground-facing yaw in city-local coordinates, and N/E/S/W are drawn in the enclosure. Texture bounds are clipped explicitly: uncovered space remains the enclosure background rather than stretching the map or clamping the player marker to an incorrect location.

Gameplay settings include **Show Minimap**, on by default, saved in the HUD section of settings.cfg. Both main-menu and pause-menu settings synchronize through the existing preference signal. Control hints move above the minimap while enabled and return when disabled.

Select GameplayHUD/Minimap in the Inspector to tune walking radius (180 m), fast radius (650 m), full-zoom horizontal speed (100 m/s), flight extra radius (180 m), and zoom response (2 per second). These radii describe half the displayed map width. Horizontal speed smoothly increases radius; flight adds range even while hovering. Exponential smoothing makes transitions independent of frame rate. Altitude does not move the map or affect zoom. Position and size can be adjusted through the Control offsets.

Validation: HUD and settings-tab headless tests pass. New coverage checks prison coordinates, altitude independence, speed bounds, flight range, smoothing in both directions, north/east headings, input passthrough, toggle visibility, preference save/reload and synchronization between settings menus. No in-game visual verification was performed. Manual checks: walk/sprint, charge a jump and land, fly/hover/stop, turn in place, compare the marker with the P map, and toggle Show Minimap off/on then restart to check persistence. Check readability and hint spacing at your usual window size.

Files changed for HUD integration: `scripts/ui-scripts/minimap.gd`, `scenes/ui/gameplay_hud.tscn`, `scripts/ui-scripts/gameplay_hud.gd`, `scripts/game_settings.gd`, `scripts/ui-scripts/settings_menu.gd`, `tests/test_gameplay_hud.gd`, `tests/test_settings_tabs.gd`, and this document.

## P menu integration

The P menu's Map tab uses the tracked `assets/ui/maps/region_map.png` and `region_map.json` copies. `scripts/ui-scripts/region_map.gd` fits the image without stretching and draws a fixed-size cyan/white player marker from the player's SuperCity-local X/Z coordinates. Altitude is ignored. The view resets to the full region when reopening the menu. Scroll zooms around the cursor, left-drag pans while zoomed, and double-click resets. Outside the exported bounds, the marker is hidden and the footer reports that the player is outside the mapped area.

To refresh the in-game map after world edits, regenerate the offline files and copy the PNG and coordinate JSON into these tracked asset paths together.

Validation: `tests/test_region_map.gd` passes coordinate-corner, prison location, altitude, transformed-city, aspect-ratio, and marker zoom/pan checks. `tests/test_gameplay_menu.gd` passes with the populated Map tab and live player/city references. Headless runs reported system certificate and settings warnings; the gameplay-menu test also deliberately exercises a failed save. In-game visual accuracy remains for manual testing: P → Map at street intersections, the airport terminal/runway, the Pine Pass entrance, and prison island; move between checks and reopen. Check that changing altitude does not shift the marker, and that zoom/pan keep the marker attached to the same location. Existing P/Escape close and shoulder-button tab controls are unchanged.

The v3 map supersedes the image-generated v1/v2 art concepts for geographic use. It is drawn offline from the saved `scenes/main.tscn` SuperCity instance, including its placement and mesh overrides. It does not create a gameplay camera or modify any scene.

## Files

- `benchmarks/export_region_map.gd`: exports visible mesh triangles in SuperCity coordinates without adding Main to the scene tree.
- `benchmarks/build_region_map.py`: orthographic software rasterizer with interpolated height testing, a flat cartographic palette, geometry boundary outlines and elevation contours.
- `artifacts/minimap/accurate_region_map_v3.png`: 5400 × 4875 full-resolution map.
- `artifacts/minimap/accurate_region_map_v3_preview.png`: smaller full-region review image.
- `artifacts/minimap/accurate_region_map_v3_city_detail.png`: city crop for inspecting streets and building footprints.
- `artifacts/minimap/accurate_region_map_v3.json`: bounds, image scale, source scene hashes and category counts.
- `artifacts/minimap/region_geometry.json` and `region_triangles.bin`: intermediate geometry export.

Artifacts are locally generated and excluded by the existing repository ignore rule. The scripts make them reproducible.

## Coordinates and scope

Bounds in SuperCity local space: X −5000 to +2200, Z −3500 to +3000. North (negative Z) is up. Scale is 0.75 pixels per metre on both axes. For future HUD use, first convert player global position to SuperCity local space, then map `u = (x + 5000) * 0.75`, `v = (z + 3500) * 0.75`.

Terrain, water, buildings, airport, prison, park paths and transport surfaces use their transformed mesh triangles. Overlap uses highest-surface elevation at each pixel. Individual tree crowns outside the park are represented by ellipses using their actual transformed bounds; combined forest chunks and park meshes retain their triangles. Small props under 2 square metres of bounding footprint and triangles under 0.04 square metres projected area are omitted, with the prop filter waived for markings. Hidden nodes, collision, distant proxies, background panorama, moving air traffic and civilians are excluded. This depicts saved geometry, not runtime actors or shader displacement. The underground tunnel is naturally obscured by terrain. Colors are assigned by scene-path categories, not by rendered textures.

## Regenerate

From the project folder, run Godot 4.7 headless with `--path . --script benchmarks/export_region_map.gd --log-file <absolute-log-path>`, then run `benchmarks/build_region_map.py` with Python containing NumPy and Pillow. No image-generation step is involved.

## Verification

The export completed with 178,617 projected triangles and no GDScript parse or execution errors. Startup separately reported the existing unresolved audio-bus UID, system certificate store error, and settings-default warning; these did not prevent the geometry export. Python rendering completed successfully. Image dimensions, uniform scale and presence of all ten map categories were checked, and the region preview and city crop were visually inspected during development.

No gameplay behavior was changed or visually tested. For manual comparison in Godot, open Main and compare the airport terminal north of its runway, its eastbound access road, Central Park's actual lake and paths, the northern highway entering Pine Pass, the river's mountain termination, the southeastern harbor, and the detached southern prison island against the image.
