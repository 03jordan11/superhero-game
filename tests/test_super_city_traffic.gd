extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	seed(811)
	var city = load("res://scenes/super_city.tscn").instantiate()
	# Keep this traffic test independent of the pedestrian system.
	city.get_node("CivilianCrowd").free()
	city.get_node("CityPedestrianRoutes").free()
	var focus := Node3D.new()
	focus.name = "TrafficFocus"
	focus.position = Vector3(-1286,2,-960)
	city.add_child(focus)
	var manager = city.get_node("TrafficManager")
	manager.focus_path = ^"../TrafficFocus"
	manager.population_target = 4
	manager.max_vehicles = 4
	manager.spawn_interval = 0.2
	manager.minimum_spawn_distance = 15.0
	manager.get_node("DistantTraffic").enabled = false # Isolate the full-vehicle fixture.
	manager.prefer_offscreen_spawns = false
	root.add_child(city)
	current_scene = city
	for frame in range(240): await physics_frame
	assert(manager.active_count >= 2 and manager.active_count <= 4,"No local traffic on actual city roads")
	var car: Vehicle = manager._cars[0].car
	var before := car.global_position
	for frame in range(120): await physics_frame
	assert(car.global_position.distance_to(before) > 0.5,"City car did not move")
	for record in manager._cars:
		assert(record.car is Vehicle and record.car.freeze)
		assert(record.progress <= record.stop_at+0.001)
	# Moving the focus must retire old traffic and refill nearby roads.
	focus.position = Vector3(1070,2,600)
	for frame in range(240): await physics_frame
	assert(not is_instance_valid(car))
	assert(manager.active_count > 0 and manager.active_count <= 4)
	manager.traffic_enabled = false
	for frame in range(10): await physics_frame
	assert(manager.active_count == 0)
	city.free()
	print("PASS: SuperCity traffic integration, local spawning, movement, cap, relocation and disable")
	quit()
