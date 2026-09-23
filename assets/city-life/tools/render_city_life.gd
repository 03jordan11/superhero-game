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
	var life=city.get_node("CityLife")
	life.set_process(false)
	life.blimp_ad_audio_enabled=false
	life.elapsed=0
	life.update_animation(0)
	var camera:=Camera3D.new()
	camera.far=14000
	camera.fov=64
	viewport.add_child(camera)
	camera.make_current()
	var views: Array=[
		["sandlot",14.0,Vector3(-1004,62,182),Vector3(-1051,0,116)],
		["sandlot_night",0.0,Vector3(-1020,18,151),Vector3(-1051,2,101)],
		["blimp",17.0,life.blimp.to_global(Vector3(118,30,100)),life.blimp.position],
		["blimp_night",0.0,life.blimp.to_global(Vector3(105,-12,86)),life.blimp.position],
		["highway",14.0,Vector3(-670,70,-1130),Vector3(-1020,25,-1860)],
		["mountain_pass",15.0,Vector3(-1035,54,-2420),Vector3(-1100,45,-2780)],
		["highway_night",0.0,Vector3(-1092,18,-2560),Vector3(-1100,28,-2800)]
	]
	var selected:=OS.get_cmdline_user_args()
	for entry in views:
		if not selected.is_empty() and str(entry[0]) not in selected: continue
		cycle.set_time(entry[1])
		camera.position=entry[2]
		camera.look_at(entry[3])
		city.get_node("NightLights")._select_lights()
		for frame in 35: await process_frame
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png("res://artifacts/city_life/%s.png"%entry[0])==OK)
		print("Captured "+str(entry[0]))
	viewport.free()
	quit()
