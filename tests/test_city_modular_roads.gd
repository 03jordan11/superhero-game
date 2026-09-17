extends SceneTree
## Validate the rendered and physical result, including pavement absorbed by roads.
var failures := 0
var probes := 0
var triangles := 0
var pieces := 0
var space: PhysicsDirectSpaceState3D

func _initialize() -> void: run.call_deferred()
func include_chunk(_name: String) -> bool: return true
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures < 30: push_error(message)
func rect(row: Array) -> Rect2: return Rect2(row[0], row[1], row[2], row[3])
func contains(p: Vector3, rows: Array) -> bool:
	for r: Array in rows:
		if rect(r).grow(.003).has_point(Vector2(p.x,p.z)): return true
	return false
func covered(target: Rect2, allowed: Array[Rect2]) -> bool:
	var remaining: Array[Rect2] = [target]
	for cut in allowed:
		var next: Array[Rect2] = []
		for a in remaining:
			var b := a.intersection(cut.grow(.001))
			if not b.has_area(): next.append(a); continue
			for part in [Rect2(a.position,Vector2(a.size.x,b.position.y-a.position.y)), Rect2(Vector2(a.position.x,b.end.y),Vector2(a.size.x,a.end.y-b.end.y)), Rect2(Vector2(a.position.x,b.position.y),Vector2(b.position.x-a.position.x,b.size.y)), Rect2(Vector2(b.end.x,b.position.y),Vector2(a.end.x-b.end.x,b.size.y))]:
				if part.size.x > .002 and part.size.y > .002: next.append(part)
		remaining = next
		if remaining.is_empty(): return true
	return remaining.is_empty()
func support(p: Vector3, height := .03) -> bool:
	probes += 1
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP,p-Vector3.UP))
	return not hit.is_empty() and absf(hit.position.y-height)<.001
func surface(visual: MeshInstance3D, index: int, allowed: Array, actual: Array[Rect2]) -> float:
	var arrays := visual.mesh.surface_get_arrays(index)
	var ids = arrays[Mesh.ARRAY_INDEX]
	if ids == null or ids.is_empty(): ids = range(arrays[Mesh.ARRAY_VERTEX].size())
	triangles += ids.size()/3
	var area := 0.0
	var allowed_rects: Array[Rect2] = []
	for row: Array in allowed: allowed_rects.append(rect(row))
	var seen := {}
	for i in range(0,ids.size(),3):
		var points: Array[Vector3] = []
		for j in 3: points.append(visual.global_transform*arrays[Mesh.ARRAY_VERTEX][ids[i+j]])
		if not points.all(func(p):return absf(p.y-.03)<.001): continue
		area += (points[1]-points[0]).cross(points[2]-points[0]).length()*.5
		var low := points[0].min(points[1]).min(points[2])
		var high := points[0].max(points[1]).max(points[2])
		var bounds := Rect2(low.x,low.z,high.x-low.x,high.z-low.z)
		if not seen.has(bounds):
			seen[bounds]=true; actual.append(bounds)
			check(covered(bounds,allowed_rects),"Rendered surface outside original footprint: %s %s"%[visual.get_path(),bounds])
	return area
