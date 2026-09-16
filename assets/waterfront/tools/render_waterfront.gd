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
	var camera:=Camera3D.new()
	camera.far=14000
	camera.fov=64
	viewport.add_child(camera)
	camera.make_current()
	var views: Array=[
		["river_day",14.0,Vector3(170,34,-250),Vector3(235,0,100)],
		["river_night",0.0,Vector3(154,5,-258),Vector3(209,1,-100)],
		["harbor_day",15.0,Vector3(1355,165,1335),Vector3(1120,7,984)],
		["harbor_boats",15.0,Vector3(1092,12,1064),Vector3(1145,2,1112)],
		["harbor_night",0.0,Vector3(1085,5,1070),Vector3(1150,2,1135)],
		["waterfront_overview",15.0,Vector3(1320,255,895),Vector3(620,12,1790)],
		["tug_closeup",15.0,Vector3(1107,7,1000),Vector3(1091,1,980)],
		["dock_sunset",18.0,Vector3(1066,4,1080),Vector3(1000,10,1550)],
		["prison_island",15.0,Vector3(850,360,1840),Vector3(300,24,2390)],
		["prison_gate",16.0,Vector3(300,20,2240),Vector3(300,29,2360)],
		["prison_night",0.0,Vector3(565,115,2210),Vector3(305,25,2400)],
		["ocean_night",0.0,Vector3(1133,4,1195),Vector3(300,30,2400)]
	]
	for entry in views:
		var selected:=OS.get_cmdline_user_args()
		if not selected.is_empty() and str(entry[0]) not in selected: continue
		cycle.set_time(entry[1])
		camera.position=entry[2]
		camera.look_at(entry[3])
		city.get_node("NightLights")._select_lights()
		for frame in 35: await process_frame
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png("res://artifacts/waterfront/%s.png"%entry[0])==OK)
		print("Captured "+str(entry[0]))
	viewport.free()
	quit()
