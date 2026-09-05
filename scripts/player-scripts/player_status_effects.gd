class_name PlayerStatusEffects
extends Node

## Owns temporary gameplay modifiers that affect Player movement.

@export_category("Hit Slowdown")
@export var hit_slowdown_duration: float = 0.5
@export_range(0.0, 1.0, 0.05) var hit_slowdown_multiplier: float = 0.5

var hit_slowdown_remaining: float = 0.0


func apply_hit_slowdown() -> float:
	hit_slowdown_remaining = maxf(hit_slowdown_duration, 0.0)
	return get_movement_speed_multiplier()


func update(delta: float) -> void:
	hit_slowdown_remaining = maxf(hit_slowdown_remaining - delta, 0.0)


func get_movement_speed_multiplier() -> float:
	if hit_slowdown_remaining <= 0.0:
		return 1.0
	return clampf(hit_slowdown_multiplier, 0.0, 1.0)
