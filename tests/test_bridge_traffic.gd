extends SceneTree
const LANES := preload("res://scripts/traffic/traffic_lanes.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	seed(910)
	var entry_id := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--entry="): entry_id = int(arg.trim_prefix("--entry="))
	var city: Node3D = load("res://scenes/super_city.tscn").instantiate()
	for key in ["CivilianCrowd","CityPedestrianRoutes","NightLights","CityOcclusion","RooftopEquipment"]:
		var node := city.get_node_or_null(key)
		if node: node.free()
	city.get_node("CityLife").set_script(null)
	var manager = city.get_node("TrafficManager")
	manager.population_target = 0
	manager.prefer_offscreen_spawns = false
	manager.get_node("DistantTraffic").enabled = false
	root.add_child(city)
	manager.set_physics_process(false)
	await physics_frame
	await physics_frame
	var selected: Array[int] = []
	for id in manager.lanes.size():
		var lane: Dictionary = manager.lanes[id]
		if lane.axis == 0 and lane.road.position.x < 160 and lane.road.end.x > 275 and (is_equal_approx(lane.start.z+3.0,760.0) or is_equal_approx(lane.start.z-3.0,760.0) or is_equal_approx(absf(lane.start.z+320.0),3.0) or is_equal_approx(absf(lane.start.z+960.0),3.0)):
			selected.append(id)
	assert(selected.size() == 6,"Expected both directions on all three bridges")
	for id in selected:
		var car: Vehicle = manager._spawn_vehicle(manager.vehicle_entries[entry_id],id,6.0)
		assert(car != null,"Bridge approach spawn failed")
		manager._cars[-1].cruise = 20.0
	var passed := {}
	for tick in 2400:
		await physics_frame
		for record in manager._cars:
			if passed.has(record.lane): continue
			manager._drive(record,1.0/30.0)
			var expected := LANES.vehicle_point(manager.lanes[record.lane],record.progress,record.half_length)
			expected.y += record.height-manager.road_height
			assert(record.car.position.distance_to(expected) < 0.001,"Bridge vehicle lost deck height")
			assert(manager._lod._raw_point(record).distance_to(expected) < 0.001,"LOD deck height mismatch")
			if record.progress >= record.stop_at-1.0:
				passed[record.lane] = true
		if passed.size() == selected.size(): break
	for record in manager._cars:
		print("BRIDGE_DRIVE: lane=%d progress=%.2f target=%.2f speed=%.2f point=%s" % [record.lane,record.progress,record.stop_at,record.speed,record.car.position])
	assert(passed.size() == selected.size(),"Vehicle stopped on a bridge")
	for record in manager._cars: record.car.free()
	manager._cars.clear()
	manager._owned.clear()
	var focus := Node3D.new()
	city.add_child(focus)
	manager._focus = focus
	var lod = manager._lod
	lod.enabled = true
	lod.demote_delay = 0.0
	for id in selected:
		var progress: float = manager.lanes[id].length*0.5
		var car: Vehicle = manager._spawn_vehicle(manager.vehicle_entries[entry_id],id,progress)
		assert(car != null,"Bridge crest spawn failed")
		var before := car.transform
		focus.position = car.position+Vector3.UP*500.0
		lod._demotions_left = 1
		assert(lod.try_demote(manager._cars[0],0.0),"Bridge vehicle did not demote")
		var proxy: Dictionary = lod.proxies[0]
		assert(lod._point(proxy).distance_to(before.origin) < 0.001)
		car.free()
		manager._cars.clear()
		manager._owned.clear()
		await physics_frame
		car = manager._spawn_vehicle(proxy.entry,id,progress,proxy)
		assert(car != null and car.transform.is_equal_approx(before),"Bridge promotion changed pose")
		car.free()
		manager._cars.clear()
		manager._owned.clear()
		lod.proxies.clear()
		await physics_frame
	city.free()
	print("PASS: vehicle entry %d traverses all bridges both ways; crest spawn and full/proxy handoffs preserve pose" % entry_id)
	quit()
