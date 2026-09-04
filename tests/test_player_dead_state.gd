extends SceneTree

const DAMAGE_INFO_SCRIPT = preload("res://scripts/damage_info.gd")


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
	player.set("is_wall_running", true)
	player.set("is_charging_jump", true)
	player.set("is_jump_active", true)
	player.set("jump_charge", 1.0)
	player.set("jump_hold_time", 1.0)
	player.velocity = Vector3(10.0, 5.0, 10.0)

	var fatal_damage = DAMAGE_INFO_SCRIPT.new(player.call("get_max_health") + 1.0)
	assert(player.call("apply_damage", fatal_damage))
	assert(player.get("is_dead"))
	assert(player.get("is_knocked_out"))
	assert(not player.get("is_flying"))
	assert(not player.get("is_ground_slamming"))
	assert(not player.get("is_wall_running"))
	assert(not player.get("is_charging_jump"))
	assert(not player.get("is_jump_active"))
	assert(player.get("jump_charge") == 0.0)
	assert(player.get("jump_hold_time") == 0.0)
	assert(machine.active_state is PlayerDeadState)
	assert(machine.get_active_state_id() == &"DeadState")
	assert(not machine.transition_to(&"GroundedState"))

	var horizontal_speed_before := Vector2(player.velocity.x, player.velocity.z).length()
	machine.physics_update(0.25, null)
	var horizontal_speed_after := Vector2(player.velocity.x, player.velocity.z).length()
	assert(horizontal_speed_after < horizontal_speed_before)

	print("PASS: PlayerDeadState migration")
	quit()
