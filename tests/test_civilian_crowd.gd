extends SceneTree
## Small population lifecycle check with a movable marker, never the player.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	seed(411)
	var city = load("res://scenes/super_city.tscn").instantiate()
	if city.has_node("Player"): city.get_node("Player").free()
	var focus := Node3D.new()
	focus.name = "CrowdFocus"
	city.add_child(focus)
	focus.position = Vector3(-1286,0.03,-972)
	var camera := Camera3D.new()
	focus.add_child(camera)
	camera.position.y = 2.0
	camera.rotation.y = PI # Look south into the city, with visible spawning enabled.
	camera.current = true
	var crowd = city.get_node("CivilianCrowd")
	crowd.get_node("CapsuleLOD").enabled = false # Preserved full-only fallback.
	crowd.player_path = ^"../CrowdFocus"
	crowd.population_target = 8
	crowd.max_civilians = 8
	crowd.ground_radius = 70.0
	crowd.forward_cone_angle = 75.0
	crowd.retention_angle_margin = 35.0
	crowd.minimum_player_distance = 5.0
	crowd.despawn_delay = 0.25
	crowd.spawns_per_frame = 1
	crowd.prefer_offscreen_spawns = false
	root.add_child(city)
	await physics_frame
	await physics_frame
	if crowd._capacity_for_length(0.0) != 0 or crowd._capacity_for_length(25.0) != 1 or crowd._capacity_for_length(100.0) != 4 or crowd._capacity_for_length(1000.0) != 6:
		fail("Route length density or local ceiling is incorrect")
		return
	if not crowd._spawn_distance_ok(focus.global_position+Vector3.FORWARD*20.0) or crowd._spawn_distance_ok(focus.global_position+Vector3.RIGHT*50.0):
		fail("Nearby circle should include behind; distant sides should be outside the cone")
		return
	var angle_point := focus.global_position+Vector3.BACK.rotated(Vector3.UP,deg_to_rad(45.0))*50.0
	if crowd._in_population_area(angle_point) or not crowd._in_population_area(angle_point,true):
		fail("Retention angle should be wider than the spawn cone")
		return
	for frame in range(180):
		await physics_frame
		if crowd.active_count > 8:
			fail("Population exceeded cap")
			return
	if crowd.active_count < 4:
		fail("Too few civilians spawned: %d / %s" % [crowd.active_count,crowd.status])
		return
	if crowd._spawn_forward.dot(Vector3.BACK) < 0.99:
		fail("Stationary population did not favor the camera direction")
		return
	var ahead := 0
	for walker in crowd.get_node("ActiveCivilians").get_children():
		if walker.global_position.z > focus.global_position.z: ahead += 1
	if ahead < ceili(crowd.active_count*0.5):
		fail("Initial population favored behind the camera")
		return
	if crowd._forward_preference(focus.global_position+Vector3.BACK*45.0) <= crowd._forward_preference(focus.global_position+Vector3.FORWARD*45.0):
		fail("Forward selection weights did not prefer space ahead")
		return
	focus.position.x += 5.0
	crowd._update_spawn_direction(0.1)
	if crowd._spawn_forward.dot(Vector3.RIGHT) < 0.99:
		fail("Fast travel did not override the sideways camera view")
		return
	focus.position.x -= 5.0
	crowd._has_player_sample = false
	crowd.despawn_delay = 1.0
	camera.rotation.y = 0.0
	crowd._update_population(0.25)
	if crowd._spawn_forward.dot(Vector3.FORWARD) < 0.99 or not crowd._retiring.is_empty():
		fail("Camera turn failed to update preference or retired existing civilians")
		return
	camera.rotation.y = PI
	crowd._update_population(0.25)
	crowd.despawn_delay = 0.25
	crowd.show_population_area = true
	crowd._draw_population_area()
	if crowd._area_debug == null or crowd._area_debug.mesh == null:
		fail("Population boundary overlay did not build")
		return
	crowd.show_population_area = false
	var before: Dictionary = {}
	var offsets: Dictionary = {}
	var shifted := 0
	for walker in crowd.get_node("ActiveCivilians").get_children():
		before[walker] = walker.global_position
		offsets[snappedf(walker.lane_offset,0.1)] = true
		for i in range(walker._path.size()):
			if walker._waypoints[i].distance_to(walker.graph.point_world(walker._path[i])) > 0.15:
				shifted += 1
				break
		if not walker.ambient_roaming or walker.graph == null:
			fail("Segment spawn did not initialize route movement")
			return
	if offsets.size() < 2 or shifted < 2 or crowd._skin_materials.size() < 2:
		fail("Expected varied offsets and shared skin materials")
		return
	for frame in range(180): await physics_frame
	var moved := 0
	for walker in before:
		if is_instance_valid(walker) and walker.global_position.distance_to(before[walker]) > 1.0: moved += 1
	if moved < 3:
		fail("Ambient civilians failed to move")
		return
	crowd.max_civilians = 3
	for frame in range(120): await physics_frame
	if crowd.active_count > 3:
		fail("Runtime cap reduction was not applied")
		return
	focus.position.y = 300.0
	for frame in range(120): await physics_frame
	if crowd.current_target != 0 or crowd.active_count != 0:
		fail("High altitude did not retire full civilians")
		return
	focus.position = Vector3(-1286,0.03,-892)
	for frame in range(180): await physics_frame
	if crowd.active_count == 0:
		fail("Population did not refill after moving and descending")
		return
	city.get_node("CityPedestrianRoutes").network_enabled = false
	for frame in range(90): await physics_frame
	if crowd.active_count != 0:
		fail("Disabled graph retained ambient walkers")
		return
	crowd.crowd_enabled = false
	print("PASS: circle/cone limits, length-based density, wider retention and overlay; forward fill, travel blend, walking, cap/altitude lifecycle and graph disable. No player or visual test.")
	quit()

func fail(message: String) -> void:
	push_error(message)
	quit(1)
