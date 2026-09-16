extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for bank_name: String in ["bank1", "bank2"]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1400, 1400)
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var preview: Node3D = load("res://assets/buildings/%s/%s_preview.tscn" % [bank_name, bank_name]).instantiate()
		viewport.add_child(preview)
		preview.get_node("Help").hide()
		var views: Array
		if bank_name == "bank1":
			views = [
				["front", Vector3(44, 28, 65), Vector3(0, 12, 0), 13.0],
				["entrance", Vector3(15, 13, 46), Vector3(0, 12, 13), 13.0],
				["rear", Vector3(-42, 27, -58), Vector3(0, 11, 0), 13.0],
				["night", Vector3(44, 28, 65), Vector3(0, 12, 0), 0.0]]
		else:
			views = [
				["front", Vector3(130, 95, 185), Vector3(0, 61, 0), 13.0],
				["entrance", Vector3(32, 14, 52), Vector3(0, 6, 7), 13.0],
				["rear", Vector3(-125, 125, -170), Vector3(0, 61, 0), 13.0],
				["crown", Vector3(48, 145, 62), Vector3(0, 108, 0), 13.0],
				["night", Vector3(130, 95, 185), Vector3(0, 61, 0), 0.0]]
		var camera: Camera3D = preview.get_node("Camera3D")
		for view: Array in views:
			preview.get_node("DayNightCycle").set_time(view[3])
			camera.position = view[1]
			camera.look_at(view[2])
			for frame in 20:
				await process_frame
			await RenderingServer.frame_post_draw
			assert(viewport.get_texture().get_image().save_png("res://artifacts/%s/%s_%s.png" % [bank_name, bank_name, view[0]]) == OK)
			print("Captured %s %s" % [bank_name, view[0]])
		viewport.free()
	quit()
