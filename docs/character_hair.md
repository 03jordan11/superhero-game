# Character hairstyles

Female civilians randomly receive Long, Buns, or Buzzed Female, with blonde,
black, brown, or grey hair and matching eyebrows. Every hairstyle/color pair
is equally likely. The player has Simple Parted hair and a beard, both brown.
Hostiles currently use the male model and are unchanged.

Hair follows the existing Head bone through a BoneAttachment3D. The original
character meshes already include eyebrows. Materials are shared by source and
color, while the original imported materials remain unchanged. Distant crowd
capsules retain their selected style/color without loading an extra skeleton;
the same selection is restored when their full character returns.

## Assets

- `assets/characters/Superhero-male/Hairstyles`: Simple Parted and Beard glTF,
  binary data, and Godot import settings.
- `assets/characters/Superhero-female/Hairstyles`: Long, Buns, and Buzzed Female
  glTF, binary data, and Godot import settings.
- Textures are referenced from each character folder using relative paths.
  Female Buzzed needs Hair 1 textures; copies were placed in the female folder.
- Removed the original Hairstyles package after preserving these dependencies:
  unused FBX/rigged exports, separate duplicate eyebrow accessories, unused
  male Buzzed hairstyle, redundant texture copies, and their import settings.
  The five retained meshes have no skin/skeleton data.

## Code and scenes changed

- `scripts/character_hair.gd`: attachment, selection, and shared color variants.
- `scenes/player.tscn`, `scenes/npcs/civilian.tscn`: hair component wiring.
- `scripts/npc-scripts/civilian.gd`, `capsule_civilian.gd`,
  `civilian_capsule_lod.gd`, and `pedestrian_journey.gd`: appearance identity
  and preservation through crowd representation changes.
- `tests/test_character_hair.gd`, `tests/render_hairstyles.gd`: validation and
  repeatable visual previews (with generated Godot UIDs).

## Validation

Godot 4.7.2 import and asset dependency checks; tests for all 12 female choices,
head rotation, eyebrow tint, unchanged shared source materials, and player
accessories; existing civilian LOD handoff and Laser Eyes tests passed.
Rendered all three female styles in all four colors during walking animation,
and the player's hair/beard, then inspected the screenshots. The test harness
still reports sandbox user-settings/cache and certificate-store warnings.

In Godot, walk among civilians and check that hair follows walking/turning.
Move away and return to check that surviving NPCs retain their appearance.
Rotate the player camera to inspect Simple Parted and the beard, then fly or
jump to check attachment during traversal. No customization UI is added yet.

Hair fit can now be adjusted in `scenes/tests/hair_fitting.tscn`; see
`docs/hair_fitting.md`. Saved HairAdjustment transforms are used on the next
game run.

## Hair clipping at gameplay distance

Automatic mesh LOD generation is disabled in the five hairstyle `.gltf.import`
files. The simplified hair surfaces collapsed inside the scalp at normal
third-person distances, despite fitting correctly up close. Keep these small
accessories at their original detail (roughly 830–3,284 triangles each). Body
mesh LOD and distant civilian capsules still operate normally. This adds hair
triangles for visible full characters, without adding nodes, draw calls, or
skeletons. Saved fitting transforms are unchanged.

`test_character_hair.gd` checks the imported surfaces for unwanted LODs.
`render_hair_distance.gd` renders the actual animated player from the back and
front at several viewing distances; use it after changing hair imports.
