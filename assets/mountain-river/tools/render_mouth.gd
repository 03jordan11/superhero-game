extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var viewport:=SubViewport.new();viewport.size=Vector2i(1500,1000);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var main: Node3D=load("res://scenes/main.tscn").instantiate()
	for child in main.get_children():
		if child.name not in ["SuperCity","MountainRiver"]:child.free()
	var city:=main.get_node("SuperCity")
	for label in ["TrafficManager","CivilianCrowd","CityPedestrianRoutes","Sound","PreviewCamera"]:city.get_node(label).free()
	viewport.add_child(main);city.get_node("DayNightCycle").cycle_running=false;city.get_node("DayNightCycle").set_time(12)
	var camera:=Camera3D.new();camera.far=12000;camera.fov=60;viewport.add_child(camera);camera.make_current()
	for shot in [["mouth",Vector3(500,500,1300),Vector3(300,0,460)],["bridge",Vector3(530,80,860),Vector3(350,0,735)],["curved_walks",Vector3(465,150,0),Vector3(220,0,-330)]]:
		camera.position=shot[1];camera.look_at(shot[2])
		for i in 24:await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://artifacts/river_mouth/"+shot[0]+".png");print("Rendered ",shot[0])
	viewport.free();quit()
