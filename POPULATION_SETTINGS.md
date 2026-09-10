# Population settings

The main menu and pause menu share three Low / Medium / High dropdowns under **Settings → Graphics → Performance**. Changes apply immediately, save automatically to `user://settings.cfg`, and affect newly loaded scenes too. When paused, the population settles after resuming. City mesh visibility and camera clipping are not changed. See [Settings menu](SETTINGS_MENU.md) for the shared tabs and other preferences.

| Preset | Density multiplier | Distant coverage multiplier |
| --- | --- | --- |
| Low | 0.50 | 0.60 |
| Medium | 0.75 | 0.80 |
| High (default) | 1.00 | 1.00 |

These are initial tuning values, not measured frame-rate guarantees. Missing or invalid preferences fall back to High. Preferences are independent of gameplay saves.

## Ownership and tuning

`GameSettings` owns the selections, persistence, multipliers, and a change signal. The shared population panel only talks to that service. Each population manager exposes `apply_population_settings(density, distance)` and translates the factors into its own configuration, including its LOD child. The UI never looks up city nodes or writes manager properties.

Scene Inspector values are the High baseline. Each manager captures its own scene overrides once at startup and computes every preset from that snapshot, so Low → Medium → High restores the original configuration without multiplying previous results. Tune the saved scene and restart to establish a new baseline. The Remote Inspector shows effective values; runtime edits to controlled properties are replaced on the next settings change. No settings application rebuilds roads/routes or adds per-frame polling.

Crowd density scales the population target, maximum civilians, civilians per 100 m, per-cell cap, and capsule allowance. Vehicle density scales the local target, full-vehicle cap, per-lane cap (at least one), and both distant tiers' targets/capacities. Counts round to whole entities. Disabled managers/LODs stay disabled. Vehicle weights, paint, following gaps, intersection speeds, walking offsets, and work-per-frame budgets are unaffected.

View distance adjusts distant crowd and traffic coverage. Nearby population radii, full-representation transitions, speed-based approach lead, and interaction guards remain unchanged. Crowd coverage cannot shrink below its local radii/transition buffer, unless the original configured range was already smaller. Traffic coverage retains a buffer around full vehicles and their approach lead. Presets never increase the configured High range. Existing silhouette/rectangle switch distances remain unchanged to keep boxes from appearing closer than before.

Distant targets and capacities also scale with approximate covered area: squared radius ratio for the inner tier and annulus area ratio for outer traffic. This avoids concentrating the old target into a smaller visible region. It approximates road availability; actual road layout, spacing and caps still determine the realized population.

With the current 900/1800 m traffic ranges, Low uses 540/1080 m and Medium 720/1440 m. With High vehicle density, the original distant targets of 160/200 become approximately 58/72 at Low distance. Applying Low vehicle density as well gives 29/36. The SuperCity capsule range of 350 m becomes 220 m on Low (the local crowd radius imposes this floor), or 280 m on Medium.

Existing spawn/removal budgets handle changes gradually. Lowering the full-vehicle cap retires at most one eligible offscreen ambient car per tick, outside the immediate spawn guard and outside a crossing. Held/released vehicles remain protected and can temporarily keep the manager over its new cap. Distant traffic retains its visibility/distance retirement rules; crowd retains its existing proximity and interaction protections. Visible or protected populations can take time to settle to a lower budget.

## Validation and manual testing

`tests/test_population_settings.gd` checks both actual menu instances, a selection while paused, persistence using an isolated temporary file, invalid/missing values, every density/distance combination repeatedly, independent controls, late scene initialization with custom baselines, and bounded live traffic trimming with a released vehicle. `-- --capture` additionally captures both menus when using a rendered Godot run.

In Godot:

1. Open Settings from the main menu. Change each dropdown, then start the game and confirm the pause menu shows those choices.
2. Compare crowd and traffic on High versus Low in the same area. Resume and move/look around to allow gradual population changes.
3. Fly above the city and compare Low/High Population View Distance. Check both distant traffic layers and the capsule crowd; buildings should keep their existing visibility.
4. Hold or throw a car, lower vehicle density, and confirm it stays available. Check nearby cars still stop and promote correctly during a fast approach.
5. Quit/relaunch and confirm preferences persist. Restore High to compare with your original scene tuning.

## Files

- `project.godot`: GameSettings autoload.
- `scripts/game_settings.gd`: preferences and persistence.
- `scenes/ui/population_settings.tscn`, `scripts/ui-scripts/population_settings.gd`: shared dropdown panel.
- `scenes/main_menu.tscn`, `scenes/main.tscn`: panel instances.
- `scripts/npc-scripts/civilian_crowd.gd`, `civilian_capsule_lod.gd`: crowd preset interpretation.
- `scripts/traffic/traffic_manager.gd`, `traffic_box_lod.gd`: traffic preset interpretation and cap retirement.
- `tests/test_population_settings.gd`: integration checks.
- `POPULATION_SETTINGS.md`, `TRAFFIC_README.md`: configuration documentation.
