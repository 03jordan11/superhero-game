class_name PlayerFlyingState
extends PlayerState

## Owns the flight lifecycle while delegating the preserved movement formulas
## to the Player during the incremental migration.


func can_enter(_previous_state: PlayerState, _context: Dictionary = {}) -> bool:
	return player._can_enter_flying_state()


func enter(_previous_state: PlayerState, _context: Dictionary = {}) -> void:
	player._enter_flying_state()


func exit(_next_state: PlayerState) -> void:
	player._exit_flying_state()


func physics_update(delta: float, input: PlayerInputSnapshot) -> void:
	player._handle_flight(delta, input)
