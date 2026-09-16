extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var viewport := SubViewport.new(); viewport.size = Vector2i(1000,1000); viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var world := Node3D.new(); viewport.add_child(world)
	var environment := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color("c7ccd0")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("d1d9e1"); env.ambient_light_energy = .45
	environment.environment = env; world.add_child(environment)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-38,-32,0); sun.shadow_enabled = true; world.add_child(sun)
	var asset: Node3D = load("res://assets/generated-buildings/commercial/commercial_skyscraper_01.tscn").instantiate()
	asset.follow_day_night_cycle = false; world.add_child(asset)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.far = 1000; world.add_child(camera); camera.current = true
	var shots := [
		["day",155,Vector3(100,93,-160),Vector3(0,65,0)],
		["entrance",29,Vector3(18,12,-50),Vector3(0,5,0)],
		["roof",32,Vector3(25,158,-30),Vector3(0,132,0)],
		["night",155,Vector3(100,93,-160),Vector3(0,65,0)]
	]
	for shot in shots:
		camera.size = shot[1]; camera.position = shot[2]; camera.look_at(shot[3])
		if shot[0] == "night":
			asset.apply_night(1); env.background_color = Color("141e30"); env.ambient_light_energy = .18; sun.light_energy = .12
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://artifacts/skyscraper_01/" + shot[0] + ".png")
	print("SKYSCRAPER_01_RENDERED: day, entrance, roof, night")
	quit()
