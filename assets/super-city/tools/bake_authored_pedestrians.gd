extends "res://assets/super-city/tools/generate_pedestrian_network.gd"
## Offline only: bake the saved pavement, then export into the existing AStar
## crowd graph. No NavigationAgents or runtime baking are introduced.
var floor_faces := PackedVector3Array()
var floor_rows: Array = []
var floor_cells: Dictionary = {}
var source_counts: Dictionary = {}
var rejected_links: Array = []
var physics: PhysicsDirectSpaceState3D
var body_query := PhysicsShapeQueryParameters3D.new()
var checked := 0
var clear_rows: Array = []
var road_masks: Array = []
var mask_cells: Dictionary = {}
var pavement_index = preload("res://scripts/npc-scripts/pedestrian_surface_index.gd").new()

func generate() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	city = main.get_node("SuperCity")
	main.remove_child(city)
	main.free()
	for name in ["TrafficManager","CivilianCrowd","CityPedestrianRoutes","NightLights","CityOcclusion","RooftopEquipment"]:
		var child = city.get_node_or_null(name)
		if child: child.free()
	city.get_node("CityLife").set_script(null)
	root.add_child(city)
	await process_frame
	await physics_frame
	await physics_frame
	physics = city.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 1.8
	body_query.shape = capsule
	body_query.collision_mask = 1
	collect_floors()
	pavement_index.build(floor_rows)
	FileAccess.open("res://artifacts/pedestrian_source_faces.json",FileAccess.WRITE).store_string(JSON.stringify(floor_rows))
	var geometry := NavigationMeshSourceGeometryData3D.new()
	geometry.add_faces(floor_faces,Transform3D.IDENTITY)
	collect_obstacles(geometry)
	var nav := NavigationMesh.new()
	nav.cell_size = 0.5
	nav.cell_height = 0.1
	nav.agent_radius = 1.0
	nav.agent_height = 1.9
	nav.agent_max_climb = 0.2
	nav.agent_max_slope = 35.0
	nav.edge_max_length = 80.0
	nav.edge_max_error = 1.3
	nav.sample_partition_type = NavigationMesh.SAMPLE_PARTITION_MONOTONE
	nav.region_min_size = 1.0
	nav.filter_walkable_low_height_spans = true
	print("BAKING: ", floor_rows.size(), " pavement triangles, bounds ", geometry.get_bounds())
	if "--reuse-bake" in OS.get_cmdline_user_args():
		nav = load("res://.godot/authored_pedestrian_bake.res")
	else:
		# Bound peak memory by baking 512 m tiles, with a shared two-metre border.
		var combined := NavigationMesh.new()
		var combined_vertices := PackedVector3Array()
		var vertex_ids := {}
		for x in range(-3,3):
			for z in range(-2,3):
				var tile := nav.duplicate() as NavigationMesh
				tile.border_size = 2.0
				tile.filter_baking_aabb = AABB(Vector3(x*512-2,-2,z*512-2),Vector3(516,22,516))
				NavigationServer3D.bake_from_source_geometry_data_async(tile,geometry)
				while NavigationServer3D.is_baking_navigation_mesh(tile): await process_frame
				var verts := tile.get_vertices()
				var mapping := {}
				for i in verts.size():
					var p := verts[i].snapped(Vector3.ONE*0.001)
					if not vertex_ids.has(p):
						vertex_ids[p] = combined_vertices.size()
						combined_vertices.append(p)
					mapping[i] = vertex_ids[p]
				for i in tile.get_polygon_count():
					var poly := PackedInt32Array()
					for id in tile.get_polygon(i): poly.append(mapping[id])
					combined.add_polygon(poly)
				print("TILE ",Vector2i(x,z),": ",tile.get_polygon_count())
		combined.set_vertices(combined_vertices)
		nav = combined
	if nav.get_polygon_count() == 0:
		push_error("Pavement bake failed; existing routes retained")
		quit(1)
		return
	ResourceSaver.save(nav,"res://.godot/authored_pedestrian_bake.res")
	print("BAKED: ",nav.get_polygon_count()," polygons")
	build_links(nav)
	if edges.is_empty():
		push_error("No supported routes; existing navigation retained")
		quit(1)
		return
	simplify_straight_runs()
	finish_inventory()
	city.free()
	quit()

