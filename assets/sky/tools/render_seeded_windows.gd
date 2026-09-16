extends SceneTree
## Capture original and seeded windows from identical real-city cameras.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var output := "res://artifacts/seeded_windows/"
	DirAccess.make_dir_recursive_absolute(output)
	var library := root.get_node("CityWindows")
	library.set_city_seed(123456)
	var viewport := SubViewport.new(); viewport.size=Vector2i(1600,1000)
	viewport.own_world_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var city: Node3D=load("res://scenes/super_city.tscn").instantiate()
	for label in ["TrafficManager","CivilianCrowd","Sound","PreviewCamera"]:
		var node:=city.get_node_or_null(NodePath(label))
		if node!=null: node.free()
	viewport.add_child(city)
	var clock=city.get_node("DayNightCycle"); clock.cycle_running=false; clock.set_time(0)
	var camera:=Camera3D.new(); camera.far=6000; camera.fov=68
	viewport.add_child(camera); camera.make_current()
	var towers: Array[Node] = []
	for node in city.find_children("*","StaticBody3D",true,false):
		if node.get("seeded_window_patterns") == true: towers.append(node)
	for frame in 30: await process_frame
	var views := [
		["skyline", Vector3(950,190,1100), Vector3(-220,130,380)],
		["offices", Vector3(-1250,100,620), Vector3(-1320,72,360)]
	]
	for view in views:
		camera.position=view[1]; camera.look_at(view[2])
		city.get_node("NightLights")._select_lights()
		for seeded in [false,true]:
			for tower in towers:
				if seeded:
					tower._apply_window_pattern()
				else:
					var mesh: Mesh=tower._original_mesh
					var visual: MeshInstance3D=tower.get_node("MeshInstance3D")
					for surface in mesh.get_surface_count():
						var material:=visual.get_active_material(surface) as StandardMaterial3D
						if material!=null and material.emission_enabled:
							material.emission_texture=mesh.surface_get_material(surface).emission_texture
							material.emission_on_uv2=false
			for frame in 20: await process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(output+view[0]+("_seeded" if seeded else "_original")+".png")
			print("SEEDED_CAPTURE ",view[0]," seeded=",seeded)
	print("SEEDED_RENDER_COMPLETE: ",towers.size()," commercial placements")
	viewport.free(); quit()
