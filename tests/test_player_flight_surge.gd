extends SceneTree

class TestInput extends Node:
	var snapshot := PlayerInputSnapshot.new()
	func capture() -> PlayerInputSnapshot: return snapshot
	func is_sprint_requested() -> bool: return snapshot.sprint_pressed
	func reset() -> void:
		snapshot = PlayerInputSnapshot.new()
		(get_parent() as PlayerCharacter).flying_state.cancel_charge()

var failures := 0
var player: PlayerCharacter
var test_input: TestInput

func _initialize() -> void: run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func held(first := false) -> PlayerInputSnapshot:
	var input := PlayerInputSnapshot.new()
	input.flight_pressed = true
	input.toggle_flight_just_pressed = first
	return input

func released() -> PlayerInputSnapshot:
	var input := PlayerInputSnapshot.new()
	input.flight_just_released = true
	return input

func tick(input: PlayerInputSnapshot, delta := 0.1) -> void:
	test_input.snapshot = input
	player._profiled_physics_process(delta)

func airborne() -> void:
	player.flying_state.cancel_charge()
	player.state_machine.transition_to(&"AirborneState")
	player.global_position = Vector3(0, 100, 0)
	player.velocity = Vector3.ZERO
	player.move_and_slide()
	player.state_machine.transition_to(&"FlyingState")
	player.stamina.restore_full()

