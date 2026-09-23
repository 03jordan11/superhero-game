@tool
extends MeshInstance3D
## Visual-only parking surface. Dimensions change the plane; the shader fits
## full-size bays to it. No frame loop, generated parking-space nodes or AI.
const MATERIAL := preload("res://assets/parking_lots/parking_lot_material.tres")
const EDGE := 0.6

@export_range(2, 300, .1, "or_greater", "suffix:m") var width_m := 30.0:
	set(value):
		width_m = maxf(2, value)
		_update_surface()
@export_range(2, 300, .1, "or_greater", "suffix:m") var depth_m := 36.0:
	set(value):
		depth_m = maxf(2, value)
		_update_surface()
@export_group("Parking Space Dimensions")
@export_range(2.2, 4, .1, "suffix:m") var stall_width_m := 2.6:
	set(value):
		stall_width_m = clampf(value, 2.2, 4)
		_update_surface()
@export_range(4.5, 7, .1, "suffix:m") var stall_depth_m := 5.2:
	set(value):
		stall_depth_m = clampf(value, 4.5, 7)
		_update_surface()
@export_range(4, 10, .1, "suffix:m") var aisle_width_m := 6.0:
	set(value):
		aisle_width_m = clampf(value, 4, 10)
		_update_surface()
var _plane: PlaneMesh

func _ready() -> void:
	_update_surface()

func _update_surface() -> void:
	if not is_inside_tree(): return
	if _plane == null:
		_plane = PlaneMesh.new()
		_plane.material = MATERIAL
		mesh = _plane
	_plane.size = Vector2(width_m, depth_m)
	set_instance_shader_parameter("lot_size_m", _plane.size)
	set_instance_shader_parameter("stall_width_m", stall_width_m)
	set_instance_shader_parameter("stall_depth_m", stall_depth_m)
	set_instance_shader_parameter("aisle_width_m", aisle_width_m)

func get_parking_layout() -> Vector2i:
	var metres := Vector2(width_m * global_basis.x.length(), depth_m * global_basis.z.length())
	return Vector2i(
		floori(maxf(0, metres.x - EDGE*2 - aisle_width_m) / stall_width_m),
		floori(maxf(0, metres.y - EDGE*2) / (stall_depth_m + aisle_width_m)))
