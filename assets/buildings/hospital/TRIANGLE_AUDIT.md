# Hospital triangle audit

## Completed reduction — September 13, 2026

Removed the 1,126 projecting window sill boxes. The rebuilt hospital has **5,612 triangles in 25 meshes**, saving 13,512 triangles (70.7%) and leaving 4,388 triangles below the hard limit. All room panels, tall glazing, arches and existing painted atlas sills remain. The generator and imported-mesh test now enforce the 10,000-triangle limit. The remainder of this document records the original pre-change audit.

Audited the exported hospital.glb index buffers on September 12, 2026 and cross-checked the procedural generator and hospital_manifest.json. This is an audit; hospital geometry and textures have not been changed.

## Budget result

The complete hospital currently has **19,124 triangles**, exceeding the new **10,000-triangle POI limit by 9,124**. It must lose at least 47.7% of its current geometry. The GLB contains 26 meshes; the native wrapper adds collision and lights, not additional rendered mesh geometry.

The budget applies to the highest-detail rendered building, included grounds and every placed prop instance. Preview rigs/ground and invisible collision do not count. City Hall currently meets it at 6,738 triangles including all placed furniture and hedges.

## Recommended first change

**Move the room-window sills into the window texture and remove their boxes.** There are 1,126 sills, each a six-face box costing 12 triangles: **13,512 triangles total (70.7% of the hospital)**. The corresponding room windows are already efficient two-triangle panels. The generator creates the sill boxes without collision, so their removal would leave existing traversal collision intact.

Removing only these boxes gives an exact geometry projection of **5,612 triangles**, leaving **4,388 triangles of budget headroom**. This assumes the painted sill fits into the existing window panels and adds no geometry. Keep its albedo and emission masks aligned so painted stone does not glow. Use a hospital-specific atlas copy if the shared texture needs changes, to avoid changing other buildings.

This one change is sufficient. Keep the tower ribs, pointed crown, rounded wings, entrance canopy and roof parapets, which contribute recognizable silhouette at modest cost.

## Additional optional savings

* Painted arch surrounds would save another 360 triangles, for a projected total of 5,252. These currently contribute real pointed outlines, so assess close views before removing them.
* Hospital lettering plus ENTRY, H and arrow lettering total 920 triangles. Textured signage could reduce this further, but preserve readability and night illumination. Replacement panel geometry must be included in the final count.
* Roof equipment uses 240 triangles and tower ribs use 252. These are low-priority reductions because their visual contribution is substantial relative to their cost.

## Complete mesh breakdown

| Exported mesh | Triangles |
| --- | ---: |
| Window sills | 13,512 |
| Room windows | 2,252 |
| Hospital lettering | 616 |
| Roof terraces | 592 |
| Arched surrounds | 360 |
| Tower ribs | 252 |
| Roof equipment | 240 |
| Entry wayfinding | 236 |
| Canopy | 194 |
| Bay piers | 144 |
| Bollards | 144 |
| Front lantern bays | 110 |
| Carved stonework | 84 |
| Entrance doors | 74 |
| Tower crown arches | 54 |
| Stepped wings | 48 |
| H wayfinding | 44 |
| Central arched bays | 36 |
| Wayfinding | 24 |
| Outer pavilions | 24 |
| Arrow wayfinding | 24 |
| Entrance sign | 12 |
| Lower central hall | 12 |
| Entrance apron | 12 |
| Central tower | 12 |
| Entrance pavilion | 12 |
| **Total** | **19,124** |

Counts are triangles, not rectangles/quads. A rectangular face usually becomes two triangles; a closed rectangular box becomes twelve.

## Validation for the optimization

After implementing the chosen reductions, recount the actual exported/imported triangles and require a complete-POI total of at most 10,000. Run the Godot import and tests/test_hospital.gd checks. Render day/night views and inspect window sill appearance, emission alignment, signs, tower crown and rounded bays. In hospital_preview.tscn use F6, then 1 for day and 3 for night. With the player, verify access through the entrance court and traversal onto the canopy and roofs.
