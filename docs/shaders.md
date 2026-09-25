# Shader inventory and loading

Maintain this list when adding, replacing, or removing a custom shader. Paths are relative to the project root. Inventory checked 2026-09-24; generated shader resources are included, while copies under `artifacts/` are excluded.

## What Godot prepares automatically

This project targets Godot 4.7 with Forward+. Godot 4.4+ precompiles many GPU pipelines during resource loading and scene instantiation, then specializes them in the background. It needs to encounter the actual mesh/material/rendering features; `preload(shader)` alone cannot guarantee every pipeline is ready. For dynamic effects, a hidden instance during loading helps. Compatibility rendering has different requirements, and shader baking on export complements rather than replaces pipeline preparation. See [Godot's pipeline compilation documentation](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html).

The project already uses threaded scene loading in `scripts/ui-scripts/loading_screen.gd`. There is no global startup pass that exercises every shader below. Keep scene-bound materials with their scenes; prioritize dynamically spawned combat effects if the Godot Pipeline Compilations monitors show first-use spikes. Avoid loading the entire city only to warm a combat effect.

Reactive Shock: `PlayerElectricity` preloads `effects/electrified.tscn` and adds a hidden, non-processing `ElectrifiedPreparation` instance during player loading. Both the mesh material and runtime override are present at that point. The visible instances reuse the same shader. This prepares the effect before its first proc, but is not a measured guarantee of zero hitches on every GPU. The command-line test environment currently reports an unavailable `user://` shader cache, so its runs cannot validate persistent disk caching.

Thunderstorm casting reuses `effects/electric_arc.gd` and its generated `StandardMaterial3D` glow/core materials for the hand spark. `PlayerThunderstorm` preloads the script and constructs a hidden arc during player loading; ribbon geometry is generated when casting. This adds no custom shader file and does not guarantee every dynamic draw pipeline is compiled before first use. The storm continues to use the existing preloaded rain and sky shaders below.

## Gameplay effects

| Shader resource | Purpose | Loading / preparation |
| --- | --- | --- |
| `effects/frost_breath.gdshader` | Cold mist and crystalline streaks in Frost Breath's cone | Preloaded by frost effect; hidden cone/particle meshes created by PlayerFrost during player loading |
| `effects/frozen_ice.gdshader` | Translucent frozen-enemy shell and solid Frost Wall with procedural frost, veins and cracks | Preloaded by frozen ice and Frost Wall effects; hidden IcePreparation and WallPreparation box meshes/materials created during player loading; wall reuses shader and increases cracks before expiry |
| `effects/electrified.gdshader` | Reactive Shock body lightning | Effect scene preloaded; hidden instance on player load |
| `effects/lightning_ground.gdshader` | White 9m targeting ring, radial ground discharge, and rising arcs after Lightning Strike | Preloaded by strike effect; marker and hidden ground/vertical meshes constructed during player loading; elapsed driven by game delta, not shader TIME |
| `effects/weather_rain.gdshader` | Camera-local rain streaks, clipped by roof height map | Weather autoload preloads shader and creates hidden MultiMesh/material at startup |
| `effects/fireball_core.gdshader` | Fireball, charged fireball and External Combustion charge glow | Script preload in Fire/fireball/combustion; hidden charge mesh created on player load |
| `effects/dragon_breath.gdshader` | Dragon Breath | Script preload in effect; runtime material |
| `effects/charge_punch_wind.gdshader` | Charged punch wind | Script preload in effect |
| `effects/laser_scorch.gdshader` | Laser scorch decals | Script preload in effect; marks created on impact |
| `effects/helicopter_wreck_fire.gdshader` | Burning helicopter wreck | Script preload in wreck; spawned after destruction |
| `effects/player_speed_trails.gdshader` | Speed trails | Preloaded and material created by player speed feedback |
| `effects/player_speed_screen.gdshader` | Screen speed overlay (canvas) | Preloaded by player speed feedback; inspect first draw separately |
| `effects/combat_arena_grid.gdshader` | Green training arena grid | Scene dependency of Combat Arena |
| Embedded in `effects/vehicle_explosion_effect.gd` | Explosion fireball, reused for External Combustion | Shader source constructed at runtime; candidate for a resource/hidden-instance warm-up if profiling shows a hitch |

The base Electric Shock uses `effects/electric_arc.gd`: ImmediateMesh ribbons with StandardMaterial3D, not a custom `.gdshader`. Standard materials also produce GPU pipelines; a custom shader inventory alone does not cover all pipeline work.

## Environment and world

| Shader resource | Purpose / loading owner |
| --- | --- |
| `assets/sky/hero_sky.gdshader` | Main/city sky, storm cloud banks and distant lightning; scene material and day-night controller preload |
| `assets/sky/streetlamp_chunks.gdshader` | Streetlamp chunk material, loaded by `scripts/streetlamp_chunks.gd` |
| `scripts/traffic/traffic_night_lenses.gdshader` | Traffic night light lenses, traffic LOD script preload |
| `assets/buildings/materials/poi_windows.gdshader` | POI windows, lighting/HLOD controller preloads |
| `assets/buildings/materials/window_palette.gdshaderinc` | Shared window color include; compiled through including shaders |
| `assets/generated-buildings/commercial/materials/city_windows.gdshader` | City windows, CityWindows autoload/controller preload |
| `assets/generated-buildings/commercial/materials/corridor_hlod.gdshader` | Distant corridor materials, HLOD controller preload |
| `assets/generated-buildings/commercial/materials/occupied_windows.gdshader` | Occupied-window resource; retained in inventory, verify use before warm-up |
| `assets/super-city/landmark_proxies/landmark_proxy.gdshader` | Baked landmark proxy materials |
| `assets/super-city/regional_proxies/regional_proxy.gdshader` | Baked regional proxy materials |
| `assets/super-city/modular-roads/road.gdshader` | Modular roads and bridge road materials |
| `assets/super-city/modular-sidewalks/sidewalk.gdshader` | Sidewalk and alley materials |
| `assets/super-city/pavement_chunks/pavement.gdshader` | Near/far pavement chunk materials |
| `assets/parking_lots/parking_lot.gdshader` | Parking lot material |
| `assets/props/subway_entrance/stairwell.gdshader` | Subway entrance scene dependency |
| `assets/city-life/fence.gdshader` | City-life scene fence material |
| `assets/city-life/steam.gdshader` | Steam resource; verify runtime use before warm-up |
| `assets/central-park/lake.gdshader` | Central Park scene lake material |
| `assets/central-park/fireflies.gdshader` | Central Park scene fireflies |
| `assets/trees/backdrop/landscape.gdshader` | Landscape backdrop material |
| `assets/coastal-airport/horizon.gdshader` | Coastal region scene horizon |
| `assets/waterfront/water.gdshader` | Waterfront, mountain river, and ship preview water |
| `assets/waterfront/foam.gdshader` | Waterfront scene foam |
| `assets/waterfront/deck.gdshader` | Waterfront scene decking |
| `assets/waterfront/chunks/riverbank.gdshader` | Riverbank chunk material |
| `assets/waterfront/harbor_chunks/harbor.gdshader` | Harbor chunk material |
| `assets/waterfront/cargo_ship/navigation_lens.gdshader` | Cargo ship navigation lights |
| `assets/mountain-river/railing.gdshader` | River and river-frontage railings |

Generated/baking tools also create temporary shader variants: `assets/super-city/tools/bake_landmark_proxies.gd` and `assets/sky/tools/render_starscape.gd`. These are tooling-only preparation work, not game-start warm-up targets.

## Maintaining and verifying the list

Discover file-based shaders with `rg --files -g '*.gdshader' -g '*.gdshaderinc'`. Check for embedded shaders with `rg -n 'shader_type|Shader.new' scripts effects assets -g '*.gd'`. Record the owner, whether its material/mesh is instantiated during loading, and any measured first-use compilation issue. A list entry or successful shader parse is not evidence that every pipeline was warmed.

Use a graphical build and Godot's Pipeline Compilations monitors when evaluating startup behavior; headless checks cannot validate GPU shader compilation. Test first use of dynamic effects and the actual exported renderer/settings. Keep startup preparation behind the existing loading screen when adding further warm-up work.
