class_name PlayerNormalMovementState
extends PlayerState

## Shared walking, jumping, gravity, and wall-run entry used by the ordinary
## grounded/airborne states. Concrete states keep ownership of their lifecycle.

var _last_published_jump_charge: float = -1.0
var _last_published_ground_speed: float = -1.0
var _last_published_walk_speed: float = -1.0
var _last_published_run_speed: float = -1.0


func enter(_previous_state: PlayerState, _context: Dictionary = {}) -> void:
	_publish_movement_changes(true)


func physics_update(delta: float, input: PlayerInputSnapshot) -> void:
	_update_vertical_movement(delta)
	if player.is_charging_flight:
		player.velocity.x = move_toward(player.velocity.x, 0.0, player.acceleration * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, player.acceleration * delta)
		_publish_movement_changes()
		return
	if _stop_horizontal_movement_if_combat_locked():
		_publish_movement_changes()
		return
	var jump_consumed := player.bounding_controller.handle_jump(input)
	if player.bounding_controller.launched_this_tick:
		_publish_movement_changes()
		return
	if not jump_consumed:
		_update_jump_input(delta, input)
	_apply_horizontal_movement(delta, input)
	if not jump_consumed and input.jump_just_pressed and not player.is_on_floor():
		_try_air_jump()
	_publish_movement_changes()


func _try_air_jump() -> bool:
	if (
		player.is_on_floor() or player.air_jump_used
		or not player.abilities.is_unlocked(PlayerAbilities.AIR_JUMP)
		or player.is_flying or player.is_ground_slamming or player.is_wall_running
		or player.is_dead or player.is_knocked_out or player.is_charging_jump
		or player.combat_controller.is_action_locked()
	):
		return false
	# Add only the power's impulse to horizontal momentum. Replace vertical
	# velocity so even a fast fall produces the same upward launch.
	var impulse := player.movement_motor.get_charged_jump_velocity(
		Vector3.ZERO, -player.transform.basis.z, 1.0,
		player.min_jump_velocity, player.max_jump_velocity,
		player.max_forward_jump_boost,
		player.status_effects.get_movement_speed_multiplier(),
		player.charged_jump_output_multiplier
	) * player.air_jump_power_ratio
	player.velocity.x += impulse.x
	player.velocity.z += impulse.z
	player.velocity.y = impulse.y
	player.air_jump_used = true
	player.is_jump_active = true
	_reset_jump_charge()
	# The new upward launch cancels the fall that preceded it.
	player.landing_impact_controller.reset_normal_landing_tracking()
	player.landing_impact_controller.max_effect_downward_speed = 0.0
	return true


func post_physics_update(_delta: float, input: PlayerInputSnapshot) -> void:
	if self is PlayerGroundedState or self is PlayerAirborneState:
		_sync_grounded_airborne(player.is_on_floor())
	_try_start_wall_run(input)


