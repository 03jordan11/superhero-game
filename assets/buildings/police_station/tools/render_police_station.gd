extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1400, 1400)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var preview: Node3D = load("res://assets/buildings/police_station/police_station_preview.tscn").instantiate()
	viewport.add_child(preview)
	preview.get_node("Help").hide()
	var views: Array = [
		["front", Vector3(44, 28, 65), Vector3(0, 12, 0), 13.0],
		["entrance", Vector3(23, 10, 40), Vector3(5, 4, 13), 13.0],
		["rear", Vector3(-42, 26, -57), Vector3(0, 11, 0), 13.0],
		["night", Vector3(44, 28, 65), Vector3(0, 12, 0), 0.0]]
	var camera: Camera3D = preview.get_node("Camera3D")
	for view: Array in views:
		preview.get_node("DayNightCycle").set_time(view[3])
		camera.position = view[1]
		camera.look_at(view[2])
		for frame in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png("res://artifacts/police_station/police_station_%s.png" % view[0]) == OK)
		print("Captured police station %s" % view[0])
	viewport.free()
	quit()
