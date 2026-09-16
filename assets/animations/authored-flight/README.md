# Authored flight animation library

Three original Blender actions, authored on the armature imported from the existing `assets/characters/Superhero-male/Superhero_Male_FullBody.gltf`. The original mesh, skin weights and rest bones are retained in the editable source. No Mixamo motion is used.

| Action | Loop | Pose and selection |
| --- | --- | --- |
| Flight_Hover | 3.2 s | Upright floating, relaxed arms and slightly staggered legs; subtle breathing/bob. Selected while stationary. |
| Flight_Move | 2.8 s | Similar silhouette with an approximately 18-degree forward lean and arms slightly behind the torso. Selected during normal movement in any direction, including vertical movement. |
| Flight_Fast | 2.0 s | Approximately 80-degree body lean, hands beside hips, extended legs/toes and forward gaze. Selected during actual Shift boost or the existing Flight Surge. |

The editable Blender actions run at 60 FPS and now have **five full-body pose columns per clip**, including a matching closing pose. Automatic Bezier handles interpolate between them, with Cycles modifiers providing repeated motion and continuous endpoint slopes. The runtime GLB has now been refreshed from the user's hand-edited source, retaining all three actions and their original durations. Pelvis motion is limited to a small visual float; the root has no translation and gameplay physics still owns movement. Normal flight keeps the model upright relative to the horizon; fast flight aligns with travel direction. Flight animation transitions use the existing `flight_animation_blend_time` Inspector control (0.3 seconds).

## Edit and rebuild

- Open `source/hero_flight.blend` in Blender. It opens in the Animation workspace, with Armature in Pose Mode and pelvis selected. Choose one of the three named actions in the Action Editor. The original textured player, weights, skeleton and packed textures are retained.
- The Action Editor shows selected bones by default. Select a bone to edit its keys; disable **Only Show Selected** to see all bones. Every keyed channel shares the same five frame positions, so each column is an editable full-body pose, including fingers. Select a pose frame, adjust the desired bones, then insert Location & Rotation keys for those bones. Auto handles respond to your edits. This remains the original deform rig, without new IK controllers or addons.
- The untouched baked source is saved separately as `source/backups/hero_flight_baked.blend`; it does not clutter the working file's action list. Blender's Text Editor also contains **START HERE - Editable flight** instructions.
- `tools/build_flight.py` contains the original authored body, hand/foot targets and loop motion. It exports a sampled runtime library, then runs the sparse conversion before saving its editable Blender source. Rebuilding regenerates the baseline and overwrites manual revisions: save manual work separately and do not use this builder to export your hand edits.
- `tools/sparsify_flight.py` is the conversion and numerical comparison tool. It preserves the first baked backup and refuses to reduce an already-converted working file again. `source/flight_editability_report.json` records the comparison results.
- `hero_flight.glb` contains the rig and animations only. Godot imports it as an AnimationLibrary using the same humanoid bone map as the existing player and authored combat clips. Keep its `.import` settings. Godot ignores the editable `source` directory.
- The legacy `Flying.fbx` asset remains on disk, but the runtime no longer loads or renames its tracks. The player no longer uses `Swim_Idle` for hovering.

### Exporting your manual edits

Save `source/hero_flight.blend`, then run:

```text
blender --background --python assets/animations/authored-flight/tools/export_edited_flight.py
godot --headless --path . --editor --import
godot --headless --path . --script tests/test_authored_flight.gd
```

Use this export-only tool for manual revisions, **not `build_flight.py`**, which regenerates the original poses. The export-only tool reads the current .blend, samples its actual edited actions into the runtime GLB, and never saves over the source. It keeps existing Godot import/retarget settings. `edited_export_report.json` records source/export hashes, action durations and source loop gaps. The latest export preserved the source hash, all three closing poses matched, and independent comparison of all 483 exported frames against the source found a maximum joint-position difference of 0.022 mm (`edited_pose_audit.json`). Godot flight regression checks passed and current front/side pose renders were inspected.

