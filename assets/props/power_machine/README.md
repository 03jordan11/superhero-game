# Power machine

Reference-inspired prop: worn ivory housing, graphite chassis, sloped transparent canopy, cyan reactor cell, small diagnostic display and a **rectangular glowing contact pad**. The user has placed it in the gas station interior and added box collision there. That scene now adds an E interaction opening the existing Powers menu; the GLB itself remains a reusable visual asset.

- `power_machine.blend`: editable, named Blender mesh parts and packed textures. The separate STUDIO collection contains preview-only lights, camera and floor.
- `power_machine.glb`: placeable Godot mesh with embedded textures, two material surfaces and a floor-centred origin. No lights, camera, collision, animation or interaction logic.
- `textures/power_machine_albedo.png`, `power_machine_roughness.png`, `power_machine_emission.png`: original painted 2048 × 2048 atlas maps. Each tile has padded edges to avoid colour/emission bleeding through mipmaps. Godot also generates extracted copies beside the GLB on import.
- `manifest.json`: dimensions, exported geometry count and per-part breakdown.
- `triangle_audit.json`: actual Godot imported geometry/material validation.
- `tools/build_power_machine.py`: reproducible Blender authoring/export/render script. Rebuilding overwrites generated files; preserve manual Blender edits first.
- `tools/validate_power_machine.gd`: import validation and optional isolated Godot art render.

Dimensions: approximately **3.51 m wide × 2.17 m high × 1.58 m deep**, including display, front handle and rear socket. Front faces **+Z in Godot**, -Y in Blender; scale is metres. Drag the GLB into your chosen scene when ready. The original Blender parts remain separate for editing; the GLB consolidates them into one mesh with opaque and transparent surfaces.

The actual exported and Godot-imported mesh contains **2,268 triangles**, including all parts. Its single station instance brings the documented exterior/interior total to **6,754**, under the 10,000-triangle POI limit.

## Checks

Godot 4.7.2 imported the asset and passed validation of triangle counts, UVs, albedo, roughness, emission, transparent glass, and exclusion of the studio rig. Front/rear Blender renders and an isolated Godot Forward+ render were inspected. No gameplay was changed or visually tested. The local engine emitted existing environment warnings about user-directory access, certificates and settings; editor scanning also reported existing city-road UID fallbacks.

To check the integrated prop: enter the gas station, approach the front panel, press E and confirm the Powers tab opens. Close with Escape and check that movement/camera control resume. The existing menu handles purchases; the machine does not grant powers for free. Emission is included; a glow halo depends on the scene's WorldEnvironment glow settings.

```text
blender --background --python assets/props/power_machine/tools/build_power_machine.py
godot --headless --path . --editor --import
godot --headless --path . --script assets/props/power_machine/tools/validate_power_machine.gd
godot --path . --script assets/props/power_machine/tools/validate_power_machine.gd -- --render
```

Preview images are in `artifacts/power_machine/` (excluded from Godot asset scanning).
