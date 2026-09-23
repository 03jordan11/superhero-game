# Resizable parking lot

Drag `parking_lot.tscn` into the city. Select its root and adjust **Width M** and
**Depth M** in the Inspector. The editor scale handles also work, including
independent width/depth scaling. Keep the surface horizontal; rotate around Y
to orient the rows and access aisle.

The shader tiles the existing city asphalt in world metres and fits complete
parking spaces without stretching the paint. Defaults are 2.6 × 5.2 m spaces,
6 m driving aisles and a 0.6 m perimeter clearance. Each row opens toward local
+Z, with a connecting access aisle along local +X. Extra space remains asphalt;
lots too small for a complete row and its aisles have no markings. Space and
aisle dimensions are also exposed in the Inspector.

White markings fade between 170 and 200 metres from the camera and disappear
completely at 200 metres. Asphalt stays visible. The shared shader material's
`paint_fade_start_m` and `paint_fade_end_m` parameters tune these distances.

The scene sits at Y = 0.045 m, just above the city's usual ground surface.
Adjust that height for other ground elevations to prevent overlapping surfaces.
This is a visual surface only: place it over existing solid ground. It does not
add collision, vehicle spawning, navigation or traffic connections.

## Preview

Open `parking_lot_preview.tscn` and press **F6**. It shows three sizes; the sliders
resize the middle lot. Right-drag to orbit, scroll to zoom, and press R to reset
the camera. Save permanent lot settings in the Inspector, not the running preview.

## Cost and validation

Each lot is one plane with **2 rendered triangles**, one shared shader material
and per-instance parameters. Markings are shader detail, with no individual
parking-space nodes or per-frame geometry generation.

`tests/test_parking_lot.gd` checks 56 size combinations, complete-space and aisle
clearances, independent instance settings, transform scaling and triangle count.
The preview has also been rendered in Godot to inspect normal, resized and
transform-scaled configurations.
