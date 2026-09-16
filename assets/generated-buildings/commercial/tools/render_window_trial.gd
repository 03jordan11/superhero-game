extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var viewport:=SubViewport.new(); viewport.size=Vector2i(1000,1100); viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var review: Node3D=load("res://scenes/tests/window_emission_trial.tscn").instantiate(); viewport.add_child(review)
	var camera: Camera3D=review.get_node("Camera3D"); camera.fov=50
	for frame in 30: await process_frame
	var sheet:=Image.create(2000,1100,false,Image.FORMAT_RGB8)
	for trial in [false,true]:
		review.set_trial(trial)
		for frame in 12: await process_frame
		await RenderingServer.frame_post_draw
		var image:=viewport.get_texture().get_image(); image.convert(Image.FORMAT_RGB8)
		var label:="trial" if trial else "original"
		image.save_png("res://artifacts/window_trial/"+label+".png")
		sheet.blit_rect(image,Rect2i(0,0,1000,1100),Vector2i(1000 if trial else 0,0))
	sheet.save_png("res://artifacts/window_trial/comparison.png")
	viewport.free(); print("WINDOW_TRIAL_RENDERED: original and trial, identical current environment"); quit()
