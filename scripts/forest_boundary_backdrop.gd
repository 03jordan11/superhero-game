extends MeshInstance3D
## One static backdrop; only the day/night signal changes its material.

func _ready() -> void:
	material_override = material_override.duplicate()
	_bind_clock.call_deferred()

func _bind_clock() -> void:
	var clock := get_tree().get_first_node_in_group(&"day_night_cycle")
	if clock != null:
		clock.night_lighting_changed.connect(_apply_night)
		_apply_night(clock.night_lighting)

func _apply_night(amount: float) -> void:
	material_override.set_shader_parameter("night_amount", amount)
