# Developer console

The debug developer screen is now a paused text console in the top-right corner. Its panel uses roughly 45% of the viewport width and 60% of its height, with an outer margin and scrolling output. There is no full-screen dimmer; the rest of the game remains visible. Open it with the existing bindable Developer Console action: backtick on keyboard, Xbox View by default. Escape, Xbox B, the pause action, or the console binding closes it. It cannot open over Pause/Settings or the TAB menu. Typing does not move or attack with the player. The world and NPCs pause until the console closes. Console UI and command execution are unavailable in release builds.

## Commands

Commands and identifiers are case-insensitive. Amounts must be positive whole integers; malformed or out-of-range values produce an error rather than partially executing a command.

| Command | Effect |
| --- | --- |
| `set strength 20` | Set base Strength to 20; power bonus remains separate. Also accepts `speed` and `resilience`. |
| `add xp 500` | Grant XP through normal leveling, including earned attribute points. |
| `add attr 3` | Grant three unspent attribute points. |
| `add pp 5` | Grant five power points/tokens to spend in Powers. |
| `reset` | Set all three attributes to 1, level to 1, XP and both unspent point balances to zero. Remove all powers/upgrades except the Power Jump core, cancel active traversal/combat, revive, and refill health/stamina. |
| `spawn civilian [amount]` | Spawn civilians near the player; amount defaults to 1, maximum 50. |
| `spawn pistol_thug [amount]` | Spawn Mafia pistol thugs near the player; amount defaults to 1, maximum 50. NPCs stay paused until the console closes. |
| `spawn rifle_thug [amount]` | Spawn Mafia rifle thugs with 30-round magazines and automatic fire; same 1–50 count limit. |
| `spawn melee_thug [amount]` | Spawn Mafia melee thugs with six-punch combos; at most two approach/attack each target while others surround. Same 1-50 count limit. |
| `spawn super_thug [amount]` | Spawn Mafia super thugs: 500 health, 40-damage slow punches, 350 XP, exclusive melee turns. Same 1-50 count limit. |
| `spawn gang_activity` | Spawn one random gang encounter scaled to hero level: Easy 1-3, Mid 4-6, Hard 7+. Follow the existing waypoint, available for this dev spawn without Trouble Sense. |
| `spawn pirates` | Spawn a stationary offshore cargo ship with 2 pistol, 3 melee, 1 machine gunner and 1 super. Defeat all seven for 500 completion XP. See [Pirates](docs/pirates.md). |
| `spawn rescue` | Spawn a protected injured civilian. E picks up/sets down; deliver to the hospital for 100 XP, $100 and 10 Good Will. The 2-minute preview timer cannot fail the rescue. |
| `spawn helicopter_chase` | Spawn one armed helicopter: 100 health, sweeping bursts, 1,000 XP on destruction. Its burning wreck falls and disappears after 30 seconds. |
| `spawn hostile [amount]` | Compatibility alias for `spawn pistol_thug`. |
| `debug landing on` / `off` | Toggle the landing target marker. |
| `debug hud on` / `off` | Toggle performance statistics and the existing player diagnostic readouts. |
| `debug enemy_names on` / `off` | Toggle hostile overhead names independently of tints. |
| `debug enemy_tints on` / `off` | Toggle type-colored mesh overlays; off restores original appearance. |
| `save` | Save current player progression. Report write failure explicitly. |
| `load` | Load saved player progression. Report missing/invalid files explicitly. |
| `status` | Show base attributes, bonuses, level, XP, and both point balances. |
| `help` / `help add` | List commands or show help for a specific command. |
| `clear` | Clear output, retaining command history. |

Spawn commands report the actual/requested count and skip positions without ground within the probe range. Each batch spreads around the current player location.

Enemy names and tints start enabled in debug builds; both are disabled in release builds. Independent switches affect existing enemies and later spawns and last only for the current session.

Tab completes/cycles command suggestions. Up/Down recalls command history and restores the unfinished input when returning to the bottom. History is bounded to 100 entries and output to 300 lines. Both are session-only. There is no shell execution, arbitrary property access, ability override, or hidden alias for removed tools. User-facing console copy lives under `console.*` in `localization/powers.json`; command keywords remain stable English identifiers.

## Saves and reset

Console grants, stat edits, and reset do not autosave. Run `save` to keep the current progression. Existing purchases in the Powers/Attributes menus still save the current player as before; those saves include any current console edits too. The console does not alter that purchase behavior.

