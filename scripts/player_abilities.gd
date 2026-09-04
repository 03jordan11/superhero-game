class_name PlayerAbilities
extends Resource

## Unlock state for traversal powers. Defaults preserve the prototype's current
## behavior while allowing progression systems to lock or unlock each power.

signal ability_changed(ability_id: StringName, is_unlocked: bool)

const FLIGHT: StringName = &"flight"
const WALL_RUN: StringName = &"wall_run"
const GROUND_SLAM: StringName = &"ground_slam"
const POWER_JUMP: StringName = &"power_jump"

@export var flight_unlocked: bool = true
@export var wall_run_unlocked: bool = true
@export var ground_slam_unlocked: bool = true
@export var power_jump_unlocked: bool = true


func is_unlocked(ability_id: StringName) -> bool:
	match ability_id:
		FLIGHT:
			return flight_unlocked
		WALL_RUN:
			return wall_run_unlocked
		GROUND_SLAM:
			return ground_slam_unlocked
		POWER_JUMP:
			return power_jump_unlocked
		_:
			return false


func set_unlocked(ability_id: StringName, is_ability_unlocked: bool) -> bool:
	if not _has_ability(ability_id) or is_unlocked(ability_id) == is_ability_unlocked:
		return false

	match ability_id:
		FLIGHT:
			flight_unlocked = is_ability_unlocked
		WALL_RUN:
			wall_run_unlocked = is_ability_unlocked
		GROUND_SLAM:
			ground_slam_unlocked = is_ability_unlocked
		POWER_JUMP:
			power_jump_unlocked = is_ability_unlocked

	ability_changed.emit(ability_id, is_ability_unlocked)
	return true


func _has_ability(ability_id: StringName) -> bool:
	return ability_id in [FLIGHT, WALL_RUN, GROUND_SLAM, POWER_JUMP]
