# Meshy gameplay player

`hero_meshy.glb` is the underwear costume, built from the approved Meshy mesh. Civilian NPCs now use the four rigged models documented in `../Civilians/README.md`. The player now wears `../hero_starter_suit/hero_starter_suit_rigged.glb`. The underwear asset includes the reference-inspired texture, short-fro hair, rigid chin and flattened chest. Its build input is retained at `source/meshy_reference_fro.glb`; the editable rigged version is `source/hero_meshy.blend`. Retired character experiments and the old MeshTest lineup were removed during the costume-library cleanup. Both retained outfits are displayed in `scenes/hero_costumes.tscn`.

The mesh is fitted to the existing player's T-pose, joint locations, floor height and approximately 1.81 m display height. It retains **1,552 triangles**, its original UV layout, and all three original embedded texture images byte-for-byte. No subdivision, remeshing, or additional rendered geometry was introduced. The anatomical fit straightens the arm/hand axes and leg stance to place the mesh joints over the existing skeleton.

The original **65-bone armature**, hierarchy and rest transforms are retained. Godot uses the same humanoid BoneMap and `Armature/GeneralSkeleton` animation target as the previous character. The current movement, flight, combat, hit, death and grab animation libraries/controller continue to drive the player. No animation clips are duplicated in the GLB.

Skin weights are transferred from the original body, then normalized to at most four influences per vertex. Head/hair vertices follow the Head bone, with a blended neck transition. The connected finger block bends coherently at the middle finger's first knuckle; thumbs blend into the existing thumb chain. All finger bones remain for animation compatibility, but there is no independent four-finger articulation. At this triangle count, deep knee/elbow bends and hands remain visibly angular at close range.

The player's `CharacterHair` node is retained with `enabled = false`: hair and beard are already in this mesh. Separate legacy hair accessories remain enabled by default for other models/NPCs. Player collision, movement tuning, controls, node paths and animation controller are unchanged.

## Chin and chest cleanup

The entire lower face, chin and beard now follow Head rigidly. The neck-to-head weight transition sits below the chin, between 1.50 and 1.54 m, preventing the jaw from stretching when animations rotate the neck and head differently. The chin still moves with the head naturally.

Ten unique chest vertices were retracted in depth by up to 3.33 cm to flatten the pointed pectoral areas. Their width and height, skin weights, UVs and triangle connectivity are unchanged. The exported mesh remains at 1,552 triangles, with no flipped or degenerate faces and all original textures preserved.

For this revision, the independent GLB audit and Godot rig regression passed, including explicit rigid-chin and chest-depth checks. Godot rendered close-ups of the chin during idle, sprint, jump charge and hover, plus a side view of the chest, were inspected. Revision files: the runtime GLB, editable Blender source, `rig_audit.json`, build/audit/render tools, `tests/test_hero_meshy.gd`, and this README.

## Costume consistency cleanup

The lip ridge is now flatter: five unique vertices retract by up to 4.1 mm, preserving mouth width/height, the rigid head weights and original triangle connectivity. A local warm lip tint uses vertex colors to reduce the generated pale band; the existing texture images remain byte-identical. `tools/costume_shapes.py` applies the repeatable edit, and `tools/import_lip_colors.gd` enables the vertex tint on import. Keep that script configured in the GLB's `.import` file. Both mitten hands remain the shape reference for the starter suit. The runtime GLB and editable Blender source include the lip revision.

## Files

- `hero_meshy.glb` and `.import`: runtime skinned mesh, textures, unchanged player skeleton and BoneMap. Automatic mesh LOD generation is disabled to preserve the already sparse hair/hand silhouette.
- `source/hero_meshy.blend`: editable mesh, skin weights, packed images and original armature. The source directory is excluded from Godot import.
- `hero_meshy_Image_*`: Godot-extracted copies of the embedded base-color, normal and metallic/roughness images.
- `rig_audit.json`: exported geometry, normalized weights, UV seam consistency, source/texture hashes and retained bone count.
- `tools/build_meshy_rig.py`: reproducible Blender fit, skinning and export.
- `tools/audit_meshy_rig.py`: independent exported-buffer audit.
- `tools/render_rig.gd`: actual Godot pose, hand/chin close-up and chest profile captures under `artifacts/hero_meshy/`.
- `scenes/previews/meshy_rig_preview.tscn` and `scripts/previews/meshy_rig_preview.gd`: isolated animation review using the real player scene and its existing controller/libraries.

Integration edits: `scenes/player.tscn`, `scripts/character_hair.gd`, `tests/test_character_hair.gd`. Added regression coverage: `tests/test_hero_meshy.gd`.

## Review in Godot

Restart the running game with **F5** to use the new player. Check walking, sprinting, charged jumping/landing, hover/forward flight, punching and grabbing/vehicle pickup with the existing controls.

For a closer look, open `scenes/previews/meshy_rig_preview.tscn` and press **F6**. Choose an animation, use quarter speed or the scrubber, press Space to pause, right-drag to orbit, and scroll to zoom. R resets the view. The preview freezes gameplay movement while manually advancing the real player's animations.

## Validation

- Independent GLB audit: 1,552 triangles, 65 joints, no degenerate triangles, normalized four-influence weights, matching weights across duplicate seam vertices, original UV coordinates and all three texture images preserved.
- `tests/test_hero_meshy.gd`: actual player integration, original bone hierarchy/rest transforms, animation target paths and matching bone poses at four timestamps in 14 clips.
- Existing tests passed: `test_character_hair`, `test_player_scene` (including Main), `test_player_pickup_binding`, `test_laser_eyes`, and `test_hostile_grab`.
- Godot 4.7.2 rendered poses were inspected for idle, sprint, crouch/jump charge, takeoff, landing, flight, punching and hold/grab, with additional hand close-ups. This was animation/scene validation; a manual city traversal session was not performed.
- The sandbox emitted certificate, settings and shader-cache warnings; loading, tests and rendering completed.

Rebuild with Blender `--background --factory-startup --python assets/characters/hero_meshy/tools/build_meshy_rig.py`, run `tools/audit_meshy_rig.py` with Python, then run Godot `--headless --path . --editor --import` while retaining the supplied `.import` BoneMap. Run `--headless --path . --script tests/test_hero_meshy.gd` for the rig regression check.