**Play starts a new scene and does not call Load Save.** To restore earlier testing: start Play, open the console, run `load`. The previous Add 5 Power Tokens button did call SaveManager immediately, but loading was always a separate action. The save stores player attributes, level/XP, money, unspent points and purchased power tiers, not world state, spawned NPCs or player position.

Power Jump is now the free starter core for fresh players, resets, and loaded older saves. Its upgrades still require points. Reset uses attributes 1/1/1 as requested; the existing player scene's fresh starting attributes remain 10/1/10. Reset preserves location, world objects, settings and money, and does not erase or overwrite the saved file until a save occurs.

## Removed and retained systems

Removed the button/checkbox developer screen, direct ability overrides, encounter-spawn tool, manual horn-preview path/status UI, and camera-testing panel/rig with their dedicated tests. Gang encounters, city horn ambience, normal gameplay camera and camera effects remain. Separate player/combat/city/crowd/vehicle performance monitors remain unchanged. Performance HUD sampling now belongs to its own script so it remains usable without the old menu.

## Implementation and changed files

- `scripts/ui-scripts/developer_menu.gd`: console layout, pause ownership, input, history, completion, and output.
- New `scripts/ui-scripts/developer_commands.gd`: explicit command dispatch, validation, stat/point/reset/spawn operations.
- New `scripts/ui-scripts/developer_performance_hud.gd`: retained diagnostics formerly owned by the old menu.
- `scenes/main.tscn`: removed old developer controls; attached the performance HUD script without changing Player paths.
- `scripts/ui-scripts/power_menu_progression.gd`, `scripts/player-scripts/player_power_controller.gd`: starter Power Jump, explicit console token saving, removal of obsolete test-token helper/signal.
- `scripts/player-scripts/player_stamina.gd`: full-restoration method for reset.
- `scripts/city_horn_ambience.gd`: removed manual preview logic; retained normal random ambience.
- `scripts/input_bindings.gd`, `localization/powers.json`: console label and localized text; removed obsolete developer-button copy.
- Deleted `camera_testing_panel.gd`, `camera_testing_rig.gd`, `test_camera_testing.gd`, and `test_audio_preview_button.gd` plus UIDs.
- Added `tests/test_developer_console.gd`; updated gameplay menu, token-save, powers-page, Greater Jump, power-attribute and city-horn tests to reflect the new behavior.
- Updated gameplay/powers/controls/audio documentation and retired the camera-testing guide.

## Manual checks

1. Open console while moving; verify the player/world freeze and typing cannot trigger actions. Close with Escape, backtick and Xbox B/View. Check Pause/Settings and TAB menu still work normally.
2. Try `set strength 20`, `add xp 300`, `add attr 3`, `add pp 5`, then `status`. Spend points in TAB. Check bonuses remain separate and commands reject negative, fractional, unknown and oversized inputs.
3. Run `save`, restart Play, and run `load`; verify attributes, points and power purchases return. Run `reset` and verify 1/1/1, level 1, zero balances, full health/stamina, and only Power Jump. Use `load` to restore the unchanged save.
4. Try reset while flying, charging, carrying a vehicle, and dead. Confirm no lingering traversal or combat state.
5. Spawn a civilian and hostile; verify they begin simulating after closing. Toggle landing/performance HUD and verify the overlays in gameplay.
6. Check Tab completion, Up/Down history, `help`, and `clear`, including a rebound console key.

## Validation completed

47 relevant regression scripts passed. Godot editor import found no GDScript parse errors. The console was rendered with the real Godot UI at 1280Ã—720 and inspected for readability, help text, command output and input layout. Automated tests cover keyboard Enter/history/completion, Xbox View opening, pause isolation, command validation, explicit saves, reset from death, starter progression, NPC spawning and retained diagnostic toggles. City horns still start and repeat naturally after removing preview code. Physical controller typing and full gameplay feel remain manual checks. Existing tool-environment user-directory/certificate warnings remain; failure fixtures intentionally test rejected save paths.

Gang encounters lock their roster and bonus at spawn. Completion bonuses are 100/500/1,000 XP for Easy/Mid/Hard, in addition to enemy XP. Medium has a tunable 2% super chance replacing its rifle. Spawn sites are 60-200 meters away and require room for the full group. See [encounter rules](docs/encounters.md).
