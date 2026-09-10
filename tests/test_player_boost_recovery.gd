extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func toggle_sprint() -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_LEFT_STICK
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)

func run() -> void:
	var settings := root.get_node("GameSettings")
	settings.set_accessibility(false, false, false)
	var player: PlayerCharacter = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.global_position.y = 5000
	player.stats.speed = 100
	player.sprint_acceleration = 1000
	player.flight_acceleration = 1000
	var controller := player.get_node("PlayerPowerController")
	controller.progression.apply_save_data({"schema_version": 2, "upgrades": {"super_speed": 0, "flight": 1}})
	var stamina := player.stamina
	for flying in [false, true]:
		player.state_machine.transition_to(&"FlyingState" if flying else &"AirborneState")
		Input.action_press("move_forward")
		Input.action_press("sprint")
		for i in 50: player._profiled_physics_process(0.1)
		check(stamina.current == 0 and stamina.exhausted, "Boost exhausts shared stamina")
		player._profiled_physics_process(0.1)
		check(player.velocity.length() > player._get_walk_speed() and stamina.current == 0, "No recharge while coasting fast with sprint held")
		for i in 30: player._profiled_physics_process(0.1)
		check(stamina.current == 0, "Continuing to hold cannot cycle back into boost")
		Input.action_release("move_forward")
		for i in 20: player._profiled_physics_process(0.1)
		check(stamina.current == 0, "Sprint intent blocks recovery without movement input")
		Input.action_release("sprint")
		player._profiled_physics_process(1.0)
		check(stamina.current == 0, "One-second delay begins when sprint is released")
		player._profiled_physics_process(1.0)
		check(stamina.current == 20 and stamina.can_boost(), "Release permits recovery to the exhaustion threshold")
		player._profiled_physics_process(4.0)
		check(stamina.current == 100, "Recovery fills normally while sprint is off")
	# Toggle mode uses the same rule, including Xbox's bindable L3 action.
	settings.set_accessibility(true, false, false)
	toggle_sprint()
	check(player.input_controller.sprint_toggled, "Xbox L3 enables toggle sprint")
	Input.action_press("move_forward")
	for i in 50: player._profiled_physics_process(0.1)
	Input.action_release("move_forward")
	player._profiled_physics_process(5.0)
	check(stamina.current == 0 and player.input_controller.sprint_toggled, "Latched sprint blocks regeneration after exhaustion")
	toggle_sprint()
	player._profiled_physics_process(2.0)
	check(stamina.current == 20, "Toggling sprint off allows recharge")
	player.free()
	print("Boost recovery: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
