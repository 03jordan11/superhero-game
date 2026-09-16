extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1600,1000)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var city: Node3D=load("res://scenes/super_city.tscn").instantiate()
	for label in ["TrafficManager","CivilianCrowd","Sound","PreviewCamera"]: city.get_node(label).free()
	viewport.add_child(city)
	var cycle=city.get_node("DayNightCycle")
	cycle.cycle_running=false
	city.get_node("CityLife").blimp_ad_audio_enabled=false
	var region=city.get_node("CoastalRegion")
	region.set_physics_process(false)
	var camera:=Camera3D.new()
	camera.far=60000
	camera.fov=65
	viewport.add_child(camera)
	camera.make_current()
	var views: Array=[
		["airport_overview",14.0,20.0,Vector3(-4250,430,950),Vector3(-3390,10,-30)],
		["airport_night",0.0,20.0,Vector3(-4300,135,650),Vector3(-3400,5,50)],
		["terminal",15.0,70.0,Vector3(-2950,55,-520),Vector3(-3260,16,-220)],
		["landing",15.0,16.0,Vector3(-4480,25,260),Vector3(-4310,14,200)],
		["takeoff",17.0,180.0,Vector3(-3060,45,340),Vector3(-3000,17,200)],
		["gate",15.0,76.0,Vector3(-2970,22,-22),Vector3(-3050,10,-100)],
		["coast_west",15.0,0.0,Vector3(-1800,650,2300),Vector3(-3800,5,500)],
		["coast_east",15.0,0.0,Vector3(2700,850,3400),Vector3(2800,0,-1200)],
		["city_horizon",15.0,0.0,Vector3(100,680,1000),Vector3(-1000,200,-2300)],
		["beach",17.0,0.0,Vector3(3400,12,LAND_Z),Vector3(5700,0,1600)]
	]
	var selected:=OS.get_cmdline_user_args()
	for entry in views:
		if not selected.is_empty() and str(entry[0]) not in selected: continue
		cycle.set_time(entry[1])
		region.elapsed=entry[2]
		region.update_air_traffic(0)
		camera.position=entry[3]
		camera.look_at(entry[4])
		city.get_node("NightLights")._select_lights()
		for frame in 35: await process_frame
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png("res://artifacts/coastal_airport/%s.png"%entry[0])==OK)
		print("Captured "+str(entry[0]))
	viewport.free()
	quit()
const LAND_Z:=1600.0
