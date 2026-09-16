# Electric Shock core

Buy the Electric core in the Powers menu (one token), then select Electricity
in the Alt wheel. Aim with right mouse and hold left mouse to channel lightning.
Controller: LT + X. Existing Aim/Attack rebinding and aim-toggle accessibility
settings apply. The existing Electricity save ID and selector slot are reused.

Default tuning on `PlayerElectricity` in `scenes/player.tscn`:

| Setting | Value |
| --- | --- |
| Damage | 30 per second, tagged `electricity` |
| Range | 30 meters, measured from the hand |
| Heat | 20 per second, including misses |
| Cooling | Shared 0.75-second delay, then 25 Heat/sec |

The shock hits one aimed target through the existing damage interface:
civilians, enemies, and damageable objects. Lightweight civilian capsules
participate through the existing ray lookup. A camera ray resolves aim, then a
hand ray enforces range and cover. Forked lines are decorative; they do not
chain damage to extra targets. The animated RightHand bone anchors the effect.
There is no new stun/status system, and all three upgrades remain planned.

The core uses the same Heat pool and overheat behavior as Fire and Laser Eyes.
At 100 Heat: stop the shock, explode, knock down, cancel flight, and apply
floor(30% of maximum health) damage. Final damage is clamped to the time left
before overheat. Fully cool and release Attack before resuming. Aim release,
power switching, selector/menu opening, focus loss, death, and input reset stop
the effect. Switching powers does not clear Heat.

Lightning is built in code from two flickering ribbons and decorative forks,
with a contact spark/light. One ImmediateMesh holds the ribbons; geometry and
materials are reused and no per-segment nodes, new textures, or third-party
addons are introduced. This basic effect does not add a new audio asset.

## Files changed

- `scripts/player-scripts/player_electricity.gd` (new): core damage and tuning.
- `effects/electric_arc.gd` (new): animated lightning and impact visuals.
- `scenes/player.tscn`: PlayerElectricity component.
- `scripts/player-scripts/player_laser_eyes.gd`: shared aiming, Heat, cancellation.
- `scripts/player-scripts/player_power_controller.gd`: Electric core unlock.
- `scripts/ui-scripts/power_menu_progression.gd`: mark only core implemented.
- `scripts/ui-scripts/gameplay_hud.gd`, `localization/powers.json`: Heat/hints/UI.
- `tests/test_electricity.gd`, `tests/render_electricity.gd` (new),
  `tests/test_powers_page.gd` (updated), and generated Godot UIDs.
- `docs/electricity.md`, `docs/power_selector.md`.

## Validation and playtest

Electricity tests cover purchase and saved unlock restoration, gating, held
input, exact damage/Heat at different tick rates, range, hand-relative cover,
misses, lightweight civilians, cancellation, cooling, flying overheat and the
exact health cost. Fire, Fire upgrades, Laser Eyes, selector, HUD, input
snapshot, Powers page/localization and power-attribute regressions passed.
Lightning and the Powers menu were rendered and inspected in the test arena;
full-city manual gameplay remains a player check.

In Godot, unlock Electric, equip Electricity with Alt, and hold RMB + LMB on a
civilian/enemy or damageable object. Check a target behind cover and one beyond
30m. Release either mouse button and switch powers while firing. While flying,
fill Heat and verify the existing explosion, fall, and full-cooling lockout.
