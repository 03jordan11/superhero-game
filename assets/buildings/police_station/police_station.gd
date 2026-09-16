extends Node3D
## Private material copies keep PoliceStation's night lighting independent per instance.
@export_range(0.0, 1.0, 0.01) var standalone_night_amount := 0.0
@export_range(0.0, 5.0, 0.05) var window_emission_energy := 2.0
@export var follow_day_night_cycle := true
var _night_materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	var copies: Dictionary = {}
	for instance: MeshInstance3D in $Model.find_children("*", "MeshInstance3D", true, false):
		for surface in instance.mesh.get_surface_count():
			var source := instance.get_active_material(surface) as StandardMaterial3D
			if source == null or not source.emission_enabled:
				continue
			if not copies.has(source):
				var copy := source.duplicate() as StandardMaterial3D
				copies[source] = copy
				_night_materials.append(copy)
			instance.set_surface_override_material(surface, copies[source])
	apply_night(standalone_night_amount)
	_bind_clock.call_deferred()

func _bind_clock() -> void:
	if not follow_day_night_cycle:
		return
	var clock := get_tree().get_first_node_in_group(&"day_night_cycle")
	if clock != null:
		clock.night_lighting_changed.connect(apply_night)
		apply_night(clock.night_lighting)

func apply_night(amount: float) -> void:
	var night := clampf(amount, 0.0, 1.0)
	for material in _night_materials:
		material.emission_energy_multiplier = window_emission_energy * night



