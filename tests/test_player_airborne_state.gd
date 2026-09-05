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
	player.global_position = Vector3(0.0, 20.0, 0.0)
	player.velocity = Vector3.ZERO
	var landing_controller := (
		player.get_node("PlayerLandingImpactController")
		as PlayerLandingImpactController
	)
	landing_controller.reset_normal_landing_tracking()
	var grounded_state := machine.active_state as PlayerNormalMovementState
	grounded_state._sync_grounded_airborne(false)

	assert(machine.active_state is PlayerAirborneState)
	machine.physics_update(0.25, PlayerInputSnapshot.new())
	assert(landing_controller.was_airborne)
	assert(is_equal_approx(player.velocity.y, -float(player.get("gravity")) * 0.25))
	assert(is_equal_approx(landing_controller.max_downward_speed, -player.velocity.y))

	var airborne_state := machine.active_state as PlayerNormalMovementState
	airborne_state._sync_grounded_airborne(true)
	assert(machine.active_state is PlayerGroundedState)

	print("PASS: PlayerAirborneState migration")
	quit()
