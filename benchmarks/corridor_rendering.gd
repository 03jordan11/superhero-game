extends "res://tests/profile_city_followup.gd"
## Disposable rendering isolation at the last captured road view.
## Never saves game scenes, materials, graphics preferences or player progress.
const OUTPUT := "res://artifacts/corridor_rendering/"
var groups: Dictionary = {}
var original_visibility: Dictionary = {}

func vector_from_log(value: String) -> Vector3:
	var parts := value.trim_prefix("(").trim_suffix(")").split(",")
	assert(parts.size() == 3)
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))

func latest_capture() -> String:
	var folder := "res://artifacts/live_performance/"
	var newest := ""
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".jsonl") and (newest.is_empty() or FileAccess.get_modified_time(folder + file) > FileAccess.get_modified_time(newest)):
			newest = folder + file
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="): newest = argument.trim_prefix("--capture=")
	return newest

func category(node: Node) -> String:
	var path := str(city.get_path_to(node))
	# Categorize placed buildings before their containing sidewalk branch.
	var ancestor := node
	while ancestor != city and ancestor != null:
		if ancestor.scene_file_path.begins_with("res://assets/buildings/") or ancestor.scene_file_path.begins_with("res://assets/generated-buildings/"):
			return "buildings"
		ancestor = ancestor.get_parent()
	if path.begins_with("Districts/"): return "buildings"
	if path.begins_with("Roads/") or path.begins_with("Sidewalks/") or path.begins_with("Ground/Sidewalks"):
		return "roads_sidewalks"
	if path.begins_with("CityLife/") or path.begins_with("NightLights/"): return "street_props_and_city_life"
	if path.begins_with("TrafficManager/"): return "traffic"
	if path.begins_with("CivilianCrowd/"): return "crowd"
	return "other"

func gather_geometry() -> void:
	var totals := {}
	for node in city.find_children("*", "GeometryInstance3D", true, false):
		var key := category(node)
		if not groups.has(key):
			groups[key] = []
			totals[key] = {"geometry_nodes": 0, "mesh_surfaces": 0}
		groups[key].append(node)
		original_visibility[node] = node.visible
		totals[key].geometry_nodes += 1
		if node is MeshInstance3D and node.mesh != null: totals[key].mesh_surfaces += node.mesh.get_surface_count()
	report.geometry_inventory = totals
	# Read actual source and runtime mesh LOD data, once per resource.
	var seen := {}
	var lod_totals := {"source_surfaces_with_lods": 0, "runtime_surfaces_with_lods": 0, "unique_mesh_pairs": 0}
	for node in groups.get("buildings", []):
		if not node is MeshInstance3D or not "_original_mesh" in node.get_parent(): continue
		var original: Mesh = node.get_parent()._original_mesh
		if original == null or seen.has(original): continue
		seen[original] = true
		lod_totals.unique_mesh_pairs += 1
		for pair in [[original, "source_surfaces_with_lods"], [node.mesh, "runtime_surfaces_with_lods"]]:
			for property in pair[0].get_property_list():
				if property.name != "_surfaces": continue
				for surface in pair[0].get("_surfaces"):
					if not surface.get("lods", []).is_empty(): lod_totals[pair[1]] += 1
	report.building_mesh_lods = lod_totals

func set_hidden(key: String, beyond := -1.0) -> int:
	var count := 0
	for node in groups.get(key, []):
		var distance := Vector2(node.global_position.x - camera.global_position.x, node.global_position.z - camera.global_position.z).length()
		if beyond >= 0 and distance <= beyond: continue
		node.hide()
		count += 1
	return count

func restore_geometry() -> void:
	for node in original_visibility: node.visible = original_visibility[node]

func screenshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + label + ".png")

func share_equivalent_window_materials() -> Array:
	var originals: Array = []
	var shared := {}
	for node in groups.get("buildings", []):
		if not node is MeshInstance3D or node.mesh == null: continue
		for surface in node.mesh.get_surface_count():
			var material := node.get_active_material(surface) as ShaderMaterial
			if material == null or material.shader == null: continue
			var key: Array = [material.shader, material.render_priority, material.next_pass]
			for property in material.get_property_list():
				if str(property.name).begins_with("shader_parameter/"):
					key.append(property.name)
					key.append(material.get(property.name))
			if not shared.has(key): shared[key] = material
			originals.append([node, surface, node.get_surface_override_material(surface)])
			node.set_surface_override_material(surface, shared[key])
	report.equivalent_material_sharing = {"surfaces": originals.size(), "unique_materials": shared.size()}
	return originals

func run() -> void:
	assert(DisplayServer.get_name() != "headless", "Run with graphics: this test measures rendering.")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var baseline_only := "--baseline-only" in OS.get_cmdline_user_args()
	report_path = OUTPUT + ("material_sharing_baseline.json" if baseline_only else "results.json")
	var capture := latest_capture()
	assert(not capture.is_empty(), "A live city capture is required.")
	var lines := FileAccess.get_file_as_string(capture).strip_edges().split("\n", false)
	var pose: Dictionary = JSON.parse_string(lines[-1])
	report.capture = capture
	report.recorded_view = pose
	seed(8421)
	root.get_node("CityWindows").start_new_game(8421)
	var settings := root.get_node("GameSettings")
	settings.set_graphics_settings(100, 0, false, 0, false, false)
	settings.set_population_settings(0, 0, 2, false)
	root.size = Vector2i(2560, 1440)
	root.content_scale_size = Vector2i(2560, 1440)
	AudioServer.set_bus_mute(0, true)
	world = load("res://scenes/main.tscn").instantiate()
	# Population initializes at the captured location, not at the hideout.
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
	await create_timer(8.0).timeout
	report.gpu = RenderingServer.get_video_adapter_name()
	report.engine = Engine.get_version_info()
	report.camera_fov = camera.fov
	report.viewport = str(root.size)
	report.note = "Rendering isolation: simulation frozen after live baseline. Only geometry visibility changes; occluders, lights and collisions stay active. Hiding distant buildings is an upper bound, not an HLOD implementation."
	await sample("live_baseline", 4)
	# Keep actors, lights and object positions identical for every rendering trial.
	pause_branch(world)
	paused = true
	gather_geometry()
	save_report()
	await sample("frozen_baseline", 4)
	await screenshot("material_sharing_baseline" if baseline_only else "baseline")
	if baseline_only:
		print("CORRIDOR_BASELINE_COMPLETE ", ProjectSettings.globalize_path(report_path))
		quit()
		return
	for trial in 2:
		for key in ["buildings", "roads_sidewalks", "street_props_and_city_life", "traffic", "crowd"]:
			set_hidden(key)
			await sample("hide_%s_trial%d" % [key, trial + 1], 3)
			if trial == 0 and key == "buildings": await screenshot("buildings_hidden")
			restore_geometry()
		await sample("restored_baseline_trial%d" % (trial + 1), 3)
	for distance in [150.0, 300.0]:
		set_hidden("buildings", distance)
		await sample("hide_buildings_beyond_%dm" % int(distance), 4)
		restore_geometry()
	var originals := share_equivalent_window_materials()
	await sample("shared_equivalent_building_materials", 4)
	await screenshot("shared_materials")
	for row in originals: row[0].set_surface_override_material(row[1], row[2])
	await sample("final_restored_baseline", 4)
	print("CORRIDOR_COMPLETE ", ProjectSettings.globalize_path(report_path))
	quit()
