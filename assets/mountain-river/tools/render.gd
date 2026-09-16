extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var viewport := SubViewport.new(); viewport.size=Vector2i(1500,1000);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var main: Node3D=load("res://scenes/main.tscn").instantiate()
	for child in main.get_children():
		if child.name not in ["SuperCity","MountainRiver"]:child.free()
	var city := main.get_node("SuperCity")
	for label in ["TrafficManager","CivilianCrowd","CityPedestrianRoutes","Sound","PreviewCamera"]:city.get_node(label).free()
	viewport.add_child(main)
	city.get_node("DayNightCycle").cycle_running=false;city.get_node("DayNightCycle").set_time(12)
	var camera:=Camera3D.new();camera.far=12000;camera.fov=60;viewport.add_child(camera);camera.make_current()
	for shot in [
		["river_overview",Vector3(2200,2200,300),Vector3(100,120,-2200)],
		["city_banks",Vector3(440,160,-160),Vector3(190,0,-470)],
		["mountain_channel",Vector3(1000,600,-2100),Vector3(310,90,-2780)],
		["north_join",Vector3(560,220,-810),Vector3(150,0,-1150)]]:
		camera.position=shot[1];camera.look_at(shot[2])
		for i in 24:await process_frame
		await RenderingServer.frame_post_draw
		var file: String="res://artifacts/river_mountains/"+shot[0]+".png"
		viewport.get_texture().get_image().save_png(file);print("Rendered ",file)
	viewport.free();quit()
