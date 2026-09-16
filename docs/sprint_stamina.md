# Sprint input and airborne stamina

Non-flight airborne movement now freezes stamina drain, regeneration and the regeneration-delay timer. This includes rising and falling, with or without Shift held. Grounded accounting resumes after landing. Flight retains boosted drain and ordinary regeneration. Air control and movement speeds are unchanged.

The player passes actual floor contact before and after movement into `PlayerStamina.finish_tick()`, so takeoff and landing frames cannot bill airborne displacement as ground sprinting. Stamina intent now comes from the same filtered input snapshot as movement, including power-selector/menu suppression.

## Stale sprint investigation

Normal keyboard-event tests passed for Shift released before W, W released before Shift, and Shift released while the power selector owns input. A separate regression reproduced a stale hold across input resets: an outstanding sprint press remained in Godot's action state after focus-loss/pause notifications, power-selector open/close, or controller disconnect. These tests model the case where a release is missed; they do not establish the exact physical sequence behind every reported occurrence.

Previously, `PlayerInputController.reset()` cleared only the toggle-sprint latch. It now also releases the raw sprint action. After a cancellation such as pause, focus loss or opening the power selector, release/repress Sprint to resume; the previous hold cannot restart sprint unexpectedly. The optional Toggle Sprint accessibility setting remains supported and still intentionally continues sprinting after a tap until toggled off or cancelled. No saved control preferences were changed.

## Car-ramp follow-up: Hold mode remains active until Shift is tapped

The player confirmed Hold mode. [Godot issue #122728](https://github.com/godotengine/godot/issues/122728) reports the same W + Shift release symptom in Godot 4.7.2 on Windows: the action remains pressed while the physical key check correctly reports released. This is a likely explanation, not a captured hardware diagnosis from this game session.

Hold-mode sprint now requires both the sprint action and an actually held mapped control. `InputBindings.is_bound_control_held()` checks the current InputMap's physical/logical keys, mouse buttons, gamepad buttons and trigger axes. This respects rebinding and controller input. Keeping the action check preserves cancellation on focus loss, menus and pause even if the physical control remains down. Toggle mode still uses its intentional accessibility latch.

A new fault-injection regression reproduces the stale action independently of keyboard hardware: release the physical Shift event, deliberately leave the sprint action pressed, and keep W held. It failed before this guard and passes afterward. Rebound keyboard/mouse controls, a gamepad button, fresh presses and cancellation also pass.

The car regression runs the actual player movement loop against `normal_car_2.tscn` at Speed 5, 20 and 50. It reaches WallRunState, releases Shift airborne, injects the stale action, and lands while W remains held. Sprint requests stay off, stamina does not drain, and speed settles to ordinary walking without another Shift tap. Existing air/bounding momentum and deceleration remain; at high Speed, settling can take several seconds. The test allows eight seconds on the ground to distinguish this from an indefinite input latch.

Ten scripts passed in this follow-up: held controls, car ramp, airborne stamina, toggle sprint, boost recovery, input reset, stamina, control bindings, flight surge and power selector. Editor import completed without GDScript parse errors. Environment/settings warnings and some shutdown resource warnings remain. These are automated tests with injected key events, not a visually observed keyboard playtest.

Follow-up files changed:

- `scripts/input_bindings.gd`: inspect mapped controls independently of cached actions.
- `scripts/player-scripts/player_input_controller.gd`: apply the held-control guard in Hold mode.
- `tests/player_test_support.gd`: inject mapped key/button events for sprint fixtures.
- `tests/test_player_airborne_stamina.gd`, `tests/test_player_stamina.gd`, `tests/test_player_toggle_sprint.gd`, and `tests/test_player_boost_recovery.gd`: use physical events; update the older boost-recovery test for the airborne freeze rule.
- Added `tests/test_sprint_held_controls.gd` and `tests/test_car_ramp_sprint.gd`, with Godot UID sidecars.
- Updated this guide.

Playtest: restart the running game, hold W + Shift into a car, release Shift in the air and keep W held through landing. Stamina should remain frozen while airborne, then recover after its grounded delay; sprint should stay off without tapping Shift again. Some existing momentum may remain briefly. Also verify a fresh Shift press starts sprint and Toggle mode still works if enabled deliberately.

## Validation

Seven scripts passed: airborne stamina, sprint-input reset, existing stamina accounting, toggle sprint, power selector, flight surge and developer console. The new reset test failed before the fix and passed after it. The airborne test runs the player movement loop through grounded sprinting, rising, falling, Shift release, landing, exhaustion, flight boost and flight cancellation. Godot editor import found no script parse errors. Existing environment/settings and occasional shutdown-resource warnings remain. This was automated validation, not a physical-keyboard playtest of the user's exact reproduction.

Manual checks:

1. Spend some stamina sprinting, jump or walk off a ledge, then release Shift. The bar should stay fixed in the air and recover on the ground after its remaining delay.
2. Repeat while holding Shift through the fall. The bar should stay fixed in the air, then drain when grounded sprinting resumes.
3. Sprint, open the power selector or pause, release Shift, then return. Sprint should stay off until a fresh press.
4. Sprint, switch away from the game, release Shift outside it, then return. Sprint should stay off.
5. Confirm flight boost still drains and ordinary flight recovers stamina.

Files changed:

- `scripts/player-scripts/player_character.gd`: filtered sprint intent and floor-contact accounting.
- `scripts/player-scripts/player_stamina.gd`: pause stamina changes during ordinary airborne movement.
- `scripts/player-scripts/player_input_controller.gd`: clear raw sprint action on reset.
- `tests/test_player_stamina.gd`: pass the explicit grounded-accounting argument.
- Added `tests/test_player_airborne_stamina.gd` and `tests/test_sprint_input_reset.gd`, with Godot UID sidecars.
- Added this guide.
