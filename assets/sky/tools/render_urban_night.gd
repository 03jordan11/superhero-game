extends SceneTree
## Reproducible real-city views. Pass -- --before for the baseline folder.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var output:="res://artifacts/urban_night/"+("before/" if "--before" in OS.get_cmdline_user_args() else "after/")
	DirAccess.make_dir_recursive_absolute(output)
	var viewport:=SubViewport.new(); viewport.size=Vector2i(1600,1000)
	viewport.own_world_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var city: Node3D=load("res://scenes/super_city.tscn").instantiate()
	for label in ["TrafficManager","CivilianCrowd","Sound","PreviewCamera"]:
		var node:=city.get_node_or_null(NodePath(label))
		if node!=null: node.free()
	viewport.add_child(city)
	var clock=city.get_node("DayNightCycle"); clock.cycle_running=false; clock.set_time(0)
	var camera:=Camera3D.new(); camera.far=6000; camera.fov=68
	viewport.add_child(camera); camera.make_current()
	for frame in 35: await process_frame
	var views:=[
		["skyline",Vector3(950,190,1100),Vector3(-220,130,380)],
		["offices",Vector3(-1250,100,620),Vector3(-1320,72,360)],
		["entrance",Vector3(-1380,2.7,318),Vector3(-1393.85,5,350)],
		["intersection",Vector3(-1281,5,454),Vector3(-1350,3,445)],
		["sky",Vector3(0,260,1000),Vector3(0,700,2000)]
	]
	for view in views:
		camera.position=view[1]; camera.look_at(view[2])
		city.get_node("NightLights")._select_lights()
		for frame in 20: await process_frame
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png(output+view[0]+".png")==OK)
		print("URBAN_CAPTURE ",output,view[0])
	viewport.free(); quit()
