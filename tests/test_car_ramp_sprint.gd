extends SceneTree

const STEP := 1.0 / 60.0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func speed(player: PlayerCharacter) -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()

func run() -> void:
	root.get_node("GameSettings").set_accessibility(false, false, false)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10000, 1, 10000)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var car := load("res://scenes/vehicles/normal_car_2.tscn").instantiate() as Vehicle
	world.add_child(car)
	for attribute in [5, 20, 50]:
		var player := load("res://scenes/player.tscn").instantiate() as PlayerCharacter
		player.position = Vector3(0, 1.1, 15)
		world.add_child(player)
		player.set_physics_process(false)
		player.stats.speed = attribute
		player.stats.resilience = 100
		player.stamina.restore_full()
		for ability in [PlayerAbilities.SUPER_SPEED, PlayerAbilities.WALL_RUN, PlayerAbilities.BOUNDING]:
			player.abilities.set_unlocked(ability, true)
		await physics_frame
		await physics_frame
		for tick in 30:
			player._profiled_physics_process(STEP)
		# Start at attained sprint speed so each run tests collision/landing,
		# rather than spending time accelerating over a huge test runway.
		player.current_ground_speed = player.stats.get_run_speed(player.minimum_run_speed, player.run_speed_per_attribute_point)
		player.velocity.z = -player.current_ground_speed
		Input.action_press("move_forward")
		preload("res://tests/player_test_support.gd").set_sprint_held(true)
		var released := false
		var landed := false
		var grounded_ticks := 0
		var stamina_on_release := 0.0
		for tick in 1500:
			player._profiled_physics_process(STEP)
			if not released and not player.is_on_floor() and player.position.y > 1.3:
				preload("res://tests/player_test_support.gd").set_sprint_held(false)
				# Model the engine retaining the sprint action after physical release.
				Input.action_press("sprint")
				released = true
				stamina_on_release = player.stamina.current
				print("Ramp release speed=", attribute, " state=", player.state_machine.get_active_state_id(), " horizontal=", speed(player), " target=", player.current_ground_speed)
			elif released:
				check(not player.input_controller.capture().sprint_pressed, "Shift remains released while W is held")
				check(player.stamina.current >= stamina_on_release, "No sprint stamina drain after release")
				if player.is_on_floor():
					if not landed:
						print("Ramp landing speed=", attribute, " horizontal=", speed(player), " target=", player.current_ground_speed)
					landed = true
					grounded_ticks += 1
					if grounded_ticks == 480:
						print("After landing 8s speed=", attribute, " horizontal=", speed(player), " target=", player.current_ground_speed)
						check(speed(player) <= player._get_walk_speed() + 0.1, "Landing with W and no Shift settles to ordinary speed without a second Shift tap")
						break
		check(released and landed, "Running into real car produces an airborne release and landing")
		Input.action_release("move_forward")
		preload("res://tests/player_test_support.gd").set_sprint_held(false)
		player.free()
	world.free()
	print("Car ramp sprint: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
