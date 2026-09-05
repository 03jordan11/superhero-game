class_name PlayerAbilities
extends Resource

## Unlock state for traversal powers. Add an ID to `unlocked_abilities` to
## register a new lockable power. Missing IDs are always treated as locked.

signal ability_changed(ability_id: StringName, is_unlocked: bool)

const FLIGHT: StringName = &"flight"
const WALL_RUN: StringName = &"wall_run"
const GROUND_SLAM: StringName = &"ground_slam"
const POWER_JUMP: StringName = &"power_jump"
const ICE: StringName = &"ice"
const LASER_EYES: StringName = &"laser_eyes"
const TELEKINESIS: StringName = &"telekinesis"
const ELECTRICITY: StringName = &"electricity"
const FIRE: StringName = &"fire"

## The single source of truth for powers available to this player.
## Add entries in the form &"ability_id": true or false.
@export var unlocked_abilities: Dictionary[StringName, bool] = {
	FLIGHT: true,
	WALL_RUN: true,
	GROUND_SLAM: true,
	POWER_JUMP: true,
	ICE: true,
	LASER_EYES: true,
	TELEKINESIS: true,
	ELECTRICITY: true,
	FIRE: true,
}


func is_unlocked(ability_id: StringName) -> bool:
	return bool(unlocked_abilities.get(ability_id, false))


func set_unlocked(ability_id: StringName, is_ability_unlocked: bool) -> bool:
	if not _has_ability(ability_id) or is_unlocked(ability_id) == is_ability_unlocked:
		return false

	unlocked_abilities[ability_id] = is_ability_unlocked
	ability_changed.emit(ability_id, is_ability_unlocked)
	return true


func _has_ability(ability_id: StringName) -> bool:
	return unlocked_abilities.has(ability_id)
