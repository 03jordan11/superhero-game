extends SceneTree
const BASE := "res://assets/waterfront/cargo_ship/"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1500,1050)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var preview: Node3D = load(BASE + "cargo_ship_preview.tscn").instantiate()
	viewport.add_child(preview)
	preview.get_node("Help").hide()
	var camera: Camera3D = preview.get_node("Camera3D")
	for i in 4:
		preview.set_variant(i)
		await capture(viewport, "variant_%s" % (i+1))
	preview.set_variant(0)
	preview.set_night(true)
	await capture(viewport, "night_starboard")
	camera.position = Vector3(21,23,42)
	camera.look_at(Vector3(11.9,19.8,54.2))
	await capture(viewport, "light_detail")
	camera.position = Vector3(-95,33,-155)
	camera.look_at(Vector3(0,12,0))
	await capture(viewport, "night_port")
	camera.position = Vector3(90,42,160)
	camera.look_at(Vector3(0,12,0))
	await capture(viewport, "night_stern")
	preview.get_node("Ship").navigation_mode = 1
	await capture(viewport, "night_anchor")
	preview.set_night(false)
	camera.position = Vector3(27,23,-17)
	camera.look_at(Vector3(0,10,0))
	await capture(viewport, "cargo_detail")
	viewport.free()
	print("CARGO_SHIP_RENDER_COMPLETE")
	quit()

func capture(viewport: SubViewport, label: String) -> void:
	for frame in 15:await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png("res://artifacts/cargo_ship/" + label + ".png") == OK)
	print("Captured cargo ship: ",label)
