extends "res://tests/profile_city_audit.gd"
## Disposable comparison; saved scenes and player preferences are never changed.
const OUTPUT := "res://artifacts/park_forest_benchmark/"
const TREES = preload("res://assets/trees/tools/tree_instances.gd")
var variant := "current"
var run_id := "1"

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--variant="): variant = argument.trim_prefix("--variant=")
		if argument.begins_with("--run="): run_id = argument.trim_prefix("--run=")
	assert(DisplayServer.get_name() != "headless", "Requires GPU rendering")
	assert(variant in ["current", "before_manual", "historical"])
	# Keep editor/import UID cache changes from redirecting the live park to a fixture.
	ResourceUID.set_id(ResourceUID.text_to_id("uid://b8uj04omxmld5"), "res://scenes/central_park.tscn")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	report_path = OUTPUT + variant + "_" + run_id + ".json"
	seed(8421)
	root.get_node("CityWindows").start_new_game(8421)
	var settings := root.get_node("GameSettings")
	settings.set_graphics_settings(100, 3, true, 0, false, false)
	settings.set_population_settings(2, 2, 2, false)
	root.size = Vector2i(1600, 900)
	root.content_scale_size = Vector2i(1600, 900)
	AudioServer.set_bus_mute(0, true)
	root.use_occlusion_culling = true
	if variant == "historical":
		world = load("res://scenes/main.tscn").instantiate()
		root.add_child(world)
		city = world.get_node("SuperCity")
		player = world.get_node("Player")
		player.set_physics_process(false)
		player.input_controller.set_process(false)
		player.superhero_character.hide()
		for monitor in world.get_node("PerformanceMonitors").get_children(): monitor.sample_interval = 300
	else:
		city = load("res://scenes/super_city.tscn").instantiate()
		world = city
		for node_name in ["TrafficManager", "CivilianCrowd", "Sound", "PreviewCamera"]:
			city.get_node(node_name).free()
		if variant == "before_manual": restore_before_layout()
		# Reuse the audit's sampling without introducing live actors or monitors.
		var monitors := Node.new()
		monitors.name = "PerformanceMonitors"
		world.add_child(monitors)
		root.add_child(world)
	current_scene = world
	var clock := city.get_node("DayNightCycle")
	clock.cycle_running = false
	camera = Camera3D.new()
	root.add_child(camera)
	camera.far = 60000
	camera.fov = 75
	camera.make_current()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for i in 30: await process_frame
	if variant != "historical": world.process_mode = Node.PROCESS_MODE_DISABLED
	report.variant = variant
	report.run = run_id
	report.engine = Engine.get_version_info()
	report.gpu = RenderingServer.get_video_adapter_name()
	report.viewport = [root.size.x, root.size.y]
	report.render_scale = root.scaling_3d_scale
	report.park = inventory(city.get_node("Landmarks/CentralPark"))
	report.forest = inventory(city.get_node("CityLife/Highway"))
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT + "source_counts.json"))
	var layout := "before" if variant == "before_manual" else "after"
	assert(TREES.trees(city.get_node("Landmarks/CentralPark")).size() == expected.central_park[layout].trees, "Wrong park layout loaded")
	assert(TREES.trees(city.get_node("CityLife")).size() == expected.city_life[layout].trees, "Wrong forest layout loaded")
	assert(report.park.lights == expected.central_park[layout].lights, "Wrong park light count")
	report.total_nodes = get_node_count()
	report.source_hashes = {
		"park": FileAccess.get_sha256("res://scenes/central_park.tscn"),
		"city_life": FileAccess.get_sha256("res://scenes/city_life.tscn")
	}
	var views := [
		["park_day", Vector3(-180,50,100), Vector3(-380,5,-60), 12.0],
		["park_night", Vector3(-180,50,100), Vector3(-380,5,-60), 23.0],
		["forest_day", Vector3(-2300,800,-600), Vector3(-1400,0,-2250), 12.0],
	]
	if variant == "historical":
		views = [
			["clear_skyline_baseline", Vector3(-350,140,260), Vector3(600,95,-220), 23.0],
			["clear_street_baseline", Vector3(100,3,-320), Vector3(100,3,-600), 23.0],
			["park_live", Vector3(-180,50,100), Vector3(-380,5,-60), 12.0],
			["aerial_live", Vector3(-150,180,370), Vector3(150,120,530), 12.0],
		]
	for view in views:
		camera.position = view[1]
		camera.look_at(view[2])
		clock.set_time(view[3])
		if variant == "historical": player.global_position = camera.position
		await create_timer(12.0 if variant == "historical" else 4.0).timeout
		for trial in (1 if variant == "historical" else 2):
			await sample(view[0] + ("" if variant == "historical" else "_trial%d" % (trial + 1)), 5.0 if variant == "historical" else 4.0)
		if run_id == "1":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUTPUT + variant + "_" + view[0] + ".png")
	print("PARK_FOREST_BENCHMARK_COMPLETE ", variant, " ", run_id)
	quit()

func restore_before_layout() -> void:
	var park := city.get_node("Landmarks/CentralPark") as Node3D
	var parent := park.get_parent()
	var pose := park.transform
	var index := park.get_index()
	park.free()
	var original := load(OUTPUT + "central_park_before.tscn").instantiate() as Node3D
	original.name = "CentralPark"
	original.transform = pose
	parent.add_child(original)
	parent.move_child(original, index)
	TREES.restore_saved_layout(city.get_node("CityLife"), OUTPUT + "city_life_before.tscn")