func _update_vertical_movement(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity = player.movement_motor.apply_gravity(
			player.velocity,
			player.gravity,
			delta
		)
		player.landing_impact_controller.observe_normal_airborne(player.velocity.y)
	elif player.landing_impact_controller.was_airborne:
		player.landing_impact_controller.resolve_normal_landing()
		player.is_jump_active = false


func _stop_horizontal_movement_if_combat_locked() -> bool:
	if not player.combat_controller.is_action_locked() and not player.hostile_grab.blocks_motion():
		return false
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	return true


func _update_jump_input(delta: float, input: PlayerInputSnapshot) -> void:
	if player.is_on_floor():
		if input.jump_pressed:
			player.jump_hold_time += delta
			if player.is_charging_jump:
				player.jump_charge = minf(
					player.jump_charge + delta,
					player.max_jump_charge_time
				)
			elif player.jump_hold_time >= player.power_jump_charge_threshold and player.abilities.is_unlocked(PlayerAbilities.POWER_JUMP):
				state_machine.transition_to(
					&"JumpChargingState",
					{"initial_charge_delta": delta}
				)

		if input.jump_just_released:
			_release_jump()
	elif input.jump_just_released:
		_reset_jump_charge()


func _apply_horizontal_movement(delta: float, input: PlayerInputSnapshot) -> void:
	var direction := player.movement_motor.get_horizontal_direction(
		input.movement,
		player.transform.basis
	)
	var walk_speed := _get_walk_speed()
	var run_speed := _get_run_speed()
	var is_sprinting := input.sprint_pressed and direction.length_squared() > 0.0 and not player.is_charging_jump and player.abilities.is_unlocked(PlayerAbilities.SUPER_SPEED) and player.stamina.request_boost(false)
	var acceleration_multiplier := _get_speed_attribute_multiplier() if is_sprinting else 1.0
	player.current_ground_speed = player.movement_motor.approach_ground_speed(
		player.current_ground_speed,
		walk_speed,
		run_speed,
		is_sprinting,
		player.sprint_acceleration,
		player.sprint_deceleration,
		acceleration_multiplier,
		delta
	)
	var target_speed := (
		player.current_ground_speed
		* player.status_effects.get_movement_speed_multiplier()
		* minf(input.movement.length(), 1.0)
	)

	if player.is_charging_jump:
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		return

	var horizontal_acceleration := player.movement_motor.get_horizontal_acceleration(
		player.acceleration,
		acceleration_multiplier,
		player.air_control_strength,
		player.is_on_floor()
	)
	if player.bounding_controller.preserve_momentum(direction, target_speed, horizontal_acceleration, delta):
		return
	player.velocity = player.movement_motor.approach_horizontal_velocity(
		player.velocity,
		direction,
		target_speed,
		horizontal_acceleration,
		delta
	)


func _release_jump() -> void:
	var was_charging := player.is_charging_jump
	if was_charging:
		var charge_percent := player.jump_charge / player.max_jump_charge_time
		player.velocity = player.movement_motor.get_charged_jump_velocity(
			player.velocity,
			-player.transform.basis.z,
			charge_percent,
			player.min_jump_velocity,
			player.max_jump_velocity,
			player.max_forward_jump_boost,
			player.status_effects.get_movement_speed_multiplier(),
			player.charged_jump_output_multiplier
		)
	else:
		player.velocity = player.movement_motor.get_quick_jump_velocity(
			player.velocity,
			player.min_jump_velocity
		)

	player.is_jump_active = true
	_reset_jump_charge()
	if was_charging and not state_machine.transition_to(&"AirborneState"):
		push_error("Player could not leave JumpChargingState.")


func _reset_jump_charge() -> void:
	player.jump_hold_time = 0.0
	player.jump_charge = 0.0
	player.is_charging_jump = false
	_publish_jump_charge()


func _publish_movement_changes(force: bool = false) -> void:
	_publish_jump_charge(force)
	var walk_speed := _get_walk_speed()
	var run_speed := _get_run_speed()
	if (
		not force
		and is_equal_approx(player.current_ground_speed, _last_published_ground_speed)
		and is_equal_approx(walk_speed, _last_published_walk_speed)
		and is_equal_approx(run_speed, _last_published_run_speed)
	):
		return
	_last_published_ground_speed = player.current_ground_speed
	_last_published_walk_speed = walk_speed
	_last_published_run_speed = run_speed
	player.ground_speed_changed.emit(
		player.current_ground_speed,
		walk_speed,
		run_speed
	)


func _publish_jump_charge(force: bool = false) -> void:
	if (
		not force
		and is_equal_approx(player.jump_charge, _last_published_jump_charge)
	):
		return
	_last_published_jump_charge = player.jump_charge
	player.jump_charge_changed.emit(
		player.jump_charge,
		player.max_jump_charge_time
	)


func _sync_grounded_airborne(is_grounded: bool) -> void:
	var destination := &"GroundedState" if is_grounded else &"AirborneState"
	if state_machine.get_active_state_id() != destination:
		state_machine.transition_to(destination)


func _try_start_wall_run(input: PlayerInputSnapshot) -> void:
	if player.is_charging_flight: return
	var collision_normal := _get_wall_collision_normal()
	if collision_normal == Vector3.ZERO:
		return
	state_machine.transition_to(
		&"WallRunState",
		{
			"collision_normal": collision_normal,
			"input_snapshot": input,
		}
	)


func _get_wall_collision_normal() -> Vector3:
	for collision_index in range(player.get_slide_collision_count()):
		var collision := player.get_slide_collision(collision_index)
		var collision_normal := collision.get_normal()
		if absf(collision_normal.y) < 0.7:
			return collision_normal
	return Vector3.ZERO
