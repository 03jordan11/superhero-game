# Frost Breath

Purchase Frost and its tier-1 Frost Breath upgrade, select Frost in the Alt wheel, then hold Aim + Attack (RMB + LMB; controller LT + X). Tier 2 adds [Frost Wall](frost_wall.md) on Aim + Q/RT. The core fist ability, Frost Armor, Frost Trails and fire extinguishing are not implemented. Helicopters take breath damage but never slow or freeze.

The cone uses `PlayerFire.breath_range` and `breath_end_radius` directly (12m and 3m), so changes to Dragon Breath's cone also update Frost Breath. World geometry blocks contact; enemies in the cone do not shield others behind them. Living, ungrabbed, unthrown hostile NPCs build frost; helicopters take only 5 damage/sec. Frost builds shared Heat at 15/sec with normal overheat. Release Aim or Attack, switch powers, open menus, lose focus or die to stop breathing. Flight uses the existing aimed-power behavior.

Unfrozen enemies take 5 damage per game second without continuous hit flinches. Movement, attack timers and animation speed progressively decrease together, reaching 15% speed just before freezing. Regular enemies freeze after 3 seconds of exposure; supers require 5. Outside the cone, buildup wears off at one second of accumulated exposure per game second, smoothly restoring speed. These timings, damage values and the minimum movement/animation multiplier are exported on `Player/PlayerFrost`.

Frozen enemies are immobile with animation paused and a translucent, procedurally frosted ice block around them. The state deals 10 damage at each whole second for five seconds (50 total), then automatically breaks. Continued breath refreshes the five-second expiry without resetting damage ticks or melee hits, and adds no breath damage. The third player melee hit breaks the ice immediately; punches, uppercuts, charged punches and counters are marked as melee. Other damage still costs health but does not count or flinch a frozen enemy. A valid grab immediately breaks the ice. Early break cancels remaining status damage. Death restores animation playback for the death pose.

Frost and Electrified replace one another to avoid competing animation freezes. Existing shock damage ticks are canceled when frost contact starts; incoming Reactive Shock clears frost buildup/freeze before taking ownership. Neither status can restore a zero animation speed left by the other.

Both new shader resources are listed in `docs/shaders.md`. Player loading creates hidden breath and ice meshes/materials; this is preparation, not a guarantee that every GPU pipeline is compiled ahead of first use. No external assets or addons were added.

## Validation and playtest

`tests/test_frost.gd` covers tier gating, Aim + Attack and reserved Q, heat, cone/cover, gradual thaw, normal/super freeze thresholds, five damage ticks, refresh semantics, melee-only breaks through actual player punches, actual grab release, movement velocity and attack-timer slowdown, status replacement and death cleanup. The graphical `tests/render_frost.gd` exercises real mouse input and captures breath, ice, cracked ice and release. Images were inspected in Combat Arena. Other combat/power regression checks run alongside these tests.

In Godot, unlock Frost tier 1 and select it. Hold RMB + LMB over melee, pistol, rifle and super thugs. Compare their slowing and freeze timing, step the cone away to watch buildup recover, and stop breathing after a freeze to check the five-second thaw. Punch a frozen target three times or grab it. Continue breathing to refresh a freeze and check normal overheat. Place cover between the hero and an enemy to verify it blocks frost.

## Modified files

- New `scripts/player-scripts/player_frost.gd`, `scripts/npc-scripts/hostile_frost.gd`, `effects/frost_breath.gd`, `effects/frost_breath.gdshader`, `effects/frozen_ice.gd`, `effects/frozen_ice.gdshader` and generated UIDs.
- `scripts/player-scripts/player_laser_eyes.gd`, `player_power_controller.gd`, `player_combat_controller.gd`, `player_hostile_grab.gd`: input/heat, tier gating, melee tagging and grab release.
- `scripts/npc-scripts/npc_base.gd`, `hostile_base.gd`, `hostile_electrified.gd`: local action speed and status lifecycle.
- `scripts/ui-scripts/gameplay_hud.gd`, `power_selector.gd`, `power_menu_progression.gd`, `localization/powers.json`, `scenes/player.tscn`: Frost presentation and component.
- `tests/test_frost.gd`, `tests/render_frost.gd`, `tests/test_power_selector.gd`, `tests/test_powers_localization.gd`; this document, controls and shader inventory.

Heat tuning: Frost Breath now adds 15 Heat/sec, so freezing a super from an empty meter uses 75 Heat instead of reaching overheat. Changed `scripts/player-scripts/player_frost.gd`, its tests/render timing, and the power/controls text.
