class_name PlayerKnockedDownState
extends PlayerState

## Owns knockdown entry, rebound movement, landing stun, recovery, and exit.


func enter(_previous_state: PlayerState, context: Dictionary = {}) -> void:
	player.is_flying = false
	player.is_ground_slamming = false
	player.is_knocked_out = true
	player.has_knockout_landed = false
	player.knockout_stun_remaining = 0.0
	player.current_flight_speed = 0.0
	player.combat_controller.cancel_punch()

	if context.get("cause") == &"flight_collision":
		var collision_normal: Vector3 = context.get("collision_normal", Vector3.ZERO)
		var collision_position: Vector3 = context.get(
			"collision_position",
			player.global_position
		)
		var impact_speed: float = context.get("impact_speed", 0.0)
		player.velocity = collision_normal * player.flight_knockout_rebound_speed
		player.velocity.y += player.flight_knockout_rebound_upward_speed
		player.camera_effects.call("trigger_knockout")
		player.landing_impact_controller.spawn_hard_landing_effect(
			impact_speed,
			collision_position,
			collision_normal
		)
	else:
		player.velocity.y = minf(player.velocity.y, 0.0)
	player.animation_controller.play_knockdown()


func exit(_next_state: PlayerState) -> void:
	player.is_knocked_out = false
	player.has_knockout_landed = false
	player.knockout_stun_remaining = 0.0
	player.velocity = Vector3.ZERO


func physics_update(delta: float, _input: PlayerInputSnapshot) -> void:
	if player.has_knockout_landed:
		player.velocity = Vector3.ZERO
		player.knockout_stun_remaining = maxf(
			player.knockout_stun_remaining - delta,
			0.0
		)
		if player.knockout_stun_remaining <= 0.0:
			_finish_knockout()
		return

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
	player.velocity = player.movement_motor.apply_gravity(
		player.velocity,
		player.gravity,
		delta
	)


func post_physics_update(_delta: float, _input: PlayerInputSnapshot) -> void:
	if player.is_on_floor():
		_begin_knockout_stun()


func _begin_knockout_stun() -> void:
	if player.has_knockout_landed:
		return
	player.has_knockout_landed = true
	player.knockout_stun_remaining = maxf(player.knockdown_stun_duration, 0.0)
	player.velocity = Vector3.ZERO
	if player.knockout_stun_remaining <= 0.0:
		_finish_knockout()


func _finish_knockout() -> void:
	if not state_machine.transition_to(&"GroundedState"):
		push_error("Player could not leave KnockedDownState.")
