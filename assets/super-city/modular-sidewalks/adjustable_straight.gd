@tool
extends StaticBody3D
## Resize the visual, collision and connection markers together without scaling physics bodies.
@export_range(0.1, 200.0, 0.1, "or_greater", "suffix:m") var length_m := 40.0:
	set(value):
		length_m = maxf(0.1, value)
		_update_dimensions()
@export_range(0.1, 40.0, 0.1, "or_greater", "suffix:m") var width_m := 4.0:
	set(value):
		width_m = maxf(0.1, value)
		_update_dimensions()

func _ready() -> void:
	_update_dimensions()

func _update_dimensions() -> void:
	# Exported setters also run before the packed scene's children exist.
	var visual := get_node_or_null("Mesh") as MeshInstance3D
	var collision := get_node_or_null("Collision0") as CollisionShape3D
	if visual == null or collision == null:
		return
	visual.scale = Vector3(width_m / 4.0, 1.0, length_m / 40.0)
	var box := collision.shape as BoxShape3D
	box.size = Vector3(width_m + 0.002, 0.03, length_m + 0.002)
	get_node("Sockets/North").position.z = -length_m / 2.0
	get_node("Sockets/South").position.z = length_m / 2.0
