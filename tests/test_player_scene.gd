extends SceneTree


func _initialize() -> void:
	_test_reusable_scene_structure()
	_test_main_scene_instance.call_deferred()


func _test_reusable_scene_structure() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	assert(player_scene != null)

	var player := player_scene.instantiate() as PlayerCharacter
	assert(player != null)
	root.add_child(player)
	assert(player.scene_file_path == "res://scenes/player.tscn")
assert(player.get_script().resource_path == "res://scripts/player-scripts/player_character.gd")
	assert(player.get("strength") == 10)
	assert(player.get("resilience") == 10)
	assert(player.get_node("CollisionShape3D") is CollisionShape3D)
	assert(player.get_node("SuperheroCharacter") is Node3D)
	assert(player.get_node("PlayerStateMachine") is PlayerStateMachine)
	assert(player.get_node("PlayerStateMachine/GroundedState") is PlayerGroundedState)
	assert(player.get_node("PlayerStateMachine/JumpChargingState") is PlayerJumpChargingState)
	assert(player.get_node("PlayerStateMachine/AirborneState") is PlayerAirborneState)
	assert(player.get_node("PlayerStateMachine/FlyingState") is PlayerFlyingState)
	assert(player.get_node("PlayerStateMachine/GroundSlamState") is PlayerGroundSlamState)
	assert(player.get_node("PlayerStateMachine/WallRunState") is PlayerWallRunState)
	assert(player.get_node("PlayerStateMachine/KnockedDownState") is PlayerKnockedDownState)
	assert(player.get_node("PlayerStateMachine/DeadState") is PlayerDeadState)
	assert(player.get_node("PlayerMovementMotor") is PlayerMovementMotor)
	assert(player.get_node("PlayerAnimationController") is PlayerAnimationController)
	assert(player.get_node("PlayerStatusEffects") is PlayerStatusEffects)
	assert(player.get_node("PlayerDamageReceiver") is PlayerDamageReceiver)
	assert(player.get_node("PlayerVehicleInteractor") is PlayerVehicleInteractor)
	assert(
		player.get_node("PlayerLandingImpactController")
		is PlayerLandingImpactController
	)
	assert(player.get_node("SpringArm3D/Camera3D") is Camera3D)
	assert(player.get_node("ChargeUI") is PlayerHud)
	assert(player.get_node("PlayerCombatController") is PlayerCombatController)
	player.free()


func _test_main_scene_instance() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	assert(main_scene != null)

	var main := main_scene.instantiate()
	root.add_child(main)

	var player := main.get_node("Player") as PlayerCharacter
	assert(player != null)
	assert(player.damage_receiver == player.get_node("PlayerDamageReceiver"))
	assert(player.vehicle_interactor == player.get_node("PlayerVehicleInteractor"))
	assert(
		player.landing_impact_controller
		== player.get_node("PlayerLandingImpactController")
	)
	assert(player.scene_file_path == "res://scenes/player.tscn")
	assert(player.get_node("PlayerStateMachine").get_child_count() == 8)
	assert(player.get_node("ChargeUI/HealthBar") is ProgressBar)
	assert(player.get_node("ChargeUI/SprintSpeedBar") is ProgressBar)
	assert(player.get_node("ChargeUI/VehicleThrowChargeBar") is ProgressBar)

	print("PASS: reusable Player scene and Main instance")
	quit()
