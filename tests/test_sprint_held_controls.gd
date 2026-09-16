extends SceneTree

const SUPPORT = preload("res://tests/player_test_support.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var settings := root.get_node("GameSettings")
	settings.set_accessibility(false, false, false)
	var player := load("res://scenes/player.tscn").instantiate() as PlayerCharacter
	root.add_child(player)
	player.set_physics_process(false)
	SUPPORT.unlock_current_powers(player)
	var controller := player.input_controller
	Input.action_press("move_forward")
	SUPPORT.set_sprint_held(true)
	check(controller.capture().sprint_pressed, "Physical Shift starts sprint")
	SUPPORT.set_sprint_held(false)
	# Fault injection: physical key is released but the action remains pressed,
	# matching the Godot 4.7.2 Windows report (godotengine/godot#122728).
	Input.action_press("sprint")
	check(Input.is_action_pressed("sprint") and not Input.is_physical_key_pressed(KEY_SHIFT), "Fixture has a stale action and a released physical key")
	check(not controller.capture().sprint_pressed, "Released Shift overrides a stale sprint action while W remains held")
	Input.action_release("sprint")
	SUPPORT.set_sprint_held(true)
	check(controller.capture().sprint_pressed, "A fresh Shift press still works")
	controller.reset()
	check(not controller.capture().sprint_pressed, "Reset suppresses even a physically held Shift")
	SUPPORT.set_sprint_held(false)
	SUPPORT.set_sprint_held(true)
	check(controller.capture().sprint_pressed, "Release and repress resumes after reset")
	SUPPORT.set_sprint_held(false)
	# Custom keyboard/mouse bindings must get the same protection.
	var original: Array[InputEvent] = InputMap.action_get_events("sprint")
	for binding in [settings.input_bindings.make_event({"kind": "key", "code": KEY_K}), settings.input_bindings.make_event({"kind": "mouse", "code": MOUSE_BUTTON_XBUTTON1})]:
		InputMap.action_erase_events("sprint")
		InputMap.action_add_event("sprint", binding)
		SUPPORT.set_sprint_held(true)
		check(controller.capture().sprint_pressed, "Rebound control starts sprint")
		SUPPORT.set_sprint_held(false)
		Input.action_press("sprint")
		check(not controller.capture().sprint_pressed, "Released rebound control rejects stale sprint")
		Input.action_release("sprint")
	InputMap.action_erase_events("sprint")
	for binding in original:
		InputMap.action_add_event("sprint", binding)
	# A held gamepad button remains a valid source when Shift is up.
	InputMap.action_erase_events("sprint")
	var gamepad_binding := InputEventJoypadButton.new()
	gamepad_binding.device = 0
	gamepad_binding.button_index = JOY_BUTTON_LEFT_STICK
	InputMap.action_add_event("sprint", gamepad_binding)
	var joy := InputEventJoypadButton.new()
	joy.device = 0
	joy.button_index = JOY_BUTTON_LEFT_STICK
	joy.pressed = true
	Input.parse_input_event(joy)
	Input.flush_buffered_events()
	check(controller.capture().sprint_pressed, "Gamepad sprint works with Shift released")
	joy = joy.duplicate()
	joy.pressed = false
	Input.parse_input_event(joy)
	Input.flush_buffered_events()
	Input.action_press("sprint")
	check(not controller.capture().sprint_pressed, "Released gamepad cannot sustain a stale action")
	Input.action_release("sprint")
	InputMap.action_erase_events("sprint")
	for binding in original:
		InputMap.action_add_event("sprint", binding)
	Input.action_release("move_forward")
	player.free()
	print("Sprint held controls: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
