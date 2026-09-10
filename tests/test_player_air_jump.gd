extends SceneTree
const STEP := 1.0 / 60.0
var failures := 0
var player: PlayerCharacter
var world: Node3D

func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func land() -> void:
	player.set_physics_process(false)
	Input.action_release("jump")
	await process_frame
	await process_frame
	player.global_position = Vector3(0, 2, 0)
	player.velocity = Vector3.ZERO
	player.state_machine.transition_to(&"GroundedState")
	await physics_frame
	for i in 120:
		player._profiled_physics_process(STEP)
		if player.is_on_floor(): break
	check(player.is_on_floor() and not player.air_jump_used, "Actual floor contact replenishes Air Jump")

func fall() -> void:
	player.global_position = Vector3(100, 25, 0)
	player.velocity = Vector3.DOWN
	player.move_and_slide()
	player.state_machine.transition_to(&"AirborneState")
	check(not player.is_on_floor(), "Falling fixture has no floor contact")

func run() -> void:
	var save := root.get_node("SaveManager")
	var path := OS.get_environment("TEMP").path_join("air_jump_%d.json" % OS.get_process_id())
	save._save_path = path
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	collider.shape = box
	floor_body.add_child(collider)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	var progression = player.get_node("PlayerPowerController").progression
	fall()
	var tap := PlayerInputSnapshot.new()
	tap.jump_pressed = true
	tap.jump_just_pressed = true
	player.state_machine.physics_update(STEP, tap)
	check(not player.air_jump_used and player.velocity.y < 0, "Core alone cannot Air Jump")
	progression.add_tokens(2)
	for tier in [1]:
		check(progression.purchase("super_leap"), "Earlier tier remains required")
		check(not player.abilities.is_unlocked(PlayerAbilities.AIR_JUMP), "Earlier tiers do not unlock Air Jump")
	check(progression.purchase("super_leap") and player.abilities.is_unlocked(PlayerAbilities.AIR_JUMP), "Second sequential upgrade enables Air Jump")
	check(progression.is_implemented("super_leap", 2) and not player.abilities.is_unlocked(PlayerAbilities.BOUNDING), "Air Jump is implemented without unlocking Bounding")
	# Independent numerical expectations: half of the upgraded full-launch stats.
	player.velocity = Vector3(4, -120, -6)
	player.landing_impact_controller.max_downward_speed = 120
	player.landing_impact_controller.max_effect_downward_speed = 120
	var state := player.state_machine.active_state as PlayerNormalMovementState
	check(state._try_air_jump(), "A fast fall can use Air Jump without a prior jump")
	check(is_equal_approx(player.velocity.y, 35 * sqrt(2.0) * 0.5), "Air Jump replaces falling velocity with half upgraded full upward launch")
	check(is_equal_approx(player.velocity.x, 4) and is_equal_approx(player.velocity.z, -6 - 30 * sqrt(2.0) * 0.5), "Existing horizontal momentum is retained with half forward boost added")
	check(player.air_jump_used and player.is_jump_active and not player.is_charging_jump and player.jump_charge == 0, "Instant launch has no charging phase")
	check(not player.get_node("PlayerSoundManager/JumpCharge").playing and player.stamina.current == player.stamina.maximum, "Air Jump does not charge audio or use stamina")
	check(player.landing_impact_controller.max_downward_speed == 0 and player.landing_impact_controller.max_effect_downward_speed == 0, "Canceled fall cannot leak into later impact strength")
	var first_velocity := player.velocity
	check(not state._try_air_jump() and player.velocity == first_velocity, "Second attempt cannot add another impulse")
	for i in 4: player.state_machine.physics_update(STEP, tap)
	check(player.velocity.y < first_velocity.y, "Repeated taps cannot replenish the jump")
	check(save.load_game() and player.air_jump_used and player.abilities.is_unlocked(PlayerAbilities.AIR_JUMP), "Loading ownership midair does not replenish usage")
	progression.apply_save_data({"schema_version": 2, "upgrades": {"super_leap": 2, "flight": 0}})
	player.state_machine.transition_to(&"FlyingState")
	player.state_machine.physics_update(STEP, tap)
	check(player.is_flying and player.air_jump_used and player.velocity.length() <= player._get_walk_speed(), "Jump in flight ascends normally")
	player.state_machine.transition_to(&"AirborneState")
	check(not player.state_machine.active_state._try_air_jump(), "Flight cycling cannot restore a consumed Air Jump")
	await land()
	# Use real physics frames so fresh-press input is sampled once per engine tick.
	player.set_physics_process(true)
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	await physics_frame
	await physics_frame
	check(not player.is_on_floor() and not player.air_jump_used and player.velocity.y <= player.min_jump_velocity, "Normal tap jump leaves airborne use available")
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	check(player.air_jump_used and player.velocity.y > player.min_jump_velocity, "A fresh airborne tap launches immediately")
	var launched := player.velocity.y
	for i in 4: await physics_frame
	check(player.velocity.y < launched and player.jump_charge == 0, "Holding Jump cannot repeat or charge the Air Jump")
	Input.action_release("jump")
	await land()
	# A charged first jump also leaves exactly one additional jump.
	player.state_machine.transition_to(&"JumpChargingState", {"initial_charge_delta": player.max_jump_charge_time})
	player.state_machine.active_state._release_jump()
	player.move_and_slide()
	check(not player.air_jump_used and player.velocity.y > 35, "Full charged ground jump leaves the extra jump available")
	player.state_machine.physics_update(STEP, tap)
	check(player.air_jump_used and is_equal_approx(player.velocity.y, 35 * sqrt(2.0) * 0.5), "Air Jump also works while rising from Super Jump")
	await land()
	fall()
	player.state_machine.transition_to(&"FlyingState")
	player.state_machine.physics_update(STEP, tap)
	check(not player.air_jump_used, "Flight ascent does not consume an available Air Jump")
	player.state_machine.transition_to(&"AirborneState")
	# Xbox A uses the configured Jump action.
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	player.set_physics_process(true)
	Input.parse_input_event(button)
	await physics_frame
	await physics_frame
	check(player.air_jump_used and player.velocity.y > 0, "Xbox A can Air Jump after leaving flight")
	button = button.duplicate()
	button.pressed = false
	Input.parse_input_event(button)
	await land()
	fall()
	for forbidden in ["is_dead", "is_knocked_out", "is_ground_slamming", "is_wall_running"]:
		player.set(forbidden, true)
		check(not player.state_machine.active_state._try_air_jump() and not player.air_jump_used, "Air Jump cannot bypass " + forbidden)
		player.set(forbidden, false)
	progression.apply_save_data({})
	check(not player.abilities.is_unlocked(PlayerAbilities.AIR_JUMP) and not player.state_machine.active_state._try_air_jump(), "Resetting ownership removes the ability")
	world.free()
	DirAccess.remove_absolute(path)
	print("Air Jump: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
