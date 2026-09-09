# Player performance diagnostics

In the main scene, `PerformanceMonitors` contains `PlayerPerformanceMonitor` and `CombatPerformanceMonitor`. Each has its own Inspector Enabled switch and Sample Interval (default five seconds). The player monitor prints `[PlayerPerf]` JSON lines in debug builds, independently of the performance HUD checkbox.

The player monitor targets `Main/Player` and the configured HUD paths. It measures CPU callback time for player physics, move_and_slide, animation-selection logic, input, damage, camera effects, landing and encounter indicators, HUD value updates, the developer performance display, and pause-menu input. It includes call counts, average and peak call time, and time normalized per physics tick and rendered frame. Nested timings overlap and must not be summed. These are not GPU, skeletal-animation evaluation, UI layout, or complete rendering timings. Use Godot's profiler/visual profiler for those costs.

It also reports player state, animation, health, speed, subtree node count, and HUD control/visible-control counts. Counts and timings reset each sample; no growing history is kept. Disabled player monitoring skips timing collection. The configured roots are resolved when the monitor enters the scene; restart after changing target paths.

Test in Godot: idle, run, charge a jump, fly, pick up/throw a vehicle, take damage, and open the developer and pause menus. Enable the existing performance HUD and landing marker to exercise those categories. Check that `[PlayerPerf]` appears every five seconds during unpaused play, and that turning Enabled off stops it while `[CombatPerf]` continues independently.

## Changed files

- `scenes/main.tscn`: groups both monitors and adds the player monitor.
- `scripts/ui-scripts/player_performance_monitor.gd`: new sampler and scoped timing collection.
- `scripts/player-scripts/player_character.gd`: player callback and movement/animation timings.
- `scripts/player-scripts/player_camera_effects.gd`: camera timing.
- `scripts/player-scripts/landing_target_indicator.gd`: landing-marker timing.
- `scripts/player-scripts/player_encounter_indicator.gd`: encounter-marker timing.
- `scripts/ui-scripts/player_hud.gd`: HUD update timings.
- `scripts/ui-scripts/developer_menu.gd`: developer processing and performance-display timings.
- `scripts/ui-scripts/pause_menu.gd`: pause input timing.
- `tests/test_player_performance_monitor.gd`: scope, sampling, reset, toggling, teardown, damage and HUD checks.
- `tests/test_combat_performance_monitor.gd`: updated monitor node path.
- `PLAYER_PERFORMANCE_MONITOR.md`: these notes.

## Validation

Godot 4.7.2 headless checks passed for the new player monitor, existing combat monitor, HUD events, and state-machine scene integration. No visual gameplay verification was performed. The older `tests/test_player_scene.gd` cannot parse because its line 17 assert is unindented; that file was not changed. The local headless environment also reports certificate-store access and a combat-script UID cache warning, with the script successfully loading by path.

SuperCity uses a standalone preview camera instead of a second player. The preview camera removes itself when the city is embedded in Main.
