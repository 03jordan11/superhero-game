extends SceneTree
const PATHS = preload("res://assets/central-park/tools/park_paths.gd")
var failures := 0
var triangles: Array[Dictionary] = []
var grid := {}
var helper := PATHS.new()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures < 15: push_error(message)

func area(poly: PackedVector2Array) -> float:
	var value := 0.0
	for i in poly.size(): value += (poly[i]-poly[0]).cross(poly[(i+1)%poly.size()]-poly[0])
	return absf(value)*.5

func coverage_at(p: Vector2) -> bool:
	for id in grid.get(Vector2i((p/8.0).floor()),[]):
		if Geometry2D.is_point_in_polygon(p,triangles[id].poly): return true
	return false

func _initialize() -> void:
	var park: Node3D = load("res://scenes/central_park.tscn").instantiate()
	helper.ground_faces = park.get_node("Terrain/Ground/MeshInstance3D").mesh.get_faces()
	for id in range(0,helper.ground_faces.size(),3):
		helper.index_polygon(helper.ground_cells,helper.ground_polygon(id),id)
	for path in park.get_node("Trails").get_children():
		var mesh: Mesh = path.get_node("MeshInstance3D").mesh
		check(mesh.surface_get_material(0).albedo_texture != null,"Textured path: "+path.name)
		var faces := mesh.get_faces()
		for i in range(0,faces.size(),3):
			var poly := PackedVector2Array()
			for j in 3: poly.append(Vector2(faces[i+j].x,faces[i+j].z))
			if area(poly) < .000001: continue
			for other in helper.candidates(grid,poly):
				for intersection in Geometry2D.intersect_polygons(poly,triangles[other].poly):
					# Float32 clipping can report micrometre-wide slivers on shared edges.
					check(area(intersection)<.001,"Overlapping path faces: %s / %s (%.7f m2)" % [path.name,triangles[other].name,area(intersection)])
			var center := (faces[i]+faces[i+1]+faces[i+2])/3.0
			var p := Vector2(center.x,center.z)
			for ground_id in helper.ground_cells.get(Vector2i((p/8).floor()),[]):
				if Geometry2D.is_point_in_polygon(p,helper.ground_polygon(ground_id)):
					check(center.y>=helper.plane_height(p,ground_id)-.001,"Ground pokes through "+path.name)
					break
			helper.index_polygon(grid,poly,triangles.size())
			triangles.append({"poly":poly,"name":path.name})
	var samples := 0
	for route in PATHS.corrected_routes():
		var points: PackedVector2Array = route.points
		for i in points.size()-1:
			# Check the entire centerline at sub-metre spacing, including junctions.
			var steps := maxi(1,ceili(points[i].distance_to(points[i+1])/.5))
			for step in steps:
				var p := points[i].lerp(points[i+1],(step+.5)/steps)
				check(coverage_at(p),"Gap in "+route.name+" at "+str(p))
				samples += 1
		if route.name.ends_with("Gate"):
			var faces: PackedVector3Array = park.get_node("Trails/"+route.name+"/MeshInstance3D").mesh.get_faces()
			var boundary_vertices := 0
			for p in faces:
				check(absf(p.x)<=254.001 and absf(p.z)<=302.001,"Gate stays within park boundary")
				if absf(p.x)>253.999 or absf(p.z)>301.999:
					boundary_vertices += 1
					check(absf(p.y-.03)<.0001,"Gate is flush with city sidewalk")
			check(boundary_vertices>=2,"Gate reaches boundary")
		if route.name.ends_with("HouseTrail") or route.name.begins_with("Bridge"):
			var end: Vector2 = points[-1]
			var faces: PackedVector3Array = park.get_node("Trails/"+route.name+"/MeshInstance3D").mesh.get_faces()
			var cap_points: Array[Vector3] = []
			for p in faces:
				if (route.name.ends_with("HouseTrail") and absf(p.z-end.y)<.0001) or (route.name.begins_with("Bridge") and absf(p.x-end.x)<.0001):
					cap_points.append(p)
			check(cap_points.size()>=2,"Path reaches entrance cap: "+route.name)
			for p in cap_points:
				var expected: float = .15 if route.name.ends_with("HouseTrail") else PATHS.LAYOUT.height(end)+.13
				check(absf(p.y-expected)<.001,"Entrance cap height matches ramp/deck: "+route.name)
	print("Park paths: %d centerline samples, %d triangles, %d failures" % [samples,triangles.size(),failures])
	park.free()
	quit(0 if failures==0 else 1)
