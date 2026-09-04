class_name PlayerGroundedState
extends PlayerState

## Owns the grounded update sequence while using Player helpers for shared body
## mutations during the incremental migration.


func physics_update(delta: float, input: PlayerInputSnapshot) -> void:
	player._update_normal_vertical_movement(delta)
	if player._stop_horizontal_movement_if_fighting():
		return
	player._update_normal_jump_input(delta, input)
	player._apply_normal_horizontal_movement(delta, input)
