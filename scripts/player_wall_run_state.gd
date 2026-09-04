class_name PlayerWallRunState
extends PlayerState

## Owns wall-run eligibility and lifecycle while delegating the preserved wall
## probes and velocity formulas to the Player during incremental migration.


func can_enter(_previous_state: PlayerState, context: Dictionary = {}) -> bool:
	return player._can_enter_wall_run_state(context)


func enter(_previous_state: PlayerState, context: Dictionary = {}) -> void:
	player._enter_wall_run_state(context)


func exit(_next_state: PlayerState) -> void:
	player._exit_wall_run_state()


func physics_update(delta: float, input: PlayerInputSnapshot) -> void:
	player._handle_wall_run(delta, input)
