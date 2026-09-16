# Hostile grabbing

## Controls to test

1. Face a melee thug or gunman within 2.5 m and tap **E**. The player lifts them by the throat with the right hand. The carried hostile's AI and collision are suspended. Supers have `can_grab = false`; ordinary civilians remain ineligible. Existing civilian rescue interactions retain priority.
2. Walk, sprint, or fly while holding them. Full flight speed remains available, including boost. The matching carried-victim clip follows the player throughout.
3. While grounded, click **LMB** for each slam: **20 / 20 / 60 damage**. The first two lift the victim again; the third releases them. One next slam can be buffered during the current animation. Holding LMB does not repeat slams. Airborne slams are disabled.
4. Hold **E** to charge a throw, then release. Full charge takes **1.2 seconds**, with a maximum **80 damage to the thrown hostile / 40 to the struck hostile**. Shorter charges scale damage. Damage and knockdown happen on the first physical collision; walls and ground damage the thrown hostile too. The initial grab does no damage.
5. **Tab** selects a throw target. Grabbing the current lock target automatically searches for another eligible enemy. At release the throw leads the selected target and compensates for gravity, then travels without homing. With no lock it follows camera aim. RMB still releases lock for free aim.
6. Tap **E** again for a harmless drop (hold less than 0.2 seconds). Knockout or death drops carried hostiles, vehicles, and rescue patients.

Try throws across a street and toward a wall, all three slams against a fresh thug, carrying during fast flight, and knockout while carrying. The automated checks use a controlled test area; city crowding and animation feel still need playtesting.

## Tuning and animation

`PlayerHostileGrab` on `scenes/player.tscn` exposes grab distance, facing cone, charge duration, throw speeds, maximum throw damage, and the three slam damage amounts. Eligibility is the `can_grab` export on `HostileBase`; it defaults to true and is disabled in `super_thug.tscn`.

`scripts/player-scripts/player_hostile_grab.gd` drives the Blender-authored `AuthoredCombo/Hero_*` and `GrabCombat/Victim_*` pairs. Both actors share a visual origin and facing while held, because victim pelvis motion already contains the attachment offset. Explicit sampling keeps both clips at the same time. Semantic release/impact times come from `assets/animations/authored-combo/grab_manifest.json`.

`scripts/npc-scripts/hostile_thrown_motion.gd` sweeps the restored hostile capsule until its first collision. It applies damage once, restores ordinary NPC processing, and never treats a timeout as an impact. Release placement checks the capsule against nearby geometry. Thrown-hit damage uses `DamageInfo.force_knockdown` so both surviving bodies are knocked down.

## Files changed for gameplay

- Added: `scripts/player-scripts/player_hostile_grab.gd`, `scripts/npc-scripts/hostile_thrown_motion.gd`, this guide, `tests/test_hostile_grab.gd`, and `tests/render_hostile_grab.gd`.
- Player integration: `scenes/player.tscn`, `player_character.gd`, `player_animation_controller.gd`, `player_combat_controller.gd`, `player_target_lock.gd`, `player_laser_eyes.gd`, and `player_damage_receiver.gd` under `scripts/player-scripts/`.
- Movement/interruption integration: `player_normal_movement_state.gd`, `player_flying_state.gd`, `player_wall_run_state.gd`, `player_ground_slam_state.gd`, `player_knocked_down_state.gd`, and `player_dead_state.gd` in the same folder.
- Hostile integration: `scripts/npc-scripts/hostile_base.gd`, `scripts/npc-scripts/npc_base.gd`, `scripts/combat-scripts/damage_info.gd`, and `scenes/npcs/super_thug.tscn`.
- Updated animation guide: `assets/animations/authored-combo/GRAB_ANIMATIONS.md`.

## Validation

`tests/test_hostile_grab.gd` exercises actual E/LMB handling, eligibility, target switching, runtime hand/throat alignment, 20/20/60 slams, recovery, full and partial charged collision damage, wall blocking, harmless drops, full-speed flying, and knockout/death cleanup.

`tests/render_hostile_grab.gd` renders the actual player and hostile using the gameplay controller. Captures are in `artifacts/grab_animations/Runtime_*.png`. Hold and slam alignment were visually inspected in Godot; these are staged runtime captures, not an interactive city playtest.

The grab integration test and eight regressions passed: target lock, opening punch dash, player damage, super knockback resistance, player knockdown, flight surge, original authored combo, and authored grab animations. The editor check found no GDScript parse errors. Existing user-directory, certificate-store and city MultiMesh diagnostics remain.

The older full rescue encounter test could not start because `hospital.tscn` lacks its expected `RescueDropOff` node. Direct rescue pickup priority, occupied-hands exclusion and shared drop behavior passed in the grab integration test; the hospital fixture was not changed here.
