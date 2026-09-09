extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("Traffic population test timed out"); quit(1))
	seed(813)
	var city := Node3D.new()
	root.add_child(city)
	current_scene = city
	var focus := CharacterBody3D.new()
	focus.name = "Focus"
	city.add_child(focus)
	focus.position = Vector3(-1280,2,-800)
	var camera := Camera3D.new()
	city.add_child(camera)
	camera.position = focus.position+Vector3.UP*15.0
	camera.look_at(focus.position+Vector3.RIGHT*50.0)
	camera.make_current()
	var manager = load("res://scenes/vehicles/traffic_manager.tscn").instantiate()
	manager.get_node("DistantTraffic").enabled = false # Isolate the full-vehicle fixture.
	manager.focus_path = ^"../Focus"
	manager.population_target = 8
	manager.max_vehicles = 8
	manager.max_vehicles_per_lane = 1
	manager.spawn_interval = 0.1
	city.add_child(manager)
	manager.set_physics_process(false)
	manager._focus = focus
	focus.velocity = Vector3.FORWARD*20.0
	manager._update_spawn_direction()
	assert(manager._spawn_forward.dot(Vector3.FORWARD) > 0.99,"Fast movement did not direct spawning")
	focus.velocity = Vector3.ZERO
	manager._update_spawn_direction()
	assert(manager._spawn_forward.dot(Vector3.RIGHT) > 0.99,"Stationary camera did not direct spawning")
	var seen: Dictionary = {}
	for frame in range(240):
		await physics_frame
		manager._step(1.0/60.0)
		assert(manager.active_count <= 8 and manager.retained_count <= 8)
		for record in manager._cars:
			if seen.has(record.id): continue
			assert(not manager._car_visible(record.car),"New traffic appeared in view")
			var lane_count := 0
			for other in manager._cars:
				if other.lane == record.lane: lane_count += 1
			assert(lane_count == 1,"Spawn lane cap was ignored")
			seen[record.id] = true
	assert(seen.size() >= 3,"Too few offscreen spawns")
	# Isolate one car to test distance hysteresis without replacement spawns.
	manager._timer = 1000000.0
	var car: Vehicle = manager._cars[0].car
	for record in manager._cars:
		if record.car != car: record.car.free()
	manager.population_target = 1
	manager._step(0.0)
	manager.spawn_radius = 50.0
	manager.despawn_radius = 100.0
	focus.position = car.position+Vector3(0,2,140)
	camera.position = focus.position+Vector3.UP*15.0
	camera.look_at(car.global_position+Vector3.UP)
	await physics_frame
	await physics_frame
	assert(manager._car_visible(car))
	manager._step(1.0)
	assert(manager.active_count == 1,"Despawn ignored the delay")
	manager._step(1.1)
	assert(manager.active_count == 1,"A visible nearby car popped away beyond the normal radius")
	camera.look_at(camera.global_position+Vector3.BACK*50.0)
	await physics_frame
	await physics_frame
	assert(not manager._car_visible(car))
	manager._step(0.1)
	assert(manager.active_count == 0,"Offscreen distant car was not retired")
	await process_frame
	city.free()
	print("PASS: camera/travel preference, offscreen spawning, lane/population caps, delayed retirement and visibility hysteresis")
	quit()
