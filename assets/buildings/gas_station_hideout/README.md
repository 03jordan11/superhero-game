# Gas station hideout exterior

Drag `gas_station_hideout.tscn` into a level to place the complete exterior. Open `gas_station_preview.tscn` and press F6 for a standalone preview. The city has not been modified.

## Asset

- Editable Blender source: `gas_station_hideout.blend`.
- Portable textured mesh: `gas_station_hideout.glb`.
- Original 2048 × 2048 texture atlases: `textures/station_albedo.png` and `textures/station_roughness.png`. Keep these alongside the Blender file. Godot also extracts the embedded GLB textures during import.
- Footprint including forecourt: 27.5 × 25 metres; maximum height approximately 6.7 metres. Front faces Godot +Z; origin is at ground level.
- Includes two garage bays, office, boarded windows, faded trim, vintage pumps and hoses, island light, sign, roof vents, pipes, and small yard clutter.
- The exterior remains a separate asset. `HideoutEntrance` adds the E prompt at the front office door; the interior is loaded only when used.
- Solid box collision covers the buildings, roofs, ground, pumps and substantial props. Small cosmetic details such as weeds and hoses do not have individual collision shapes.
- The placeable exterior has only its entrance interaction script, with no camera or lights. Preview lighting exists only in the preview scene.

## Triangle audit

The complete exported and Godot-imported asset contains **2,200 triangles** across seven mesh surfaces at highest detail, below the requested 5,000-triangle limit. Grounds and every included prop are counted; collision and preview nodes are excluded.

| Part | Triangles |
| --- | ---: |
| Architecture | 108 |
| Facade | 288 |
| Roof | 264 |
| Details | 124 |
| Pumps | 768 |
| Yard | 636 |
| Grounds | 12 |
| **Total** | **2,200** |

`triangle_audit.json` records the imported geometry audit. `manifest.json` contains export counts, dimensions and collision definitions.

## Rebuild and validation

Run these from the project root, substituting the installed executable paths:

```text
blender --background --python assets/buildings/gas_station_hideout/tools/build_gas_station.py
godot --headless --path . --editor --import
godot --headless --path . --script assets/buildings/gas_station_hideout/tools/prepare_gas_station.gd
godot --headless --path . --script tests/test_gas_station_hideout.gd
```

The builder regenerates the source, textures, export and manifest; the preparation script regenerates the placeable and preview scenes. Preserve manual edits before rebuilding.

Validation passed for imported triangle counts, materials, UVs, markers, and physics rays against the garage roof, office roof, forecourt and pump. Front, entrance and rear views were rendered and inspected using Godot Forward+. In gameplay, test walking around the forecourt and pumps, landing on both roofs, and the asset's scale beside the player.

## Separate hideout interior

`gas_station_interior.tscn` is an independent scene loaded on entry, never a child of the city or exterior scene. Its office and garage match the exterior shell's asymmetric footprint (approximately 20 × 11 metres before wall thickness). The Blender source is `gas_station_interior.blend`, the mesh is `gas_station_interior.glb`, and the new atlas is `textures/interior_albedo.png`. It shares the exterior's roughness atlas and weathered surface palette.

Props include a salvaged computer desk, investigation board, cot and blanket, lockers, workbench and tools, storage racks, crates, tires and a drum. Most of the garage floor remains clear, with a simple training mat. Props are static dressing for now. Separate warm office and cooler garage lights belong only to this interior scene.

The furnished interior retains **2,286 triangles**, now split into **46 surfaces** for editing. The placed powers machine adds **2,268 triangles / 2 surfaces**. The complete exterior + interior + machine total is **6,754 triangles**, below the overall 10,000-triangle POI limit. See `interior_triangle_audit.json` and `editable_props_audit.json`. Box collision covers the room shell and the original major furnishings; the office-to-garage opening is clear.

### Moving interior props in Godot

Open `gas_station_interior.tscn` directly, then expand **Model → Props**. There are 38 locally editable named prop nodes, including the desk, monitors, keyboard, chair, cot, bedding, lockers, workbench, toolboard, toolbox, vise, oil tins, racks, individual crates, training mat, tires, drum, and ceiling fixtures. Select the named prop node in the Scene tree and use the move/rotate gizmo or Inspector Transform. Select `Workbench`, for example, rather than its `Mesh` or `Collision` child. No Editable Children toggle or Blender mesh separation is required.

Accessories are children of their furniture: the desk carries its monitors and keyboard, the cot carries its bedding, the workbench carries its tools and cans, and racks carry their crates. You can select these child props in the Scene tree and move them independently. Original furniture collision shapes are children of their corresponding prop; moving the whole prop moves both its appearance and collision. CeilingFixture nodes likewise carry the existing room lights. Small decorative pieces retain their original lack of collision; these nodes remain static scenery, not physics pickup objects.

