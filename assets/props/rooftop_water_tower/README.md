# Shared rooftop water tower

Drag `rooftop_water_tower.tscn` onto any flat rooftop. Local Y=0 is the feet;
the complete prop is approximately 2.81 m wide and 4.25 m tall. The scene owns
its mesh, material and simple collision and has no dependency on residential assets.

Blender-authored eight-sided wood tank, four steel supports and a conical roof:
**64 rendered triangles**, independently checked in the exported GLB and Godot mesh.
`rooftop_water_tower.blend` is the editable standalone source.

Residential models 04, 09 and 16 instance this same scene. It is not baked into
their building meshes. Their separate AC units use the existing shared hospital prop.
