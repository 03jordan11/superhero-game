extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func press_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	root.get_node("GameSettings").input_bindings.load_config(ConfigFile.new())
	var player := load("res://scenes/player.tscn").instantiate() as PlayerCharacter
	world.add_child(player)
	player.set_physics_process(false)
	player.input_controller.set_process(false)
	player.spring_arm.rotation.x = 0.0
	var car := load("res://scenes/vehicles/normal_car_1.tscn").instantiate() as Vehicle
	world.add_child(car)
	await physics_frame
	await physics_frame
	car.global_position = player.camera.global_position - player.camera.global_basis.z * 6.0 - car.get_node("CollisionShape3D").position
	await physics_frame
	await physics_frame
	player.abilities.set_unlocked(PlayerAbilities.VEHICLE_LIFT, false)
	check(not player.vehicle_interactor.try_pick_up_vehicle(), "Vehicle Lift remains required")
	player.abilities.set_unlocked(PlayerAbilities.VEHICLE_LIFT, true)
	await process_frame
	player.set_physics_process(true)
	press_key(KEY_E, true)
	var input: PlayerInputSnapshot = player.input_controller.capture()
	check(input.vehicle_interact_pressed and not input.secondary_power_pressed and not input.flight_pressed, "Physical E requests pickup without powers or flight")
	await physics_frame
	await physics_frame
	check(player.vehicle_interactor.held_vehicle == car, "Physical E picks up the vehicle through the normal player physics path")
	press_key(KEY_E, false)
	await process_frame
	await process_frame
	press_key(KEY_E, true)
	await create_timer(0.3).timeout
	press_key(KEY_E, false)
	await physics_frame
	await physics_frame
	player.set_physics_process(false)
	check(not player.vehicle_interactor.has_held_vehicle() and car.linear_velocity.length() > 0, "Hold and release E throws the held car")
	press_key(KEY_Q, true)
	input = player.input_controller.capture()
	check(input.secondary_power_pressed and not input.vehicle_interact_pressed and not input.flight_pressed, "Physical Q triggers only secondary power")
	press_key(KEY_Q, false)
	press_key(KEY_F, true)
	input = player.input_controller.capture()
	check(input.flight_pressed and not input.secondary_power_pressed and not input.vehicle_interact_pressed, "Physical F retains flight")
	press_key(KEY_F, false)
	world.free()
	print("Pickup binding: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
