extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(90.0).timeout.connect(func(): push_error("Intersection test timed out"); quit(1))
	seed(812)
	var city = load("res://scenes/super_city.tscn").instantiate()
	city.get_node("CivilianCrowd").free()
	city.get_node("CityPedestrianRoutes").free()
	var focus := Node3D.new()
	focus.name = "TrafficFocus"
	city.add_child(focus)
	var manager = city.get_node("TrafficManager")
	manager.focus_path = ^"../TrafficFocus"
	manager.get_node("DistantTraffic").enabled = false # Isolate the full-vehicle fixture.
	manager.prefer_offscreen_spawns = false
	manager.intersection_pause = 0.8 # Keep this timing fixture independent of Inspector tuning.
	manager.despawn_radius = 1000.0
	root.add_child(city)
	current_scene = city
	manager.set_physics_process(false)
	manager._timer = 1000000.0
	var source := -1
	var disconnected := 0
	for i in range(manager.lanes.size()):
		if manager.lanes[i].connections.is_empty(): disconnected += 1
		if source < 0 and manager.lanes[i].connections.size() == 3: source = i
	assert(source >= 0,"No generated four-way junction")
	print("Generated junction connectivity: ",manager.lanes.size()-disconnected," connected lanes, ",disconnected," terminal lanes")
	var lane: Dictionary = manager.lanes[source]
	focus.position = lane.end
	await physics_frame
	await physics_frame
	for connection in lane.connections:
		var car: Vehicle = manager._spawn_vehicle(manager.vehicle_entries[0],source,lane.length-12.0)
		assert(car != null)
		var record: Dictionary = manager._cars[-1]
		var chosen_gap: float = record.following_gap
		var chosen_speed: float = record.intersection_speed
		assert(chosen_speed >= manager.minimum_intersection_speed and chosen_speed <= manager.maximum_intersection_speed)
		record.chosen_exit = connection
		record.arrival = manager._next_arrival
		manager._next_arrival += 1
		var start_crossings: int = manager.crossings_completed
		var previous := car.global_position
		var paused := 0
		for frame in range(1500):
			await physics_frame
			manager._step(1.0/60.0)
			assert(car.global_position.distance_to(previous) < 0.3,"Junction transition teleported car")
			previous = car.global_position
			if record.wait_time > 0.0 and record.connection.is_empty(): paused += 1
			if not record.connection.is_empty():
				assert(manager._junction_owners.size() == 1)
				assert(record.speed <= minf(record.cruise,chosen_speed)+0.001,"Junction speed exceeded this car's limit")
			assert(record.following_gap == chosen_gap and record.intersection_speed == chosen_speed,"Driving variation was rerolled")
			if manager.crossings_completed > start_crossings: break
		assert(paused >= 30,"Car did not pause before entering")
		assert(manager.crossings_completed == start_crossings+1,"Car failed to leave intersection")
		assert(record.lane == connection.to and record.connection.is_empty())
		assert(manager._junction_owners.is_empty(),"Intersection reservation was not released")
		assert(record.progress >= record.half_length+manager.junction_stop_margin-0.01)
		var before := car.global_position
		for frame in range(60):
			await physics_frame
			manager._step(1.0/60.0)
		assert(car.global_position.distance_to(before) > 1.0)
		print("PASS: intersection exit ",connection.to," straight=",connection.straight)
		car.free()
		manager._step(1.0/60.0)
	# Two arrivals at the same junction must not acquire it together.
	var second_source := -1
	for i in range(manager.lanes.size()):
		if i != source and manager.lanes[i].junction == lane.junction:
			second_source = i
			break
	assert(second_source >= 0)
	var first: Vehicle = manager._spawn_vehicle(manager.vehicle_entries[0],source,lane.length-8.0)
	var second: Vehicle = manager._spawn_vehicle(manager.vehicle_entries[0],second_source,manager.lanes[second_source].length-8.0)
	assert(first != null and second != null)
	var first_record: Dictionary = manager._cars[0]
	var second_record: Dictionary = manager._cars[1]
	first_record.arrival = manager._next_arrival
	manager._next_arrival += 1
	first_record.chosen_exit = lane.connections[0]
	var exit_lane: Dictionary = manager.lanes[first_record.chosen_exit.to]
	var obstruction := StaticBody3D.new()
	var obstruction_shape := CollisionShape3D.new()
	var obstruction_box := BoxShape3D.new()
	obstruction_box.size = Vector3(6,3,6)
	obstruction_shape.shape = obstruction_box
	obstruction.add_child(obstruction_shape)
	city.add_child(obstruction)
	obstruction.position = exit_lane.start+exit_lane.forward*(first_record.half_length+manager.junction_stop_margin)+Vector3.UP
	await physics_frame
	await physics_frame
	manager._wait_at_junction(first_record,2.0)
	assert(first_record.connection.is_empty() and manager._junction_owners.is_empty(),"Car entered despite a blocked exit")
	obstruction.free()
	await physics_frame
	await physics_frame
	manager._wait_at_junction(first_record,2.0)
	manager._wait_at_junction(second_record,2.0)
	assert(not first_record.connection.is_empty() and second_record.connection.is_empty())
	assert(manager._junction_owners.size() == 1)
	first.leave_traffic()
	assert(manager._junction_owners.is_empty(),"Pickup handoff retained intersection lock")
	first.free()
	manager._step(1.0/60.0)
	await physics_frame
	await physics_frame
	manager._wait_at_junction(second_record,2.0)
	assert(not second_record.connection.is_empty())
	second.free()
	manager._step(1.0/60.0)
	assert(manager._junction_owners.is_empty(),"Freed car retained intersection lock")
	city.free()
	print("PASS: real-city straight/left/right traversal, pause, continued movement, single occupancy and release/free cleanup")
	quit()
