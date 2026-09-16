# Hostile enemies

Implemented enemies: `pistol_thug`, `rifle_thug`, `melee_thug`, and `super_thug`, all faction `mafia`. Source roster: [Enemy Types](https://docs.google.com/document/d/1cfkCKhJwSapSw3fEFDa8jyoB_PPJVikF-DL8INff5c0/edit?tab=t.0). Other roster entries remain unimplemented.

## Class ownership

- `NPCBase`: existing health, hit reactions, knockback, gravity and movement lifecycle, XP amount, and `died(npc)` signal. Death is now guarded against duplicate calls.
- `HostileBase`: identity, faction, aggression, detection, alerts, target, guard/combat/search state transitions, search movement, obstacle probes, diagnostics, and reward handling.
- `RangedHostile`: weapon resource, individual ammo/cooldowns, reload lifecycle, damage/accuracy resolution, and repositioning. Calls presentation hooks implemented by the weapon-specific subclass.
- `PistolHostile`: existing pistol animation and audio integration. Restarts an interrupted reload after the hit reaction without granting free ammo.
- `scenes/npcs/pistol_thug.tscn`: Mafia identity, model, animation controller, sounds, and stat/resource configuration. The existing placeholder character appearance is retained.

`scenes/npcs/hostile.tscn` inherits the canonical thug scene to preserve existing scene references and child node paths. The old `hostile.gd` script path also remains a compatibility subclass. Pistol diagnostic method/property aliases remain available.

## Tuning

Select the pistol thug root in the Inspector. Inherited exports include maximum health, XP (`experience_gain`), hit/knockback settings, faction, aggression, awareness, movement, magazine size, and shot pauses. Expand `weapon` to edit damage and accuracy, or assign another resource. The default is `resources/weapons/pistol_thug_weapon.tres`.

Defaults: 100 health, 10 XP, six rounds; damage falls from 5 to 2 between 10 and 30 meters; maximum hit distance 50 meters. Detection radius 17 meters, ally alert radius 25 meters, combat retention range 60 meters. Current health/ammo/timers belong to each NPC; weapon resources contain tuning only.

## Allegiance and combat

Only enemies with the same non-`none` faction share alerts. An NPC always accepts its own detection alert. Alerts cannot target an ally or a dead character. Disabling `aggressive_to_player` disables autonomous player detection, while allowing responses to allied alerts or damage; it is not a full diplomacy system.

Initial detection and search reacquisition require visibility. Accepted damage from a valid non-ally acquires that attacker and alerts nearby allies. Shots still require a collision ray that reaches the target. Existing range-based search and local obstacle avoidance are retained; this is not full city pathfinding.

Defeat awards the existing XP amount to the player once and emits the existing death signal once. The prior reward policy is preserved: a hostile death awards XP regardless of damage source. Faction combat/kill attribution can refine that policy when those systems are requested. Gang encounter completion rewards remain separate. The restored on-demand gang scene now scales its mixed roster and reward to hero level; see [encounter rules](encounters.md).

## Spawning and manual checks

Open the dev console with backtick (or its rebound control):

```text
spawn pistol_thug
spawn pistol_thug 5
spawn rifle_thug 5
spawn hostile 3
help spawn
```

Amounts default to one and accept 1â€“50. `hostile` is the compatibility alias. `civilian` also accepts an amount. Groups spread around the current player location and skip positions without ground within the probe range. Output reports actual/requested count. NPCs remain paused until the console closes.

1. On an open street, spawn one thug and close the console. Check detection, alert marker, pistol animation/sound, reload, and damage.
2. Spawn five and check individual positioning, ally alerts, and repositioning while you move, jump, and fly out of range.
3. Approach behind a wall: it should block initial detection and bullet damage. Move into view to initiate combat.
4. Hit a thug during a reload, then let it recover. It should restart the reload and resume firing.
5. Defeat one and check for 10 XP, once; subsequent hits should award nothing.
6. Try invalid counts (`0`, `-1`, `1.5`, `51`) and an unknown type: nothing should spawn.

## Automated validation

`tests/test_pistol_thug.gd` covers class/scene identity, balance, resource damage, visibility, faction/range filtering, independent health/ammo, damage retaliation, interrupted reloads with the real animation, death/reward idempotence, legacy scene compatibility, and encounter integration. `tests/test_developer_console.gd` covers batch spawning, validation, pause behavior, and console help alongside the existing console regressions. Existing pistol-hit and combat/audio tests exercise the compatibility paths.

`tests/test_combat_performance_monitor.gd` now creates its own five enemies because the main scene no longer contains a fixed hostile fixture. All five relevant test scripts passed in Godot 4.7.2 headless; the editor import found no GDScript parse errors. Test runs emitted environment certificate/settings warnings and shutdown resource warnings. The console test also deliberately exercises a failed save path.

These are headless checks; gameplay appearance and feel still require the manual checks above.


## Rifle and overhead-label update

The rifle scene inherits the pistol scene/presentation as a prototype variant. It uses the same model, shooting/reload clips, audio, health (100), XP (10), damage (2–5), accuracy, search and repositioning. Its magazine holds 30 rounds and `automatic_shot_interval` is 0.12 seconds. Automatic shots use a timer independent of animation completion; a frame hitch never causes several shots in a single update. Pistol interval remains zero, retaining the original animation-paced behavior. Actual sustained cadence also depends on frame time, reloads and repositioning.

`HostileBase` creates camera-facing bold labels with dark outlines, above health and below the alert marker. Defeated enemies hide their names. Inspector exports `nameplate_text`, `nameplate_kind`, and `nameplate_height` control them. `NameplateKind` and `NAMEPLATE_COLORS` reserve:

| Type | Text currently used | Color |
| --- | --- | --- |
| Pistol | Pistol | Green `#66e080` |
| Rifle | RIFLE | Dull yellow `#c5b458` |
| Melee | MELEE | Red `#e55d5d` |
| Super (reserved) | — | Orange `#ef9a42` |
| Sniper (reserved) | — | Blue `#639df5` |

Files changed in this update:

- `scripts/npc-scripts/ranged_hostile.gd`: optional automatic cadence and shared single-round firing.
- `scripts/npc-scripts/hostile_base.gd`: shared overhead labels and reserved palette.
- `scenes/npcs/pistol_thug.tscn`: Pistol text and raised alert marker to avoid overlap.
- Added `scenes/npcs/rifle_thug.tscn`: Mafia rifle configuration with 30-round magazine.
- Added `resources/ui/enemy_nameplate_bold.tres`: shared bold system font.
- `scripts/ui-scripts/developer_commands.gd`, `localization/powers.json`, `DEVELOPER_CONSOLE.md`: rifle spawn registration, completion, help and instructions.
- Added `tests/test_rifle_thug.gd` and `tests/render_enemy_nameplates.gd` (plus UIDs); extended `tests/test_developer_console.gd`.
- Updated this guide.

Validation: Godot import and four headless scripts passed (rifle, pistol, console, bullet-hit audio). With relocation disabled, the one-second test produced eight rifle shots versus two pistol shots; it also verified all 30 rounds, animation-driven reload completion, interruption, cross-type Mafia alerts, colors and label visibility. The actual enemy scenes were rendered with Godot and the labels inspected in `artifacts/enemy_nameplates.png`; names, health and alerts are separate and readable. Environment/settings and shutdown-resource warnings remain in some headless runs.

Playtest: spawn a pistol and rifle together, close the console, compare their labels and firing speeds, let the rifle exhaust its magazine and reload, and hit it during reload to check recovery. Movement/combat feel still needs in-game observation.


## Melee combos and debug appearance

`MeleeHostile` extends `HostileBase`, retaining health, XP, Mafia alerts, detection, reactions and search. It reuses the player's Punch_01/02/03 clips through `HostileAnimationController`. Each attack performs six punches (repeating the three existing clips twice), then yields its slot and recovers for 2.5 seconds. It faces the target between swings but commits its facing during each swing. Each impact checks range, height, facing arc and line of sight, dealing damage only once. Moving out of reach stops the remaining combo; hitting the thug interrupts it.

A `MeleeAttackCoordinator` on each target grants at most two approach/attack slots across encounters. Other thugs spread into surround positions and queue for their turn, skirting the inner attack area. Slots release on combo completion, damage interruption, death, removal, target change or approach timeout. Unreachable/airborne targets prevent new approaches. Movement uses existing local obstacle steering plus a ground-step check; complex city routes still need playtesting.

Melee Inspector defaults: 100 health, 10 XP, 10 damage per punch, 8.5 m/s approach, 2.2 m reach, 0.2-second impact delay, six punches, 2.5-second recovery, 9 m surround radius, 3.5 m/s surround speed, four-second approach timeout.

Names and mesh tints are independent debug settings. Both start enabled in debug builds and are disabled in release builds. Tints match the type palette: pistol green, rifle dull yellow, melee red (MELEE label), super orange and sniper blue. Per-enemy overlays preserve shared source materials; tint off restores original overlays. Switches affect existing enemies and later spawns and last only for the current session:

```text
spawn melee_thug 8
debug enemy_names off
debug enemy_tints off
debug enemy_names on
debug enemy_tints on
```

### Files changed for this update

- Added `scripts/npc-scripts/melee_hostile.gd` and `scenes/npcs/melee_thug.tscn`: melee behavior, tuning and Mafia configuration.
- Added `scripts/npc-scripts/melee_attack_coordinator.gd`: per-target cap and waiting queue.
- Updated `scripts/npc-scripts/hostile_animation_controller.gd`: shared player punch clips.
- Updated `scripts/npc-scripts/hostile_base.gd`: debug overlays/name visibility and overridable combat facing.
- Updated `scripts/ui-scripts/debug_manager.gd`: independent debug flags and live change signal.
- Updated `scripts/ui-scripts/developer_commands.gd`, `localization/powers.json`, and `DEVELOPER_CONSOLE.md`: spawning, toggles, completion and help.
- Added `tests/test_melee_thug.gd` and `tests/test_enemy_debug_visuals.gd`; extended `tests/test_developer_console.gd` and `tests/render_enemy_nameplates.gd`. New scripts include Godot UID sidecars.
- Updated this guide.

Validation: Godot editor import found no script parse errors. Melee, debug visuals, pistol, rifle, developer console and bullet-hit audio scripts passed. Melee tests cover two-/three-punch damage, dodging, wall occlusion, slot handoff, interruptions, removal, airborne targets, approach timeout, and eight enemies in live physics with the two-attacker cap checked each frame. Debug tests cover existing/new enemies, independent toggles, original material restoration and dead labels. Godot renders were inspected with debug visuals enabled (`artifacts/enemy_nameplates.png`) and disabled (`artifacts/enemy_debug_off.png`). These verify appearance, not interactive combat feel. Existing environment/settings and shutdown-resource warnings remain in some test runs.

Playtest: on an open street spawn eight melee thugs, then close the console. Watch two approach while others surround; stand still briefly to see six-punch combos and attackers take turns. Sidestep a swing, interrupt a combo, defeat one, then jump/fly away to check recovery and slot release. Add pistol and rifle thugs to compare colors. Toggle each debug flag separately, then spawn another enemy with both flags off to check it inherits the settings.


### Six-punch and corpse-collision adjustment

Updated `scripts/npc-scripts/melee_hostile.gd` for six punches, a 9 m surround radius and 2.5-second recovery; `hostile_animation_controller.gd` cycles the three clips for longer combos. `hostile_base.gd` disables hostile body shapes/layers on death while the death animation continues, so corpses cannot obstruct movement or become platforms. A ground ray lets airborne corpses fall and settle without restoring their capsules; settled bodies stop physics processing.

Extended `tests/test_melee_thug.gd` to cover six-punch completion and wider surround destinations; added `tests/test_hostile_death_collision.gd` (and UID) to verify horizontal movement and falling probes pass through corpses for all three hostile types, and airborne corpses settle on the floor. Both tests and the pistol regression passed. Updated this guide and `DEVELOPER_CONSOLE.md`.

Playtest: spawn eight melee thugs, wait for a full six-punch turn and watch the handoff/retreat. Confirm waiting enemies give more space. Defeat each enemy type, then walk and jump across the body; the standing capsule should no longer block or lift the player.


## Super thugs and stronger debug tints

`SuperHostile` inherits melee behavior, with a Mafia `super_thug` scene, orange SUPER label, 1.5x model scale, and a correspondingly larger capsule, obstacle probes and raised labels. Stats: 500 health, 40 damage per punch, 350 XP on defeat. Punch clips play at half speed with a 0.4-second impact delay; six-punch combos repeat with 0.8 seconds of recovery. Supers approach at 5 m/s, surround at 2.5 m/s and search at 3.5 m/s. Normal melee approach speed is reduced from 10 to 8.5 m/s, surround from 4 to 3.5 m/s, and search from 6 to 5 m/s. Values remain Inspector exports.

Supers join the same FIFO queue as normal melee. When a super reaches the front, it waits for both current normal melee turns to finish; later waiters cannot skip it. Its exclusive turn begins when it receives permission to approach. Only that super can approach/attack; other supers and normal melee stay in surround. Once active, it repeats combos without retreating or yielding until death. Damage still interrupts a swing but preserves the exclusive turn. Distance, cover and airborne targets also preserve the turn; supers hold when vertical separation prevents reaching the player. Death/despawn or an invalid/dead target clears the reservation, so the queue cannot retain an obsolete owner. Ranged enemies retain their existing behavior.

Debug mesh tint opacity is now 75 percent (previously 55 percent) for every hostile type. Existing independent name/tint toggles remain supported and are still debug-only.

Files changed: added `scripts/npc-scripts/super_hostile.gd` and `scenes/npcs/super_thug.tscn`; updated `melee_attack_coordinator.gd`, `melee_hostile.gd`, `hostile_animation_controller.gd`, and `hostile_base.gd` in `scripts/npc-scripts`, plus `scenes/npcs/melee_thug.tscn`. Updated `scripts/ui-scripts/developer_commands.gd`, `localization/powers.json`, `DEVELOPER_CONSOLE.md`, and this guide. Added `tests/test_super_thug.gd`; extended `test_developer_console.gd`, `test_enemy_debug_visuals.gd`, `test_hostile_death_collision.gd`, `test_combat_performance_monitor.gd`, and `render_enemy_nameplates.gd` in `tests`. New scripts include UID sidecars.

Validation: super, melee, debug visuals, death collision, console, rifle, and mixed combat-monitor tests passed. Super checks cover FIFO order, draining normal turns, exclusive approach/attack, repeat combos, slower playback and impact timing, 40 damage per swing, 350 XP once, hit interruptions, target distance/height, death/despawn/invalid-target cleanup, and live physics with one super attacking while five others wait. Godot rendering confirmed model size, label placement and stronger tints. Interactive combat feel remains a manual check. Existing environment/settings and some shutdown-resource warnings remain in test runs.

Playtest: run `spawn melee_thug 6` and `spawn super_thug 2`, then close the console. Check the larger orange model and slower movement. Observe normal melee finish their turns before a super enters, then remain outside while it repeatedly attacks. Interrupt the super, move out of reach, and return: it should keep its turn. Defeat it and verify 350 XP and the next queued enemy advancing. Confirm no corpse collision, and toggle names/tints independently.


### Super knockback resistance

`NPCBase` now exposes `knockback_resistant`, enabled only on `scenes/npcs/super_thug.tscn`. Knockback and ground-slam reactions become a standing chest-hit stagger for resistant NPCs. Full damage, lethal death handling and the super exclusive turn remain intact. The original damage payload is not modified, preserving knockback for other enemies hit by the same area attack.

Files: updated `scripts/npc-scripts/npc_base.gd`, `scenes/npcs/super_thug.tscn` and this guide; added `tests/test_super_knockback_resistance.gd` and its UID. The new test exercises the player third-punch hit query, full finisher damage, no knockback displacement/knockdown, standing reaction, shared ground-slam payloads, normal enemy knockback, the Inspector toggle, and lethal turn release. It and super/pistol regressions passed; Godot editor import found no script parse errors.

Playtest: spawn a super and land the full three-punch player combo. The third hit should damage and stagger it while it stays standing, then it should resume its exclusive turn. Normal melee thugs should still be knocked down by the finisher.


## Level-scaled gang encounters

Use `spawn gang_activity` to create a mixed Mafia group and a dev waypoint. See [encounter rules, architecture, validation and changed files](encounters.md). The old fixed `hostile_scene`/`hostile_count` configuration is replaced by tier-based roster generation. Individual thug stats and XP remain unchanged.
