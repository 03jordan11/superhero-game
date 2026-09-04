class_name PlayerGroundSlamState
extends PlayerState

## Owns ground-slam eligibility and lifecycle while delegating the preserved
## descent formula to the Player during the incremental migration.


func can_enter(_previous_state: PlayerState, context: Dictionary = {}) -> bool:
	return player._can_enter_ground_slam_state(context)


func enter(_previous_state: PlayerState, context: Dictionary = {}) -> void:
	player._enter_ground_slam_state(context)


func exit(_next_state: PlayerState) -> void:
	player._exit_ground_slam_state()


func physics_update(_delta: float, _input: PlayerInputSnapshot) -> void:
	player._handle_ground_slam()
