# Gameplay menu and purchased power locks

Press **TAB** during gameplay to open the player menu. TAB again, Escape, or Close resumes play. Xbox defaults to **R3** (right-stick click); B closes and LB/RB switch tabs. The gameplay-menu action is bindable in Settings → Controls. Older custom bindings are preserved: if TAB or R3 was already assigned, the new action receives an unused binding instead. TAB continues navigating settings while the pause menu is open.

The menu has **Powers, Gear, Attributes, Journal, Map** tabs. Gear, Journal, and Map are blank. Powers uses the existing page, moved out of Pause; its categories are now Movement, Body, Elemental. All nine documented cores and 27 upgrade slots have localized names and descriptions. The power cards stay visible while their detail panel scrolls. Attributes shows Strength, Speed, Resilience, level, and XP and refreshes from stat events. Power bonuses display in the effective total with the contribution beside it, for example `Strength 15 (+5)` for base 10 plus 5. Players now spend earned attribute points here; each level gained through XP awards one point, and each point buys +1 to a chosen base attribute.

## Gameplay locks implemented

| Existing ability | Required purchase |
| --- | --- |
| Charged superhero jump | Super Jump core (free starter) |
| One Air Jump per airborne trip | Super Jump upgrade 2 |
| Bounding after a fast, forceful landing | Super Jump upgrade 3 |
| Boosted ground sprint | Speed core |
| Wall running | Speed upgrade 3 |
| Normal flight | Flight core |
| Boosted flight | Flight upgrade 1 |
| Existing airborne ground slam, now labeled Dive Bomb | Flight upgrade 2 |
| Physical car pickup / throwing | Strength upgrade 2 |
| Existing marker toward active encounters | Mind core |

New games start with the Power Jump core unlocked and zero tokens; all other powers start locked. Ordinary movement, uncharged jumps, and basic punches remain available. Core purchases have no cross-branch prerequisites. Buying a branch advances exactly one tier at a time; wall running and car lifting cannot bypass earlier tiers. The developer console grants power points to spend in the menu; direct ability overrides have been removed.

**Core attribute bonuses are now active:** Strength grants +5 Strength points; Speed grants +5 Speed points. Strength currently increases punch damage. Speed increases boosted running and flight targets and their acceleration. Ordinary movement and normal flight stay at a fixed 10 m/s by default. At base Strength 10 and Speed 1, Attributes shows `Strength 15 (+5)` and `Speed 6 (+5)`. Strength-scaled jumping/impact damage, charged punches, heat, and elemental attacks remain planned. Air Jump is active at Super Jump upgrade 2 and Bounding at upgrade 3. Greater Jump (Super Jump upgrade 1) is active. Stamina and Speed upgrade 1 (Endurance) are active.

Unfinished tiers remain purchasable in sequence, marked **PLANNED**, so the documented paths to existing later upgrades are reachable. Purchasing a planned tier reserves that tier but does not enable a nonexistent mechanic. Flight's third slot remains “To Be Defined.”

## Tokens, saves, and compatibility

Costs retain the existing temporary **one token per core or upgrade**. Earning power tokens is still undefined; attribute points are a separate level-up reward. Use console `add pp 5` for testing, then `save` to persist console changes. Purchases in the Powers/Attributes menus still autosave current player progression. Play starts a fresh scene; use console `load` to restore a saved player. See [DEVELOPER_CONSOLE.md](DEVELOPER_CONSOLE.md).

The player owns one progression model through `PlayerPowerController`; menu visibility does not own or reset progress. SaveManager writes that model into the existing `power_menu` section, now with schema version 2. Purchased tiers drive current ability flags on load. Legacy default-true gameplay flags cannot grant unpurchased powers.

Old prototype saves migrate as follows:

- Stable IDs remain `super_leap`, `super_speed`, `flight`, `ice`, `fire`, `electricity`, and `laser_eyes`, even where displayed names changed.
- Purchased `telekinesis` tiers become Mind tiers.
- A purchased standalone `ground_slam` grants at least Flight tier 2, preserving access to that move under its new path. Its old placeholder upgrades do not create additional new mechanics.
- Power Jump is the starter core. Loading retains its purchased upgrades and always grants at least the core.
- Missing progression starts with Power Jump only and zero tokens. Invalid currency/tier values are bounded. Loading does not autosave or add bonuses repeatedly.

## Localization and extension

All newly surfaced menu, attribute, power, and upgrade text lives in `localization/powers.json`, using the existing `powers_text.gd` loader and English fallback. Keys include `gameplay.*`, `controls.gameplay_menu`, and `power.<id>.upgrade.<1–3>.name/description`. `power.<id>.current` explains which part currently works. Locale changes update an open menu.

