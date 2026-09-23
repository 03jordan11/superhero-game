# Subway entrance

Place `subway_entrance.tscn` on a sidewalk. The root is at ground level, centered
under the canopy; **+Z is the open approach side**. Match the root Y to the top
of the sidewalk. Overall dimensions are **3.8 m wide × 5.1 m deep × 3.57 m high**.
Leave at least 1.5 m of clear pavement in front of the entrance.

The blank canopy and information panel contain no lettering, numbers or logos.
Dark charcoal metal, muted stone, a green rectangular rooftop beacon, tinted glass and warm
underside strips follow the existing city palette. The beacon and strips are emissive
materials, without added light nodes.

The stairwell is a painted depth illusion on a sealed surface, not underground
geometry. No pavement excavation is needed. A collision barrier closes the
opening pending fast-travel integration. The posts, side panels, back wall,
information panel and canopy also have simple box collision.

`Approach` is a marker 3.2 m forward of the root for later interaction/arrival
placement. There is no interaction, fast-travel code, player, camera or runtime
generation script on the asset. It has not been placed in the city.

All parts are named MeshInstance3D nodes grouped by purpose. Open the scene to
edit them, or enable Editable Children on a placed instance. Move/rotate the
whole entrance using its root so geometry, collision and marker stay together.

## Budget and checks

**386 rendered triangles**, counted from the saved Godot meshes at full detail:
32 boxes × 12 triangles plus the 2-triangle sealed stairwell. Every placed mesh
is counted. Collision shapes and the marker are not rendered.

`tests/test_subway_entrance.gd` checks the saved geometry budget, bounds, marker,
collision and absence of text or runtime scripts. Two Godot render views were
inspected. In the city, test sidewalk alignment and walk around all sides to
check collision and approach clearance.

`build_subway_entrance.gd` is an offline authoring script that recreates the
scene. Running it overwrites manual changes to this asset; ordinary placement
and editing do not require running it.
