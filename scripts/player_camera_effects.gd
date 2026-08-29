extends Node

@export_category("Landing Camera Effects")
@export var landing_shake_threshold: float = 12.0
@export var landing_shake_max_speed: float = 30.0
@export var maximum_shake_distance: float = 0.24
@export var shake_duration: float = 0.32
@export var maximum_shake_duration: float = 0.55
@export var maximum_impact_kick: float = 0.4
@export var impact_kick_recovery_speed: float = 1.8

var spring_arm: SpringArm3D
var base_spring_arm_position: Vector3
var shake_time_remaining: float = 0.0
var shake_strength: float = 0.0
var active_shake_duration: float = 0.0
var impact_kick_offset: float = 0.0


func setup(target_spring_arm: SpringArm3D) -> void:
	spring_arm = target_spring_arm
	base_spring_arm_position = spring_arm.position


func trigger_landing(max_downward_speed: float) -> void:
	if max_downward_speed < landing_shake_threshold:
		return

	var impact_percent := inverse_lerp(
		landing_shake_threshold,
		landing_shake_max_speed,
		max_downward_speed
	)
	impact_percent = clampf(impact_percent, 0.0, 1.0)
	shake_strength = maximum_shake_distance * impact_percent
	active_shake_duration = lerpf(shake_duration, maximum_shake_duration, impact_percent)
	shake_time_remaining = active_shake_duration
	impact_kick_offset = maxf(impact_kick_offset, maximum_impact_kick * impact_percent)


func trigger_knockout() -> void:
	# A full-speed flight collision should always read as a maximum camera impact.
	trigger_landing(landing_shake_max_speed)


func _process(delta: float) -> void:
	if spring_arm == null:
		return

	var shake_offset := Vector3.ZERO
	if shake_time_remaining > 0.0:
		shake_time_remaining = maxf(shake_time_remaining - delta, 0.0)
		var fade := shake_time_remaining / maxf(active_shake_duration, 0.001)
		shake_offset = Vector3(
			randf_range(-shake_strength, shake_strength) * fade,
			randf_range(-shake_strength, shake_strength) * fade,
			0.0
		)

	impact_kick_offset = move_toward(
		impact_kick_offset,
		0.0,
		impact_kick_recovery_speed * delta
	)
	spring_arm.position = base_spring_arm_position + shake_offset + Vector3.UP * impact_kick_offset
