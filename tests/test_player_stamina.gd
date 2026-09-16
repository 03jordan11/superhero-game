extends SceneTree
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func tick(stamina: PlayerStamina, seconds: float, boosting: bool, flying := false, moving := true) -> void:
	stamina.begin_tick(boosting)
	if boosting: stamina.request_boost(flying)
	stamina.finish_tick(seconds, Vector3.FORWARD if moving else Vector3.ZERO, true)

func run() -> void:
	var settings := root.get_node("GameSettings")
	settings.set_accessibility(false, false, false)
	var player: PlayerCharacter = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var stamina := player.stamina
	var hud = player.get_node("GameplayHUD")
	check(stamina.current == 100 and stamina.maximum == 100, "Starting Resilience provides 100 stamina")
	tick(stamina, 1.0, true, false, false)
	check(stamina.current == 100, "Stationary or fully blocked boosts cost nothing")
	tick(stamina, 1.0, true)
	check(stamina.current == 80 and hud.stamina_bar.value == 80, "Running consumes 20 per second and updates HUD")
	tick(stamina, 0.5, false)
	check(stamina.current == 80, "Regeneration waits for delay")
	tick(stamina, 1.0, false)
	check(stamina.current == 90, "Only time after the delay contributes to recovery")
	tick(stamina, 1.0, false)
	check(stamina.current == 100, "Regeneration clamps to capacity")
	tick(stamina, 5.0, true, true)
	check(stamina.current == 0 and stamina.exhausted and not stamina.can_boost(), "Five seconds of flight boost exhausts the pool")
	check(hud.stamina_label.text.begins_with("Exhausted"), "HUD distinguishes exhaustion")
	tick(stamina, 1.5, true, true)
	check(stamina.current == 0 and not stamina.can_boost(), "Held boost cannot recover from exhaustion")
	tick(stamina, 10.0, true, true, false)
	check(stamina.current == 0, "Standing still with boost held cannot recover")
	tick(stamina, 1.5, false)
	check(stamina.current == 10 and not stamina.can_boost(), "Release starts recovery delay and keeps boost locked below threshold")
	tick(stamina, 0.5, false)
	check(stamina.current == 20 and stamina.can_boost(), "Boost unlocks at twenty percent")
	tick(stamina, 4.0, false)
	var controller := player.get_node("PlayerPowerController")
	controller.progression.apply_save_data({"schema_version": 2, "upgrades": {"super_speed": 1, "flight": 1}})
	check(stamina.running_drain_multiplier == 0.5, "Endurance is active on purchased tier load")
	tick(stamina, 1.0, true)
	check(stamina.current == 90, "Endurance halves running drain")
	tick(stamina, 1.0, true, true)
	check(stamina.current == 70, "Endurance leaves flight drain unchanged")
	player.stats.resilience = 11
	check(stamina.maximum == 110 and stamina.current == 70, "Capacity grows without instantly refilling spent stamina")
	player.stats.resilience = 1
	check(stamina.maximum == 10 and stamina.current == 10, "Capacity decrease clamps current stamina")
	player.stats.resilience = 10
	tick(stamina, 10.0, false)
	settings.always_show_stamina = false
	hud._refresh_status_visibility()
	check(not hud.get_node("Stamina").visible, "Contextual full stamina is hidden")
	tick(stamina, 1.0, true)
	check(hud.get_node("Stamina").visible, "Contextual stamina appears during use")
	settings.always_show_stamina = true
	tick(stamina, 10.0, false)
	check(hud.get_node("Stamina").visible, "Always-show preference keeps full stamina visible")

	# Real movement states use the gate while ordinary movement stays independent of Speed.
	player.global_position.y = 100.0
	var input := PlayerInputSnapshot.new()
	input.movement = Vector2.UP
	player.stats.speed = 50
	player.velocity = Vector3.ZERO
	player.current_ground_speed = player._get_walk_speed()
	player.state_machine.physics_update(1.0, input)
	check(player._get_walk_speed() == 10 and Vector2(player.velocity.x, player.velocity.z).length() == 10, "High Speed leaves ordinary movement unchanged")
	check(player.state_machine.transition_to(&"FlyingState"), "Flight unlocked for movement checks")
	player.state_machine.physics_update(1.0, input)
	check(player.velocity.length() == 10, "High Speed leaves normal flight unchanged")
	input.sprint_pressed = true
	stamina.begin_tick()
	player.state_machine.physics_update(0.1, input)
	check(player.current_flight_speed > 10, "Speed still improves boosted flight")
	stamina.finish_tick(5.0, Vector3.FORWARD, false)
	player.state_machine.physics_update(2.0, input)
	check(player.is_flying and player.current_flight_speed == 10, "Exhaustion returns to normal flight without dropping player")
	player.state_machine.transition_to(&"AirborneState")
	player.current_ground_speed = 10
	player.state_machine.physics_update(1.0, input)
	check(player.current_ground_speed == 10, "Exhaustion blocks boosted running too")
	# Run the actual player loop, including input capture, movement and stamina accounting.
	tick(stamina, 10.0, false)
	player.state_machine.transition_to(&"FlyingState")
	Input.action_press("move_forward")
	preload("res://tests/player_test_support.gd").set_sprint_held(true)
	player._profiled_physics_process(0.25)
	check(stamina.current == 95, "Real physics loop drains stamina during flight movement")
	preload("res://tests/player_test_support.gd").set_sprint_held(false)
	player._profiled_physics_process(1.5)
	check(stamina.current == 100, "Normal flight regenerates stamina after delay")
	Input.action_release("move_forward")
	tick(stamina, 1.0, true)
	var before_pause := stamina.current
	paused = true
	player.set_physics_process(true)
	await physics_frame
	await physics_frame
	check(stamina.current == before_pause, "Paused player physics cannot recover stamina")
	player.set_physics_process(false)
	paused = false
	var before_death := stamina.current
	player._die()
	tick(stamina, 10.0, false)
	check(stamina.current == before_death, "Death stops stamina recovery")
	player.free()
	print("Player stamina: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
