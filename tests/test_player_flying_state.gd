extends SceneTree


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	assert(main_scene != null)

	var main := main_scene.instantiate()
	root.add_child(main)

	var player := main.get_node("Player") as PlayerCharacter
	var machine := player.get_node("PlayerStateMachine") as PlayerStateMachine
	var abilities := player.get("abilities") as PlayerAbilities
	var hud := player.get_node("ChargeUI") as PlayerHud
	player.set("is_charging_jump", true)
	player.set("is_jump_active", true)
	player.set("jump_charge", 1.0)
	player.set("jump_hold_time", 1.0)
	player.velocity = Vector3(5.0, -20.0, 5.0)

	assert(abilities != null)
	assert(abilities.is_unlocked(PlayerAbilities.FLIGHT))
	assert(machine.transition_to(&"FlyingState"))
	assert(machine.active_state is PlayerFlyingState)
	assert(player.get("is_flying"))
	assert(player.velocity.y == 0.0)
	assert(not player.get("is_charging_jump"))
	assert(not player.get("is_jump_active"))
	assert(player.get("jump_charge") == 0.0)
	assert(player.get("jump_hold_time") == 0.0)

	player.velocity = Vector3(20.0, 0.0, 0.0)
	var speed_before := player.velocity.length()
	machine.physics_update(0.1, PlayerInputSnapshot.new())
	assert(player.velocity.length() < speed_before)
	assert(hud.flight_speed_bar.value > 0.0)

	assert(machine.transition_to(&"AirborneState"))
	assert(not player.get("is_flying"))
	assert(hud.flight_speed_bar.value == 0.0)
	assert(machine.active_state is PlayerAirborneState)
	assert(abilities.set_unlocked(PlayerAbilities.FLIGHT, false))
	assert(not machine.transition_to(&"FlyingState"))
	assert(machine.active_state is PlayerAirborneState)
	assert(not player.get("is_flying"))

	print("PASS: PlayerFlyingState migration and ability guard")
	quit()
