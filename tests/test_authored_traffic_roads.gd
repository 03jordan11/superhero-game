extends SceneTree
const LANES := preload("res://scripts/traffic/traffic_lanes.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	var city := main.get_node("SuperCity") as Node3D
	main.remove_child(city)
	main.free()
	for key in ["TrafficManager","CivilianCrowd","CityPedestrianRoutes","NightLights","CityOcclusion","RooftopEquipment"]:
		var node := city.get_node_or_null(key)
		if node: node.free()
	city.get_node("CityLife").set_script(null)
	root.add_child(city)
	await physics_frame
	await physics_frame
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/traffic/layout.json"))
	var lanes := LANES.build(data,3.0,0.03,true)
	# Check both directions: every lane must be reachable from the network and
	# able to return to it, rather than belonging to an isolated traffic loop.
	var reverse := {}
	for id in lanes.size(): reverse[id] = []
	for id in lanes.size():
		for connection in lanes[id].connections: reverse[connection.to].append(id)
	for backwards in [false,true]:
		var seen := {0:true}
		var pending := [0]
		while not pending.is_empty():
			var id: int = pending.pop_back()
			var neighbors: Array = reverse[id] if backwards else lanes[id].connections.map(func(c): return c.to)
			for next: int in neighbors:
				if not seen.has(next):
					seen[next] = true
					pending.append(next)
		assert(seen.size() == lanes.size(),"Traffic network has an isolated component")
	var roads := []
	for road in data.roads:
		if road.kind == "street": roads.append(road)
	var space := city.get_world_3d().direct_space_state
	var unsupported := []
	var blocked := []
	var ends := []
	var probes := 0
	var connections := 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8,1.2,4.2)
	for id in lanes.size():
		var lane: Dictionary = lanes[id]
		if lane.connections.is_empty(): ends.append({"lane":id,"end":str(lane.end),"sources":roads[id/2].sources})
		for step in range(0,int(ceil(lane.length/4.0))+1):
			var progress := minf(step*4.0,lane.length)
			var p := LANES.point(lane,progress)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.3,p-Vector3.UP*0.3,1))
			if hit.is_empty() or absf(hit.position.y-p.y) > 0.08:
				unsupported.append({"lane":id,"point":str(p),"sources":roads[id/2].sources,"hit":str(hit.get("position","none"))})
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform = Transform3D(Basis.looking_at(LANES.direction(lane,progress),Vector3.UP,true),p+Vector3.UP*0.85)
			query.collision_mask = 1
			var collisions := space.intersect_shape(query,1)
			if not collisions.is_empty():
				blocked.append({"lane":id,"point":str(p),"collider":str(city.get_path_to(collisions[0].collider)),"sources":roads[id/2].sources})
			probes += 1
		for connection in lane.connections:
			connections += 1
			for step in range(int(ceil(connection.length/2.0))+1):
				var p: Vector3 = connection.curve.sample_baked(minf(step*2.0,connection.length))
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.3,p-Vector3.UP*0.3,1))
				if hit.is_empty(): unsupported.append({"lane":id,"curve_to":connection.to,"point":str(p)})
				var distance := minf(step*2.0,connection.length)
				var tangent: Vector3 = (connection.curve.sample_baked(minf(distance+0.1,connection.length))-connection.curve.sample_baked(maxf(distance-0.1,0))).normalized()
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = shape
				query.transform = Transform3D(Basis.looking_at(tangent,Vector3.UP,true),p+Vector3.UP*0.85)
				query.collision_mask = 1
				var hits := space.intersect_shape(query,1)
				if not hits.is_empty(): blocked.append({"lane":id,"curve_to":connection.to,"point":str(p),"collider":str(city.get_path_to(hits[0].collider))})
	var report := {"lanes":lanes.size(),"connections":connections,"probes":probes,"unsupported":unsupported,"blocked":blocked,"dead_ends":ends}
	FileAccess.open("res://artifacts/authored_traffic_audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("TRAFFIC_ROAD_AUDIT: lanes=%d connections=%d probes=%d unsupported=%d blocked=%d dead_ends=%d" % [lanes.size(),connections,probes,unsupported.size(),blocked.size(),ends.size()])
	city.free()
	assert(unsupported.is_empty(),"Traffic surface mismatch; see artifacts/authored_traffic_audit.json")
	assert(blocked.is_empty(),"Traffic blocked; see artifacts/authored_traffic_audit.json")
	assert(ends.is_empty(),"City traffic should not terminate at a removed road")
	quit()
