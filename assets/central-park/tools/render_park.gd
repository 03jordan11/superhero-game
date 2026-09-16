extends SceneTree
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/central_park")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600,1000)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var city: Node3D = load("res://scenes/super_city.tscn").instantiate()
	for label in ["TrafficManager","CivilianCrowd","Sound","PreviewCamera"]: city.get_node(label).free()
	viewport.add_child(city)
	var cycle = city.get_node("DayNightCycle")
	cycle.cycle_running = false
	var park := city.get_node("Landmarks/CentralPark") as Node3D
	var camera := Camera3D.new()
	camera.far = 5000.0
	camera.fov = 66.0
	viewport.add_child(camera)
	camera.make_current()
	var views := [
		["path_bridge_west",13.0,Vector3(-78,30,39),Vector3(-60,1,18)],
		["path_bridge_east",13.0,Vector3(155,30,40),Vector3(132,1,18)],
		["path_north_junction",13.0,Vector3(-82,35,-226),Vector3(-70,1,-263)],
		["path_lake_junction",13.0,Vector3(11,35,79),Vector3(32,1,56)],
		["path_southwest_gate",13.0,Vector3(-215,20,318),Vector3(-228,.15,299)],
		["path_house_entry",13.0,Vector3(177,23,179),Vector3(155,.15,169)],
		["park_overview",12.0,Vector3(-70,590,420),Vector3(0,0,-20)],
		["lake_day",15.0,Vector3(160,24,94),Vector3(20,3,-60)],
		["bridge_railings",13.0,Vector3(-38,5.8,18),Vector3(12,2.5,18)],
		["lakeside_night",0.0,Vector3(157,4.8,-54),Vector3(55,4,-60)],
		["hermit_house",0.0,Vector3(-169,2.7,-161),Vector3(-171,2.2,-186)],
		["firefly_grove",0.0,Vector3(-131,2.6,-26),Vector3(-126,2.0,-49)],
		["meadow_day",13.0,Vector3(-55,65,282),Vector3(-25,0.35,170)],
		["meadow_ground",15.0,Vector3(-40,2.3,222),Vector3(-25,1.5,123)],
		["forest_trail",17.0,Vector3(-216,4,-99),Vector3(-173,3,-161)],
		["night_overview",0.0,Vector3(-70,590,420),Vector3(0,0,-20)]
	]
	var lantern: Node3D = park.get_node("Lanterns").get_child(0)
	for region_name in ["CityLife","CoastalRegion"]:
		var regions := city.find_children(region_name,"Node3D",true,false)
		if regions.is_empty(): continue
		var trees := preload("res://assets/trees/tools/tree_instances.gd").trees(regions[0])
		if trees.is_empty(): continue
		var tree: Node3D = trees[0]
		views.append(["editable_trees_"+region_name.to_snake_case(),13.0,park.to_local(tree.global_position+Vector3(45,35,60)),park.to_local(tree.global_position+Vector3(0,10,0))])
	views.append(["lantern_detail",0.0,lantern.position+Vector3(4,4,6),lantern.position+Vector3(0,2.7,0)])
	var bushes: MultiMeshInstance3D = park.get_node("Foliage/Undergrowth")
	var bush_position := bushes.multimesh.get_instance_transform(0).origin
	views.append(["bush_detail",13.0,bush_position+Vector3(4,2.8,4),bush_position+Vector3(.6,.6,0)])
	for entry in views:
		cycle.set_time(entry[1])
		camera.position = park.to_global(entry[2])
		camera.look_at(park.to_global(entry[3]))
		city.get_node("NightLights")._select_lights()
		for frame in 35: await process_frame
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png("res://artifacts/central_park/%s.png"%entry[0])==OK)
		print("Captured "+str(entry[0]))
	viewport.free()
	quit()
