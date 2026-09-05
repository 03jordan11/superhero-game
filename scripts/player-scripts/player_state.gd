class_name PlayerState
extends Node

## Shared contract for mutually exclusive Player locomotion and life states.

@export var state_id: StringName

var player: PlayerCharacter
var state_machine: PlayerStateMachine


func setup(target_player: PlayerCharacter, target_state_machine: PlayerStateMachine) -> void:
	player = target_player
	state_machine = target_state_machine


func get_state_id() -> StringName:
	if state_id != &"":
		return state_id
	return StringName(name)


func can_enter(_previous_state: PlayerState, _context: Dictionary = {}) -> bool:
	return true


func can_exit(_next_state: PlayerState) -> bool:
	return true


func enter(_previous_state: PlayerState, _context: Dictionary = {}) -> void:
	pass


func exit(_next_state: PlayerState) -> void:
	pass


func handle_input(_input: PlayerInputSnapshot) -> void:
	pass


func physics_update(_delta: float, _input: PlayerInputSnapshot) -> void:
	pass


func post_physics_update(_delta: float, _input: PlayerInputSnapshot) -> void:
	pass


func _get_run_speed() -> float:
	return player.stats.get_run_speed(
		player.minimum_run_speed,
		player.run_speed_per_attribute_point
	)


func _get_walk_speed() -> float:
	return player.stats.get_walk_speed(
		player.minimum_run_speed,
		player.run_speed_per_attribute_point,
		player.walk_speed_ratio
	)


func _get_speed_attribute_multiplier() -> float:
	return player.stats.get_speed_multiplier(
		player.minimum_run_speed,
		player.run_speed_per_attribute_point
	)
