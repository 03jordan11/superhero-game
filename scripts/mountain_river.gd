extends Node3D
## City-owned river reach meeting the original solid mountain. Shared waterfront shader, synchronized night/pause behavior.
@export_range(0.0,3.0,0.05) var animation_speed := 1.0
var _elapsed := 0.0
var _water: ShaderMaterial

func _ready() -> void:
	_water = $Water.material_override.duplicate()
	$Water.material_override = _water
	_bind_clock.call_deferred()

func _bind_clock() -> void:
	var clock := get_tree().get_first_node_in_group(&"day_night_cycle")
	if clock != null:
		clock.night_lighting_changed.connect(apply_night)
		apply_night(clock.night_lighting)

func apply_night(amount: float) -> void:
	_water.set_shader_parameter("night_amount",amount)

func _physics_process(delta: float) -> void:
	_elapsed += delta*animation_speed
	_water.set_shader_parameter("elapsed",_elapsed)