func relative(node: Node3D) -> Transform3D:
	return city.global_transform.affine_inverse()*node.global_transform

func shown(node: Node) -> bool:
	while node != city:
		if node is Node3D and not node.visible: return false
		node = node.get_parent()
	return true

func add_triangle(a: Vector3,b: Vector3,c: Vector3,kind: String,source: String) -> void:
	var normal := (c-a).cross(b-a).normalized()
	if normal.y < 0.7: return
	var rect := Rect2(Vector2(a.x,a.z),Vector2.ZERO).expand(Vector2(b.x,b.z)).expand(Vector2(c.x,c.z))
	if rect.end.y < -978 or rect.position.y > 1207: return
	var pieces: Array = [PackedVector3Array([a,b,c])]
	if kind != "crossing":
		var candidates := {}
		for key in spatial_keys(rect):
			for id in mask_cells.get(key,[]): candidates[id] = true
		for id in candidates:
			var mask: Dictionary = road_masks[id]
			if not rect.intersects(mask.rect): continue
			if maxf(a.y,maxf(b.y,c.y)) < mask.height-0.15 or minf(a.y,minf(b.y,c.y)) > mask.height+0.15: continue
			var next := []
			for polygon: PackedVector3Array in pieces: next.append_array(subtract_polygon_rect(polygon,mask.rect))
			pieces = next
	for polygon: PackedVector3Array in pieces:
		for i in range(1,polygon.size()-1): record_triangle(polygon[0],polygon[i],polygon[i+1],kind,source)

func record_triangle(a: Vector3,b: Vector3,c: Vector3,kind: String,source: String) -> void:
	if (b-a).cross(c-a).length_squared()<0.00001: return
	var rect := Rect2(Vector2(a.x,a.z),Vector2.ZERO).expand(Vector2(b.x,b.z)).expand(Vector2(c.x,c.z))
	var index := floor_rows.size()
	floor_rows.append({"v":[a.x,a.y,a.z,b.x,b.y,b.z,c.x,c.y,c.z],"kind":kind,"source":source})
	floor_faces.append_array(PackedVector3Array([a,b,c]))
	for key in spatial_keys(rect):
		if not floor_cells.has(key): floor_cells[key] = []
		floor_cells[key].append(index)
	source_counts[source] = int(source_counts.get(source,0))+1

func cut_polygon(polygon: PackedVector3Array,axis: int,boundary: float,positive: bool) -> PackedVector3Array:
	var result := PackedVector3Array()
	if polygon.is_empty(): return result
	var previous := polygon[-1]
	var prev_in := previous[axis]>=boundary if positive else previous[axis]<=boundary
	for current in polygon:
		var inside := current[axis]>=boundary if positive else current[axis]<=boundary
		if inside != prev_in:
			result.append(previous.lerp(current,(boundary-previous[axis])/(current[axis]-previous[axis])))
		if inside: result.append(current)
		previous = current; prev_in = inside
	return result

func subtract_polygon_rect(polygon: PackedVector3Array,rect: Rect2) -> Array:
	var outside := []
	var remainder := polygon
	for plane in [[0,rect.position.x,true],[0,rect.end.x,false],[2,rect.position.y,true],[2,rect.end.y,false]]:
		var piece := cut_polygon(remainder,plane[0],plane[1],not plane[2])
		if piece.size()>=3: outside.append(piece)
		remainder = cut_polygon(remainder,plane[0],plane[1],plane[2])
	return outside

