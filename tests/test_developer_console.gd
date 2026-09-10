extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)

func run() -> void:
	var saves := root.get_node("SaveManager")
	var path := OS.get_environment("TEMP").path_join("console_%d.json" % OS.get_process_id())
	saves._save_path = path
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var player: PlayerCharacter = main.get_node("Player")
	player.set_physics_process(false)
	var menu = main.get_node("DeveloperMenu")
	var commands = menu.commands
	var progression = player.get_node("PlayerPowerController").progression
	check(progression.level("super_leap") == 0 and player.abilities.is_unlocked(PlayerAbilities.POWER_JUMP), "Power Jump is a real starter core")
	check(not menu.visible and not paused, "Console starts hidden")
	key(KEY_QUOTELEFT)
	check(menu.visible and paused and root.get_node("DebugManager").developer_menu_open and menu.command_input.has_focus(), "Shortcut opens a paused focused console")
	await process_frame
	menu.command_input.text = "SeT strength 20"
	key(KEY_ENTER)
	check(player.stats.strength == 20 and menu.output.text.contains("base 20"), "Enter executes a case-insensitive command and shows result")
	menu.command_input.text = "draft"
	key(KEY_UP)
	check(menu.command_input.text == "SeT strength 20", "Up recalls history")
	key(KEY_DOWN)
	check(menu.command_input.text == "draft", "Down restores draft")
	menu.command_input.text = "add a"
	key(KEY_TAB)
	check(menu.command_input.text == "add attr " and not main.get_node("GameplayMenu").visible, "Tab completes arguments without opening gameplay menu")
	commands.execute("add xp 300")
	commands.execute("add attr 3")
	commands.execute("add pp 12")
	check(player.stats.level == 3 and player.stats.attribute_points == 5 and progression.tokens == 12, "Grants apply XP levels, attribute balance and power points")
	check(not saves.has_save(), "Console edits never save implicitly")
	for invalid in ["set speed 0", "set speed -1", "set speed 1.5", "set speed 999999999999999999999999", "set speed nan", "set speed 2 extra", "set money 3", "add attr -10", "add pp 1;reset", "power flight 3", "spawn gang", "audio horn", "camera", "reset now"]:
		commands.execute(invalid)
	check(player.stats.speed == 1 and player.stats.attribute_points == 5 and progression.tokens == 12, "Invalid or removed commands cannot mutate player state")
	commands.execute("set speed 9223372036854775807")
	check(player.stats.speed == PlayerStats.MAX_PROGRESSION_VALUE, "Valid integer boundary stays exact")
	commands.execute("set speed 2")
	check(commands.execute("save").contains("saved") and saves.has_save(), "Explicit save persists progression")
	var saved := FileAccess.get_file_as_string(path)
	progression.purchase("strength")
	commands.execute("set strength 25")
	check(player.stats.strength == 25 and player.stats.get_effective_strength() == 30, "Set changes base while preserving derived bonus")
	commands.execute("save")
	saved = FileAccess.get_file_as_string(path)
	progression.upgrades["flight"] = 2
	progression.upgrades["super_leap"] = 1
	progression.changed.emit()
	player.state_machine.transition_to(&"FlyingState")
	player.abilities.set_unlocked(PlayerAbilities.FIRE, true)
	player._die()
	commands.execute("reset")
	check(player.stats.strength == 1 and player.stats.speed == 1 and player.stats.resilience == 1, "Reset sets all attributes to one")
	check(player.stats.level == 1 and player.stats.experience == 0 and player.stats.attribute_points == 0 and progression.tokens == 0, "Reset clears level and currencies")
	for id in player.abilities.unlocked_abilities:
		check(player.abilities.is_unlocked(id) == (id == PlayerAbilities.POWER_JUMP), "Reset leaves only Power Jump")
	check(not player.is_dead and not player.is_flying and player.charged_jump_output_multiplier == 1 and player.get_current_health() == 100 and player.stamina.current == 10, "Reset revives player and restores base health, stamina and jump")
	check(player.state_machine.active_state is PlayerGroundedState and player.velocity == Vector3.ZERO, "Reset clears active traversal")
	check(FileAccess.get_file_as_string(path) == saved, "Reset does not alter saved file")
	check(commands.execute("load").contains("loaded") and player.stats.strength == 25 and progression.level("strength") == 0, "Load restores saved attributes and purchases")
	check(FileAccess.get_file_as_string(path) == saved, "Load does not autosave")
	commands.execute("debug hud on")
	check(main.get_node("PerformanceHUD").visible and player.player_hud.visible, "HUD command controls performance and player diagnostics")
	commands.execute("debug landing on")
	check(root.get_node("DebugManager").show_landing_target, "Landing command reaches existing indicator")
	commands.execute("debug hud off")
	commands.execute("debug landing off")
	var before := main.get_child_count()
	commands.execute("spawn civilian")
	commands.execute("spawn hostile")
	check(main.get_child_count() == before + 2 and paused, "NPC commands spawn while simulation stays paused")
	var current_health := player.get_current_health()
	await physics_frame
	await physics_frame
	check(player.get_current_health() == current_health, "Spawned hostiles cannot attack while console is paused")
	saves._save_path = path.path_join("missing/save.json")
	check(commands.execute("save").contains("Save failed"), "Save failure is explicit")
	saves._save_path = path
	menu._submit("clear")
	check(menu.output.text.is_empty(), "Clear clears output")
	key(KEY_ESCAPE)
	check(not menu.visible and not paused and not main.get_node("PauseMenu").visible, "Escape closes console without opening Pause")
	main.get_node("PauseMenu").pause_game()
	key(KEY_QUOTELEFT)
	check(not menu.visible and paused, "Console cannot steal another menu's pause")
	main.get_node("PauseMenu").resume_game()
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_BACK
	pad.pressed = true
	root.push_input(pad)
	check(menu.visible and paused, "Xbox View opens console")
	main.free()
	check(not paused and not root.get_node("DebugManager").developer_menu_open, "Removing an open console releases its pause")
	DirAccess.remove_absolute(path)
	print("Developer console: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
