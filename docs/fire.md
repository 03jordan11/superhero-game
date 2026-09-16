# Fire powers

Purchase Fire and its first two upgrades in the Powers menu, then select Fire
in the Alt wheel. Existing saves with these tiers purchased enable them
immediately. External Combustion (third upgrade) remains planned.

| Ability | Keyboard/mouse | Controller | Behavior |
| --- | --- | --- | --- |
| Fire core | Aim with RMB, tap LMB | LT + tap X | 40 damage, 3m blast, 20 Heat per shot |
| Charged Fireball | Aim, hold LMB, release LMB | LT + hold/release X | Full charge in 1.5 seconds; 80 center damage, 6m blast |
| Dragon Breath | Aim, hold Q | LT + hold RT | 20 damage/sec, 12m cone reaching 3m wide in radius |

These use the rebindable Aim, Attack, and Secondary Power actions. The
accessibility aim toggle still works. After unlocking Charged Fireball, even
quick taps launch on release. Partial charges interpolate damage, radius and
visual size. Full blasts deal 80 damage within the inner fifth of their radius,
then fall linearly to 40 at the edge. Normal fireballs keep their fixed damage.

Charging adds 20 Heat/sec, including while held beyond full charge. Launching
adds the normal 20 Heat (50 total for a full 1.5-second charge). Dragon Breath
also adds 20 Heat/sec. Both use the shared meter, cooling delay/rate, and
existing overheat behavior: explosion, knockdown, loss of flight, and
floor(30% of maximum health) damage. Overheating while charging discards the
stored projectile. Final breath damage is limited to the time remaining before
overheat. Fully cool and release the attack buttons before resuming.

Dragon Breath takes priority if Q and LMB are held together, canceling a stored
fireball. Release and press LMB again to begin another charge. Releasing aim,
switching powers, menus, focus loss, death, and input reset cancel the charge
and stream. Breath uses the existing damage interface for civilians, enemies,
and damageable objects, including lightweight civilian capsules. Each target
receives one hit per damage tick; cover blocks the stream and its side targets.
Burn status and persistent spreading fire are deferred.

Fireballs sweep their motion to prevent tunneling and exclude their shooter
from blast damage. As before, their radial impact explosion does not check
cover inside the blast radius. Blast visuals scale with radius; audio retains
the existing quieter Fire setting. The breath effect uses one animated cone,
100 particles, and a light, with bounded physics and crowd spatial queries.

All gameplay tuning is exported on PlayerFire in `scenes/player.tscn`.
The HUD shows charge percentage, a full-charge release prompt, and the current
rebindable Dragon Breath key. No external assets or addons were required.

## Files changed for these upgrades

- `scripts/player-scripts/player_fire.gd`: charging, release, breath and tuning.
- `scripts/player-scripts/player_laser_eyes.gd`: shared heat and cancellation.
- `scripts/player-scripts/player_abilities.gd`, `player_power_controller.gd`:
  first/second Fire upgrade unlocks from saved progression.
- `effects/fireball.gd`, `fireball_core.gdshader`: charged size and fiery core.
- `effects/dragon_breath.gd`, `dragon_breath.gdshader`: stream visuals and damage.
- `scripts/combat-scripts/explosion_controller.gd`: optional charged falloff.
- `scripts/npc-scripts/civilian_capsule_lod.gd`: capsule falloff and breath hits.
- `scripts/input_bindings.gd`, `scripts/player-scripts/player_input_snapshot.gd`,
  `project.godot`: Q/RT secondary power and Attack release capture.
- `scripts/ui-scripts/power_menu_progression.gd`, `gameplay_hud.gd`,
  `scenes/ui/gameplay_hud.tscn`, `localization/powers.json`: unlock UI and hints.
- `tests/test_fire_upgrades.gd`, `render_fire_upgrades.gd`: behavior and renders.
- Updated `tests/test_fire.gd`, `test_player_input_snapshot.gd`,
  `test_control_bindings.gd`, `test_powers_page.gd`; generated Godot UIDs.
- This document.

## Validation and playtest

The automated checks exercise tier gating, saved unlocks, tap/hold/release,
charge timing at different tick rates, heat beyond max charge, damage falloff,
multi-target breath and occlusion, civilian capsules, interruption, and flying
overheat. Existing Fire, Laser Eyes, selector, input, HUD, Powers UI,
civilian LOD, thrown-vehicle and explosion-audio checks are also run.
Rendered charge, projectile, impact and breath views in the test arena.
Full-city manual gameplay and sound balance still need a player check.

In Godot, buy Fire upgrades one and two and select Fire with Alt. Try a quick
RMB+LMB tap, a 1.5-second hold/release, and an extended hold. Aim at multiple
nearby damageable targets with RMB+Q, then place a wall between you and them.
Try both attacks in flight and fill Heat to confirm the existing fall/knockdown.
Open the selector during a charge to confirm it cancels without launching.
