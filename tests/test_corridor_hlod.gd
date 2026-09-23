extends SceneTree
var failures := 0

func _initialize() -> void:
	run.call_deferred()
	create_timer(90).timeout.connect(func(): push_error("HLOD test timed out"); quit(1))

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	paused = true
	var loading := root.get_node("LoadingScreen")
	loading.begin("LOADING CITY")
	root.get_node("CityWindows").start_new_game(8421)
	root.get_node("GameSettings").set_population_settings(0, 0, 2, false)
	var main := load("res://scenes/main.tscn").instantiate() as Node3D
	for monitor in main.get_node("PerformanceMonitors").get_children(): monitor.enabled = false
	root.add_child(main)
	current_scene = main
	var controller := main.get_node("SuperCity/CityBuildingChunks")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/chunks/city_chunks.json"))
	await loading.finish(true)
	# This test isolates ordinary city chunks; landmarks have their own swap test.
	main.get_node("SuperCity/LandmarkProxies").enabled = false
	check(controller.prepared and not loading.active, "Loading waits for the actual HLOD preparation")
	check(controller.batches.size() == manifest.chunks.size(), "All city chunks prepared")
	check(controller.total_chunks == manifest.chunks.size(), "Loading progress uses actual city chunk count")
	var source_surfaces := 0
	var merged_surfaces := 0
	for batch in controller.batches:
		check(not batch.originals.is_empty(), "Chunk has supported source visuals")
		check(batch.proxies.size() == 1, "Exactly one proxy mesh per chunk")
		check(batch.merged_surfaces == 1 and batch.proxies[0].mesh.get_surface_count() == 1, "Exactly one drawable surface per chunk")
		check(batch.merged_triangles == batch.proxy_boxes * 10, "Proxy consists of five new quads per structural box")
		check(batch.merged_triangles < batch.source_triangles / 2, "Proxy uses less than half the original triangles")
		for proxy in batch.proxies:
			for surface in proxy.mesh.get_surface_count():
				for vertex: Vector3 in proxy.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					check(batch.bounds.grow(0.02).has_point(proxy.global_transform * vertex), "Baked positions remain inside the source bounds")
		source_surfaces += batch.source_surfaces
		merged_surfaces += batch.merged_surfaces
		batch.set_far(false)
		var near_position: Vector3 = batch.centre + Vector3(controller.near_distance_m + batch.radius - 1, 0, 0)
		var far_position: Vector3 = batch.centre + Vector3(controller.near_distance_m + batch.radius + controller.switching_margin_m + 1, 0, 0)
		batch.update(far_position, controller.near_distance_m, controller.switching_margin_m)
		check(batch.far_active, "Far camera enables replacement")
		for mesh in batch.originals: check(not mesh.visible, "Original visual hidden when replaced")
		for proxy in batch.proxies: check(proxy.is_visible_in_tree(), "Replacement and its parent grid are visible")
		batch.update(near_position, controller.near_distance_m, controller.switching_margin_m)
		check(not batch.far_active, "Returning camera restores originals before near clearance")
		batch.update(batch.centre + Vector3(controller.near_distance_m + batch.radius + 5, 0, 0), controller.near_distance_m, controller.switching_margin_m)
		check(not batch.far_active, "Hysteresis does not oscillate inside the margin")
		for i in batch.originals.size(): check(batch.originals[i].visible == batch.original_visibility[i], "Original visibility restored")
	check(merged_surfaces < source_surfaces, "Merging reduces total material surfaces")
	controller.enabled = false
	check(main.get_node("SuperCity/CityHall").visible, "City Hall unchanged")
	for batch in controller.batches:
		for mesh in batch.originals:
			check(not str(mesh.get_path()).contains("CityHall/"), "City Hall never merged")
	# Collision shapes stay enabled under the original buildings after swapping.
	for side in controller.get_children():
		for chunk in side.get_children():
			for building in chunk.get_buildings():
				check(building.scene_file_path.begins_with("res://assets/generated-buildings/"), "Only ordinary buildings have proxies")
				for collider in building.find_children("*", "CollisionShape3D", true, false):
					check(not collider.disabled, "Traversal collision remains enabled")
				if building.scene_file_path.begins_with("res://assets/buildings/"):
					var triangles := 0
					for visual in building.find_children("*", "MeshInstance3D", true, false):
						if visual.mesh == null: continue
						for surface in visual.mesh.get_surface_count():
							var arrays: Array = visual.mesh.surface_get_arrays(surface)
							var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
							triangles += (indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
					check(triangles <= 10000, "Complete POI remains within 10,000 triangles: " + str(building.name))
	# Settings/time updates refresh the atlas without rebaking geometry.
	var old_atlas: RefCounted = controller.atlas
	var cycle := main.get_node("SuperCity/DayNightCycle")
	cycle.set_time(23.0)
	root.get_node("CityWindows").brightness = 1.25
	await process_frame
	await process_frame
	check(controller.atlas == old_atlas and controller.prepared, "Lighting changes do not rebuild geometry")
	for i in controller.atlas.sources.size():
		var material: Material = controller.atlas.sources[i]
		if not material is ShaderMaterial: continue
		var entry: Color = controller.atlas._data.get_pixel(i, 3)
		check(is_equal_approx(entry.r, material.get_shader_parameter("emission_energy")), "Night energy matches source")
		check(is_equal_approx(entry.g, 1.25), "Brightness matches source")
		var original: Image = material.get_shader_parameter("room_data").get_meta("hlod_cpu_image")
		var padded: Image = controller.atlas.room_images[i]
		check(original.get_data() == padded.get_region(Rect2i(Vector2i.ZERO, original.get_size())).get_data(), "Seeded room data preserved exactly")
	root.get_node("CityWindows").start_new_game(1776)
	check(not controller.prepared, "Seed changes immediately invalidate the old replacement")
	while not controller.prepared: await process_frame
	check(controller.atlas != old_atlas, "Seed change rebuilds replacement material bindings")
	var first_building := main.get_node("SuperCity/Districts/WestVillage/WestVillage_0028")
	old_atlas = controller.atlas
	first_building.window_emission_energy = 3.0
	while not controller.prepared: await process_frame
	check(controller.atlas != old_atlas, "Per-building intensity overrides update replacement bindings")
	controller.enabled = true
	for batch in controller.batches: batch.set_far(true)
	controller.enabled = false
	for batch in controller.batches:
		check(not batch.far_active, "Disabling HLOD restores sources")
		for i in batch.originals.size(): check(batch.originals[i].visible == batch.original_visibility[i], "Toggle restores original visuals")
	print("HLOD_INVENTORY: ", JSON.stringify(controller.batches.map(func(batch): return batch.inventory())))
	print("HLOD_TEST: %d -> %d surfaces; build %.1f ms; %d failures" % [source_surfaces, merged_surfaces, controller.build_ms, failures])
	main.free()
	quit(1 if failures else 0)