func run() -> void:
	create_timer(90).timeout.connect(func():push_error("City road validation timed out");quit(1))
	var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/modular-roads/city_conversion.json"))
	check(FileAccess.get_sha256("res://assets/super-city/layout.json")==audit.layout_sha256,"Traffic layout is byte-identical")
	var city: Node3D = load("res://scenes/super_city.tscn").instantiate()
	var holder := Node3D.new(); root.add_child(holder)
	var chunks := {}
	for c: Dictionary in audit.chunks:
		if not include_chunk(c.name): continue
		var branches := []
		for path in ["Roads/"+c.name,"Sidewalks/"+c.name.replace("roads_","sidewalks_")]:
			var node: Node3D = city.get_node(path)
			node.get_parent().remove_child(node); holder.add_child(node); branches.append(node)
		chunks[c.name]=branches
	var infills: Array[Node3D] = []
	for path in ["Ground/CitySidewalkGroundInfill","Ground/Sidewalks3_2GroundInfill"]:
		var infill: Node3D = city.get_node(path)
		infill.get_parent().remove_child(infill); infills.append(infill)
	city.free()
	await physics_frame
	await physics_frame
	space=holder.get_world_3d().direct_space_state
	for c: Dictionary in audit.chunks:
		if not chunks.has(c.name): continue
		var branches: Array = chunks[c.name]
		check(branches[0].get_child_count()==c.combined_roads.size(),"Road instance count: "+c.name)
		check(branches[1].get_child_count()==c.remaining_walks.size(),"Independent paving count: "+c.name)
		var areas := [0.0,0.0]
		var actual_roads: Array[Rect2] = []; var actual_walks: Array[Rect2] = []
		for branch in branches:
			check(not branch is StaticBody3D,"Chunk does not retain old combined collision")
			for piece: Node3D in branch.get_children():
				pieces += 1
				check(piece is StaticBody3D and not piece.scene_file_path.is_empty(),"Editable prefab instance")
				check(piece.scale.is_equal_approx(Vector3.ONE),"Physics body is unscaled")
				var visual: MeshInstance3D = piece.get_node("Mesh")
				if branch==branches[0]:
					check(piece.get_child_count()==2 and not piece.has_node("RoadSockets"),"City connection helpers remain editor-only")
					areas[0]+=surface(visual,0,c.original_road_rects,actual_roads)
					if visual.mesh.get_surface_count()>1: areas[1]+=surface(visual,1,c.original_sidewalk_rects,actual_walks)
				else: areas[1]+=surface(visual,0,c.original_sidewalk_rects,actual_walks)
		for kind in 2:
			var expected: Array = c.original_road_rects if kind==0 else c.original_sidewalk_rects
			var actual: Array[Rect2] = actual_roads if kind==0 else actual_walks
			var area := 0.0
			for row: Array in expected:
				var r := rect(row); area+=r.get_area()
				check(covered(r,actual),"No hole in rendered footprint: %s %s"%[c.name,r])
				var nx := maxi(1,ceili(r.size.x/5)); var nz := maxi(1,ceili(r.size.y/5))
				for ix in nx+1:
					for iz in nz+1:
						var p := Vector3(r.position.x+r.size.x*ix/nx,0,r.position.y+r.size.y*iz/nz)
						check(support(p),"Collision covers original surface: %s %s"%[c.name,p])
			check(absf(areas[kind]-area)<.2,"Exact area without overlapping surfaces: %s kind %d: %.3f vs %.3f"%[c.name,kind,areas[kind],area])
		var bounds := rect(c.bounds)
		var all_rects: Array = c.original_road_rects+c.original_sidewalk_rects
		for x in range(int(bounds.position.x)+1,int(bounds.end.x),19):
			for z in range(int(bounds.position.y)+1,int(bounds.end.y),19):
				var p := Vector3(x+.037,0,z+.037)
				if not contains(p,all_rects): check(not support(p),"No added pavement/collision in openings: %s %s"%[c.name,p])
	# A fitted road and its sidewalk must move together, including collision.
	var first: Node3D = chunks.values()[0][0].get_child(0)
	var r: Rect2 = first.road_rects()[0]
	var point: Vector3 = first.global_transform*Vector3(r.get_center().x,0,r.get_center().y)
	var paving: Rect2 = first.sidewalk_rects()[0]
	var paving_point: Vector3 = first.global_transform*Vector3(paving.get_center().x,0,paving.get_center().y)
	first.position.y+=10
	await physics_frame
	await physics_frame
	check(support(point+Vector3.UP*10,10.03),"Road collision follows edited module")
	check(not support(point),"No baked collider remains at old position")
	for infill in infills: holder.add_child(infill)
	await physics_frame
	await physics_frame
	check(support(paving_point,0),"Existing ground remains when attached sidewalk moves")
	var old_walks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/modular-sidewalks/city_conversion.json"))
	var pilot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/modular-sidewalks/sidewalks_3_2_conversion.json"))
	pilot.name="sidewalks_3_2"; old_walks.chunks.append(pilot)
	for c: Dictionary in old_walks.chunks:
		if not include_chunk(c.name.replace("sidewalks_","roads_")): continue
		for row: Array in c.removed_rects:
			var p := rect(row).get_center()
			check(support(Vector3(p.x,0,p.y),0),"Removed waterfront stub retains ground instead of pavement")
	print("CITY_MODULAR_ROADS: %d chunks, %d pieces, %d triangles, %d footprint/collision probes, %d failures"%[chunks.size(),pieces,triangles,probes,failures])
	holder.free(); quit(0 if failures==0 else 1)
