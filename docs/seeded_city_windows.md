# City window colors and occupancy

All 20 commercial, 20 residential and 10 industrial models share this system.
Separate building percentages are enabled by default: **industrial 5%**,
**residential 7%**, **commercial 10%**. Colors default to **60% warm**
(amber/soft yellow), remaining windows cool blue-white, brightness **2x**.
Existing saves with explicit window settings retain those saved values.

## Shared palette and POIs

`assets/buildings/materials/city_window_palette.tres` is the reusable palette:
amber `#e4b766`, soft yellow `#f2dba6`, and cool blue-white `#9ac8dc`.
Both the generated buildings and POIs use this resource and the same color-mixing
shader include. Edit that resource to change the colors for all participating
buildings. The debug HUD's warm mix and brightness also apply to all of them.

| POI | Lit windows |
| --- | ---: |
| Bank 1 and Bank 2 | 2% |
| Police station | 20% |
| City Hall | 10% |
| Hospital | 30% |
| Firehouse | 10% |

These five POI sliders are available in **Night windows** and saved with the city
settings. They apply independently of the three district sliders. Existing saves
without POI settings receive these defaults.

POI window surfaces receive emission-only UV2 room IDs. Ranks are selected across
each complete building, keeping patterns stable when sliders change; percentages
round to whole windows (the historic bank has 39 openings, so 2% lights one).
Hospital curtain-wall sections receive separate ranks for their rows and columns,
including vertically repeated tiles. Partially clipped arch cells can make the
visible fraction differ slightly. No triangles or collision shapes are added.

Recovered glass masks preserve rectangular/arched openings, frames and mullions.
`assets/buildings/materials/tools/build_window_masks.py` rebuilds them from the
authored emission atlases. Signs, police/firehouse fixtures, hospital entrance
lights and the rescue marker retain their separate lighting behavior.

The gas-station hideout and Harbor Authority office are additional special
buildings outside this POI window pass; their existing lighting remains unchanged.

## Controls

While playing a debug build, press **backtick** (or your rebound developer-menu
shortcut). **Night windows** appears beside the console. Gameplay pauses and the
mouse releases; lighting changes still render immediately.

- **Lit windows:** 0–100% across all three building types.
- **Use separate building percentages:** replaces the citywide percentage with
  independent commercial, residential and industrial percentages.
- **Warm colors:** warm versus cool mix; occupancy changes preserve window colors.
- **Brightness:** 0–3 times the new palette's default glow.
- **Set midnight / Set noon:** change the game clock to compare night and day.

The performance HUD also shows C/R/I percentages. Exported properties are under
**Remote → CityWindows** in the Inspector. Use the existing console **save**
command to keep tuning; **load** restores tuning and seed. Sliders never autosave.

## Implementation

### Shared runtime window materials (September 22)

Wall/roof resources and room-data textures were already shared, but the generated
building script created a new ShaderMaterial for each placed building's window
surface. Identical-looking resources still have distinct identities, preventing
some otherwise compatible draws from batching.

Clock-driven generated buildings now obtain shared materials from CityWindows,
keyed by original mesh/surface, source override, window-pattern variant, emission
intensity and clock. Settings/palette changes and day/night emission update each
cached material once. Seed changes rebuild bindings, and leaving the scene
releases that clock's material cache. No shader code, textures or geometry change.
Standalone previews and explicit per-building `apply_night()` overrides retain
private materials. Different intensity overrides and clocks remain independent.
POI materials keep their existing per-building room layouts and behavior.

The same recorded corridor benchmark now measured 4,274 draws versus 4,872 before
(598 fewer, about 12%). Live median frame time was 10.29 ms versus 11.85 ms;
frozen-scene rendered objects and primitives were unchanged at 8,861 and 857,178.
These are local benchmark results, not a guaranteed FPS gain in every view.
Evidence: `artifacts/corridor_rendering/material_sharing_baseline.json` and its
PNG; original measurements remain in `artifacts/corridor_rendering/results.json`.
Use the corridor benchmark with `--baseline-only` to repeat the shorter check.

