extends SceneTree
## Regression check for the first city chunk converted to editable sidewalk modules.
var failures := 0
var probes := 0
func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures < 20: push_error(message)

func in_rects(point: Vector3, rects: Array) -> bool:
	for r: Array in rects:
		if Rect2(r[0], r[1], r[2], r[3]).grow(0.002).has_point(Vector2(point.x, point.z)):
			return true
	return false

func run() -> void:
	var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/super-city/modular-sidewalks/sidewalks_3_2_conversion.json"))
	var city = load("res://scenes/super_city.tscn").instantiate()
	var chunk: Node3D = city.get_node("Sidewalks/sidewalks_3_2")
	chunk.get_parent().remove_child(chunk)
	city.free()
	root.add_child(chunk)
	await physics_frame
	await physics_frame
	check(chunk.get_child_count() == 98, "98 independently selectable pieces")
	check(not chunk.has_node("CollisionShape3D"), "Original combined collision is gone")
	var triangle_count := 0
	var top_area := 0.0
	for piece: Node3D in chunk.get_children():
		check(piece is StaticBody3D and piece.scale.is_equal_approx(Vector3.ONE), "Each module is an unscaled physics body")
		var visual: MeshInstance3D = piece.get_node("Mesh")
		for s in visual.mesh.get_surface_count():
			var a := visual.mesh.surface_get_arrays(s)
			var ids = a[Mesh.ARRAY_INDEX]
			if ids == null or ids.is_empty(): ids = range(a[Mesh.ARRAY_VERTEX].size())
			triangle_count += ids.size() / 3
			for i in range(0,ids.size(),3):
				var points: Array[Vector3] = []
				for j in 3: points.append(visual.global_transform * a[Mesh.ARRAY_VERTEX][ids[i+j]])
				if points.all(func(p): return absf(p.y - 0.03) < 0.0001):
					top_area += (points[1]-points[0]).cross(points[2]-points[0]).length() / 2.0
					for p in points: check(in_rects(p,audit.kept_rects), "Rendered vertex stays in original retained footprint: " + str(p))
	check(triangle_count == 1400, "Actual meshes total 1,400 triangles")
	check(absf(top_area-float(audit.new_top_area_m2)) < 0.05, "Rendered area matches original retained area")
	var space := chunk.get_world_3d().direct_space_state
	for r: Array in audit.kept_rects:
		for x in range(int(r[0]),int(r[0]+r[2])+1):
			for z in range(int(r[1]),int(r[1]+r[3])+1):
				var p := Vector3(x,0,z)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP,p-Vector3.UP))
				check(not hit.is_empty() and absf(hit.position.y-0.03)<0.001, "Retained sidewalk collision at " + str(p))
				probes += 1
	for r: Array in audit.removed_rects:
		var p := Vector3(r[0]+r[2]/2.0,0,r[1]+r[3]/2.0)
		check(space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP,p-Vector3.UP)).is_empty(), "No leftover collision on deleted waterfront strip")
	var infill = load("res://assets/super-city/modular-sidewalks/sidewalks_3_2_ground_infill.tscn").instantiate()
	root.add_child(infill)
	await physics_frame
	await physics_frame
	for r: Array in audit.removed_rects:
		var p := Vector3(r[0]+r[2]/2.0,0,r[1]+r[3]/2.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP,p-Vector3.UP))
		check(not hit.is_empty() and absf(hit.position.y)<0.001, "Deleted strip is filled with ground at Y = 0")
	var first: Node3D = chunk.get_node("Straight_01_01")
	var old_position := first.global_position
	first.position.y += 10
	await physics_frame
	await physics_frame
	var exposed_ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(old_position+Vector3.UP,old_position-Vector3.UP))
	check(not exposed_ground.is_empty() and absf(exposed_ground.position.y)<0.001, "Moving a piece exposes ground instead of leaving pavement collision or a hole")
	first.position.y -= 10
	var prefab: PackedScene = load("res://assets/super-city/modular-sidewalks/straight_adjustable.tscn")
	var a = prefab.instantiate(); var b = prefab.instantiate()
	a.position = Vector3(-5000,0,-5000); b.position = Vector3(-5100,0,-5000)
	root.add_child(a); root.add_child(b)
	a.length_m = 27.0; a.width_m = 6.0
	check(a.get_node("Collision0").shape != b.get_node("Collision0").shape, "Resizing has instance-local collision")
	check(b.get_node("Collision0").shape.size.is_equal_approx(Vector3(4.002,0.03,40.002)), "Resizing does not affect another instance")
	check(a.get_node("Collision0").shape.size.is_equal_approx(Vector3(6.002,0.03,27.002)), "Collision follows fitted dimensions")
	check(a.get_node("Mesh").scale.is_equal_approx(Vector3(1.5,1,0.675)), "Mesh follows fitted dimensions")
	check(is_equal_approx(a.get_node("Sockets/North").position.z,-13.5), "Connection markers follow fitted length")
	a.free(); b.free(); chunk.free(); infill.free()
	print("SIDEWALK_3_2_MODULAR: %d pieces, %d triangles, %.1f square metres, %d collision probes, %d failures" % [98,triangle_count,top_area,probes,failures])
	quit(0 if failures == 0 else 1)
