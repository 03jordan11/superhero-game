extends SceneTree

var failures := 0
var test_path: String

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func write_save(text: String) -> void:
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func open_menu() -> Node:
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	return menu

func run() -> void:
	create_timer(90).timeout.connect(func(): push_error("Main menu load test timed out"); quit(1))
	var saves := root.get_node("SaveManager")
	var original_path: String = saves._save_path
	test_path = OS.get_environment("TEMP").path_join("main_menu_load_%d.json" % OS.get_process_id())
	saves._save_path = test_path
	var menu := open_menu()
	check(menu.load_button.disabled, "Load is disabled with no save")
	for invalid in ["broken json", "[]", "{}", '{"player": [], "save_version": 2}', '{"player": {}, "save_version": 999}']:
		write_save(invalid)
		menu._refresh_load_button()
		check(menu.load_button.disabled, "Malformed or unsupported save cannot be loaded")
	# A legacy save can still enable the button; a file disappearing after the
	# menu opens must fail without destroying the menu or starting a new game.
	write_save('{"player": {}}')
	menu._refresh_load_button()
	check(not menu.load_button.disabled, "Legacy save remains supported")
	saves.delete_save()
	menu.load_button.pressed.emit()
	await process_frame
	await process_frame
	check(current_scene == menu and menu.load_button.disabled, "Missing save at click stays in menu")
	check(menu.load_status.text.contains("Could not load") and not menu.get_node("Center/Menu/PlayButton").disabled, "Failure has feedback and leaves Play available")

	# Generate a real save from an outdoor-positioned player without touching the
	# user's file, then drive the actual main-menu button and scene transition.
	var source: PlayerCharacter = load("res://scenes/player.tscn").instantiate()
	root.add_child(source)
	source.position = Vector3(900, 300, -700)
	source.stats.money = 4321
	source.stats.strength = 7
	source.stats.attribute_points = 3
	var powers := source.get_node("PlayerPowerController")
	powers.progression.apply_save_data({"tokens": 8, "upgrades": {"super_leap": 0, "ice": 1}})
	check(powers.select_active_power(&"ice"), "Select a non-default power before saving")
	var selected: StringName = powers.active_power
	saves.begin_new_game(123456)
	check(saves.save_game(), "Save outdoor progress")
	var saved_text := FileAccess.get_file_as_string(test_path)
	source.free()
	menu.free()
	menu = open_menu()
	check(not menu.load_button.disabled, "Saved game detected when menu opens")
	menu.load_button.pressed.emit()
	menu._on_load_pressed()
	await process_frame
	await process_frame
	check(current_scene.name == &"GasStationInterior", "Load Game starts inside the hideout")
	if current_scene.name != &"GasStationInterior":
		saves.delete_save(); saves._save_path = original_path; quit(1); return
	var player: PlayerCharacter = current_scene.get_node("Player")
	var spawn: Node3D = current_scene.get_node("PlayerSpawn")
	check(player.global_position.distance_to(spawn.global_position) < 0.3, "Player starts at the interior spawn regardless of outdoor save location")
	check(player.stats.money == 4321 and player.stats.strength == 7 and player.stats.attribute_points == 3, "Saved player stats restored")
	powers = player.get_node("PlayerPowerController")
	check(powers.progression.tokens == 8 and powers.progression.level("ice") == 1 and powers.active_power == selected, "Saved powers, tokens and selection restored")
	check(root.get_node("CityWindows").city_seed == 123456, "Saved city seed restored")
	check(get_nodes_in_group(&"player").size() == 1 and get_nodes_in_group(&"gameplay_menu").size() == 1, "Load creates exactly one player and gameplay menu")
	check(not paused and player.velocity.length() < 1.0 and player.spring_arm.spring_length < 2.0, "Loaded game is playable with indoor camera and reset movement")
	check(current_scene.get_node("GameplayMenu").powers_page.progression == powers.progression, "Indoor powers UI uses loaded progression")
	check(FileAccess.get_file_as_string(test_path) == saved_text, "Loading does not overwrite the save")
	var pause_menu := current_scene.get_node("PauseMenu")
	pause_menu.pause_game()
	check(paused and pause_menu.visible, "Pause menu works after load")
	pause_menu.resume_game()
	# The normal exit path must retain the same player and restored progress.
	var identity := player.get_instance_id()
	var travel := get_first_node_in_group(&"hideout_travel")
	var expected_return: Vector3 = travel._return_transform.origin
	travel._cooldown_until = 0
	var exit_door: Node3D = current_scene.get_node("ExitDoor")
	player.global_position = exit_door.to_global(Vector3(0, 0, 1.1))
	check(exit_door.try_interact(player), "Loaded hideout exit can be used")
	await process_frame
	await process_frame
	check(current_scene.name == &"Main", "Exit returns to city")
	check(player.get_instance_id() == identity and player.stats.money == 4321, "Exit retains the loaded player and progress")
	check(player.global_position.distance_to(expected_return) < 0.5, "Exit places hero safely outside the gas station")
	current_scene.free()
	travel.free()
	# Play stays a fresh start even when a save exists.
	menu = open_menu()
	menu.get_node("Center/Menu/PlayButton").pressed.emit()
	await process_frame
	await process_frame
	check(current_scene.name == &"GasStationInterior" and current_scene.get_node("Player").stats.money != 4321, "New Game starts in the hideout without restoring saved progress")
	check(current_scene.get_node("Player").global_position.distance_to(current_scene.get_node("PlayerSpawn").global_position) < 0.3, "New Game uses the hideout spawn")
	check(FileAccess.get_file_as_string(test_path) == saved_text, "Starting Play does not overwrite the save")
	current_scene.free()
	get_first_node_in_group(&"hideout_travel").free()
	saves.delete_save()
	saves._save_path = original_path
	print("MAIN_MENU_LOAD: save detection, failure recovery, hideout spawn, progress, exit and new game; %d failures" % failures)
	quit(1 if failures else 0)
