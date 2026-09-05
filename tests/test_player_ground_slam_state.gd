extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	assert(main_scene != null)

	var main := main_scene.instantiate()
	root.add_child(main)

	var player := main.get_node("Player") as PlayerCharacter
	var machine := player.get_node("PlayerStateMachine") as PlayerStateMachine
	var abilities := player.get("abilities") as PlayerAbilities
	player.global_position = Vector3(0.0, 10.0, 0.0)
	assert(machine.transition_to(&"FlyingState"))
	assert(player.get("is_flying"))

	var target_position := Vector3.ZERO
	assert(machine.transition_to(
		&"GroundSlamState",
		{"target_position": target_position}
	))
	assert(machine.active_state is PlayerGroundSlamState)
	assert(not player.get("is_flying"))
	assert(player.get("is_ground_slamming"))
	assert(player.get("ground_slam_target") == target_position)
	assert(player.get("current_flight_speed") == 0.0)

	machine.physics_update(0.1, null)
	assert(player.velocity.y < 0.0)
	assert(is_equal_approx(
		player.velocity.length(),
		float(player.get("ground_slam_speed"))
			* player.stats.get_speed_multiplier(
				player.minimum_run_speed,
				player.run_speed_per_attribute_point
			)
	))

	var ground_slam_state := machine.active_state as PlayerGroundSlamState
	ground_slam_state._finish_ground_slam()
	assert(machine.active_state is PlayerAirborneState)
	assert(not player.get("is_ground_slamming"))
	assert(player.get("ground_slam_impact_pending"))
	assert(player.velocity == Vector3.ZERO)

	assert(abilities.set_unlocked(PlayerAbilities.GROUND_SLAM, false))
	player.set("is_jump_active", true)
	assert(not machine.transition_to(
		&"GroundSlamState",
		{"target_position": target_position}
	))
	assert(machine.active_state is PlayerAirborneState)
	assert(not player.get("is_ground_slamming"))

	print("PASS: PlayerGroundSlamState migration and ability guard")
	quit()