func run() -> void:
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1600, 1000)
		root.content_scale_size = Vector2i(1600, 1000)
	var save := root.get_node("SaveManager")
	var save_path := OS.get_environment("TEMP").path_join("flight_surge_%d.json" % OS.get_process_id())
	save._save_path = save_path
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(500, 2, 500)
	collider.shape = shape
	floor_body.add_child(collider)
	floor_body.position.y = -1
	world.add_child(floor_body)
	player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process_input(false)
	var real_input := player.input_controller
	test_input = TestInput.new()
	player.add_child(test_input)
	player.input_controller = test_input
	var progression = player.get_node("PlayerPowerController").progression
	progression.apply_save_data({"schema_version": 2, "upgrades": {"flight": 2}})
	check(not player.abilities.is_unlocked(PlayerAbilities.FLIGHT_SURGE), "Surge stays locked at Flight tier two")
	player.global_position.y = 100
	tick(held(true))
	check(player.is_flying, "Without surge, F still toggles immediately")
	progression.add_tokens(1)
	check(progression.purchase("flight"), "Third Flight upgrade can be purchased")
	check(player.abilities.is_unlocked(PlayerAbilities.FLIGHT_SURGE) and progression.is_implemented("flight", 3), "Purchase enables the implemented ability")
	var saved: Dictionary = progression.to_save_data()
	progression.apply_save_data(saved)
	check(player.abilities.is_unlocked(PlayerAbilities.FLIGHT_SURGE), "Surge survives progression round trip")
	# Exercise the actual powers page and gameplay HUD, not just localization data.
	var page := preload("res://scripts/ui-scripts/powers_page.gd").new()
	page.embedded = true
	page.progression = progression
	world.add_child(page)
	page.select_power("flight")
	check(page.upgrade_names[2].text == "Flight Surge" and not page.upgrade_states[2].text.contains("PLANNED"), "Skill UI names the implemented third upgrade")
	if "--capture" in OS.get_cmdline_user_args():
		player.get_node("GameplayHUD").hide()
		page.show()
		page.detail_scroll.set_deferred("scroll_vertical", 480)
		await capture("flight_surge_skill")
		page.hide()
		player.get_node("GameplayHUD").show()
	page.queue_free()
	var hud := player.get_node("GameplayHUD")
	airborne()
	tick(held(true), 0.05)
	check(player.is_flying and player.stamina.is_full(), "Tap press waits without spending stamina")
	tick(released(), 0.01)
	check(not player.is_flying and player.stamina.is_full(), "Tap release toggles flight normally")
	# Ground launch must ignore a tilted camera, including when already in flight mode.
	player.global_position = Vector3(0, 3, 0)
	await physics_frame
	for i in 30: tick(PlayerInputSnapshot.new(), 0.05)
	check(player.is_on_floor(), "Fixture reaches actual floor contact")
	player.spring_arm.rotation.x = -0.65
	var camera_basis := player.camera.global_basis
	tick(held(true), 0.3)
	tick(released(), 0.01)
	check(player.is_flying and player.velocity.normalized().is_equal_approx(Vector3.UP), "Walking-ground charge enters flight with vertical launch")
	check(player.camera.global_basis.is_equal_approx(camera_basis), "Walking-ground launch preserves camera orientation")
	player.state_machine.transition_to(&"AirborneState")
	player.global_position = Vector3(0, 3, 0)
	player.velocity = Vector3.ZERO
	for i in 30: tick(PlayerInputSnapshot.new(), 0.05)
	player.stamina.restore_full()
	player.state_machine.transition_to(&"FlyingState")
	tick(held(true), 0.3)
	check(player.is_charging_flight and hud.get_node("FlightCharge").visible, "Charge activates and shows gameplay meter")
	player.combat_controller.request_punch()
	check(not player.combat_controller.is_action_locked(), "Charging blocks conflicting punches")
	for i in 20: tick(held(), 0.1)
	check(player.stamina.is_full() and player.is_on_floor(), "Full charge waits for release without cost or auto-launch")
	check(hud.flight_charge_bar.value == 100.0, "Charge meter caps at full power")
	if "--capture" in OS.get_cmdline_user_args():
		root.get_node("GameSettings").set_show_control_hints(true, false)
		await capture("flight_surge_charge")
	tick(released(), 0.01)
	check(player.is_flying and player.velocity.normalized().is_equal_approx(Vector3.UP), "Ground surge launches vertically in flight mode")
	check(is_equal_approx(player.velocity.length(), player.flight_surge_max_speed), "Full hold reaches configured maximum speed")
	check(player.stamina.current == 0 and player.stamina.exhausted, "Launch spends the whole bar and exhausts")
	check(player.camera.global_basis.is_equal_approx(camera_basis), "Ground launch never rotates the camera")
	check(not hud.get_node("FlightCharge").visible, "Release clears the charge HUD")
	tick(PlayerInputSnapshot.new(), 0.1)
	check(player.velocity.y > 100, "Launch impulse survives subsequent movement updates")
	# Short charge gives less power; facing is the mesh's full 3D orientation.
	airborne()
	var facing := Vector3(1, -0.4, 0.6).normalized()
	player.superhero_character.global_basis = Basis.looking_at(facing, Vector3.UP, true)
	camera_basis = player.camera.global_basis
	tick(held(true), 0.3)
	tick(released(), 0.01)
	check(player.velocity.normalized().is_equal_approx(facing), "Air launch follows character facing, including downward pitch")
	check(player.velocity.length() >= player.flight_surge_min_speed and player.velocity.length() < player.flight_surge_max_speed, "Shorter hold gives a weaker surge")
	check(player.camera.global_basis.is_equal_approx(camera_basis), "Air launch leaves camera orientation alone")
	# Empty bar returns to ordinary flight and uses the established recovery rules.
	for i in 7: tick(PlayerInputSnapshot.new(), 0.1)
	var movement := PlayerInputSnapshot.new()
	movement.movement = Vector2.UP
	movement.sprint_pressed = true
	for i in 60: tick(movement, 0.1)
	check(player.is_flying and player.stamina.current == 0, "Holding sprint after surge blocks regeneration but allows flight")
	check(is_equal_approx(player.velocity.length(), player._get_walk_speed()), "Exhaustion settles to normal flight speed")
	tick(PlayerInputSnapshot.new(), 1.0)
	check(player.stamina.current == 0, "Normal regeneration delay remains")
	tick(PlayerInputSnapshot.new(), 0.5)
	check(player.stamina.current > 0 and not player.stamina.is_full(), "Normal regeneration resumes after releasing sprint")
	# Eligibility is checked both at the start and release; holding cannot arm later.
	player.stamina.current = player.stamina.maximum * 0.5
	player.stamina.exhausted = false
	tick(held(true), 0.3)
	check(not player.is_charging_flight and hud.flight_charge_label.text.contains("full stamina"), "Partial stamina shows why charge is unavailable")
	player.stamina.restore_full()
	tick(held(), 2.0)
	tick(released(), 0.01)
	check(player.stamina.is_full() and player.flying_state.surge_remaining == 0, "Refilling mid-hold cannot bypass initial eligibility")
	tick(held(true), 0.3)
	player.stamina.current -= 1
	tick(released(), 0.01)
	check(player.flying_state.surge_remaining == 0, "Losing full stamina before release prevents launch")
	# Menus/focus/rebind reset must never turn a cancelled hold into a launch or toggle.
	player.stamina.restore_full()
	tick(held(true), 0.3)
	real_input.reset()
	tick(released())
	check(player.stamina.is_full() and not player.is_charging_flight and player.is_flying, "Input reset cancels without spending or toggling")
	tick(held(true), 0.3)
	tick(PlayerInputSnapshot.new())
	tick(released())
	check(player.stamina.is_full() and player.flying_state.surge_remaining == 0, "Suppressed input cancels safely")
	tick(held(true), 0.3)
	player.state_machine.transition_to(&"KnockedDownState", {"cause": &"damage"})
	tick(released())
	check(player.is_knocked_out and not player.is_charging_flight and player.stamina.is_full(), "Knockdown cancels charge without cost")
	player.input_controller = real_input
	world.free()
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(save_path)
	print("Flight Surge: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)

func capture(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png")
