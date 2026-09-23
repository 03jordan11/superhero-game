extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
	create_timer(120).timeout.connect(func(): push_error("Landmark test timed out"); quit(1))
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	paused = true
	var loading := root.get_node("LoadingScreen")
	loading.begin("LANDMARK TEST")
	var main := load("res://scenes/main.tscn").instantiate() as Node3D
	for monitor in main.get_node("PerformanceMonitors").get_children(): monitor.enabled = false
	root.add_child(main)
	current_scene = main
	var controller := main.get_node("SuperCity/LandmarkProxies")
	await loading.finish(true)
	paused = true
	controller.set_process(false)
	check(controller.prepared and controller.prepared_chunks == 17, "Loading waits for all 17 landmarks")
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	var collisions := {}
	for entry in controller.entries:
		for collider in entry.source.find_children("*", "CollisionShape3D", true, false):
			collisions[collider] = [collider.disabled, collider.global_transform, collider.shape]
		check(entry.proxy.mesh.get_surface_count() == 1, "Exactly one surface per landmark")
		check(entry.proxy.global_transform.is_equal_approx(entry.source.global_transform), "Proxy uses source position/rotation/scale")
		camera.position = entry.centre
		controller.update_visibility()
		check(not entry.far_active and entry.source.visible and not entry.proxy.visible, "Near view uses original")
		camera.position = entry.centre + Vector3(entry.radius + controller.near_distance_m + controller.switching_margin_m + 1, 0, 0)
		controller.update_visibility()
		check(entry.far_active and entry.proxy.is_visible_in_tree(), "Distant camera uses visible replacement")
		for visual in entry.source.find_children("*", "GeometryInstance3D", true, false):
			check(not visual.is_visible_in_tree(), "All original geometry is hidden when distant")
		for light in entry.source.find_children("*", "Light3D", true, false):
			check(not light.is_visible_in_tree(), "Original landmark lights are hidden when distant")
		if entry.source.name == &"CentralPark":
			entry.source.apply_night(1.0)
			check(not entry.source.get_node("Fireflies").is_visible_in_tree(), "Park animation cannot re-show hidden fireflies")
		camera.position = entry.centre + Vector3(entry.radius + controller.near_distance_m + 5, 0, 0)
		controller.update_visibility()
		check(entry.far_active, "Return hysteresis retains distant proxy in margin")
		camera.position = entry.centre + Vector3(entry.radius + controller.near_distance_m - 1, 0, 0)
		controller.update_visibility()
		check(not entry.far_active and entry.source.visible, "Returning restores original root")
	controller.enabled = false
	for entry in controller.entries:
		check(entry.source.visible == entry.original_visible and not entry.proxy.visible, "Enabled=false restores original-only rendering")
	for collider in collisions:
		check(collisions[collider] == [collider.disabled, collider.global_transform, collider.shape], "Collision shape, transform and enabled state unchanged")
	var clock := get_first_node_in_group(&"day_night_cycle")
	clock.set_time(23.0)
	controller._refresh_lighting()
	for entry in controller.entries:
		check(entry.proxy.material_override.get_shader_parameter("night_amount") > 0.9, "Night emission follows clock")
	clock.set_time(12.0)
	controller._refresh_lighting()
	for entry in controller.entries:
		check(entry.proxy.material_override.get_shader_parameter("night_amount") < 0.01, "Daytime emission is off")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(controller.DATA_PATH))
	for record in data.landmarks:
		var mesh: ArrayMesh = load(record.mesh)
		var actual: int = mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
		check(actual == record.proxy_triangles and actual < record.source_triangles / 2, "Saved replacement geometry matches audit and is substantially reduced")
		if record.path.ends_with("CentralPark"): check(actual == 2, "Park is a two-triangle rectangle")
		else: check(record.source_triangles <= 10000, "Highest detail building POI stays within 10k budget")
	main.free()
	camera.free()
	print("LANDMARK_PROXY_TEST: ", failures, " failures; no FPS measurement")
	quit(1 if failures else 0)