Validation passed: `test_shared_building_materials.gd`,
`test_seeded_city_windows.gd`, `test_urban_night.gd`, and
`test_poi_window_palette.gd`, plus the graphical corridor replay. The screenshot
was inspected. Sandbox settings/cache/certificate warnings remain in the logs.

For a manual check, restart with F5 and revisit the same corridor. Compare draw
calls, then use `time pause`, `time 17` and `time 18` to inspect daylight and
evening. Change Night windows brightness/occupancy in the developer menu, and
enter/exit the hideout to verify that patterns and lighting remain correct.

Files in this change: `scripts/city_window_lighting.gd`,
`assets/generated-buildings/commercial/commercial_skyscraper_01.gd`,
`tests/test_shared_building_materials.gd`,
`benchmarks/corridor_rendering.gd`, and this guide.

The shared controller preserves geometry, collision, albedo, roughness and metallic
settings. Its shader combines the facade with a recovered full window mask and a
small, nearest-sampled floating-point room-data texture. Masks preserve frames and
mullions; the foundry's solid wall rows remain excluded. Previously dark windows
are eligible, so 100% includes all windows, not just the originally lit subset.

Fixed shuffled ranks select lit windows. Raising occupancy adds windows without
reshuffling retained colors or brightness. Changes update uniforms, without
regenerating textures or meshes. Day/night signals fade emission to zero in daytime.
There are no new triangles, per-window lights or time-based noise.
The palette normalizes the previous 2x emission strength to retain its colors
rather than clipping to white; brightness remains adjustable.

Percentages apply to the eligible facade UV grid, rounded to whole rooms. Shared
and partial UV regions mean one visible side may not measure exactly the chosen
percentage. Opposite faces retain their authored UV sharing. Six cached placement
variants break repetition between buildings. All 50 assets/six variants use about
**0.77 MiB** of native room data, plus small shared masks; GPU allocation differs.

Buildings with `seeded_window_patterns = false` retain their original materials.
The sky and street lighting are unaffected. See the POI section for landmark coverage.

Manual saves include `world.window_lighting`: seed, pattern version 2, occupancy,
district overrides, warm fraction and brightness. Legacy saves retain their seed
and get new tuning defaults. Invalid/missing seeds use 8421; non-finite settings
are rejected and percentages clamped. New Game changes the seed, retaining tuning.

## Validation and manual check

Automated checks cover all 50 models/six variants, unchanged geometry, mask
boundaries, 0/25/50/75/100%, live overrides, cache sharing, stable seeds, real
save/load, paused controls and day/night. Existing developer-console, residential
and industrial regression checks pass. Forward+ city screenshots at each
percentage, daytime and the debug panel are in `artifacts/window_colors/`.
Gameplay traversal was not manually tested.

In Godot, face several buildings, open the debug menu, set midnight and compare
0, 25, 50, 75 and 100%. Try separate district percentages, then set noon. Save a
preferred combination, change it and load to confirm restoration.

## Changed files

- `scripts/city_window_lighting.gd`: masks, room data, settings and persistence.
- `assets/generated-buildings/commercial/commercial_skyscraper_01.gd`: shared
  controller used by all three packs.
- `assets/generated-buildings/commercial/materials/city_windows.gdshader`: emission.
- `scripts/ui-scripts/window_lighting_controls.gd`, `developer_menu.gd`,
  `developer_performance_hud.gd`: controls and percentage readout.
- `assets/sky/tools/render_seeded_windows.gd`: reproducible visual comparisons.
- `tests/test_seeded_city_windows.gd`, `test_urban_night.gd`,
  `test_power_token_saves.gd`, `test_residential_rework.gd`,
  `test_industrial_rework.gd`, `test_developer_console.gd`: updated coverage.
- This guide and new script/shader UID files.

POI extension files: the six controllers under `assets/buildings/`,
`scripts/poi_window_lighting.gd`, `scripts/window_light_palette.gd`, shared palette,
POI shader/include and eight masks under `assets/buildings/materials/`, the mask
builder, `tests/test_poi_window_palette.gd`, and updated bank, City Hall, hospital,
police and firehouse regression tests. Previews are in `artifacts/poi_palette/`.
Check each POI at midnight, change its slider to 0 and 100, then restore the default;
confirm that fixture/sign lights remain on and all night lighting fades at noon.
