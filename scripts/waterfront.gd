extends Node3D
## Authored waterfront. Only water, moored boat motion and beacons animate at runtime.
@export_range(0.0, 3.0, 0.05) var wave_strength := 1.0
@export_range(0.0, 3.0, 0.05) var animation_speed := 1.0
@export_range(0.0, 2.0, 0.05) var night_light_brightness := 1.0
@export var boat_motion_enabled := true
@export var searchlights_enabled := true
var _elapsed := 0.0
var _night := 0.0
var _materials: Array[ShaderMaterial] = []
var _glows: Array[StandardMaterial3D] = []
var _lights: Array[Light3D] = []
var _boats: Array[Node3D] = []
var _beacons: Array[Node3D] = []

func _ready() -> void:
	var copies: Dictionary = {}
	for mesh in find_children("*", "MeshInstance3D", true, false):
		var source: Material = mesh.material_override
		if source == null: continue
		if source is ShaderMaterial or source.has_meta("night_glow"):
			if not copies.has(source):
				copies[source] = source.duplicate()
				if source is ShaderMaterial:
					if not source.shader.resource_path.ends_with("deck.gdshader"):
						_materials.append(copies[source])
				else:
					_glows.append(copies[source])
			mesh.material_override = copies[source]
	for light in find_children("*", "Light3D", true, false):
		light.set_meta("base_energy", light.light_energy)
		_lights.append(light)
	for boat in get_node("Boats").get_children():
		boat.set_meta("rest", boat.transform)
		_boats.append(boat)
	for node in find_children("SearchlightPivot*", "Node3D", true, false):
		node.set_meta("rest_yaw", node.rotation.y)
		_beacons.append(node)
	_bind_clock.call_deferred()
	apply_night(0.0)

func _bind_clock() -> void:
	var clock := get_tree().get_first_node_in_group(&"day_night_cycle")
	if clock == null: return
	clock.night_lighting_changed.connect(apply_night)
	apply_night(clock.night_lighting)

func apply_night(amount: float) -> void:
	_night = amount
	for light in _lights:
		light.light_energy = float(light.get_meta("base_energy")) * amount * night_light_brightness
		light.visible = light.light_energy > 0.001 and (not light.has_meta("searchlight") or searchlights_enabled)
	for material in _glows:
		material.emission_energy_multiplier = float(material.get_meta("night_glow")) * amount * night_light_brightness
	for material in _materials:
		if material.shader.resource_path.ends_with("water.gdshader"):
			material.set_shader_parameter("night_amount", amount)
			material.set_shader_parameter("wave_strength", wave_strength)

func _physics_process(delta: float) -> void:
	_elapsed += delta * animation_speed
	for material in _materials: material.set_shader_parameter("elapsed", _elapsed)
	for i in _boats.size():
		var boat := _boats[i]
		var rest: Transform3D = boat.get_meta("rest")
		boat.transform = rest
		if boat_motion_enabled:
			boat.position.y += sin(_elapsed * 0.7 + i * 1.7) * 0.11
			boat.rotation.x += sin(_elapsed * 0.52 + i) * 0.009
			boat.rotation.z += cos(_elapsed * 0.63 + i * 1.9) * 0.014
	for i in _beacons.size():
		_beacons[i].rotation.y = float(_beacons[i].get_meta("rest_yaw")) + sin(_elapsed * 0.14 + i * 1.7) * 0.85
	apply_night(_night)
