class_name PlayerStats
extends Resource

## Authoritative Player attributes and their derived gameplay calculations.

signal stat_changed(stat_id: StringName, value: int)
signal experience_changed(current_experience: int, experience_to_next_level: int)
signal level_changed(current_level: int)
signal attribute_points_changed(points: int)

const STRENGTH: StringName = &"strength"
const SPEED: StringName = &"speed"
const RESILIENCE: StringName = &"resilience"
const MIN_ATTRIBUTE_VALUE: int = 1
const MIN_LEVEL: int = 1
const BASE_EXPERIENCE_TO_LEVEL: int = 100
## Saturate at the storage limit instead of overflowing signed 64-bit integers.
const MAX_PROGRESSION_VALUE: int = 0x7fffffffffffffff
const FIRST_SATURATED_REQUIREMENT_LEVEL: int = 58
var _power_bonuses: Dictionary[StringName, int] = {STRENGTH: 0, SPEED: 0}

@export_category("Progression")
@export var level: int = MIN_LEVEL:
	set(value):
		var normalized_value := maxi(value, MIN_LEVEL)
		if level == normalized_value:
			return
		level = normalized_value
		level_changed.emit(level)

@export var experience: int = 0:
	set(value):
		var normalized_value := maxi(value, 0)
		if experience == normalized_value:
			return
		experience = normalized_value
		experience_changed.emit(experience, get_experience_to_next_level())

@export var money: int = 0
@export var attribute_points: int = 0:
	set(value):
		var normalized := maxi(value, 0)
		if attribute_points == normalized: return
		attribute_points = normalized
		attribute_points_changed.emit(attribute_points)

@export_category("Attributes")
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


func can_upgrade_attribute(attribute: StringName) -> bool:
	return attribute in [STRENGTH, SPEED, RESILIENCE] and attribute_points > 0 and int(get(attribute)) < MAX_PROGRESSION_VALUE


func upgrade_attribute(attribute: StringName) -> bool:
	if not can_upgrade_attribute(attribute): return false
	attribute_points -= 1
	set(attribute, int(get(attribute)) + 1)
	return true


func _earn_level() -> void:
	# Award only from XP progression, never from loading or editing the level.
	attribute_points += mini(1, MAX_PROGRESSION_VALUE - attribute_points)
	level += 1


func set_power_bonuses(strength_bonus: int, speed_bonus: int) -> void:
	var next := {STRENGTH: maxi(strength_bonus, 0), SPEED: maxi(speed_bonus, 0)}
	var changed: Array[StringName] = []
	for attribute in next:
		if _power_bonuses[attribute] != next[attribute]: changed.append(attribute)
		_power_bonuses[attribute] = next[attribute]
	# Base attributes remain editable/savable; listeners re-read effective values.
	for attribute in changed: stat_changed.emit(attribute, get(attribute))


func get_power_bonus(attribute: StringName) -> int:
	if not _power_bonuses.has(attribute): return 0
	return mini(_power_bonuses[attribute], MAX_PROGRESSION_VALUE - int(get(attribute)))


func get_effective_strength() -> int:
	return strength + get_power_bonus(STRENGTH)


func get_effective_speed() -> int:
	return speed + get_power_bonus(SPEED)


func get_experience_to_next_level() -> int:
	if level >= FIRST_SATURATED_REQUIREMENT_LEVEL:
		return MAX_PROGRESSION_VALUE
	return BASE_EXPERIENCE_TO_LEVEL << (level - MIN_LEVEL)


func add_experience(amount: int) -> void:
	var remaining_experience := maxi(amount, 0)
	while level < MAX_PROGRESSION_VALUE and experience >= get_experience_to_next_level():
		experience -= get_experience_to_next_level()
		_earn_level()

	while remaining_experience > 0:
		if level == MAX_PROGRESSION_VALUE:
			experience += mini(remaining_experience, MAX_PROGRESSION_VALUE - experience)
			return
		var experience_needed := get_experience_to_next_level() - experience
		if remaining_experience < experience_needed:
			experience += remaining_experience
			return

		remaining_experience -= experience_needed
		experience = 0
		_earn_level()


func get_run_speed(
	minimum_run_speed: float,
	run_speed_per_attribute_point: float
) -> float:
	return (
		minimum_run_speed
		+ float(get_effective_speed() - MIN_ATTRIBUTE_VALUE) * run_speed_per_attribute_point
	)


func get_walk_speed(
	minimum_run_speed: float,
	_run_speed_per_attribute_point: float,
	walk_speed_ratio: float
) -> float:
	# Ordinary movement and normal flight stay independent of Speed.
	return minimum_run_speed * clampf(walk_speed_ratio, 0.1, 1.0)


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
