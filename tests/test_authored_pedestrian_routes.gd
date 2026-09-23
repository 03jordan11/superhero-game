extends SceneTree
const CAPSULE = preload("res://scripts/npc-scripts/capsule_civilian.gd")
const JOURNEY = preload("res://scripts/npc-scripts/pedestrian_journey.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	var city: Node3D = main.get_node("SuperCity")
	main.remove_child(city); main.free()
	for name in ["CivilianCrowd","TrafficManager","NightLights","CityOcclusion","RooftopEquipment"]:
		var child = city.get_node_or_null(name)
		if child: child.free()
	city.get_node("CityLife").set_script(null)
	root.add_child(city)
	await physics_frame
	await physics_frame
	var graph = city.get_node("CityPedestrianRoutes")
	assert(graph.enabled_module_ids.size()==graph.inventory.modules.size(),"Saved city has disabled/unregistered routes")
	var space := city.get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = 0.55; shape.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape; query.collision_mask = 1
	var failures := []
	var checked := 0
	var slope_edge: Array = []
	for edge in graph.inventory.edges:
		var a: Vector3 = graph.point_world(edge[0]); var b: Vector3 = graph.point_world(edge[1])
		if a.distance_to(b)>7 and absf(a.y-b.y)>0.6 and a.z < -300 and a.z > -340: slope_edge = edge
		var steps := maxi(1,ceili(a.distance_to(b)/2.0))
		for i in range(steps+1):
			var p := a.lerp(b,float(i)/steps)
			var problem := ""
			if not graph.contains_body(p,0.55,edge[0],edge[1]): problem = "outside walking corridor"
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.2,p-Vector3.UP*0.2,1))
			if hit.is_empty():
				# A ray exactly on two imported triangle edges can miss both.
				# Verify support within 2 cm of the center of the 55 cm foot radius.
				for offset in [Vector3(0.02,0,0),Vector3(-0.02,0,0),Vector3(0,0,0.02),Vector3(0,0,-0.02)]:
					hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(p+offset+Vector3.UP*0.2,p+offset-Vector3.UP*0.2,1))
					if not hit.is_empty(): break
				if hit.is_empty(): problem = "no ground support"
			query.transform = Transform3D(Basis.IDENTITY,p+Vector3.UP*0.96)
			var hits := space.intersect_shape(query,1)
			if not hits.is_empty(): problem = str(city.get_path_to(hits[0].collider))
			if not problem.is_empty(): failures.append({"edge":edge,"point":str(p),"problem":problem})
			checked += 1
	FileAccess.open("res://artifacts/authored_pedestrian_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"probes":checked,"failures":failures},"\t"))
	print("PEDESTRIAN AUDIT: ",checked," probes; ",failures.size()," failures")
	if not failures.is_empty():
		push_error("Route validation failed; see artifacts/authored_pedestrian_validation.json")
		quit(1); return
	for spec in [[100.0,500.0,760.0,12.0],[2.0,322.0,-320.0,16.0],[116.0,274.0,-960.0,12.0]]:
		var connected_sides := 0
		for side in [-1,1]:
			var allowed := {}; var start := -1; var end := -1
			var min_x := INF; var max_x := -INF
			for id in graph.astar.get_point_ids():
				var p: Vector3 = graph.astar.get_point_position(id)
				if p.x<spec[0] or p.x>spec[1] or absf(p.z-(spec[2]+side*spec[3]))>1.6: continue
				allowed[id] = true
				if p.x<min_x: start = id; min_x = p.x
				if p.x>max_x: end = id; max_x = p.x
			# Polygon-center routes can finish inside a terminal pavement polygon;
			# require coverage within 20 m of each model end, with no middle gap.
			if start<0 or min_x>spec[0]+20 or max_x<spec[1]-20: continue
			var seen := {start:true}; var pending := [start]
			while not pending.is_empty():
				var id: int = pending.pop_back()
				for neighbor in graph.astar.get_point_connections(id):
					if allowed.has(neighbor) and not seen.has(neighbor): seen[neighbor] = true; pending.append(neighbor)
			if seen.has(end): connected_sides += 1
		print("BRIDGE at z=",spec[2],": ",connected_sides," continuous walkway sides")
		if connected_sides == 0: push_error("A river bridge has no end-to-end walkway"); quit(1); return
	assert(not slope_edge.is_empty(),"Missing sloping bridge edge")
	assert(not graph.contains_body(city.to_global(Vector3(162,0.03,-336)),0.55,slope_edge[0],slope_edge[1]),"Bridge route incorrectly accepts the water below")
	var a: Vector3 = graph.point_world(slope_edge[0]); var b: Vector3 = graph.point_world(slope_edge[1])
	var capsule = CAPSULE.new()
	city.add_child(capsule); capsule.set_process(false)
	capsule.graph = graph
	capsule._path = PackedInt64Array([slope_edge[0],slope_edge[1]])
	capsule._waypoints = PackedVector3Array([a,b]); capsule._path_index = 1
	capsule.global_position = a
	var horizontal := Vector2(a.x-b.x,a.z-b.z).length()
	capsule._profiled_process(horizontal/capsule.walk_speed*0.5)
	assert(capsule.global_position.distance_to(a.lerp(b,0.5))<0.02,"Capsule ignored bridge height")
	var clone = CAPSULE.new(); city.add_child(clone); clone.set_process(false)
	JOURNEY.restore(clone,JOURNEY.capture(capsule))
	assert(clone.global_position == capsule.global_position,"Slope handoff changed height")
	clone.free(); capsule.free()
	for reverse in [false,true]:
		var from_id: int = slope_edge[1] if reverse else slope_edge[0]
		var to_id: int = slope_edge[0] if reverse else slope_edge[1]
		var walker = load("res://scenes/npcs/routed_civilian.tscn").instantiate()
		walker.route_graph_path = graph.get_path(); walker.start_point_id = from_id
		walker.begin_ambient_route(graph,from_id,to_id)
		walker.position = walker.spawn_position(0.1)+Vector3.UP*0.01
		city.add_child(walker)
		var before: Vector3 = walker.global_position
		for frame in range(90): await physics_frame
		print("SLOPE WALK ",reverse,": ",walker.global_position-before," / ",walker.route_status)
		assert(walker.global_position.distance_to(before)>2.0,"Full civilian stopped on slope")
		assert(absf(walker.global_position.y-before.y)>0.08,"Full civilian did not follow slope")
		assert(walker.global_basis.y.dot(Vector3.UP)>0.999,"Walker tilted on slope")
		walker.free()
	city.free()
	print("PASS: authored clearance/support, river bridges, capsule grade and handoff, full civilian uphill/downhill movement")
	quit()
