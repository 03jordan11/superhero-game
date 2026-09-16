extends SceneTree
## Offline contact sheet and street-scale detail rendering; no gameplay changes.
const OUT = "res://assets/generated-buildings/industrial/"
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var current: Node3D

func _initialize() -> void:
	call_deferred("render_all")

func render_all() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/industrial_batch/night")
	root.get_node("CityWindows").set_city_seed(12345)
	viewport = SubViewport.new()
	viewport.size = Vector2i(360,480)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	var environment = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("151e30")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d1d9e1")
	env.ambient_light_energy = 0.18
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	world.add_child(environment)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38,-32,0)
	light.light_energy = 0.15
	light.shadow_enabled = true
	world.add_child(light)
	var floor_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(10000,10000)
	floor_mesh.mesh = plane
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("848b8b")
	mat.roughness = 1
	floor_mesh.material_override = mat
	world.add_child(floor_mesh)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 2000
	world.add_child(camera)
	camera.current = true
	var heading = Label.new()
	heading.position = Vector2(15,12)
	heading.add_theme_font_size_override("font_size",16)
	heading.add_theme_color_override("font_color",Color("dce4ee"))
	viewport.add_child(heading)
	var dimensions = Label.new()
	dimensions.position = Vector2(15,450)
	dimensions.add_theme_font_size_override("font_size",14)
	dimensions.add_theme_color_override("font_color",Color("dce4ee"))
	viewport.add_child(dimensions)
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(OUT+"manifest.json"))
	var sheet = Image.create(1800,960,false,Image.FORMAT_RGB8)
	for i in range(1,11):
		if current != null:
			current.free()
		current = load(OUT+"industrial_building_%02d.tscn" % i).instantiate()
		current.follow_day_night_cycle=false
		world.add_child(current)
		current.apply_night(1)
		var size: Vector3 = current.get_node("MeshInstance3D").mesh.get_aabb().size
		heading.text = "Industrial %02d" % i
		dimensions.text = "%.0f x %.0f m  /  %.1f m tall" % [size.x,size.z,size.y]
		camera.size = maxf(size.y * 1.4, (size.x + size.z) * 0.95)
		var target = Vector3(0,size.y*0.48,0)
		camera.position = target + Vector3(150,80,-220)
		camera.look_at(target)
		for frame in 25: await process_frame
		await RenderingServer.frame_post_draw
		var img = viewport.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(img,Rect2i(0,0,360,480),Vector2i(((i-1)%5)*360,int((i-1)/5)*480))
		if i in [1,3,4,7,8,9]:
			img.save_png("res://artifacts/industrial_batch/night/building_%02d.png" % i)
	sheet.save_png("res://artifacts/industrial_batch/night/contact_sheet.png")
	# Last building's lobby, at a human-scale camera height.
	heading.hide()
	dimensions.hide()
	viewport.size = Vector2i(1200,800)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 65
	camera.position = Vector3(16,2,-32)
	camera.look_at(Vector3(0,5,-5))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://artifacts/industrial_batch/night/street_detail.png")
	print("Rendered contact sheet and street detail.")
	quit()

