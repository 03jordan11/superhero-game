class_name PlayerDeadState
extends PlayerState

## Terminal state that owns death cleanup and body settling.


func can_exit(_next_state: PlayerState) -> bool:
	return false


func enter(_previous_state: PlayerState, _context: Dictionary = {}) -> void:
	player.is_dead = true
	player.is_flying = false
	player.is_ground_slamming = false
	player.is_knocked_out = true
	player.is_wall_running = false
	player.has_knockout_landed = false
	player.knockout_stun_remaining = 0.0
	player.current_flight_speed = 0.0
	player.is_charging_jump = false
	player.is_jump_active = false
	player.jump_charge = 0.0
	player.jump_hold_time = 0.0
	player.velocity.y = minf(player.velocity.y, 0.0)
	if player.vehicle_interactor.has_held_vehicle():
		player.vehicle_interactor.drop_held_vehicle()
	player.combat_controller.cancel_punch()
	player.animation_controller.play_death()


func physics_update(delta: float, _input: PlayerInputSnapshot) -> void:
	player.velocity.x = move_toward(
		player.velocity.x,
		0.0,
		player.flight_knockout_rebound_deceleration * delta
	)
	player.velocity.z = move_toward(
		player.velocity.z,
		0.0,
		player.flight_knockout_rebound_deceleration * delta
	)
	if not player.is_on_floor():
		player.velocity = player.movement_motor.apply_gravity(
			player.velocity,
			player.gravity,
			delta
		)
	else:
		player.velocity = Vector3.ZERO