### Sparse pose frames and playback

| Action | Neutral / roll left | Highest / inhale | Neutral / roll right | Lowest / exhale | Matching closing key |
| --- | ---: | ---: | ---: | ---: | ---: |
| Flight_Hover | 1 | 49 | 97 | 145 | 193 |
| Flight_Move | 1 | 43 | 85 | 127 | 169 |
| Flight_Fast | 1 | 31 | 61 | 91 | 121 |

Keep the first and closing poses identical when changing a loop. The action-specific frame ranges retain the closing keys and original durations. Blender's scene playback range does not automatically change when switching actions: set End to 192, 168 or 120 respectively to preview a loop without showing the duplicate closing frame twice. Keep the closing keys at 193, 169 and 121 for interpolation/export.

The conversion reduced 127,029 scalar keys to 3,945 (96.9% fewer), arranged in five pose columns per action instead of a column every frame. Bone heads, tails and rotations were compared to the baked source at quarter-frame intervals across all three loops (1,923 samples). The worst measured bone-endpoint difference was 0.732 mm and the worst rotation difference was 0.048 degrees. All weighted body, eye and eyebrow vertices were also compared at 33 points per clip, including in-between frames: the largest sampled surface difference was 0.759 mm. Endpoint positions match exactly; quaternion differences are below 0.000003 degrees, and endpoint curve slopes match within numerical precision.

At the initial sparse conversion, the saved file was reopened and independently rechecked against the baked backup. Rest bones, mesh/weight-group counts and FPS were unchanged, and the runtime GLB was left untouched at that stage. The later hand-edited source was exported using the separate workflow above. No other animation libraries were edited. The numerical reduction report describes the baseline conversion, not subsequent user pose edits.

## References and visual direction

[DC's Superman flight retrospective](https://www.dc.com/blog/2023/04/13/taking-flight-twelve-moments-that-defined-superman) and [Man of Steel's first-flight scene](https://www.youtube.com/watch?v=sQA199D8U2g) informed the restrained floating posture and strong airborne silhouette. The hands-at-sides fast pose follows the requested game direction. These are pose references, not copied animation data.

[Blender's glTF export documentation](https://docs.blender.org/manual/en/4.4/addons/import_export/scene_gltf2.html) describes exporting separate actions as an animation library. This asset was built with Blender 5.2.1 LTS and imported/tested in Godot 4.7.2.

## Validation and playtest

`tests/test_authored_flight.gd` checks all tracks against the actual player skeleton, finite poses, loop continuity, no root displacement, the fast-flight hand/body silhouette, and real player input selection (hover, forward/side/back/vertical movement, boost, locked boost and surge). Existing flying-state, Flight Surge, boost-recovery and authored-combo tests also pass. Godot front/side pose previews were rendered and inspected; see `artifacts/authored_flight/poses.png` and `side.png`.

In Play, unlock Flight and Flight Boost through the existing powers flow if needed. Fly with F and release movement to hover; move without Shift, then hold/release Shift while moving. Check side/back/vertical movement, turns, transitions, and returning to ground movement. Final animation feel during an extended city flight still needs a player playtest.

## Files changed

- Added this library's GLB/import settings, Blender source and build script.
- `scripts/player-scripts/player_animation_controller.gd`: replaces swimming/Mixamo flight with the three authored clips.
- `scripts/player-scripts/player_character.gd`: passes movement and actual boost/surge state to animation selection.
- `scripts/player-scripts/player_flying_state.gd`: exposes actual boost state and keeps normal flight upright.
- `scripts/npc-scripts/character_animation_library_loader.gd`: removes unused legacy flight loading/catalog entries.
- Added `tests/test_authored_flight.gd` and `tests/render_authored_flight.gd` plus Godot UID files.
- `tests/render_hair_distance.gd`: uses the replacement fast-flight clip for its existing preview.
