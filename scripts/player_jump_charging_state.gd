class_name PlayerJumpChargingState
extends PlayerState

## Owns the charged-jump lifecycle and update sequence while using Player
## helpers for shared body mutations during the incremental migration.


func can_enter(previous_state: PlayerState, _context: Dictionary = {}) -> bool:
	return (
		previous_state is PlayerGroundedState
		and player._can_enter_jump_charging_state()
	)


func enter(_previous_state: PlayerState, context: Dictionary = {}) -> void:
	player._enter_jump_charging_state(context)


func exit(_next_state: PlayerState) -> void:
	player._reset_jump_charge()


func physics_update(delta: float, input: PlayerInputSnapshot) -> void:
	player._update_normal_vertical_movement(delta)
	if player._stop_horizontal_movement_if_fighting():
		return
	player._update_normal_jump_input(delta, input)
	player._apply_normal_horizontal_movement(delta, input)
