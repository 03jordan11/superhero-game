# Throat-grab animation preview

The Blender-authored animation library is now integrated with hostile grabbing, charged collision-based throws, grounded slams, carrying, `can_grab`, and drop-on-death/knockdown. The scene below remains an animation-only inspection tool. See [gameplay controls and tuning](../../../docs/hostile-grabbing.md).

## Inspect in Godot

Open `res://scenes/previews/grab_animation_preview.tscn` and press **F6** (Run Current Scene). Choose a pair from the dropdown. The normal-colored character is the player and the blue character is the held hostile.

- Space or the button pauses/resumes. Restart repeats a one-shot.
- The slider scrubs both actors together. Select 0.25x speed for close inspection.
- Drag right mouse to orbit; use the mouse wheel to zoom.
- Impact/grip/release times are shown under the slider.
- Throw release previews the release pose, without projectile travel; flight previews the carrying pose in place.

## Library and editable source

All **26 new clips** are in the same `hero_combo.glb` AnimationLibrary as `Hero_Cross`, `Hero_Hook`, and `Hero_FlyingUppercut`. The existing player already registers this as `AuthoredCombo`, so the new clips are available there without adding grab controls to gameplay. The three existing combat actions are retained from `source/hero_combo.blend`.

`source/hero_combat_grabs.blend` contains the original textured hero rig, a blue copy of the **same rig** for the victim, all 29 actions, studio lights and a review camera. It opens on the matched Hold pose. Choose the corresponding `Hero_…` and `Victim_…` actions on the two armatures to inspect another pair. No second skeleton or player-to-hostile retargeting was created. The existing Godot humanoid import mapping is retained for both.

`tools/build_grabs.py` authors and bakes the new clips in Blender at 60 fps. It uses the existing combat pose/IK authoring functions and samples the actual UAL1 Walk and Jog clips for carry locomotion. Flight follows the established hover/cruise/fast pose workflow. Rebuilding overwrites the generated source, library and rendered previews; save manual animation revisions separately before rebuilding.

Build order:

1. Blender `--background --python assets/animations/authored-combo/tools/build_grabs.py`.
2. Blender `--background --python assets/animations/authored-combo/tools/build_charge_punch.py` to append the three charged-punch clips (32 clips total).
3. Godot `--headless --path . --script assets/animations/authored-combo/tools/configure_grab_import.gd` to set loop imports from both manifests.
4. Reimport `hero_combo.glb` in Godot (or run the headless editor import).

The original `build_combo.py` rebuilds only the three original clips; run the build order above afterward to restore the combined library. The final editable 32-action source is `source/hero_charge_punch.blend`; the grab source still contains its original 29 actions.

## Matched actions

Each row has a `Hero_` and `Victim_` clip with identical duration. The victim's grip reaction, throat/wrist clutch, dangling kicks, flight trailing, slam impacts and release poses are authored separately from the player.

| Pair | Duration | Behavior / timing |
| --- | --- | --- |
| Grab | 0.60 s | Right hand reaches; grip at 0.20; lift completes at 0.60. |
| Hold | 2.40 s | Looped supported throat hold and uneven victim kicks. |
| CarryWalk | 1.33 s | Existing walking footwork; stable right holding arm. |
| CarryRun | 0.93 s | Existing jogging footwork; free left arm balances. |
| CarryFlightHover | 2.40 s | Upright flight with hanging victim. |
| CarryFlightMove | 2.00 s | Forward lean; victim starts trailing. |
| CarryFlightFast | 1.60 s | Horizontal full-speed player pose; victim trails alongside/above. |
| ThrowCharge | 0.60 s | Torso coils and draws the held enemy back. |
| ThrowHold | 1.60 s | Looped charged posture. |
| ThrowRelease | 0.70 s | Forward drive; release marker at 0.30. |
| Slam1 | 1.00 s | Ground impact at 0.36; retains grip and lifts back to Hold. |
| Slam2 | 1.00 s | Opposite torso twist; impact at 0.36; lifts back to Hold. |
| Slam3 | 1.20 s | Strong downward drive; impact/release at 0.44; victim remains down. |

Loop flags and semantic event times are in `grab_manifest.json` and Blender action markers. The grab gameplay controller consumes these times to apply damage and release the victim.

## Integration contract

The two visual actors share **one position and facing reference** while the paired animation plays. The player Root bone stays in place. Victim pelvis translations position the hanging body and its slam arc relative to that shared origin. **Do not also parent these already-offset victim clips to the hand**: that would apply the attachment offset twice. The preview demonstrates the correct setup. `PlayerHostileGrab` now implements this setup, collision suspension, and safe detachment into a thrown/knocked-down state.

The throw release clip ends at the release staging position; velocity/trajectory must move the victim after the release marker. First/second slams return to the holding pose; the final slam keeps the victim down while the player recovers. Flight clips support full-speed flying poses without changing gameplay speed.

Implemented gameplay: hostiles only, civilian rescues unchanged; right-hand throat hold; supers excluded through `can_grab`; E charge/release throw; collision-only damage up to 80 to the thrown hostile and half to the struck hostile; grounded 20/20/60 slams; carrying during full-speed flight; knockout/death drops carried objects/people. See [the gameplay guide](../../../docs/hostile-grabbing.md) for controls, tuning and test instructions.

## Validation and files

`tests/test_grab_animations.gd` checks all 29 imported clips, shared-rig tracks, durations, looping, finite poses, fixed actor roots, loop seams, paired throat contact and slam ground height. `tests/test_authored_combo.gd` continues checking the three original punches separately. `tests/render_grab_animations.gd` renders the imported pairs in Godot. Blender key-pose renders are under `artifacts/grab_animations/`.

Animation validation: grab animation checks, original combo regression and combat/wind audio regression passed. Imported slam pelvis heights are approximately 0.14–0.15 m at impact. Blender renders and Godot Hold/Fast Flight/Slam renders were inspected for alignment and body clearance. The gameplay integration adds actual-controller renders and `tests/test_hostile_grab.gd`; see the gameplay guide for coverage and remaining playtesting.

Animation assets added: Blender builder/source, manifest, import configuration helper, this guide, preview scene/script and grab validation/render tests. Updated: combined `hero_combo.glb`, its import loop settings, combo README and original combo test to allow the additional clips. Gameplay integration files are listed in the gameplay guide.
