# Keyboard, mouse, and Xbox controls

Open **Settings → Controls** from the main menu or pause menu. Each gameplay action has one keyboard/mouse binding and one Xbox binding. Select a binding, then press its replacement. Assigning an occupied input swaps the two actions within that device's column. Changes apply immediately and save to `user://settings.cfg`; each column has its own reset button.

## Default scheme

| Action | Keyboard / mouse | Xbox |
| --- | --- | --- |
| Movement | W / A / S / D | Left stick, fixed |
| Camera | Mouse, fixed | Right stick, fixed |
| Jump / charged jump / ascend | Space | A |
| Sprint / boost | Shift | L3 (left-stick click) |
| Toggle flight | F | Y |
| Punch / charged punch / airborne ground slam | Left mouse | X |
| Descend in flight | Ctrl | B |
| Aim / camera-facing strafe | Hold RMB | Hold LT |
| Secondary power / Dragon Breath while aiming | Hold Q | Hold RT |
| Power selector | Hold Alt | Hold LB |
| Pick up / charge throw / drop vehicle | E | RB |
| Pick up / safely set down injured civilian | E | RB |
| Pause | Escape | Menu |
| Gameplay menu | Tab | R3 (right-stick click) |
| Developer menu | Backtick | View |

Jump and vehicle interaction keep their existing hold/release behavior. Sprint defaults to Hold; **Gameplay → Boost / Sprint → Toggle** also applies to L3 or its replacement. Flight and wall-running still require their existing unlocks.

**Strength upgrade 1: Charged Punch.** While grounded and empty-handed, hold Attack for 0.25 seconds to begin charging, then release to punch. Full power takes 1 second total hold. Quick clicks perform normal punches on release once this upgrade is unlocked. The 10-metre, 60-degree cone deals up to 100 damage nearby, falling to 30 at its edge; shorter holds are weaker. Susceptible enemies are knocked down, supers resist knockdown, and walls block the hit. Airborne Attack still uses the existing ground slam; Attack while holding an enemy still slams them. See [tuning and animation source](docs/charged-punch.md).

Rescue civilians use a press of E/RB for pickup or safe set-down. They cannot be thrown. While carrying any person or car, other pickups are blocked; a release press cannot also grab another object. Person pickup requires no Vehicle Lift unlock. Sprinting, jumping and flight remain available. Heavy/Super landings and ground slams while carrying a person subtract five seconds from the rescue's preview timer.

Buttons, bumpers, stick clicks, D-pad directions, LT, and RT can be assigned. Controller stick axes cannot be reassigned or used as action buttons. The Xbox system/Guide button stays with the operating system. Keyboard bindings use individual physical keys, including modifier keys themselves; modifier chords and mouse-wheel bindings are not supported. Left/right/middle and the two standard mouse side buttons are supported.

During capture, Escape cancels, or leave the controller untouched for 15 seconds to cancel. Escape is reserved for cancellation in this screen; Reset Keyboard / Mouse restores the default Escape pause binding. Release an already-held trigger before assigning it. Capture also cancels when settings close, the application loses focus, or a controller disconnects. Binding/capture input is consumed before menu actions; player input is blocked during capture.

The gameplay menu opens with Tab / R3 and has Powers, Gear, Attributes, Journal, and Map tabs; see [GAMEPLAY_MENU.md](GAMEPLAY_MENU.md). Its action is rebindable. When added to an older settings file, occupied default inputs receive an unused alternative without resetting existing custom bindings.

Menu controls stay fixed: D-pad navigation, A selects, B goes back, and LB/RB switch settings tabs. Keyboard Tab/arrows/Enter and Escape remain available. Gameplay pause has its own input action, so B can descend during gameplay and go back during menus. Bindings work across controller reconnection/device IDs. All connected gamepads share the Xbox control scheme; this is a single-player input setup.

## Movement and feedback

### Eight-direction movement update

Changed files for this update:

- `scripts/player-scripts/player_character.gd`: full ground movement facing, persistent idle heading, and camera-facing aim mode; retains the exported turn-speed setting.
- `scripts/player-scripts/player_input_controller.gd`: preserve world-facing heading during ordinary camera rotation and follow camera yaw during aiming.
- `scripts/input_bindings.gd`, `project.godot`: pickup E, secondary power Q, flight F; versioned saved-default migration preserves custom assignments.
- `localization/powers.json`, `docs/fire.md`, `docs/laser_eyes.md`, `docs/power_selector.md`, and this guide: synchronized control descriptions.
- Added `tests/test_player_directional_movement.gd` and `tests/test_player_pickup_binding.gd` (plus UIDs); updated `tests/test_control_bindings.gd` and the control descriptions in `tests/test_fire_upgrades.gd`.

Validation for this update: editor import reported no GDScript parse errors. Ten headless scripts passed: directional movement, physical pickup bindings, control bindings/migration, movement motor, input snapshot, flight surge, bounding, fire upgrades, laser eyes, and vehicle-interactor cleanup. Real E input picked up and threw a car with Vehicle Lift unlocked. Environment certificate/settings warnings and some shutdown resource warnings remain. Visual gameplay feel was not observed.

Manual check: walk and sprint in all eight directions, stop and orbit the camera, then hold RMB and repeat A/D/S. The body should face movement normally, stay in its last world heading while idle, and face the camera's forward direction while aiming. Release RMB while moving to resume turning. With Vehicle Lift unlocked, aim the camera at a nearby car and use E to pick up, then hold/release E to throw. Check RMB+Q with Dragon Breath unlocked and selected, and F for flight.

