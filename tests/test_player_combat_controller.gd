extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	assert(main_scene != null)

	var main := main_scene.instantiate()
	root.add_child(main)

	var player := main.get_node("Player") as PlayerCharacter
	assert(player != null)
	var combat_controller := player.get_node("PlayerCombatController") as PlayerCombatController
	var machine := player.get_node("PlayerStateMachine") as PlayerStateMachine
	var jump_state := machine.get_state(&"JumpChargingState") as PlayerJumpChargingState
	assert(combat_controller != null)
	assert(not combat_controller.is_action_locked())
	assert(jump_state.can_enter(machine.active_state))

	combat_controller.request_punch()
	assert(combat_controller.is_action_locked())
	assert(not jump_state.can_enter(machine.active_state))

	combat_controller.cancel_punch()
	assert(not combat_controller.is_action_locked())
	assert(jump_state.can_enter(machine.active_state))

	print("PASS: PlayerCombatController action-lock ownership")
	quit()
