# Utility helicopter

For the reusable flight controller and the single circling city helicopter, see
[city patrol and flight tuning](../../../docs/helicopter_flight.md).

Reference-inspired low-poly utility helicopter, modeled in Blender. No registration
numbers, lettering or logos. Forward is **-Z**, up is **+Y**, starboard is **+X**.
Body length is approximately 11.8 m; main rotor diameter is 13.8 m.

## Open and test

Open `helicopter_preview.tscn` and press **F6**. It contains all four liveries:
forest/cream and coastal blue are static; rescue red and charcoal/orange spin.
Hold right mouse and use WASD to move the inspection camera, Q/E for down/up,
and Shift for faster movement. These controls are local to this preview.

Use `helicopter.tscn` as the reusable scene in encounters or atmosphere.
Select its root in the Inspector:

- **Livery**: four shared materials on the same UV layout.
- **Custom Livery Texture**: optional replacement atlas for this instance only.
- **Rotors Spinning**: off by default for parked scenery; enables both rotor pivots.
- **Main Rotor RPM / Tail Rotor RPM**: defaults 324 / 1650, independently tunable.
- **Parked Collision Enabled**: enables solid cabin, boom, fin and skid volumes.
  Disabled by default for a visual aircraft that will later use a separate moving body.

Rotor motion runs in play mode, not while editing. Switching motion off freezes
the current angle. `reset_rotors()` restores the authored parked orientation.
The root does not fly or implement encounter AI, weapons or vehicle damage.

## Scene structure

```
UtilityHelicopter
  Body
  MainRotorPivot (Y axis)
    MainRotor
  TailRotorPivot (X axis)
    TailRotor
  LightMounts
    PortRed
    StarboardGreen
    TailWhite
    TopBeacon
    LandingLight
  ParkedCollision
    Solid0 ...
```

Red port and green starboard lens geometry is included. The markers provide
positions for future light nodes/effects; this asset does not emit actual light.
Main and tail rotor blades are real solid meshes and are excluded from collision.
Windows are opaque tinted surfaces with painted reflections; doors are closed.

## Textures and Blender source

`blender/helicopter.blend` contains the body and separate rotor assemblies with
their authored pivots, and all four packed livery images. `helicopter.glb` is the
exported geometry. Godot uses the three native meshes in `meshes/`.

The four 512x512 PNG atlases share a 4x4 tile layout. Tile numbering starts at the
bottom left, progressing left to right, then upward (Blender UV convention):

| Tile | Use |
| --- | --- |
| 0 | Main body panels |
| 1 | Tail, colored panels and stripe |
| 2 | Accent stripe |
| 3 | Skids and mechanical metal |
| 4 | Opaque blue glass with subtle reflection |
| 5 | Blades, seams and dark openings |
| 6 | Rotor tip markings |
| 7 / 8 | Red / green navigation lenses |
| 9-15 | Reserved palette tiles |

Keep glass, metal and navigation lens tiles consistent when creating a livery.
UVs are inset from tile borders to limit mipmap bleeding. Set a replacement PNG
through Custom Livery Texture for immediate use; the supplied native `.res`
textures are generated copies of the PNGs. Shared materials are never modified
when a single instance changes its livery.

## Rebuild and audit

1. Run Blender in background with `tools/build_helicopter.py`.
2. Run Godot headless with `--script res://assets/aircraft/helicopter/tools/import_helicopter.gd`.
3. Run Godot headless with `--script res://assets/aircraft/helicopter/tools/build_preview.gd`.
4. Run `tests/test_helicopter.gd` with Godot, then `tools/render_preview.gd` with a renderer.

Actual GLB and Godot geometry both contain **1,480 rendered triangles**:
1,248 body, 148 main rotor and 84 tail rotor. This includes skids, windows,
engine details and navigation lenses. Collision and preview ground/labels are
excluded. See `triangle_audit.json`; the complete asset is below 6,000 triangles.

Checks passed in Godot 4.7.2: exported/native counts, UVs, winding, correct pivots,
static mode, independent instance rotation/materials, all four liveries, custom
texture override, navigation marker sides and solid cabin collision. Godot renders
were inspected. No flight or encounter gameplay was implemented or playtested.
Sandbox certificate/settings/shader-cache warnings occurred during validation.

Test rotor spinning/stopping, each livery and custom texture replacement in the
preview. Inspect both sides for red/green lens placement. If using as parked
scenery, enable parked collision and check cabin/skid contact in your game scene.

All additions are under `assets/aircraft/helicopter/`, `artifacts/helicopter/` and
`tests/test_helicopter.gd`; no existing game scene or environment was changed.
