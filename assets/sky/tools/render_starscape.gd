extends SceneTree
## Actual GPU views of the original pole, all cube seams, and the new galaxy.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/starscape")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600,1000)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var env := WorldEnvironment.new()
	env.name = "Daylight"
	scene.add_child(env)
	for name in ["Sun","Moon"]:
		var light := DirectionalLight3D.new()
		light.name = name
		scene.add_child(light)
	var cycle := Node.new()
	cycle.set_script(load("res://scripts/day_night_cycle.gd"))
	cycle.cycle_running = false
	cycle.cloud_coverage = 0.0
	scene.add_child(cycle)
	cycle.set_time(0)
	var camera := Camera3D.new()
	camera.fov = 80
	scene.add_child(camera)
	camera.make_current()
	# Reference shader passes bypass atmosphere/ground only to inspect all cube faces.
	var inspection := Shader.new()
	inspection.code = "shader_type sky; uniform samplerCube galaxy : filter_linear_mipmap; uniform samplerCube stars : filter_linear_mipmap; void sky(){ COLOR=texture(galaxy,EYEDIR).rgb*1.8+texture(stars,EYEDIR).rgb*1.5; }"
	var material := ShaderMaterial.new()
	material.shader = inspection
	material.set_shader_parameter("galaxy",load("res://assets/sky/custom_galaxy.res"))
	material.set_shader_parameter("stars",load("res://assets/sky/custom_stars.res"))
	var active_sky: Sky = env.environment.sky
	var original: Material = active_sky.sky_material
	active_sky.sky_material = material
	var views: Array = [["galaxy",Vector3(.77,0,-.64)],["north_pole",Vector3.UP],["south_pole",Vector3.DOWN]]
	var directions: Array[Vector3] = [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]
	for i in directions.size():
		for j in range(i+1,directions.size()):
			if is_zero_approx(directions[i].dot(directions[j])):
				views.append(["edge_%d_%d" % [i,j],(directions[i]+directions[j]).normalized()])
	for view in views:
		var direction: Vector3 = view[1].normalized()
		camera.look_at(direction,Vector3.FORWARD if absf(direction.y)>.99 else Vector3.UP)
		await capture(viewport,view[0])
	active_sky.sky_material = original
	var rotation: Basis = cycle._material.get_shader_parameter("star_rotation")
	camera.look_at(rotation.inverse()*Vector3.UP)
	await capture(viewport,"former_pinch_in_game_shader")
	viewport.free()
	quit()

func capture(viewport: SubViewport, label: String) -> void:
	for frame in 16: await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png("res://artifacts/starscape/%s.png" % label) == OK)
	print("Captured ",label)
