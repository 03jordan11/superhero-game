extends "res://assets/super-city/tools/generate_super_city.gd"
## Offline pedestrian authoring only. Never repacks a city or its geometry.
const DEST = "res://assets/super-city/pedestrians/"
var surfaces: Array[Rect2] = []
var kinds: Array[String] = []
var water: Array[Rect2] = []
var footprints: Array[Rect2] = []
var obstacle_cells: Dictionary = {}
var cells: Dictionary = {}
var points: Array = []
var edges: Array = []
var modules: Dictionary = {}
var centers: Array[int] = []
var point_lookup: Dictionary = {}
var edge_lookup: Dictionary = {}
var warnings: Array[String] = []
var river_curve: Array = []
var road_footprints: Array[Rect2] = []

func _initialize() -> void:
	generate.call_deferred()

func generate() -> void:
	DirAccess.make_dir_recursive_absolute(DEST)
	var layout = JSON.parse_string(FileAccess.get_file_as_string(OUT+"layout.json"))
	river_curve=layout.get("river_curve_rows",[])
	for row in layout.roads:road_footprints.append(to_rect(row.rect))
	for row in layout.river_rects: water.append(to_rect(row))
	water.append_array(subtract_rect(to_rect(layout.bay_rect),to_rect(layout.pier_rect)))
	var source = load(SCENE).instantiate()
	for building in layout.buildings:
		var node = source.get_node_or_null(building.node)
		if node == null:
			warnings.append("Missing authored building: "+building.node)
			continue
		# Use the current scene's collision footprint, not stale placement data.
		var shape_node: CollisionShape3D = node.get_node("CollisionShape3D")
		if shape_node.shape is BoxShape3D:
			var box: Vector3 = shape_node.shape.size
			var bounds: AABB = (node.transform*shape_node.transform)*AABB(-box/2,box)
			footprints.append(Rect2(bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z))
		if node.position.distance_to(Vector3(building.position[0],building.position[1],building.position[2])) > 0.1:
			warnings.append("Moved building checked at current position: "+building.node)
	source.free()
	# Complete POIs include grounds/steps/props, so reserve their authored envelope
	# as well as ordinary building boxes. The perimeter sidewalks remain routable.
	for landmark in layout.get("landmarks",[]):
		footprints.append(to_rect(landmark.rect))
	for rect in footprints:
		for key in spatial_keys(rect):
			if not obstacle_cells.has(key): obstacle_cells[key] = []
			obstacle_cells[key].append(rect)
	for row in layout.sidewalks:
		for piece in subtract_all([to_rect(row)],water): add_surface(piece,"sidewalk")
	for road in layout.roads:
		if road.kind == "alley":
			for piece in subtract_all([to_rect(road.rect)],water): add_surface(piece,"alley")
	for i in range(surfaces.size()):
		for key in spatial_keys(surfaces[i].grow(0.01)):
			if not cells.has(key): cells[key] = []
			cells[key].append(i)
	for rect in surfaces:
		centers.append(add_point(rect.get_center()))
	for i in range(surfaces.size()):
		var rect := surfaces[i]
		var neighbors: Dictionary = {}
		for key in spatial_keys(rect.grow(0.01)):
			for j in cells.get(key,[]):
				if j > i: neighbors[j] = true
		for j in neighbors:
			var other := surfaces[int(j)]
			var portal := Vector2.INF
			var lo := maxf(rect.position.y,other.position.y)
			var hi := minf(rect.end.y,other.end.y)
			if hi-lo >= 1.2:
				if absf(rect.end.x-other.position.x) < 0.01: portal = Vector2(rect.end.x,(lo+hi)/2)
				elif absf(other.end.x-rect.position.x) < 0.01: portal = Vector2(rect.position.x,(lo+hi)/2)
			lo = maxf(rect.position.x,other.position.x)
			hi = minf(rect.end.x,other.end.x)
			if hi-lo >= 1.2:
				if absf(rect.end.y-other.position.y) < 0.01: portal = Vector2((lo+hi)/2,rect.end.y)
				elif absf(other.end.y-rect.position.y) < 0.01: portal = Vector2((lo+hi)/2,rect.position.y)
			if portal != Vector2.INF:
				var id := add_point(portal)
				add_edge(centers[i],id,kinds[i])
				add_edge(id,centers[j],kinds[j])
	# Crosswalks connect sidewalk modules across ordinary streets only.
	for street in layout.roads:
		if street.kind != "street": continue
		var rect := to_rect(street.rect)
		for junction in layout.roads:
			if junction.kind != "junction": continue
			var jr := to_rect(junction.rect)
			var p := Vector2.INF
			var q := Vector2.INF
			if street.axis == 0 and is_equal_approx(jr.position.y,rect.position.y) and is_equal_approx(jr.size.y,rect.size.y):
				var x := INF
				if is_equal_approx(jr.end.x,rect.position.x): x = rect.position.x+3.5
				if is_equal_approx(jr.position.x,rect.end.x): x = rect.end.x-3.5
				if x != INF:
					p = Vector2(x,rect.position.y-2)
					q = Vector2(x,rect.end.y+2)
			elif street.axis == 1 and is_equal_approx(jr.position.x,rect.position.x) and is_equal_approx(jr.size.x,rect.size.x):
				var z := INF
				if is_equal_approx(jr.end.y,rect.position.y): z = rect.position.y+3.5
				if is_equal_approx(jr.position.y,rect.end.y): z = rect.end.y-3.5
				if z != INF:
					p = Vector2(rect.position.x-2,z)
					q = Vector2(rect.end.x+2,z)
			if p != Vector2.INF: connect_crossing(p,q)
	connect_curved_quays()
	discard_unused_points()
	var astar := AStar3D.new()
	for i in range(points.size()): astar.add_point(i,Vector3(points[i][0],0.03,points[i][2]))
	for edge in edges: astar.connect_points(edge[0],edge[1])
	var components: Dictionary = {}
	var component_sizes: Array[int] = []
	for id in astar.get_point_ids():
		if components.has(id) or astar.get_point_connections(id).is_empty(): continue
		var queue: Array[int] = [id]
		components[id] = component_sizes.size()
		var cursor := 0
		while cursor < queue.size():
			for neighbor in astar.get_point_connections(queue[cursor]):
				if not components.has(neighbor):
					components[neighbor] = component_sizes.size()
					queue.append(neighbor)
			cursor += 1
		component_sizes.append(queue.size())
	for key in modules:
		var module: Dictionary = modules[key]
		var candidates: Array = module.nodes.keys()
		var first: int = candidates[0]
		var last := first
		var farthest := 0.0
		for id in candidates:
			if components.get(id,-1) != components.get(first,-2): continue
			var distance := astar.get_point_position(first).distance_to(astar.get_point_position(id))
			if distance > farthest:
				farthest = distance
				last = id
		module.start = first
		module.destination = last
		module.component = components.get(first,-1)
		module.nodes = candidates
		module.erase("temporary")
	var point_modules: Dictionary = {}
	for key in modules:
		modules[key].neighbors = []
		for id in modules[key].nodes:
			if not point_modules.has(id): point_modules[id] = []
			point_modules[id].append(key)
	for owners: Array in point_modules.values():
		for key in owners:
			for neighbor in owners:
				if neighbor != key and not neighbor in modules[key].neighbors: modules[key].neighbors.append(neighbor)
	var saved := {"points":points,"edges":edges,"modules":modules,"surfaces":surfaces.map(func(r): return [r.position.x,r.position.y,r.size.x,r.size.y]),"excluded_water":water.map(func(r): return [r.position.x,r.position.y,r.size.x,r.size.y]),"component_sizes":component_sizes,"warnings":warnings,"source_scene":SCENE,"source_scene_sha256":FileAccess.get_sha256(SCENE),"river_crossings":0}
	saved.river_curve_rows=river_curve
	saved.quay_road_cuts=road_footprints.map(func(r):return [r.position.x,r.position.y,r.size.x,r.size.y])
	FileAccess.open(DEST+"network.json",FileAccess.WRITE).store_string(JSON.stringify(saved,"\t"))
	write_scene()
	write_inventory(component_sizes)
	print("Pedestrian network: %d modules, %d points, %d segments, %d connected components. River crossings excluded." % [modules.size(),points.size(),edges.size(),component_sizes.size()])
	quit()

