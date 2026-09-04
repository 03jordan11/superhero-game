class_name PlayerKnockedDownState
extends PlayerState

## Owns the knockdown lifecycle while delegating the preserved movement and
## stun calculations to the Player during the incremental migration.


func enter(_previous_state: PlayerState, context: Dictionary = {}) -> void:
	player._enter_knocked_down_state(context)


func exit(_next_state: PlayerState) -> void:
	player._exit_knocked_down_state()


func physics_update(delta: float, _input: PlayerInputSnapshot) -> void:
	player._handle_knockout(delta)
