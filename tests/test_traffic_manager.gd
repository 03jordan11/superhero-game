extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("Traffic test timed out"); quit(1))
	seed(810)
	var city := Node3D.new()
	root.add_child(city)
	current_scene = city
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(6000,1,5000)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.5
	floor_body.add_child(floor_shape)
	city.add_child(floor_body)
	var focus := Node3D.new()
	focus.name = "Focus"
	city.add_child(focus)
	var manager = load("res://scenes/vehicles/traffic_manager.tscn").instantiate()
	manager.focus_path = ^"../Focus"
	manager.population_target = 1
	manager.get_node("DistantTraffic").enabled = false # Isolate the full-vehicle fixture.
	manager.prefer_offscreen_spawns = false
	manager.intersection_pause = 100000.0 # This fixture isolates the stop line and pickup.
	manager.minimum_following_gap = 3.0
	manager.maximum_following_gap = 3.0
	city.add_child(manager)
	manager.set_physics_process(false)
	manager._timer = 1000000.0
	assert(manager.lanes.size() == 706)
	for i in range(0,manager.lanes.size(),2):
		var a: Dictionary = manager.lanes[i]
		var b: Dictionary = manager.lanes[i+1]
		assert(a.forward.is_equal_approx(-b.forward))
		assert(a.road.has_point(Vector2(a.start.x,a.start.z)))
		assert(a.road.grow(0.001).has_point(Vector2(b.start.x,b.start.z)))
	assert(manager.vehicle_entries.size() == 17)
	var total := 0.0
	for entry in manager.vehicle_entries: total += entry.weight
	assert(is_equal_approx(total,100.0))
	var entries: Array = manager.vehicle_entries.duplicate()
	for entry in manager.vehicle_entries: entry.weight = 0.0
	assert(manager._choose_entry() == null)
	manager.vehicle_entries[0].weight = 1.0
	assert(manager._choose_entry() == manager.vehicle_entries[0])
	for i in range(entries.size()): manager.vehicle_entries[i].weight = 1.0
	focus.position = manager.lanes[0].start+manager.lanes[0].forward*30.0
	await physics_frame
	await physics_frame
	var car: Vehicle = manager._spawn_vehicle(manager.vehicle_entries[0],0,20.0)
	assert(car != null and car.traffic_controlled and car.freeze)
	assert(car.freeze_mode == RigidBody3D.FREEZE_MODE_KINEMATIC)
	assert(car.global_basis.z.dot(manager.lanes[0].forward) > 0.99)
	assert(manager._spawn_vehicle(manager.vehicle_entries[1],0,21.0) == null)
	var start := car.global_position
	for frame in range(180):
		await physics_frame
		manager._step(1.0/60.0)
	assert(car.global_position.distance_to(start) > 8.0,"Traffic did not advance")
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6,3,6)
	shape.shape = box
	wall.add_child(shape)
	city.add_child(wall)
	var forward: Vector3 = manager.lanes[0].forward
	wall.global_position = car.global_position+forward*18.0+Vector3.UP*1.0
	for frame in range(240):
		await physics_frame
		manager._step(1.0/60.0)
	assert(car.traffic_speed < 0.1,"Traffic did not stop for obstacle")
	assert((wall.global_position-car.global_position).dot(forward) > 5.0)
	wall.free()
	start = car.global_position
	for frame in range(90):
		await physics_frame
		manager._step(1.0/60.0)
	assert(car.global_position.distance_to(start) > 1.0,"Traffic did not resume")
	var record: Dictionary = manager._cars[0]
	record.stop_at = record.progress+5.0
	for frame in range(180):
		await physics_frame
		manager._step(1.0/60.0)
	assert(record.progress <= record.stop_at+0.001 and car.traffic_speed < 0.1)
	# Actual ray pickup and release: no traffic transform may overwrite the carry pose.
	var player := CharacterBody3D.new()
	player.add_to_group(&"player")
	city.add_child(player)
	player.global_position = car.global_position-forward*8.0
	var camera := Camera3D.new()
	player.add_child(camera)
	camera.global_position = player.global_position+Vector3.UP*0.8
	camera.look_at(car.global_position+Vector3.UP*0.8)
	var interactor := PlayerVehicleInteractor.new()
	player.add_child(interactor)
	interactor.setup(player,camera)
	await physics_frame
	await physics_frame
	assert(interactor.try_pick_up_vehicle())
	assert(not car.traffic_controlled and car.get_parent() == player)
	assert(interactor.held_vehicle_parent == manager.get_node("ReleasedVehicles"))
	manager._step(1.0/60.0)
	assert(manager._cars.is_empty() and manager.retained_count == 1)
	assert(car.position.is_equal_approx(interactor.held_vehicle_offset))
	interactor.drop_held_vehicle()
	assert(not car.freeze and car.get_parent() == manager.get_node("ReleasedVehicles"))
	manager.traffic_enabled = false
	manager._step(1.0/60.0)
	assert(is_instance_valid(car),"Traffic disable removed an interacted vehicle")
	car.free()
	manager._step(1.0/60.0)
	assert(manager.retained_count == 0)
	city.free()
	print("PASS: generated lanes, weights, spawn spacing, movement, obstacle stop/resume, junction stop, pickup/drop handoff and cleanup")
	quit()
