# Hostile mesh pass / NPC test room

Open `res://scenes/NPCTestScene.tscn` and run the current scene with F6.
This room contains the three prepared hostiles and the exact starter-suit model
used by `scenes/player.tscn`, at its gameplay scale. All three hostiles
now have initial rigs and play animations alongside the hero. The brute is
uniformly enlarged to the approved 2.30 m height.

## First pass scope

Only the hands were remodeled: each has one rounded four-finger mitten and a
connected separate thumb. Skin and glove materials are matched to the original
hand colors. Existing wrist accessories and the rest of the models remain as
imported. No clothing seam repairs or body sculpting were added.

The prepared copies use a feet-at-zero origin and uniform human-scale sizing:

| Model | Height, including hair | Exported triangles |
| --- | ---: | ---: |
| Superhero reference | 1.813 m | Existing player asset |
| Bearded hostile | 1.80 m | 2,436 |
| Brute hostile | 2.30 m | 2,404 |
| Skinny hostile | 1.80 m, including mohawk | 2,351 |

Original GLBs and textures at the top of this folder are preserved. The scene
uses `prepared/thug_white_male_beard_rigged.glb`,
`prepared/thug_white_male_skinny_rigged.glb`, and
`prepared/thug_white_male_brute_rigged.glb`. Editable meshes with embedded textures are in
`source/*_mittens.blend`; the three editable rigs are in `source/*_rigged.blend`.
Blender source imports are disabled
by this project's existing configuration.

`tools/build_mitten_pass.py` rebuilds these three assets from their original
imports using Blender in background mode. It does not discover or modify other
new character imports. Regenerating overwrites the prepared GLBs and Blender
files, so preserve any later manual sculpt edits before running it again.

## Initial rig pass

`tools/rig_hostiles.py` builds the three hostile rigs from their
prepared mitten meshes. It fits the existing 65-bone gameplay humanoid skeleton
to each character (including the brute's height and broader torso), transfers weights from a fitted donor, then assigns coherent
head, waist, mitten, and thumb weights. It preserves target vertex positions,
topology, UVs, materials, and height. Weights are normalized, limited to four
influences per vertex, and shared across duplicate seam vertices.

The new GLB import settings use the same Godot humanoid BoneMap as the hero.
These are initial skin weights for visual review, not final deformation approval.
Regenerating overwrites the rigged GLBs and Blender rig files. Append
`-- brute` to the Blender command to rebuild just the brute; `-- beard` and
`-- skinny` similarly limit the rebuild to one model.

## Inspection controls

- Right mouse drag: orbit. Middle mouse drag: pan. Wheel: zoom.
- Dropdown or 1–8: select a character. 0 or R: overview.
- Hero + hostiles / Civilian lineup: frame the corresponding group.
- Front / Back: view the selected area from either side.
- Hands close-up: inspect the selected character's hand; orbit to inspect its
  volume and thumb. Pan or orbit to inspect the opposite hand.
- Cyan guide: hero height. Gray guides: 0.5 m intervals.
- Animation dropdown: existing general, action, and fighting clips; Rest pose
  returns to the mesh inspection pose. Playback begins with Idle.
- Space or Play/Pause: toggle playback. Restart: return to the clip start.
- Speed: 0.1×, 0.25×, 0.5×, 1×, or 2×. Slider: pause and scrub the clip.
- The hero and all three rigged hostiles stay synchronized, including while
  focusing an individual character.
- Hands close-up follows the animated hand bone. Middle mouse pan releases
  that tracking so the camera can inspect another area.

The room has `Reference`, `Hostiles`, and `Friendlies` groups. `Friendlies`
contains the four rigged civilian previews. To add an approved model later,
add a Node3D holder under the
appropriate group with a `Model` child, optional `Label`, and `display_name`
metadata. The picker registers these holders automatically. Optional Vector3
`hand_focus` metadata defines a hand close-up point in holder-local space.

## Encounter integration

- Pistol and rifle thugs use the skinny rig (including the legacy hostile alias).
- Melee thugs use the bearded rig.
- Super thugs use the brute rig at its authored 2.3 m height, with a matching
  2.3 m collision capsule and no extra model scale multiplier.
- Enemy body debug tints are off by default, revealing the authored materials.
  The existing optional developer tint command and overhead names still work.

The visual root keeps its existing `Superhero_Male_FullBody` node name so the
gameplay animation controller and player grab paths continue to resolve.
SuperThug now instances NPCBase directly to supply its own model; its
SuperHostile script still inherits melee behavior, and its combat tuning is
preserved. The gang and pirate encounter spawners already reference these
hostile scenes and therefore receive the new models without spawner changes.

A focused headless check loaded all four enemy types, verified their models and
the brute's height, played idle/movement/attack animations, and checked the tint
default: PASS. The encounter scene was not run or visually reviewed for this
integration; that review is left to the user.

## Validation

- Rig pass: one brief Godot 4.7.2 scene smoke check, including Idle, Walk, and
  Punch_01, scrubbing and playback resume: PASS. Forward+ snapshots confirmed
  the rigged models receive animated poses. Detailed animation quality is
  left for user review. No broader gameplay suite was run.
- Existing mesh-pass validation (performed before rigging):
- Imported heights, feet alignment, actor selection, hand zoom, back view, and
  reset are checked by that test.
- Forward+ overview, character views, and hand views were rendered and inspected.
- Reimported exported GLBs: both hands have no open/nonmanifold edges,
  inconsistent adjacent face winding, or zero-area faces after accounting for
  UV/material seam vertex duplication.
- Non-hand triangles retain original positions (within 0.000001 source units)
  and UVs. Normal round-trip differences are below one degree.
- Detailed inspection artifacts are in `artifacts/hostile_mesh_audit/`.

Run the scene test with Godot `--headless --path . --script
res://tests/test_npc_test_scene.gd`. To capture rendered views, omit `--headless`
and append `-- --capture`.

Other pre-existing mesh concerns, including clothing/accessory open edges and
the bearded mesh's degenerate face, require approval before a future cleanup.