func add_road_mask(rect: Rect2,tr: Transform3D) -> void:
	var bounds := tr*AABB(Vector3(rect.position.x,0.03,rect.position.y),Vector3(rect.size.x,0,rect.size.y))
	var world := Rect2(bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z)
	var id := road_masks.size()
	road_masks.append({"rect":world,"height":bounds.position.y})
	for key in spatial_keys(world):
		if not mask_cells.has(key): mask_cells[key] = []
		mask_cells[key].append(id)

func add_rect(rect: Rect2,tr: Transform3D,kind: String,source: String) -> void:
	var a := tr*Vector3(rect.position.x,0.03,rect.position.y)
	var b := tr*Vector3(rect.end.x,0.03,rect.position.y)
	var c := tr*Vector3(rect.end.x,0.03,rect.end.y)
	var d := tr*Vector3(rect.position.x,0.03,rect.end.y)
	add_triangle(a,b,c,kind,source)
	add_triangle(a,c,d,kind,source)

func collect_floors() -> void:
	for node in city.get_node("Roads").find_children("*","StaticBody3D",true,false):
		if node.has_method("road_rects") and node.width_m>=12 and shown(node):
			for rect: Rect2 in node.road_rects(): add_road_mask(rect,relative(node))
	# The level north deck intersects the quay. The two arched decks clear it.
	add_road_mask(Rect2(-10,-79,20,158),relative(city.get_node("NorthRiverBridge")))
	for node in city.find_children("*","StaticBody3D",true,false):
		if not node.has_method("sidewalk_rects") or not shown(node): continue
		var path := str(city.get_path_to(node))
		if not path.begins_with("Roads/") and not path.begins_with("SouthRiverBridge/"): continue
		var tr := relative(node)
		if tr.origin.z > 780: continue
		for rect: Rect2 in node.sidewalk_rects(): add_rect(rect,tr,"sidewalk",path)
		if node.width_m < 12:
			for rect: Rect2 in node.road_rects(): add_rect(rect,tr,"alley",path)
		var w: float = node.width_m
		if node.piece_type == 1:
			var h: float = node.cross_width_m
			for arm in range(4):
				if (node.active_arms & node.crosswalk_arms & (1<<arm)) == 0: continue
				var r: Rect2
				match arm:
					0: r = Rect2(-w/2-2,-h/2-5,w+4,3)
					1: r = Rect2(w/2+2,-h/2-2,3,h+4)
					2: r = Rect2(-w/2-2,h/2+2,w+4,3)
					3: r = Rect2(-w/2-5,-h/2-2,3,h+4)
				add_rect(r,tr,"crossing",path)
		else:
			if node.crosswalk_north: add_rect(Rect2(-w/2-2,-node.length_m/2+2,w+4,3),tr,"crossing",path)
			if node.crosswalk_south: add_rect(Rect2(-w/2-2,node.length_m/2-5,w+4,3),tr,"crossing",path)
	for node: MeshInstance3D in city.find_children("*","MeshInstance3D",true,false):
		var path := str(city.get_path_to(node))
		var selected := path.begins_with("Sidewalks/") and node.get_parent().has_meta("sidewalk_module")
		selected = selected or path == "RiverFrontage/Quay" or path in ["SouthRiverBridge/Walkways","CityHallBridge/Walkways","NorthRiverBridge/Walkways"]
		selected = selected or path.begins_with("Waterfront/Harbor/ConcretePier") or path.begins_with("Landmarks/CentralPark/Trails/")
		selected = selected or path.begins_with("Landmarks/CentralPark/Landmarks/BowBridge/Deck/")
		if not selected or not shown(node) or node.mesh == null: continue
		var tr := relative(node)
		var faces := node.mesh.get_faces()
		for i in range(0,faces.size(),3): add_triangle(tr*faces[i],tr*faces[i+1],tr*faces[i+2],"sidewalk",path)

