extends SceneTree

class PunchTarget extends StaticBody3D:
	var received := 0.0
	func apply_damage(info) -> void:
		received += info.amount

var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(value: bool, copy: String) -> void:
	if not value:
		failures += 1
		push_error(copy)

func run() -> void:
	var save := root.get_node("SaveManager")
	var path := OS.get_environment("TEMP").path_join("power_attributes_%d.json" % OS.get_process_id())
	save._save_path = path
	var world := Node3D.new()
	root.add_child(world)
	var player: PlayerCharacter = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.global_position.y = 10.0
	var controller := player.get_node("PlayerPowerController")
	var progression = controller.progression
	var stats := player.stats
	check(stats.strength == 10 and stats.speed == 1 and stats.get_effective_strength() == 10, "No bonuses before purchasing")
	controller.progression.add_tokens(20)
	progression.purchase("strength")
	check(stats.strength == 10 and stats.get_effective_strength() == 15, "Strength core gives five derived points")
	progression.purchase("super_speed")
	check(stats.speed == 1 and stats.get_effective_speed() == 6, "Speed core gives five attribute points")
	check(stats.get_run_speed(20.0, 5.0) == 45.0, "Speed bonus reaches sprint calculations")
	check(stats.get_walk_speed(20.0, 5.0, 0.5) == 10.0, "Speed bonus leaves ordinary movement fixed")
	check(stats.get_speed_multiplier(20.0, 5.0) == 2.25, "Speed bonus reaches acceleration scaling")
	var menu = load("res://scripts/ui-scripts/gameplay_menu.gd").new()
	world.add_child(menu)
	menu.open_menu()
	menu.tabs.current_tab = 2
	check(menu.attribute_labels.strength.text == "Strength  15 (+5)" and menu.attribute_labels.speed.text == "Speed  6 (+5)", "Actual bonuses appear beside effective attributes")
	stats.strength = 12
	check(menu.attribute_labels.strength.text == "Strength  17 (+5)", "Editing base stats retains the separate bonus")
	stats.strength = 10
	menu.close_menu()
	var target := PunchTarget.new()
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.4
	collision.shape = shape
	target.add_child(collision)
	world.add_child(target)
	target.global_position = player.global_position + Vector3.UP + Vector3.FORWARD * player.combat_controller.punch_hit_distance
	await physics_frame
	player.combat_controller.request_punch()
	player._profiled_physics_process(player.combat_controller.punch_hit_delay + 0.01)
	check(target.received == 30.0, "Real player combat passes effective Strength to punch damage")
	player.combat_controller.cancel_punch()
	progression.purchase("flight")
	check(player.state_machine.transition_to(&"FlyingState"), "Flight fixture unlocked")
	var input := PlayerInputSnapshot.new()
	input.movement = Vector2.UP
	player.state_machine.physics_update(1.0, input)
	check(is_equal_approx(player.velocity.length(), 10.0), "Speed bonus leaves normal flight fixed")
	progression.purchase("strength")
	progression.purchase("super_speed")
	controller.progression.add_tokens(1)
	for i in range(3): controller.sync_abilities()
	check(stats.get_effective_strength() == 15 and stats.get_effective_speed() == 6, "Upgrades, token grants and resyncs do not stack bonuses")
	check(save.save_game(), "Bonus ownership saved")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(saved.player.stats.strength == 10 and saved.player.stats.speed == 1, "Save records base attributes only")
	for i in range(3):
		check(save.load_game(), "Save reload")
		check(stats.get_effective_strength() == 15 and stats.get_effective_speed() == 6, "Reload applies bonus exactly once")
	progression.apply_save_data({})
	menu.open_menu()
	check(stats.get_effective_strength() == 10 and stats.get_effective_speed() == 1, "Loading unowned cores removes bonuses")
	check(menu.attribute_labels.strength.text == "Strength  10" and menu.attribute_labels.speed.text == "Speed  1", "Unowned bonuses disappear from Attributes")
	menu.close_menu()
	# Existing purchased saves gain the new benefits without modifying base stats.
	check(save.load_game() and stats.get_effective_strength() == 15, "Existing core purchases acquire the new bonus")
	stats.strength = PlayerStats.MAX_PROGRESSION_VALUE
	check(stats.get_effective_strength() == PlayerStats.MAX_PROGRESSION_VALUE and stats.get_power_bonus(PlayerStats.STRENGTH) == 0, "Bonuses cannot overflow an attribute")
	stats.strength -= 2
	check(stats.get_power_bonus(PlayerStats.STRENGTH) == 2 and stats.get_effective_strength() == PlayerStats.MAX_PROGRESSION_VALUE, "Displayed contribution matches saturation")
	world.free()
	DirAccess.remove_absolute(path)
	print("Power attributes: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
