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
	assert(machine.active_state is PlayerGroundedState)

	player.call("_sync_grounded_airborne_state", false)
	assert(machine.active_state is PlayerAirborneState)

	player.call("_sync_grounded_airborne_state", true)
	assert(machine.active_state is PlayerGroundedState)

	assert(machine.transition_to(&"FlyingState"))
	player.call("_sync_grounded_airborne_state", false)
	assert(machine.active_state is PlayerFlyingState)
	assert(player.get("is_flying"))

	print("PASS: Player ground-contact state synchronization")
	quit()
