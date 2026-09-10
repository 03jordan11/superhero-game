extends SceneTree

const STEP := 1.0 / 60.0
var failures := 0
var player: PlayerCharacter
var bounding: PlayerBoundingController
var world: Node3D

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func speed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()

func tick() -> void:
	await physics_frame
	player._profiled_physics_process(STEP)

func release_jump() -> void:
	Input.action_release("jump")
	await process_frame
	await process_frame

func tap() -> void:
	Input.action_press("jump")
	await tick()
	await release_jump()

func fall(horizontal: float = 40.0, downward: float = 20.0, height: float = 5.0) -> void:
	await physics_frame
	bounding.reset()
	player.global_position = Vector3(0, height, 0)
	player.velocity = Vector3(0, -downward, -horizontal)
	player.move_and_slide()
	player.state_machine.transition_to(&"AirborneState")
	player.is_jump_active = false
	player.is_charging_jump = false
	player.air_jump_used = false
	check(not player.is_on_floor(), "Fall fixture is airborne")

func land() -> void:
	for i in 600:
		await tick()
		if player.is_on_floor(): break
	check(player.is_on_floor(), "Player reaches actual floor contact")

func run() -> void:
	var save := root.get_node("SaveManager")
	var save_path := OS.get_environment("TEMP").path_join("bounding_%d.json" % OS.get_process_id())
	save._save_path = save_path
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5000, 1, 5000)
	collider.shape = box
	floor_body.add_child(collider)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	bounding = player.bounding_controller
	await physics_frame
	var progression = player.get_node("PlayerPowerController").progression
	progression.add_tokens(3)
	progression.purchase("super_leap")
	progression.purchase("super_leap")
	check(player.abilities.is_unlocked(PlayerAbilities.AIR_JUMP) and not player.abilities.is_unlocked(PlayerAbilities.BOUNDING), "Tier 2 unlocks Air Jump only")
	await fall()
	await land()
	check(bounding.window_remaining == 0.0, "Tier 2 cannot open a Bounding window")
	progression.purchase("super_leap")
	check(player.abilities.is_unlocked(PlayerAbilities.BOUNDING), "Tier 3 enables Bounding")
	check(progression.is_implemented("super_leap", 2) and progression.is_implemented("super_leap", 3), "Both reordered upgrades are implemented")
	check(not bounding.qualifies(Vector3(15, -30, 0)), "Low horizontal speed fails")
	check(not bounding.qualifies(Vector3(50, -11, 0)), "Low downward force fails")
	check(bounding.qualifies(Vector3(16, -12, 0)), "Both thresholds qualify at the boundary")

	await fall()
	await land()
	check(bounding.window_remaining > 0.24, "Qualifying landing opens the 0.25 second window")
	for i in 10: await tick()
	var incoming := speed()
	await tap()
	check(not player.is_on_floor() and player.velocity.y > 49.0, "A tap inside the window gives full upgraded jump height")
	check(is_equal_approx(speed(), incoming * 0.9), "Bound retains 90 percent of momentum without adding a forward boost")
	check(not player.air_jump_used and player.jump_charge == 0, "Bound neither consumes Air Jump nor charges")
	check(player.stamina.current == player.stamina.maximum, "Bounding has no stamina cost")

	# Real ballistic cycles must conserve enough speed for several hops, then stop.
	var count := 1
	var previous := speed()
	while count < 20:
		await land()
		if bounding.window_remaining <= 0.0: break
		await tap()
		check(speed() < previous, "Each unboosted cycle loses momentum")
		previous = speed()
		count += 1
	check(count >= 3 and count < 20 and speed() < bounding.minimum_horizontal_speed, "Chain lasts multiple bounds and naturally ends below the speed threshold")
	# A real fully charged jump retains enough momentum to enter the same chain.
	player.state_machine.transition_to(&"JumpChargingState")
	player.jump_charge = player.max_jump_charge_time
	player.state_machine.active_state._release_jump()
	await tick()
	check(not player.is_on_floor(), "Fully charged jump leaves the floor")
	await land()
	check(bounding.window_remaining > 0.0, "Super Jump qualifies through actual landing speeds")
	await tap()
	check(player.velocity.y > 49, "Super Jump can chain into a bound")

	await fall()
	await land()
	for i in 17: await tick()
	check(bounding.window_remaining == 0.0, "Late input cannot use an expired landing window")
	Input.action_press("jump")
	await tick()
	check(player.is_on_floor() and player.velocity.y <= 0.0, "Late press retains ordinary ground jump controls")
	await release_jump()
	await tick()
	check(player.velocity.y <= player.min_jump_velocity, "Late release is an ordinary quick jump")

	# Close to the floor, a fresh tap buffers Bounding instead of spending Air Jump.
	await fall(40, 20, 2.5)
	await tap()
	check(bounding.buffer_remaining > 0.0 and not player.air_jump_used and player.velocity.y < 0, "Early tap near the floor reserves Bounding without Air Jump")
	for i in 12:
		if player.is_on_floor():
			# A tap accepted at contact survives expiration on the launch tick.
			bounding.buffer_remaining = STEP * 0.5
		await tick()
		if bounding.launched_this_tick: break
	check(bounding.launched_this_tick and player.velocity.y > 49 and not player.air_jump_used, "Released buffered tap launches after real landing")
	await tap()
	check(player.air_jump_used, "A new tap can Air Jump after a released buffered bound")

	await fall(40, 20, 40)
	await tap()
	check(player.air_jump_used and bounding.buffer_remaining == 0 and player.velocity.y > 0, "Far above the ground Air Jump remains immediate")
	await fall(40, 20, 2.5)
	await tap()
	player.global_position.y = 40
	for i in 9: await tick()
	check(bounding.buffer_remaining == 0 and not player.air_jump_used, "An early tap expires if the predicted landing does not happen")
	await fall()
	await land()
	Input.action_press("jump")
	await tick()
	for i in 330: await tick()
	check(player.is_on_floor() and not player.is_charging_jump and player.jump_charge == 0, "Holding the bound button cannot automatically bounce or charge on the next landing")
	await release_jump()
	await tick()
	check(player.is_on_floor(), "Releasing a held bound does not create an extra ground jump")

	# Contact must not restore speed removed by another collision.
	await fall()
	await land()
	player.velocity = Vector3.ZERO
	await tap()
	check(player.is_on_floor(), "Losing horizontal momentum before the tap cancels Bounding")

	# Actual Dive Bomb transition/impact stays excluded even after its state exits.
	progression.apply_save_data({"schema_version": 2, "upgrades": {"super_leap": 3, "flight": 2}})
	await fall(40, 20, 25)
	player.is_jump_active = true
	check(player.state_machine.transition_to(&"GroundSlamState", {"target_position": Vector3(0, 0, -30)}), "Dive Bomb fixture enters")
	await land()
	check(bounding.window_remaining == 0 and bounding.buffer_remaining == 0, "Dive Bomb landing cannot bound")
	for flag in ["is_flying", "is_knocked_out", "is_dead", "is_wall_running", "ground_slam_impact_pending"]:
		bounding.window_remaining = 0.2
		bounding.buffer_remaining = 0.1
		player.set(flag, true)
		bounding.begin_tick(STEP)
		check(bounding.window_remaining == 0 and bounding.buffer_remaining == 0, "Interrupted timing resets for " + flag)
		player.set(flag, false)

	await fall()
	await land()
	check(save.load_game() and bounding.window_remaining == 0, "Loading clears transient landing input")
	await fall()
	await land()
	paused = true
	check(bounding.window_remaining == 0, "Opening a paused menu clears pending Bounding input")
	paused = false

	# Xbox A reaches Bounding through the existing bindable Jump action.
	await fall()
	await land()
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	Input.parse_input_event(pad)
	Input.flush_buffered_events()
	await tick()
	check(player.velocity.y > 49 and not player.is_on_floor(), "Xbox A triggers Bounding")
	pad = pad.duplicate()
	pad.pressed = false
	Input.parse_input_event(pad)
	await release_jump()
	var bindings: Node = root.get_node("GameSettings").input_bindings
	var rebound := InputEventKey.new()
	rebound.physical_keycode = KEY_K
	rebound.pressed = true
	bindings.rebind("jump", "keyboard", rebound)
	await fall()
	await land()
	Input.parse_input_event(rebound)
	Input.flush_buffered_events()
	await tick()
	check(player.velocity.y > 49 and not player.is_on_floor(), "Rebound keyboard Jump triggers Bounding")
	rebound = rebound.duplicate()
	rebound.pressed = false
	Input.parse_input_event(rebound)
	await release_jump()
	bindings.load_config(ConfigFile.new())
	world.free()
	DirAccess.remove_absolute(save_path)
	print("Bounding: %s (%d chained bounds)" % ["PASS" if failures == 0 else "FAIL", count])
	quit(0 if failures == 0 else 1)
