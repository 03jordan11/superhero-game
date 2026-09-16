extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(45.0).timeout.connect(func(): push_error("Far traffic test timed out"); quit(1))
	seed(818)
	var city := Node3D.new()
	root.add_child(city)
	current_scene = city
	var focus := CharacterBody3D.new()
	focus.name = "Focus"
	city.add_child(focus)
	var camera := Camera3D.new()
	city.add_child(camera)
	camera.make_current()
	var manager = load("res://scenes/vehicles/traffic_manager.tscn").instantiate()
	manager.focus_path = ^"../Focus"
	manager.prefer_offscreen_spawns = false
	city.add_child(manager)
	manager.set_physics_process(false)
	manager._timer = 1000000.0
	var lod = manager.get_node("DistantTraffic")
	lod._population_timer = 1000000.0
	lod.demote_delay = 0.0
	var source := -1
	for i in range(lod._straight.size()):
		if not lod._straight[i].is_empty():
			source = i
			break
	assert(source >= 0)
	var car: Vehicle = manager._spawn_vehicle(manager.vehicle_entries[0],source,20.0)
	assert(car != null)
	var original := car.global_position
	var id: int = manager._cars[0].traffic_id
	var entry: Resource = manager._cars[0].entry
	var gap: float = manager._cars[0].following_gap
	focus.position = original+Vector3.UP*500.0
	manager._step(0.0)
	assert(lod.silhouette_count == 1 and lod.rectangle_count == 0)
	await process_frame
	var record: Dictionary = lod.proxies[0]
	focus.position = original+Vector3.UP*1100.0
	manager._step(0.0)
	assert(lod.proxies.size() == 1 and lod.rectangle_count == 1 and lod.silhouette_count == 0)
	assert(manager._cars.is_empty(),"Rectangle acquired a physical representation")
	assert(record.traffic_id == id and record.entry == entry and record.following_gap == gap)
	assert(lod._point(record).is_equal_approx(original),"Mesh transition moved the car")
	assert(lod._batches.size() == 1)
	var batch: MultiMeshInstance3D = lod._batches.values()[0]
	assert(batch.multimesh.mesh is PlaneMesh and batch.multimesh.mesh.get_faces().size() == 6)
	assert(batch.multimesh.use_colors and batch.multimesh.mesh.material == lod._mesh.surface_get_material(0))
	assert(batch.multimesh.custom_aabb.has_volume())
	var demotions: int = lod.flat_demotions
	for distance in [950.0,850.0,999.0,801.0]:
		focus.position = original+Vector3.UP*distance
		manager._step(0.0)
		assert(record.flat and lod.flat_demotions == demotions,"Tier flickered inside its hysteresis band")
	focus.position = original+Vector3.UP*750.0
	manager._step(0.0)
	assert(not record.flat and lod.silhouette_count == 1 and lod.flat_promotions == 1)
	assert(lod._point(record).is_equal_approx(original))
	# Rectangles retain straight-junction progress rather than restarting their route.
	focus.position = original+Vector3.UP*1100.0
	manager._step(0.0)
	var lane: Dictionary = manager.lanes[source]
	record.progress = lane.length-1.0
	record.speed = (manager.minimum_speed+manager.maximum_speed)*0.5
	lod._advance(record,0.5)
	assert(not record.connection.is_empty() and record.flat)
	var crossing_position: Vector3 = lod._point(record)
	focus.position = crossing_position+Vector3.UP*750.0
	manager._step(0.0)
	assert(not record.flat and not record.connection.is_empty())
	assert(lod._point(record).is_equal_approx(crossing_position))
	# A dive preserves position, then finishes the crossing before physical promotion.
	focus.position = crossing_position+Vector3.UP*1100.0
	manager._step(0.0)
	assert(record.flat)
	focus.position = crossing_position+Vector3.UP*20.0
	lod._transition_timer = 0.0
	manager._step(0.0)
	assert(lod.proxies.size() == 1 and manager._cars.is_empty())
	assert(lod._point(record).distance_to(crossing_position) < 0.001)
	for tick in 100:
		lod._transition_timer = 0.0
		manager._step(0.1)
		if not manager._cars.is_empty(): break
	assert(lod.proxies.is_empty() and manager._cars.size() == 1)
	var full: Dictionary = manager._cars[0]
	assert(full.traffic_id == id and full.entry == entry and full.following_gap == gap)
	assert(full.connection.is_empty())
	full.car.free()
	manager._step(0.0)
	# Separate radial populations keep the existing near field populated.
	focus.position = original+Vector3.UP*420.0
	camera.position = focus.position
	camera.look_at(original,Vector3.FORWARD)
	lod.population_target = 12
	lod.max_boxes = 16
	lod.far_population_target = 18
	lod.far_max_proxies = 24
	for tick in range(60):
		lod._population_timer = 0.0
		manager._step(0.25)
		assert(lod.proxies.size() <= 40)
	var counts: Vector2i = lod._population_counts()
	assert(counts.x >= 10 and counts.y >= 14,"Outer population displaced inner coverage")
	assert(lod.rectangle_count > 0 and lod.silhouette_count > 0)
	var ids: Dictionary = {}
	for proxy in lod.proxies:
		assert(not ids.has(proxy.traffic_id))
		ids[proxy.traffic_id] = true
	# Repeat distant relocations to catch lingering records and empty batches.
	lod._population_timer = 1000000.0
	for pass_index in range(3):
		focus.position += Vector3.RIGHT*6000.0
		for tick in range(12): manager._step(1.0)
		assert(lod.proxies.is_empty() and lod._batches.is_empty())
		await process_frame
		assert(lod.get_child_count() == 0)
		focus.position = original+Vector3.UP*420.0
		for tick in range(10):
			lod._population_timer = 0.0
			manager._step(0.25)
		lod._population_timer = 1000000.0
		assert(lod.proxies.size() <= 40)
	lod.far_enabled = false
	manager._step(0.0)
	assert(lod.rectangle_count == 0 and lod._coverage_radius() == lod.view_distance and lod._proxy_limit() == lod.max_boxes)
	lod.enabled = false
	manager._step(0.0)
	assert(lod.proxies.is_empty() and lod._batches.is_empty())
	city.free()
	print("PASS: tier-3 geometry/batching, identity/color/position, hysteresis, crossing continuity, direct physical promotion, independent coverage/caps and repeated cleanup")
	quit()
