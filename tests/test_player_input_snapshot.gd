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
	Input.action_press("flight_descend")
	Input.action_press("pick_up_vehicle")

	var pressed_snapshot := PlayerInputSnapshot.capture()
	assert(pressed_snapshot.movement.is_equal_approx(
		Vector2(1.0, -1.0).normalized()
	))
	assert(is_equal_approx(pressed_snapshot.lateral_movement, 1.0))
	assert(pressed_snapshot.sprint_pressed)
	assert(pressed_snapshot.move_forward_pressed)
	assert(pressed_snapshot.jump_pressed)
	assert(pressed_snapshot.jump_just_pressed)
	assert(pressed_snapshot.descend_pressed)
	assert(pressed_snapshot.toggle_flight_just_pressed)
	assert(pressed_snapshot.vehicle_interact_pressed)
	assert(pressed_snapshot.vehicle_interact_just_pressed)

	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	Input.action_release("jump")
	Input.action_release("toggle_flight")
	Input.action_release("flight_descend")
	Input.action_release("pick_up_vehicle")

	var released_snapshot := PlayerInputSnapshot.capture()
	assert(released_snapshot.movement.is_zero_approx())
	assert(is_zero_approx(released_snapshot.lateral_movement))
	assert(not released_snapshot.sprint_pressed)
	assert(not released_snapshot.move_forward_pressed)
	assert(not released_snapshot.jump_pressed)
	assert(released_snapshot.jump_just_released)
	assert(not released_snapshot.descend_pressed)
	assert(not released_snapshot.vehicle_interact_pressed)
	assert(released_snapshot.vehicle_interact_just_released)
