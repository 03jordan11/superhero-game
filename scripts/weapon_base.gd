class_name WeaponBase
extends Resource

@export var max_damage: float = 0.0
@export var min_damage: float = 0.0
@export var falloff_start_distance: float = 0.0
@export var falloff_end_distance: float = 0.0
@export var maximum_hit_distance: float = 0.0
@export_range(0.0, 1.0, 0.01) var close_stationary_hit_chance: float = 0.0
@export_range(0.0, 1.0, 0.01) var close_moving_hit_chance: float = 0.0
@export_range(0.0, 1.0, 0.01) var minimum_hit_chance: float = 0.0
@export var accuracy_falloff_start_distance: float = 0.0


func can_hit_at_distance(distance: float) -> bool:
	return distance >= 0.0 and distance <= maximum_hit_distance


func calculate_damage(distance: float) -> float:
	if not can_hit_at_distance(distance):
		return 0.0
	if distance <= falloff_start_distance:
		return max_damage
	if falloff_end_distance <= falloff_start_distance:
		return min_damage

	var falloff_weight := inverse_lerp(
		falloff_start_distance,
		falloff_end_distance,
		distance
	)
	return lerpf(max_damage, min_damage, clampf(falloff_weight, 0.0, 1.0))


func calculate_hit_chance(distance: float, target_is_moving_horizontally: bool) -> float:
	if not can_hit_at_distance(distance):
		return 0.0

	var close_hit_chance := (
		close_moving_hit_chance
		if target_is_moving_horizontally
		else close_stationary_hit_chance
	)
	if distance <= accuracy_falloff_start_distance:
		return clampf(close_hit_chance, 0.0, 1.0)
	if maximum_hit_distance <= accuracy_falloff_start_distance:
		return clampf(minimum_hit_chance, 0.0, 1.0)

	var falloff_weight := inverse_lerp(
		accuracy_falloff_start_distance,
		maximum_hit_distance,
		distance
	)
	return lerpf(
		close_hit_chance,
		minimum_hit_chance,
		clampf(falloff_weight, 0.0, 1.0)
	)
