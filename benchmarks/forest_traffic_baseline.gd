extends SceneTree
## Repeat before/after changes with the same config. Never saves gameplay state.
const CONFIG := "res://benchmarks/forest_traffic_baseline_config.json"
const OUTPUT := "res://artifacts/forest_traffic_baseline/"
var config: Dictionary
var report: Dictionary = {"scenarios": []}
var report_path := ""
var label := "before_traffic_removal_verified"
var world: Node3D
var city: Node3D
var camera: Camera3D
var trees: Array[MeshInstance3D] = []
var originals: Array[bool] = []

func _initialize() -> void:
	run.call_deferred()
	create_timer(420).timeout.connect(func(): push_error("Forest baseline timed out"); quit(1))

func vector(value: Variant) -> Vector3:
	if value is String:
		var parts: PackedStringArray = value.trim_prefix("(").trim_suffix(")").split(",")
		return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	return Vector3(value[0], value[1], value[2])

func run() -> void:
	assert(DisplayServer.get_name() != "headless", "This benchmark requires GPU rendering")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--label="): label = argument.trim_prefix("--label=").validate_filename()
	report_path = OUTPUT + label + ".json"
	assert(not FileAccess.file_exists(report_path), "Choose a new --label to preserve existing results")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	seed(config.seed)
	root.get_node("CityWindows").start_new_game(config.seed)
	var settings := root.get_node("GameSettings")
	settings.set_graphics_settings(config.render_scale, config.shadow_quality, config.bloom, 0, false, false)
	settings.set_population_settings(config.crowd_density, config.vehicle_density, config.population_distance, false)
	root.size = Vector2i(config.resolution[0], config.resolution[1])
	root.content_scale_size = root.size
	root.use_occlusion_culling = true
	AudioServer.set_bus_mute(0, true)
	world = load("res://scenes/main.tscn").instantiate()
	var player := world.get_node("Player")
	player.position = vector(config.views[0].player_position)
	for monitor in world.get_node("PerformanceMonitors").get_children(): monitor.enabled = false
	root.add_child(world)
	current_scene = world
	# enabled=false alone still runs CityPerformanceMonitor._process, which resets
	# the viewport measurement flag every frame. Stop monitor processing as well.
	for monitor in world.get_node("PerformanceMonitors").get_children(): monitor.set_process(false)
	city = world.get_node("SuperCity")
	player.set_physics_process(false)
	player.input_controller.set_process(false)
	player.set_process_input(false)
	for canvas in world.find_children("*", "CanvasLayer", true, false): canvas.hide()
	world.get_node("PerformanceHUD").set_process(false)
	var cycle := city.get_node("DayNightCycle")
	cycle.cycle_running = false
	cycle.set_time(config.time_of_day)
	camera = Camera3D.new()
	camera.fov = player.camera.fov
	camera.far = player.camera.far
	root.add_child(camera)
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for controller in get_nodes_in_group(&"city_hlod_preparation"):
		while not controller.prepared: await process_frame
	var counts := {}
	for path in ["CityLife/Highway", "CoastalRegion"]:
		var branch := city.get_node(path)
		assert(branch.is_visible_in_tree(), "Forest parent hidden; restore it before benchmarking: " + path)
		var count := 0
		for mesh: MeshInstance3D in branch.find_children("*", "MeshInstance3D", true, false):
			if not mesh.scene_file_path.begins_with("res://assets/trees/"): continue
			assert(mesh.is_visible_in_tree(), "An authored forest tree is hidden: " + str(mesh.get_path()))
			trees.append(mesh)
			originals.append(mesh.visible)
			count += 1
		counts[path] = count
	assert(trees.size() > 0)
	report.merge({"label": label, "started_utc": Time.get_datetime_string_from_system(true),
		"config": config, "gpu": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info(),
		"camera_fov": camera.fov, "camera_far": camera.far, "viewport": [root.size.x, root.size.y],
		"render_scale": root.scaling_3d_scale, "vsync": DisplayServer.window_get_vsync_mode(),
		"fps_cap": Engine.max_fps, "forest_counts": counts,
		"traffic_manager_present": city.has_node("TrafficManager"),
		"traffic_controls_visible": city.get_node("CityLife/TrafficControls").is_visible_in_tree() if city.has_node("CityLife/TrafficControls") else false,
		"notes": "Live stationary simulation; only player locomotion/input is frozen. Traffic/crowds continue, so populations may vary. Only northern/coastal tree visibility changes. Park, roads, terrain, occluders, collisions, city and landmark proxies remain. CPU/physics/GPU timings overlap; do not sum. Quality 0 means Low, not disabled."})
	report.source_hashes = {}
	for path in ["scenes/main.tscn", "scenes/super_city.tscn", "scenes/city_life.tscn", "scenes/coastal_region.tscn", "scripts/traffic/traffic_manager.gd", "scripts/traffic/traffic_box_lod.gd", "scripts/city_life.gd", "scripts/landmark_proxies.gd", "benchmarks/forest_traffic_baseline.gd", CONFIG.trim_prefix("res://")]:
		report.source_hashes[path] = FileAccess.get_sha256("res://" + path)
	for view: Dictionary in config.views:
		camera.position = vector(view.camera_position)
		camera.rotation = vector(view.camera_rotation)
		player.global_position = vector(view.player_position)
		set_forests(true)
		print("FOREST_BASELINE warmup ", view.name)
		await create_timer(config.warmup_seconds).timeout
		for trial in int(config.trials):
			# Reverse order on alternate trials to reduce order/temperature bias.
			for enabled in ([true, false] if trial % 2 == 0 else [false, true]):
				set_forests(enabled)
				await create_timer(config.settle_seconds).timeout
				await sample(view.name, enabled, trial + 1)
				if trial == 0:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(OUTPUT + label + "_" + view.name + ("_on.png" if enabled else "_off.png"))
	set_forests(true)
	report.valid_baseline = true
	var completed := FileAccess.open(report_path, FileAccess.WRITE)
	completed.store_string(JSON.stringify(report, "\t"))
	completed.close()
	print("FOREST_BASELINE_COMPLETE ", report_path)
	world.free()
	quit()