func collect_obstacles(geometry: NavigationMeshSourceGeometryData3D) -> void:
	# Box colliders cover authored buildings, props and barriers. Their vertical
	# span matters: bridge decks must not cut off a promenade underneath them.
	var count := 0
	for node: CollisionShape3D in city.find_children("*","CollisionShape3D",true,false):
		if node.disabled or not node.shape is BoxShape3D: continue
		var parent := node.get_parent() as CollisionObject3D
		if parent == null or (parent.collision_layer & 1) == 0: continue
		var path := str(city.get_path_to(node))
		if path.begins_with("Ground/") or path.begins_with("Roads/") or path.begins_with("Sidewalks/") or path.begins_with("Mountain"): continue
		if path.contains("/Trails/") or path.contains("/Walkways/") or path.contains("ConcretePier") or path == "RiverFrontage/Quay/Solid/CollisionShape3D": continue
		var tr := relative(node)
		var box: Vector3 = node.shape.size
		var bounds := tr*AABB(-box/2,box)
		if bounds.end.y < 0.3 or bounds.position.y > 18 or bounds.size.y < 0.05: continue
		var rect := Rect2(bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z)
		var nearby := false
		for key in spatial_keys(rect):
			if floor_cells.has(key): nearby = true; break
		if not nearby: continue
		var outline := PackedVector3Array()
		for p in [Vector3(-box.x/2,0,-box.z/2),Vector3(box.x/2,0,-box.z/2),Vector3(box.x/2,0,box.z/2),Vector3(-box.x/2,0,box.z/2)]:
			var vertex: Vector3 = tr*p
			vertex.y = 0
			outline.append(vertex)
		# Projected obstructions classify the floor span, not the head volume.
		# Extend down by pedestrian height to include benches and low overhangs.
		geometry.add_projected_obstruction(outline,bounds.position.y-1.8,minf(bounds.size.y,30.0)+1.8,false)
		count += 1
	print("OBSTACLES: ", count)

func surface_at(p: Vector3, crossings := true) -> Dictionary:
	var best := {}
	var error := 0.36
	for index in floor_cells.get(Vector2i(floori(p.x/100),floori(p.z/100)),[]):
		var row: Dictionary = floor_rows[index]
		if not crossings and row.kind == "crossing": continue
		var v: Array = row.v
		var a := Vector3(v[0],v[1],v[2]); var b := Vector3(v[3],v[4],v[5]); var c := Vector3(v[6],v[7],v[8])
		if not Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])): continue
		var plane := Plane(a,b,c)
		var y := (plane.d-plane.normal.x*p.x-plane.normal.z*p.z)/plane.normal.y
		var diff := absf(y-p.y)
		if diff < error or (diff <= error+0.001 and not best.is_empty() and best.kind == "crossing" and row.kind != "crossing"):
			error = diff
			best = {"height":y,"kind":row.kind,"source":row.source}
	return best

func grounded(p: Vector3) -> Vector3:
	var row := surface_at(p)
	if row.is_empty(): return Vector3.INF
	p.y = row.height
	return p

func point3(p: Vector3) -> int:
	var key := p.snapped(Vector3.ONE*0.001)
	if point_lookup.has(key): return point_lookup[key]
	point_lookup[key] = points.size()
	points.append([p.x,p.y,p.z])
	return points.size()-1

