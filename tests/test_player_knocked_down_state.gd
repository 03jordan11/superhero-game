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
	player.set("is_flying", true)
	player.set("is_ground_slamming", true)
	player.set("current_flight_speed", 40.0)
	player.set("knockdown_stun_duration", 0.5)
	player.velocity = Vector3(8.0, 6.0, 4.0)

	assert(machine.transition_to(&"KnockedDownState", {"cause": &"damage"}))
	assert(machine.active_state is PlayerKnockedDownState)
	assert(machine.get_active_state_id() == &"KnockedDownState")
	assert(player.get("is_knocked_out"))
	assert(not player.get("is_flying"))
	assert(not player.get("is_ground_slamming"))
	assert(player.get("current_flight_speed") == 0.0)
	assert(player.velocity.y == 0.0)

	var horizontal_speed_before := Vector2(player.velocity.x, player.velocity.z).length()
	machine.physics_update(0.25, null)
	var horizontal_speed_after := Vector2(player.velocity.x, player.velocity.z).length()
	assert(horizontal_speed_after < horizontal_speed_before)
	assert(player.velocity.y < 0.0)

	var knocked_down_state := machine.active_state as PlayerKnockedDownState
	knocked_down_state._begin_knockout_stun()
	assert(player.get("has_knockout_landed"))
	machine.physics_update(0.25, null)
	assert(machine.active_state is PlayerKnockedDownState)
	machine.physics_update(0.25, null)
	assert(machine.active_state is PlayerGroundedState)
	assert(not player.get("is_knocked_out"))
	assert(not player.get("has_knockout_landed"))
	assert(player.get("knockout_stun_remaining") == 0.0)

	print("PASS: PlayerKnockedDownState migration")
	quit()
