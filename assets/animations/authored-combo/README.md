# Blender-authored superhero combo

The three authored combat source files now use sparse editable keys. See
[Editing animations](EDITING_ANIMATIONS.md) for which file to open, pose editing,
paired-character setup, loop handling, backups, and validation results.

## Grab animation extension

The library now also contains **26 matched grab/carry/throw/slam clips**, authored in Blender on the same rig. See [GRAB_ANIMATIONS.md](GRAB_ANIMATIONS.md) for the preview scene, clip list, source file and paired-actor integration contract. Run `scenes/previews/grab_animation_preview.tscn` with F6 to review them. Grab gameplay is not wired up yet. The original three-punch documentation below remains applicable to the punch subset.

Three new actions made on the player's original male superhero armature in Blender 5.2.1. The player uses the original combo by default; the authored set remains available through **Use Authored Combo**. The existing `Punch_01`, `Punch_02`, and `Punch_03` actions and both original animation source files are untouched.

## Try it / compare

1. Run the game and start on the ground. Tap left mouse to punch; tap again during recovery to queue the next punch, then again for the flying uppercut. The existing controller binding is X.
2. Check a single punch returning to idle, the complete right-cross / left-hook / right-uppercut sequence, and the uppercut returning to normal landing/movement.
3. In `scenes/player.tscn`, select **PlayerAnimationController**. Toggle **Use Authored Combo** off for the originals; on for the new set. You can also change this on the running player's Remote Inspector between combos. The next punch uses the selected set.
4. **Authored Combo Blend Time** controls the transition into the new clips (default 0.06 seconds). Original clips retain their existing blend setting.

## Files

| File | Purpose |
| --- | --- |
| `source/hero_combo.blend` | Editable, packed-texture hero, three named actions, camera and studio lights. Select Armature and choose an action in Blender's Action Editor. |
| `source/.gdignore` | Keeps the editable Blender source from being imported a second time by Godot. |
| `hero_combo.glb` | Animation-only armature export; imported as one Godot AnimationLibrary, approximately 193 KiB. |
| `hero_combo.glb.import` | Same humanoid bone mapping as the player, baked at 60 fps; retains constant finger/guard channels. |
| `tools/build_combo.py` | Reproducible Blender authoring, baking, export and render script. Keyed hand/foot targets and torso timing are near the top. |
| `../../../scripts/player-scripts/player_animation_controller.gd` | Registers the separate `AuthoredCombo` library and selects new/original clips. |
| `../../../tests/test_authored_combo.gd` | Import, skeleton, pose, comparison, combo sequencing and launch regression checks. |

Run the build script **from the project root** with `blender --background --python assets/animations/authored-combo/tools/build_combo.py`. It rebuilds only the three original clips. Follow the complete build order in [GRAB_ANIMATIONS.md](GRAB_ANIMATIONS.md) afterward to restore the grab and charged-punch clips before reimporting. The current combined library contains 32 clips; see [charged-punch controls and tuning](../../../docs/charged-punch.md).

## Animation design

| Clip | Duration | Action |
| --- | --- | --- |
| `Hero_Cross` | 0.700 s | Rear-hand right cross: weight loads back, hips turn ahead of the shoulders, fist extends at 0.20 s, torso follows through, hand retracts to guard. |
| `Hero_Hook` | 0.767 s | Wide left hook: opposite-side coil, bent elbow and horizontal fist arc, strong torso rotation, foot pivot and controlled recovery. |
| `Hero_FlyingUppercut` | 0.917 s | Deep knee/hip compression, right fist drives up through 0.20–0.30 s, leg extension into the existing 0.25 s launch, opposite knee tucks, raised fist holds briefly before airborne recovery. |

Root motion stays with `PlayerCombatController`; the clips contain local pelvis compression and limb movement. Existing damage, launch velocity, lunge, sounds and controls are unchanged. The airborne trajectory is provided by the game, so scrubbing the Blender uppercut alone shows the pose/tuck without the full jump trajectory.

The anatomy reference is Dinu & Louis (2020), [Biomechanical Analysis of the Cross, Hook, and Uppercut in Junior vs. Elite Boxers](https://www.frontiersin.org/journals/sports-and-active-living/articles/10.3389/fspor.2020.598861/full). It informed pelvis-to-trunk-to-arm coordination, the cross's forward extension, and rotational hook/uppercut mechanics. The large anticipation, follow-through, and airborne finisher are deliberate superhero exaggerations, not a recreation of a measured boxing performance.

## Validation

- Godot 4.7.2 imported exactly three non-looping clips with all tracks resolving to the player's `GeneralSkeleton` and mapped bones.
- `tests/test_authored_combo.gd`: PASS, including original/new selection, all three combo steps, forward-reaching fists, fist above head in the uppercut, no root translation, launch and action unlock.
- `tests/test_player_combat_controller.gd`: PASS.
- `tests/test_combat_and_wind_audio.gd`: PASS.
- Rendered and inspected Blender key poses and Godot runtime sequence frames. The actual PlayerCharacter completed the combo, launched to approximately 4.10 m body-center height from a 1.0 m standing body-center height, landed, and released the action lock.
- `artifacts/authored_combo/combo_preview.gif` and `runtime_contact_sheet.jpg` show the rendered Godot run on a simple test floor, using a review camera. These are not captures of a manual combat encounter in the city.
- No new GDScript parse errors. Full editor import still reports existing city resource UID / MultiMesh errors. This restricted environment also reports unavailable user settings, shader-cache writes and certificate-store access; those did not prevent the isolated combo tests or rendering.
