extends SceneTree
const RUNTIME = preload("res://scripts/pavement_chunks.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func face_key(a: Vector3, b: Vector3, c: Vector3) -> String:
	var points := [str(a.snapped(Vector3.ONE * .002)), str(b.snapped(Vector3.ONE * .002)), str(c.snapped(Vector3.ONE * .002))]
	points.sort()
	return "|".join(points)

func faces(node: MeshInstance3D, city: Node3D, tops_only := false) -> Dictionary:
	var result := {}
	var pose := RUNTIME.POSE.pose_in(node, city)
	for surface in node.mesh.get_surface_count():
		var arrays := node.mesh.surface_get_arrays(surface)
		var ids = arrays[Mesh.ARRAY_INDEX]
		if ids == null or ids.is_empty(): ids = range(arrays[Mesh.ARRAY_VERTEX].size())
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in range(0, ids.size(), 3):
			if tops_only and (pose.basis.inverse().transposed() * normals[ids[i]]).normalized().y < .99: continue
			var key := face_key(pose * vertices[ids[i]], pose * vertices[ids[i+1]], pose * vertices[ids[i+2]])
			result[key] = result.get(key, 0) + 1
	return result

func merge_faces(target: Dictionary, other: Dictionary) -> void:
	for key in other: target[key] = target.get(key, 0) + other[key]

func same_faces(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size(): return false
	for key in a:
		if a[key] != b.get(key, 0): return false
	return true

func run() -> void:
	create_timer(120).timeout.connect(func(): push_error("Pavement test timeout"); quit(1))
	paused = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	for monitor in world.get_node("PerformanceMonitors").get_children(): monitor.enabled = false
	var city: Node3D = world.get_node("SuperCity")
	var controller = city.get_node("PavementChunks")
	controller.enabled = false
	root.add_child(world)
	for frame in 6: await process_frame
	controller.set_process(false)
	check(controller.prepared and controller.valid_bake, "Pavement bake matches Main after module rebuilds")
	check(controller.sources.size() == 798 and controller.entries.size() == 24, "798 source meshes replaced by 24 chunks")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RUNTIME.OUT + "inventory.json"))
	check(data.source_surfaces == 1428 and data.near_triangles == 46844 and data.far_triangles == 9346, "Exact source and reduced geometry counts")
	var collisions := {}
	for group in ["Roads", "Sidewalks"]:
		for shape in city.get_node(group).find_children("*", "CollisionShape3D", true, false):
			collisions[shape] = [shape.transform, shape.shape, shape.disabled]
	var original_flags := {}
	for mesh in RUNTIME.source_meshes(city): original_flags[mesh] = mesh.visible
	for row: Dictionary in data.chunks:
		var chunk := controller.get_node(NodePath(row.name)) as Node3D
		var original_faces := {}
		var original_tops := {}
		for path: String in row.sources:
			var source := city.get_node(NodePath(path)) as MeshInstance3D
			merge_faces(original_faces, faces(source, city))
			merge_faces(original_tops, faces(source, city, true))
		var near := chunk.get_node("FullDetail") as MeshInstance3D
		var far := chunk.get_node("DistantProxy") as MeshInstance3D
		check(near.mesh.get_surface_count() == 1 and far.mesh.get_surface_count() == 1, "One material surface per chunk at either LOD")
		check(same_faces(original_faces, faces(near, city)), "Full geometry exactly preserved: " + row.name)
		check(same_faces(original_tops, faces(far, city)), "Distant top footprint exact, including cutouts: " + row.name)
	controller.enabled = true
	for mode in [1, 2]:
		controller.force_lod = mode
		controller.update_visibility()
		for source in controller.sources: check(not source.visible, "Original visual hidden; no double rendering")
		for entry in controller.entries:
			check(entry.node.visible and entry.near.visible == (mode == 1) and entry.far.visible == (mode == 2), "Exactly one active mesh per chunk")
		for shape in collisions:
			check([shape.transform, shape.shape, shape.disabled] == collisions[shape], "Physical surface unchanged at both LODs")
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	controller.force_lod = 0
	var entry: Dictionary = controller.entries[0]
	var box: AABB = controller.global_transform * entry.bounds
	for sample in [[0.0, 0], [351.0, 1], [325.0, 1], [299.0, 0]]:
		camera.position = Vector3(box.end.x + sample[0], box.get_center().y, box.get_center().z)
		controller.update_visibility()
		check(entry.state == sample[1], "Nearest-edge switching with 50 m hysteresis")
	controller.enabled = false
	for source in original_flags: check(source.visible == original_flags[source], "Disable restores originals")
	check(not entry.node.visible, "Disable hides baked meshes")
	check(city.has_node("TrafficManager") and city.has_node("CityPedestrianRoutes"), "Traffic and pedestrian nodes retained")
	# A representative road ray must still hit the same body with the proxy forced.
	await physics_frame
	var road: MeshInstance3D = controller.sources[0]
	var triangle: PackedVector3Array = road.mesh.get_faces()
	var point := road.global_transform * ((triangle[0] + triangle[1] + triangle[2]) / 3.0)
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP, point - Vector3.UP)
	var space := city.get_world_3d().direct_space_state
	var before := space.intersect_ray(query)
	controller.force_lod = 2
	controller.enabled = true
	await physics_frame
	var after := space.intersect_ray(query)
	check(not before.is_empty() and after.get("collider") == before.get("collider"), "Proxy retains original road collision")
	# Fresh edited scene: changed authored road must fail safely rather than disappear.
	controller.enabled = false
	controller.sources[0].get_parent().position.x += 1.0
	check(JSON.stringify(RUNTIME.snapshot(city), "", true) != JSON.stringify(data.sources, "", true), "Source movement invalidates baked geometry")
	controller.valid_bake = false
	controller.enabled = true
	check(controller.sources[0].visible and not entry.node.visible, "Stale bake falls back to original visuals")
	world.free()
	camera.free()
	print("Pavement chunks: %d failures" % failures)
	quit(0 if failures == 0 else 1)
