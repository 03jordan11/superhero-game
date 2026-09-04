extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	assert(main_scene != null)

	var main := main_scene.instantiate()
	root.add_child(main)

	var player := main.get_node("Player") as CharacterBody3D
	assert(player is PlayerCharacter)
	var machine := player.get_node("PlayerStateMachine") as PlayerStateMachine
	assert(machine != null)
	assert(machine.is_initialized)
	assert(machine.player == player)
	assert(machine.active_state is PlayerGroundedState)
	assert(machine.get_active_state_id() == &"GroundedState")
	assert(machine.states.size() == 8)

	print("PASS: PlayerStateMachine inert scene integration")
	quit()
