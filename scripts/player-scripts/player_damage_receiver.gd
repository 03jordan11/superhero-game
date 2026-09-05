class_name PlayerDamageReceiver
extends Node

## Owns Player health and damage consequences that do not directly mutate the body.

const HEALTH_COMPONENT_SCRIPT = preload("res://scripts/health_component.gd")

signal health_changed(current_health: float, max_health: float)
signal death_requested(damage_info)
signal hit_slowdown_requested(speed_multiplier: float)
signal flight_knockdown_requested

var health_component
var status_effects: PlayerStatusEffects
var combat_controller: PlayerCombatController
var animation_controller: PlayerAnimationController


func setup(
	initial_max_health: float,
	target_status_effects: PlayerStatusEffects,
	target_combat_controller: PlayerCombatController,
	target_animation_controller: PlayerAnimationController
) -> void:
	status_effects = target_status_effects
	combat_controller = target_combat_controller
	animation_controller = target_animation_controller
	health_component = HEALTH_COMPONENT_SCRIPT.new(initial_max_health)
	health_component.health_changed.connect(_on_health_changed)
	health_component.depleted.connect(_on_health_depleted)


func apply_damage(
	damage_info,
	was_flying: bool,
	flight_knockdown_chance: float,
	is_knocked_out: bool
) -> bool:
	if health_component == null or not health_component.apply_damage(damage_info):
		return false
	if health_component.is_depleted():
		return true

	if status_effects != null:
		hit_slowdown_requested.emit(status_effects.apply_hit_slowdown())
	if was_flying and flight_knockdown_chance > 0.0 and randf() < flight_knockdown_chance:
		flight_knockdown_requested.emit()
	elif (
		animation_controller != null
		and (combat_controller == null or not combat_controller.is_action_locked())
		and not is_knocked_out
	):
		animation_controller.play_hit_reaction()
	return true


func get_current_health() -> float:
	return health_component.current_health if health_component != null else 0.0


func get_max_health() -> float:
	return health_component.max_health if health_component != null else 0.0


func set_max_health(new_max_health: float) -> void:
	if health_component != null:
		health_component.set_max_health(new_max_health)


func _on_health_changed(current_health: float, max_health: float) -> void:
	health_changed.emit(current_health, max_health)


func _on_health_depleted(damage_info) -> void:
	death_requested.emit(damage_info)
