extends SceneTree
## Geometry/topology regression against the actual edited city, not just the plan.
const LANES=preload("res://scripts/traffic/traffic_lanes.gd")
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func rect_of(row: Array) -> Rect2: return Rect2(row[0],row[1],row[2],row[3])
func run() -> void:
	create_timer(60).timeout.connect(func():push_error("POI integration timed out");quit(1))
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/layout.json"))
	var graph: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/pedestrians/network.json"))
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/poi-integration/integration.json"))
	var city: Node3D=load("res://scenes/super_city.tscn").instantiate()
	for name in ["TrafficManager","CivilianCrowd","Sound","PreviewCamera"]: city.get_node(name).free()
	root.add_child(city)
	current_scene=city
	await physics_frame
	await physics_frame
	check(graph.component_sizes.size()==2 and graph.river_crossings==0,"Keep the two intentionally separate pedestrian riverbanks")
	check(graph.modules.size()==262,"District modules include the revised riverfront")
	check(graph.source_scene_sha256==FileAccess.get_sha256("res://scenes/super_city.tscn"),"A* snapshot matches final city scene")
	for key in graph.modules:
		var module: Dictionary=graph.modules[key]
		var marker: Node3D=city.get_node("CityPedestrianRoutes/"+module.district+"/"+module.label+"/StartHere")
		var p: Array=graph.points[module.start]
		check(marker.position.distance_to(Vector3(p[0],p[1],p[2]))<.01,"Editor route-start marker matches A*: "+key)
	check(is_equal_approx(city.get_node("CityHall").position.x,-292),"City hall aligns with Central Park's center")
	check(city.get_node("Hospital").position.distance_to(Vector3(-311.00287,0.6300144,378.79425))<30,"Hospital remains near the user's south-park placement")
	for removed in plan.removed_buildings: check(not city.has_node(removed),"Removed building has no remaining scene/collision: "+removed)
	for poi in layout.landmarks:
		check(city.has_node(poi.node),"Missing POI "+poi.node)
		var r:=rect_of(poi.rect)
		for road in layout.roads: check(not r.intersects(rect_of(road.rect)),"POI overlaps road: "+poi.node)
		for building in layout.buildings: check(not r.intersects(rect_of(building.rect)),"POI overlaps remaining building: "+poi.node+" / "+building.node)
		if poi.node in ["Bank1","Bank2"]: check(poi.district=="FinancialQuarter","Both banks belong in Financial Quarter")
	var space:=city.get_world_3d().direct_space_state
	var capsule:=CapsuleShape3D.new()
	capsule.radius=0.32
	capsule.height=1.7
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=capsule
	query.collision_mask=1
	var sampled:=0
	var seen: Dictionary={}
	for edge in graph.edges:
		var pa: Array=graph.points[edge[0]]
		var pb: Array=graph.points[edge[1]]
		var a:=Vector3(pa[0],0.03,pa[2])
		var b:=Vector3(pb[0],0.03,pb[2])
		var near:=false
		for poi in layout.landmarks:
			var site:=rect_of(poi.site).grow(8)
			if site.has_point(Vector2(a.x,a.z)) or site.has_point(Vector2(b.x,b.z)): near=true; break
		if not near: continue
		for step in range(ceili(a.distance_to(b)/2.0)+1):
			var p:=a.lerp(b,minf(1.0,step*2.0/maxf(.01,a.distance_to(b))))
			query.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*.95)
			var hits:=space.intersect_shape(query,4)
			for hit in hits:
				var key:=str(city.get_path_to(hit.collider))
				if not seen.has(key): check(false,"NPC capsule blocked on updated path near %s by %s"%[p,key]);seen[key]=true
			var floor_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.6,p-Vector3.UP*.25,1))
			if floor_hit.is_empty():
				# Shared triangle-edge precision: a tiny adjacent probe is sufficient.
				floor_hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3(.01,.6,.013),p+Vector3(.01,-.25,.013),1))
			check(not floor_hit.is_empty(),"Missing walk support near "+str(p))
			sampled+=1
	# Every generated traffic lane and curve must stay out of the reserved POIs.
	var lanes:=LANES.build(layout,3.5,0.4,true)
	var connection_count:=0
	for lane in lanes:
		for connection in lane.connections:
			connection_count+=1
			for p in connection.curve.get_baked_points():
				for poi in layout.landmarks: check(not rect_of(poi.rect).has_point(Vector2(p.x,p.z)),"Vehicle turn enters "+poi.node)
	check(connection_count>500,"Traffic junction network remains populated")
	var junctions: Array=[]
	for road in layout.roads:
		if road.kind=="junction":junctions.append(road)
	for control in city.get_node("CityLife/TrafficControls").get_children():
		var id:=int(control.get_meta("junction"))
		check(id>=0 and id<junctions.size(),"Traffic control retains valid junction ID")
	# Only the integrated hospital should own a rescue drop-off in the live city.
	check(get_nodes_in_group(&"hospital_rescue_zone").size()==1,"Exactly one active hospital rescue destination")
	var main: Node3D=load("res://scenes/main.tscn").instantiate()
	for poi in layout.landmarks: check(not main.has_node(poi.node),"Remove duplicate main-scene POI showroom")
	main.free()
	print("POI_INTEGRATION: %d failures; %d physical path samples; %d lanes / %d vehicle turns; 262 modules / 2 banks."%[failures,sampled,lanes.size(),connection_count])
	city.free()
	quit(0 if failures==0 else 1)
