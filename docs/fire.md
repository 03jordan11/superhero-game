# Fire powers

Purchase Fire and its three upgrades in the Powers menu, then select Fire
in the Alt wheel. Existing saves with these tiers purchased enable them
immediately. Burning status remains planned.

| Ability | Keyboard/mouse | Controller | Behavior |
| --- | --- | --- | --- |
| Fire core | Aim with RMB, tap LMB | LT + tap X | 40 damage, 3m blast, 20 Heat per shot |
| Charged Fireball | Aim, hold LMB, release LMB | LT + hold/release X | Full charge in 1.5 seconds; 80 center damage, 6m blast |
| Dragon Breath | Aim, hold Q | LT + hold RT | 20 damage/sec, 12m cone reaching 3m wide in radius |
| External Combustion | Without aiming, hold/release Q | Without aiming, hold/release RT | Vent 10–100 Heat for 10–70 damage in a 1–8m radius; 300s cooldown |

These use the rebindable Aim, Attack, and Power Special actions. The
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

Fireball/breath tuning is exported on PlayerFire; combustion tuning is exported on PlayerExternalCombustion in `scenes/player.tscn`.
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

## External Combustion (tier 3)

Select Fire in the Alt wheel. Q without Aim starts a stationary charge using the shared Heat bar, at 50 Heat per game second (two seconds from empty, one second from 50%). Ground and flying casts are supported; flight hovers. At 100% Heat the manual charge holds safely until a real Q release. Switching powers, input suppression, menus, focus loss and death cancel without firing or spending the cooldown. Remaining heat then cools normally. Hits cost health but cannot stun, interrupt or knock a charging hero out of flight; lethal damage still kills.

Release below 10 Heat does nothing. From 10 to 100 Heat, damage interpolates linearly from 10 to 70 and radius from 1 to 8 meters. Every successful blast empties Heat and starts the full 300-second cooldown. It affects living enemies within the spherical radius, including supers and nearby attack helicopters; it excludes the hero. NPC knockback uses the existing forced-knockdown flag; aircraft take damage without knockback. Like existing fireball blasts, this radial damage does not check cover. No burning status is applied yet.

When Fire is selected, tier 3 is unlocked and the cooldown is ready, reaching 100 Heat through aimed fire attacks automatically releases the full blast without self-damage or player knockdown. Manual charging suppresses this passive. During cooldown, or with another power selected, the original overheat explosion, 30% max-health cost and knockdown still apply. Both passive and manual releases share the same cooldown, shown in the plain-text cooldown area. The existing session cooldown owner (`Weather`) retains this value across travel, like the electrical powers; it is not saved to disk.

Presentation reuses the Thunderstorm spell animations, fireball shader for the charge glow, and the existing vehicle explosion scene/audio, scaled to the blast radius. The explosion requests 50% game/audio speed for its 1.4 game-second effect, with the shared helper's 0.1 real-second ease-in and 0.5 real-second ease-out. These values are Inspector tunables. Charging itself does not slow time. Pause/focus loss/scene teardown immediately clear slowdown for cleanup.

Validation: `tests/test_external_combustion.gd` covers tier/selection gates, threshold and interpolation, charging/holding, actual aimed-fire passive activation, cooldown overheat fallback, enemy/super knockback and aircraft damage without displacement, no self-damage, flight, damage armor/death, cancellation, HUD and scene cleanup. `tests/render_external_combustion.gd` runs real Q input and checks live game/audio easing; charge, blast and cooldown captures were inspected. Fire, counter, lightning and helper regressions also pass. Audio balance still needs a listening playtest.

Files for this upgrade: `scripts/player-scripts/player_external_combustion.gd` (new), `player_character.gd`, `player_laser_eyes.gd`, `player_damage_receiver.gd`, `player_anticipation.gd`, `player_lightning_strike.gd`; `scripts/slow_motion.gd`; `scripts/weather_controller.gd`; `scripts/encounter-scripts/helicopter-chase/attack_helicopter.gd`; `scripts/ui-scripts/gameplay_hud.gd`, `power_menu_progression.gd`; `scenes/player.tscn`, `scenes/ui/gameplay_hud.tscn`; `localization/powers.json`; combustion/slow-motion/lightning/counter/travel tests and related controls/shader/cooldown documentation.

Playtest: unlock Fire tier 3, hold Q from empty for two seconds, keep holding at full heat, then release near normal and super thugs. Repeat with partial heat for a smaller blast. Use Aim + Q to fill Heat and trigger the passive; repeat during cooldown to verify normal overheat. Charge in flight while taking gunfire. Check the cooldown text and smooth audio/time recovery, plus a counter dodge and a held Lightning Strike.
