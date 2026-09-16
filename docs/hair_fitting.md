# Hair fitting studio

Open `res://scenes/tests/hair_fitting.tscn` in Godot's 3D editor. Five labeled
stations show Simple Parted, Beard, Long, Buns, and Buzzed Female, each with the
matching fixed reference body. The scene has its own floor, lights, and camera.

1. In the LOCAL scene tree, expand `Models`, then the desired station.
2. Select **HairAdjustment**. Press **F** in the 3D viewport to frame it.
3. Move, rotate, or scale this node with the gizmos, or edit Inspector >
   Transform. Its pivot is near the head, so scaling does not lift the hair
   from the floor. Small adjustments are usually enough.
4. Inspect from the front, sides, and back using the editor camera.
5. Save this scene with **Ctrl+S**. Restart the game to use the saved fit.

Keep ReferenceBody and the imported HairMesh child unchanged. Do not change
HairAdjustment's metadata. Station positions only arrange the lineup and do
not affect in-game placement. Edit the Local scene, not the Remote tree while
playing: Remote edits disappear when Play stops. F6 runs a static overview;
the actual fitting work is done in the editor's 3D viewport.

Each HairAdjustment stores an editable transform and its original neutral
transform. CharacterHair reads their difference directly from the saved scene
once per game session and applies it before attaching hair to the Head bone.
NPC color/randomization and the existing animation attachment remain intact.
Saving a fit does not overwrite the source glTF models. There is no manual
coordinate copying or separate export step.

Changed files: `scenes/tests/hair_fitting.tscn`, `scripts/character_hair.gd`,
`tests/test_hair_fitting.gd`, `tests/render_hair_fitting.gd`, and this document.
