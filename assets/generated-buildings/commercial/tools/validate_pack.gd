extends SceneTree
## Read-only scene validation. Writes only this pack's validation report.
const OUT = "res://assets/generated-buildings/commercial/"
var failures: Array[String] = []
var rows: Array = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	var collection: Array[PackedScene] = []
	var files = DirAccess.get_files_at(OUT)
	var scene_count = 0
	for file in files:
		if file.ends_with(".tscn"):
			scene_count += 1
	check(scene_count == 20, "Expected exactly 20 building scenes")
	for i in range(1,21):
		var path = OUT + "commercial_skyscraper_%02d.tscn" % i
		check(FileAccess.file_exists(path), "Missing " + path)
		var packed = load(path) as PackedScene
		check(packed != null, "Cannot load " + path)
		if packed == null:
			continue
		collection.append(packed)
		var body = packed.instantiate()
		check(body is StaticBody3D, path + " root must be StaticBody3D")
		if body.has_node("RooftopHVAC"):
			validate_revised(body, path)
			body.free()
			continue
		check(body.get_child_count() == 2, path + " must have exactly two children")
		check(body.transform == Transform3D.IDENTITY, path + " root must be identity")
		check(body.get_script() == null, path + " must have no script")
		var visual = body.get_node_or_null("MeshInstance3D") as MeshInstance3D
		var collision = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		check(visual != null and visual.mesh != null, path + " missing mesh")
		check(collision != null and collision.shape is BoxShape3D, path + " missing simple box collision")
		if visual == null or visual.mesh == null or collision == null or not collision.shape is BoxShape3D:
			body.free()
			continue
		check(visual.transform == Transform3D.IDENTITY, path + " mesh must be identity")
		check(collision.scale == Vector3.ONE, path + " collision scale")
		check(not collision.disabled, path + " collision disabled")
		check(body.collision_layer == 1, path + " default world collision layer")
		var bounds = visual.mesh.get_aabb()
		check(absf(bounds.position.y) < 0.0001, path + " base is not at Y=0")
		check(absf(bounds.get_center().x) < 0.0001 and absf(bounds.get_center().z) < 0.0001, path + " horizontal origin not centered")
		var box = AABB(collision.position-collision.shape.size/2,collision.shape.size).grow(0.001)
		check(box.encloses(bounds), path + " box does not enclose mesh")
		check(bounds.size.x <= 34.1 and bounds.size.z <= 34.1, path + " footprint too large")
		var triangles = 0
		for s in range(visual.mesh.get_surface_count()):
			check(visual.mesh.surface_get_material(s) is StandardMaterial3D, path + " unexpected shader")
			var arrays = visual.mesh.surface_get_arrays(s)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			triangles += int(vertices.size()/3)
			for v in vertices:
				check(v.is_finite() and box.has_point(v) and v.y >= -0.0001,path+" invalid/uncovered vertex")
			for t in range(0,vertices.size(),3):
				var cross = (vertices[t+1]-vertices[t]).cross(vertices[t+2]-vertices[t])
				check(cross.length() > 0.00001, path + " degenerate triangle")
				check(cross.dot(normals[t]) < 0.0, path + " winding/normal mismatch")
		rows.append({"scene":path.get_file(),"size_m":[bounds.size.x,bounds.size.y,bounds.size.z],"triangles":triangles,"surfaces":visual.mesh.get_surface_count(),"nodes":3})
		body.free()
	# City Crafter is optional and is no longer present in this checkout.
	var config_path := "res://addons/citycrafter/city_configuration.gd"
	var addon_checked := FileAccess.file_exists(config_path)
	if addon_checked:
		var config = load(config_path).new()
		config.commercial_buildings = collection
		check(config.commercial_buildings.size() == 20 and config.is_valid(), "CityConfiguration array assignment failed")
	var file = FileAccess.open(OUT+"tools/validation_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"passed":failures.is_empty(),"failures":failures,"typed_array_entries":collection.size(),"citycrafter_checked":addon_checked,"buildings":rows},"\t"))
	print("Validation: %d scenes, %d Array[PackedScene] entries, %d failures" % [rows.size(),collection.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)

func relative_transform(node: Node3D, body: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != body:
		result = parent.transform * result
		parent = parent.get_parent()
	return result

func validate_revised(body: StaticBody3D, path: String) -> void:
	check(body.transform == Transform3D.IDENTITY, path + " root must be identity")
	check(body.get_script() != null, path + " missing night lighting")
	check(body.has_node("MeshInstance3D") and body.has_node("CollisionShape3D") and body.has_node("RooftopHVAC"), path + " missing required nodes")
	var boxes: Array[AABB] = []
	for collision: CollisionShape3D in body.find_children("*", "CollisionShape3D", true, false):
		check(collision.shape is BoxShape3D and not collision.disabled, path + " invalid collision")
		boxes.append((relative_transform(collision, body) * AABB(-collision.shape.size/2, collision.shape.size)).grow(.002))
	var triangles := 0
	var surfaces := 0
	var bounds := AABB()
	for visual: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		var transform := relative_transform(visual, body)
		bounds = bounds.merge(transform * visual.mesh.get_aabb())
		surfaces += visual.mesh.get_surface_count()
		triangles += visual.mesh.get_faces().size() / 3
		for surface in visual.mesh.get_surface_count():
			check(visual.mesh.surface_get_material(surface) is StandardMaterial3D, path + " invalid material")
			var arrays := visual.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var ids: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if ids.is_empty():
				for index in vertices.size(): ids.append(index)
			for vertex in vertices:
				var covered := false
				for box in boxes:
					if box.has_point(transform * vertex): covered = true
				check(vertex.is_finite() and covered, path + " invalid/uncovered vertex")
			for t in range(0, ids.size(), 3):
				var cross := (vertices[ids[t+1]]-vertices[ids[t]]).cross(vertices[ids[t+2]]-vertices[ids[t]])
				check(cross.length() > .00001 and cross.dot(normals[ids[t]]) < 0, path + " degenerate triangle or winding mismatch")
	check(triangles <= 108, path + " exceeds original complete triangle budget")
	rows.append({"scene":path.get_file(), "size_m":[bounds.size.x,bounds.size.y,bounds.size.z], "triangles":triangles, "surfaces":surfaces, "nodes":body.find_children("*", "", true, false).size()+1})
