extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(45.0).timeout.connect(func(): push_error("Traffic box test timed out"); quit(1))
	seed(816)
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
	lod.far_enabled = false # Isolate full/silhouette handoffs.
	lod.population_target = 1
	lod.demote_delay = 0.0
	lod._population_timer = 1000000.0
	var source := -1
	for i in range(lod._straight.size()):
		if not lod._straight[i].is_empty():
			source = i
			break
	assert(source >= 0)
	var lane: Dictionary = manager.lanes[source]
	var car: Vehicle = manager._spawn_vehicle(manager.vehicle_entries[0],source,20.0)
	assert(car != null)
	var full: Dictionary = manager._cars[0]
	var identity: int = full.traffic_id
	var entry: Resource = full.entry
	var gap: float = full.following_gap
	var speed: float = full.intersection_speed
	var original_position := car.global_position
	focus.position = original_position+Vector3.UP*500.0
	camera.position = focus.position
	camera.look_at(original_position,Vector3.FORWARD)
	manager._step(0.0)
	assert(manager._cars.is_empty() and lod.proxies.size() == 1 and lod.demotions == 1)
	var proxy: Dictionary = lod.proxies[0]
	assert(proxy.traffic_id == identity and proxy.entry == entry)
	assert(lod._point(proxy).is_equal_approx(original_position),"Demotion changed position")
	assert(proxy.following_gap == gap and proxy.intersection_speed == speed)
	assert(lod._batches.size() == 1 and lod.get_child_count() == 1,"Expected one batch, no per-car nodes")
	var batch: MultiMeshInstance3D = lod._batches.values()[0]
	assert(batch.multimesh.visible_instance_count == 1)
	assert(batch.multimesh.mesh.get_surface_count() == 1,"Silhouette split the batch into multiple surfaces")
	assert(batch.multimesh.use_colors and batch.multimesh.mesh.surface_get_material(0).vertex_color_use_as_albedo)
	assert(batch.multimesh.custom_aabb.has_volume())
	await process_frame
	# A far obstacle does not stop the visual-only tier.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20,10,20)
	shape.shape = box
	wall.add_child(shape)
	city.add_child(wall)
	wall.position = original_position
	await physics_frame
	await physics_frame
	var previous: float = proxy.progress
	lod._advance(proxy,1.0)
	assert(proxy.progress > previous,"Distant box performed collision stopping")
	# Smooth prediction between 10/5 Hz state updates must not jump when committed.
	proxy["motion_elapsed"] = 0.075
	var predicted: Vector3 = lod._point(proxy)
	assert(predicted.distance_to(lod._raw_point(proxy)) > 0.0)
	lod._flush_motion(proxy)
	assert(lod._point(proxy).distance_to(predicted) < 0.001,"Low-rate motion update jumped visually")
	# But promotion must fail rather than create an overlapping physical vehicle.
	focus.position = lod._point(proxy)+Vector3.UP*2.0
	lod._transition_timer = 0.0
	manager._step(0.0)
	assert(manager._cars.is_empty() and lod.proxies.size() == 1 and lod.blocked_promotions > 0)
	assert(lod.hidden_count == 1,"Blocked close proxy remained non-interactive scenery")
	wall.free()
	await physics_frame
	await physics_frame
	var before_promotion: Vector3 = lod._point(proxy)
	lod._transition_timer = 0.0
	manager._step(0.0)
	assert(lod.proxies.is_empty() and manager._cars.size() == 1)
	full = manager._cars[0]
	assert(full.traffic_id == identity and full.entry == entry)
	assert(full.car.global_position.is_equal_approx(before_promotion),"Promotion changed position")
	assert(full.following_gap == gap and full.intersection_speed == speed)
	# A longer LOD grace period overrides ordinary far-car retirement.
	lod.demote_delay = 5.0
	focus.position = full.car.global_position+Vector3.RIGHT*400.0
	manager._step(2.5)
	assert(manager._cars.size() == 1 and lod.proxies.is_empty(),"Ordinary retirement bypassed the LOD grace period")
	manager._step(3.0)
	assert(lod.proxies.size() == 1 and manager._cars.is_empty())
	lod.demote_delay = 0.0
	# Headroom exhausted by a held vehicle: keep proxy bounded and retry after release/free.
	focus.position += Vector3.UP*500.0
	lod._transition_timer = 0.0
	manager._step(0.0)
	await process_frame
	manager._step(0.0)
	assert(lod.proxies.size() == 1)
	var held: Vehicle = manager._spawn_vehicle(manager.vehicle_entries[1],source ^ 1,20.0)
	assert(held != null)
	held.leave_traffic()
	held.reparent(focus)
	manager.max_vehicles = 1
	focus.position = lod._point(lod.proxies[0])+Vector3.UP*2.0
	lod._transition_timer = 0.0
	manager._step(0.0)
	assert(manager._cars.is_empty() and lod.proxies.size() == 1 and manager.retained_count == 1)
	assert(is_instance_valid(held) and held.get_parent() == focus)
	held.free()
	lod._transition_timer = 0.0
	manager._step(0.0)
	assert(lod.proxies.is_empty() and manager._cars.size() == 1)
	manager.max_vehicles = 12
	# Finish a straight crossing before joining physical traffic rules.
	focus.position += Vector3.UP*500.0
	lod._transition_timer = 0.0
	manager._step(0.0)
	await process_frame
	proxy = lod.proxies[0]
	proxy.connection = lod._straight[source]
	proxy.progress = lane.length
	proxy.crossing_progress = proxy.connection.length*0.5
	before_promotion = lod._point(proxy)
	focus.position = before_promotion+Vector3.UP*20.0
	lod._transition_timer = 0.0
	manager._step(0.0)
	assert(manager._cars.is_empty() and lod.proxies.size() == 1)
	assert(lod._point(proxy).distance_to(before_promotion) < 0.001)
	for tick in 100:
		lod._transition_timer = 0.0
		manager._step(0.1)
		if not manager._cars.is_empty(): break
	assert(lod.proxies.is_empty() and manager._cars.size() == 1)
	full = manager._cars[0]
	assert(full.connection.is_empty() and manager._junction_owners.is_empty())
	focus.position += Vector3.UP*500.0
	lod._transition_timer = 0.0
	manager._step(0.0)
	assert(lod.proxies.size() == 1)
	await process_frame
	# High-speed approach extends promotion range, including a vertical dive.
	focus.position = lod._point(lod.proxies[0])+Vector3.UP*280.0
	focus.velocity = Vector3.DOWN*150.0
	lod._transition_timer = 0.0
	manager._step(0.0)
	assert(lod.proxies.is_empty() and manager._cars.size() == 1,"Dive did not promote early")
	focus.velocity = Vector3.ZERO
	# Seed a bounded distant field at altitude; no full cars should spawn beneath us.
	manager._cars[0].car.free()
	focus.position = original_position+Vector3.UP*500.0
	lod.population_target = 16
	lod.max_boxes = 20
	for tick in range(30):
		manager._timer = 0.0
		lod._population_timer = 0.0
		manager._step(0.25)
	assert(lod.proxies.size() == 16 and manager._cars.is_empty())
	assert(lod._batches.size() < lod.proxies.size())
	var identities: Dictionary = {}
	for record in lod.proxies:
		assert(not identities.has(record.traffic_id))
		identities[record.traffic_id] = true
		assert(manager._flat_distance(lod._point(record),focus.position) <= lod.view_distance+20.0)
	# Relocation retires old records and empty regions; disabling removes all box state.
	lod._population_timer = 1000000.0
	focus.position += Vector3.RIGHT*5000.0
	for tick in range(8): manager._step(1.0)
	assert(lod.proxies.is_empty() and lod._batches.is_empty())
	await process_frame
	assert(lod.get_child_count() == 0)
	focus.position = original_position+Vector3.UP*500.0
	lod._population_timer = 0.0
	manager._step(0.1)
	assert(not lod.proxies.is_empty())
	lod.enabled = false
	manager._step(0.0)
	assert(lod.proxies.is_empty() and lod._batches.is_empty())
	city.free()
	print("PASS: box batches/bounds, far movement, stable handoff, blocked/capped promotion, carried protection, crossing handoff, dive lead, altitude population and cleanup")
	quit()
