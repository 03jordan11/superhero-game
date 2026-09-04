extends SceneTree


func _initialize() -> void:
	_test_calculations()
	_test_player_integration.call_deferred()


func _test_calculations() -> void:
	var motor := PlayerMovementMotor.new()

	var diagonal_direction := motor.get_horizontal_direction(
		Vector2(1.0, -1.0),
		Basis.IDENTITY
	)
	assert(diagonal_direction.is_normalized())
	assert(diagonal_direction.is_equal_approx(
		Vector3(1.0, 0.0, -1.0).normalized()
	))

	var turned_basis := Basis(
		Vector3(0.0, 0.0, -1.0),
		Vector3.UP,
		Vector3(1.0, 0.0, 0.0)
	)
	var turned_direction := motor.get_horizontal_direction(
		Vector2(0.0, -1.0),
		turned_basis
	)
	assert(turned_direction.is_equal_approx(Vector3.LEFT))
	assert(motor.get_horizontal_direction(
		Vector2.ZERO,
		turned_basis
	).is_zero_approx())

	var flight_direction := motor.get_flight_direction(
		Vector2(1.0, -1.0),
		1.0,
		Basis.IDENTITY
	)
	assert(flight_direction.is_normalized())
	assert(flight_direction.is_equal_approx(
		Vector3(1.0, 1.0, -1.0).normalized()
	))

	var turned_flight_direction := motor.get_flight_direction(
		Vector2(0.0, -1.0),
		0.0,
		turned_basis
	)
	assert(turned_flight_direction.is_equal_approx(Vector3.LEFT))
	assert(motor.get_flight_direction(
		Vector2.ZERO,
		-1.0,
		Basis.IDENTITY
	).is_equal_approx(Vector3.DOWN))
	assert(motor.get_flight_direction(
		Vector2.ZERO,
		0.0,
		turned_basis
	).is_zero_approx())

	var gravity_velocity := motor.apply_gravity(
		Vector3(4.0, 10.0, -6.0),
		30.0,
		0.25
	)
	assert(gravity_velocity.is_equal_approx(Vector3(4.0, 2.5, -6.0)))

	var falling_velocity := motor.apply_gravity(
		Vector3(-3.0, -5.0, 8.0),
		20.0,
		0.5
	)
	assert(falling_velocity.is_equal_approx(Vector3(-3.0, -15.0, 8.0)))

	var accelerated_speed := motor.approach_ground_speed(
		10.0,
		10.0,
		20.0,
		true,
		2.0,
		4.0,
		3.0,
		0.5
	)
	assert(is_equal_approx(accelerated_speed, 13.0))

	var decelerated_speed := motor.approach_ground_speed(
		20.0,
		10.0,
		20.0,
		false,
		2.0,
		4.0,
		3.0,
		0.5
	)
	assert(is_equal_approx(decelerated_speed, 14.0))

	var minimum_speed := motor.approach_ground_speed(
		0.0,
		10.0,
		20.0,
		false,
		2.0,
		4.0,
		3.0,
		0.5
	)
	assert(is_equal_approx(minimum_speed, 10.0))

	var high_attribute_speed := motor.approach_ground_speed(
		10.0,
		10.0,
		515.0,
		true,
		2.0,
		4.0,
		25.75,
		1.0
	)
	assert(is_equal_approx(high_attribute_speed, 61.5))

	var accelerated_flight_speed := motor.approach_flight_speed(
		10.0,
		10.0,
		30.0,
		true,
		4.0,
		3.0,
		2.0,
		0.5
	)
	assert(is_equal_approx(accelerated_flight_speed, 14.0))

	var decelerated_flight_speed := motor.approach_flight_speed(
		25.0,
		10.0,
		30.0,
		false,
		4.0,
		3.0,
		2.0,
		0.5
	)
	assert(is_equal_approx(decelerated_flight_speed, 22.0))

	var minimum_flight_speed := motor.approach_flight_speed(
		5.0,
		10.0,
		30.0,
		false,
		4.0,
		3.0,
		2.0,
		0.5
	)
	assert(is_equal_approx(minimum_flight_speed, 10.0))

	var high_attribute_flight_speed := motor.approach_flight_speed(
		10.0,
		10.0,
		1000.0,
		true,
		2.0,
		3.0,
		25.75,
		1.0
	)
	assert(is_equal_approx(high_attribute_flight_speed, 61.5))

	var hover_velocity := motor.approach_hover_velocity(
		Vector3(3.0, 4.0, 0.0),
		2.5,
		1.0,
		1.0
	)
	assert(hover_velocity.is_equal_approx(Vector3(1.5, 2.0, 0.0)))

	var downward_slam_velocity := motor.get_ground_slam_velocity(
		Vector3(0.0, 10.0, 0.0),
		Vector3.ZERO,
		80.0,
		2.0
	)
	assert(downward_slam_velocity.is_equal_approx(Vector3(0.0, -160.0, 0.0)))

	var diagonal_slam_velocity := motor.get_ground_slam_velocity(
		Vector3.ZERO,
		Vector3(3.0, -4.0, 0.0),
		50.0,
		1.0
	)
	assert(diagonal_slam_velocity.is_equal_approx(Vector3(30.0, -40.0, 0.0)))
	assert(motor.get_ground_slam_velocity(
		Vector3.ONE,
		Vector3.ONE,
		80.0,
		2.0
	).is_zero_approx())

	var vertical_wall_run_velocity := motor.get_wall_run_velocity(
		Vector3.RIGHT,
		Vector3.RIGHT,
		0.0,
		12.0,
		1.0,
		8.0,
		2.0,
		0.5
	)
	assert(vertical_wall_run_velocity.is_equal_approx(Vector3(-1.0, 12.0, 0.0)))

	var lateral_wall_run_velocity := motor.get_wall_run_velocity(
		Vector3.FORWARD,
		Vector3.RIGHT,
		1.0,
		12.0,
		1.0,
		8.0,
		2.0,
		0.5
	)
	assert(lateral_wall_run_velocity.is_equal_approx(Vector3(8.0, 12.0, 1.0)))

	var reverse_wall_run_velocity := motor.get_wall_run_velocity(
		Vector3.FORWARD,
		Vector3.RIGHT,
		-1.0,
		12.0,
		1.0,
		8.0,
		2.0,
		0.5
	)
	assert(reverse_wall_run_velocity.is_equal_approx(Vector3(-8.0, 12.0, 1.0)))

	var parallel_wall_run_velocity := motor.get_wall_run_velocity(
		Vector3.RIGHT,
		Vector3.RIGHT,
		1.0,
		12.0,
		1.0,
		8.0,
		2.0,
		0.5
	)
	assert(parallel_wall_run_velocity.is_equal_approx(Vector3(-1.0, 12.0, 0.0)))

	var quick_jump_velocity := motor.get_quick_jump_velocity(
		Vector3(3.0, -5.0, -2.0),
		10.0
	)
	assert(quick_jump_velocity.is_equal_approx(Vector3(3.0, 10.0, -2.0)))

	var charged_jump_velocity := motor.get_charged_jump_velocity(
		Vector3(3.0, 0.0, -2.0),
		Vector3(0.0, 0.0, -2.0),
		0.5,
		10.0,
		30.0,
		40.0,
		2.0
	)
	assert(charged_jump_velocity.is_equal_approx(Vector3(3.0, 20.0, -42.0)))

	var uncharged_jump_velocity := motor.get_charged_jump_velocity(
		Vector3(3.0, -5.0, -2.0),
		Vector3.FORWARD,
		0.0,
		10.0,
		30.0,
		40.0,
		2.0
	)
	assert(uncharged_jump_velocity.is_equal_approx(Vector3(3.0, 10.0, -2.0)))

	var grounded_acceleration := motor.get_horizontal_acceleration(
		40.0,
		3.0,
		0.35,
		true
	)
	assert(is_equal_approx(grounded_acceleration, 120.0))

	var airborne_acceleration := motor.get_horizontal_acceleration(
		40.0,
		3.0,
		0.35,
		false
	)
	assert(is_equal_approx(airborne_acceleration, 42.0))

	var accelerated_velocity := motor.approach_horizontal_velocity(
		Vector3(5.0, 7.0, -2.0),
		Vector3.RIGHT,
		20.0,
		40.0,
		0.25
	)
	assert(accelerated_velocity.is_equal_approx(Vector3(15.0, 7.0, 0.0)))

	var stopped_velocity := motor.approach_horizontal_velocity(
		Vector3(5.0, 7.0, -12.0),
		Vector3.ZERO,
		20.0,
		20.0,
		0.25
	)
	assert(stopped_velocity.is_equal_approx(Vector3(0.0, 7.0, -7.0)))

	motor.free()


func _test_player_integration() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	assert(main_scene != null)

	var main := main_scene.instantiate()
	root.add_child(main)

	var player := main.get_node("Player") as CharacterBody3D
	assert(player != null)
	var motor := player.get_node("PlayerMovementMotor") as PlayerMovementMotor
	assert(motor != null)
	assert(player.get("movement_motor") == motor)

	print("PASS: PlayerMovementMotor calculations and Player integration")
	quit()
