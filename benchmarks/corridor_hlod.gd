extends "res://benchmarks/corridor_rendering.gd"
## Paired same-camera HLOD comparisons; settings/progress never saved.
const HLOD_OUTPUT := "res://artifacts/city_proxies_500/benchmark/"

func capture_hlod(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(HLOD_OUTPUT + label + ".png")

func run() -> void:
	assert(DisplayServer.get_name() != "headless", "Graphical rendering required")
	DirAccess.make_dir_recursive_absolute(HLOD_OUTPUT)
	report_path = HLOD_OUTPUT + "results.json"
	var capture := "res://artifacts/live_performance/city_13296.jsonl"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="): capture = argument.trim_prefix("--capture=")
	var lines := FileAccess.get_file_as_string(capture).strip_edges().split("\n", false)
	var pose: Dictionary = JSON.parse_string(lines[-1])
	seed(8421)
	root.get_node("CityWindows").start_new_game(8421)
	var settings := root.get_node("GameSettings")
	settings.set_graphics_settings(100, 0, false, 0, false, false)
	settings.set_population_settings(0, 0, 2, false)
	root.size = Vector2i(2560, 1440)
	root.content_scale_size = root.size
	AudioServer.set_bus_mute(0, true)
	world = load("res://scenes/main.tscn").instantiate()
	player = world.get_node("Player")
	player.position = Vector3(pose.player_position[0], pose.player_position[1], pose.player_position[2])
	root.add_child(world)
	current_scene = world
	city = world.get_node("SuperCity")
	player.set_physics_process(false)
	player.set_process_input(false)
	for monitor in world.get_node("PerformanceMonitors").get_children():
		monitor.enabled = false
		monitor.set_process(false)
	for node in world.find_children("*", "CanvasLayer", true, false): node.hide()
	world.get_node("PerformanceHUD").set_process(false)
	var cycle := city.get_node("DayNightCycle")
	cycle.cycle_running = false
	cycle.set_time(17.0)
	camera = Camera3D.new()
	root.add_child(camera)
	camera.fov = player.camera.fov
	camera.far = player.camera.far
	camera.position = vector_from_log(pose.camera_position)
	camera.rotation = vector_from_log(pose.camera_rotation)
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var controller := city.get_node("CityBuildingChunks")
	while not controller.prepared: await process_frame
	await create_timer(8.0).timeout
	pause_branch(world)
	paused = true
	report.gpu = RenderingServer.get_video_adapter_name()
	report.capture = capture
	report.recorded_view = pose
	report.build_ms = controller.build_ms
	report.chunks = controller.batches.map(func(batch): return batch.inventory())
	report.note = "Same-camera frozen scene pairs. One single-surface simplified box/tier proxy per chunk; original building geometry hidden in distant chunks. Physics unchanged."
	for trial in 2:
		controller.enabled = false
		await sample("originals_%d" % (trial + 1), 3)
		if trial == 0: await capture_hlod("originals")
		controller.enabled = true
		controller.update_visibility()
		await sample("hlod_%d" % (trial + 1), 3)
		if trial == 0: await capture_hlod("hlod")
	# Force proxies near the camera only for visual QA, not performance claims.
	for batch in controller.batches: batch.set_far(true)
	await capture_hlod("forced_hlod_near")
	controller.update_visibility()
	# Compare night lighting from the same stopped scene.
	cycle.set_time(23.0)
	controller.enabled = false
	await sample("night_originals", 2)
	await capture_hlod("night_originals")
	controller.enabled = true
	controller.update_visibility()
	await sample("night_hlod", 2)
	await capture_hlod("night_hlod")
	for batch in controller.batches: batch.set_far(true)
	await capture_hlod("night_forced_hlod_near")
	controller.update_visibility()
	report.active_chunks = controller.batches.filter(func(batch): return batch.far_active).map(func(batch): return batch.chunk_name)
	# Flight view exposes more of the chunk than a street corridor does.
	cycle.set_time(17.0)
	camera.position = Vector3(-1050, 550, -900)
	camera.look_at(Vector3(-550, 0, -480))
	controller.enabled = false
	await sample("flight_originals", 3)
	await capture_hlod("flight_originals")
	controller.enabled = true
	controller.update_visibility()
	await sample("flight_hlod", 3)
	await capture_hlod("flight_hlod")
	# Verify the stand-ins' actual rendering cost without other city geometry.
	# These forced-all comparisons are separate from normal distance switching.
	for visual in world.find_children("*", "GeometryInstance3D", true, false): visual.hide()
	for batch in controller.batches:
		batch.set_far(true)
		batch.set_far(false)
	await sample("corridor_originals_only", 1)
	await capture_hlod("corridor_originals_only")
	for batch in controller.batches: batch.set_far(true)
	await sample("corridor_proxies_only", 1)
	await capture_hlod("corridor_proxies_only")
	save_report()
	print("HLOD_BENCHMARK_COMPLETE ", ProjectSettings.globalize_path(report_path))
	quit()