func link3(p: Vector3,q: Vector3) -> void:
	if p == Vector3.INF or q == Vector3.INF or p.distance_to(q)<0.05: return
	var kind := "sidewalk"
	var steps := maxi(1,ceili(p.distance_to(q)/0.75))
	var samples := PackedVector3Array()
	var previous_height := p.y
	for i in range(steps+1):
		var sample := p.lerp(q,float(i)/steps)
		if i>0: sample.y = previous_height+(q.y-p.y)/steps
		var row := surface_at(sample)
		if row.is_empty(): return
		sample.y = row.height
		previous_height = sample.y
		samples.append(sample)
		for side in range(8):
			var offset := Vector2.from_angle(side*TAU/8.0)*0.56
			var foot := sample+Vector3(offset.x,0,offset.y)
			if not pavement_index.contains(foot,true): return
			if not pavement_index.contains(foot,false): kind = "crossing"
		if row.kind == "crossing": kind = "crossing"
		elif row.kind == "alley" and kind != "crossing": kind = "alley"
		body_query.transform = Transform3D(Basis.IDENTITY,city.to_global(sample+Vector3.UP*0.96))
		var hits := physics.intersect_shape(body_query,1)
		var support := physics.intersect_ray(PhysicsRayQueryParameters3D.create(city.to_global(sample+Vector3.UP*0.2),city.to_global(sample-Vector3.UP*0.2),1))
		checked += 1
		if not hits.is_empty() or support.is_empty():
			rejected_links.append({"point":str(sample),"obstacle":str(city.get_path_to(hits[0].collider)) if not hits.is_empty() else "no support"})
			return
	if absf(samples[-1].y-q.y)>0.1: return
	# Preserve real changes in bridge grade; a long chord across the arch would
	# put capsules under the walkway and fail promotion ground checks.
	var first := samples[0]
	for i in range(1,samples.size()-1):
		var a := (samples[i]-first).normalized()
		var b := (samples[i+1]-samples[i]).normalized()
		if a.dot(b)<0.99999:
			record_link(first,samples[i],kind)
			first = samples[i]
	record_link(first,q,kind)

func record_link(p: Vector3,q: Vector3,kind: String) -> void:
	if p.distance_to(q)<0.01: return
	var a := point3(p); var b := point3(q)
	var key := Vector2i(mini(a,b),maxi(a,b))
	if edge_lookup.has(key): return
	var mid := Vector2((p.x+q.x)/2,(p.z+q.z)/2)
	var district := district_at(mid)
	var label := "Block_%02d_%02d" % [floori((mid.y+1000)/160)+1,floori((mid.x+1500)/180)+1]
	if mid.y>780: label = "Pier" if mid.x>600 else "Waterfront"
	var module_id := district+"_"+label
	if not modules.has(module_id): modules[module_id] = {"district":district,"label":label,"nodes":{},"edge_count":0}
	modules[module_id].nodes[a] = true; modules[module_id].nodes[b] = true
	modules[module_id].edge_count += 1
	edges.append([a,b,kind,module_id])
	edge_lookup[key] = true

func build_links(nav: NavigationMesh) -> void:
	var vertices := nav.get_vertices()
	var portals := {}
	for i in nav.get_polygon_count():
		var polygon := nav.get_polygon(i)
		var center := Vector3.ZERO
		for id in polygon: center += vertices[id]
		center = grounded(center/polygon.size())
		if center == Vector3.INF: continue
		for j in range(1,polygon.size()-1):
			var v := []
			for id in [polygon[0],polygon[j],polygon[j+1]]:
				var p: Vector3 = vertices[id]
				v.append_array([p.x,p.y,p.z])
			clear_rows.append({"v":v})
		for j in polygon.size():
			var a: int = polygon[j]; var b: int = polygon[(j+1)%polygon.size()]
			var key := Vector2i(mini(a,b),maxi(a,b))
			if not portals.has(key): portals[key] = []
			portals[key].append(center)
	for key: Vector2i in portals:
		if portals[key].size() != 2: continue
		var mid := grounded((vertices[key.x]+vertices[key.y])/2)
		for center: Vector3 in portals[key]: link3(center,mid)
	print("LINKS: ",edges.size()," / physics probes ",checked," / blocked candidates ",rejected_links.size())

