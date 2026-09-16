extends SceneTree
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		if failures<25:push_error(message)
func run() -> void:
	create_timer(90).timeout.connect(func():push_error("River mouth check timed out");quit(1))
	var main: Node3D=load("res://scenes/main.tscn").instantiate()
	for child in main.get_children():
		if child.name not in ["SuperCity","MountainRiver"]:child.free()
	var city:=main.get_node("SuperCity")
	for label in ["TrafficManager","CivilianCrowd","Sound","PreviewCamera"]:city.get_node(label).free()
	root.add_child(main);current_scene=main;await process_frame;await physics_frame;await physics_frame
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/mountain-river/mouth/report.json"))
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/layout.json"))
	var graph: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/pedestrians/network.json"))
	check(report.mouth_width>=340,"River mouth widened eastward")
	for p in report.removed_buildings:check(not city.has_node(p),"Removed building and collider: "+p)
	check(graph.source_scene_sha256==FileAccess.get_sha256("res://scenes/super_city.tscn"),"Routes match final scene")
	check(graph.component_sizes.size()==2,"Exactly two connected pedestrian riverbanks")
	check(city.get_node("Waterfront/Water/River").visible,"Urban water visible")
	check(main.has_node("MountainRiver") and not city.has_node("MountainRiver"),"Mountain extension remains Main-only")
	var space:=main.get_world_3d().direct_space_state
	var bridge_samples:=0
	for crossing in layout.crossings:
		var width:=0.0
		for road in layout.roads:
			if road.kind=="street" and road.axis==0 and absf(road.rect[1]+road.rect[3]*.5-crossing)<.01:width=road.rect[3];break
		var row: Array=report.rows[clampi(int((crossing+1000)/10),0,180)]
		for z_offset in [0.31,-width*.5-2.0,width*.5+2.0]:
			for x in range(int(row[1])+1,int(row[2]),9):
				var p:=Vector3(x+.37,4,crossing+z_offset)
				var query:=PhysicsRayQueryParameters3D.create(p,p+Vector3.DOWN*10)
				var hit:=space.intersect_ray(query)
				check(not hit.is_empty() and absf(hit.position.y-.03)<.015,"Bridge deck/sidewalk continuous: "+str(p))
				if not hit.is_empty():
					query.exclude=[hit.rid];var other:=space.intersect_ray(query)
					check(other.is_empty() or other.position.y<hit.position.y-.005,"No coplanar bridge surface overlap: "+str(p))
				bridge_samples+=1
	for x in [150,270,350,450]:
		for z in [795,800.1,805]:
			var p:=Vector3(x,5,z);var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p,p+Vector3.DOWN*45))
			check(not hit.is_empty() and hit.position.y<-5,"Open mouth without leftover land/seawall: "+str(p))
	var network:=city.get_node("CityPedestrianRoutes")
	for district in network.get_children():
		for key in graph.modules:
			if graph.modules[key].district==district.name:district.enabled_routes[key]=true
	network.schedule_rebuild();await process_frame;await process_frame
	var capsule:=CapsuleShape3D.new();capsule.radius=.3;capsule.height=1.6
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1
	var samples:=0;var blockers:={}
	for e in graph.edges:
		var a:=Vector3(graph.points[e[0]][0],.03,graph.points[e[0]][2]);var b:=Vector3(graph.points[e[1]][0],.03,graph.points[e[1]][2])
		var middle:=(a+b)*.5
		if middle.x<80 or middle.x>530 or middle.z < -1000 or middle.z>800:continue
		var row: Array=report.rows[clampi(int((middle.z+1000)/10),0,180)]
		if middle.x<row[1]-30 or middle.x>row[2]+30:continue
		for i in ceili(a.distance_to(b)/3)+1:
			var p:=a.lerp(b,minf(1,i*3/maxf(.01,a.distance_to(b))))
			check(network.contains_body(network.to_global(p),.3,e[0],e[1]),"Runtime NPC footprint accepts authored route: "+str(p))
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.7,p-Vector3.UP*.2))
			if hit.is_empty():hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3(.013,.7,.017),p+Vector3(.013,-.2,.017)))
			check(not hit.is_empty(),"Solid walking surface beneath route: "+str(p))
			query.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*.84)
			for obstacle in space.intersect_shape(query,4):
				var path:=str(city.get_path_to(obstacle.collider))
				if not blockers.has(path):check(false,"NPC collision obstruction at %s: %s"%[p,path]);blockers[path]=true
			samples+=1
	print("River mouth: %d bridge surface probes, %d NPC route samples, %d failures"%[bridge_samples,samples,failures])
	main.free();quit(0 if failures==0 else 1)