`power_menu_progression.gd` defines branch order, costs, tier limits, and which tiers have implemented effects. `player_power_controller.gd` maps actual abilities to required branch levels. Future implementations should update both the ability mapping and the current/planned copy. The controller derives bonuses from core ownership and applies them through `PlayerStats.set_power_bonuses`. The two core bonuses default to 5 and are tunable on PlayerPowerController in the Inspector. Gameplay reads effective Strength/Speed; saves and developer attribute edits retain base values. Bonus changes emit stat events so Attributes refreshes immediately. Existing saves with the cores purchased gain these benefits when loaded; repeat loads, token grants, and later upgrades do not stack bonuses.

## Validation and test checklist

All 48 relevant headless regression scripts passed, and the final Godot editor import found no GDScript errors. The suite covers existing player systems plus the gameplay menu, attribute bonuses, sequential purchases, ability gates, automatic saves, legacy migration, failure feedback, JSON localization, Xbox menu input, and preservation of custom bindings. Existing traversal regression fixtures now explicitly unlock the abilities they exercise; fresh-game locks are covered separately in `test_gameplay_menu.gd`. Tests use isolated temporary saves and preferences.

The attribute purchase buttons and exhausted stamina HUD were rendered and inspected at 1280×720. Keyboard Enter and Xbox A purchase events passed automated checks. All five tabs and the scrolling Powers details were rendered with Direct3D 12 / Forward+ and inspected at 1280×720. Physical Xbox input and traversal feel still need hands-on checks. The tool environment continues to emit its existing restricted-user-directory and certificate-store warnings; save-failure fixtures deliberately exercise failed writes.

1. Start a fresh game. Verify TAB/R3 opens the five tabs, TAB/Esc/B closes, and Powers is absent from Pause. Check blank Gear/Journal/Map and current Attributes.
2. Before purchasing, confirm charged Power Jump works, while sprint boost, flight, vehicle lifting, and wall running remain locked. Check that ordinary movement, basic jumping, and punching still work.
3. Add test tokens. Buy Flight core, then Flight Boost, then Dive Bomb. Test each ability before and after its tier. Confirm Speed is independently purchasable.
4. Buy the whole Speed path and Strength through upgrade 2. Test wall running and car pickup/throwing. Earlier planned purchases should not claim active dodge/charged-punch effects. Buy Mind and spawn an encounter to test its marker.
5. Save/load and restart/load. Confirm tokens and unlocks agree and Attributes never gains repeat bonuses. Change attributes through the developer tools and check their values on the Attributes tab.
6. Rebind the gameplay menu on keyboard and controller. Check opening/closing, LB/RB tab switching, D-pad card selection, and scrolling to the purchase button.

## Files changed

- Added `scripts/ui-scripts/gameplay_menu.gd` and `scripts/player-scripts/player_power_controller.gd` with UID files.
- Updated `scenes/main.tscn` and `scenes/player.tscn` to add those nodes without changing existing player paths.
- Updated `scripts/ui-scripts/powers_page.gd`, `power_menu_progression.gd`, `power_menu_icon.gd`, `pause_menu.gd`, and `developer_menu.gd` for the embedded page, branch paths, and player-owned progression.
- Updated `scripts/player-scripts/player_abilities.gd`, `player_normal_movement_state.gd`, `player_flying_state.gd`, `player_vehicle_interactor.gd`, `player_encounter_indicator.gd`, and `player_input_controller.gd` for locks.
- Updated `scripts/save_manager.gd`, `scripts/input_bindings.gd`, `scripts/ui-scripts/control_bindings_panel.gd`, and `localization/powers.json` for persistence, controls, and localized copy.
- Added `tests/test_gameplay_menu.gd` and `tests/player_test_support.gd`; updated existing player fixtures and affected menu, save, localization, HUD, settings, and binding tests.
- Added this guide and updated `POWERS_MENU.md`, `POWERS_DESIGN.md`, and `CONTROLS.md`.

## Attribute-bonus follow-up

Modified `player_stats.gd`, `player_power_controller.gd`, `player_character.gd`, `power_menu_progression.gd`, and the localization catalog; updated the affected menu tests and this guide/design reference. Added `tests/test_player_power_attributes.gd` (plus UID) to test real punch damage, movement formulas and flight, effective-value displays, base edits, repeated saves/loads, removal of bonuses, and integer saturation. No save-format change is needed: base stats were already stored separately from purchases.

Manual check: purchase Strength and Speed, open Attributes, compare punch damage and traversal speed, then save/load repeatedly. Starting at base Strength 10 / Speed 1 should remain 15 (+5) / 6 (+5). At default tuning, sprint target becomes 45 m/s and walking/normal flight stay at 10 m/s. Flight still requires its own unlocks.