func set_forests(enabled: bool) -> void:
	for i in trees.size(): trees[i].visible = originals[i] and enabled

func population() -> Dictionary:
	var manager := city.get_node_or_null("TrafficManager")
	var crowd := city.get_node_or_null("CivilianCrowd")
	return {"full_vehicles": manager.active_count if manager != null else 0,
		"distant_vehicles": manager._lod.proxies.size() if manager != null and manager._lod != null else 0,
		"full_civilians": get_nodes_in_group(&"civilian").size(),
		"distant_civilians": crowd._lod.capsule_count if crowd != null and crowd._lod != null else 0}

func sample(view: String, enabled: bool, trial: int) -> void:
	var rows := []
	var start := Time.get_ticks_usec()
	var previous := start
	var initial_population := population()
	var rid := root.get_viewport_rid()
	while Time.get_ticks_usec() - start < config.sample_seconds * 1000000.0:
		await process_frame
		var now := Time.get_ticks_usec()
		rows.append({"frame_ms": (now - previous) / 1000.0,
			"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"physics_tick_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu(),
			"gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(rid),
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"rendered_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"render_memory_mib": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0})
		previous = now
	var result := {"view": view, "forests_enabled": enabled, "trial": trial, "frames": rows.size(),
		"nodes": get_node_count(), "population_start": initial_population, "population_end": population(), "stats": {}}
	for key in rows[0]:
		var values := []
		var total := 0.0
		for row in rows:
			values.append(row[key])
			total += row[key]
		values.sort()
		result.stats[key] = {"mean": total / values.size(), "median": values[values.size()/2],
			"p95": values[mini(values.size()-1, ceili(values.size() * 0.95)-1)],
			"p99": values[mini(values.size()-1, ceili(values.size() * 0.99)-1)]}
	result.fps = 1000.0 / result.stats.frame_ms.mean
	assert(result.stats.gpu_ms.mean > 0.0, "GPU timer unavailable; do not accept this baseline")
	var raw_path := OUTPUT + label + "_" + view + ("_on_" if enabled else "_off_") + str(trial) + ".json"
	var raw := FileAccess.open(raw_path, FileAccess.WRITE)
	raw.store_string(JSON.stringify(rows))
	raw.close()
	result.raw_samples = raw_path
	report.scenarios.append(result)
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("FOREST_SAMPLE ", view, " on=", enabled, " trial=", trial, " fps=", snappedf(result.fps, 0.1), " draw_calls=", snappedf(result.stats.draw_calls.mean, 1))
