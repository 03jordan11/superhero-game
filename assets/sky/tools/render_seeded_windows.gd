extends SceneTree
## Reproducible Forward+ city comparison, including the live debug controls.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var output := "res://artifacts/window_colors/"
	DirAccess.make_dir_recursive_absolute(output)
	var library := root.get_node("CityWindows")
	library.restore_data({"seed": 123456, "use_district_percentages": false})
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 1000)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var city: Node3D = load("res://scenes/super_city.tscn").instantiate()
	for label in ["TrafficManager", "CivilianCrowd", "Sound", "PreviewCamera"]:
		var node := city.get_node_or_null(NodePath(label))
		if node != null: node.free()
	viewport.add_child(city)
	var clock = city.get_node("DayNightCycle")
	clock.cycle_running = false
	clock.set_time(0)
	var camera := Camera3D.new()
	camera.far = 6000
	camera.fov = 68
	viewport.add_child(camera)
	camera.make_current()
	var views := [
		["skyline", Vector3(950,190,1100), Vector3(-220,130,380)],
		["offices", Vector3(-1250,100,620), Vector3(-1320,72,360)]
	]
	for view in views:
		camera.position = view[1]
		camera.look_at(view[2])
		city.get_node("NightLights")._select_lights()
		for percentage in [0,25,50,75,100]:
			library.lit_window_percent = percentage
			for frame in 8: await process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(output + view[0] + "_%03d.png" % percentage)
	clock.set_time(12)
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output + "offices_day.png")
	clock.set_time(0)
	library.lit_window_percent = 50
	var layer := CanvasLayer.new()
	viewport.add_child(layer)
	layer.add_child(load("res://scripts/ui-scripts/window_lighting_controls.gd").new())
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output + "debug_controls.png")
	print("WINDOW_COLORS_RENDER_COMPLETE")
	viewport.free()
	quit()