func to_rect(row: Array) -> Rect2: return Rect2(row[0],row[1],row[2],row[3])

func add_surface(rect: Rect2, kind: String) -> void:
	if minf(rect.size.x,rect.size.y) < 1.2: return
	surfaces.append(rect)
	kinds.append(kind)

func point_clear(p: Vector2, crossing := false) -> bool:
	for i in range(9):
		var sample := p+(Vector2.from_angle(i*TAU/8.0)*0.56 if i < 8 else Vector2.ZERO)
		for rect in water:
			if not river_curve.is_empty() and rect.position.y>=-1000 and rect.end.y<=800:continue
			if rect.has_point(sample): return false
		if not river_curve.is_empty() and sample.y>=-1000 and sample.y<=800:
			var bounds:=curve_bounds(sample.y)
			if sample.x>=bounds.x and sample.x<=bounds.y:return false
		for rect in obstacle_cells.get(Vector2i(floori(sample.x/100),floori(sample.y/100)),[]):
			if rect.has_point(sample): return false
		if crossing: continue
		var inside := false
		for index in cells.get(Vector2i(floori(sample.x/100),floori(sample.y/100)),[]):
			if surfaces[index].has_point(sample):
				inside = true
				break
		if not inside and not on_curved_quay(sample): return false
	return true

