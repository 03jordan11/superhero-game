extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1500,1000)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var city: Node3D=load("res://scenes/super_city.tscn").instantiate()
	for name in ["TrafficManager","CivilianCrowd","CityPedestrianRoutes","Sound","PreviewCamera"]:city.get_node(name).free()
	viewport.add_child(city)
	city.get_node("DayNightCycle").cycle_running=false
	city.get_node("DayNightCycle").set_time(12.0)
	var camera:=Camera3D.new()
	camera.far=5000
	camera.fov=65
	viewport.add_child(camera)
	camera.make_current()
	for shot in [
		["civic",Vector3(-250,215,-155),Vector3(-300,12,-402)],
		["hospital",Vector3(-330,180,208),Vector3(-292,36,390)],
		["bank1",Vector3(-139,25,480),Vector3(-139,9,512)],
		["bank2",Vector3(109,22,641),Vector3(109,25,603)],
		["firehouse",Vector3(-616,20,482),Vector3(-616,9,507)]]:
		camera.position=shot[1]
		camera.look_at(shot[2])
		for i in 20: await process_frame
		await RenderingServer.frame_post_draw
		var path: String="res://artifacts/poi_integration/"+shot[0]+".png"
		viewport.get_texture().get_image().save_png(path)
		print("Rendered ",path)
	viewport.free()
	quit()
