# Enemy lock-on

The powers/gameplay menu now opens with **P**. Older saved default assignments migrate from Caps Lock/Tab to Tab/P; unrelated custom bindings remain intact.

Tap **Tab** to select the nearest visible living enemy within **60 m** of the hero. Further taps cycle the other visible enemies in stable order and wrap around. Targets are aggressive `HostileBase` NPCs; civilians, neutral NPCs, corpses and scenery are excluded. The existing attack helicopter is not a person in this NPC group.

Hold **Tab for 0.5 seconds** to release. Short taps execute on key release, so a held unlock never cycles first. Holding without a target does not acquire one. Keyboard repeat cannot advance the target repeatedly. The control appears in the existing binding settings; the controller default is **D-pad Left** and other bindings are retained.

When the selected enemy dies, lock-on selects the nearest remaining visible, aggressive enemy within **60 m**, using the same field-of-view and cover checks as manual acquisition. If none qualify, it releases. This also works if the dead enemy is immediately removed. Losing a living target to distance, cover, removal or changed allegiance does not trigger automatic retargeting.

**Right mouse / Aim** releases lock-on immediately so mouse motion can aim freely in the same frame. Held aim (including remapped/controller aim and accessibility toggle mode) prevents lock acquisition and takes priority over a simultaneous enemy death. Releasing aim leaves lock-on disabled until a fresh **Tab** tap. Pending Tab presses are discarded when aiming starts.

## Movement and camera

The camera follows the target's upper torso smoothly, retaining the existing spring arm collision, pitch limits and landing effects. A gold diamond identifies the target and the HUD displays its name and controls. Mouse/controller look cannot fight the camera while locked. Unlock keeps the current camera orientation and restores free look.

On the ground and during ordinary jumps, the hero faces the target: **W** approaches, **S** retreats, and **A/D** strafe. This uses existing locomotion animations. The opening grounded punch now dashes toward the selected enemy and starts its hit timing after arrival; later combo hits do not dash. Punch damage is unchanged and reach extends 0.4 m farther, preserving the previous close-range coverage. Solid cover still blocks hits. Flight retains its existing camera-relative controls and flight poses; hovering does not automatically chase the target. Wall-running, a ground slam, ship interaction, knockout or death releases the lock.

## Release rules and tuning

### Opening punch dash

With a target locked, the first grounded attack closes the gap using the player's normal collision movement. It pauses the punch wind-up during travel and restarts the punch on arrival, about 2 m from the enemy. It does not teleport, add damage, or repeat on later hits or when the combo loops. Unlocking, changing targets, target death, a blocking wall or a ledge cancels the dash. Brief loss of floor contact on shallow pavement drops is tolerated for 0.15 seconds; walkable slopes do not count as walls. Flight attacks retain their existing controls.

Movement keys cannot interrupt the approach or enter wall-running while attacking. Bullet hits still deal damage and play their impact sound, but do not flinch or slow a committed melee attack. Dash speed also ignores an existing hit slowdown so a bullet just before the click cannot cause a premature timeout. Death and knockout still cancel combat.

One follow-up click is buffered during travel or early punch wind-up and survives arrival. Additional clicks cannot queue a whole sequence. Disable `buffer_early_combo_input` to restore the final-window-only rule for normal swings. Every new swing restarts its animation, clearing previous hit/landing reaction state. Grounded clicks take priority over a stale jump flag, and active combos accept follow-ups during the uppercut's brief airborne phase.

Uppercut launch speed is now **6 m/s** (previously 12), adjustable through `uppercut_launch_velocity` on the combat controller. At the player's default gravity this produces a hop of roughly **0.75 m**, instead of roughly 3 m, reducing the chance of landing on an enemy's head. Damage and forward motion are unchanged. The physics regression checks that the hop stays below 1 m and returns to the ground without standing on the enemy.

Inspector controls on **Player/PlayerCombatController**: enabled, speed (**75 m/s**), maximum starting distance (**60 m**), timeout (**1.1 s**), allowed height difference (**1.5 m**), floor-contact grace (**0.15 s**), and early combo input buffering. It is a ground dash; it does not jump between rooftops. Punch reach uses an extended collision volume to keep close targets hittable while reaching **0.4 m** farther than before. Among overlapping valid hits, the locked enemy is preferred.

The dash aims **0.25 m inside** its arrival distance (`opening_dash_arrival_margin`). This prevents retreating melee enemies from holding the player in the paused wind-up: previously the player stopped exactly at 2 m, the enemy moved just outside the 2.05 m arrival threshold on its next tick, and the dash repeated that chase until timeout. The inner stopping point lets arrival commit while the enemy moves. Attack timing, damage, enemy behavior and wall/ledge checks remain unchanged.

