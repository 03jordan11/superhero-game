extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func read_save(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func run() -> void:
	var manager := root.get_node("SaveManager")
	var original_path: String = manager._save_path
	var test_path := OS.get_environment("TEMP").path_join("power_token_save_test_%d.json" % OS.get_process_id())
	manager._save_path = test_path
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var player: PlayerCharacter = main.get_node("Player")
	var dev = main.get_node("DeveloperMenu")
	var page = main.get_node("GameplayMenu").powers_page
	player.stats.money = 123
	var actual_powers: Dictionary = player.abilities.unlocked_abilities.duplicate(true)
	dev.commands.execute("add pp 5")
	check(not manager.has_save(), "Console grant does not save implicitly")
	dev.commands.execute("save")
	var saved := read_save(test_path)
	check(saved.power_menu.tokens == 5, "Save must include all newly added tokens")
	check(saved.player.stats.money == 123, "Token grant must save the player's current game state too")
	check(dev.commands.execute("status").contains("Power points 5"), "Console reports granted point balance")
	page.progression.purchase("ice")
	page.progression.purchase("ice")
	player.stats.money = 456
	dev.commands.execute("add pp 5")
	dev.commands.execute("save")
	saved = read_save(test_path)
	check(saved.power_menu.tokens == 8 and saved.power_menu.upgrades.ice == 1, "Later grants must save the current balance and matching test upgrades")
	check(saved.player.stats.money == 456, "Every grant must save fresh game state")
	check(player.abilities.unlocked_abilities == actual_powers, "Saving menu progression must not activate gameplay powers")
	main.free()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	page = main.get_node("GameplayMenu").powers_page
	dev = main.get_node("DeveloperMenu")
	check(page.progression.tokens == 0, "Fresh scene starts clean until Load Save")
	dev.commands.execute("load")
	check(page.progression.tokens == 8 and page.progression.level("ice") == 1, "Load must restore tokens and test upgrades in a fresh scene")
	check(page.token_label.text == "8" and dev.commands.execute("status").contains("Power points 8"), "Both token displays must refresh on load")
	check(read_save(test_path) == saved, "Loading must not trigger an autosave")
	page.progression.purchase("fire")
	check(manager.save_game(), "Ordinary Save must include the current token state")
	check(read_save(test_path).power_menu.tokens == 7, "Manual save must reflect spent tokens")
	# Older saves omit this optional section and should reset to a clean starter.
	saved.erase("power_menu")
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	check(manager.load_game(), "Legacy saves should remain loadable")
	check(page.progression.tokens == 0 and page.progression.level("ice") == -1 and page.progression.level("super_leap") == 0, "Legacy saves start with zero points and only Power Jump")
	page.progression.apply_save_data({"tokens": -8, "upgrades": {"ice": 99, "super_leap": -5, "fire": "invalid"}})
	check(page.progression.tokens == 0 and page.progression.level("ice") == 3 and page.progression.level("super_leap") == 0 and page.progression.level("fire") == -1, "Loaded currency and upgrade values must be bounded")
	# Intentionally fail one save; tokens stay available and the UI offers retry.
	manager._save_path = test_path.path_join("missing/save.json")
	dev.commands.execute("add pp 5")
	check(page.progression.tokens == 5 and dev.commands.execute("save").contains("Save failed"), "Save failure must not claim success or silently lose the grant")
	manager._save_path = test_path
	check(manager.save_game(), "Manual retry should save the granted balance")
	check(read_save(test_path).power_menu.tokens == 5, "Retry must include unsaved tokens")
	main.free()
	check(manager.delete_save(), "Test save should be removable")
	manager._save_path = original_path
	if failures == 0: print("PASS: explicit console saves, full player state, fresh-scene load, legacy defaults, validation and save-failure retry")
	quit(1 if failures else 0)
