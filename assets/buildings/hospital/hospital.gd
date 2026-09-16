extends Node3D
## Per-instance materials: the imported GLB and other hospitals remain unchanged.
@export_range(0.0, 1.0, 0.01) var standalone_night_amount := 0.0
@export_range(0.0, 5.0, 0.05) var window_emission_energy := 2.0
@export_range(0.0, 5.0, 0.05) var sign_emission_energy := 1.5
@export_range(0.0, 5.0, 0.05) var entrance_light_energy := 1.8
@export var follow_day_night_cycle := true
var _night_materials: Array[StandardMaterial3D] = []
var _entrance_lights: Array[Light3D] = []

func _ready() -> void:
	var copies: Dictionary = {}
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		# The rescue marker glows in daylight too; it is not a window/sign.
		if node.get_parent() is HospitalRescueZone: continue
		var instance := node as MeshInstance3D
		for surface in instance.mesh.get_surface_count():
			var source := instance.get_active_material(surface) as StandardMaterial3D
			if source == null or not source.emission_enabled:
				continue
			if not copies.has(source):
				var copy := source.duplicate() as StandardMaterial3D
				copies[source] = copy
				_night_materials.append(copy)
			instance.set_surface_override_material(surface, copies[source])
	for light: Light3D in find_children("*", "Light3D", true, false):
		_entrance_lights.append(light)
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
		var energy := window_emission_energy if material.emission_texture != null else sign_emission_energy
		material.emission_energy_multiplier = energy * night
	for light in _entrance_lights:
		light.light_energy = entrance_light_energy * night
		light.visible = night > 0.001
