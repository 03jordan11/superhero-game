extends SceneTree
## Short load/movement smoke check, not a player or crowd performance test.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var city = load("res://scenes/super_city.tscn").instantiate()
	# Player placement and gameplay testing belong to the user.
	if city.has_node("Player"):
		city.get_node("Player").free()
	if city.has_node("CityPedestrianRoutes"):
		city.get_node("CityPedestrianRoutes").free()
	if not city.has_node("CivilianRoutePilot"):
		city.add_child(load("res://scenes/npcs/civilian_route_pilot.tscn").instantiate())
	var pilot = city.get_node("CivilianRoutePilot")
	var civilian = pilot.get_node("Civilian")
	root.add_child(city)
	var graph = pilot.get_node("RouteGraph")
	if not graph.valid or graph.astar.get_point_count() != 15:
		_fail("Graph did not load")
		return
	if graph.route(0,14).is_empty() or not graph.route(0,9,false).is_empty():
		_fail("Crossing connectivity is incorrect")
		return
	if not graph.route(0,999).is_empty():
		_fail("Invalid destination must return an empty route")
		return
	var before: Vector3 = civilian.global_position
	for i in range(180):
		await physics_frame
	if civilian.global_position.distance_to(before) < 4.0:
		_fail("Civilian failed to walk: "+civilian.route_status)
		return
	if absf(civilian.global_position.x+572.0) > 0.1 or absf(civilian.global_position.y-0.03) > 0.1:
		_fail("Civilian left its starting sidewalk")
		return
	if civilian.animation_controller.animation_player.current_animation != "Walk":
		_fail("Existing walk animation was not selected")
		return
	civilian.route_enabled = false
	await physics_frame
	await physics_frame
	if Vector2(civilian.velocity.x,civilian.velocity.z).length() > 0.01:
		_fail("Route disable did not stop the civilian")
		return
	print("PASS: route connectivity, sidewalk movement, animation and disable. Sliding left for visual testing.")
	city.free()
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