func on_curved_quay(p: Vector2) -> bool:
	if river_curve.is_empty() or p.y < -1000 or p.y > 800:return false
	var bounds:=curve_bounds(p.y)
	var left:=bounds.x;var right:=bounds.y
	if not ((p.x>=left-12 and p.x<=left) or (p.x>=right and p.x<=right+12)):return false
	for road in road_footprints:
		if road.has_point(p):return false
	return true

func curve_bounds(z: float) -> Vector2:
	var index:=clampi(int((z+1000)/10),0,river_curve.size()-2)
	var a: Array=river_curve[index];var b: Array=river_curve[index+1]
	var t: float=(z-a[0])/(b[0]-a[0])
	var left: float=lerpf(a[1],b[1],t);var right: float=lerpf(a[2],b[2],t)
	return Vector2(left,right)

func connect_curved_quays() -> void:
	if river_curve.is_empty():return
	var existing_count:=points.size()
	for side in [-1,1]:
		var previous:=-1
		for row in river_curve:
			var p:=Vector2(row[1]-6 if side==-1 else row[2]+6,row[0])
			if not point_clear(p):previous=-1;continue
			var id:=add_point(p)
			if previous>=0:add_edge(previous,id,"sidewalk")
			previous=id
			var nearest:=-1;var distance:=35.0
			for candidate in existing_count:
				var q:=Vector2(points[candidate][0],points[candidate][2]);var d:=p.distance_to(q)
				if d<distance and candidate!=id and segment_clear(p,q):nearest=candidate;distance=d
			if nearest>=0:add_edge(id,nearest,"sidewalk")

func discard_unused_points() -> void:
	# Clipped sidewalk slivers can have a center but no usable connection.
	# Do not publish these as isolated A* destinations or crowd spawn candidates.
	var used:={};var remap:={};var kept: Array=[]
	for edge in edges:used[edge[0]]=true;used[edge[1]]=true
	for id in points.size():
		if used.has(id):remap[id]=kept.size();kept.append(points[id])
	for edge in edges:edge[0]=remap[edge[0]];edge[1]=remap[edge[1]]
	for module in modules.values():
		var updated:={}
		for id in module.nodes:
			if remap.has(id):updated[remap[id]]=true
		module.nodes=updated
	points=kept

func segment_clear(p: Vector2, q: Vector2, crossing := false) -> bool:
	var steps := maxi(1,ceili(p.distance_to(q)/1.0))
	for i in range(steps+1):
		if not point_clear(p.lerp(q,float(i)/steps),crossing): return false
	return true

func add_point(p: Vector2) -> int:
	var key := Vector2(snappedf(p.x,0.001),snappedf(p.y,0.001))
	if point_lookup.has(key): return point_lookup[key]
	var id := points.size()
	points.append([p.x,0.03,p.y])
	point_lookup[key] = id
	return id

func add_edge(a: int, b: int, kind: String) -> void:
	if a == b: return
	var key := Vector2i(mini(a,b),maxi(a,b))
	if edge_lookup.has(key): return
	var p := Vector2(points[a][0],points[a][2])
	var q := Vector2(points[b][0],points[b][2])
	if not segment_clear(p,q,kind == "crossing"):
		# A diagonal from a long strip's center to an end portal can clip
		# the inside corner. Try an orthogonal elbow within the surface union.
		if kind != "crossing":
			for elbow in [Vector2(p.x,q.y),Vector2(q.x,p.y)]:
				if elbow == p or elbow == q: continue
				if segment_clear(p,elbow) and segment_clear(elbow,q):
					var turn := add_point(elbow)
					add_edge(a,turn,kind)
					add_edge(turn,b,kind)
					return
		return
	var middle := (p+q)/2
	var district := district_at(middle)
	var label := "Block_%02d_%02d" % [floori((middle.y+1000)/160)+1,floori((middle.x+1500)/180)+1]
	if middle.y > 780: label = "Pier" if PIER.has_point(middle) else "Waterfront"
	var module_id := district+"_"+label
	if not modules.has(module_id): modules[module_id] = {"district":district,"label":label,"nodes":{},"edge_count":0}
	modules[module_id].nodes[a] = true
	modules[module_id].nodes[b] = true
	modules[module_id].edge_count += 1
	edges.append([a,b,kind,module_id])
	edge_lookup[key] = true