func simplify_straight_runs() -> void:
	# Collapse only redundant collinear waypoints, retaining junctions, grade
	# changes, crossing boundaries and district/module ownership.
	var adjacency := {}
	for id in points.size(): adjacency[id] = {}
	for i in edges.size():
		adjacency[edges[i][0]][edges[i][1]] = i
		adjacency[edges[i][1]][edges[i][0]] = i
	for id in points.size():
		if adjacency[id].size()!=2: continue
		var neighbors: Array = adjacency[id].keys()
		var a: int = neighbors[0]; var b: int = neighbors[1]
		if adjacency[a].has(b): continue
		var ai: int = adjacency[id][a]; var bi: int = adjacency[id][b]
		if edges[ai][2] != edges[bi][2] or edges[ai][3] != edges[bi][3]: continue
		var p := Vector3(points[a][0],points[a][1],points[a][2])
		var q := Vector3(points[b][0],points[b][1],points[b][2])
		var mid := Vector3(points[id][0],points[id][1],points[id][2])
		if p.distance_to(q)>60: continue
		var closest := Geometry3D.get_closest_point_to_segment(mid,p,q)
		if closest.distance_to(mid)>0.025: continue
		edges[ai][0] = a; edges[ai][1] = b
		edges[bi] = []
		adjacency[a].erase(id); adjacency[b].erase(id); adjacency[id].clear()
		adjacency[a][b] = ai; adjacency[b][a] = ai
	edges = edges.filter(func(edge): return not edge.is_empty())
	modules.clear()
	for edge in edges:
		var key: String = edge[3]
		if not modules.has(key):
			var split := key.find("_")
			modules[key] = {"district":key.left(split),"label":key.substr(split+1),"nodes":{},"edge_count":0}
		modules[key].nodes[edge[0]] = true; modules[key].nodes[edge[1]] = true
		modules[key].edge_count += 1
	print("SIMPLIFIED: ",edges.size()," segments")

func finish_inventory() -> void:
	discard_unused_points()
	var astar := AStar3D.new()
	for i in points.size(): astar.add_point(i,Vector3(points[i][0],points[i][1],points[i][2]))
	for edge in edges: astar.connect_points(edge[0],edge[1])
	var components := {}; var sizes: Array[int] = []
	for id in astar.get_point_ids():
		if components.has(id): continue
		var pending := [id]; var size := 0
		components[id] = sizes.size()
		while not pending.is_empty():
			var current: int = pending.pop_back(); size += 1
			for next in astar.get_point_connections(current):
				if not components.has(next): components[next] = sizes.size(); pending.append(next)
		sizes.append(size)
	var owners := {}
	for key in modules:
		var module: Dictionary = modules[key]
		module.nodes = module.nodes.keys()
		module.start = module.nodes[0]; module.destination = module.nodes[-1]
		module.component = components[module.start]; module.neighbors = []
		for id in module.nodes:
			if not owners.has(id): owners[id] = []
			owners[id].append(key)
	for list: Array in owners.values():
		for key in list:
			for other in list:
				if key != other and not other in modules[key].neighbors: modules[key].neighbors.append(other)
	write_scene()
	var data := {"version":2,"points":points,"edges":edges,"modules":modules,"surfaces":[],"floor_triangles":floor_rows,"clear_triangles":clear_rows,"component_sizes":sizes,"river_crossings":3,"source_scene":SCENE,"source_scene_sha256":FileAccess.get_sha256(SCENE),"source_main_sha256":FileAccess.get_sha256("res://scenes/main.tscn"),"source_counts":source_counts,"warnings":warnings}
	FileAccess.open(DEST+"network.json",FileAccess.WRITE).store_string(JSON.stringify(data)+"\n")
	FileAccess.open("res://artifacts/pedestrian_bake_audit.json",FileAccess.WRITE).store_string(JSON.stringify({"components":sizes,"rejected_links":rejected_links,"physics_probes":checked,"sources":source_counts},"\t"))
	var report := "# Authored pedestrian route inventory\n\n%d route modules, %d points, %d segments. Component sizes: %s.\n\n" % [modules.size(),points.size(),edges.size(),str(sizes)]
	report += "Built from the saved Main/SuperCity pavement: native road sidewalks and painted crossing positions, independent sidewalk modules, City Hall surrounds, both concrete piers, river quays, park trails/Bow Bridge, and all three river bridge walkways. Airport and mountain/highway routes are excluded.\n\n"
	report += "Offline Godot navigation baking reserves static box-collider clearance; %d support/head-clearance probes checked candidate routes against actual scene physics. %d obstructed candidates were omitted. Exported routes use the existing AStar crowd system. No runtime navigation bake or NavigationAgents were added.\n\n" % [checked,rejected_links.size()]
	report += "Disconnected pavement remains a separate walking component when no physically supported, unobstructed paved connection exists. These are not joined across grass, roads without a painted crossing, or empty space. See README.md for current coverage and remaining geometry gaps.\n\n| Module | Segments |\n| --- | ---: |\n"
	var keys := modules.keys(); keys.sort()
	for key in keys: report += "| %s | %d |\n" % [key,modules[key].edge_count]
	FileAccess.open(DEST+"INVENTORY.md",FileAccess.WRITE).store_string(report)
	print("AUTHORED NETWORK: ",modules.size()," modules, ",points.size()," points, components ",sizes)

