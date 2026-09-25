extends SceneTree
var failures := 0

func _initialize() -> void:
	create_timer(120).timeout.connect(func(): push_error("Gym travel timed out"); quit(1))
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func aim(player: PlayerCharacter, door: Node3D) -> void:
	player.global_position = door.to_global(Vector3(0, -.35, 1.8))
	player.global_rotation.y = door.global_rotation.y
	player.ground_facing_yaw = player.global_rotation.y
	player.velocity = Vector3.ZERO
	player.spring_arm.rotation = Vector3.ZERO
	player.camera.look_at(door.global_position)
	player.reset_physics_interpolation()

func press_e() -> void:
	Input.action_press("pick_up_vehicle")
	for tick in 3: await physics_frame
	await process_frame
	Input.action_release("pick_up_vehicle")
	while root.get_node("LoadingScreen").active: await process_frame

func run() -> void:
	var city := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(city)
	current_scene = city
	var weather := root.get_node("Weather")
	weather.set_weather(&"thunderstorm")
	weather.thunderstorm_cooldown_remaining = 300.0
	weather.lightning_strike_cooldown_remaining = 60.0
	weather.external_combustion_cooldown_remaining = 300.0
	weather.storm_amount = 1.0
	var player := city.get_node("Player") as PlayerCharacter
	var identity := player.get_instance_id()
	var money := player.stats.money
	var speed := player.minimum_run_speed
	var run_attribute := player.run_speed_per_attribute_point
	var walk := player.walk_speed_ratio
	var spring := player.spring_arm.spring_length
	for cycle in 2:
		var exterior := city.get_node("SuperCity/BoxingGymExterior") as Node3D
		var door := exterior.get_node("GymEntrance") as Node3D
		check(not door.new_game_destination,"Gym must never become the New Game hideout")
		var expected_return: Transform3D = exterior.get_node("FrontReturn").global_transform
		aim(player,door)
		for tick in 3: await physics_frame
		player.camera.look_at(door.global_position)
		check(door.can_interact(player),"Placed and rotated gym can be entered while looking at door")
		player.is_dead = true
		check(not door.can_interact(player),"Dead player cannot enter")
		player.is_dead = false
		var blocker := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(4,4,.3)
		shape.shape = box
		blocker.add_child(shape)
		city.add_child(blocker)
		blocker.global_transform = Transform3D(door.global_basis,door.to_global(Vector3(0,0,.75)))
		await physics_frame
		await physics_frame
		player.camera.look_at(door.global_position)
		check(not door.can_interact(player),"Obstruction blocks door interaction")
		blocker.free()
		await physics_frame
		await physics_frame
		player.camera.look_at(door.global_position)
		player.camera.rotate_y(PI)
		check(not door.can_interact(player),"Looking away prevents entry")
		await press_e()
		check(current_scene == city,"E looking away does not load the gym")
		player.camera.look_at(door.global_position)
		player.global_position = door.to_global(Vector3(0,0,-1))
		check(not door.can_interact(player),"Cannot enter from behind wall")
		aim(player,door)
		var city_clock := get_first_node_in_group(&"game_clock")
		city_clock.set_time(19.5)
		city_clock.cycle_running = false
		await press_e()
		check(current_scene.name == &"BoxingGym","E loads gym interior")
		if current_scene.name != &"BoxingGym": quit(1); return
		check(not is_instance_valid(city),"City unloaded on entry")
		for tick in 2: await physics_frame
		check(weather.is_thunderstorm() and current_scene.is_in_group(&"weather_indoors"), "Storm persists into tagged interior")
		check(weather.thunderstorm_cooldown_remaining > 0.0 and weather.thunderstorm_cooldown_remaining < 300.0, "Summon cooldown continues across interior entry")
		check(weather.lightning_strike_cooldown_remaining > 0.0 and weather.lightning_strike_cooldown_remaining < 60.0, "Lightning cooldown continues across interior entry")
		check(weather.sheltered and not weather._rain.visible and weather._rain_audio.playing, "Gym has audible indoor weather without rain particles")
		check(get_nodes_in_group(&"player").size() == 1,"No duplicate player")
		check(current_scene.get_node("Player").get_instance_id() == identity,"Original player retained")
		check(player.stats.money == money,"Progress retained")
		check(player.global_position.distance_to(current_scene.get_node("PlayerSpawn").global_position)<.2,"Arrives at interior entrance")
		check(is_equal_approx(player.spring_arm.spring_length,1.5),"Shoulder camera indoors")
		check(is_equal_approx(player.minimum_run_speed,6.0),"Gym movement configured on transferred player")
		var clock := current_scene.get_node("Clock")
		check(is_equal_approx(clock.time_of_day,19.5),"City clock preserved indoors")
		clock.advance_hours(1)
		var travel := get_first_node_in_group(&"hideout_travel")
		while Time.get_ticks_msec() < travel._cooldown_until + 50: await process_frame
		var room := current_scene
		var exit_door := room.get_node("ExitDoor") as Node3D
		aim(player,exit_door)
		for tick in 3: await physics_frame
		player.camera.look_at(exit_door.global_position)
		check(exit_door.can_interact(player),"Front exit works when looking at door")
		await press_e()
		check(current_scene.name == &"Main","E exits to city")
		if current_scene.name != &"Main": quit(1); return
		city = current_scene
		for tick in 2: await physics_frame
		check(weather.is_thunderstorm() and weather.storm_amount == 1.0, "Same storm returns after real city reload")
		check(weather.thunderstorm_cooldown_remaining > 0.0, "Summon cooldown survives real city reload")
		check(weather.lightning_strike_cooldown_remaining > 0.0, "Lightning cooldown survives real city reload")
		check(weather.external_combustion_cooldown_remaining > 0.0 and weather.external_combustion_cooldown_remaining < 300.0, "Combustion cooldown survives real city reload")
		check(not is_instance_valid(room),"Gym unloaded on exit")
		check(player.get_instance_id() == identity and get_nodes_in_group(&"player").size()==1,"Single same player returned")
		check(player.global_position.distance_to(expected_return.origin)<.5,"Return follows placed building transform")
		check(is_equal_approx(player.spring_arm.spring_length,spring),"Outdoor camera restored")
		check(is_equal_approx(player.minimum_run_speed,speed) and is_equal_approx(player.run_speed_per_attribute_point,run_attribute) and is_equal_approx(player.walk_speed_ratio,walk),"Outdoor movement restored")
		check(is_equal_approx(get_first_node_in_group(&"game_clock").time_of_day,20.5),"Indoor time follows player back outside")
		while Time.get_ticks_msec() < travel._cooldown_until + 50: await process_frame
	print("GYM_TRAVEL_TEST cycles=2 failures=",failures)
	weather.set_weather(&"clear")
	quit(1 if failures else 0)
