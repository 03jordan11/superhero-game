extends SceneTree
const BASE := "res://assets/aircraft/helicopter/"
func _initialize() -> void: call_deferred("render_all")
func render_all() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000,700)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world: Node3D = load(BASE+"helicopter_preview.tscn").instantiate()
	viewport.add_child(world)
	world.get_node("CanvasLayer").hide()
	for node in world.get_children():
		if node is Label3D or node.name in ["RescueSpinning","CoastalStatic","CharcoalSpinning"]: node.hide()
	var heli := world.get_node("ForestStatic") as Node3D
	heli.position = Vector3.ZERO
	var camera := world.get_node("Camera3D") as Camera3D
	camera.set_script(null)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16.5
	camera.position = Vector3(-15,8,-18)
	camera.look_at(Vector3(0,2,1.8))
	var sheet := Image.create(2000,1400,false,Image.FORMAT_RGB8)
	for i in range(4):
		heli.set("livery",i)
		for frame in range(5): await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		image.save_png(BASE+"previews/livery_%d.png"%i)
		sheet.blit_rect(image,Rect2i(0,0,1000,700),Vector2i((i%2)*1000,(i/2)*700))
	sheet.save_png(BASE+"previews/four_liveries.png")
	heli.set("livery",0)
	camera.position = Vector3(-20,6,3)
	camera.look_at(Vector3(0,2,1.8))
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(BASE+"previews/side.png")
	camera.size = 6.0
	camera.position = Vector3(0,3,-14)
	camera.look_at(Vector3(0,2.3,-2.6))
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(BASE+"previews/front.png")
	print("HELICOPTER_RENDER_PASS")
	quit()
