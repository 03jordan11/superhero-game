extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	assert(main_scene != null)

	var main := main_scene.instantiate()
	root.add_child(main)
	preload("res://tests/player_test_support.gd").unlock_current_powers(main.get_node("Player"))

	var player := main.get_node("Player") as PlayerCharacter
	var machine := player.get_node("PlayerStateMachine") as PlayerStateMachine
	var hud := player.get_node("ChargeUI") as PlayerHud
	hud.show()
	var walk_speed := float(player.call("_get_walk_speed"))
	var run_speed := player.stats.get_run_speed(player.minimum_run_speed, player.run_speed_per_attribute_point)
	player.set("current_ground_speed", walk_speed)
	player.velocity = Vector3.ZERO
	Input.action_press("move_forward")
	Input.action_press("sprint")

	assert(machine.active_state is PlayerGroundedState)
	machine.physics_update(0.25, PlayerInputSnapshot.capture())
	var accelerated_speed: float = player.get("current_ground_speed")
	assert(accelerated_speed > walk_speed)
	assert(accelerated_speed <= run_speed)
	assert(Vector2(player.velocity.x, player.velocity.z).length() > 0.0)
	assert(hud.sprint_speed_bar.value > 0.0)
	var accelerated_hud_percent := hud.sprint_speed_bar.value

	Input.action_release("sprint")
	machine.physics_update(0.25, PlayerInputSnapshot.capture())
	assert(float(player.get("current_ground_speed")) < accelerated_speed)
	assert(hud.sprint_speed_bar.value < accelerated_hud_percent)

	Input.action_release("move_forward")
	print("PASS: PlayerGroundedState migration")
	quit()
