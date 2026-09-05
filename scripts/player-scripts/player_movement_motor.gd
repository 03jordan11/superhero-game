class_name PlayerMovementMotor
extends Node

## Calculates shared horizontal movement without owning Player state or input.


func get_horizontal_direction(input: Vector2, movement_basis: Basis) -> Vector3:
	return (
		movement_basis * Vector3(input.x, 0.0, input.y)
	).normalized()


func get_flight_direction(
	input: Vector2,
	vertical_input: float,
	camera_basis: Basis
) -> Vector3:
	var camera_right := camera_basis.x
	var camera_forward := -camera_basis.z
	return (
		camera_right * input.x
		- camera_forward * input.y
		+ Vector3.UP * vertical_input
	).normalized()


func apply_gravity(
	current_velocity: Vector3,
	gravity_strength: float,
	delta: float
) -> Vector3:
	var next_velocity := current_velocity
	next_velocity.y -= gravity_strength * delta
	return next_velocity


func approach_ground_speed(
	current_speed: float,
	walk_speed: float,
	run_speed: float,
	is_sprinting: bool,
	sprint_acceleration: float,
	sprint_deceleration: float,
	speed_multiplier: float,
	delta: float
) -> float:
	var next_speed := maxf(current_speed, walk_speed)
	var target_speed := run_speed if is_sprinting else walk_speed
	var change_rate := sprint_acceleration if is_sprinting else sprint_deceleration
	return move_toward(
		next_speed,
		target_speed,
		change_rate * speed_multiplier * delta
	)


func approach_flight_speed(
	current_speed: float,
	base_speed: float,
	maximum_speed: float,
	is_sprinting: bool,
	flight_acceleration: float,
	flight_deceleration: float,
	speed_multiplier: float,
	delta: float
) -> float:
	if is_sprinting:
		return move_toward(
			current_speed,
			maximum_speed,
			flight_acceleration * speed_multiplier * delta
		)

	return maxf(
		base_speed,
		move_toward(
			current_speed,
			base_speed,
			flight_deceleration * speed_multiplier * delta
		)
	)


func approach_hover_velocity(
	current_velocity: Vector3,
	stop_deceleration: float,
	speed_multiplier: float,
	delta: float
) -> Vector3:
	return current_velocity.move_toward(
		Vector3.ZERO,
		stop_deceleration * speed_multiplier * delta
	)


func get_ground_slam_velocity(
	current_position: Vector3,
	target_position: Vector3,
	ground_slam_speed: float,
	speed_multiplier: float
) -> Vector3:
	return (
		current_position.direction_to(target_position)
		* ground_slam_speed
		* speed_multiplier
	)


func get_wall_run_velocity(
	wall_normal: Vector3,
	player_right: Vector3,
	lateral_input: float,
	vertical_speed: float,
	stick_speed: float,
	lateral_speed: float,
	attribute_speed_multiplier: float,
	movement_speed_multiplier: float
) -> Vector3:
	var lateral_velocity := Vector3.ZERO
	if absf(lateral_input) > 0.0:
		var desired_side_direction := player_right * lateral_input
		var wall_tangent := desired_side_direction - (
			wall_normal * desired_side_direction.dot(wall_normal)
		)
		if wall_tangent.length_squared() > 0.0:
			lateral_velocity = (
				wall_tangent.normalized()
				* lateral_speed
				* attribute_speed_multiplier
			)

	return (
		Vector3.UP
		* vertical_speed
		* attribute_speed_multiplier
		* movement_speed_multiplier
		- wall_normal * stick_speed
		+ lateral_velocity * movement_speed_multiplier
	)


func get_quick_jump_velocity(
	current_velocity: Vector3,
	jump_velocity: float
) -> Vector3:
	var launch_velocity := current_velocity
	launch_velocity.y = jump_velocity
	return launch_velocity


func get_charged_jump_velocity(
	current_velocity: Vector3,
	forward_direction: Vector3,
	charge_percent: float,
	minimum_jump_velocity: float,
	maximum_jump_velocity: float,
	maximum_forward_boost: float,
	movement_speed_multiplier: float
) -> Vector3:
	var launch_velocity := current_velocity
	launch_velocity.y = lerpf(
		minimum_jump_velocity,
		maximum_jump_velocity,
		charge_percent
	)

	var forward_boost := (
		maximum_forward_boost
		* charge_percent
		* movement_speed_multiplier
	)
	var normalized_forward := forward_direction.normalized()
	launch_velocity.x += normalized_forward.x * forward_boost
	launch_velocity.z += normalized_forward.z * forward_boost
	return launch_velocity


func get_horizontal_acceleration(
	base_acceleration: float,
	speed_multiplier: float,
	air_control_strength: float,
	is_grounded: bool
) -> float:
	var horizontal_acceleration := base_acceleration * speed_multiplier
	if not is_grounded:
		horizontal_acceleration *= air_control_strength
	return horizontal_acceleration


func approach_horizontal_velocity(
	current_velocity: Vector3,
	direction: Vector3,
	target_speed: float,
	horizontal_acceleration: float,
	delta: float
) -> Vector3:
	var next_velocity := current_velocity
	var target_horizontal_velocity := Vector3.ZERO
	if direction.length_squared() > 0.0:
		target_horizontal_velocity = direction * target_speed

	var velocity_step := horizontal_acceleration * delta
	next_velocity.x = move_toward(
		next_velocity.x,
		target_horizontal_velocity.x,
		velocity_step
	)
	next_velocity.z = move_toward(
		next_velocity.z,
		target_horizontal_velocity.z,
		velocity_step
	)
	return next_velocity
