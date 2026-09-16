extends SceneTree
## Run with a real renderer: --path <project> --script res://assets/sky/render_sky_previews.gd
## Saves actual city/sky renders; does not change or save the scene.

func _initialize() -> void:
	render_views.call_deferred()

func render_views() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/sky")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 1000)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var city: Node3D = load("res://scenes/super_city.tscn").instantiate()
	for node_name in ["TrafficManager", "CivilianCrowd", "Sound", "PreviewCamera"]:
		var node := city.get_node_or_null(node_name)
		if node != null: node.free()
	viewport.add_child(city)
	var cycle = city.get_node("DayNightCycle")
	cycle.cycle_running = false
	var camera := Camera3D.new()
	camera.far = 12000.0
	camera.fov = 80.0
	viewport.add_child(camera)
	camera.make_current()
	camera.position = Vector3(900, 260, 1100)
	camera.look_at(Vector3(-300, 480, -600))
	# Allow noise generation / imports / shaders to settle before capturing.
	for frame in 45: await process_frame
	for entry in [["dawn", 6.0], ["day", 12.0], ["sunset", 18.0], ["blue_hour", 19.0], ["midnight", 0.0], ["late_night", 3.0]]:
		cycle.set_time(entry[1])
		await capture(viewport, entry[0])
	cycle.set_time(0.0)
	var moon_direction: Vector3 = cycle._material.get_shader_parameter("moon_direction")
	camera.look_at(camera.position + moon_direction * 100.0)
	await capture(viewport, "moon")
	camera.position = Vector3(-551, 2.5, 364)
	camera.look_at(Vector3(-550, 14, 530))
	await capture(viewport, "night_street")
	viewport.free()
	quit()

func capture(viewport: SubViewport, label: String) -> void:
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image().save_png("res://artifacts/sky/%s.png" % label)
	assert(result == OK, "Could not save sky preview: " + label)
	print("Captured " + label)
