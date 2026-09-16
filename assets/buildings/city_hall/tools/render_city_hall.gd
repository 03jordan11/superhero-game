extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 1200)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var preview: Node3D = load("res://assets/buildings/city_hall/city_hall_preview.tscn").instantiate()
	viewport.add_child(preview)
	preview.get_node("Help").hide()
	var camera: Camera3D = preview.get_node("Camera3D")
	var views: Array = [
		["city_hall_front", Vector3(130, 105, 220), Vector3(0, 25, 0)],
		["city_hall_entrance", Vector3(0, 16, 125), Vector3(0, 28, 0)],
		["city_hall_rear", Vector3(-145, 115, -215), Vector3(0, 25, -10)],
		["city_hall_courtyard", Vector3(38, 40, -83), Vector3(0, 9, -33)],
		["city_hall_furniture", Vector3(12, 11.5, -42), Vector3(5, 8.6, -36)],
		["city_hall_dome_rear", Vector3(25, 60, -68), Vector3(0, 45, 3)],
		["city_hall_retaining_walls", Vector3(110, 60, -140), Vector3(0, 12, -50)],
		["city_hall_steps", Vector3(26, 15, 83), Vector3(0, 4, 54)],
		["city_hall_corner", Vector3(130, 25, 65), Vector3(94, 3, 32)],
		["city_hall_night", Vector3(130, 105, 220), Vector3(0, 25, 0), 0.0],
		["city_hall_courtyard_night", Vector3(38, 40, -83), Vector3(0, 9, -33), 0.0]
	]
	for view: Array in views:
		preview.get_node("DayNightCycle").set_time(view[3] if view.size() > 3 else 13.0)
		camera.position = view[1]
		camera.look_at(view[2])
		for frame in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png("res://artifacts/city_hall/%s.png" % view[0]) == OK)
		print("Captured " + str(view[0]))
	viewport.free()
	quit()
