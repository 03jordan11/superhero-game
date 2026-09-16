extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(40.0).timeout.connect(func(): push_error("Population settings test timed out"); quit(1))
	var settings := root.get_node("GameSettings")
	# UI callbacks exercise persistence without touching the player's preferences.
	var test_file := OS.get_environment("TEMP").path_join("superhero_settings_test_%d.cfg" % OS.get_process_id())
	settings._settings_file = test_file
	settings.set_population_settings(2,2,2,false)
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	var panel: Node = menu.get_node("Center/SettingsMenu").population_settings
	var full_scene = load("res://scenes/main.tscn").instantiate()
	var pause: Node = full_scene.get_node("PauseMenu")
	full_scene.remove_child(pause)
	full_scene.free()
	root.add_child(pause)
	var pause_panel: Node = pause.get_node("Center/SettingsMenu").population_settings
	assert(panel.get_node("CrowdRow/Dropdown").item_count == 3)
	assert(pause_panel.get_node("DistanceRow/Dropdown").selected == 2)
	if "--capture" in OS.get_cmdline_user_args():
		menu._on_settings_pressed()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("population_settings_main.png"))
	paused = true
	var dropdown: OptionButton = pause_panel.get_node("CrowdRow/Dropdown")
	dropdown.select(0)
	dropdown.item_selected.emit(0)
	assert(settings.crowd_density == 0 and panel.get_node("CrowdRow/Dropdown").selected == 0)
	assert(FileAccess.file_exists(test_file), "Menu selection was not saved")
	if "--capture" in OS.get_cmdline_user_args():
		menu.hide()
		pause.pause_game()
		pause._on_settings_pressed()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("population_settings_pause.png"))
	paused = false
	settings.set_population_settings(2,2,2,false)
	settings.load_settings(test_file)
	assert(settings.crowd_density == 0 and settings.vehicle_density == 2)
	var config := ConfigFile.new()
	config.set_value("population","crowd_density","wrong type")
	config.set_value("population","vehicle_density",50)
	assert(config.save(test_file) == OK)
	settings.load_settings(test_file)
	assert(settings.crowd_density == 2 and settings.vehicle_density == 2 and settings.population_view_distance == 2)
	DirAccess.remove_absolute(test_file)
	settings.load_settings(test_file)
	assert(settings.crowd_density == 2)

	var city := Node3D.new()
	root.add_child(city)
	current_scene = city
	var focus := CharacterBody3D.new()
	focus.name = "Focus"
	city.add_child(focus)
	focus.position = Vector3(-1280,2,-800)
	var camera := Camera3D.new()
	city.add_child(camera)
	camera.position = focus.position+Vector3.UP*15.0
	camera.look_at(camera.position+Vector3.RIGHT*50.0)
	camera.make_current()
	var manager = load("res://scenes/vehicles/traffic_manager.tscn").instantiate()
	manager.focus_path = ^"../Focus"
	manager.population_target = 20
	manager.max_vehicles = 30
	manager.max_vehicles_per_lane = 4
	city.add_child(manager)
	manager.set_physics_process(false)
	var lod = manager.get_node("DistantTraffic")
	var crowd = load("res://scenes/npcs/civilian_crowd.tscn").instantiate()
	crowd.max_civilians = 100
	crowd.ground_radius = 220.0
	city.add_child(crowd)
	var capsules = crowd.get_node("CapsuleLOD")
	# All nine density/distance combinations, repeatedly, must derive from scene overrides.
	for cycle in range(3):
		for density in range(3):
			for distance in range(3):
				settings.set_population_settings(density,density,distance,false)
				var factor: float = settings.vehicle_scale()
				assert(manager.population_target == roundi(20*factor) and manager.max_vehicles == roundi(30*factor))
				assert(crowd.population_target == roundi(40*factor) and crowd.max_civilians == roundi(100*factor))
				assert(is_equal_approx(crowd.civilians_per_100m,4.0*factor))
				assert(crowd.max_civilians_per_cell == roundi(6*factor))
				assert(lod.view_distance <= 900 and lod.far_view_distance >= lod.view_distance)
				assert(lod.population_target <= roundi(24*factor) and lod.far_population_target <= roundi(16*factor))
				assert(capsules.view_distance >= crowd.ground_radius and capsules.view_distance <= 350)
				assert(lod.promote_distance == 150 and lod.demote_distance == 220)
				assert(lod.far_promote_distance == 800 and lod.far_demote_distance == 1000)
				assert(capsules.promote_distance == 90 and crowd.minimum_npc_spacing == 1.6)
	assert(manager.population_target == 20 and lod.population_target == 24 and lod.far_population_target == 16)
	assert(lod.max_boxes == 24 and lod.far_max_proxies == 16 and capsules.max_capsules == 120)
	settings.set_population_settings(0,2,2,false)
	assert(manager.population_target == 20 and crowd.population_target == 20, "Crowd setting changed traffic")
	settings.set_population_settings(2,0,0,false)
	assert(crowd.population_target == 40 and manager.population_target == 10)
	assert(lod.view_distance == 540 and lod.far_view_distance == 1080)
	assert(lod.population_target == 4 and lod.far_population_target == 3)
	assert(capsules.view_distance == 220)
	# Scenes entering after a selection also use it, with their own baselines.
	var next_manager = load("res://scenes/vehicles/traffic_manager.tscn").instantiate()
	next_manager.population_target = 30
	city.add_child(next_manager)
	next_manager.set_physics_process(false)
	assert(next_manager.population_target == 15)
	next_manager.free()
	settings.set_population_settings(2,2,2,false)

	# Existing offscreen full vehicles shrink gradually even with visual LOD enabled.
	manager._focus = focus
	manager._update_spawn_direction()
	manager._timer = 1000000.0
	lod._population_timer = 1000000.0
	for i in range(8): manager._spawn_near_focus()
	assert(manager._cars.size() >= 3)
	var survivor: Vehicle = manager._cars[0].car
	survivor.leave_traffic()
	manager.max_vehicles = 1
	var previous: int = manager._cars.size()
	manager._step(0.0)
	# One released record plus at most one ambient vehicle removed this tick.
	assert(manager._cars.size() >= previous-2)
	for i in range(20):
		await physics_frame
		manager._step(0.0)
	assert(manager._cars.is_empty(), "Lower cap did not retire surplus offscreen traffic")
	assert(is_instance_valid(survivor), "Budget trimming removed a released vehicle")
	city.free()
	menu.free()
	pause.free()
	settings.set_population_settings(2,2,2,false)
	await process_frame
	print("PASS: shared paused/main UI, persistence/invalid defaults, independent presets, all combinations without drift, late scene tuning, bounded live traffic trimming and released vehicle protection")
	quit()
