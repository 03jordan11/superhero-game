extends SceneTree
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func key(down: bool, location := KEY_LOCATION_LEFT) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ALT
	event.location = location
	event.pressed = down
	return event

func run() -> void:
	root.get_node("GameSettings").input_bindings.load_config(ConfigFile.new())
	var player: PlayerCharacter = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var powers := player.get_node("PlayerPowerController")
	var wheel := player.get_node("PowerSelector/Wheel")
	var laser := player.laser_eyes
	powers.progression.apply_save_data({"schema_version": 2, "upgrades": {"laser_eyes": 0}})
	check(powers.active_power == &"laser_eyes", "Laser Eyes starts equipped")
	player.state_machine.transition_to(&"JumpChargingState")
	player.vehicle_interactor.is_charging_vehicle_throw = true
	player.vehicle_interactor.vehicle_throw_hold_time = 0.5
	root.push_input(key(true, KEY_LOCATION_RIGHT))
	check(not wheel.visible, "Right Alt does not open wheel")
	root.push_input(key(true))
	check(wheel.visible and powers.is_selector_open(), "Held Left Alt opens wheel")
	check(not player.is_charging_jump and not player.vehicle_interactor.is_charging_throw(), "Opening cancels jump and throw charges")
	Input.action_press("attack")
	Input.action_press("jump")
	Input.action_press("move_forward")
	var snapshot: PlayerInputSnapshot = player.input_controller.capture()
	check(not snapshot.activate_power_pressed and not snapshot.jump_pressed, "Wheel blocks combat and traversal snapshots")
	var rotation := player.rotation
	var camera_rotation := player.spring_arm.rotation
	player.input_controller.apply_look(Vector2(1, 1))
	check(player.rotation == rotation and player.spring_arm.rotation == camera_rotation, "Wheel blocks camera rotation")
	for action in ["attack", "jump", "move_forward"]: Input.action_release(action)
	wheel.choose_direction(Vector2.RIGHT * 200)
	root.push_input(key(false))
	check(not wheel.visible and powers.active_power == &"ice", "Release equips the highlighted power")
	check(player.get_node("GameplayHUD/ActivePower").text.contains("Ice"), "HUD reflects equipped power")
	var fire := PlayerInputSnapshot.new()
	fire.aim_power_pressed = true
	fire.activate_power_pressed = true
	laser.update_power(0.1, PlayerInputSnapshot.new())
	laser.update_power(0.1, fire)
	check(not laser.firing and laser.heat == 0, "Unimplemented power cannot fire lasers")
	for i in 4:
		wheel.open()
		wheel.choose_direction(Vector2.UP.rotated(i * PI / 2) * 200)
		wheel.close(true)
		check(powers.active_power == wheel.IDS[i], "All four sectors are selectable")
	wheel.open()
	wheel.choose_direction(Vector2.ZERO)
	wheel.close(true)
	check(powers.active_power == &"electricity", "Center keeps current power")
	wheel.open()
	wheel.choose_direction(Vector2.UP * 200)
	wheel.cancel()
	check(powers.active_power == &"electricity", "Cancel preserves power")
	wheel.open()
	paused = true
	wheel._process(0)
	check(not wheel.visible and paused, "Another menu cancels selection without unpausing")
	paused = false
	wheel.open()
	wheel._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not wheel.visible, "Focus loss cancels wheel")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_LEFT_SHOULDER
	pad.pressed = true
	root.push_input(pad)
	check(wheel.visible and wheel._controller, "Controller LB opens selection")
	Input.action_press("look_down")
	wheel._process(0.016)
	pad.pressed = false
	root.push_input(pad)
	Input.action_release("look_down")
	check(not wheel.visible and powers.active_power == &"fire", "Right stick and LB release select power")
	root.push_input(key(true))
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	check(not wheel.visible and not paused, "Escape cancels without pausing")
	root.push_input(key(false))
	check(not powers.select_active_power(&"flight"), "Traversal cannot enter the ranged power slot")
	powers.select_active_power(&"laser_eyes")
	laser.update_power(0.1, PlayerInputSnapshot.new())
	laser.update_power(0.1, fire)
	check(laser.firing, "Equipped laser still fires while aiming")
	wheel.open()
	check(not laser.firing, "Opening wheel stops beam immediately")
	laser.update_power(0.1, PlayerInputSnapshot.new())
	wheel.close(true)
	laser.update_power(0.1, fire)
	check(not laser.firing, "Held attack cannot leak out of selection")
	laser.update_power(0.1, PlayerInputSnapshot.new())
	laser.update_power(0.1, fire)
	check(laser.firing, "Fresh attack resumes after selection")
	var manager := root.get_node("SaveManager")
	var original_path: String = manager._save_path
	manager._save_path = "res://artifacts/selector_test_save.json"
	powers.select_active_power(&"fire")
	check(manager.save_game(), "Save selected power")
	powers.select_active_power(&"ice")
	check(manager.load_game() and powers.active_power == &"fire", "Load restores selected power")
	for invalid in ["unknown", 42, null]:
		var file := FileAccess.open(manager._save_path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"player": {"active_power": invalid}}))
		file.close()
		check(manager.load_game() and powers.active_power == &"laser_eyes", "Invalid or legacy selections fall back safely")
	manager.delete_save()
	manager._save_path = original_path
	player.free()
	print("POWER_SELECTOR_TESTS: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
