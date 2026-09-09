class_name TrafficVehicleEntry
extends Resource
## One selectable scene and its relative spawn frequency.
@export var scene: PackedScene
@export_range(0.0,100.0,0.1) var weight := 1.0
## Color of the distant box representation; does not recolor the full scene.
@export var distant_color := Color.WHITE
## The supplied car meshes face +Z. Set 180 for a scene facing -Z.
@export_range(-180.0,180.0,1.0) var heading_offset_degrees := 0.0
