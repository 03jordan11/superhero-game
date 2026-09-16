extends Node3D
## Baked park geometry; runtime only animates water and the nocturnal details.
@export_range(0.0, 2.0, 0.05) var lantern_brightness := 1.0
@export_range(0.0, 12.0, 0.1) var firefly_brightness := 5.0
@export var fireflies_enabled := true
@export_range(0.0, 3.0, 0.1) var animation_speed := 1.0

var _lights: Array[Light3D] = []
var _glowing_materials: Array[StandardMaterial3D] = []
var _water: ShaderMaterial
var _fireflies: ShaderMaterial
var _night := 0.0
var _elapsed := 0.0
var _update_timer := 0.0

func _ready() -> void:
	# Duplicate the materials we animate so preview/game instances stay independent.
	var material_copies: Dictionary = {}
	for node in find_children("*", "GeometryInstance3D", true, false):
		if node.has_meta("glow_material"):
			var source: StandardMaterial3D = node.material_override
			if not material_copies.has(source):
				material_copies[source] = source.duplicate()
				_glowing_materials.append(material_copies[source])
			node.material_override = material_copies[source]
	for node in find_children("*", "Light3D", true, false):
		_lights.append(node)
		node.set_meta("base_energy", node.light_energy)
	_water = get_node("Lake/Water").material_override.duplicate()
	get_node("Lake/Water").material_override = _water
	_fireflies = get_node("Fireflies").material_override.duplicate()
	get_node("Fireflies").material_override = _fireflies
	_bind_clock.call_deferred()
	apply_night(0.0)

func _bind_clock() -> void:
	var cycle := get_tree().get_first_node_in_group(&"day_night_cycle")
	if cycle == null: return
	cycle.night_lighting_changed.connect(apply_night)
	apply_night(cycle.night_lighting)

func apply_night(amount: float) -> void:
	_night = amount
	for light in _lights:
		light.light_energy = float(light.get_meta("base_energy")) * _night * lantern_brightness
		light.visible = light.light_energy > 0.001
	for material in _glowing_materials:
		material.emission_energy_multiplier = float(material.get_meta("glow_energy", 2.0)) * _night * lantern_brightness
	_water.set_shader_parameter("night_amount", amount)
	_fireflies.set_shader_parameter("night_amount", amount if fireflies_enabled else 0.0)
	_fireflies.set_shader_parameter("brightness", firefly_brightness)
	get_node("Fireflies").visible = fireflies_enabled and amount > 0.001

func _process(delta: float) -> void:
	_elapsed += delta * animation_speed
	_update_timer += delta
	if _update_timer < 1.0 / 30.0: return
	_update_timer = 0.0
	_water.set_shader_parameter("elapsed", _elapsed)
	_fireflies.set_shader_parameter("elapsed", _elapsed)
	apply_night(_night) # Remote Inspector tuning also takes effect with a stopped sun.
