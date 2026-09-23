# Prison, cargo ship and airport proxies

`Main/SuperCity/RegionalProxies` manages five independent, single-surface meshes: PrisonIsland, CargoShip, Airport, Flight1 and Flight2. Default switching matches the forest pass: switch out beyond **350 m from the nearest point of the object's world bounds**, return inside **300 m**. The 50 m hysteresis prevents threshold flicker. The ship and aircraft proxies follow the source translation and rotation every frame.

| Object | Mesh surfaces before this pass | Current near surfaces | Distant surfaces | Mesh triangles before | Current near triangles | Distant triangles |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Complete prison island | 817 | 349 | 1 | 14,356 | 7,180 | 1,280 |
| Container ship | 21 | 21 | 1 | 4,268 | 4,268 | 262 |
| Airport, including all four aircraft | 606 | 606 | 3 | 26,234 | 8,230 | 1,762 |

The airport distant total is a 1,336-triangle static mesh plus two independently moving 213-triangle aircraft. Static parked jets are in the airport mesh. These are complete geometry totals, including hidden navigation-light modes where applicable, **not measured frame draw calls**. The directional bake inventory only counts visuals active at capture time, so its ship source count is 4,204 triangles/13 surfaces rather than the complete 4,268/21.

## What is replaced

- Prison: simple walls and building shells with baked facades, island terrain/surf silhouette, landing and access ramp. Small furniture, rocks and fittings are omitted or represented in the directional captures.
- Ship: low-poly hull/deck geometry plus combined cargo and superstructure shells. Surface details are baked from the placed ship's materials. The proxy follows the existing harbor schedule.
- Airport: runway/taxiway/apron slabs, terminal/tower/hangar shells, static parked aircraft and access road. Paint, glazing and small details are captured in an atlas. Moving aircraft are excluded from the static bake.
- Each replacement has one mesh surface and one material. Distant meshes cast no shadows. Textures are embedded in compressed `.res` resources, so no editor texture import is required for runtime.

Original nodes and all collision shapes remain in place. The island and ship roots are hidden at distance. Airport children are hidden individually except AirTraffic; each scheduled aircraft swaps independently. Scripts and schedules continue; this is a rendering change, not unloading or simulation suspension. Near and distant representations are mutually exclusive.

The project requires complete optimized POIs to stay below 10,000 triangles at highest detail. To meet that requirement, the near prison now paints bars into flat window textures instead of rendering 468 separate bar meshes. Near airport runway bulbs use eight-triangle shapes; thin paint strips and cabin windows use quads; cylinders and aircraft round surfaces have fewer subdivisions. Node paths and collision are preserved. Counts include every MultiMesh bulb and all four planes. Even adding a conservative glyph-plus-outline allowance, the full prison is at most **7,272** triangles and airport **9,134**.

## Test in Godot

Restart Main, then select **Main/SuperCity/RegionalProxies** in the Remote tree.

1. Set **Force Lod** to **Originals** or **Distant proxies** for a fixed-camera comparison. This overrides distance for all five objects.
2. Return to **Automatic**, fly toward/away from the island, ship and airport, and check the transition. Distance is to each object's bounds, not its center; the airport is large and includes its access road.
3. **Enabled = false** restores all originals. Hiding the controller only hides proxy geometry; it is not an originals comparison.
4. Check landing on the ship, island and runway. Watch a plane and the ship move while distant, then approach them. Check night-time return of airport lighting.

Coarse silhouettes, projection seams and loss of small runway markings at distance are expected. The ship's baked appearance uses its current palette; changing palettes requires rebaking. Distant imagery follows day/night amount but does not reproduce individual strobes, rotating searchlights or changing ship navigation-light modes. The full effects return nearby.

## Remaining scenery audit

`assets/super-city/regional_proxies/scenery_audit.json` records source mesh surfaces and highest-detail triangles, with every MultiMesh placement counted. Forests are omitted because they already have chunks. The remaining candidate categories were inspected without modifying them.

