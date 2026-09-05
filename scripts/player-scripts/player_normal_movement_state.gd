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
	if _stop_horizontal_movement_if_combat_locked():
		_publish_movement_changes()
		return
	_update_jump_input(delta, input)
	_apply_horizontal_movement(delta, input)
	_publish_movement_changes()


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
	if not player.combat_controller.is_action_locked():
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
			elif player.jump_hold_time >= player.power_jump_charge_threshold:
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
	var is_sprinting := input.sprint_pressed and direction.length_squared() > 0.0
	player.current_ground_speed = player.movement_motor.approach_ground_speed(
		player.current_ground_speed,
		walk_speed,
		run_speed,
		is_sprinting,
		player.sprint_acceleration,
		player.sprint_deceleration,
		_get_speed_attribute_multiplier(),
		delta
	)
	var target_speed := (
		player.current_ground_speed
		* player.status_effects.get_movement_speed_multiplier()
	)

	if player.is_charging_jump:
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		return

	var horizontal_acceleration := player.movement_motor.get_horizontal_acceleration(
		player.acceleration,
		_get_speed_attribute_multiplier(),
		player.air_control_strength,
		player.is_on_floor()
	)
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
			player.status_effects.get_movement_speed_multiplier()
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
