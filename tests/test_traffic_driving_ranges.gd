extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("Traffic ranges test timed out"); quit(1))
	seed(815)
	var city := Node3D.new()
	root.add_child(city)
	current_scene = city
	var focus := Node3D.new()
	focus.name = "Focus"
	city.add_child(focus)
	var manager = load("res://scenes/vehicles/traffic_manager.tscn").instantiate()
	manager.focus_path = ^"../Focus"
	manager.get_node("DistantTraffic").enabled = false # Isolate the full-vehicle fixture.
	manager.prefer_offscreen_spawns = false
	city.add_child(manager)
	manager.set_physics_process(false)
	manager._timer = 1000000.0
	manager.lanes.assign([{"start":Vector3.ZERO,"end":Vector3(0,0,200),
		"forward":Vector3.BACK,"length":200.0,"junction":-1,"connections":[]}])
	manager.minimum_following_gap = 2.0
	manager.maximum_following_gap = 4.0
	manager.minimum_intersection_speed = 4.0
	manager.maximum_intersection_speed = 6.0
	var gaps: Dictionary = {}
	var speeds: Dictionary = {}
	for i in range(16):
		var car: Vehicle = manager._spawn_vehicle(manager.vehicle_entries[0],0,20.0)
		assert(car != null)
		var record: Dictionary = manager._cars[0]
		assert(record.following_gap >= 2.0 and record.following_gap <= 4.0)
		assert(record.intersection_speed >= 4.0 and record.intersection_speed <= 6.0)
		gaps[record.following_gap] = true
		speeds[record.intersection_speed] = true
		car.free()
		manager._step(0.0)
	assert(gaps.size() > 1 and speeds.size() > 1,"Cars received identical driving values")
	# Inverted ranges collapse to the minimum, matching cruise-speed settings.
	manager.minimum_following_gap = 6.0
	manager.maximum_following_gap = 2.0
	manager.minimum_intersection_speed = 5.0
	manager.maximum_intersection_speed = 3.0
	var lead: Vehicle = manager._spawn_vehicle(manager.vehicle_entries[0],0,100.0)
	assert(lead != null)
	var leader: Dictionary = manager._cars[0]
	assert(leader.following_gap == 6.0 and leader.intersection_speed == 5.0)
	# A new car ahead must respect the existing follower's larger gap.
	manager.minimum_following_gap = 2.0
	manager.maximum_following_gap = 2.0
	var close_progress: float = leader.progress+leader.half_length*2.0+3.0
	assert(manager._spawn_vehicle(manager.vehicle_entries[0],0,close_progress) == null,
		"Spawn ignored the existing follower's gap")
	await physics_frame
	await physics_frame
	var stops: Array[float] = []
	for gap in [2.0,6.0]:
		manager.minimum_following_gap = gap
		manager.maximum_following_gap = gap
		var follower: Vehicle = manager._spawn_vehicle(manager.vehicle_entries[0],0,70.0)
		assert(follower != null)
		var record: Dictionary = manager._cars[-1]
		record.cruise = 10.0
		await physics_frame
		await physics_frame
		# Keep the leader stopped. Advance only the follower against its real collider.
		for frame in range(900): manager._drive(record,1.0/60.0)
		var bumper_gap: float = leader.progress-record.progress-leader.half_length-record.half_length
		assert(absf(bumper_gap-gap) < 0.15,"Follower did not stop at its own selected gap")
		assert(record.speed < 0.1)
		stops.append(record.progress)
		follower.free()
		manager._step(0.0)
	assert(absf(stops[0]-stops[1]-4.0) < 0.15,"Different gaps did not produce different spacing")
	city.free()
	print("PASS: varied bounded driving values, inverted/equal ranges, directional spawn clearance and actual follower stopping gaps")
	quit()
