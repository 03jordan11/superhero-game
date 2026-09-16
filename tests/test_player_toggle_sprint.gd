extends SceneTree
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func press_sprint(echo := false) -> void:
	var event: InputEventKey = InputMap.action_get_events("sprint")[0].duplicate()
	event.pressed = true
	event.echo = echo
	root.push_input(event)

func run() -> void:
	var settings := root.get_node("GameSettings")
	var debug := root.get_node("DebugManager")
	settings.set_accessibility(false, false, false)
	var player: PlayerCharacter = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	preload("res://tests/player_test_support.gd").unlock_current_powers(player)
	player.set_physics_process(false)
	var controller := player.input_controller
	preload("res://tests/player_test_support.gd").set_sprint_held(true)
	check(controller.capture().sprint_pressed, "Hold mode follows held input")
	preload("res://tests/player_test_support.gd").set_sprint_held(false)
	check(not controller.capture().sprint_pressed, "Hold mode stops on release")
	settings.set_accessibility(true, false, false)
	press_sprint()
	check(controller.capture().sprint_pressed, "One real input event latches sprint")
	press_sprint(true)
	check(controller.capture().sprint_pressed, "Key repeat does not toggle off")
	var input: PlayerInputSnapshot = controller.capture()
	input.movement = Vector2.UP
	input.move_forward_pressed = true
	player.current_ground_speed = player._get_walk_speed()
	player.state_machine.physics_update(0.25, input)
	check(player.current_ground_speed > player._get_walk_speed(), "Toggle snapshot accelerates actual ground movement")
	check(player.state_machine.transition_to(&"FlyingState"), "Can enter flight fixture")
	player.state_machine.physics_update(0.25, input)
	check(player.current_flight_speed > player._get_walk_speed(), "Toggle also drives flight boost")
	press_sprint()
	check(not controller.capture().sprint_pressed, "Second press switches sprint off")
	press_sprint()
	paused = true
	check(not controller.sprint_toggled, "Pause immediately clears latch")
	paused = false
	check(not controller.capture().sprint_pressed, "Resume does not restart boost")
	press_sprint()
	controller.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not controller.sprint_toggled, "Focus loss clears latch")
	press_sprint()
	debug.developer_menu_open = true
	check(not controller.capture().sprint_pressed, "Developer menu cancels boost")
	press_sprint()
	check(not controller.sprint_toggled, "Developer-menu input cannot latch boost")
	debug.developer_menu_open = false
	press_sprint()
	player.is_knocked_out = true
	check(not controller.capture().sprint_pressed, "Knockdown clears boost")
	player.is_knocked_out = false
	press_sprint()
	settings.set_accessibility(false, false, false)
	check(not controller.sprint_toggled, "Changing hold/toggle mode resets latch")
	# Accessibility uses the action, not a hard-coded Shift key.
	var bindings := InputMap.action_get_events("sprint")
	InputMap.action_erase_events("sprint")
	var rebound := InputEventKey.new()
	rebound.keycode = KEY_K
	InputMap.action_add_event("sprint", rebound)
	settings.set_accessibility(true, false, false)
	press_sprint()
	check(controller.capture().sprint_pressed, "Toggle follows rebound sprint action")
	InputMap.action_erase_events("sprint")
	for binding in bindings: InputMap.action_add_event("sprint", binding)
	player._die()
	check(player.is_dead and not controller.sprint_toggled, "Death event cancels boost")
	press_sprint()
	check(not controller.capture().sprint_pressed, "Dead player cannot re-enable boost")
	player.free()
	settings.set_accessibility(false, false, false)
	print("Toggle sprint: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