func write_scene() -> void:
	# Preserve inherited marker paths and the user's saved checkbox/debug settings.
	var path := "res://scenes/npcs/city_pedestrian_routes.tscn"
	var text := FileAccess.get_file_as_string(path).replace("\r\n","\n")
	for key in modules:
		var module: Dictionary = modules[key]
		var header: String = '[node name="'+module.label+'" type="Node3D" parent="'+module.district+'"]'
		var marker: String = '[node name="StartHere" type="Marker3D" parent="'+module.district+'/'+module.label+'"]'
		var p: Array = points[module.start]
		var position_line := 'position = Vector3(%s, %s, %s)' % [p[0],p[1],p[2]]
		if not header in text:
			text += '\n'+header+'\nmetadata/module_id = "'+key+'"\n\n'+marker+'\n'+position_line+'\ngizmo_extents = 3.0\n'
		else:
			var start := text.find(marker)
			var end := text.find("\n[node",start+1)
			if end == -1: end = text.length()
			var block := text.substr(start,end-start)
			var re := RegEx.create_from_string("position = Vector3\\([^\\n]*\\)")
			text = text.substr(0,start)+re.sub(block,position_line)+text.substr(end)
	FileAccess.open(path,FileAccess.WRITE).store_string(text)
	var city_text := FileAccess.get_file_as_string(SCENE).replace("\r\n","\n")
	var sections := city_text.split("\n[node ")
	for i in range(1,sections.size()):
		var header := sections[i].get_slice("\n",0)
		if 'parent="CityPedestrianRoutes"' in header:
			var district := header.get_slice('name="',1).get_slice('"',0)
			var re := RegEx.create_from_string("(?s)enabled_routes = (\\{.*?\\})")
			var match := re.search(sections[i])
			if match:
				var settings: Dictionary = str_to_var(match.get_string(1))
				for key in modules:
					if modules[key].district == district and not settings.has(key): settings[key] = true
				sections[i] = sections[i].replace(match.get_string(),"enabled_routes = "+var_to_str(settings))
		elif 'name="StartHere"' in header and 'parent="CityPedestrianRoutes/' in header:
			var parent := header.get_slice('parent="CityPedestrianRoutes/',1).get_slice('"',0)
			var key := parent.replace("/","_")
			if modules.has(key):
				var p: Array = points[modules[key].start]
				var re := RegEx.create_from_string("transform = Transform3D\\([^\\n]*\\)")
				sections[i] = re.sub(sections[i],"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)" % [p[0],p[1],p[2]])
	FileAccess.open(SCENE,FileAccess.WRITE).store_string("\n[node ".join(sections))
