class_name PlayerStats
extends Resource

## Authoritative Player attributes and their derived gameplay calculations.

signal stat_changed(stat_id: StringName, value: int)

const STRENGTH: StringName = &"strength"
const SPEED: StringName = &"speed"
const RESILIENCE: StringName = &"resilience"
const MIN_ATTRIBUTE_VALUE: int = 1

@export var strength: int = MIN_ATTRIBUTE_VALUE:
	set(value):
		var normalized_value := maxi(value, MIN_ATTRIBUTE_VALUE)
		if strength == normalized_value:
			return
		strength = normalized_value
		stat_changed.emit(STRENGTH, strength)

@export var speed: int = MIN_ATTRIBUTE_VALUE:
	set(value):
		var normalized_value := maxi(value, MIN_ATTRIBUTE_VALUE)
		if speed == normalized_value:
			return
		speed = normalized_value
		stat_changed.emit(SPEED, speed)

@export var resilience: int = MIN_ATTRIBUTE_VALUE:
	set(value):
		var normalized_value := maxi(value, MIN_ATTRIBUTE_VALUE)
		if resilience == normalized_value:
			return
		resilience = normalized_value
		stat_changed.emit(RESILIENCE, resilience)


func get_max_health(health_per_resilience: float) -> float:
	return maxf(health_per_resilience, 1.0) * float(resilience)


func get_run_speed(
	minimum_run_speed: float,
	run_speed_per_attribute_point: float
) -> float:
	return (
		minimum_run_speed
		+ float(speed - MIN_ATTRIBUTE_VALUE) * run_speed_per_attribute_point
	)


func get_walk_speed(
	minimum_run_speed: float,
	run_speed_per_attribute_point: float,
	walk_speed_ratio: float
) -> float:
	return get_run_speed(
		minimum_run_speed,
		run_speed_per_attribute_point
	) * clampf(walk_speed_ratio, 0.1, 1.0)


func get_speed_multiplier(
	minimum_run_speed: float,
	run_speed_per_attribute_point: float
) -> float:
	return get_run_speed(
		minimum_run_speed,
		run_speed_per_attribute_point
	) / maxf(minimum_run_speed, 0.001)


func get_flight_knockdown_chance(
	resilience_one_knockdown_chance: float,
	knockdown_immunity_resilience: int
) -> float:
	var immunity_resilience := maxi(knockdown_immunity_resilience, 2)
	var resilience_weight := inverse_lerp(
		1.0,
		float(immunity_resilience),
		float(resilience)
	)
	return lerpf(
		clampf(resilience_one_knockdown_chance, 0.0, 1.0),
		0.0,
		clampf(resilience_weight, 0.0, 1.0)
	)