func connect_crossing(p: Vector2, q: Vector2) -> void:
	if not point_clear(p) or not point_clear(q) or not segment_clear(p,q,true): return
	var pi := add_point(p)
	var qi := add_point(q)
	for pair in [[p,pi],[q,qi]]:
		for i in cells.get(Vector2i(floori(pair[0].x/100),floori(pair[0].y/100)),[]):
			if surfaces[i].has_point(pair[0]): add_edge(pair[1],centers[i],kinds[i])
	add_edge(pi,qi,"crossing")

func write_scene() -> void:
	var previous: Node = null
	if FileAccess.file_exists("res://scenes/npcs/city_pedestrian_routes.tscn"):
		previous = load("res://scenes/npcs/city_pedestrian_routes.tscn").instantiate()
	var text := '[gd_scene format=3]\n\n[ext_resource type="Script" path="res://scripts/npc-scripts/city_pedestrian_network.gd" id="1"]\n[ext_resource type="Script" path="res://scripts/npc-scripts/pedestrian_district.gd" id="2"]\n\n[node name="CityPedestrianRoutes" type="Node3D"]\nscript = ExtResource("1")\n'
	if previous != null:
		for property in ["network_enabled","show_debug_routes","show_disabled_routes","crossing_passing_margin"]:
			text += property+" = "+var_to_str(previous.get(property))+"\n"
	for district in ["WestVillage","NorthHeights","Parkside","CivicCenter","FinancialQuarter","Eastbank","FoundryWard","Docklands"]:
		var selected := ""
		for key in modules:
			if modules[key].district == district and modules[key].start != modules[key].destination:
				selected = key
				break
		var settings: Dictionary = {selected:true}
		var enabled := true
		var debug := true
		if previous != null and previous.has_node(NodePath(district)):
			var old = previous.get_node(NodePath(district))
			settings = old.enabled_routes.duplicate()
			enabled = old.district_enabled
			debug = old.show_debug
		text += '\n[node name="'+district+'" type="Node3D" parent="."]\nscript = ExtResource("2")\ndistrict_id = "'+district+'"\nenabled_routes = '+var_to_str(settings)+'\ndistrict_enabled = '+var_to_str(enabled)+'\nshow_debug = '+var_to_str(debug)+'\n'
		var sorted := modules.keys()
		sorted.sort()
		for key in sorted:
			if modules[key].district != district: continue
			var label: String = modules[key].label
			var p: Array = points[modules[key].start]
			text += '\n[node name="'+label+'" type="Node3D" parent="'+district+'"]\nmetadata/module_id = "'+key+'"\n'
			text += '\n[node name="StartHere" type="Marker3D" parent="'+district+'/'+label+'"]\nposition = Vector3(%s, 0.03, %s)\ngizmo_extents = 3.0\n' % [p[0],p[2]]
	FileAccess.open("res://scenes/npcs/city_pedestrian_routes.tscn",FileAccess.WRITE).store_string(text)
	if previous != null: previous.free()

func write_inventory(component_sizes: Array[int]) -> void:
	var report := "# Generated pedestrian route inventory\n\n%d modules; %d points; %d segments. Connected bank sizes: %s. River crossings: 0.\n\nOne checkbox enables one route module. Population is managed separately by CivilianCrowd. Block labels are north-to-south row and west-to-east column; they are organizational boundaries, not navigation barriers.\n\n" % [modules.size(),points.size(),edges.size(),str(component_sizes)]
	report += "| District / module | Segments | Start → destination IDs | Connected neighboring modules |\n| --- | ---: | --- | --- |\n"
	var keys := modules.keys()
	keys.sort()
	for key in keys:
		var module: Dictionary = modules[key]
		report += "| %s | %d | %d → %d | %s |\n" % [key,module.edge_count,module.start,module.destination,", ".join(module.neighbors)]
	report += "\n## Source checks\n\nBuilding collision footprints were read from the current Super City scene. Links were sampled at 1 m intervals with a 0.56 m footprint margin against sidewalk/alley unions, building footprints and excluded water. These are offline geometry checks, not a guarantee against later moved obstacles.\n\n"
	report += "No moved or missing authored buildings detected.\n" if warnings.is_empty() else "\n".join(warnings)
	FileAccess.open(DEST+"INVENTORY.md",FileAccess.WRITE).store_string(report)
