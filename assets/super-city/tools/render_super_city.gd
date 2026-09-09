extends SceneTree
## Offline views of the actual scene. No player scripts or generation run in previews.
const OUT = "res://assets/super-city/"
var viewport: SubViewport
var city: Node3D
var camera: Camera3D

func _initialize() -> void:
	call_deferred("render_views")

func render_views() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1800,1200)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	city = load("res://scenes/super_city.tscn").instantiate()
	for district in city.get_node("Districts").get_children():
		for building in district.get_children():
			building.get_node("MeshInstance3D").visibility_range_end = 0
	viewport.add_child(city)
	var env: Environment = city.get_node("Daylight").environment
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ambient_light_energy = 0.7
	camera = Camera3D.new()
	camera.far = 12000
	camera.near = 2
	viewport.add_child(camera)
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2200
	camera.position = Vector3(0,4000,0)
	camera.look_at(Vector3.ZERO,Vector3.FORWARD)
	# Screenshot-only 2D labels, never baked into the city or converted to meshes.
	var labels: Array[Label] = []
	for entry in [["WEST VILLAGE",Vector3(-1130,0,-50)],["NORTH HEIGHTS",Vector3(-380,0,-740)],["PARKSIDE",Vector3(-685,0,-80)],["CENTRAL PARK",Vector3(-290,0,0)],["CIVIC CENTER",Vector3(-820,0,510)],["FINANCIAL QUARTER",Vector3(30,0,530)],["EASTBANK",Vector3(760,0,-250)],["FOUNDRY WARD",Vector3(1200,0,180)],["DOCKLANDS",Vector3(1180,0,560)],["PIER",Vector3(1130,0,900)],["BAY",Vector3(0,0,915)]]:
		var label = Label.new()
		label.text = entry[0]
		label.position = camera.unproject_position(entry[1])+Vector2(-60,-12)
		label.add_theme_font_size_override("font_size",18)
		label.add_theme_color_override("font_color",Color.WHITE)
		label.add_theme_color_override("font_outline_color",Color("20292d"))
		label.add_theme_constant_override("outline_size",5)
		viewport.add_child(label)
		labels.append(label)
	await capture("district_map")
	for label in labels:
		label.free()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 62
	for entry in [["bay_skyline",Vector3(1300,740,1800),Vector3(-60,50,50)],["park_and_downtown",Vector3(-900,290,560),Vector3(-110,65,60)],["industrial_pier",Vector3(1400,230,1050),Vector3(850,20,530)],["street_and_sidewalk",Vector3(-551,2.5,364),Vector3(-550,14,530)],["river_crossing",Vector3(410,120,275),Vector3(230,0,110)]]:
		camera.near = 0.2 if entry[0] == "street_and_sidewalk" else 2
		camera.position = entry[1]
		camera.look_at(entry[2])
		await capture(entry[0])
	print("Rendered district map and five SuperCity views.")
	quit()

func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img = viewport.get_texture().get_image()
	assert(img.save_png(OUT+"previews/"+label+".png") == OK)
