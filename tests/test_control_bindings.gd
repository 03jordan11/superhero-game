extends SceneTree
const BINDINGS = preload("res://scripts/input_bindings.gd")
var failures := 0
var settings: Node
var bindings: Node

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func key(code: int, down := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	return event

func button(code: int, down := true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = code
	event.pressed = down
	return event

func axis(code: int, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = code
	event.axis_value = value
	return event

func input(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	settings = root.get_node("GameSettings")
	bindings = settings.input_bindings
	var path := OS.get_environment("TEMP").path_join("control_bindings_%d.cfg" % OS.get_process_id())
	settings._settings_file = path
	bindings.load_config(ConfigFile.new())
	check(bindings.label_for("lock_target","keyboard")=="Tab" and bindings.label_for("gameplay_menu","keyboard")=="P","New targeting/menu defaults")
	var version_two:=ConfigFile.new(); version_two.set_value("bindings","version",2)
	version_two.set_value("bindings_keyboard","lock_target",{"kind":"key","code":KEY_CAPSLOCK})
	version_two.set_value("bindings_keyboard","gameplay_menu",{"kind":"key","code":KEY_TAB})
	version_two.set_value("bindings_keyboard","pick_up_vehicle",{"kind":"key","code":KEY_R})
	bindings.load_config(version_two)
	check(bindings.label_for("lock_target","keyboard")=="Tab" and bindings.label_for("gameplay_menu","keyboard")=="P","Previous Caps/Tab defaults migrate")
	check(bindings.label_for("pick_up_vehicle","keyboard")=="R","Version-two custom controls survive migration")
	bindings.load_config(ConfigFile.new())
	check(bindings.label_for("attack", "keyboard") == "Left Mouse" and bindings.label_for("pick_up_vehicle", "keyboard") == "E", "Power and vehicle defaults do not conflict")
	check(bindings.label_for("aim_power", "keyboard") == "Right Mouse" and bindings.label_for("attack", "controller") == "X", "Aim and power have mouse/controller bindings")
	check(bindings.label_for("secondary_power", "keyboard") == "Q" and bindings.label_for("secondary_power", "controller") == "RT", "Dragon Breath has independent Q and RT defaults")
	var legacy := ConfigFile.new()
	legacy.set_value("bindings_keyboard", "pick_up_vehicle", {"kind": "key", "code": KEY_E})
	legacy.set_value("bindings_keyboard", "jump", {"kind": "key", "code": KEY_K})
	bindings.load_config(legacy)
	check(bindings.label_for("pick_up_vehicle", "keyboard") == "E" and bindings.label_for("attack", "keyboard") == "Left Mouse" and bindings.label_for("jump", "keyboard") == "K", "Legacy E vehicle binding remains E while unrelated custom controls remain")
	var previous := ConfigFile.new()
	previous.set_value("bindings_keyboard", "pick_up_vehicle", {"kind": "key", "code": KEY_R})
	previous.set_value("bindings_keyboard", "secondary_power", {"kind": "key", "code": KEY_E})
	previous.set_value("bindings_keyboard", "jump", {"kind": "key", "code": KEY_K})
	bindings.load_config(previous)
	check(bindings.label_for("pick_up_vehicle", "keyboard") == "E" and bindings.label_for("secondary_power", "keyboard") == "Q" and bindings.label_for("jump", "keyboard") == "K", "Old R/E defaults migrate to E/Q without resetting custom jump")
	bindings.rebind("pick_up_vehicle", "keyboard", key(KEY_R))
	var saved_current := ConfigFile.new()
	bindings.write_config(saved_current)
	bindings.load_config(saved_current)
	check(bindings.label_for("pick_up_vehicle", "keyboard") == "R", "New explicitly customized R binding survives reload")
	previous.set_value("bindings_keyboard", "jump", {"kind": "key", "code": KEY_Q})
	bindings.load_config(previous)
	check(bindings.label_for("jump", "keyboard") == "Q" and bindings.label_for("pick_up_vehicle", "keyboard") == "E" and bindings.label_for("secondary_power", "keyboard") != "Q", "Custom Q binding takes priority over a migrated default")
	bindings.load_config(ConfigFile.new())
	check(bindings.label_for("jump", "controller") == "A", "Xbox jump defaults to A")
	check(bindings.label_for("toggle_flight", "controller") == "Y", "Xbox flight defaults to Y")
	check(bindings.label_for("attack", "controller") == "X", "Xbox attack defaults to X")
	check(bindings.label_for("sprint", "controller").begins_with("L3"), "Xbox sprint defaults to L3")
	var result: String = bindings.rebind("jump", "keyboard", key(KEY_F))
	check(result.contains("Swapped") and bindings.label_for("toggle_flight", "keyboard") == "Space", "Conflicts swap without losing an action")
	check(bindings.label_for("jump", "controller") == "A", "Keyboard rebinding preserves Xbox")
	bindings.rebind("attack", "controller", axis(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	check(bindings.label_for("attack", "controller") == "RT", "Trigger binding")
	check(bindings.rebind("move_forward", "controller", button(JOY_BUTTON_X)).contains("fixed"), "Controller movement cannot be rebound")
	check(bindings.rebind("jump", "controller", axis(JOY_AXIS_RIGHT_X, 1.0)).contains("Choose"), "Camera axes cannot be assigned as buttons")
	check(bindings.rebind("jump", "controller", button(JOY_BUTTON_GUIDE)).contains("Choose"), "System Guide button remains reserved")
	check(settings.save_settings() == OK, "Bindings saved with settings")
	bindings.reset_device("keyboard")
	check(bindings.label_for("jump", "keyboard") == "Space" and bindings.label_for("attack", "controller") == "RT", "Reset affects only selected device")
	settings.load_settings(path)
	check(bindings.label_for("jump", "keyboard") == "F" and bindings.label_for("attack", "controller") == "RT", "Both binding sets survive reload")
	var invalid := ConfigFile.new()
	invalid.set_value("bindings_controller", "jump", {"kind": "trigger", "code": JOY_AXIS_LEFT_X})
	invalid.set_value("bindings_keyboard", "jump", {"kind": "key", "code": KEY_F})
	invalid.set_value("bindings_keyboard", "toggle_flight", {"kind": "key", "code": KEY_F})
	bindings.load_config(invalid)
	check(bindings.label_for("jump", "controller") == "A" and bindings.label_for("jump", "keyboard") == "Space", "Invalid axes and duplicate saved bindings restore usable defaults")
	# Real scene UI capture; no private direct capture calls for assigning input.
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	for i in range(2):
		root.push_input(button(JOY_BUTTON_DPAD_DOWN))
		root.push_input(button(JOY_BUTTON_DPAD_DOWN, false))
	check(root.gui_get_focus_owner() == menu.get_node("Center/Menu/SettingsButton"), "Controller can navigate main menu")
	root.push_input(button(JOY_BUTTON_A))
	root.push_input(button(JOY_BUTTON_A, false))
	check(menu.settings_menu.visible, "A opens settings")
	for i in range(3):
		root.push_input(button(JOY_BUTTON_RIGHT_SHOULDER))
		root.push_input(button(JOY_BUTTON_RIGHT_SHOULDER, false))
	check(menu.settings_menu.tabs.current_tab == 3, "RB cycles to Controls tab")
	await process_frame
	var panel = menu.settings_menu.controls_panel
	for i in range(5):
		root.push_input(button(JOY_BUTTON_DPAD_DOWN))
		root.push_input(button(JOY_BUTTON_DPAD_DOWN, false))
	check(root.gui_get_focus_owner() == panel.buttons.keyboard.jump, "D-pad reaches binding rows")
	root.push_input(button(JOY_BUTTON_A))
	root.push_input(button(JOY_BUTTON_A, false))
	check(bindings.is_capturing and panel._dialog.visible, "Keyboard capture opens")
	root.push_input(button(JOY_BUTTON_Y))
	check(bindings.is_capturing, "Wrong device does not bind or dismiss")
	root.push_input(key(KEY_K))
	check(not bindings.is_capturing and panel.buttons.keyboard.jump.text == "K", "Input reaches capture and updates UI")
	panel.buttons.controller.jump.pressed.emit()
	root.push_input(key(KEY_ESCAPE))
	check(not bindings.is_capturing and bindings.label_for("jump", "controller") == "A" and menu.settings_menu.visible, "Escape cancels capture without leaving settings")
	panel.buttons.controller.jump.pressed.emit()
	root.push_input(axis(JOY_AXIS_LEFT_X, 0.95))
	root.push_input(axis(JOY_AXIS_TRIGGER_LEFT, 0.3))
	check(bindings.is_capturing, "Stick motion and small trigger noise are ignored")
	root.push_input(axis(JOY_AXIS_TRIGGER_LEFT, 0.8))
	check(not bindings.is_capturing and panel.buttons.controller.jump.text == "LT", "Controller trigger capture works")
	panel.buttons.controller.jump.pressed.emit()
	root.push_input(button(JOY_BUTTON_B))
	check(not bindings.is_capturing and bindings.label_for("jump", "controller") == "B" and menu.settings_menu.visible, "B can be assigned without navigating back")
	panel.buttons.controller.jump.pressed.emit()
	bindings._capture_timer.start(0.02)
	await create_timer(0.06).timeout
	check(not bindings.is_capturing, "Controller can escape capture by waiting for timeout")
	panel.buttons.keyboard.jump.pressed.emit()
	menu._on_back_pressed()
	check(not bindings.is_capturing and not panel._dialog.visible, "Hiding settings cancels capture")
	menu.free()
	bindings.load_config(ConfigFile.new())
	var player: PlayerCharacter = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	preload("res://tests/player_test_support.gd").unlock_current_powers(player)
	player.set_physics_process(false)
	player.input_controller.set_process(false)
	input(button(JOY_BUTTON_A))
	check(player.input_controller.capture().jump_pressed, "Xbox A reaches the jump snapshot")
	check(player.get_node("GameplayHUD").binding_text("jump") == "A", "Xbox input switches HUD hints")
	input(button(JOY_BUTTON_A, false))
	# Finish the jump input frame before measuring stick-only movement.
	await process_frame
	await process_frame
	input(axis(JOY_AXIS_LEFT_Y, -0.1))
	check(player.input_controller.capture().movement == Vector2.ZERO, "Left-stick deadzone suppresses drift")
	input(axis(JOY_AXIS_LEFT_Y, -0.6))
	var snapshot: PlayerInputSnapshot = player.input_controller.capture()
	check(snapshot.movement.y < -0.45 and snapshot.movement.y > -0.55, "Left stick retains partial strength")
	player.state_machine.physics_update(1.0, snapshot)
	check(is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), player._get_walk_speed() * 0.5), "Partial stick produces partial ground speed")
	check(player.state_machine.transition_to(&"FlyingState"), "Flight fixture unlocked")
	player.state_machine.physics_update(1.0, snapshot)
	check(is_equal_approx(player.velocity.length(), player._get_walk_speed() * 0.5), "Partial stick produces partial flight speed")
	input(axis(JOY_AXIS_LEFT_Y, 0.0))
	input(axis(JOY_AXIS_RIGHT_X, 0.6))
	var yaw := player.rotation.y
	player.input_controller.update_controller_look(0.1)
	check(is_equal_approx(player.rotation.y - yaw, -deg_to_rad(150.0) * 0.05), "Right stick rotates camera at delta-scaled analog speed")
	input(axis(JOY_AXIS_RIGHT_X, 0.0))
	input(axis(JOY_AXIS_RIGHT_Y, 1.0))
	player.input_controller.update_controller_look(10.0)
	check(is_equal_approx(player.spring_arm.rotation.x, deg_to_rad(player.min_camera_angle)), "Controller camera respects pitch clamp")
	input(axis(JOY_AXIS_RIGHT_Y, 0.0))
	settings.set_accessibility(true, false, false)
	input(button(JOY_BUTTON_LEFT_STICK))
	input(button(JOY_BUTTON_LEFT_STICK, false))
	check(player.input_controller.capture().sprint_pressed, "L3 works with toggle sprint")
	bindings._on_connection_changed(0, false)
	check(not player.input_controller.capture().sprint_pressed, "Controller disconnect resets sprint latch")
	bindings.rebind("sprint", "controller", axis(JOY_AXIS_TRIGGER_LEFT, 1.0))
	input(axis(JOY_AXIS_TRIGGER_LEFT, 0.8))
	input(axis(JOY_AXIS_TRIGGER_LEFT, 0.9))
	check(player.input_controller.capture().sprint_pressed, "Repeated trigger samples toggle sprint only once")
	input(axis(JOY_AXIS_TRIGGER_LEFT, 0.0))
	input(axis(JOY_AXIS_TRIGGER_LEFT, 0.8))
	check(not player.input_controller.capture().sprint_pressed, "Second trigger squeeze toggles off")
	input(axis(JOY_AXIS_TRIGGER_LEFT, 0.0))
	bindings.rebind("attack", "controller", axis(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	check(bindings.is_action_press(axis(JOY_AXIS_TRIGGER_RIGHT, 0.8), "attack"), "Trigger attack edge")
	check(not bindings.is_action_press(axis(JOY_AXIS_TRIGGER_RIGHT, 0.9), "attack"), "Held trigger does not repeat attacks")
	check(not bindings.is_action_press(axis(JOY_AXIS_TRIGGER_RIGHT, 0.0), "attack"), "Release is not attack")
	check(bindings.is_action_press(axis(JOY_AXIS_TRIGGER_RIGHT, 0.8), "attack"), "Trigger can attack again after release")
	# Pause uses a separate action; B must descend without pausing or freeing mouse.
	var scene = load("res://scenes/main.tscn").instantiate()
	var pause = scene.get_node("PauseMenu")
	scene.remove_child(pause)
	scene.free()
	root.add_child(pause)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var mouse_mode_before := Input.mouse_mode
	input(button(JOY_BUTTON_B))
	check(not paused and player.input_controller.capture().descend_pressed, "B descends without pausing")
	check(Input.mouse_mode == mouse_mode_before, "B does not release mouse")
	input(button(JOY_BUTTON_B, false))
	input(button(JOY_BUTTON_START))
	input(button(JOY_BUTTON_START, false))
	check(paused and pause.visible, "Menu button pauses")
	pause._on_settings_pressed()
	pause.settings_menu.tabs.current_tab = 3
	panel = pause.settings_menu.controls_panel
	panel.buttons.controller.pause.pressed.emit()
	root.push_input(button(JOY_BUTTON_Y))
	check(paused and pause.settings_menu.visible and bindings.label_for("pause", "controller") == "Y", "Pause can be rebound while paused without closing settings")
	input(button(JOY_BUTTON_B))
	input(button(JOY_BUTTON_B, false))
	check(paused and not pause.settings_menu.visible, "B backs out of settings")
	input(button(JOY_BUTTON_B))
	input(button(JOY_BUTTON_B, false))
	check(not paused, "B resumes from pause actions")
	input(button(JOY_BUTTON_Y))
	input(button(JOY_BUTTON_Y, false))
	check(paused, "Rebound pause action works")
	pause.resume_game()
	pause.free()
	player.free()
	DirAccess.remove_absolute(path)
	print("Control bindings: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
