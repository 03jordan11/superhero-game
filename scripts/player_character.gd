class_name PlayerCharacter
extends CharacterBody3D

## Typed coordinator contract used by Player states during migration.
## res://player.gd currently provides the concrete implementation.


func _can_enter_flying_state() -> bool:
	return false


func _enter_flying_state() -> void:
	pass


func _exit_flying_state() -> void:
	pass


func _handle_flight(_delta: float, _input: PlayerInputSnapshot) -> void:
	pass


func _can_enter_ground_slam_state(_context: Dictionary) -> bool:
	return false


func _enter_ground_slam_state(_context: Dictionary) -> void:
	pass


func _exit_ground_slam_state() -> void:
	pass


func _handle_ground_slam() -> void:
	pass


func _can_enter_wall_run_state(_context: Dictionary) -> bool:
	return false


func _enter_wall_run_state(_context: Dictionary) -> void:
	pass


func _exit_wall_run_state() -> void:
	pass


func _handle_wall_run(_delta: float, _input: PlayerInputSnapshot) -> void:
	pass


func _can_enter_jump_charging_state() -> bool:
	return false


func _enter_jump_charging_state(_context: Dictionary) -> void:
	pass


func _reset_jump_charge() -> void:
	pass


func _update_normal_vertical_movement(_delta: float) -> void:
	pass


func _stop_horizontal_movement_if_fighting() -> bool:
	return false


func _update_normal_jump_input(
	_delta: float,
	_input: PlayerInputSnapshot
) -> void:
	pass


func _apply_normal_horizontal_movement(
	_delta: float,
	_input: PlayerInputSnapshot
) -> void:
	pass


func _enter_knocked_down_state(_context: Dictionary) -> void:
	pass


func _exit_knocked_down_state() -> void:
	pass


func _handle_knockout(_delta: float) -> void:
	pass


func _enter_dead_state() -> void:
	pass


func _handle_death(_delta: float) -> void:
	pass
