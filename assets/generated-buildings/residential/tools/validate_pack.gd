extends SceneTree
## Read-only scene validation. Writes only this pack's validation report.
const OUT = "res://assets/generated-buildings/residential/"
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
		var path = OUT + "residential_building_%02d.tscn" % i
		check(FileAccess.file_exists(path), "Missing " + path)
		var packed = load(path) as PackedScene
		check(packed != null, "Cannot load " + path)
		if packed == null:
			continue
		collection.append(packed)
		var body = packed.instantiate()
		check(body is StaticBody3D, path + " root must be StaticBody3D")
		check(body.get_child_count() >= 3, path + " must have mesh, collision and shared roof props")
		check(body.transform == Transform3D.IDENTITY, path + " root must be identity")
		check(body.get_script()!=null, path + " must have seeded emission controller")
		var visual = body.get_node_or_null("MeshInstance3D") as MeshInstance3D
		var collision = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		check(visual != null and visual.mesh != null, path + " missing mesh")
		check(collision != null and collision.shape is BoxShape3D, path + " missing solid box collision")
		if visual == null or visual.mesh == null or collision == null or not collision.shape is BoxShape3D:
			body.free()
			continue
		check(visual.transform == Transform3D.IDENTITY, path + " mesh must be identity")
		check(collision.scale == Vector3.ONE, path + " collision scale")
		check(not collision.disabled, path + " collision disabled")
		check(body.collision_layer == 1, path + " default world collision layer")
		var bounds = visual.mesh.get_aabb()
		check(absf(bounds.position.y) < 0.0001, path + " base is not at Y=0")
		for node in body.get_children():
			if node is CollisionShape3D:
				check(node.shape is BoxShape3D and node.shape.size.x > 0 and node.shape.size.y > 0 and node.shape.size.z > 0, path + " invalid solid volume")
		var box = bounds.grow(0.001)
		check(bounds.size.x <= 38.0 and bounds.size.z <= 32.0, path + " footprint too large")
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
		for prop_name in ["RooftopHVAC","RooftopWaterTower"]:
			var prop=body.get_node_or_null(NodePath(prop_name))
			if prop!=null: triangles+=prop.get_node("MeshInstance3D").mesh.get_faces().size()/3
		check(triangles<10000,path+" complete geometry budget exceeded")
		rows.append({"scene":path.get_file(),"size_m":[bounds.size.x,bounds.size.y,bounds.size.z],"triangles":triangles,"surfaces":visual.mesh.get_surface_count(),"nodes":body.get_child_count()+1})
		body.free()
	# The old CityCrafter addon is no longer installed; retain optional compatibility.
	if ResourceLoader.exists("res://addons/citycrafter/city_configuration.gd"):
		var config_script = load("res://addons/citycrafter/city_configuration.gd")
		var config = config_script.new()
		config.residential_buildings = collection
		check(config.residential_buildings.size() == 20 and config.is_valid(), "CityConfiguration array assignment failed")
	var file = FileAccess.open(OUT+"tools/validation_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"passed":failures.is_empty(),"failures":failures,"typed_array_entries":collection.size(),"buildings":rows},"\t"))
	print("Validation: %d scenes, %d Array[PackedScene] entries, %d failures" % [rows.size(),collection.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)

