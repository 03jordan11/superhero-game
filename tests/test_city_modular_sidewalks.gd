extends SceneTree
var failures := 0
var probes := 0
var footprint := {}
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures < 25: push_error(message)
func contains_point(point: Vector3, rects: Array, margin := 0.003) -> bool:
	for r: Rect2 in rects:
		if r.grow(margin).has_point(Vector2(point.x,point.z)): return true
	return false
func support(space: PhysicsDirectSpaceState3D, p: Vector3, height: float) -> bool:
	probes += 1
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP,p-Vector3.UP))
	return not hit.is_empty() and absf(hit.position.y-height)<0.001
func run() -> void:
	var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/modular-sidewalks/city_conversion.json"))
	var city = load("res://scenes/super_city.tscn").instantiate()
	var world := Node3D.new();root.add_child(world)
	var nodes := {}
	for c: Dictionary in audit.chunks:
		var node: Node3D = city.get_node("Sidewalks/"+c.name)
		node.get_parent().remove_child(node);world.add_child(node);nodes[c.name]=node
		var rects: Array = []
		for r: Array in c.kept_rects:rects.append(Rect2(r[0],r[1],r[2],r[3]))
		footprint[c.name]=rects
	var infill = city.get_node("Ground/CitySidewalkGroundInfill")
	infill.get_parent().remove_child(infill);world.add_child(infill)
	city.free()
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	var total_triangles := 0
	var total_pieces := 0
	var total_area := 0.0
	for c: Dictionary in audit.chunks:
		var node: Node3D = nodes[c.name]
		check(node.get_child_count()==c.placements.size(),"Module count: "+c.name)
		check(not node is StaticBody3D and not node.has_node("CollisionShape3D"),"Combined collision removed: "+c.name)
		var triangles := 0; var top_area := 0.0
		for piece: Node3D in node.get_children():
			total_pieces += 1
			check(piece is StaticBody3D and not piece.scene_file_path.is_empty(),"Editable module scene instance")
			check(piece.scale.is_equal_approx(Vector3.ONE),"Physics body stays unscaled")
			var visual: MeshInstance3D = piece.get_node("Mesh")
			for s in visual.mesh.get_surface_count():
				var a := visual.mesh.surface_get_arrays(s);var ids = a[Mesh.ARRAY_INDEX]
				if ids == null or ids.is_empty():ids=range(a[Mesh.ARRAY_VERTEX].size())
				triangles += ids.size()/3
				for i in range(0,ids.size(),3):
					var ps: Array[Vector3] = []
					for j in 3:ps.append(visual.global_transform*a[Mesh.ARRAY_VERTEX][ids[i+j]])
					if ps.all(func(p):return absf(p.y-0.03)<0.0001):
						top_area += (ps[1]-ps[0]).cross(ps[2]-ps[0]).length()/2.0
						for p in ps:check(contains_point(p,footprint[c.name]),"Rendered footprint: %s %s"%[c.name,p])
			for socket: Node3D in piece.get_node("Sockets").get_children():
				for offset in [-0.002,0.0,0.002]:
					var p: Vector3 = socket.global_position+socket.global_basis.z*offset
					if contains_point(p,footprint[c.name],-0.0001):check(support(space,p,0.03),"Connection seam: %s %s"%[c.name,p])
		var expected_area := 0.0
		for r: Array in c.kept_rects:
			expected_area += r[2]*r[3]
			var nx := maxi(1,ceili(r[2]/4.0));var nz := maxi(1,ceili(r[3]/4.0))
			for ix in nx+1:
				for iz in nz+1:
					var p := Vector3(r[0]+r[2]*ix/nx,0,r[1]+r[3]*iz/nz)
					check(support(space,p,0.03),"Retained collision: %s %s"%[c.name,p])
		check(absf(top_area-expected_area)<0.15,"Exact retained area: "+c.name)
		check(triangles==c.new_triangles,"Actual triangles: "+c.name)
		for r: Array in c.removed_rects:
			check(support(space,Vector3(r[0]+r[2]/2.0,0,r[1]+r[3]/2.0),0),"Deleted remnant exposes ground")
		total_triangles+=triangles;total_area+=top_area
	# Exercise actual move/delete behavior once in each converted chunk.
	var moved := []
	for c: Dictionary in audit.chunks:
		var piece: Node3D = nodes[c.name].get_child(0)
		var original := piece.global_position
		moved.append([piece,original,c]);piece.position.y+=10
	await physics_frame
	await physics_frame
	for row: Array in moved:
		var p: Vector3 = row[1];var c: Dictionary = row[2]
		check(support(space,p,0),"Ground remains when a module moves: "+c.name)
		check(support(space,p+Vector3.UP*10,10.03),"Module collision follows moved visual: "+c.name)
	print("CITY_MODULAR_SIDEWALKS: %d chunks, %d pieces, %d triangles, %.2f m2, %d support/seam probes, %d failures"%[audit.chunks.size(),total_pieces,total_triangles,total_area,probes,failures])
	world.free();quit(0 if failures==0 else 1)
