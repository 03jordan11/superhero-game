extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func launch(player: PlayerCharacter, charge: float) -> Vector3:
	player.state_machine.transition_to(&"GroundedState")
	player.state_machine.transition_to(&"JumpChargingState")
	player.jump_charge = charge * player.max_jump_charge_time
	player.velocity = Vector3.ZERO
	player.state_machine.active_state._release_jump()
	return player.velocity

func apex_height(player: PlayerCharacter) -> float:
	player.global_position = Vector3(0, 1000, 0)
	var highest := player.global_position.y
	# Exercise actual gravity/movement integration, not just launch formulas.
	while player.velocity.y > 0:
		player._profiled_physics_process(1.0 / 120.0)
		highest = maxf(highest, player.global_position.y)
	return highest - 1000

func run() -> void:
	var save := root.get_node("SaveManager")
	var path := OS.get_environment("TEMP").path_join("greater_jump_%d.json" % OS.get_process_id())
	save._save_path = path
	var player: PlayerCharacter = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var controller := player.get_node("PlayerPowerController")
	var progression = controller.progression
	controller.progression.add_tokens(5)
	check(player.charged_jump_output_multiplier == 1, "New game has no jump upgrade")
	var base_launch := launch(player, 1.0)
	var base_height := apex_height(player)
	var base_partial := launch(player, 0.5)
	check(player.charged_jump_output_multiplier == 1, "Core unlock alone keeps original jump")
	progression.purchase("super_leap")
	check(progression.is_implemented("super_leap", 1), "Greater Jump is marked implemented")
	var upgraded_launch := launch(player, 1.0)
	var upgraded_height := apex_height(player)
	check(absf(upgraded_height / base_height - 2.0) < 0.02, "Actual jump apex doubles within physics-step tolerance")
	check(is_equal_approx(upgraded_launch.y, base_launch.y * sqrt(2.0)), "Height doubles rather than quadruples")
	var base_range := absf(base_launch.z) * 2.0 * base_launch.y / player.gravity
	var upgraded_range := absf(upgraded_launch.z) * 2.0 * upgraded_launch.y / player.gravity
	check(is_equal_approx(upgraded_range, base_range * 2), "Power contribution doubles ballistic forward range")
	var upgraded_partial := launch(player, 0.5)
	check(is_equal_approx(upgraded_partial.y * upgraded_partial.y, base_partial.y * base_partial.y * 2), "Partial-charge height also doubles")
	check(launch(player, 5.0).is_equal_approx(upgraded_launch), "Charge cannot exceed upgraded launch caps")
	player.state_machine.transition_to(&"GroundedState")
	player.velocity = Vector3.ZERO
	player.grounded_state._release_jump()
	check(player.velocity.y == player.min_jump_velocity, "Ordinary quick jump stays unchanged")
	for i in 3:
		check(save.load_game(), "Purchased upgrade reloads")
		check(launch(player, 1).is_equal_approx(upgraded_launch), "Reload never compounds the multiplier")
	progression.purchase("super_leap")
	check(launch(player, 1).is_equal_approx(upgraded_launch), "Later planned tiers do not double it again")
	progression.apply_save_data({"schema_version":2, "upgrades":{"super_leap":0}})
	check(launch(player, 1).is_equal_approx(base_launch), "Loading only the core removes Greater Jump")
	check(player.max_jump_velocity == 35 and player.max_forward_jump_boost == 30, "Inspector base tuning remains unchanged")
	player.free()
	DirAccess.remove_absolute(path)
	print("Greater Jump: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