| Category under SuperCity | Surfaces | Triangles | Main finding |
| --- | ---: | ---: | --- |
| Waterfront/Riverbanks | 1,454 | 19,056 | 519 stone-course meshes, 374 railing posts, 173 coping pieces and 173 quay walls |
| Roads | 1,372 | 46,162 | 742 mesh nodes across road/junction pieces; multiple surfaces on many meshes |
| Waterfront/Harbor | 494 | 7,704 | 288 individual corrugation meshes and 48 container door locks |
| CityLife/Benches | 332 | 3,984 | 83 benches, four separate meshes each |
| CityLife/Highway, excluding forests | 172 | 18,995 | Includes 92 guardrail posts, 48 median barriers and terrain |
| Waterfront/Boats | 113 | 4,960 | Numerous rails/stanchions and windows |
| CityLife/Baseball | 93 | 3,366 | Separate fence posts, rails and chain-link panels |
| CityLife/Blimp | 19 | 22,460 | **Five tiny strobe spheres alone use 21,120 triangles** |
| NightLights | 4 | 338,124 | **LampPosts: 320,328 triangles in one global MultiMesh**; three lens batches add 17,796 |

For reducing separate render submissions, riverbanks, roads, harbor container details and benches are the clearest next candidates. The blimp strobes are an easy triangle reduction. Lamp posts need simpler geometry and spatial batches/distance handling rather than more material sharing: they are already batched, and the global batch has coarse visibility bounds. Disabling active light nodes is a different experiment from disabling LampPosts geometry. Actual costs depend on what is visible and which render passes run; no FPS benchmark was performed for this pass.

## Files and rebuilding

- `scripts/regional_proxies.gd`: runtime switching, moving transforms, loading preparation, night material updates.
- `assets/super-city/tools/bake_regional_proxies.gd`: generates the five proxy meshes using directional capture support in `bake_landmark_proxies.gd`. The older landmark baker received small optional output/geometry hooks; its default behavior is preserved.
- `assets/super-city/regional_proxies/`: five meshes, facade/night PNG previews, shader, inventory, audit and near-detail replacement resources in `near/`.
- `assets/super-city/tools/regional_geometry.gd`: near-detail budget reductions, also called by both regional generators.
- `scenes/waterfront.tscn` and `scenes/coastal_region.tscn`: targeted mesh/material substitutions, no node removals or placement changes.
- `scenes/main.tscn`: adds RegionalProxies.
- `assets/waterfront/tools/generate_waterfront.gd` and `assets/coastal-airport/tools/generate_coastal_airport.gd`: retain near-detail reductions on regeneration.
- `export_presets.cfg`: includes the runtime regional inventory JSON.
- `tests/test_regional_proxies.gd`: replacement, distance hysteresis, movement, lighting restoration, collision-resource preservation and complete POI budget checks.
- `assets/super-city/tools/audit_scenery.gd`: repeatable static scenery audit.

Rebake distant proxies from the project folder with the graphical renderer:

```powershell
& 'D:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --path . --script res://assets/super-city/tools/bake_regional_proxies.gd
```

Run the audit headlessly with `--headless --path . --script res://assets/super-city/tools/audit_scenery.gd`. The audit writes geometry counts, not FPS. Existing performance monitors may create their normal log during scene setup; no timed benchmark or FPS comparison was collected.

## Validation

Godot 4.7.2: regional proxy tests, coastal airport tests, ship schedule tests, existing landmark proxy tests and forest chunk tests pass. Both modified regional generators parse successfully. Original/proxy graphical captures for all target types were inspected, including the corrected double-sided aircraft wings/tail. These were automated captures rather than a manual traversal playtest.

The existing waterfront suite reports **seven failures**, identically reproduced using the pre-change waterfront scene: one island gate-approach collision step, five old road-crossing assertions, and the old nine-boat count expectation. These were not introduced by the proxy changes and were left outside this pass. Logs and before/proxy screenshots are under `artifacts/regional_proxies/`.
