extends SceneTree
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func key(code: int, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	return event

func run() -> void:
	root.get_node("SaveManager")._save_path = OS.get_environment("TEMP").path_join("machine_test_%d.json" % OS.get_process_id())
	var bindings: Node = root.get_node("GameSettings").input_bindings
	bindings.reset_device("keyboard")
	var room := (load("res://assets/buildings/gas_station_hideout/gas_station_interior.tscn") as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	var player: PlayerCharacter = load("res://scenes/player.tscn").instantiate()
	room.add_child(player)
	player.set_physics_process(false)
	var machine: Node3D = room.get_node("power_machine/Interaction")
	check(room.has_node("power_machine/StaticBody3D/CollisionShape3D"), "User-created collision remains intact")
	player.global_position = machine.to_global(Vector3(0, 1.05, 8))
	check(not machine.try_interact(player), "Cannot open Powers from far away")
	player.global_position = machine.to_global(Vector3(0, 1.05, -1.3))
	check(not machine.try_interact(player), "Cannot operate machine from behind the wall")
	player.global_position = machine.to_global(Vector3(0, 1.05, 2.0))
	check(machine.can_interact(player), "Front of machine is usable outside its collision")
	player.is_dead = true
	check(not machine.try_interact(player), "Dead player cannot use machine")
	player.is_dead = false
	player.is_knocked_out = true
	check(not machine.try_interact(player), "Knocked-out player cannot use machine")
	player.is_knocked_out = false
	player.is_charging_flight = true
	check(not machine.try_interact(player), "Charging flight cannot open machine")
	player.is_charging_flight = false
	paused = true
	check(not machine.try_interact(player), "Machine cannot steal an existing pause")
	paused = false
	# Physical keyboard input reaches the actual player snapshot/interaction path.
	await process_frame
	Input.parse_input_event(key(KEY_E))
	Input.flush_buffered_events()
	check(Input.is_action_just_pressed("pick_up_vehicle"), "Physical E maps to interact")
	player._profiled_physics_process(1.0 / 60.0)
	var menu: Node = get_first_node_in_group(&"gameplay_menu")
	check(menu != null, "E creates the existing menu in a standalone room")
	if menu == null:
		quit(1)
		return
	check(menu.visible and paused and menu.tabs.current_tab == 0, "E opens Powers and pauses")
	check(menu.powers_page.progression == player.get_node("PlayerPowerController").progression, "Machine uses actual player purchases")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Menu releases the mouse")
	Input.parse_input_event(key(KEY_E, false))
	Input.flush_buffered_events()
	root.push_input(key(KEY_ESCAPE))
	check(not menu.visible and not paused, "Escape closes machine menu and unpauses")
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Closing restores camera control")
	menu.open_menu()
	menu.tabs.current_tab = 2
	menu.close_menu()
	check(machine.try_interact(player) and menu.tabs.current_tab == 0, "Machine selects Powers after visiting another tab")
	check(get_nodes_in_group(&"gameplay_menu").size() == 1, "Existing menu is reused")
	menu.close_menu()
	# Rebound controls drive the same path and the visible hint follows the binding.
	bindings.rebind("pick_up_vehicle", "keyboard", key(KEY_F8))
	bindings.active_device = "keyboard"
	machine._refresh = 0.0
	machine._process(0.2)
	check(machine.prompt.text.contains("F8"), "Machine prompt follows rebound interact key")
	await process_frame
	Input.parse_input_event(key(KEY_F8))
	Input.flush_buffered_events()
	player._profiled_physics_process(1.0 / 60.0)
	check(menu.visible and paused, "Rebound interact opens Powers through player input")
	Input.parse_input_event(key(KEY_F8, false))
	Input.flush_buffered_events()
	if "--render" in OS.get_cmdline_user_args():
		for frame in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/power_machine/powers_menu.png")
	menu.close_menu()
	bindings.reset_device("keyboard")
	room.free()
	print("POWER_MACHINE_INTERACTION_PASS failures=", failures)
	quit(1 if failures else 0)