`tests/test_melee_dash_recovery.gd` runs normal player/enemy physics and animation playback against melee groups, gunmen and supers at 3, 10 and 25 m. It verifies damage, bounded wind-up near the target, and restored movement after the combo. The old implementation failed all three retreating-melee cases; logs are in `artifacts/melee-dash-regression-before*` and `artifacts/melee-dash-regression-after*`. Files changed for this correction: `scripts/player-scripts/player_combat_controller.gd`, that new regression test, and this guide.

Reliability regression checks in `tests/test_opening_punch_dash.gd` reproduce the previous gunfire timeout, discarded travel click and grounded stale-jump rejection. They also cover moving targets, pavement drops, movement/wall-run exclusion, restarting interrupted clips, normal engine animation playback, and wall/ledge safety. Results are in `artifacts/dash-fix-*`. This fix changes the combat controller, animation controller, damage receiver, player input routing, wall-run eligibility, that test and this guide. Interactive combat feel still needs an in-game playtest.

This update changes `scripts/player-scripts/player_combat_controller.gd`, `scripts/input_bindings.gd`, `project.godot`, `tests/test_opening_punch_dash.gd`, `tests/test_player_target_lock.gd`, `tests/test_control_bindings.gd`, `tests/test_gameplay_menu.gd`, and this guide. Test with an enemy 10–30 m away: Tab to lock, then attack. Verify that you close the gap, hit after arriving, and continue the combo without another dash. Also test a wall, a ledge, and P opening/closing the powers menu. Automated movement/hit/binding checks are recorded under `artifacts/opening-dash-*` and `artifacts/dash-*`; the new dash's animation feel has not been visually playtested.

### Lock retention

- Break distance: **80 m**, allowing room beyond the acquisition radius.
- Cover: initial selection requires a clear camera ray to the torso or head. A selected enemy may be obscured for **0.5 seconds** before release; passing behind a narrow obstruction briefly is tolerated.
- Target death selects the nearest eligible visible enemy within acquisition range, or releases if none qualify. Removal of a living target or becoming non-aggressive releases without switching.
- Right mouse or held aim releases immediately; aiming blocks retargeting and requires a fresh Tab tap afterward.
- Menus/focus resets cancel pending taps/holds, preventing a release in a menu from becoming an unintended cycle.
- Selection scans the hostile group when requested. Only the current target is monitored afterward, with visibility rays at **0.1-second** intervals.

Tune acquisition distance, break distance, hold duration, obstruction grace, visibility interval, camera follow speed and torso height on **Player/PlayerTargetLock** in the Inspector.

## Files changed

The death-retargeting, free-aim and lower-uppercut update changes `scripts/player-scripts/player_target_lock.gd`, `scripts/player-scripts/player_character.gd`, `scripts/player-scripts/player_combat_controller.gd`, `tests/test_player_target_lock.gd`, `tests/test_opening_punch_dash.gd`, and this guide. Tests cover death/cleanup, no eligible replacement, aim priority, fresh-press requirements, and uppercut height/contact. Logs are `artifacts/lock-retarget-*` and `artifacts/uppercut-height-*`.

- `project.godot`, `scripts/input_bindings.gd`: startup action and remappable defaults.
- `scenes/player.tscn`, `scripts/player-scripts/player_target_lock.gd`: targeting component, tracking and UI.
- `scripts/player-scripts/player_character.gd`: tracking before movement and combat-facing strafing.
- `scripts/player-scripts/player_input_controller.gd`, `player_input_snapshot.gd`: tap/hold snapshots, free-look ownership and interruption resets.
- `tests/test_player_target_lock.gd`, `test_player_input_snapshot.gd`, `render_target_lock.gd`: tests and inspection capture.
- This guide and generated Godot script UIDs.

## Test in Godot

Use `spawn pistol_thug 3` or `spawn gang_activity` in the developer console. Close it, face the group, and tap Tab repeatedly. Confirm the marker cycles, A/D circle the target, S backs away without turning the hero, and punches connect only within reach. Hold Tab for half a second and confirm no intervening target switch. Reacquire, then move beyond 80 m or behind solid cover to break the lock. Test rebinding in Controls as well.

Automated checks cover selection exclusions, cycling, tap/hold thresholds, focus/menu interruption, target deletion, obstruction, range, strafing, melee facing and hovering. Existing directional movement, input, bindings, combat, flight surge and ship docking checks are also run. The Godot-rendered test arena in `artifacts/target-lock.png` verifies the marker and HUD placement; interactive combat feel still needs a player playtest.
