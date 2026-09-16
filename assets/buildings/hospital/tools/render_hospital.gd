extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1400, 1400)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var preview: Node3D = load("res://assets/buildings/hospital/hospital_preview.tscn").instantiate()
	viewport.add_child(preview)
	preview.get_node("Help").hide()
	var camera: Camera3D = preview.get_node("Camera3D")
	var cycle: Node = preview.get_node("DayNightCycle")
	var views: Array = [
		["hospital_day",13.0,Vector3(160,125,235),Vector3(0,64,0)],
		["hospital_night",0.0,Vector3(160,125,235),Vector3(0,64,0)],
		["hospital_courtyard",15.0,Vector3(0,20,110),Vector3(0,46,0)],
		["hospital_rear",13.0,Vector3(-165,155,-210),Vector3(0,63,0)],
		["hospital_crown",15.0,Vector3(25,119,100),Vector3(0,110,-3.4)],
		["hospital_entrance",15.0,Vector3(0,25,88),Vector3(0,6,26)],
		["hospital_canopy",15.0,Vector3(22,20,50),Vector3(0,5,25)],
		["hospital_right_side",15.0,Vector3(130,55,55),Vector3(38,31,7)],
		["hospital_left_side",10.0,Vector3(-130,55,55),Vector3(-38,31,7)]
	]
	for view: Array in views:
		cycle.set_time(view[1])
		camera.position = view[2]
		camera.look_at(view[3])
		for frame in 45:
			await process_frame
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png("res://artifacts/hospital/%s.png" % view[0]) == OK)
		print("Captured " + str(view[0]))
	viewport.free()
	quit()
