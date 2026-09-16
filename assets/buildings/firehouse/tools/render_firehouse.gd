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
	var preview: Node3D = load("res://assets/buildings/firehouse/firehouse_preview.tscn").instantiate()
	viewport.add_child(preview)
	preview.get_node("Help").hide()
	var camera: Camera3D = preview.get_node("Camera3D")
	var views := [
		["firehouse_front", Vector3(42, 27, 62), Vector3(0, 11, 0), 13.0],
		["firehouse_bays", Vector3(10, 8, 42), Vector3(2, 7, 9), 13.0],
		["firehouse_tower", Vector3(-38, 26, 35), Vector3(-12, 18, 4), 13.0],
		["firehouse_rear", Vector3(-38, 28, -53), Vector3(0, 10, 0), 13.0],
		["firehouse_rear_door", Vector3(5, 3, -19), Vector3(2, 1.5, -11), 13.0],
		["firehouse_night", Vector3(42, 27, 62), Vector3(0, 11, 0), 0.0]]
	for view: Array in views:
		preview.get_node("DayNightCycle").set_time(view[3])
		camera.position = view[1]
		camera.look_at(view[2])
		for frame in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png("res://artifacts/firehouse/%s.png" % view[0]) == OK)
		print("Captured " + str(view[0]))
	viewport.free()
	quit()
