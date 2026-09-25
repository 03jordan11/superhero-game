extends SceneTree


func _initialize() -> void:
	_test_explicit_values()
	_test_input_capture()
	print("PASS: PlayerInputSnapshot values and input capture")
	quit()


func _test_explicit_values() -> void:
	var snapshot := PlayerInputSnapshot.new(
		Vector2(0.25, -0.75),
		-0.5,
		true,
		true,
		true,
		true,
		false,
		true,
		true,
		true,
		true,
		false
	)
	assert(snapshot.movement == Vector2(0.25, -0.75))
	assert(is_equal_approx(snapshot.lateral_movement, -0.5))
	assert(snapshot.sprint_pressed)
	assert(snapshot.move_forward_pressed)
	assert(snapshot.jump_pressed)
	assert(snapshot.jump_just_pressed)
	assert(not snapshot.jump_just_released)
	assert(snapshot.descend_pressed)
	assert(snapshot.toggle_flight_just_pressed)
	assert(snapshot.vehicle_interact_pressed)
	assert(snapshot.vehicle_interact_just_pressed)
	assert(not snapshot.vehicle_interact_just_released)


func _test_input_capture() -> void:
	Input.action_press("move_right")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	Input.action_press("jump")
	Input.action_press("toggle_flight")
	Input.action_press("attack")
	Input.action_press("aim_power")
	Input.action_press("secondary_power")
	Input.action_press("flight_descend")
	Input.action_press("dodge_roll")
	Input.action_press("pick_up_vehicle")
	Input.action_press("lock_target")

	var pressed_snapshot := PlayerInputSnapshot.capture()
	assert(pressed_snapshot.lock_target_pressed and pressed_snapshot.lock_target_just_pressed)
	assert(pressed_snapshot.movement.is_equal_approx(
		Vector2(1.0, -1.0).normalized()
	))
	assert(is_equal_approx(pressed_snapshot.lateral_movement, 1.0))
	assert(pressed_snapshot.sprint_pressed)
	assert(pressed_snapshot.move_forward_pressed)
	assert(pressed_snapshot.jump_pressed)
	assert(pressed_snapshot.jump_just_pressed)
	assert(pressed_snapshot.descend_pressed)
	assert(pressed_snapshot.dodge_just_pressed)
	assert(pressed_snapshot.toggle_flight_just_pressed)
	assert(pressed_snapshot.flight_pressed)
	assert(pressed_snapshot.activate_power_pressed and pressed_snapshot.aim_power_pressed)
	assert(pressed_snapshot.activate_power_just_pressed)
	assert(pressed_snapshot.secondary_power_pressed)
	assert(pressed_snapshot.secondary_power_just_pressed)
	assert(pressed_snapshot.vehicle_interact_pressed)
	assert(pressed_snapshot.vehicle_interact_just_pressed)

	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	Input.action_release("jump")
	Input.action_release("toggle_flight")
	Input.action_release("attack")
	Input.action_release("aim_power")
	Input.action_release("secondary_power")
	Input.action_release("flight_descend")
	Input.action_release("dodge_roll")
	Input.action_release("pick_up_vehicle")
	Input.action_release("lock_target")

	var released_snapshot := PlayerInputSnapshot.capture()
	assert(not released_snapshot.lock_target_pressed and released_snapshot.lock_target_just_released)
	assert(released_snapshot.movement.is_zero_approx())
	assert(is_zero_approx(released_snapshot.lateral_movement))
	assert(not released_snapshot.sprint_pressed)
	assert(not released_snapshot.move_forward_pressed)
	assert(not released_snapshot.jump_pressed)
	assert(released_snapshot.jump_just_released)
	assert(not released_snapshot.descend_pressed)
	assert(not released_snapshot.flight_pressed)
	assert(released_snapshot.flight_just_released)
	assert(not released_snapshot.activate_power_pressed and not released_snapshot.aim_power_pressed)
	assert(released_snapshot.activate_power_just_released and not released_snapshot.secondary_power_pressed)
	assert(released_snapshot.secondary_power_just_released)
	assert(not released_snapshot.vehicle_interact_pressed)
	assert(released_snapshot.vehicle_interact_just_released)
