extends SceneTree
var failures := 0

func _initialize() -> void:
	create_timer(120).timeout.connect(func(): push_error("Arena travel test timeout"); quit(1))
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var session_script = load("res://scripts/combat_arena_session.gd")
	# A real interior exercises standalone-player replacement and menu restoration.
	var city_mode := "--city" in OS.get_cmdline_user_args()
	var origin_path := "res://scenes/main.tscn" if city_mode else "res://assets/interiors/boxing_gym/boxing_gym.tscn"
	var room := load(origin_path).instantiate() as Node3D
	root.add_child(room)
	current_scene = room
	var hero := room.get_node("Player") as PlayerCharacter
	hero.stats.money = 765
	hero.stats.strength = 7
	hero.abilities.set_unlocked(PlayerAbilities.FLIGHT, true)
	hero.damage_receiver.health_component.current_health = 321.0
	var clock := get_first_node_in_group(&"game_clock")
	if clock != null:
		clock.set_time(19.5)
		clock.cycle_running = false
	hero.global_position += Vector3(2, 0, 0)
	var identity := hero.get_instance_id()
	var pose := hero.global_transform
	for cycle in (1 if city_mode else 2):
		pose = hero.global_transform
		var session: Node
		if city_mode:
			var menu := current_scene.get_node("PauseMenu")
			menu.pause_game()
			menu.arena_button.pressed.emit()
			await process_frame
			while root.get_node("LoadingScreen").active: await process_frame
			session = get_first_node_in_group(&"combat_arena_session")
		else:
			session = session_script.new()
			root.add_child(session)
			check(await session.enter(), "Enter training from interior")
		check(current_scene.scene_file_path == session.ARENA_PATH, "Arena becomes current scene")
		check(get_nodes_in_group(&"player").size() == 1, "Only training player is active")
		var trainee := current_scene.get_node("Player") as PlayerCharacter
		check(trainee != hero and not hero.is_inside_tree(), "Original hero retained outside tree")
		check(trainee.stats.money == 765 and trainee.stats.strength == 7, "Stats copied into training")
		check(trainee.abilities.is_unlocked(PlayerAbilities.FLIGHT), "Developer ability overrides copied")
		trainee.stats.money = 1
		trainee.stats.strength = 1
		trainee.abilities.set_unlocked(PlayerAbilities.FLIGHT, false)
		check(hero.stats.money == 765 and hero.stats.strength == 7 and hero.abilities.is_unlocked(PlayerAbilities.FLIGHT), "Training resources are isolated")
		check(await session.leave(), "Return succeeds")
		check(current_scene.scene_file_path == origin_path, "Returns to origin scene")
		check(get_nodes_in_group(&"player").size() == 1 and current_scene.get_node("Player").get_instance_id() == identity, "Returns same original hero")
		check(hero.global_transform.is_equal_approx(pose), "Entry position and orientation restored")
		check(hero.stats.money == 765 and hero.stats.strength == 7, "Training edits discarded")
		check(is_equal_approx(hero.get_current_health(), 321.0), "Original health preserved")
		clock = get_first_node_in_group(&"game_clock")
		if clock != null: check(is_equal_approx(clock.time_of_day, 19.5) and not clock.cycle_running, "World clock preserved")
		check(current_scene.has_node("PauseMenu") and current_scene.has_node("GameplayMenu"), "Interior menus restored")
		check(not paused and not root.is_input_disabled(), "Travel restores input and pause state")
		var menu := current_scene.get_node("PauseMenu")
		menu.pause_game()
		check(menu.arena_button.text == "Combat Arena", "Returned ESC menu can enter again")
		menu.resume_game()
		await process_frame
	current_scene.free()
	print("COMBAT_ARENA_TRAVEL_TEST failures=", failures)
	quit(1 if failures else 0)