## Attribute upgrades and stamina

Each level earned through `PlayerStats.add_experience` grants one attribute point. Points can be saved up and spent on Strength, Speed, or Resilience in Attributes. A purchase costs one point and increases the base stat by one, preserving separate power bonuses. Buttons disable when no points remain; purchases autosave and show a retry message if saving fails. The save's `player.stats.attribute_points` field stores the unspent balance. Missing fields default to zero: older saves receive no retroactive points, and assigning/loading a level does not grant points.

`PlayerStamina` is a small child node on Player. Inspector tuning defaults:

| Setting | Default |
| --- | --- |
| Capacity per Resilience | 10 |
| Boost drain per second | 20 |
| Recovery per second | 20 |
| Delay after last drain | 1 second |
| Exhaustion recovery threshold | 20% of capacity |

At Resilience 10, 100 stamina supports five seconds of continuous boosting. Speed's Endurance upgrade halves boosted-running drain to 10/second, allowing ten seconds; flight drain stays 20/second. Drain starts during boost acceleration and uses actual displacement after collision handling, so stationary input and fully blocked movement cost nothing. Existing airborne sprint steering follows running drain. Wall running, charged jumps and Dive Bomb retain their existing resource behavior; no extra stamina costs were added to those moves.

Exhaustion prevents further boosts until 20% has recovered. Holding sprint or leaving toggle sprint on blocks all regeneration, including while coasting, exhausted, stationary, or blocked. Release sprint (or toggle it off) to start the one-second recovery delay. Movement decelerates to its ordinary target and normal flight stays available. Recovery works during ordinary movement and normal flight with sprint off; pause freezes it and death stops it. New player instances start full. Runtime stamina is not added to the save; loading stats adjusts capacity and clamps the current pool. Added capacity fills through normal recovery, not immediate stat-edit refills.

The HUD shows current/max stamina and an Exhausted label during lockout. Settings → Gameplay → Always Show Stamina is active; when disabled, the bar appears only while below capacity. New menu and HUD text remains in `localization/powers.json`.

Changed files for this pass: `player_stats.gd`, `player_character.gd`, `player_normal_movement_state.gd`, `player_flying_state.gd`, `player_power_controller.gd`, `save_manager.gd`, `gameplay_menu.gd`, `gameplay_hud.gd`, `settings_menu.gd`, `power_menu_progression.gd`, `scenes/player.tscn`, `scenes/ui/gameplay_hud.tscn`, and `localization/powers.json`. Added `player_stamina.gd` and two regression scripts (`test_player_attribute_upgrades.gd`, `test_player_stamina.gd`) plus Godot UIDs. Updated `test_player_power_attributes.gd` for fixed normal speeds and the related design/HUD/settings documentation.

Manual checks:
1. Earn XP to level up, open TAB → Attributes, and spend points on each stat. Check the balance, (+5) bonuses, and save/load persistence. Existing saves should have zero points until a new level is earned.
2. Compare walking and normal flight before/after Speed purchases: both should stay at 10 m/s with default tuning. Boosted traversal should become faster.
3. With Resilience 10, sprint/fly boosted until empty. Confirm the fallback to ordinary speed, one-second recovery delay, and restart at 20%. Test both hold and toggle sprint, on keyboard and Xbox.
4. Buy Endurance and compare drain: running should last twice as long; flight should remain five seconds. Increase Resilience and check maximum stamina rises by 10.
5. Stop moving or press directly against a wall while holding sprint. Stamina should not drain. Pause during recovery to confirm the pool freezes. Toggle Always Show Stamina and verify full/in-use visibility.

## Held-sprint recovery and Greater Jump follow-up

Stamina now receives raw sprint intent before ability/stamina gating, through `PlayerInputController.is_sprint_requested`. Exhaustion cannot turn a held input into an apparent release. This also covers rebound keyboard/controller buttons and toggle sprint. The one-second regeneration delay remains held until sprint is released or switched off. Ordinary movement does not need to stop physically before recovering.

Super Jump upgrade 1, **Greater Jump**, doubles charged-jump height and the power's ballistic forward-distance contribution, consistent with the agreed tree. The core alone retains its original jump. Upward velocity and the added forward boost scale by `sqrt(2)`: at unchanged gravity, height and airtime × forward boost each become twice the original. This also raises the maximum output at full charge. Quick jumps are unchanged. Existing momentum, air steering, and terrain still affect actual travel distance; this is not a hard distance limit or the still-planned Strength scaling.

