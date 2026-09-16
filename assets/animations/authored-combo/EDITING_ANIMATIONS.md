# Editing the authored combat animations

The three source files now contain sparse editable actions with their original
reference meshes, skin weights, packed textures, rigs, action names and 60 FPS
timing. The flight source already received this treatment and was left alone.

| Open this file | Use it for | Total scalar keys before / after |
| --- | --- | --- |
| `source/hero_combo.blend` | Cross, hook and flying uppercut | 38,398 / 5,860 |
| `source/hero_combat_grabs.blend` | Matched hero/victim grab, carry, throw and slam actions; both bodies included | 593,328 / 40,205 |
| `source/hero_charge_punch.blend` | Charged punch windup, hold and release; also contains copies of the other combat actions | 635,145 / 43,048 |

There are **32 distinct actions** across these files. The later files include
copies of the earlier actions; edit the appropriate source in the table to avoid
maintaining conflicting versions of the same clip. The older imported
`assets/animations/blender/superher_animations.blend` was not part of this conversion.

## Edit a pose

1. Open the appropriate source. It opens in the Animation workspace, in Pose Mode,
   with the reference character and pelvis selected.
2. Choose the action in the Action Editor. Select the bones you want to change.
   **Only Show Selected** is enabled so unrelated bone keys stay hidden.
3. Scrub to a labeled action marker, adjust the pose, then insert Location &
   Rotation keys for the changed bones. Main poses are regular keys; extra
   breakdown keys retain arcs and fast movement between them.
4. Set the playback range for the selected action. Switching actions does not
   automatically change the scene range. Every action retains its explicit
   export range, and all ranges are listed in the Blender text block
   **START HERE - Editable combat**.

The key count varies by bone. Constant bones have two keys. Breathing/flight
holds need very few keys; rapid punches, victim kicks, and abrupt grip/release
transitions need more. Some short sections retain adjacent-frame keys where
removing them would noticeably change contact or fast rotations. The combined
summary of all bones can therefore still look busy; select a particular bone
to work with its reduced curves.

Transitions use **Bezier interpolation with fitted Aligned handles**. These
handles preserve the motion more closely than switching all curves to Automatic.
Move keys to change poses; adjust handles in the Graph Editor to reshape easing.
Short sharp transitions retain Linear interpolation. Do not bulk-convert the
fitted handles to Automatic unless you intend to change the motion.

Loops have matching first/last poses and tangents, plus Cycles modifiers. Keep
both endpoint poses and handle slopes matched when editing. To preview without
playing the duplicate endpoint twice, end playback one frame before the final
key; retain the final key in the action's export range.

For paired actions, select `Armature` and choose `Hero_…`, then select
`VictimPreview` and choose the corresponding `Victim_…` action. Both rigs must
stay at their shared origin; victim pelvis motion already includes the held
offset. The charge-punch file includes the hero body only; use the grab file
for paired editing.

## Preservation and validation

The game GLBs were **not re-exported**, and the user's edited flight `.blend`
and flight GLB are byte-for-byte unchanged. Original baked backups are in
`source/backups/*_baked.blend`; existing `.blend1` files were also left alone.

The conversion preserves the original keyed orientations and removes equivalent
quaternion sign flips that caused interpolation spins between some baked frames.
Quarter-frame motion comparisons use these equivalent, hemisphere-aligned
rotations; comparisons at the original integer frames also use the untouched
baked sources. Nearly all actions stay within 6 mm at bone endpoints and 0.85
degrees. CarryRun needed a slightly larger allowance (8 mm / 1.3 degrees) to
close an existing 4.7 mm seam and match its loop velocity. All sampled skin errors
remain below 8 mm. These are measured approximations, not a claim of identical
curves.

Reopening all three saved files verified the reference geometry, weights, rigs,
textures, action names, FPS, event frames and loop tangents. Paired hand-to-neck
offsets changed by at most 5.18 mm over quarter-frame samples. Source key-pose
renders were inspected. The existing Godot combo, grab-animation and charged-
punch tests passed; the game itself was not manually playtested for this source
editing change. Environment log/certificate warnings remain.

Conversion tooling and audit files:

- `tools/sparsify_combat.py` performs the source-only conversion and skips sources
  already marked editable, protecting later manual edits.
- `tools/validate_editable_combat.py` independently reopens sources, compares
  structure and paired contact, checks seams, and renders previews.
- `source/combat_editability_report.json` and `source/editability_hero_*.json`
  record per-action key counts, bone key counts, ranges and measured errors.
- `artifacts/combat_editability/source_validation.json` records the reopening
  audit; that folder also contains three source preview renders.

**Do not run the original `build_*.py` scripts after making manual edits.** They
regenerate animation poses and overwrite sources/exports. They are authoring
generators, not an export-only workflow. Save your changes in the `.blend` files
and export those edited actions when ready to update the game.
