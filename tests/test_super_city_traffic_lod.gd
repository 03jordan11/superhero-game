extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(60.0).timeout.connect(func(): push_error("City traffic LOD test timed out"); quit(1))
	seed(817)
	var city = load("res://scenes/super_city.tscn").instantiate()
	city.get_node("CivilianCrowd").free()
	city.get_node("CityPedestrianRoutes").free()
	var focus := CharacterBody3D.new()
	focus.name = "LODTestFocus"
	city.add_child(focus)
	focus.position = Vector3(-1100,420,-650)
	var camera := Camera3D.new()
	city.add_child(camera)
	camera.position = focus.position
	var manager = city.get_node("TrafficManager")
	manager.focus_path = ^"../LODTestFocus"
	root.add_child(city)
	current_scene = city
	manager.set_physics_process(false)
	await process_frame
	camera.look_at(Vector3(-1000,0,-1000))
	camera.make_current()
	var lod = manager.get_node("DistantTraffic")
	var blockers = city.get_node("CityOcclusion")
	assert(blockers.building_count > 0 and blockers.triangle_count > 0)
	assert(blockers.get_child_count() == 10)
	for blocker in blockers.get_children(): assert(blocker.occluder is ArrayOccluder3D)
	lod.far_enabled = "--tier3" in OS.get_cmdline_user_args()
	for tick in range(50):
		await physics_frame
		manager._step(0.25)
	assert(lod.proxies.size() >= 15 and lod.proxies.size() <= lod._proxy_limit())
	assert(manager.active_count == 0,"High flight kept spawning full physics vehicles below")
	var farthest := 0.0
	var visible := 0
	for record in lod.proxies:
		farthest = maxf(farthest,manager._flat_distance(lod._point(record),focus.position))
		if lod._visible(record): visible += 1
	assert(farthest > 350.0 and visible > 0)
	if lod.far_enabled:
		assert(farthest > 1000.0 and lod.rectangle_count > 0 and lod.silhouette_count > 0)
	print("City LOD: ",lod.proxies.size()," boxes in ",lod._batches.size()," regions, ",visible," visible; farthest ",roundi(farthest)," m")
	print("Tier counts: ",lod.silhouette_count," silhouettes, ",lod.rectangle_count," rectangles")
	lod.occlusion_culling_enabled = false
	for batch in lod._batches.values(): assert(batch.ignore_occlusion_culling)
	lod.occlusion_culling_enabled = true
	for batch in lod._batches.values(): assert(not batch.ignore_occlusion_culling)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var capture_path := OS.get_environment("TEMP").path_join("traffic_box_lod_preview.png")
		root.get_texture().get_image().save_png(capture_path)
		print("Rendered preview: ",capture_path)
		# Close inspection of the distant representation without promoting it.
		var detail_point: Vector3 = city.to_global(lod._point(lod.proxies[0]))
		camera.position = detail_point+Vector3(12,8,15)
		camera.look_at(detail_point+Vector3.UP)
		await RenderingServer.frame_post_draw
		var detail_path := OS.get_environment("TEMP").path_join("traffic_lod_silhouette_preview.png")
		root.get_texture().get_image().save_png(detail_path)
		print("Silhouette preview: ",detail_path)
		if lod.far_enabled:
			for record in lod.proxies:
				if not record.get("flat",false): continue
				var rectangle_point: Vector3 = city.to_global(lod._point(record))
				camera.position = rectangle_point+Vector3(12,12,15)
				camera.look_at(rectangle_point)
				await RenderingServer.frame_post_draw
				var rectangle_path := OS.get_environment("TEMP").path_join("traffic_lod_rectangle_preview.png")
				root.get_texture().get_image().save_png(rectangle_path)
				print("Rectangle preview: ",rectangle_path)
				break
	# Descend toward one box, using the same real city collisions as gameplay.
	var candidate: Dictionary = lod.proxies[0]
	var identity: int = candidate.traffic_id
	focus.position = lod._point(candidate)+Vector3.UP*10.0
	manager._timer = 1000000.0
	lod._transition_timer = 0.0
	manager._step(0.0)
	var found := false
	for record in manager._cars:
		if record.traffic_id == identity: found = true
	assert(found,"A box on a real road failed to promote after descent")
	manager.traffic_enabled = false
	for tick in range(20):
		manager._step(0.1)
		await process_frame
	assert(manager.active_count == 0 and lod.proxies.is_empty() and lod._batches.is_empty())
	city.free()
	print("PASS: SuperCity altitude coverage beyond civilian LOD, real-road promotion and tier shutdown")
	quit()
