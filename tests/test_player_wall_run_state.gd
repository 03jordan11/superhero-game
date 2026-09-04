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
	var wall_normal := Vector3.RIGHT
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var input_snapshot := PlayerInputSnapshot.capture()

	assert(abilities.is_unlocked(PlayerAbilities.WALL_RUN))
	assert(machine.transition_to(
		&"WallRunState",
		{
			"collision_normal": wall_normal,
			"input_snapshot": input_snapshot,
		}
	))
	assert(machine.active_state is PlayerWallRunState)
	assert(player.get("is_wall_running"))
	assert(player.get("wall_run_normal") == wall_normal)
	assert(not player.get("wall_run_has_left_ground"))
	assert(player.velocity.y > 0.0)
	assert(player.velocity.x < 0.0)

	# With no wall collision in this isolated test, the preserved wall probe
	# should end the run and return to airborne movement.
	machine.physics_update(0.1, input_snapshot)
	assert(machine.active_state is PlayerAirborneState)
	assert(not player.get("is_wall_running"))
	assert(not player.get("wall_run_has_left_ground"))

	assert(abilities.set_unlocked(PlayerAbilities.WALL_RUN, false))
	assert(not machine.transition_to(
		&"WallRunState",
		{
			"collision_normal": wall_normal,
			"input_snapshot": input_snapshot,
		}
	))
	assert(machine.active_state is PlayerAirborneState)
	assert(not player.get("is_wall_running"))

	Input.action_release("move_forward")
	Input.action_release("sprint")
	print("PASS: PlayerWallRunState migration and ability guard")
	quit()
