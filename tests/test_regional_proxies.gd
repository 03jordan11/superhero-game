extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func geometry(node: Node) -> Dictionary:
	var data := {"triangles":0,"surfaces":0,"label_triangle_upper_bound":0}
	if node is MeshInstance3D and node.mesh != null:
		data.triangles += node.mesh.get_faces().size()/3
		data.surfaces += node.mesh.get_surface_count()
	if node is MultiMeshInstance3D and node.multimesh != null:
		data.triangles += node.multimesh.mesh.get_faces().size()/3*node.multimesh.instance_count
		data.surfaces += node.multimesh.mesh.get_surface_count()
	# Two triangles for each glyph plus its outline; count whitespace too, conservatively.
	if node is Label3D: data.label_triangle_upper_bound += node.text.length()*4
	for child in node.get_children():
		var sub := geometry(child)
		for key in data: data[key] += sub[key]
	return data
func run() -> void:
	create_timer(90).timeout.connect(func(): push_error("Regional proxy test timeout"); quit(1))
	paused = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	for monitor in world.get_node("PerformanceMonitors").get_children(): monitor.enabled=false
	root.add_child(world)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	var controller = world.get_node("SuperCity/RegionalProxies")
	for frame in 6: await process_frame
	check(controller.prepared and controller.prepared_chunks==5,"All five proxies prepared during loading")
	controller.set_process(false)
	var colliders := {}
	var budget := {}
	for path in ["Waterfront/PrisonIsland","CoastalRegion/Airport","Sidewalks/CargoShip"]:
		var source: Node3D = world.get_node("SuperCity/"+path)
		budget[path]=geometry(source)
		check(budget[path].triangles+budget[path].label_triangle_upper_bound<=10000,"Complete POI, including aircraft, grounds, props and text, stays under 10k: "+path)
		for shape in source.find_children("*","CollisionShape3D",true,false): colliders[shape]=[shape.disabled,shape.global_transform,shape.shape]
	controller.force_lod=2
	controller.update_visibility()
	for entry in controller.entries:
		check(entry.proxy.mesh.get_surface_count()==1,"One material surface per proxy")
		check(entry.proxy.is_visible_in_tree(),"Distant replacement visible")
		for source in entry.roots: check(not source.visible,"Original geometry hidden")
		check(entry.proxy.find_children("*","CollisionObject3D",true,false).is_empty(),"Proxies add no physics")
		var box: AABB=entry.source.global_transform*entry.bounds
		controller.force_lod=0
		camera.position=box.get_center()
		controller.update_visibility()
		check(not entry.far,"Original returns within bounds")
		camera.position=Vector3(box.end.x+351,box.get_center().y,box.get_center().z)
		controller.update_visibility()
		check(entry.far,"Proxy beyond nearest edge +350m")
		camera.position.x=box.end.x+325
		controller.update_visibility()
		check(entry.far,"Hysteresis retains proxy")
		camera.position.x=box.end.x+299
		controller.update_visibility()
		check(not entry.far,"Original inside300m")
		controller.force_lod=2
		controller.update_visibility()
	var coast=world.get_node("SuperCity/CoastalRegion")
	coast.elapsed=150
	coast.update_air_traffic(0)
	var ship=world.get_node("SuperCity/Sidewalks/CargoShip")
	var saved_pose: Transform3D=ship.transform
	ship.position+=Vector3(100,0,100)
	ship.rotate_y(0.3)
	controller.update_visibility()
	for entry in controller.entries:
		check(entry.proxy.global_transform.is_equal_approx(entry.source.global_transform),"Moving proxies follow current translation and rotation")
	ship.transform=saved_pose
	coast.elapsed=0
	coast.update_air_traffic(0)
	var cycle=world.get_node("SuperCity/DayNightCycle")
	cycle.set_time(0)
	controller._refresh_lighting()
	for entry in controller.entries:
		for light in entry.source.find_children("*","Light3D",true,false):
			if entry.source.name!=&"Airport" or not str(entry.source.get_path_to(light)).begins_with("AirTraffic/"):
				check(not light.is_visible_in_tree(),"Night updates cannot unhide replaced lighting")
	for shape in colliders:
		check(shape.disabled==colliders[shape][0] and shape.shape==colliders[shape][2],"Collision state and resource preserved")
	controller.enabled=false
	for light in coast._lights:
		check(light.is_visible_in_tree()==(light.light_energy>0.001),"Night airport lights restore after disabling proxies")
	for entry in controller.entries:
		check(not entry.proxy.visible,"Disabling restores originals")
		for i in entry.roots.size(): check(entry.roots[i].visible==entry.flags[i],"Original flags restored")
	FileAccess.open("res://artifacts/regional_proxies/budget.json",FileAccess.WRITE).store_string(JSON.stringify(budget,"\t"))
	print("REGIONAL_BUDGET ",JSON.stringify(budget))
	print("Regional proxies: ",failures," failures")
	world.free()
	camera.free()
	quit(1 if failures else 0)
