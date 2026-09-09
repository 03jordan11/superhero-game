extends SceneTree
## Independent scene/geometry/connectivity checks; never writes original assets.
const OUT = "res://assets/super-city/"
var failures: Array[String] = []
var stats: Dictionary = {}

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func rect(value: Array) -> Rect2:
	return Rect2(value[0],value[1],value[2],value[3])

func body_check(body: Node) -> void:
	check(body is StaticBody3D,"Not a StaticBody3D: "+str(body.name))
	check(body.get_child_count() == 2,"Expected exactly mesh and collision: "+str(body.name))
	var visual = body.get_node_or_null("MeshInstance3D") as MeshInstance3D
	var collision = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	check(visual != null and visual.mesh != null,"Missing mesh: "+str(body.name))
	check(collision != null and collision.shape != null,"Missing collision: "+str(body.name))
	if visual == null or visual.mesh == null or collision == null or collision.shape == null:
		return
	check(body.scale.is_equal_approx(Vector3.ONE) and visual.scale == Vector3.ONE and collision.scale == Vector3.ONE,"Scaled mesh/body/collision: "+str(body.name))
	check(not collision.disabled,"Disabled collider: "+str(body.name))
	var bounds = visual.mesh.get_aabb()
	if collision.shape is BoxShape3D:
		var box = AABB(collision.position-collision.shape.size/2,collision.shape.size)
		check(box.grow(0.001).encloses(bounds),"Box coverage failed: "+str(body.name))
	else:
		check(collision.shape is ConcavePolygonShape3D,"Unexpected chunk collision: "+str(body.name))
		check(collision.shape.get_faces().size() > 0,"Empty surface collision")
	for s in range(visual.mesh.get_surface_count()):
		check(visual.mesh.surface_get_material(s) is StandardMaterial3D,"Unexpected material")
		var arrays = visual.mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in range(0,vertices.size(),3):
			check(vertices[i].is_finite(),"Non-finite vertex")
			var cross = (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
			check(cross.length_squared() > 0.00000001,"Degenerate triangle: "+str(body.name))
			check(cross.dot(normals[i]) < 0,"Incorrect winding: "+str(body.name))

func _initialize() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(OUT+"layout.json"))
	var packed = load("res://scenes/super_city.tscn") as PackedScene
	check(packed != null,"City did not load")
	if packed == null:
		quit(1)
		return
	var city = packed.instantiate()
	check(city.name == &"SuperCity","Wrong city root")
	check(rect(data.city_rect).size == Vector2(3000,2000),"City must be 3 x 2 km")
	check(city.get_meta("city_size_m") == Vector2(3000,2000),"Scene size metadata differs")
	var park = rect(data.park_rect)
	var river: Array[Rect2] = []
	for row in data.river_rects:
		river.append(rect(row))
	for i in range(river.size()-1):
		check(river[i].grow(0.01).intersects(river[i+1]),"River is disconnected")
	check(river[-1].end.y == rect(data.bay_rect).position.y,"River does not meet bay")
	var road_rects: Array[Rect2] = []
	var alley_count = 0
	for row in data.roads:
		var r = rect(row.rect)
		road_rects.append(r)
		check(not r.intersects(park),"Road inside park")
		if row.kind != "junction":
			check(is_equal_approx(r.size.y if row.axis == 0 else r.size.x,row.width),"Carriageway width changed by clipping")
		check(int(row.width) in [6,12,20,28],"Unexpected road width")
		if row.kind == "alley":
			alley_count += 1
		if not row.crossing_corridor:
			for water in river:
				check(not r.intersects(water),"Road intrudes into river away from crossing")
	check(alley_count > 30,"Too few through-block alleys")
	# Road patches must form one connected component, including alley mouths and pier.
	var visited: Dictionary = {0:true}
	var queue: Array[int] = [0]
	var cursor = 0
	while cursor < queue.size():
		var index = queue[cursor]
		cursor += 1
		for j in range(road_rects.size()):
			if not visited.has(j) and road_rects[index].grow(0.04).intersects(road_rects[j]):
				visited[j] = true
				queue.append(j)
	check(visited.size() == road_rects.size(),"Disconnected road patches: %d of %d" % [road_rects.size()-visited.size(),road_rects.size()])
	var detached: Array = []
	for i in range(road_rects.size()):
		if not visited.has(i):
			detached.append(data.roads[i])
	var walks: Array[Rect2] = []
	for row in data.sidewalks:
		var r = rect(row)
		walks.append(r)
		check(not r.intersects(park),"Sidewalk intrudes into green park rectangle")
		for road in road_rects:
			check(not r.grow(-0.001).intersects(road),"Sidewalk blocks a carriageway or alley")
	var building_rects: Array[Rect2] = []
	var districts: Dictionary = {}
	for row in data.buildings:
		var body = city.get_node_or_null(row.node)
		check(body != null,"Missing baked building: "+row.node)
		if body == null:
			continue
		body_check(body)
		check(body.scene_file_path == row.asset,"Building lost its source PackedScene")
		check(is_zero_approx(body.position.y),"Building not grounded")
		var visual: MeshInstance3D = body.get_node("MeshInstance3D")
		var world_bounds: AABB = body.transform * visual.mesh.get_aabb()
		var actual = Rect2(world_bounds.position.x,world_bounds.position.z,world_bounds.size.x,world_bounds.size.z)
		var r = rect(row.rect)
		check(actual.position.distance_to(r.position) < 0.002 and actual.size.distance_to(r.size) < 0.002,"Scene and layout footprint differ")
		check(visual.visibility_range_end >= 850,"Missing per-instance draw-distance override")
		check(not r.intersects(park),"Building occupies park")
		for other in building_rects:
			check(not r.intersects(other),"Buildings overlap")
		for road in road_rects:
			check(not r.intersects(road),"Building blocks road/alley")
		for walk in walks:
			check(not r.intersects(walk),"Building blocks sidewalk")
		for water in river:
			check(not r.intersects(water),"Building occupies river")
		building_rects.append(r)
		districts[row.district] = districts.get(row.district,0)+1
	check(districts.size() == 8,"Expected eight populated districts")
	check(data.used_building_assets.size() == 50,"Not all 50 created building designs are represented")
	for category in ["Ground","WaterPlaceholders","Roads","Sidewalks","Landmarks"]:
		for body in city.get_node(category).get_children():
			body_check(body)
	for filename in DirAccess.get_files_at(OUT+"prefabs"):
		if filename.ends_with(".tscn"):
			var prefab = load(OUT+"prefabs/"+filename).instantiate()
			body_check(prefab)
			prefab.free()
	# Player placement is user-owned and is not part of city validation.
	check(city.has_node("TraversalStarts/ParkToSkyline"),"Missing suggested traversal-start marker")
	stats = {"engine":Engine.get_version_info().string,"passed":failures.is_empty(),"failures":failures,"city_size_m":[3000,2000],"buildings":building_rects.size(),"unique_building_assets":data.used_building_assets.size(),"districts":districts,"road_patches":road_rects.size(),"connected_road_patches":visited.size(),"detached_roads":detached,"alleys":alley_count,"sidewalk_patches":walks.size(),"crossings":data.crossings.size(),"park_size_m":[park.size.x,park.size.y]}
	var file = FileAccess.open(OUT+"tools/validation_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(stats,"\t"))
	print("SuperCity validation: %d buildings / %d designs / %d districts / %d road patches; %d failures" % [building_rects.size(),data.used_building_assets.size(),districts.size(),road_rects.size(),failures.size()])
	city.free()
	quit(0 if failures.is_empty() else 1)
