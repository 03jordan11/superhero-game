extends SceneTree
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func key(code: int, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	return event

func run() -> void:
	root.get_node("SaveManager")._save_path = OS.get_environment("TEMP").path_join("sleep_test_%d.json" % OS.get_process_id())
	var settings: Node = root.get_node("GameSettings")
	settings.set_show_control_hints(false, false)
	var bindings: Node = settings.input_bindings
	bindings.reset_device("keyboard")
	var room: Node3D = load("res://assets/buildings/gas_station_hideout/gas_station_interior.tscn").instantiate()
	root.add_child(room); current_scene = room
	var clock: Node = room.get_node("Clock")
	clock.cycle_running = false
	var player: PlayerCharacter = load("res://scenes/player.tscn").instantiate()
	room.add_child(player); player.set_physics_process(false)
	var hud: Node = player.get_node("GameplayHUD")
	var bed: Node3D = room.get_node("Model/Props/Cot/SleepInteraction")
	clock.set_time(0.0)
	check(hud.get_node("Clock").text == "00:00", "HUD shows zero-padded midnight")
	clock.set_time(9.0 + 5.01 / 60.0)
	check(hud.get_node("Clock").text == "09:05", "HUD uses 24-hour HH:MM with hints hidden")
	clock.set_time(23.0 + 59.01 / 60.0)
	check(hud.get_node("Clock").text == "23:59", "HUD shows last minute before midnight")
	clock.set_time(23.5)
	player.global_position = bed.global_position + Vector3(0, 0, 6)
	check(not bed.try_interact(player), "Cannot sleep from far away")
	player.global_position = bed.global_position + Vector3(0, 0.2, 1.2)
	await physics_frame; await physics_frame
	check(bed.can_interact(player), "Cot is usable from its open side")
	player.is_dead = true
	check(not bed.try_interact(player), "Sleep cannot revive dead players")
	player.is_dead = false
	player.is_flying = true
	check(not bed.try_interact(player), "Cannot sleep while flying")
	player.is_flying = false
	paused = true
	check(not bed.try_interact(player), "Sleep cannot act through a pause menu")
	paused = false
	player.damage_receiver.health_component.apply_damage(DAMAGE.new(300.0))
	await process_frame
	Input.parse_input_event(key(KEY_E)); Input.flush_buffered_events()
	player._profiled_physics_process(1.0/60.0)
	Input.parse_input_event(key(KEY_E, false)); Input.flush_buffered_events()
	check(is_equal_approx(clock.time_of_day, 7.5), "Physical E advances exactly eight hours across midnight")
	check(player.get_current_health() == player.get_max_health(), "Sleep restores full current maximum health")
	check(hud.health_bar.value == player.get_max_health(), "Healing updates the HUD through health signals")
	check(hud.get_node("Clock").text == "07:30", "HUD immediately reflects sleep time")
	check(bed.prompt.text.contains("RESTED"), "Rest gives visible feedback")
	check(not bed.try_interact(player), "One interaction cannot skip repeated nights")
	bed._rested_until = 0
	bindings.rebind("pick_up_vehicle", "keyboard", key(KEY_F8))
	bindings.active_device = "keyboard"
	bed._refresh = 0.0; bed._process(0.2)
	check(bed.prompt.text.contains("F8") and bed.prompt.text.contains("8"), "Bed hint follows rebound input and sleep duration")
	await process_frame
	Input.parse_input_event(key(KEY_F8)); Input.flush_buffered_events()
	player._profiled_physics_process(1.0/60.0)
	Input.parse_input_event(key(KEY_F8, false)); Input.flush_buffered_events()
	check(is_equal_approx(clock.time_of_day, 15.5), "Rebound key sleeps even at full health")
	clock.cycle_running = true; clock.day_length_minutes = 1.0
	clock._process(1.0)
	check(is_equal_approx(clock.time_of_day, 15.9), "Time continues to progress indoors")
	clock.cycle_running = false
	if "--render" in OS.get_cmdline_user_args():
		bindings.reset_device("keyboard")
		clock.set_time(7.5)
		bed._rested_until = 0; bed._refresh = 0.0; bed._process(0.2)
		var camera := Camera3D.new(); room.add_child(camera)
		camera.position = Vector3(-5.4, 2.6, -3.1)
		camera.look_at(bed.global_position); camera.make_current()
		for tick in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/hideout_sleep.png")
	bindings.reset_device("keyboard")
	room.free()
	print("HIDEOUT_SLEEP_PASS failures=", failures)
	quit(1 if failures else 0)
