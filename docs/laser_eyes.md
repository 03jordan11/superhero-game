# Laser Eyes core ability

Unlock the core through Tab → Powers → Laser Eyes. All three upgrades remain
planned; there is no equipment-slot system yet.

- Hold right-click to aim, then hold left-click to fire. Aiming zooms the camera
  to 80% of its normal FOV and shows a small reticle. Releasing either button stops
  the beam. Without aiming, left-click retains punches and air slams. E no longer fires.
- Vehicle interaction defaults to E. Old saved R vehicle bindings migrate
  while unrelated custom bindings remain. Controls are rebindable. Controller
  defaults are LT to aim and X (Attack) to fire; vehicle interaction remains RB.
- The existing right-click accessibility preference now controls hold/toggle
  aiming. Firing remains hold-only. Pausing/rebinding/focus loss stops firing.
- Twin beams originate at the animated head and converge on the camera target.
  Eye-to-target obstruction checks prevent shooting through nearby cover.
- Fixed beam damage is 25 per second; maximum range is 180 world units.
  Physics targets supporting `apply_damage` and lightweight civilians are supported.
- Heat rises at 20 percentage points per second: five continuous seconds to
  overheat. Releasing starts a 0.75-second delay, then cooling removes 25 points
  per second. After overheat, cool to zero and release the fire button to rearm.
- Overheat stops the beam, triggers the existing explosion, and forces knockdown
  and gravity, including while flying. Self-damage is floor(maximum health × 0.3).
  The player is excluded from the separate 75-damage blast within six world units.
  Damaged vehicles can still trigger their existing secondary explosions.
- Ground hits leave black scorch trails. Marks fade and expire after 15 seconds,
  with at most 128 active retained marks. No downloaded images or new addons.
- Shared explosion playback was reduced again from -9 dB to -15 dB (another 6 dB, approximately half the signal amplitude).

Tuning values are exported on PlayerLaserEyes in the Player scene. No attribute
scaling or upgrade effects have been added.

## Validation and manual checks

Godot 4.7.2 editor import, laser mechanics, control bindings/migration, gameplay
HUD, Flight Surge, input snapshots, civilian damage lookup, powers page,
explosion audio, gameplay menu, Player scene, knockdown and localization checks
passed. Tests cover exact heat timing, damage, cover, animated beam origins,
scorch limits/expiry, area damage, floored self-damage and safe overheat recovery.

GPU rendering in a small test scene verified beams, reticle, Heat HUD, ground
trails and the reused explosion. Captures are under `artifacts/laser_*.png`.
This was automated testing and render inspection, not a manual city playtest.

In the game, unlock the core and hold right-click and left-click against a vehicle or enemy.
Release right-click while holding left-click to verify the beam stops. Sweep along a road and watch the scorch trail fade.
Overheat while flying near damageable objects: verify the explosion, health
cost, fall, cooldown and subsequent recovery. Confirm E still handles vehicles.

## Files changed for Laser Eyes

Added `scripts/player-scripts/player_laser_eyes.gd`, `effects/laser_scorch.gd`,
`effects/laser_scorch.gdshader`, `scripts/ui-scripts/laser_reticle.gd`,
`tests/test_laser_eyes.gd`, `tests/render_laser_eyes.gd`, their Godot UID files,
and this note.

Updated `project.godot`, `scenes/player.tscn`, `scenes/ui/gameplay_hud.tscn`,
`scripts/input_bindings.gd`, `scripts/player-scripts/player_character.gd`,
`scripts/player-scripts/player_input_snapshot.gd`,
`scripts/player-scripts/player_input_controller.gd`,
`scripts/player-scripts/player_power_controller.gd`,
`scripts/ui-scripts/power_menu_progression.gd`, `scripts/ui-scripts/gameplay_hud.gd`,
`scripts/ui-scripts/settings_menu.gd`, `localization/powers.json`,
`scripts/combat-scripts/explosion_controller.gd`,
`scripts/npc-scripts/civilian_capsule_lod.gd`, `effects/vehicle_explosion_effect.gd`,
`tests/test_control_bindings.gd`, `tests/test_player_input_snapshot.gd`, and
`tests/test_vehicle_explosion_audio.gd`.
