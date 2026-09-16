# Rooftop HVAC

Reusable 48-triangle StaticBody3D scene, extracted from the hospital's existing
roof equipment (unit at Godot coordinates -13, 129, -18). Hospital geometry and
materials are reused; the hospital itself is unchanged. The unit uses four simple
boxes, with a single bounding box collider, and measures 9.4 × 2.8 × 6.4 m.
Its bottom is at local Y=0. Place the scene at the desired roof elevation.

The commercial skyscraper revision builder extracts and saves this prop. It is
instanced separately on commercial_skyscraper_01 so it can be moved or replaced
without editing the building mesh.
