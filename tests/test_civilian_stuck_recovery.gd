extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var city = load("res://scenes/super_city.tscn").instantiate()
	for node_name in ["Player", "CivilianCrowd", "CityPedestrianRoutes"]:
		if city.has_node(node_name): city.get_node(node_name).free()
	var pilot = load("res://scenes/npcs/civilian_route_pilot.tscn").instantiate()
	pilot.get_node("Civilian").free()
	city.add_child(pilot)
	root.add_child(city)
	var graph = pilot.get_node("RouteGraph")
	var walker = load("res://scenes/npcs/routed_civilian.tscn").instantiate()
	walker.route_graph_path = graph.get_path()
	walker.lane_offset = 0.4
	walker.begin_ambient_route(graph, 0, 6)
	walker.position = walker.spawn_position(0.2) + Vector3.UP * 0.01
	city.add_child(walker)
	var start: Vector3 = walker.global_position
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 2, 1)
	shape.shape = box
	wall.add_child(shape)
	city.add_child(wall)
	wall.global_position = start + Vector3(0, 1, 4)
	# An intentional wait longer than the recovery threshold must be ignored.
	walker._pause_remaining = 2.0
	for i in range(110): await physics_frame
	if walker.stuck_recoveries != 0:
		_fail("Intentional wait triggered recovery")
		return
	walker.spacing_speed_limit = 0.0
	for i in range(120): await physics_frame
	if walker.stuck_recoveries != 0:
		_fail("Waiting behind another pedestrian triggered recovery")
		return
	walker.spacing_speed_limit = INF
	var previous: Vector3 = walker.global_position
	for i in range(330):
		await physics_frame
		if walker.global_position.distance_to(previous) > 0.2:
			_fail("Recovery teleported the civilian")
			return
		previous = walker.global_position
	if walker.stuck_recoveries != 1 or walker.global_position.z >= start.z - 1.0:
		_fail("Blocked civilian did not reverse and walk away: " + walker.route_status)
		return
	if walker.get_node("CollisionShape3D").disabled or walker.lane_offset != 0.4:
		_fail("Recovery changed collisions or lost the lane offset")
		return
	print("PASS: intentional wait ignored; blocked civilian reversed and walked away without teleporting or disabling collision")
	city.free()
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
