extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func key(code: Key, pressed: bool, shift := false, alt := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.shift_pressed = shift
	event.alt_pressed = alt
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	var settings := root.get_node("GameSettings")
	settings.set_accessibility(false, false, false)
	var player := load("res://scenes/player.tscn").instantiate() as PlayerCharacter
	root.add_child(player)
	player.set_physics_process(false)
	preload("res://tests/player_test_support.gd").unlock_current_powers(player)
	var controller := player.input_controller
	# Real key event ordering, including releases consumed by a UI overlay.
	key(KEY_SHIFT, true, true)
	key(KEY_W, true, true)
	check(controller.capture().sprint_pressed, "Shift+W requests sprint")
	key(KEY_SHIFT, false)
	check(not controller.capture().sprint_pressed, "Releasing Shift before W clears sprint")
	key(KEY_W, false)
	key(KEY_SHIFT, true, true)
	key(KEY_W, true, true)
	key(KEY_W, false, true)
	key(KEY_SHIFT, false)
	check(not controller.capture().sprint_pressed, "Releasing W before Shift clears sprint")
	key(KEY_SHIFT, true, true)
	key(KEY_ALT, true, true, true)
	key(KEY_SHIFT, false, false, true)
	key(KEY_ALT, false)
	check(not controller.capture().sprint_pressed, "Shift release during power selector does not latch sprint")
	# Model a held event whose release happens outside the application.
	for notification_id in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT, Node.NOTIFICATION_PAUSED]:
		Input.action_press("sprint")
		controller.notification(notification_id)
		check(not controller.capture().sprint_pressed and not Input.is_action_pressed("sprint"), "Reset clears raw sprint after focus loss/pause")
	Input.action_press("sprint")
	var wheel := player.get_node("PowerSelector/Wheel")
	wheel.open()
	wheel.close(false)
	check(not controller.capture().sprint_pressed, "Power selector reset cannot resume a stale held sprint")
	Input.action_press("sprint")
	settings.input_bindings.controller_disconnected.emit()
	check(not controller.capture().sprint_pressed, "Controller disconnect clears raw held sprint")
	Input.action_release("sprint")
	key(KEY_SHIFT, true, true)
	check(controller.capture().sprint_pressed, "Fresh press works after cancellation")
	key(KEY_SHIFT, false)
	check(not controller.capture().sprint_pressed, "Fresh release stops sprint")
	player.free()
	print("Sprint input reset: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
