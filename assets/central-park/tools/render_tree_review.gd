extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var species := OS.get_cmdline_user_args()[0]
	assert(species in ["birch","pine","willow"])
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600,1000)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("b0c4cf")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .65
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-35,0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color("708366")
	plane.material = grass
	ground.mesh = plane
	ground.position.y = -.025
	stage.add_child(ground)
	for entry in [["ORIGINAL " + species.to_upper(),-9.0,"res://artifacts/central_park/%s_before_final.res" % species],
		["SIMPLIFIED " + species.to_upper(),9.0,"res://assets/central-park/meshes/tree_%s.res" % species]]:
		var tree := MeshInstance3D.new()
		tree.mesh = load(entry[2]) as Mesh
		tree.position.x = entry[1]
		stage.add_child(tree)
		var label := Label3D.new()
		label.text = "%s  /  %d TRIANGLES" % [entry[0],tree.mesh.get_faces().size()/3]
		label.font_size = 52
		label.pixel_size = .01
		label.position = Vector3(entry[1],18.5,0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color("22333a")
		label.outline_modulate = Color("e0e5df")
		label.no_depth_test = true
		stage.add_child(label)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 40
	camera.position = Vector3(0,18,44)
	stage.add_child(camera)
	camera.look_at(Vector3(0,8.5,0))
	camera.make_current()
	for frame in 20: await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png("res://artifacts/central_park/%s_comparison.png" % species) == OK)
	print("Captured %s comparison" % species)
	viewport.free()
	quit()