Ground walking/sprinting turns the character fully toward camera-relative movement: eight keyboard directions and continuous stick directions. Movement responds immediately while the model turns smoothly, controlled by the player Inspector's `movement_turn_speed`. Releasing movement keeps the last world-facing direction even while orbiting the camera. Hold RMB/LT (or the aim accessibility toggle) to face camera-forward and strafe. Jump launch direction, air control and flight retain their existing camera-relative rules.

Old saved default pickup R and secondary-power E bindings migrate to E and Q. Custom bindings are preserved; a custom action occupying Q takes priority. Flight stays F. Vehicle Lift must be unlocked to pick up cars, and the camera must point at a vehicle within pickup range.

Left-stick movement preserves analog strength on the ground and in flight, with a circular 20% movement deadzone. Right-stick camera movement also has a deadzone and uses elapsed time, maintaining consistent rotation across frame rates and preserving existing camera pitch limits. On the player's `PlayerInputController` child, the Inspector exposes controller look speed (150 degrees/second by default) and look deadzone (20%). Mouse sensitivity keeps its existing player setting.

The HUD's existing jump/flight/sprint hints switch between keyboard and Xbox labels as those devices are used and update after rebinding. Sprint toggle clears when bindings change or a controller disconnects, in addition to existing pause/focus/death/accessibility resets. Repeated trigger motion samples produce one attack, sprint-toggle, pause, or developer-menu activation per squeeze. Background controller input is disabled while the application is unfocused.

## Extending the scheme

`scripts/input_bindings.gd` owns the action catalog, defaults, fixed sticks, Xbox labels, capture, conflict swaps, and ConfigFile serialization. `GameSettings.input_bindings` is its shared instance, created before the player/menu scenes. It registers gameplay actions in Godot's InputMap at startup; the catalog is the runtime source of truth, including for the older actions already present in `project.godot`.

To add an action, add its ID, display name, default physical key (negative mouse-button index for a mouse binding), and default Xbox button to `ACTIONS`. Use unique defaults. The Controls UI, reset, and persistence pick it up automatically. Then consume the named action in the relevant gameplay system or input snapshot. Use `is_action_press(event, action)` for event-driven button actions that may be rebound to a trigger; it prevents continuous axis samples from repeating a press. Polling actions can continue using Godot's `Input` API. Camera/stick mappings live separately in `STICKS`.

Preferences add `bindings_keyboard` and `bindings_controller` sections to the existing settings file. Missing sections use defaults. Invalid entries or duplicate bindings restore that device's default set; gameplay save data and power progress are unaffected. Save failures appear in the settings status message, and the chosen bindings remain active for the session.

## Verification and manual checks

The 42 relevant headless regression scripts passed, including player states, input, combat, settings, HUD, audio, and power-menu tests. `tests/test_control_bindings.gd` covers persisted bindings, conflicts, invalid data, fixed sticks, input capture/cancellation, controller-driven menu navigation, analog movement/look, trigger edges, sprint disconnect reset, and the separate gameplay-pause/menu-Back behavior. It uses simulated Godot input events and isolated temporary preference files.

The Controls tab, scrolling, focus navigation, and capture overlay were rendered with Direct3D 12 / Forward+ and inspected at 1280×720. Physical Xbox hardware and traversal feel still need hands-on testing. Headless runs have the existing restricted-user-directory/certificate-store warnings; some existing audio fixtures also report resources at shutdown.

1. With an Xbox controller, use D-pad/A to open Settings and LB/RB to reach Controls. Change keyboard and Xbox bindings, try a conflict swap, restart, and verify both sets persist. Reset one column and confirm the other is retained.
2. Move the left stick slightly and fully on the ground and in flight; check right-stick camera speed, drift, and pitch limits. Keyboard movement should retain its previous full-speed behavior.
3. Test A tap/hold/release jump, Y flight, X punches/air slam, B descend, and RB vehicle pickup/throw/drop. Test L3 with both Hold and Toggle sprint.
4. Rebind an action to LT/RT. Check one activation per squeeze for toggle/attack actions and proper hold/release for jump and vehicle throwing. Move the sticks during capture and confirm they are ignored.
5. Confirm Menu pauses, B returns from settings and resumes from pause actions, and B never pauses while descending. Rebind Pause and verify the replacement works. Try capture cancellation, unplug/reconnect, and switching application focus.

## Files changed for this feature

- Added `scripts/input_bindings.gd`, `scripts/ui-scripts/control_bindings_panel.gd`, and `tests/test_control_bindings.gd`, with Godot UID files.
- Updated `scripts/game_settings.gd`, `scripts/ui-scripts/settings_menu.gd`, and `scenes/ui/settings_menu.tscn`: binding storage, Controls tab contents, tab navigation, and visible status feedback.
- Updated `scripts/player-scripts/player_input_controller.gd` and `player_character.gd`: stick look, action-based attacks, capture guards, and sprint resets.
- Updated `scripts/player-scripts/player_normal_movement_state.gd` and `player_flying_state.gd`: analog movement strength.
- Updated `scripts/ui-scripts/main_menu.gd`, `pause_menu.gd`, `developer_menu.gd`, and `gameplay_hud.gd`: Xbox focus, pause/Back distinction, input guards, and device-specific hints.
- Updated `tests/test_settings_tabs.gd` and `SETTINGS_MENU.md`; added this guide.

The developer console pauses gameplay while open. Backtick/View opens it; Escape/B or the console binding closes it. Type `help` for commands, use Tab for completion and Up/Down for history. See [DEVELOPER_CONSOLE.md](DEVELOPER_CONSOLE.md).
