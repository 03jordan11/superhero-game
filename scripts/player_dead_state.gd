class_name PlayerDeadState
extends PlayerState

## Terminal state that preserves the Player's existing death implementation
## while transition ownership moves into the state machine.


func can_exit(_next_state: PlayerState) -> bool:
	return false


func enter(_previous_state: PlayerState, _context: Dictionary = {}) -> void:
	player._enter_dead_state()


func physics_update(delta: float, _input: PlayerInputSnapshot) -> void:
	player._handle_death(delta)
