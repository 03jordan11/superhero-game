extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(value: bool, copy: String) -> void:
	if not value:
		failures += 1
		push_error(copy)
func key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event
func run() -> void:
	var manager := root.get_node("SaveManager")
	var path := OS.get_environment("TEMP").path_join("gameplay_menu_%d.json" % OS.get_process_id())
	manager._save_path = path
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var player: PlayerCharacter = main.get_node("Player")
	player.set_physics_process(false)
	var controller = player.get_node("PlayerPowerController")
	var progression = controller.progression
	var menu = main.get_node("GameplayMenu")
	var pause = main.get_node("PauseMenu")
	for ability in controller.REQUIREMENTS:
		check(player.abilities.is_unlocked(ability) == (ability == PlayerAbilities.POWER_JUMP), "Only Power Jump starts unlocked: " + String(ability))
	check(not player.state_machine.transition_to(&"FlyingState"), "Locked flight cannot start")
	check(player.state_machine.transition_to(&"JumpChargingState"), "Starter Power Jump is available")
	player.state_machine.transition_to(&"GroundedState")
	check(not player.vehicle_interactor.try_pick_up_vehicle(), "Locked vehicle lift refuses pickup")
	var snapshot := PlayerInputSnapshot.new()
	snapshot.movement = Vector2.UP
	snapshot.sprint_pressed = true
	player.current_ground_speed = player._get_walk_speed()
	player.state_machine.physics_update(1.0, snapshot)
	check(is_equal_approx(player.current_ground_speed, player._get_walk_speed()), "Locked super speed remains at ordinary speed")
	root.push_input(key(KEY_P))
	check(menu.visible and paused and not pause.visible, "P opens gameplay menu and pauses")
	check(menu.tabs.get_tab_count() == 5, "All five groups exist")
	for i in range(5):
		check(menu.tabs.get_tab_title(i) == ["Powers", "Gear", "Attributes", "Journal", "Map"][i], "Requested tab order")
	for i in [1, 3]: check(menu.tabs.get_tab_control(i).get_child_count() == 0, "Future page stays blank")
	check(menu.tabs.get_tab_control(4).get_child_count() == 1, "Map tab contains regional map")
	check(menu.map_page.player == player and menu.map_page.city == main.get_node("SuperCity"), "Map uses live player and saved city coordinate space")
	check(menu.powers_page.progression == progression, "Page shares the player's authoritative progression")
	check(not menu.powers_page.back_button.is_visible_in_tree(), "Embedded Powers uses outer menu close")
	check(not pause.pause_actions.has_node("PowersButton"), "Pause actions no longer include Powers")
	check(pause.pause_actions.has_node("CombatArenaButton") == OS.is_debug_build(), "Combat Arena entry is development-only")
	root.push_input(key(KEY_P))
	check(not menu.visible and not paused, "P closes the gameplay menu")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_RIGHT_STICK
	pad.pressed = true
	root.push_input(pad)
	check(menu.visible and paused, "Xbox R3 opens the gameplay menu")
	pad = pad.duplicate()
	pad.button_index = JOY_BUTTON_RIGHT_SHOULDER
	root.push_input(pad)
	check(menu.tabs.current_tab == 1, "RB switches gameplay tabs")
	pad = pad.duplicate()
	pad.button_index = JOY_BUTTON_B
	root.push_input(pad)
	check(not paused and not menu.visible, "Xbox B closes the gameplay menu")
	main.get_node("DeveloperMenu").commands.execute("add pp 5")
	check(progression.tokens == 5 and not manager.has_save(), "Console grants target player progression without saving")
	check(progression.purchase("flight"), "Flight core purchase")
	check(player.abilities.is_unlocked(PlayerAbilities.FLIGHT) and not player.abilities.is_unlocked(PlayerAbilities.FLIGHT_BOOST), "Flight core grants only normal flight")
	check(player.state_machine.transition_to(&"FlyingState"), "Purchased flight works")
	player.state_machine.physics_update(1.0, snapshot)
	check(is_equal_approx(player.velocity.length(), player._get_walk_speed()), "Flight boost stays gated behind upgrade one")
	check(progression.purchase("flight"), "Flight upgrade one purchase")
	player.state_machine.physics_update(1.0, snapshot)
	check(player.velocity.length() > player._get_walk_speed(), "Flight upgrade one enables existing boost")
	check(not player.abilities.is_unlocked(PlayerAbilities.GROUND_SLAM), "Dive bomb still locked")
	progression.purchase("flight")
	check(player.abilities.is_unlocked(PlayerAbilities.GROUND_SLAM), "Flight upgrade two grants ground slam")
	player.global_position.y = 50.0
	check(player.state_machine.transition_to(&"GroundSlamState", {"target_position": Vector3.ZERO}), "Purchased Dive Bomb can start existing slam")
	player.state_machine.transition_to(&"GroundedState")
	progression.purchase("super_leap")
	check(player.state_machine.transition_to(&"JumpChargingState"), "Purchased charged jump works")
	player.state_machine.transition_to(&"GroundedState")
	progression.purchase("super_speed")
	check(not player.abilities.is_unlocked(PlayerAbilities.WALL_RUN), "Speed core does not skip wall-run tiers")
	player.state_machine.physics_update(1.0, snapshot)
	check(player.current_ground_speed > player._get_walk_speed(), "Speed core enables boosted ground movement")
	controller.progression.add_tokens(20)
	for tier in range(1, 4):
		progression.purchase("super_speed")
		check(player.abilities.is_unlocked(PlayerAbilities.WALL_RUN) == (tier == 3), "Wall run follows documented upgrade path")
	var base_strength := player.stats.strength
	for tier in range(3):
		progression.purchase("strength")
		check(player.abilities.is_unlocked(PlayerAbilities.VEHICLE_LIFT) == (tier == 2), "Car lifting requires Strength upgrade two")
	check(player.stats.strength == base_strength, "Power bonus does not mutate base Strength")
	progression.purchase("mind")
	check(player.abilities.is_unlocked(PlayerAbilities.TROUBLE_SENSE), "Mind core grants existing encounter marker")
	progression.purchase("fire")
	check(player.abilities.is_unlocked(PlayerAbilities.FIRE), "Fire core unlocks the implemented fire ability")
	menu.open_menu()
	menu.tabs.current_tab = 2
	player.stats.strength = 17
	check(menu.attribute_labels.strength.text == "Strength  22 (+5)", "Attributes display effective stats and bonus")
	check(menu.attribute_labels.strength.text.contains("(+5)"), "Purchased Strength bonus is visible")
	check(menu.attribute_text("strength", 17, 5) == "Strength  22 (+5)", "Attributes show effective value and separate power contribution")
	check(controller.attribute_bonus("strength") == 5, "Strength core adds five points")
	player.stats.add_experience(100)
	check(menu.level_label.text.contains("Level 2"), "Visible level and XP refresh from stats")
	var translation := Translation.new()
	translation.locale = "fr"
	translation.add_message("gameplay.tab.map", "Carte")
	translation.add_message("gameplay.attribute.strength", "Force")
	translation.add_message("power.flight.upgrade.2.name", "Plongeon")
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale("fr")
	await process_frame
	menu.powers_page.select_power("flight")
	check(menu.tabs.get_tab_title(4) == "Carte" and menu.attribute_labels.strength.text.begins_with("Force"), "Menu and attributes localize live")
	check(menu.powers_page.upgrade_names[1].text == "Plongeon", "Upgrade names localize live")
	TranslationServer.set_locale("en")
	root.push_input(key(KEY_ESCAPE))
	check(not paused and not menu.visible and not pause.visible, "Escape closes the gameplay menu without opening Pause")
	check(manager.save_game(), "Save writes current power purchases")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(saved.power_menu.schema_version == 2 and saved.power_menu.upgrades.flight == 2, "Saved tiers have explicit schema")
	progression.apply_save_data({})
	check(not player.abilities.is_unlocked(PlayerAbilities.FLIGHT), "Reset removes access")
	check(manager.load_game() and player.abilities.is_unlocked(PlayerAbilities.FLIGHT_BOOST) and player.abilities.is_unlocked(PlayerAbilities.VEHICLE_LIFT), "Loading restores gameplay unlocks")
	check(JSON.parse_string(FileAccess.get_file_as_string(path)) == saved, "Load does not autosave")
	# Legacy default-true ability flags must not bypass purchases.
	saved.erase("power_menu")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	manager.load_game()
	check(not player.abilities.is_unlocked(PlayerAbilities.FLIGHT) and progression.level("super_leap") == 0, "Legacy saves without purchases start locked")
	progression.apply_save_data({"tokens": 7, "upgrades": {"ground_slam": 0, "telekinesis": 1, "super_leap": 0}})
	check(progression.level("flight") == 2 and progression.level("mind") == 1 and progression.level("super_leap") == 0, "Old purchased branches migrate; starter remains available")
	manager._save_path = path.path_join("missing/file.json")
	menu.open_menu()
	menu.powers_page.select_power("super_leap")
	menu.powers_page._purchase_selected()
	check(player.abilities.is_unlocked(PlayerAbilities.POWER_JUMP) and menu.powers_page.feedback_label.text.contains("saving failed"), "Save failure retains purchase and reports retry")
	menu.close_menu()
	manager._save_path = path
	# A saved assignment that occupies new defaults must survive adding this action.
	var bindings: Node = root.get_node("GameSettings").input_bindings
	var config := ConfigFile.new()
	bindings.write_config(config)
	config.erase_section_key("bindings_keyboard", "gameplay_menu")
	config.erase_section_key("bindings_controller", "gameplay_menu")
	config.set_value("bindings_keyboard", "jump", {"kind": "key", "code": KEY_P})
	config.set_value("bindings_controller", "jump", {"kind": "button", "code": JOY_BUTTON_RIGHT_STICK})
	bindings.load_config(config)
	check(bindings.label_for("jump", "keyboard") == "P" and bindings.label_for("jump", "controller").begins_with("R3"), "Adding menu binding preserves existing custom assignments")
	check(bindings.label_for("gameplay_menu", "keyboard") != "P", "New action finds a free default if occupied")
	main.free()
	DirAccess.remove_absolute(path)
	print("Gameplay menu: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
