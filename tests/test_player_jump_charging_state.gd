extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	assert(main_scene != null)

	var main := main_scene.instantiate()
	root.add_child(main)

	var player := main.get_node("Player") as CharacterBody3D
	var machine := player.get_node("PlayerStateMachine") as PlayerStateMachine
	var abilities := player.get("abilities") as PlayerAbilities
	var initial_charge_delta := 0.5
	assert(machine.active_state is PlayerGroundedState)
	assert(machine.transition_to(
		&"JumpChargingState",
		{"initial_charge_delta": initial_charge_delta}
	))
	assert(machine.active_state is PlayerJumpChargingState)
	assert(player.get("is_charging_jump"))
	assert(is_equal_approx(player.get("jump_charge"), initial_charge_delta))

	player.velocity = Vector3(5.0, 0.0, 5.0)
	machine.physics_update(0.1, PlayerInputSnapshot.new())
	assert(player.velocity.x == 0.0)
	assert(player.velocity.z == 0.0)

	player.set("jump_charge", 0.75)
	var expected_charge_percent := 0.75 / float(player.get("max_jump_charge_time"))
	var expected_vertical_velocity := lerpf(
		float(player.get("min_jump_velocity")),
		float(player.get("max_jump_velocity")),
		expected_charge_percent
	)
	var expected_forward_boost := (
		float(player.get("max_forward_jump_boost"))
		* expected_charge_percent
		* float(player.call("_get_movement_speed_multiplier"))
	)
	player.call("_release_jump")
	assert(machine.active_state is PlayerAirborneState)
	assert(player.get("is_jump_active"))
	assert(not player.get("is_charging_jump"))
	assert(player.get("jump_charge") == 0.0)
	assert(player.get("jump_hold_time") == 0.0)
	assert(is_equal_approx(player.velocity.y, expected_vertical_velocity))
	assert(is_equal_approx(player.velocity.z, -expected_forward_boost))

	assert(machine.transition_to(&"GroundedState"))
	assert(abilities.set_unlocked(PlayerAbilities.POWER_JUMP, false))
	assert(not machine.transition_to(
		&"JumpChargingState",
		{"initial_charge_delta": initial_charge_delta}
	))
	assert(machine.active_state is PlayerGroundedState)
	assert(not player.get("is_charging_jump"))

	player.velocity = Vector3.ZERO
	player.call("_release_jump")
	assert(is_equal_approx(player.velocity.y, float(player.get("min_jump_velocity"))))
	assert(player.get("is_jump_active"))

	print("PASS: PlayerJumpChargingState migration and ability guard")
	quit()
