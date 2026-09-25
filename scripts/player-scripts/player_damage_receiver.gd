class_name PlayerDamageReceiver
extends Node

## Owns Player health and damage consequences that do not directly mutate the body.

const HEALTH_COMPONENT_SCRIPT = preload("res://scripts/health_component.gd")

signal health_changed(current_health: float, max_health: float)
signal death_requested(damage_info)
signal hit_slowdown_requested(speed_multiplier: float)
signal flight_knockdown_requested
signal damage_received(damage_info)

@export_category("Preservation")
@export_range(0.0, 60.0, 0.1, "suffix:s") var regeneration_delay := 5.0
@export_range(0.0, 100.0, 0.1, "suffix:HP/s") var regeneration_rate := 1.0
var regeneration_enabled := false
var regeneration_cooldown := 0.0

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
	regeneration_cooldown = regeneration_delay


func _physics_process(delta: float) -> void:
	update_regeneration(delta)


func update_regeneration(delta: float) -> void:
	if health_component == null or delta <= 0.0: return
	var waiting_time := regeneration_cooldown
	regeneration_cooldown = maxf(0.0, regeneration_cooldown - delta)
	if not regeneration_enabled: return
	# Only heal for the part of this tick after the delay expires.
	var healing_time := maxf(0.0, delta - waiting_time)
	health_component.heal(healing_time * regeneration_rate)


func apply_damage(
	damage_info,
	was_flying: bool,
	flight_knockdown_chance: float,
	is_knocked_out: bool
) -> bool:
	# Protect the entire evade, counter opportunity, and counter recovery before
	# health, damage signals, hit reactions, or slowdown can interrupt the action.
	if get_parent() is PlayerCharacter and get_parent().anticipation.active():
		return false
	if get_parent() is PlayerCharacter and get_parent().is_dodging:
		return false
	if health_component == null or not health_component.apply_damage(damage_info):
		return false
	regeneration_cooldown = regeneration_delay
	damage_received.emit(damage_info)
	if health_component.is_depleted():
		return true
	# Protected elemental casts have reaction armor. Damage, death,
	# regeneration delay and Reactive Shock have already been resolved normally.
	if get_parent() is PlayerCharacter and (get_parent().lightning_strike.casting or get_parent().external_combustion.casting or get_parent().frost_wall.casting):
		return true
	# Taking damage still costs health and plays impact audio. A committed melee
	# attack has armor against bullet flinches/slowdown so it can reach its target.
	if damage_info.damage_type == &"bullet" and combat_controller != null and combat_controller.is_action_locked():
		return true

	if status_effects != null:
		hit_slowdown_requested.emit(status_effects.apply_hit_slowdown())
	if was_flying and flight_knockdown_chance > 0.0 and randf() < flight_knockdown_chance:
		flight_knockdown_requested.emit()
	elif (
		animation_controller != null
		and (combat_controller == null or not combat_controller.is_action_locked())
		and not (get_parent() is PlayerCharacter and get_parent().hostile_grab.owns_animation())
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


func restore_full_health() -> void:
	if health_component != null:
		health_component.restore_full_health()


func _on_health_depleted(damage_info) -> void:
	death_requested.emit(damage_info)
