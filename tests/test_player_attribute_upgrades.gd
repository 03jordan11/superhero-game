extends SceneTree
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var stats := PlayerStats.new()
	stats.add_experience(750)
	check(stats.level == 4 and stats.experience == 50 and stats.attribute_points == 3, "Multiple levels award one point each")
	stats.add_experience(-50)
	check(stats.attribute_points == 3, "Negative XP cannot grant points")
	for id in [PlayerStats.STRENGTH, PlayerStats.SPEED, PlayerStats.RESILIENCE]:
		check(stats.upgrade_attribute(id) and stats.get(id) == 2, "Each chosen attribute costs one point")
	check(stats.attribute_points == 0 and not stats.upgrade_attribute(PlayerStats.STRENGTH), "Cannot overspend")
	stats.attribute_points = 1
	check(not stats.upgrade_attribute(&"money") and stats.attribute_points == 1, "Only the three attributes can be purchased")
	stats.strength = PlayerStats.MAX_PROGRESSION_VALUE
	check(not stats.upgrade_attribute(PlayerStats.STRENGTH) and stats.attribute_points == 1, "Capped stat does not consume points")
	stats.attribute_points = PlayerStats.MAX_PROGRESSION_VALUE
	stats.add_experience(800)
	check(stats.attribute_points == PlayerStats.MAX_PROGRESSION_VALUE, "Point awards saturate safely")
	stats.level = 12
	stats.attribute_points = 0
	check(stats.attribute_points == 0, "Direct level assignment never grants points")

	var path := OS.get_environment("TEMP").path_join("attribute_upgrades_%d.json" % OS.get_process_id())
	var save := root.get_node("SaveManager")
	save._save_path = path
	var world := Node3D.new()
	root.add_child(world)
	var player: PlayerCharacter = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	var menu = load("res://scripts/ui-scripts/gameplay_menu.gd").new()
	world.add_child(menu)
	menu.open_menu()
	menu.tabs.current_tab = 2
	check(menu.attribute_buttons.strength.disabled, "Upgrade buttons disabled without points")
	player.stats.add_experience(300)
	check(menu.points_label.text == "Attribute points: 2" and not menu.attribute_buttons.strength.disabled, "Open menu responds to earned points")
	player.stats.set_power_bonuses(5, 5)
	await process_frame
	menu.attribute_buttons.strength.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	root.push_input(key)
	key = key.duplicate()
	key.pressed = false
	root.push_input(key)
	check(player.stats.strength == 11 and player.stats.attribute_points == 1 and menu.attribute_labels.strength.text == "Strength  16 (+5)", "Button upgrades base stat while preserving bonus display")
	menu.attribute_buttons.resilience.grab_focus()
	var controller_button := InputEventJoypadButton.new()
	controller_button.button_index = JOY_BUTTON_A
	controller_button.pressed = true
	root.push_input(controller_button)
	controller_button = controller_button.duplicate()
	controller_button.pressed = false
	root.push_input(controller_button)
	check(player.stats.resilience == 11 and player.get_max_health() == 1100 and player.stamina.maximum == 110, "Resilience purchase updates health and stamina capacity")
	check(menu.attribute_buttons.speed.disabled and menu.attribute_feedback.text.contains("saved"), "Last point disables buttons and reports save")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(saved.player.stats.attribute_points == 0 and saved.player.stats.strength == 11, "Purchase auto-saves spent points and base stat")
	player.stats.add_experience(400)
	check(save.save_game(), "Save unspent point")
	for i in 3:
		check(save.load_game() and player.stats.attribute_points == 1, "Repeated loads do not grant or lose points")
	# Existing saves have no balance; never backfill from level, nor retain runtime points.
	saved.player.stats.erase("attribute_points")
	saved.player.stats.level = 9
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	check(save.load_game() and player.stats.attribute_points == 0, "Old level-nine save starts with zero points")
	player.stats.add_experience(player.stats.get_experience_to_next_level())
	check(player.stats.level == 10 and player.stats.attribute_points == 1, "Old save earns points on future level-ups")
	save._save_path = path.path_join("missing/save.json")
	menu._upgrade_attribute("speed")
	check(player.stats.attribute_points == 0 and menu.attribute_feedback.text.contains("saving failed"), "Failed save leaves purchase in memory and gives retry guidance")
	menu.close_menu()
	world.free()
	DirAccess.remove_absolute(path)
	print("Attribute upgrades: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
