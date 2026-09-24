# Legacy character usage audit

Checked September 24, 2026 after replacing crowd and rescue visuals with the
four rigged civilians. No legacy character models were deleted: the older
assets still have references outside the crowd/rescue system.

| Asset | Remaining uses | Decision |
| --- | --- | --- |
| `hero_meshy/hero_meshy.glb` | Underwear outfit in `scenes/hero_costumes.tscn`; reference geometry in `hero_starter_suit/tools/refine_costume.py`; mesh audit and costume tests | Retain |
| `Superhero-male/Superhero_Male_FullBody.gltf` | Skeleton/weight donor for `Civilians/tools/rig_civilians.py`, `Hostiles/tools/rig_hostiles.py`, `hero_meshy/tools/build_meshy_rig.py`, and `hero_starter_suit/tools/rig_costume.py`; grab and hair-fitting previews; hero rig regression | Retain |
| `Superhero-female/Superhero_Female_FullBody.gltf` | `scenes/tests/hair_fitting.tscn`; `tests/fixtures/civilian_legacy_benchmark.tscn`, used by `benchmarks/civilian_models.gd`; costume regression | Retain |
| Male and female `Hairstyles/*.gltf` | `scripts/character_hair.gd`; hair-fitting scene and tests; legacy benchmark | Retain |
| `hero_meshy/source/meshy_reference_fro.glb` and `hero_meshy/source/hero_meshy.blend` | Rebuild input and editable source for the retained underwear outfit | Retain |

The original male also supplies the skeleton for the authored flight and combo
animation builders under `assets/animations/`. These are live rebuild dependencies.

The associated glTF buffers, textures, import configurations, and source files
are dependencies of these retained assets and stay with them. The new civilian,
hostile, and story-character source meshes are outside this legacy cleanup.

Crowds use `scenes/npcs/civilian.tscn` and the four entries in
`scripts/npc-scripts/civilian_model.gd`. Rescue missions instantiate the inherited
`rescue_patient.tscn` and explicitly select one of those entries with the
encounter's RNG before entering the tree. A selected model survives pickup/drop
reparenting; selection is not repeated during the mission.

The names `Superhero_Female_FullBody` and `Superhero_Male_FullBody` remain on some
gameplay holder nodes to preserve script paths. Those names do not imply use of
the old mesh: the civilian holder contains its new model under `Visual`, and
hostile scenes instance their respective rigged hostile GLBs.

Validation: `tests/test_rescue_encounter.gd` passed headlessly, including selected
civilian asset, injured pose, pickup, carry anchor, drop/re-pickup identity,
hospital completion, and rewards. The test fixture was updated to create the
city-owned hospital drop-off node. Visual appearance was not reviewed.

Files changed in this pass: `scripts/encounter-scripts/rescue_encounter.gd`,
`tests/test_rescue_encounter.gd`, `assets/characters/hero_starter_suit/README.md`
(removed its stale civilian-model description), and this audit. No assets deleted.
