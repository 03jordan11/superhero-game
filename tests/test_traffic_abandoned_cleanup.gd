extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("Abandoned traffic test timed out"); quit(1))
	var city := Node3D.new()
	root.add_child(city)
	current_scene = city
	var focus := Node3D.new()
	focus.name = "Focus"
	city.add_child(focus)
	var camera := Camera3D.new()
	city.add_child(camera)
	camera.position = Vector3(0,4,0)
	camera.make_current()
	var manager = load("res://scenes/vehicles/traffic_manager.tscn").instantiate()
	manager.focus_path = ^"../Focus"
	manager.get_node("DistantTraffic").enabled = false # Isolate the full-vehicle fixture.
	manager.prefer_offscreen_spawns = false
	manager.max_vehicles = 2
	manager.population_target = 2
	city.add_child(manager)
	manager.set_physics_process(false)
	manager._timer = 1000000.0
	manager.abandoned_cleanup_delay = 3.0
	await physics_frame
	var car: Vehicle = manager._spawn_vehicle(manager.vehicle_entries[0],0,20.0)
	assert(car != null)
	car.leave_traffic()
	car.gravity_scale = 0.0
	car.freeze = false
	car.global_position = Vector3(300,2,0)
	manager._step(0.0)
	assert(manager._cars.is_empty() and manager.retained_count == 1)
	assert(not manager._car_visible(car))
	manager._step(2.0)
	assert(not car.is_queued_for_deletion(),"Cleanup ignored grace period")
	# Looking back resets the whole timer, even when already far away.
	camera.look_at(car.global_position)
	manager._step(5.0)
	assert(not car.is_queued_for_deletion(),"Visible abandoned vehicle was removed")
	camera.look_at(camera.position+Vector3.FORWARD)
	manager._step(2.0)
	assert(not car.is_queued_for_deletion(),"Visibility did not reset the timer")
	# Nearby cars, active throws and spinning cars are all protected.
	car.position.x = 50.0
	manager._step(5.0)
	assert(not car.is_queued_for_deletion(),"Nearby vehicle was removed")
	car.position.x = 300.0
	car.linear_velocity = Vector3.RIGHT*10.0
	manager._step(5.0)
	assert(not car.is_queued_for_deletion(),"Moving thrown vehicle was removed")
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.UP*2.0
	manager._step(5.0)
	assert(not car.is_queued_for_deletion(),"Spinning vehicle was removed")
	car.angular_velocity = Vector3.ZERO
	# Mirror the existing pickup/drop lifecycle, including a second pickup.
	car.reparent(focus)
	car.freeze = true
	manager._step(5.0)
	assert(not car.is_queued_for_deletion(),"Carried vehicle was removed")
	car.reparent(manager.get_node("ReleasedVehicles"))
	car.freeze = false
	manager._step(2.0)
	car.reparent(focus)
	car.freeze = true
	manager._step(0.1)
	car.reparent(manager.get_node("ReleasedVehicles"))
	car.freeze = false
	manager._step(2.0)
	assert(not car.is_queued_for_deletion(),"Repickup did not reset cleanup")
	manager.abandoned_cleanup_enabled = false
	manager._step(5.0)
	assert(not car.is_queued_for_deletion(),"Cleanup toggle was ignored")
	manager.abandoned_cleanup_enabled = true
	manager.focus_path = ^"../MissingFocus"
	manager.use_camera_without_player = false
	manager._step(5.0)
	assert(not car.is_queued_for_deletion(),"Missing focus did not protect vehicles")
	manager.focus_path = ^"../Focus"
	camera.clear_current(false)
	manager._step(5.0)
	assert(not car.is_queued_for_deletion(),"Missing camera did not protect vehicles")
	camera.make_current()
	# Fill the cap with another abandoned car; only one can retire per tick.
	var second: Vehicle = manager._spawn_vehicle(manager.vehicle_entries[1],0,40.0)
	assert(second != null)
	second.leave_traffic()
	second.gravity_scale = 0.0
	second.freeze = false
	second.global_position = Vector3(330,2,0)
	assert(manager._spawn_vehicle(manager.vehicle_entries[2],0,60.0) == null,"Released cars bypassed the cap")
	manager.traffic_enabled = false # Cleanup remains independent of driving population.
	manager._step(3.0)
	assert(manager.abandoned_cleaned_count == 1,"Cleanup retirement was not bounded")
	await process_frame
	manager._step(0.1)
	assert(manager.abandoned_cleaned_count == 2)
	await process_frame
	manager._step(0.0)
	assert(manager.retained_count == 0 and manager._abandoned.is_empty(),"Cleanup left ownership or timer records")
	# Capacity is available for actual population refill after cleanup.
	manager.traffic_enabled = true
	focus.position = manager.lanes[0].start+manager.lanes[0].forward*40.0
	manager.minimum_spawn_distance = 5.0
	manager.spawn_attempts_per_update = 20
	for attempt in range(20):
		manager._timer = 0.0
		manager._step(0.0)
		if manager.active_count > 0: break
	assert(manager.active_count > 0,"Traffic did not refill after abandoned cleanup")
	# External destruction also discards weak tracking records.
	var replacement: Vehicle = manager._cars[0].car
	replacement.leave_traffic()
	replacement.free()
	manager._timer = 1000000.0
	manager._step(0.0)
	assert(manager._abandoned.is_empty(),"Externally freed vehicle left a timer record")
	city.free()
	print("PASS: abandoned cleanup delay/reset, visibility/distance/motion/carry protection, toggles, bounded retirement, bookkeeping and population refill")
	quit()
