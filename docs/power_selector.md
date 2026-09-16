# Active power selector

Hold **Left Alt**, move the mouse toward a power, and release Alt to equip it.
The center keeps the current power; Escape cancels. Controller default: hold
**LB**, point the right stick, then release LB. Both bindings can be changed in
Settings. Right Alt is excluded from the default shortcut.

The four slots are Laser Eyes (top), Ice (right), Fire (bottom), Electricity
(left). Laser Eyes starts equipped. Ice is a selectable placeholder labeled
NOT IMPLEMENTED. Laser Eyes, Fire and Electricity require their purchased
cores. Aim with right mouse, then hold left mouse for Laser Eyes or Electric
Shock, or tap it for a Fireball. Fire upgrades add hold/release charging and
Dragon Breath on Q. Without aiming, existing melee/slam controls remain.
All three implemented powers share Heat and overheat. See `fire.md` and
`electricity.md` for tuning and controls.

The bottom-center HUD shows the equipped power and selector binding. Ordinary
save/load includes the selection, with Laser Eyes as the fallback for old saves
or invalid selections. Changing the selection does not automatically save.

The world continues running while choosing. Movement input, attacks, and camera
look are suppressed; flight can settle into hover and airborne gravity continues.
Opening cancels beam, flight/jump charging, and vehicle throw charging while
preserving any held vehicle. Firing requires releasing attack after closing.
Focus loss, death, knockdown, another menu, a binding change, and controller
disconnect cancel the wheel.

## Files changed for this feature

- `project.godot`, `scripts/input_bindings.gd`: selector action/defaults.
- `scenes/player.tscn`, `scripts/ui-scripts/power_selector.gd`: radial overlay.
- `scripts/player-scripts/player_power_controller.gd`: active selection.
- `scripts/player-scripts/player_character.gd`, `player_input_controller.gd`,
  `player_laser_eyes.gd`, `player_vehicle_interactor.gd` in that same folder:
  input isolation, selected-power firing, and charge cancellation.
- `scripts/save_manager.gd`: selection persistence.
- `scenes/ui/gameplay_hud.tscn`, `scripts/ui-scripts/gameplay_hud.gd`,
  `localization/powers.json`: equipped-power display and text.
- `tests/test_power_selector.gd`, `tests/render_power_selector.gd`:
  behavior checks and repeatable visual preview (plus Godot-generated UIDs).

## Validation

Godot 4.7.2 headless editor import and selector checks; regressions for Laser
Eyes, input snapshots, control bindings, HUD, and gameplay menu. The wheel and
equipped HUD were rendered in a test arena and screenshots inspected. This is
not a manual playthrough of the full city. Sandbox runs report unavailable
user settings/caches and root certificate store; the gameplay-menu test also
reports an inaccessible temporary save path, despite its assertions passing.
The selector save/load test uses a workspace-local temporary file and passes.

In Godot, try all four directions and the center, cancel with Escape, switch
while firing, then select Laser Eyes and fire with a fresh aimed click. Try it
while flying and charging a jump, and verify that the camera stays still while
choosing. Save and reload after selecting another power.
