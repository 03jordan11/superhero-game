# Civilian rigs

All four civilians are rigged in `res://scenes/NPCTestScene.tscn` under
`Friendlies`. Press F6 and select **Civilian lineup**, or focus a character
using keys 5–8 or the actor dropdown. The Animation dropdown, Play/Pause,
Restart, slow playback, scrubbing, and Hands close-up work with all four rigs.
Select **Rest pose** to compare their original T-poses and heights.

| Key | Model | Triangles | Height including hair and footwear |
| --- | --- | ---: | ---: |
| 5 | civilian_male_fat | 4,185 | 1.78 m |
| 6 | civilian_male_young | 4,264 | 1.80 m |
| 7 | civilian_woman_athletic | 4,148 | 1.72 m |
| 8 | civilian_woman_sweater | 4,264 | 1.68 m |

`prepared/*_rigged.glb` contains the fitted 65-bone humanoid rigs and skin
weights. Their import settings use the same Godot humanoid bone mapping as
the hero and hostiles, so the existing shared animation libraries drive them.
`source/*_rigged.blend` contains editable rigs with packed textures.

The original GLBs and textures remain unchanged. In the prepared copies,
uniform sizing and feet alignment are baked into the geometry; scene instances
use identity transforms. There is no sculpting or topology change. Weights are
normalized to at most four influences per vertex, and coincident UV seam
vertices share weights. Joined finger geometry uses a shared finger curl;
these are initial body/hand weights for visual review, without secondary hair
or clothing simulation.

The gameplay civilian scene now picks from all four models with equal probability.
This also covers routed crowds, console-spawned civilians, and rescue patients.
`model_variant_index` can pin a particular model in the Inspector; Random is the
default. Distant crowd capsules retain that choice through promotion/demotion,
so returning to a person preserves their appearance. Original textured materials
and integrated hair are used, with no legacy body tint or extra hair shell.
The existing `Superhero_Female_FullBody` holder name is retained for controller
and rescue paths; its `Visual` child contains the selected civilian rig.

Rebuild all four with Blender:

```
blender --background --factory-startup --python assets/characters/Civilians/tools/rig_civilians.py
```

Append `-- civilian_male_fat` (or other stems from the table) to rebuild selected
models. The builder reuses the existing hostile rigging helpers, and preserves
the prepared import settings. `prepared/rig_pass_audit.json` records source
hashes, height, triangles, bone/influence counts, and geometry/UV preservation.

Validation: the builder checks geometry and UV preservation after uniform
sizing, complete normalized weights, and the influence limit. The focused
Godot smoke check is `res://tests/test_npc_test_scene.gd`: all eight actors,
their heights and ground alignment, preview controls, and brief Idle, Walk,
and Punch_01 playback. Animation appearance is left for the user's review.

Crowd integration checks passed headlessly: all four variants in the ordinary,
routed, and rescue scenes; seven movement/reaction clips; normal crowd spawning
and walking; and capsule promotion/demotion with model identity preserved.
The live crowd's appearance has not been visually reviewed in this pass.

Files changed for the crowd integration:

- `scenes/npcs/civilian.tscn`
- `scripts/npc-scripts/civilian_model.gd` (new model selector)
- `scripts/npc-scripts/civilian.gd`
- `scripts/npc-scripts/civilian_animation_controller.gd`
- `scripts/npc-scripts/capsule_civilian.gd`
- `scripts/npc-scripts/civilian_capsule_lod.gd`
- `scripts/npc-scripts/pedestrian_journey.gd`
- `tests/test_civilian_meshy.gd` (existing entry point, now covers all four rigs)
- `tests/test_civilian_crowd.gd`
- `tests/test_civilian_capsule_lod.gd`
- This README and `assets/characters/hero_meshy/README.md`
