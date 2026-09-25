# Anticipation counter

Unlock Preservation and its first upgrade, Anticipation. The existing `mind` save ID is retained; no new save migration is needed.

Only the opening punch of a melee combo offers a counter opportunity. A red exclamation mark above the hero appears during the last 0.35 seconds before impact. Regular thugs gain a brief idle anticipation before their punch animation; the existing animation-to-impact timing is preserved. Super thugs retain their longer punch windup. Later combo punches and gunfire never display this warning.

Press **Left Ctrl down** (default Dodge binding) during the warning to duck in place. It works while standing still and can cancel an ordinary punch. Holding the key, keyboard repeats, or pressing before the window does not trigger it later. Right Ctrl does not trigger the counter evade. Remapped Dodge controls and controller B use the same press-only behavior. Outside the warning, the existing moving dodge roll remains available.

The duck costs 10% maximum stamina. It cannot begin during flight, wall running, ground slam, charge attacks/jumps/flight, carrying/grabs, ship interactions, death, or knockdown. The opening attack must actually reach its normal range, arc, and line-of-sight checks before the evade is successful.

On success, the world and hero animation slow to 40% speed for 0.5 real seconds. Press Attack within 0.5 real seconds to counter the original attacker. A fresh press during the duck can be buffered; holding Attack beforehand is not enough. Counter damage is twice a normal punch, including effective Strength. Normal thugs receive their existing knockdown reaction; resistant super thugs receive their existing hit stagger and interrupted combo. Counter hits respect range and walls, cannot repeat within one action, and do not use the opening punch dash.

The entire active sequence—duck, counter input window, counter swing, and recovery—ignores incoming hits of every damage type. Ignored hits cannot cost HP, cause flinches/knockdown/slowdown, reset health regeneration, or interrupt the counter. Protection ends immediately when the action completes, expires, or is canceled; a lingering slow-motion effect alone grants no protection. Only melee combo openings can initiate the evade. Counter input timing runs in real time during slow motion; counter impact and recovery follow the slowed animation clock. Defeating the target or finishing the counter opportunity does not truncate the slow-motion duration. Pausing cancels the opportunity and restores time; death, respawn, and scene removal also clean up. Slow motion uses the shared `SlowMotion` autoload to change world simulation, animation timing, and global audio playback by the same amount. All sounds run at 40% speed during the default counter slowdown; the helper restores both speeds together. See [helper API](slow_motion.md).

Placeholder animation clips: UAL1 `Crouch_Idle` for the duck, UAL2 `Melee_Hook` and `Melee_Hook_Rec` for the counter/recovery. The warning follows the hero without rotating the camera. Visuals and timing can be replaced later.

## Tuning and testing

Inspector: `Player/PlayerAnticipation`. Exposed values include warning/counter windows, stamina fraction, damage multiplier, range, impact/recovery timing, and slow-motion strength/duration. Hit protection follows the active action instead of a separate timer.

In Combat Arena, unlock Anticipation, spawn a melee thug, and stand still. Tap Left Ctrl on the red warning, then Attack. Repeat with a super thug. Check the difference between knockdown and stagger, try holding Ctrl before the warning, and miss the opening and inspect later punches. Add a pistol/rifle thug: gunfire should neither damage nor flinch you during the duck, counter input window, swing, or recovery, then should hurt normally once the action ends. Test both attacking and letting the counter opportunity expire, plus pause/reset/travel during slow motion.

Automated coverage in `tests/test_player_anticipation.gd` includes unlock gating, press/hold/repeat/right-Ctrl handling, live engine input and physics, measured animation speed during slow motion, synchronized impact timing, normal-punch cancellation, stamina, damage, normal/super reactions, multiple attackers, canceled swings, range, gunfire, pause, real-time expiry, target death, and scene teardown. Use `--render` with a graphical Godot run to capture warning/duck/counter frames in `artifacts/anticipation_*.png`.

Validation: Anticipation (headless and graphical), dodge roll, melee thug, super thug, health regeneration, and arena round-trip checks passed. Warning, duck, and hook frames were inspected from a graphical run. Editor import completed without GDScript parse errors; existing environment/UID and shutdown resource warnings remain. Hands-on timing/animation feel still needs playtesting.

Slow-motion follow-up: removed the hero animation's inverse-speed compensation and increased the default duration from 0.25 to 0.5 real seconds so the effect reads clearly. Counter impact/recovery now follow scaled time, and target death no longer ends the effect early. Headless runtime measurement advanced the hero animation by 0.074 seconds over 0.179 real seconds (approximately 40% speed). Updated Anticipation tests, dodge roll, arena travel, and editor import passed; the revised effect still needs hands-on feel testing.

Files for this feature:

- Added `scripts/player-scripts/player_anticipation.gd` and `tests/test_player_anticipation.gd` plus generated UIDs.
- Updated `scenes/player.tscn`, `scripts/player-scripts/player_character.gd`, `player_damage_receiver.gd`, and `player_stamina.gd` for integration.
- Updated `scripts/npc-scripts/melee_hostile.gd` for opening-windup timing and evade resolution.
- Updated `scripts/ui-scripts/power_menu_progression.gd` and `localization/powers.json` for the implemented upgrade.
- Updated `tests/test_combat_arena_travel.gd` to capture the actual entry pose per trip, allowing normal floor settling between trips.
