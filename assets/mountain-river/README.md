# Mountain river and forest clearing

## Current placement: solid mountain

The river extension now belongs to `SuperCity/MountainRiver` in `scenes/super_city.tscn`. Main inherits it through SuperCity; its separate river instance and all river-specific terrain overrides have been removed.

`PinePassMountains` retains the original mesh and collision from `city_life.tscn`, without a canyon cut. Water ends at the solid mountain surface. The hidden water, bank rock, and riverbed geometry beneath the mountain have been removed, with matching trimmed bank/bed collisions. Resources are in `terminated/`; `tools/trim_at_mountain.gd` clips against the original mountain faces without modifying them. The existing NorthernGround and CoastalTerrain channel resources are applied in SuperCity to keep the forest approach visible; neither changes the mountain's form.

Validation: `tests/test_mountain_river.gd` compares original mountain vertices and collision in both scene contexts, checks 76 mountain and 140 open-channel ray probes, and verifies water day/night and pause behavior. All passed. An additional 1,408 triangle probes verify that no remaining river triangle centers are beneath the mountain; bank and bed collision faces match the trimmed meshes. Native SuperCity renders were inspected; manual player traversal was not performed.

Review: open SuperCity directly and fly north along the river to the mountain face. Main should show the same intact mountain and only one river extension.

The notes below are historical. Do not run `tools/apply_main.py` or the old terrain-carving workflow: those restore the superseded Main-only canyon arrangement.

## Initial forest and mountain pass

Open `scenes/main.tscn` to see this pass. `MountainRiver` is a sibling of
`SuperCity`. The standalone city and waterfront scenes retain their existing
river; Main overrides the old stepped banks, water and terrain resources.

- The river follows a continuous, sampled curve from the bay at Z=800 through
  the city to a mountain headwater at Z=-3160, Y=160. The new northern reach is
  approximately 2.2 km long in the north/south direction.
- The city channel is 104 m wide. It fits inside the old 140 m stepped channel;
  solid paving fills the space between the old land edge and the new bank.
  The narrower waterline leaves existing roads, buildings and A* routes intact.
- Main uses carved copies of NorthernGround, CoastalTerrain and PinePassMountains,
  with matching collision resources. Both overlapping northern ground layers
  are cut. The riverbed is eight metres below the new northern water surface.
- All five road bridges, piers, harbor walls, boats and the ocean remain.
  Old city quay wall collisions are disabled along with their visuals. New
  railings use alpha-cut rectangles, with openings at the bridges.
- Water uses the existing waterfront shader and follows the day/night cycle
  and pause state.

## Trees

| Region | Before | Removed | Remaining |
| --- | ---: | ---: | ---: |
| Northern forest / CityLife | 4,943 | 1,024 | 3,919 |
| Coastal region | 5,038 | 1,127 | 3,911 |

Of the 2,151 removed instances, 1,100 intersected mountain terrain, 1,008 lay
behind the range viewed from the city center, and 43 overlapped the new river
corridor. The existing 366 park trees were preserved, including prior manual
deletions. Trees remain individually editable scene instances. The existing
tree generators preserve deletions from these saved regional scenes.

`report.json` records every removed tree, its reason, source hashes and the river
cross-sections. The new river meshes total 4,144 triangles. Cutting the three
terrain layers adds 7,762 triangles; tree removal more than offsets this.
The removed trees account for 172,800 triangles (1,404 pines and 747 oaks).

## Changed files

- `scenes/main.tscn`: river instance, curved bank overrides and carved terrain.
- `scenes/city_life.tscn`, `scenes/coastal_region.tscn`: removed tree instances and
  updated tree-count metadata.
- `scenes/mountain_river.tscn`, `scripts/mountain_river.gd`: new authored reach
  and its water animation/day-night binding.
- `assets/mountain-river/`: generated meshes, collisions, railing shader,
  authoring scripts and report.
- `tests/test_mountain_river.gd`: new geometry and runtime checks.
- `tests/test_tree_scenes.gd`, `tests/test_coastal_airport.gd`: expectations
  updated for the approved clearing and earlier manual park deletions.

## Authoring and verification

The scripts in `tools/` are one-off authoring scripts for this saved layout.
`inspect.gd` captures the source geometry, `prepare.py` clips it and prunes tree
nodes, `build.gd` writes meshes/collisions and `apply_main.py` adds Main overrides.
They use the task backup in `artifacts/river_mountains/before`; do not rerun them
over subsequent manual scene edits without updating that baseline.

Rendered Main views are in `artifacts/river_mountains/`. Verification includes
`test_mountain_river.gd`, `test_tree_scenes.gd`, `test_city_poi_integration.gd`,
`test_coastal_airport.gd` and `test_waterfront.gd`. The river test checks the cut
terrain, riverbed, walkable paving, bank walls, bridge deck collisions, preserved
navigation sources, and night/pause synchronization.

For a player check, run Main, fly north along the river from the city to its
mountain source, land on the curved city quays, and cross the existing bridges.
Rendered views and physics probes were checked; manual player traversal is a
separate check.