The user's `power_machine` instance stays at its original scene-root transform. The workbench assembly and separate wall toolboard were moved 3.3 metres to the right to clear it. No other furnishings were repositioned. The station's room shell remains grouped under Model → Shell, with its collision under RoomCollision.

### Powers machine interaction

Approach the front of the machine and press **E** (the remappable pick-up/interact action). The existing gameplay menu opens directly on **Powers**, using the player's actual tokens and upgrades. Escape or Close returns to gameplay and restores camera control. The regular gameplay-menu shortcut remains available.

`power_machine/Interaction` uses `scripts/power_machine_interaction.gd`. Its Inspector exposes interaction distance, marker distance, front-panel position and width. The floating prompt follows keyboard/controller binding labels. The interaction takes priority over grabbing when usable, while hideout doors keep their existing priority. Carrying, death, knockdown, active combat, traversal charges and other blocking states retain their existing controls. Front-only reach prevents use through the back wall.

The user's `power_machine/StaticBody3D/CollisionShape3D`, machine transform and room layout are preserved. The normal city route reuses the transferred gameplay menu; a standalone room preview creates the same menu on first use if it does not already exist. `tests/test_power_machine_interaction.gd` verifies physical E and rebound-key input, pause/close behavior, progression sharing, range/state gates and menu reuse. `tests/test_hideout_interior.gd` also exercises machine use on repeated city/interior visits.

The original export combined props by category to reduce rendering submissions (draw calls). That saved a small amount of rendering overhead, but prevented convenient scene layout editing. The current structure shares the same texture atlas and retains exactly the same triangle count while exposing whole furnishings as editable nodes. Details within one object, such as chair legs, remain combined.

### Enter and exit

- Approach the front office door at the station already placed in the city and press **E** (the remappable pick-up/interact action).
- The city is unloaded, including its encounters. No city cache or paused exterior is retained.
- The same player enters the interior, keeping health, stats, progression, abilities and the player's HUD. Pause and powers menus remain available.
- Indoors the camera sits close over the right shoulder (0.6 m right offset, 1.5 m follow distance), with wall collision clearance. The outdoor pivot, distance and angle are restored on exit. Tune `shoulder_offset`, `shoulder_distance` and `shoulder_pitch_degrees` on `hideout_travel.gd`.
- Use **E** at the inside front door to unload the interior and reload a fresh city, returning outside the station. Encounters reset. The outdoor camera distance is restored.
- Carrying objects/people, death, knockdown and locked combat actions block doorway use. The action is consumed before grab/vehicle interactions.

Door range and marker range are Inspector controls on `HideoutEntrance` / `ExitDoor`. `PlayerSpawn` controls interior arrival. Move the exterior instance in the city normally; the return position follows the actual placed door.

For a standalone walkable art preview, open `gas_station_interior_preview.tscn` and press F6. That preview has no loaded city to return to; use the main scene to test the full entry/exit flow.

### Interior authoring and checks

```text
blender --background --python assets/buildings/gas_station_hideout/tools/build_interior.py
godot --headless --path . --editor --import
godot --headless --path . --script assets/buildings/gas_station_hideout/tools/prepare_interior.gd
godot --headless --path . --script tests/test_hideout_interior.gd
godot --headless --path . --script tests/test_editable_hideout_props.gd
```

The preparation step now updates the **existing interior only**. On first conversion it creates native prop nodes and transfers the original collision shapes. Subsequent runs refresh mesh resources in `interior_meshes/` while preserving scene layout, parenting, collision edits, machine placement, doors and lights. It does not rebuild the exterior, entrance or preview scene. Editing the room's `.tscn` is the layout workflow; the Blender source and GLB contain the original authoring positions. Rebuilding the Blender script still overwrites its generated source/GLB, so preserve manual Blender edits first. Runtime integration remains in `scripts/hideout_door.gd`, `scripts/hideout_travel.gd`, and the E-priority hook in `scripts/player-scripts/player_character.gd`.

Editable-prop validation checks all 38 local nodes, attachment of collision and lights, machine clearance against every furnishing, physics collision after moving a workbench, and the full POI geometry count. `-- --render` produces isolated Godot room views in `artifacts/interior-prop-edit/`. Front-wall, garage and office views were inspected; full manual traversal remains a playtest step.

The test drives E through the real player input in the full city twice, checks actual city/interior destruction, fresh encounters, retained player identity/progress, restored camera and return location, and verifies imported triangle counts and collision rays. `-- --render` also produces Godot screenshots in `artifacts/gas_station_hideout`; `-- --quit-inside` checks shutdown from the room. In gameplay, also check camera clearance while walking between the office and garage, around props and beneath the ceiling.