The upgrade multiplier is derived from ownership without changing Inspector base values. Partial charges scale consistently; charge is bounded to its full-charge maximum. Loading and later purchases never compound the upgrade.

Files changed in this follow-up: `player_input_controller.gd`, `player_stamina.gd`, `player_character.gd`, `player_power_controller.gd`, `player_normal_movement_state.gd`, `player_movement_motor.gd`, `power_menu_progression.gd`, `localization/powers.json`, and the gameplay/powers design documentation. Updated `test_player_stamina.gd`; added `test_player_boost_recovery.gd` and `test_player_greater_jump.gd` with Godot UIDs.

Validation includes real player-loop exhaustion/coasting, keyboard held sprint, Xbox L3 toggle events, stationary holds, release delay, actual simulated jump apex, partial charges, full-charge bounds, unchanged quick jumps, and repeated save loads. Gameplay feel still needs an in-editor playtest.

Manual follow-up: exhaust stamina while running and while boosting in flight, keep holding sprint for several seconds, then release it. Confirm no recovery until release plus the delay. Repeat with Toggle Sprint enabled. Compare a fully charged jump with only the Super Jump core against Greater Jump; the apex should be about twice as high. Save/load and repeat.

## Air Jump implementation

Super Jump upgrade 2 grants one Air Jump per airborne trip. The sequential tree is Greater Jump, Air Jump, then Bounding (all three implemented). After buying it, a fresh press of the bound Jump action (Space / Xbox A by default) launches immediately with no charge, whether falling off a ledge, rising/falling from a normal jump, or using Super Jump. Active flight keeps its existing ascend input; falling after leaving flight can use the remaining Air Jump.

The default `air_jump_power_ratio` is 0.5, exposed under Player's Power Jump tuning. It halves the upward launch velocity and added forward impulse of the current fully charged Super Jump, including Greater Jump's multiplier. At current defaults with Greater Jump, this is about 24.75 m/s upward and 21.21 m/s added forward. Existing horizontal momentum is preserved; downward/upward velocity is replaced by the new launch. This is half launch power, not half geometric height: from the launch point, unchanged gravity gives roughly one-quarter of the full jump's height.

The player tracks one consumed use until actual floor contact; toggling flight, entering other movement states, purchasing powers, or reloading progression midair does not refill it. It is unavailable during flight, wall running, knockdown, death, or Dive Bomb. There is no stamina cost. Quick-jump/charge controls on the ground remain unchanged. Reset removes the Air Jump upgrade and clears its runtime use flag; new player instances start with an unused airborne slot.

The new upward launch clears the old fall's tracked landing-impact speed. Only the fall after the Air Jump contributes to the next landing's strength. This prevents canceled high-speed falls from producing stale oversized landing effects.

Changed files: `player_abilities.gd`, `player_power_controller.gd`, `player_character.gd`, `player_normal_movement_state.gd`, `developer_commands.gd`, `power_menu_progression.gd`, `localization/powers.json`, `GAMEPLAY_MENU.md`, `POWERS_DESIGN.md`, and `POWERS_MENU.md`. Added `tests/test_player_air_jump.gd` plus its Godot UID. Updated `tests/test_control_bindings.gd` to finish its jump input frame before testing stick-only movement. Tests cover sequential gating, half-launch values with Greater Jump, momentum, falling, real tap/hold input and Xbox A, actual landings, flight transitions, reloads, forbidden states, no stamina/charge audio, and canceled-fall tracking.

Validation: Godot editor import completed without GDScript parse errors. All 48 selected regression scripts passed, including the new Air Jump test and corrected controls fixture. Headless runs reported existing environment log/settings/certificate warnings. Gameplay feel has not been visually verified and still needs the manual check below.

Manual check: grant `add pp 2`, buy the first two Super Jump upgrades, then tap Jump in the air after a normal jump, a full charged jump, and walking off a roof. Try holding and tapping again before landing: only one extra jump should occur. Land and repeat. With Flight unlocked, ascend normally, then exit flight and tap Jump while falling; flight cycling must not replenish an already-used Air Jump.

## Bounding and reordered Super Jump tree

The order is now Greater Jump (1), Air Jump (2), Bounding (3). Bounding uses the existing bound Jump action, a 0.25-second landing window, and a 0.12-second early input buffer. Both horizontal and downward landing speed must meet their thresholds; Dive Bomb impacts are excluded. Full upward Super Jump velocity is paired with 90% of existing horizontal momentum, with no extra forward impulse or stamina cost. Fast airborne movement coasts with gentle drag so chains work, then naturally end below the speed cutoff. See [BOUNDING.md](BOUNDING.md) for tuning, input priority, save behavior, changed files, and playtest instructions.
